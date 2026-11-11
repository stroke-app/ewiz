import Foundation
import EWizKit

/// stdout is the protocol stream, and the battery channel writes to it from a timer while
/// the main loop writes replies. One lock keeps each message on its own line.
enum Output {
    private static let lock = NSLock()

    static func write(_ line: String) {
        lock.lock(); defer { lock.unlock() }
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}

/// Pushes low-battery warnings into a Claude Code session as channel events.
///
/// Claude Code registers a channel only from a server that declares
/// `experimental["claude/channel"]`, connects on the pre-2026-07-28 handshake, and is named
/// with `--dangerously-load-development-channels server:ewiz` while channels are in research
/// preview. Anywhere else the notifications are unknown methods, which JSON-RPC clients
/// ignore, so sending them unconditionally costs nothing.
///
/// Starts once the client has initialized; reads the switch and threshold on every check,
/// so changing them in eWiz applies within one interval.
final class BatteryChannel: @unchecked Sendable {
    static let method = "notifications/claude/channel"
    static let interval: TimeInterval = 30

    static let instructions = """
        eWiz also pushes battery warnings into this session as <channel source="ewiz" \
        event="battery_low|battery_critical|charger_connected">. They are one-way: no reply \
        is expected. On battery_low, keep work saved and committed and avoid starting long \
        jobs without telling the user. On battery_critical, save and commit now and wrap up. \
        charger_connected means the warning is over.
        """

    private let queue = DispatchQueue(label: "ewiz.mcp.battery")
    private var timer: DispatchSourceTimer?
    private var tracker = BatteryAlerts.Tracker()
    private let read: @Sendable () -> BatteryAlerts.Reading
    private let send: @Sendable (String) -> Void

    init(read: @escaping @Sendable () -> BatteryAlerts.Reading = BatteryAlerts.currentReading,
         send: @escaping @Sendable (String) -> Void = Output.write) {
        self.read = read
        self.send = send
    }

    /// Idempotent: a second initialize on the same connection doesn't start a second timer.
    func start() {
        queue.async {
            guard self.timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + 1, repeating: Self.interval, leeway: .seconds(1))
            t.setEventHandler { [weak self] in self?.check() }
            t.resume()
            self.timer = t
        }
    }

    private func check() {
        guard BatteryAlerts.isEnabled else {
            tracker = BatteryAlerts.Tracker()   // switched off: start clean if switched back on
            return
        }
        guard let alert = tracker.update(read(), threshold: BatteryAlerts.threshold) else { return }
        send(Self.notification(alert))
    }

    static func notification(_ alert: BatteryAlerts.Alert) -> String {
        let message: [String: Any] = [
            "jsonrpc": "2.0",
            "method": method,
            "params": ["content": alert.text, "meta": ["event": alert.event]],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: message, options: [.withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
