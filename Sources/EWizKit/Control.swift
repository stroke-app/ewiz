import Foundation

/// Control protocol between the GUI (client) and the root daemon (server),
/// spoken over a Unix domain socket as newline-delimited JSON.

/// System sleep/idle power features that drain battery while the lid is closed.
/// Raw values are the matching `pmset` keys.
public enum PowerToggle: String, Codable, Sendable, CaseIterable {
    case powerNap = "powernap"
    case wakeOnNetwork = "womp"
    case tcpKeepAlive = "tcpkeepalive"
    case dimOnBattery = "lessbright"
    /// Wakes when an iPhone/Watch comes near. In a bag that fires over and over.
    case proximityWake = "proximitywake"
    /// Blocks sleep outright while a terminal/SSH session is alive — the classic
    /// "why was my Mac hot and empty in my bag".
    case ttysKeepAwake = "ttyskeepawake"

    /// Where a toggle belongs in the UI.
    public enum Category: Sendable {
        case sleepWake       // features that keep the Mac busy during sleep
        case batteryOptions  // macOS "Battery > Options" style tweaks
    }

    /// Which pmset power source this toggle applies to.
    public enum Scope: String, Sendable {
        case all = "-a"
        case battery = "-b"
        case ac = "-c"
    }

    public var category: Category {
        switch self {
        case .powerNap, .wakeOnNetwork, .tcpKeepAlive, .proximityWake, .ttysKeepAwake:
            return .sleepWake
        case .dimOnBattery: return .batteryOptions
        }
    }

    /// `dimOnBattery` is battery-only (`-b`); the rest apply to all sources.
    public var scope: Scope {
        switch self {
        case .dimOnBattery: return .battery
        default: return .all
        }
    }

    public var title: String {
        switch self {
        case .powerNap: return "Power Nap"
        case .wakeOnNetwork: return "Wake for network access"
        case .tcpKeepAlive: return "Keep network alive in sleep"
        case .dimOnBattery: return "Slightly dim the display on battery"
        case .proximityWake: return "Wake when a nearby device is close"
        case .ttysKeepAwake: return "Stay awake for terminal sessions"
        }
    }

    public var hint: String {
        switch self {
        case .powerNap: return "Wakes periodically while closed to sync Mail/iCloud"
        case .wakeOnNetwork: return "Lets other devices wake this Mac over the network"
        case .tcpKeepAlive: return "Keeps Find My & push active during sleep"
        case .dimOnBattery: return "Lowers brightness a little when unplugged to stretch battery life"
        case .proximityWake: return "Lets an iPhone or Watch nearby wake this Mac, over and over in a bag"
        case .ttysKeepAwake: return "Keeps the Mac fully awake while any terminal or SSH session is open"
        }
    }
}

public enum ControlRequest: Codable, Sendable {
    case getStatus
    case setConfig(EWizConfig)
    case setLowPowerMode(Bool)
    case setPowerToggle(PowerToggle, Bool)
    case applyMode(SaveMode)
    /// Pause charging: minutes > 0 = for that long; 0 = resume now;
    /// -1 = pause indefinitely until resumed.
    case pauseCharging(Int)
    /// The Mac is about to sleep — cut charging now if configured to.
    case prepareForSleep
    /// Start (true) or cancel (false) a one-shot charge-to-100% calibration.
    case calibrateToFull(Bool)
    /// Turn Sealed Sleep on or off. Its own request rather than a config write because the
    /// daemon has to snapshot what it displaces on the way in and put it back on the way
    /// out, and a plain config save has no transition to hang that on.
    case setSealedSleep(Bool)
    /// Choose instant wake vs hibernation while sealed. Re-applies if Sealed Sleep is on.
    case setSealedSleepFastWake(Bool)
    /// Delete the daemon-written history file. The GUI can't (root-owned dir), so it
    /// asks the daemon.
    case clearSamples
    /// Replace the daemon's own binary with the one at this path and restart onto it, so a
    /// legacy `/usr/local/bin` install can take a new build without an administrator prompt.
    /// Honoured only when both binaries carry the same Developer ID team — see `HelperUpdate`.
    case installUpdate(path: String)
}

