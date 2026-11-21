import Foundation

/// How the MagSafe charge LED should behave.
public enum MagSafeLEDMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// macOS controls the LED (default — eWiz doesn't touch it).
    case system
    /// Reflect charge status: orange charging, green holding, off during the post-wake settling window.
    case status
    case off

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Auto"
        case .status: return "Status"
        case .off:    return "Off"
        }
    }
}

/// Persistent settings shared between the GUI (writer) and root daemon (reader).
/// Stored as JSON at a system-wide path so the daemon can read it for any logged-in user.
public struct EWizConfig: Codable, Equatable, Sendable {
    public var chargeLimitEnabled: Bool
    /// Upper charge threshold (%); charging stops at/above this.
    public var chargeLimit: Int
    /// Hysteresis: charging resumes below (chargeLimit - resumeMargin), avoiding toggle thrash.
    public var resumeMargin: Int
    /// Pause charging when the battery is too warm (heat accelerates wear).
    public var heatAwareEnabled: Bool
    /// Temperature (°C) at/above which charging pauses.
    public var maxChargeTempC: Double
    /// Legacy LED flag, kept for older daemon/GUI compat; `magSafeLedMode` is authoritative.
    public var magSafeLedEnabled: Bool
    public var magSafeLedMode: MagSafeLEDMode

    /// Force-discharge (run off battery while plugged) to bring the level down to the limit.
    public var dischargeEnabled: Bool
    /// "Don't charge while plugged in": run the Mac off the adapter and leave the battery
    /// exactly where it is, whatever the level or the limit. Overrides everything except
    /// an explicit pause — a level of hold no other setting expresses, since the limit
    /// still charges *up to* its ceiling and a schedule only holds inside its window.
    public var holdCharge: Bool
    /// Cut charging before sleep so macOS can't top up past the limit while the daemon is frozen.
    public var disableChargingBeforeSleep: Bool
    /// Hold a power assertion (while plugged) so idle-sleep can't interrupt limit enforcement.
    public var preventIdleSleep: Bool
    /// "Always Active": keep the Mac awake with the lid closed (`pmset disablesleep`).
    /// AC-only by default — auto-releases when unplugged (a closed Mac awake on battery
    /// runs hot and drains fast) unless `keepAwakeOnBattery` is set.
    public var keepAwake: Bool
    /// Opt-in: also keep awake with the lid closed on battery. Off by default (drains
    /// fast, runs hot); the `keepAwakeMaxTempC` guardrail still applies.
    public var keepAwakeOnBattery: Bool
    /// When true, keep-awake holds only while a matching task runs (see
    /// `keepAwakeProcesses` / `keepAwakeMinCpu`); when false, it holds until turned off.
    public var keepAwakeRequiresTask: Bool
    /// Process names (case-insensitive substring match) that keep the Mac awake, e.g. ["ffmpeg", "npm"].
    public var keepAwakeProcesses: [String]
    /// If > 0, any process using ≥ this %CPU also counts as "busy" (0 = names only).
    public var keepAwakeMinCpu: Double
    /// Thermal guardrail: release keep-awake at/above this °C to protect a closed Mac. 0 = off.
    public var keepAwakeMaxTempC: Double
    /// When task-gated keep-awake is on, actively put the Mac to sleep once the
    /// matching task finishes (instead of only releasing the hold and waiting for
    /// idle sleep). Lets an overnight build/download finish and then sleep right away.
    public var sleepWhenTaskDone: Bool
    /// Recurring windows that switch keep-awake on and off on a weekly timetable.
    /// While at least one is enabled, keep-awake holds only inside a window; with none
    /// enabled the `keepAwake` toggle alone decides.
    public var keepAwakeSchedules: [AwakeSchedule]
    /// Auto-off deadline for keep-awake ("keep awake for 2 hours"). Once it passes the
    /// daemon clears this *and* `keepAwake`, so the Mac can't be stranded awake by a
    /// timer nobody is watching. nil = no timer.
    public var keepAwakeUntil: Date?

