import Foundation

/// A bundle of settings applied together by a save mode. `powerNap`, `wakeOnNetwork`,
/// and `tcpKeepAlive` are *feature* states (true = active/using power), matching pmset.
public struct SaveProfile: Sendable, Equatable {
    public var chargeLimitEnabled: Bool
    public var chargeLimit: Int
    public var heatAwareEnabled: Bool
    public var maxChargeTempC: Double
    public var lowPowerMode: Bool
    public var powerNap: Bool
    public var wakeOnNetwork: Bool
    public var tcpKeepAlive: Bool
    public var wifiOffOnLidClose: Bool
    public var bluetoothOffOnLidClose: Bool
    public var restoreOnWake: Bool
    /// macOS High Power Mode (`pmset highpowermode`). Only a handful of Macs have it —
    /// the Max-chip MacBook Pros and the desktops — so this is a request, not a promise;
    /// see `HighPowerMode.isSupported`.
    public var highPowerMode: Bool
    /// Don't let the Mac idle-sleep out from under a long job.
    public var preventIdleSleep: Bool
    /// Charge at the full hardware rate, overriding gentle charging's duty cycle.
    public var fullChargePower: Bool

    public init(chargeLimitEnabled: Bool, chargeLimit: Int,
                heatAwareEnabled: Bool, maxChargeTempC: Double,
                lowPowerMode: Bool,
                powerNap: Bool, wakeOnNetwork: Bool, tcpKeepAlive: Bool,
                wifiOffOnLidClose: Bool, bluetoothOffOnLidClose: Bool,
                restoreOnWake: Bool,
                highPowerMode: Bool = false,
                preventIdleSleep: Bool = false,
                fullChargePower: Bool = false) {
        self.chargeLimitEnabled = chargeLimitEnabled
        self.chargeLimit = chargeLimit
        self.heatAwareEnabled = heatAwareEnabled
        self.maxChargeTempC = maxChargeTempC
        self.lowPowerMode = lowPowerMode
        self.powerNap = powerNap
        self.wakeOnNetwork = wakeOnNetwork
        self.tcpKeepAlive = tcpKeepAlive
        self.wifiOffOnLidClose = wifiOffOnLidClose
        self.bluetoothOffOnLidClose = bluetoothOffOnLidClose
        self.restoreOnWake = restoreOnWake
        self.highPowerMode = highPowerMode
        self.preventIdleSleep = preventIdleSleep
        self.fullChargePower = fullChargePower
    }
}

/// What Extreme Performance displaced on the way in, so leaving it puts things back.
///
/// Only the settings *unique* to the performance mode are captured. Charge limit and
/// heat-aware charging are deliberately not here: every mode's profile defines those, so
/// whichever mode you switch to owns them, exactly as it did before this mode existed.
/// Restoring them would mean Extreme → Normal quietly ignoring Normal's own charge limit.
///
/// What is here are the levers nothing else touches — gentle charging and the idle-sleep
/// block. Those have no other owner, so without this they would simply be lost: a render
/// mode that quietly forgets the charge rate you set is a settings loss you only notice
/// later, at the wrong moment.
public struct PerformanceRestore: Codable, Sendable, Equatable {
    public var preventIdleSleep: Bool
    public var chargePower: Int
    public var slowCharge: Bool

    public init(preventIdleSleep: Bool, chargePower: Int, slowCharge: Bool) {
        self.preventIdleSleep = preventIdleSleep
        self.chargePower = chargePower
        self.slowCharge = slowCharge
    }
}