public struct ControlResponse: Codable, Sendable {
    public var ok: Bool
    public var config: EWizConfig
    public var batteryPercent: Int
    public var chargingEnabled: Bool
    public var schemeDescription: String
    public var lowPowerModeEnabled: Bool
    /// Current state of each PowerToggle, keyed by its raw pmset key.
    public var powerToggles: [String: Bool]
    /// Why charging is paused: "limit", "heat", "paused", or nil.
    public var pauseReason: String?
    public var magSafeSupported: Bool
    public var dischargeSupported: Bool
    public var discharging: Bool
    /// Temperature sensors, warmest first.
    public var sensors: [SensorReading]
    /// Live `hibernatemode`. nil from a Mac that does not expose the key, or an older daemon.
    public var hibernateMode: Int?
    /// Live `standby`, same caveat.
    public var standbyEnabled: Bool?
    /// pmset keys the last Sealed Sleep write asked for and did not get. Empty is the
    /// normal case; a name in here means this Mac refused that particular setting.
    public var sealedSleepRefused: [String]
    /// Whether this Mac exposes macOS High Power Mode at all (Max-chip MacBook Pros and
    /// the desktops). False from an older daemon, which is the safe reading: the app then
    /// doesn't promise a switch that isn't there.
    public var highPowerModeSupported: Bool
    /// Whether High Power Mode is on right now.
    public var highPowerModeEnabled: Bool
    /// The steps macOS's own charge limit offers, when this Mac limits through it because
    /// its SMC charge keys are gated. Empty on a Mac with a real key, and from an older daemon.
    public var nativeLimitSteps: [Int]
    /// The step eWiz currently has macOS enforcing, nil when none.
    public var nativeLimitApplied: Int?
    /// Whether this Mac has an SMC charge-inhibit key. Charge Power duty-cycles that key,
    /// so without one it can do nothing. An older daemon omits it and reads as true, which
    /// is what it would have claimed anyway.
    public var chargeControlSupported: Bool
    public var message: String?
    /// Protocol version of the responding daemon. Older daemons omit it → decode to 0 → outdated.
    public var daemonProtocolVersion: Int
    /// Behaviour/build version of the daemon (see `HelperBuild`). Lets the GUI update a
    /// helper that's protocol-current but behaviour-stale. Older daemons decode to 0.
    public var daemonBuildVersion: Int

    public init(ok: Bool, config: EWizConfig, batteryPercent: Int,
                chargingEnabled: Bool, schemeDescription: String,
                lowPowerModeEnabled: Bool = false,
                powerToggles: [String: Bool] = [:],
                pauseReason: String? = nil, magSafeSupported: Bool = false,
                dischargeSupported: Bool = false, discharging: Bool = false,
                sensors: [SensorReading] = [],
                hibernateMode: Int? = nil,
                standbyEnabled: Bool? = nil,
                sealedSleepRefused: [String] = [],
                highPowerModeSupported: Bool = false,
                highPowerModeEnabled: Bool = false,
                nativeLimitSteps: [Int] = [],
                nativeLimitApplied: Int? = nil,
                chargeControlSupported: Bool = true,
                message: String? = nil,
                daemonProtocolVersion: Int = ControlProtocol.version,
                daemonBuildVersion: Int = HelperBuild.version) {
        self.ok = ok
        self.config = config
        self.batteryPercent = batteryPercent
        self.chargingEnabled = chargingEnabled
        self.schemeDescription = schemeDescription
        self.lowPowerModeEnabled = lowPowerModeEnabled
        self.powerToggles = powerToggles
        self.pauseReason = pauseReason
        self.magSafeSupported = magSafeSupported
        self.dischargeSupported = dischargeSupported
        self.discharging = discharging
        self.sensors = sensors
        self.hibernateMode = hibernateMode
        self.standbyEnabled = standbyEnabled
        self.sealedSleepRefused = sealedSleepRefused
        self.highPowerModeSupported = highPowerModeSupported
        self.highPowerModeEnabled = highPowerModeEnabled
        self.nativeLimitSteps = nativeLimitSteps
        self.nativeLimitApplied = nativeLimitApplied
        self.chargeControlSupported = chargeControlSupported
        self.message = message
        self.daemonProtocolVersion = daemonProtocolVersion
        self.daemonBuildVersion = daemonBuildVersion
    }