    /// Recurring charging windows (charge/hold/discharge on a weekly timetable).
    public var schedules: [ChargeSchedule]
    /// Once-daily "ready by" top-up target.
    public var readyBy: ReadyByTarget
    /// Legacy gentle-charging on/off flag; superseded by `chargePower` (kept in sync
    /// for older daemons).
    public var slowCharge: Bool
    /// Charge power 0–100% of full rate via duty-cycling the on/off switch (the hardware
    /// has no current dial, so it's an average). 100 = full rate; 0 = hold.
    public var chargePower: Int
    /// One-shot calibration: ignore the limit, charge to 100%, then auto-clear. Gives
    /// the battery an occasional full cycle.
    public var calibrateToFull: Bool
    /// Charging paused until this time (nil = not paused; distantFuture = until resumed).
    public var pauseUntil: Date?
    /// Sealed Sleep: power memory down when the lid shuts, and switch off everything that
    /// would wake the Mac while it is. See `SealedSleep` for what that buys and what it costs.
    public var sealedSleep: Bool
    /// Keep instant wake: seal everything *except* memory. See `SealedSleep.fastWakeIsDefault`.
    public var sealedSleepFastWake: Bool
    /// The pmset settings Sealed Sleep displaced, held for its exit. Non-nil only while it
    /// is on; see `SealedSleepRestore`.
    /// Minutes of closed-lid sleep before instant wake hands over to hibernation.
    /// 0 never hands over. Only consulted while Sealed Sleep and fast wake are both on.
    public var sealedSleepHibernateAfter: Int
    public var sealedSleepRestore: SealedSleepRestore?
    public var mode: SaveMode
    /// Settings Extreme Performance took over, held for its exit. Non-nil only while a
    /// performance mode is active; see `PerformanceRestore`.
    public var performanceRestore: PerformanceRestore?

    public init(chargeLimitEnabled: Bool = false,
                chargeLimit: Int = 80,
                resumeMargin: Int = 5,
                heatAwareEnabled: Bool = false,
                maxChargeTempC: Double = 35.0,
                magSafeLedEnabled: Bool = false,
                magSafeLedMode: MagSafeLEDMode? = nil,
                dischargeEnabled: Bool = false,
                holdCharge: Bool = false,
                disableChargingBeforeSleep: Bool = false,
                preventIdleSleep: Bool = false,
                keepAwake: Bool = false,
                keepAwakeOnBattery: Bool = false,
                keepAwakeRequiresTask: Bool = false,
                keepAwakeProcesses: [String] = [],
                keepAwakeMinCpu: Double = 0,
                keepAwakeMaxTempC: Double = 0,
                sleepWhenTaskDone: Bool = false,
                keepAwakeSchedules: [AwakeSchedule] = [],
                keepAwakeUntil: Date? = nil,
                schedules: [ChargeSchedule] = [],
                readyBy: ReadyByTarget = ReadyByTarget(),
                slowCharge: Bool = false,
                chargePower: Int = 100,
                calibrateToFull: Bool = false,
                pauseUntil: Date? = nil,
                sealedSleep: Bool = false,
                sealedSleepFastWake: Bool = SealedSleep.fastWakeIsDefault,
                sealedSleepHibernateAfter: Int = 20,
                sealedSleepRestore: SealedSleepRestore? = nil,
                mode: SaveMode = .off,
                performanceRestore: PerformanceRestore? = nil) {
        self.chargeLimitEnabled = chargeLimitEnabled
        self.chargeLimit = chargeLimit
        self.resumeMargin = resumeMargin
        self.heatAwareEnabled = heatAwareEnabled
        self.maxChargeTempC = maxChargeTempC
        self.magSafeLedEnabled = magSafeLedEnabled
        // New installs default to Status; older configs migrate from the legacy flag
        // in `init(from:)`.
        self.magSafeLedMode = magSafeLedMode ?? .status
        self.dischargeEnabled = dischargeEnabled
        self.holdCharge = holdCharge
        self.disableChargingBeforeSleep = disableChargingBeforeSleep
        self.preventIdleSleep = preventIdleSleep
        self.keepAwake = keepAwake
        self.keepAwakeOnBattery = keepAwakeOnBattery
        self.keepAwakeRequiresTask = keepAwakeRequiresTask
        self.keepAwakeProcesses = keepAwakeProcesses
        self.keepAwakeMinCpu = keepAwakeMinCpu
        self.keepAwakeMaxTempC = keepAwakeMaxTempC
        self.sleepWhenTaskDone = sleepWhenTaskDone
        self.keepAwakeSchedules = keepAwakeSchedules
        self.keepAwakeUntil = keepAwakeUntil
        self.schedules = schedules
        self.readyBy = readyBy
        self.slowCharge = slowCharge
        self.chargePower = min(100, max(0, chargePower))
        self.calibrateToFull = calibrateToFull
        self.pauseUntil = pauseUntil
        self.sealedSleep = sealedSleep
        self.sealedSleepFastWake = sealedSleepFastWake
        self.sealedSleepHibernateAfter = sealedSleepHibernateAfter
        self.sealedSleepRestore = sealedSleepRestore
        self.mode = mode
        self.performanceRestore = performanceRestore
    }