public extension EWizConfig {
    /// The config that results from switching to `mode`.
    ///
    /// Pure, and separate from the daemon on purpose: the transition rules — what a
    /// performance mode displaces, what its exit puts back, and what it must not touch on
    /// the way through — are the part of this feature most likely to be quietly wrong, and
    /// this way they can be tested without root, a socket or a real Mac.
    ///
    /// The pmset writes stay with the daemon; this only decides what the settings become.
    func applying(_ mode: SaveMode) -> EWizConfig {
        let p = mode.profile
        let leaving = self.mode
        var cfg = self
        cfg.mode = mode

        // Every mode owns these, and always has.
        cfg.chargeLimitEnabled = p.chargeLimitEnabled
        cfg.chargeLimit = p.chargeLimit
        cfg.heatAwareEnabled = p.heatAwareEnabled
        cfg.maxChargeTempC = p.maxChargeTempC

        // Capture what a performance mode displaces, once, on the way in. Only on the
        // transition: re-applying Extreme while already in it must not overwrite the
        // snapshot with Extreme's own values, or the exit would restore nothing.
        if mode.isPerformance && !leaving.isPerformance {
            cfg.performanceRestore = PerformanceRestore(
                preventIdleSleep: cfg.preventIdleSleep,
                chargePower: cfg.chargePower,
                slowCharge: cfg.slowCharge)
        }
        let restore = (!mode.isPerformance && leaving.isPerformance) ? cfg.performanceRestore : nil
        if !mode.isPerformance { cfg.performanceRestore = nil }

        cfg.preventIdleSleep = restore?.preventIdleSleep ?? p.preventIdleSleep

        if p.fullChargePower {
            cfg.chargePower = 100
            cfg.slowCharge = false
        } else if let restore {
            cfg.chargePower = restore.chargePower
            cfg.slowCharge = restore.slowCharge
        }

        // A performance mode that leaves charging inhibited is a contradiction: a paused
        // or held pack can't supplement the adapter under load, which is most of the point.
        if mode.isPerformance {
            cfg.pauseUntil = nil
            cfg.holdCharge = false
            cfg.dischargeEnabled = false
        }
        return cfg
    }
}

/// One-tap power profiles, declared as a spectrum: spend everything on the left, save
/// everything on the right, with `off` (plain macOS) in the middle. `allCases` drives the
/// segmented picker, so the declaration order *is* the axis the user reads.
public enum SaveMode: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Everything eWiz can do for speed, and the battery pays for it.
    case extremePerformance
    case off
    case normal
    case superSaver

    public var id: String { rawValue }

    /// Unknown values decode to `.off` rather than throwing.
    ///
    /// The config file is shared between the app and the root daemon, and the two can be
    /// different builds mid-update. A helper that predates this case would otherwise fail
    /// to decode the whole `EWizConfig` over one unrecognised string and fall back to
    /// defaults — silently resetting the user's charge limit to get there.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = SaveMode(rawValue: raw) ?? .off
    }

    public var title: String {
        switch self {
        case .extremePerformance: return "Extreme"
        case .off: return "Off"
        case .normal: return "Normal"
        case .superSaver: return "Super Saver"
        }
    }

    public var summary: String {
        switch self {
        case .extremePerformance:
            return "Extreme Performance: High Power Mode where the Mac has it, Low Power Mode off, no charge limit so the battery can feed peak loads, and no idle sleep. Runs hot, charges to 100%, and costs battery lifespan. Meant for a render or a build, not all day."
        case .off:
            return "No battery saving, standard macOS behavior."
        case .normal:
            return "Charge limit 80%, pause when warm, Power Nap off. Find My stays active."
        case .superSaver:
            return "Low Power Mode, charge limit 80%, pause when warm, all sleep wake-ups off, Wi-Fi & Bluetooth off when closed."
        }
    }

    /// Whether this mode trades battery health for something else, and so shouldn't be
    /// left on by accident.
    public var isPerformance: Bool { self == .extremePerformance }

    public var profile: SaveProfile {
        switch self {
        case .extremePerformance:
            // Charge limit off, and deliberately so. This is the one lever a charge-limit
            // app is uniquely placed to pull: a MacBook under sustained peak load draws
            // more than the adapter alone supplies and makes up the difference from the
            // battery, so a pack held at 80% — or worse, sitting at the limit with
            // charging inhibited — is a power ceiling on the SoC. Full pack, full budget.
            //
            // Heat-aware charging stays *on*, at a ceiling raised from 35 °C to 45 °C.
            // Turning it off outright was the obvious move and the wrong one: 35 °C trips
            // constantly under the exact load this mode exists for, but charging a
            // lithium cell above ~45 °C damages it in a way no performance mode is worth.
            // So the nuisance threshold goes and the safety threshold stays.
            return SaveProfile(
                chargeLimitEnabled: false, chargeLimit: 100,
                heatAwareEnabled: true, maxChargeTempC: 45.0,
                lowPowerMode: false,
                powerNap: false, wakeOnNetwork: false, tcpKeepAlive: true,
                wifiOffOnLidClose: false, bluetoothOffOnLidClose: false,
                restoreOnWake: true,
                highPowerMode: true,
                preventIdleSleep: true,
                fullChargePower: true)

        case .off:
            return SaveProfile(
                chargeLimitEnabled: false, chargeLimit: 80,
                heatAwareEnabled: false, maxChargeTempC: 35.0,
                lowPowerMode: false,
                powerNap: true, wakeOnNetwork: false, tcpKeepAlive: true,
                wifiOffOnLidClose: false, bluetoothOffOnLidClose: false,
                restoreOnWake: true)

        case .normal:
            return SaveProfile(
                chargeLimitEnabled: true, chargeLimit: 80,
                heatAwareEnabled: true, maxChargeTempC: 35.0,
                lowPowerMode: false,
                powerNap: false, wakeOnNetwork: false, tcpKeepAlive: true,
                wifiOffOnLidClose: false, bluetoothOffOnLidClose: false,
                restoreOnWake: true)

        case .superSaver:
            return SaveProfile(
                chargeLimitEnabled: true, chargeLimit: 80,
                heatAwareEnabled: true, maxChargeTempC: 33.0,
                lowPowerMode: true,
                powerNap: false, wakeOnNetwork: false, tcpKeepAlive: false,
                wifiOffOnLidClose: true, bluetoothOffOnLidClose: true,
                restoreOnWake: true)
        }
    }
}