    // Version-tolerant decoding: missing newer fields fall back to defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        config = try c.decodeIfPresent(EWizConfig.self, forKey: .config) ?? .default
        batteryPercent = try c.decodeIfPresent(Int.self, forKey: .batteryPercent) ?? 0
        chargingEnabled = try c.decodeIfPresent(Bool.self, forKey: .chargingEnabled) ?? false
        schemeDescription = try c.decodeIfPresent(String.self, forKey: .schemeDescription) ?? ""
        lowPowerModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .lowPowerModeEnabled) ?? false
        powerToggles = try c.decodeIfPresent([String: Bool].self, forKey: .powerToggles) ?? [:]
        pauseReason = try c.decodeIfPresent(String.self, forKey: .pauseReason)
        magSafeSupported = try c.decodeIfPresent(Bool.self, forKey: .magSafeSupported) ?? false
        dischargeSupported = try c.decodeIfPresent(Bool.self, forKey: .dischargeSupported) ?? false
        discharging = try c.decodeIfPresent(Bool.self, forKey: .discharging) ?? false
        sensors = try c.decodeIfPresent([SensorReading].self, forKey: .sensors) ?? []
        hibernateMode = try c.decodeIfPresent(Int.self, forKey: .hibernateMode)
        standbyEnabled = try c.decodeIfPresent(Bool.self, forKey: .standbyEnabled)
        sealedSleepRefused = try c.decodeIfPresent([String].self, forKey: .sealedSleepRefused) ?? []
        highPowerModeSupported = try c.decodeIfPresent(Bool.self, forKey: .highPowerModeSupported) ?? false
        highPowerModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .highPowerModeEnabled) ?? false
        nativeLimitSteps = try c.decodeIfPresent([Int].self, forKey: .nativeLimitSteps) ?? []
        nativeLimitApplied = try c.decodeIfPresent(Int.self, forKey: .nativeLimitApplied)
        chargeControlSupported = try c.decodeIfPresent(Bool.self, forKey: .chargeControlSupported) ?? true
        message = try c.decodeIfPresent(String.self, forKey: .message)
        daemonProtocolVersion = try c.decodeIfPresent(Int.self, forKey: .daemonProtocolVersion) ?? 0
        daemonBuildVersion = try c.decodeIfPresent(Int.self, forKey: .daemonBuildVersion) ?? 0
    }
}

public enum ControlSocket {
    public static let path = "/var/run/ewiz.sock"
}

public enum ControlProtocol {
    /// Bumped when the request/response contract gains something the daemon must
    /// understand; the GUI warns when the installed helper reports an older version.
    ///   v2: added `pauseCharging`.
    ///   v3: MagSafe LED mode (Auto/Status/Off) + post-wake settling.
    ///   v4: prepareForSleep, calibrateToFull, prevent-idle-sleep.
    ///   v5: clearSamples (delete the daemon-written history file).
    ///   v6: installUpdate — the daemon can replace its own signed binary on request, which
    ///       is how a helper update stops costing an admin prompt. The app must know whether
    ///       the installed helper understands this before it offers the quiet path.
    ///   v7: the Extreme Performance mode. This one has to be gated: `applyMode` carries a
    ///       `SaveMode` the old daemon has never heard of, and an unknown enum case fails
    ///       the whole request decode — the daemon wouldn't apply a weaker version of the
    ///       mode, it would drop the request on the floor.
    // Note: the dim-on-battery toggle is a plain additive pmset write — an older
    // helper simply ignores an unknown toggle, so it doesn't warrant a version
    // bump or an "outdated helper" warning.
    public static let version = 7
}