    public static let `default` = EWizConfig()

    /// Keys that no longer have a property, read only to migrate what they meant.
    private enum LegacyKeys: String, CodingKey {
        /// The "Normal"/"Deep" sleep-depth picker Sealed Sleep replaced.
        case sleepDepth
    }

    // Version-tolerant decoding: missing keys fall back to defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        chargeLimitEnabled = try c.decodeIfPresent(Bool.self, forKey: .chargeLimitEnabled) ?? false
        chargeLimit = try c.decodeIfPresent(Int.self, forKey: .chargeLimit) ?? 80
        resumeMargin = try c.decodeIfPresent(Int.self, forKey: .resumeMargin) ?? 5
        heatAwareEnabled = try c.decodeIfPresent(Bool.self, forKey: .heatAwareEnabled) ?? false
        maxChargeTempC = try c.decodeIfPresent(Double.self, forKey: .maxChargeTempC) ?? 35.0
        magSafeLedEnabled = try c.decodeIfPresent(Bool.self, forKey: .magSafeLedEnabled) ?? false
        // Migrate: if the mode key is missing (older config), derive it from the flag.
        magSafeLedMode = try c.decodeIfPresent(MagSafeLEDMode.self, forKey: .magSafeLedMode)
            ?? (magSafeLedEnabled ? .status : .system)
        dischargeEnabled = try c.decodeIfPresent(Bool.self, forKey: .dischargeEnabled) ?? false
        holdCharge = try c.decodeIfPresent(Bool.self, forKey: .holdCharge) ?? false
        disableChargingBeforeSleep = try c.decodeIfPresent(Bool.self, forKey: .disableChargingBeforeSleep) ?? false
        preventIdleSleep = try c.decodeIfPresent(Bool.self, forKey: .preventIdleSleep) ?? false
        keepAwake = try c.decodeIfPresent(Bool.self, forKey: .keepAwake) ?? false
        keepAwakeOnBattery = try c.decodeIfPresent(Bool.self, forKey: .keepAwakeOnBattery) ?? false
        keepAwakeRequiresTask = try c.decodeIfPresent(Bool.self, forKey: .keepAwakeRequiresTask) ?? false
        keepAwakeProcesses = try c.decodeIfPresent([String].self, forKey: .keepAwakeProcesses) ?? []
        keepAwakeMinCpu = try c.decodeIfPresent(Double.self, forKey: .keepAwakeMinCpu) ?? 0
        keepAwakeMaxTempC = try c.decodeIfPresent(Double.self, forKey: .keepAwakeMaxTempC) ?? 0
        sleepWhenTaskDone = try c.decodeIfPresent(Bool.self, forKey: .sleepWhenTaskDone) ?? false
        keepAwakeSchedules = try c.decodeIfPresent([AwakeSchedule].self, forKey: .keepAwakeSchedules) ?? []
        keepAwakeUntil = try c.decodeIfPresent(Date.self, forKey: .keepAwakeUntil)
        schedules = try c.decodeIfPresent([ChargeSchedule].self, forKey: .schedules) ?? []
        readyBy = try c.decodeIfPresent(ReadyByTarget.self, forKey: .readyBy) ?? ReadyByTarget()
        slowCharge = try c.decodeIfPresent(Bool.self, forKey: .slowCharge) ?? false
        // Migrate: configs predating `chargePower` map the legacy on/off flag to
        // 50% (the old Gentle-charging average); otherwise full power.
        chargePower = min(100, max(0, try c.decodeIfPresent(Int.self, forKey: .chargePower)
            ?? (slowCharge ? 50 : 100)))
        calibrateToFull = try c.decodeIfPresent(Bool.self, forKey: .calibrateToFull) ?? false
        pauseUntil = try c.decodeIfPresent(Date.self, forKey: .pauseUntil)
        // Migrate: the Normal/Deep "sleep depth" picker this replaced wrote the same
        // hibernatemode, so anyone who had chosen Deep was already asking for Sealed Sleep
        // and keeps it. The old key has no property left to synthesise a case for, hence
        // the second container.
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        sealedSleep = try c.decodeIfPresent(Bool.self, forKey: .sealedSleep)
            ?? (try legacy.decodeIfPresent(String.self, forKey: .sleepDepth) == "deep")
        // Absent in configs written before the choice existed. Those were all hibernating,
        // so they keep hibernating — changing what someone's Mac does on upgrade, silently,
        // is worse than leaving them on the slower setting until they pick.
        sealedSleepFastWake = try c.decodeIfPresent(Bool.self, forKey: .sealedSleepFastWake)
            ?? (try c.decodeIfPresent(Bool.self, forKey: .sealedSleep) == true ? false
                                                                              : SealedSleep.fastWakeIsDefault)
        sealedSleepHibernateAfter = try c.decodeIfPresent(Int.self, forKey: .sealedSleepHibernateAfter) ?? 20
        sealedSleepRestore = try c.decodeIfPresent(SealedSleepRestore.self, forKey: .sealedSleepRestore)
        // Older configs still carry `fanMode`, `fanAutoAboveTempC` and the older
        // `fanBoost*` keys from the fan control that used to live here. Unknown keys are
        // ignored, so they load fine and the next save drops them.
        mode = try c.decodeIfPresent(SaveMode.self, forKey: .mode) ?? .off
        performanceRestore = try c.decodeIfPresent(PerformanceRestore.self, forKey: .performanceRestore)
    }

    // MARK: - Keep-awake gating

    /// The keep-awake timetable: true when a window is open now, or when there are no
    /// enabled windows at all (then the toggle alone decides — having added no schedule
    /// must not silently disable the feature).
    ///
    /// Static so the GUI can ask the same question of its own published values without
    /// assembling a whole config, keeping one definition of "is a window open".
    public static func keepAwakeWindowOpen(_ schedules: [AwakeSchedule],
                                          at date: Date = Date(),
                                          calendar: Calendar = .current) -> Bool {
        let armed = schedules.filter(\.enabled)
        return armed.isEmpty || armed.contains { $0.isActive(at: date, calendar: calendar) }
    }

    /// Whether "Always Active" should be holding right now, ignoring the power, task
    /// and heat gates the daemon layers on top: the toggle is on, any auto-off timer
    /// hasn't run out, and the timetable allows it.
    public static func keepAwakeArmed(enabled: Bool,
                                      until: Date?,
                                      schedules: [AwakeSchedule],
                                      at date: Date = Date(),
                                      calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        if let until, date >= until { return false }
        return keepAwakeWindowOpen(schedules, at: date, calendar: calendar)
    }

    public func keepAwakeWindowOpen(at date: Date = Date(),
                                    calendar: Calendar = .current) -> Bool {
        Self.keepAwakeWindowOpen(keepAwakeSchedules, at: date, calendar: calendar)
    }

    /// Used by the daemon each tick, and by the GUI so the menu bar and the clamshell
    /// display saver agree with what is actually being enforced.
    public func keepAwakeArmed(at date: Date = Date(),
                               calendar: Calendar = .current) -> Bool {
        Self.keepAwakeArmed(enabled: keepAwake, until: keepAwakeUntil,
                            schedules: keepAwakeSchedules, at: date, calendar: calendar)
    }
}

public enum EWizPaths {
    /// System-wide config dir under /Library for daemon visibility. Made writable by
    /// the GUI via the installer (or the helper).
    public static let configDirectory =
        URL(fileURLWithPath: "/Library/Application Support/eWiz", isDirectory: true)

    public static let configFile =
        configDirectory.appendingPathComponent("config.json")

    /// Where the root daemon appends periodic battery samples.
    public static let historyFile =
        configDirectory.appendingPathComponent("history.jsonl")

    /// Per-user config dir, used when the GUI records history itself (no root daemon).
    public static var userConfigDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/eWiz", isDirectory: true)
    }

    public static var userHistoryFile: URL {
        userConfigDirectory.appendingPathComponent("history.jsonl")
    }
}

public enum ConfigStore {
    public static func load() -> EWizConfig {
        guard let data = try? Data(contentsOf: EWizPaths.configFile),
              let cfg = try? JSONDecoder().decode(EWizConfig.self, from: data)
        else { return .default }
        return cfg
    }

    /// Write the config. Throws if the directory isn't writable by this process.
    public static func save(_ config: EWizConfig) throws {
        try FileManager.default.createDirectory(
            at: EWizPaths.configDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: EWizPaths.configFile, options: .atomic)
    }
}
