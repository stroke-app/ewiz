import Foundation
import BattlifyKit

/// Unix-domain-socket server: one newline-delimited JSON request/response per connection.
final class ControlServer {
    private let path: String
    private let handler: @Sendable (ControlRequest) -> ControlResponse
    private var listenFD: Int32 = -1
    /// The inode our listener is bound to. If the path later points somewhere else, another
    /// instance has taken it and nothing can reach us — see `ownsSocketPath`.
    private var boundInode: (dev: Int32, ino: UInt64)?

    init(path: String = ControlSocket.path,
         handler: @escaping @Sendable (ControlRequest) -> ControlResponse) {
        self.path = path
        self.handler = handler
    }

    /// Bring the listener up. Fatal on failure, deliberately: a daemon with no control
    /// socket looks alive to launchd while the app hangs waiting for an answer that can never
    /// come. Exiting hands the problem to launchd, which restarts us and usually clears it.
    func start() {
        _ = startListening(fatalOnFailure: true)
    }

    @discardableResult
    private func startListening(fatalOnFailure: Bool) -> Bool {
        /// Give up the way the caller asked: fatally on first start, or with a false that
        /// lets a rebind attempt fail without killing a working daemon.
        func giveUp(_ what: String) -> Bool {
            if fatalOnFailure { fail(what) }
            perror(what)
            return false
        }

        unlink(path) // remove stale socket from a previous run

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return giveUp("socket") }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dst in
                pathBytes.withUnsafeBufferPointer { src in
                    dst.update(from: src.baseAddress!, count: src.count)
                }
            }
        }

        let bound = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0 else { close(fd); return giveUp("bind") }

        // Mode has to stay permissive: connecting to a unix socket needs write permission
        // on the path, and the GUI runs as an ordinary user whose uid isn't knowable here.
        // Access control therefore lives on the accepted connection instead, where the
        // kernel reports who the peer really is — see `peerIsAuthorized`.
        chmod(path, 0o666)

        guard listen(fd, 8) == 0 else { close(fd); return giveUp("listen") }
        listenFD = fd
        // Remember which inode we own, so a stolen path is detectable later.
        var info = stat()
        if stat(path, &info) == 0 {
            boundInode = (info.st_dev, info.st_ino)
        }
        HelperLog.info("control socket listening at \(path)")

        let handler = self.handler
        Thread.detachNewThread {
            ControlServer.acceptLoop(fd, handler: handler)
        }
        return true
    }

    /// False once the socket path no longer refers to the inode we bound.
    ///
    /// This is one of the two ways a control channel is lost. Two daemons briefly overlap
    /// during an install; the second unlinks the first's socket and binds its own; the second
    /// then goes away. The survivor is still listening — on an inode nothing can reach by
    /// name — so the app gets "connection refused" from a daemon that reports itself
    /// perfectly healthy.
    var ownsSocketPath: Bool {
        guard let boundInode else { return true }   // never bound cleanly; nothing to compare
        var info = stat()
        guard stat(path, &info) == 0 else { return false }
        return info.st_dev == boundInode.dev && info.st_ino == boundInode.ino
    }

    /// The other way, and the one that cost a user 6% overnight: the path is still ours and
    /// the descriptor backing it is gone.
    ///
    /// Owning the path says nothing about whether anyone is still answering on it. A listener
    /// that has been closed leaves the socket file exactly where it was, so the inode check
    /// passes while every connection is refused.
    ///
    /// `fcntl(F_GETFD)`, not `getsockopt(SO_ACCEPTCONN)`. The latter is the obvious answer to
    /// "is this still listening" and Darwin doesn't implement it for unix-domain sockets: it
    /// fails with `ENOPROTOOPT`, which a health check reads as "not listening", so the daemon
    /// rebinds a perfectly good socket every single tick. Asking whether the descriptor is
    /// still open is the question that actually has an answer here, and a closed descriptor
    /// is precisely the failure this is looking for.
    var isListening: Bool {
        listenFD >= 0 && fcntl(listenFD, F_GETFD) != -1
    }

    /// Both halves of "can the app still reach us".
    var isReachable: Bool { ownsSocketPath && isListening }

    /// The end-to-end version: connect to our own path and see whether anything answers.
    ///
    /// The cheap checks can't see a dead accept loop — the kernel queues a connection to a
    /// listening socket nobody is accepting on, so `connect` succeeds and the client then
    /// waits forever, which is what the app experiences as a hang. This is the only check
    /// that tests the whole path, so it runs on a slow cadence rather than every tick.
    ///
    /// It asks with `probeLine`, which the accept thread answers itself. Asking with a real
    /// request measured the daemon's lock instead of the listener: a sleep transition holds
    /// that lock for seconds, the probe timed out behind it, and a perfectly good socket was
    /// torn down and rebound, dropping whatever the app had queued on it.
    func answersItsOwnCall(timeout: Int32 = 2) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = path.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else { return false }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: pathBytes.count) { dst in
                pathBytes.withUnsafeBufferPointer { src in
                    dst.update(from: src.baseAddress!, count: src.count)
                }
            }
        }
        let connected = withUnsafePointer(to: &addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return false }

        let request = Self.probeLine + Data([0x0A])
        let sent = request.withUnsafeBytes { raw in write(fd, raw.baseAddress, raw.count) }
        guard sent == request.count else { return false }

        var byte: UInt8 = 0
        return read(fd, &byte, 1) == 1
    }

    /// Stand the listener back up in place, without taking the daemon down with it.
    ///
    /// Tried before exiting, because exiting drops everything the daemon is holding — the
    /// charge state, a deferral part-way through, the sealed-sleep snapshot — to fix a
    /// socket. If the rebind fails, the caller falls back to exiting and lets launchd do it
    /// the blunt way.
    @discardableResult
    func rebind() -> Bool {
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        boundInode = nil
        return startListening(fatalOnFailure: false)
    }

    private func fail(_ what: String) -> Never {
        perror(what)
        HelperLog.error("cannot serve the control socket at \(path); exiting so launchd retries")
        exit(5)
    }

    private static func acceptLoop(_ fd: Int32,
                                   handler: @escaping @Sendable (ControlRequest) -> ControlResponse) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                // `continue` on everything was two bugs in one line. A fatal error (the
                // descriptor is gone) spun this thread against a dead socket forever, burning
                // a core on a battery app; and it did it silently, so the daemon went on
                // looking healthy while nothing could reach it. Transient errors are retried,
                // anything else ends the loop and leaves `isListening` to report the truth.
                switch errno {
                case EINTR, ECONNABORTED, EAGAIN, EMFILE, ENFILE:
                    continue
                default:
                    HelperLog.error("accept failed (\(errno)); listener is down")
                    return
                }
            }
            guard peerIsAuthorized(client) else {
                HelperLog.info("refused a control connection from another user")
                close(client)
                continue
            }
            // A client that connects and never finishes its line used to hold this loop,
            // and with it every other client, indefinitely. The app writes its request the
            // moment it connects, so a short read bound costs nothing.
            setTimeouts(client, seconds: 2)
            guard let request = readLine(client) else { close(client); continue }
            if request == probeLine {
                _ = "\"pong\"\n".withCString { write(client, $0, strlen($0)) }
                close(client)
                continue
            }
            // Served off this thread so a handler waiting on the daemon's lock doesn't stop
            // the listener accepting. One serial queue, in accept order: the app sends whole
            // configs, and two of them applied out of order would undo the newer edit.
            handlerQueue.async {
                respond(client, to: request, handler: handler)
                close(client)
            }
        }
    }

    /// The health probe's request. Answered on the accept thread without the daemon's lock;
    /// never sent by the app.
    private static let probeLine = Data("\"ping\"".utf8)

    private static let handlerQueue = DispatchQueue(label: "com.battlify.helper.control")

    private static func setTimeouts(_ fd: Int32, seconds: Int) {
        var tv = timeval(tv_sec: seconds, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    }

    /// Whether the process on the other end may command this daemon.
    ///
    /// The socket is world-writable by necessity (see `start`), so without this any local
    /// process — any user, any sandboxed thing that can reach /var/run — could stop the
    /// battery charging, hold the machine awake, or drive the fans, all as root. `getpeereid`
    /// asks the kernel for the peer's real uid, which the client cannot forge.
    ///
    /// Root is allowed because that's the CLI and our own tooling. Beyond that only the
    /// console owner — the person actually logged in at the screen — which is who the GUI
    /// runs as. Another logged-out user's background process is not that.
    private static func peerIsAuthorized(_ fd: Int32) -> Bool {
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(fd, &uid, &gid) == 0 else { return false }
        if uid == 0 { return true }
        var info = stat()
        guard stat("/dev/console", &info) == 0 else { return false }
        return uid == info.st_uid
    }

    private static func respond(_ fd: Int32, to reqData: Data,
                                handler: (ControlRequest) -> ControlResponse) {
        let resp: ControlResponse
        if let req = try? JSONDecoder().decode(ControlRequest.self, from: reqData) {
            resp = handler(req)
        } else {
            // reply anyway so a version-skewed client sees an error, not a hang
            resp = ControlResponse(
                ok: false, config: .default, batteryPercent: 0,
                chargingEnabled: false, schemeDescription: "",
                message: "unrecognized request")
        }

        guard var out = try? JSONEncoder().encode(resp) else { return }
        out.append(0x0A)
        _ = out.withUnsafeBytes { raw -> Int in
            write(fd, raw.baseAddress, raw.count)
        }
    }

    private static func readLine(_ fd: Int32) -> Data? {
        var out = Data()
        var byte: UInt8 = 0
        while true {
            let n = read(fd, &byte, 1)
            if n == 0 { break }
            if n < 0 { return nil }
            if byte == 0x0A { break }
            out.append(byte)
        }
        return out.isEmpty ? nil : out
    }
}