public enum HelperBuild {
    /// Bumped when the daemon's *behaviour* changes enough to warrant updating an
    /// installed helper even though the protocol is unchanged (see `ChargeLimitStore.helperOutdated`).
    ///   v1: gentle 2-min charge-power duty cycle (replaces the 10s toggle that
    ///       flickered the charge indicators), + shutdown/perf hardening.
    ///   v2: fix force-discharge oscillation — gate discharge/LED/keep-awake on
    ///       physical adapter presence (raw SMC AC-W, falling back to IOKit's
    ///       ExternalConnected) instead of the providing-source flag, which flips
    ///       to "battery" while discharging.
    ///   v5: fan boost removed — SMC fan writes are refused on Apple silicon, so an
    ///       installed helper still running the fan policy must be replaced.
    ///   v6: idle back-off — the enforcement loop drops to a slow tick once the lid is
    ///       shut on battery, so it stops doing work inside maintenance dark wakes.
    ///   v7: the daemon registers for sleep itself and cuts charging on the way down
    ///       whenever a limit is enforced. An installed v6 helper only cuts when the GUI
    ///       asks and the option is ticked, so it lets the battery charge past the limit
    ///       to full while the Mac sleeps — it has to be replaced, not just re-run.
    ///       Also adds the "don't charge while plugged in" hold and its amber LED.
    ///   v8: fan control, and — the reason this must reach every install — a v8 helper hands
    ///       fans back to macOS whenever the config says auto but the SMC says forced. Forced
    ///       mode persists across reboots, so a Mac left pinned by the removed fan-boost
    ///       feature stays pinned until a helper that knows to undo it runs.
    ///   v9: the v8 fan code read `F<i>Md != 0` as "forced" — an M3 Pro reports 3 with macOS
    ///       in charge — so it wrote the key every tick, failed, and logged an error every
    ///       few seconds while fighting a controller that wasn't there. v9 writes nothing
    ///       unless a manual speed is set, latches a refusal instead of retrying, and reports
    ///       fan-write support and temperature sensors to the app.
    ///   v10: a daemon that can't serve its control socket now exits instead of running deaf.
    ///        One install left a helper alive and listening on an inode whose path a
    ///        short-lived second instance had replaced: launchd reported the job healthy while
    ///        every app request got "connection refused", so the app hung. Bind failures are
    ///        fatal, and the tick loop exits if the path stops pointing at our own socket.
    ///   v11: the installer now evicts the old `com.battpie.helper` daemon left behind by the
    ///        rename. Both daemons ran with KeepAlive and drove the same SMC charge keys on
    ///        their own timers, so they overwrote each other; when the orphan won a tick while
    ///        holding the charge inhibit, the Mac drained to empty on the charger. This bump
    ///        is the whole point of the fix — the eviction only runs when an install runs.
    ///   v12: Extreme Performance — High Power Mode, a fan floor, no charge limit and no
    ///        idle sleep, applied and unwound as one unit. A v11 helper can't parse the
    ///        mode at all, and it's also the helper that would have to *undo* the fan
    ///        floor on the way out: leaving that to an older build is how a Mac ends up
    ///        with its fans pinned after the mode is switched off (see v8).
    ///   v13: Extreme Performance now snapshots what it displaces (`PerformanceRestore`) and
    ///        puts it back on exit. A v12 helper applies the mode but keeps no snapshot, so
    ///        leaving it discards a hand-set fan speed and any gentle-charging setting —
    ///        and it's the daemon, not the app, that owns that state.
    ///   v14: fan control stopped disabling itself. A v13 helper latched "this Mac refuses
    ///        fan writes" off any failed write, including `restoreAuto()` — housekeeping that
    ///        runs on shutdown, on the heat guard and every time anyone picks Auto. On a Mac
    ///        where nothing was ever forced, the SMC refusing that redundant write left the
    ///        Custom control greyed out for the rest of the daemon's life, explaining that the
    ///        hardware couldn't do something nobody had asked it to do. Only a write the user
    ///        asked for latches now, and `restoreAuto()` skips fans that aren't forced.
    ///   v15: fan writes are verified by reading the key back. Apple silicon returns success
    ///        for `F<i>Md = 1` and leaves it reading 0, so a v14 helper believed it had taken
    ///        the fans over, reported control as working, and held a Custom speed the
    ///        hardware had never accepted. v15 checks, and says so when the answer is no.
    ///   v16: fan control is gone, and the removal is the reason this must ship. A v15
    ///        helper still enforces whatever `fanMode` the old config holds, and it is also
    ///        the only thing that can undo a fan left forced — the SMC keeps forced mode
    ///        across a restart. v16 hands every forced fan back to macOS on startup and
    ///        then never touches them again. It also owns closed-lid sleep: hibernation,
    ///        the sleep/wake toggles and the radios are applied as one verified unit
    ///        (`SealedSleep`), which a v15 helper cannot parse at all.
    ///   v17: "prevent idle sleep" is no longer gated on the charge limit being on. A v16
    ///        helper ANDed the two, so Extreme Performance — which asks for no idle sleep
    ///        and deliberately turns the limit off — could never hold the assertion, and a
    ///        Mac left on a long render idled out from under it. Only the daemon holds that
    ///        assertion, so the fix ships with the daemon.
    ///   v18: instant wake now hands over to hibernation once a close outlasts the deferral
    ///        (`DeferredHibernate`). Apple silicon has no `standbydelay`, so the only way to
    ///        get both an instant lid and a flat battery line is for the daemon to book its
    ///        own wake and re-sleep into `hibernatemode 25`. A v17 helper ignores the new
    ///        config key entirely, so the closed-lid drain it was installed to stop stays.
    ///   v19: a daemon could go deaf and stay running. The health check only compared the
    ///        socket path to the inode it bound, which passes while our own listener is no
    ///        longer listening — the socket file sits there refusing every connection, the
    ///        app reports "helper not installed", and nothing enforces the charge limit or
    ///        Sealed Sleep until someone notices. One 23-hour close cost 6% that way. v19
    ///        asks the kernel whether the descriptor is still accepting, rebinds in place
    ///        when it isn't, and only exits if that fails. It also finishes a hibernation
    ///        deferral from the tick loop, because a scheduled dark wake doesn't always
    ///        deliver the wake notification the other half was waiting on.
    ///   v20: v19's health check asked `getsockopt(SO_ACCEPTCONN)`, which Darwin does not
    ///        implement for unix-domain sockets — it fails with ENOPROTOOPT, which reads as
    ///        "not listening", so a v19 daemon rebinds a healthy socket every tick and drops
    ///        whatever was in flight while it does. It checks the descriptor instead, probes
    ///        the socket end to end every two minutes (the only check that can see a dead
    ///        accept loop), and restarts itself if rebinding stops helping.
    ///   v21: the daemon no longer quits on a Mac with no SMC charge-inhibit key. Up to v20
    ///        it exited 3 at startup, launchd respawned it forever, and the app — which only
    ///        knows the helper by its socket — said "Helper not installed" no matter how
    ///        many times you installed it. Everything else the helper owns (Sealed Sleep,
    ///        the sleep/wake toggles, Low Power Mode, Always Active) needs no charge key,
    ///        so v21 runs without one and skips charge enforcement; `schemeDescription`
    ///        already reports "unsupported" for anyone who needs to know.
    ///   v22: working with the lid closed no longer blanks an external display. The hold
    ///        ran `pmset displaysleepnow` on every lid close, and that command takes every
    ///        display with it — so a docked Mac kept running with its monitor dark and no
    ///        input would bring it back. v22 blanks only when the built-in panel is the
    ///        only display it can see.
    ///   v23: "don't charge" and the charge limit now hold on Macs with no charge-inhibit
    ///        key, by cutting the adapter instead. Up to v22 there was nothing to enforce
    ///        them with on that hardware, so the switch read "Held. The battery won't rise"
    ///        while the battery charged past it to full — measured climbing 80% → 85% with
    ///        the hold on. The adapter is the only lever those Macs expose, so the hold
    ///        parks on it: battery while at or above the mark, a short top-up two points
    ///        below.
    ///   v24: docked clamshell holds the display awake. `disablesleep` and the system
    ///        assertion keep the Mac running with the lid shut, but neither stops the
    ///        display idle timer, so after five minutes the external monitor — the only
    ///        screen left — went dark with no obvious way back, and the laptop had to be
    ///        opened again. v24 holds `PreventUserIdleDisplaySleep` while, and only while,
    ///        the lid is shut over an attached monitor.
    ///   v25: three fixes that only a running daemon can carry. Charge control is now
    ///        claimed only for the key set the read/write paths actually use — a Mac with
    ///        one of the two legacy keys and no CHTE advertised charge limiting and then
    ///        failed every SMC call into a `try?`, while `schemeDescription` said
    ///        "unsupported" beside it. The MagSafe hold-blink tracks the hold whatever the
    ///        LED mode is, so switching the light to Status no longer announces a hold that
    ///        engaged hours ago. And every line the helper logs is stamped with the local
    ///        time: the log is the only record of what happened inside a closed lid, and
    ///        four thousand undated sentences answer no question anyone brings to it.
    ///   v26: holding without draining on Macs whose SMC charge keys are gated (macOS 26.7 /
    ///        15.8 firmware). The hold and the limit go through macOS's own charge limit,
    ///        which stops the charge and keeps the Mac on wall power, from 80% up; the
    ///        adapter-cut hold, which ran the Mac off its battery 2% at a time, is kept
    ///        only for Macs with neither. The MagSafe light follows what the battery is
    ///        doing rather than what the daemon intended, and is rewritten every tick and
    ///        again after each power change: macOS repaints it without touching ACLC, so
    ///        the readback said green while the connector showed amber.
    public static let version = 26
}