/// Long-term care: hold the pack near the middle of its range and run off the adapter.
///
/// A lithium cell ages two ways. Cycling it wears it out, and that's the one everybody
/// knows about. The other is calendar ageing — the slow, permanent capacity loss that
/// happens while the battery just *sits there*, and its rate depends almost entirely on
/// what state of charge it sits at. A pack parked at 100% degrades several times faster
/// than the same pack parked near the middle, whether or not it's ever used. A desk Mac
/// left plugged in at full is the worst case for a battery that is otherwise doing nothing.
///
/// So this isn't "stop charging" — that would hold whatever level you happened to be at,
/// including 100%, which is the level you most want to leave. It's "get to the middle and
/// stay there": charge up to the target if below, run the battery down to it if above, and
/// then sit on the adapter indefinitely.
///
/// 60% rather than Apple's ~50% storage figure because this is meant for a Mac in daily
/// use, not one in a drawer. The calendar-ageing curve is nearly as flat at 60 as at 50,
/// and the extra ten points is the difference between having a usable reserve when you
/// unplug and not.
///
/// Nothing new in the daemon drives this. The charge limit and the discharge-to-limit
/// behaviour it composes are the same ones that have always been there and are already
/// tested; what was missing was a single switch that sets all three coherently, instead of
/// asking someone to work out that "limit 60 + discharge on" is the longevity setting.
public enum LongevityCare {
    /// Where the pack is parked. See above for why this number and not 50 or 80.
    public static let targetPercent = 100 - 40

    /// Whether a config is currently set up for long-term care.
    ///
    /// Derived rather than stored. A separate flag would be a second source of truth about
    /// the same three settings, free to disagree with them the moment anyone moved the
    /// limit slider — and then the switch would read "on" over a Mac charging to 80%.
    public static func isActive(_ cfg: EWizConfig) -> Bool {
        cfg.chargeLimitEnabled
            && cfg.chargeLimit == targetPercent
            && cfg.dischargeEnabled
            && !cfg.holdCharge
    }
}

public extension EWizConfig {
    /// Turn long-term care on or off.
    ///
    /// Pure, and beside `applying(_:)` for the same reason: what a one-tap setting does to
    /// every other setting is the part most likely to be quietly wrong, and here it can be
    /// tested without root or a socket.
    func applyingLongevityCare(_ on: Bool) -> EWizConfig {
        var cfg = self
        if on {
            cfg.chargeLimitEnabled = true
            cfg.chargeLimit = LongevityCare.targetPercent
            cfg.dischargeEnabled = true
            // Heat-aware stays on with it: this mode deliberately runs the pack down to the
            // target while plugged in, and a warm cell is the one case where that should wait.
            cfg.heatAwareEnabled = true
            // `holdCharge` freezes the level exactly where it is, which would pin the pack
            // at whatever it happened to read — including the 100% this exists to get off.
            cfg.holdCharge = false
            // A pause outranks everything, so leaving one set would make the switch do nothing.
            cfg.pauseUntil = nil
            cfg.calibrateToFull = false
        } else {
            // Only the two settings this turned on come back off. The limit stays enabled at
            // a conventional ceiling rather than switching limiting off altogether — someone
            // leaving long-term care wants their battery back, not their charge limit gone.
            cfg.chargeLimit = 80
            cfg.dischargeEnabled = false
        }
        return cfg
    }
}