public enum ControlError: Error, CustomStringConvertible {
    case notConnected          // daemon not running / socket missing
    case ioError(String)
    case decodeError

    public var description: String {
        switch self {
        case .notConnected: return "eWiz helper is not running"
        case .ioError(let s): return "Control I/O error: \(s)"
        case .decodeError: return "Could not decode helper response"
        }
    }
}

/// Synchronous client: connect, send one request, read one response, close.
public enum ControlClient {
    public static func send(_ request: ControlRequest,
                            socketPath: String = ControlSocket.path) throws -> ControlResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlError.ioError("socket() failed") }
        defer { close(fd) }

        // Bound send/recv so a wedged daemon can't hang the caller (some call synchronously).
        var tv = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        guard pathBytes.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw ControlError.ioError("socket path too long")
        }
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
        guard connected == 0 else { throw ControlError.notConnected }

        var line = try JSONEncoder().encode(request)
        line.append(0x0A) // newline
        try writeAll(fd, line)

        let respData = try readLine(fd)
        guard let resp = try? JSONDecoder().decode(ControlResponse.self, from: respData) else {
            throw ControlError.decodeError
        }
        return resp
    }

    private static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { raw in
            var off = 0
            let base = raw.bindMemory(to: UInt8.self).baseAddress!
            while off < data.count {
                let n = write(fd, base + off, data.count - off)
                if n <= 0 { throw ControlError.ioError("write failed") }
                off += n
            }
        }
    }

    private static func readLine(_ fd: Int32) throws -> Data {
        var out = Data()
        var byte: UInt8 = 0
        while true {
            let n = read(fd, &byte, 1)
            if n == 0 { break }            // EOF
            if n < 0 { throw ControlError.ioError("read failed") }
            if byte == 0x0A { break }      // newline terminator
            out.append(byte)
        }
        return out
    }
}
