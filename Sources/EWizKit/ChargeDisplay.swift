import Foundation

/// What the battery and the helper report, flattened for `ChargeDisplay`.
///
/// Everything here is a fact one of the two stores already holds; nothing is derived. The
/// deriving happens in one place so the menu-bar glyph, the panel header, its hint rows
/// and the tooltip can't each work out a different answer from the same facts — which is
/// how the icon came to show a finished charge over a header that said "Charging to 80%".
public struct ChargeDisplayInput: Equatable, Sendable {
    public var percentage: Int
    public var isCharging: Bool
    /// macOS's view: external power is what's running the Mac.
    public var isPluggedIn: Bool
    public var isFullyCharged: Bool
    public var limitEnabled: Bool
    /// Where the limit actually stops on this Mac (`ChargeLimitStore.effectiveLimit`).
    public var effectiveLimit: Int
    /// The macOS charge-limit step the helper has applied, nil when none.
    public var nativeLimitApplied: Int?
    /// Holds park on macOS's own steps (80, 85, …) rather than exactly where they were thrown.
    public var usesNativeLimit: Bool
    /// "Don't charge" is on.
    public var holdCharge: Bool
    /// The helper's word for why charging is off, if it has one.
    public var pauseReason: String?
    /// The helper is running the Mac off the battery with the cable in.
    public var discharging: Bool
    /// A timed or indefinite pause is set.
    public var isPaused: Bool
    /// A one-off charge to 100% is in progress.
    public var calibrating: Bool
    /// Charge power as a percentage, for the "charging gently" hint.
    public var chargePower: Int

    public init(percentage: Int, isCharging: Bool, isPluggedIn: Bool, isFullyCharged: Bool = false,
                limitEnabled: Bool = false, effectiveLimit: Int = 80, nativeLimitApplied: Int? = nil,
                usesNativeLimit: Bool = false, holdCharge: Bool = false, pauseReason: String? = nil,
                discharging: Bool = false, isPaused: Bool = false, calibrating: Bool = false,
                chargePower: Int = 100) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.isFullyCharged = isFullyCharged
        self.limitEnabled = limitEnabled
        self.effectiveLimit = effectiveLimit
        self.nativeLimitApplied = nativeLimitApplied
        self.usesNativeLimit = usesNativeLimit
        self.holdCharge = holdCharge
        self.pauseReason = pauseReason
        self.discharging = discharging
        self.isPaused = isPaused
        self.calibrating = calibrating
        self.chargePower = chargePower
    }
}

/// Why charging is off when nothing about the level explains it.
public enum ChargePause: Equatable, Sendable {
    /// A timed pause, or "until I resume".
    case user
    case heat
    /// The helper waits a moment after wake before charging.
    case settling
    case schedule
    /// Cut on the way into sleep; gone by the time anyone reads it.
    case sleep
}

/// What charging is doing, as one value.
///
/// Levels aren't carried in the cases (only targets are), so a view can watch for a
/// change of state without the battery ticking up a percent counting as one.
public enum ChargeDisplayState: Equatable, Sendable {
    case onBattery
    /// On the adapter, not taking a charge, and eWiz isn't the reason: the charger
    /// negotiating, macOS's own trickle gap, or a hold that hasn't engaged yet.
    case pluggedIn
    /// Current is flowing; `to` is where it stops — the limit, the hold's step, or 100.
    case charging(to: Int)
    /// A one-off charge to 100%, whether or not current is flowing right now.
    case calibrating(charging: Bool)
    /// At or above the limit with charging stopped by it.
    case heldAtLimit(Int)
    /// "Don't charge" keeping the level where it is.
    case holding(at: Int)
    /// Above the stop and running off the battery down to it.
    case draining(to: Int)
    case paused(ChargePause)
    case full

    /// Whether charging arrived somewhere it meant to stop. Only the completions are
    /// allowed to flash the check mark.
    public var isComplete: Bool {
        switch self {
        case .full, .heldAtLimit, .holding: return true
        default: return false
        }
    }

    /// The level charging is heading for or sitting at, when the state has one.
    public var target: Int? {
        switch self {
        case .charging(let to), .draining(let to): return to
        case .heldAtLimit(let at), .holding(let at): return at
        case .calibrating, .full: return 100
        case .onBattery, .pluggedIn, .paused: return nil
        }
    }

    /// Same case, whatever the numbers: a hold moving from 80 to 85 is still a hold.
    public func sameKind(as other: ChargeDisplayState) -> Bool {
        switch (self, other) {
        case (.onBattery, .onBattery), (.pluggedIn, .pluggedIn), (.charging, .charging),
             (.calibrating, .calibrating), (.heldAtLimit, .heldAtLimit), (.holding, .holding),
             (.draining, .draining), (.paused, .paused), (.full, .full):
            return true
        default:
            return false
        }
    }
}

/// The mark drawn inside the menu-bar glyph.
public enum ChargeMark: Equatable, Sendable {
    case none
    /// Current is flowing in.
    case bolt
    /// On the adapter and not taking a charge: held, paused, or waiting.
    case pause
    /// A charge just finished — only ever shown by the completion flash.
    case check
}

/// One reading of the charge state and every line of UI that describes it.
public struct ChargeDisplay: Equatable, Sendable {
    public let input: ChargeDisplayInput
    public let state: ChargeDisplayState

    public init(_ input: ChargeDisplayInput) {
        self.input = input
        self.state = Self.resolve(input)
    }

    /// Where charging stops on this Mac right now: the hold's level or step when "Don't
    /// charge" is on, otherwise the limit, otherwise full. The hold wins over the limit
    /// here as it does in the helper.
    public static func stop(_ i: ChargeDisplayInput) -> Int {
        if i.holdCharge {
            // Under macOS's limit a hold can only park on a step, so the helper rounds up
            // and charges to it first; with a real charge key it parks exactly where it is.
            return i.usesNativeLimit ? (i.nativeLimitApplied ?? 100) : i.percentage
        }
        if i.limitEnabled && !i.calibrating { return i.effectiveLimit }
        return 100
    }

    public var stop: Int { Self.stop(input) }

    static func resolve(_ i: ChargeDisplayInput) -> ChargeDisplayState {
        // `|| discharging`: holding on a Mac with no charge key means cutting the adapter,
        // and macOS then says "Battery Power" with the cable still in. That's the hold
        // doing its job, not an unplug.
        guard i.isPluggedIn || i.discharging else { return .onBattery }
        let stop = stop(i)

        // Current flowing is a hardware fact and outranks every reason the helper gives:
        // its status is polled, so for up to half a minute it can still say "limit" or
        // "hold" about a battery that has visibly started charging. On this Mac that lag
        // is routine — macOS's limit reports a hold at any level whenever current isn't
        // flowing, including the seconds after plugging in at 49%.
        if i.isCharging {
            return i.calibrating ? .calibrating(charging: true) : .charging(to: stop)
        }

        if i.isPaused { return .paused(.user) }

        if i.holdCharge {
            // Under the stop the hold hasn't engaged yet: macOS is about to charge up to
            // its step. Saying "Holding at 80%" over a gauge reading 49 is the bug.
            return i.percentage >= stop ? .holding(at: stop) : .pluggedIn
        }

        // A limit at 100 limits nothing; full there is just full.
        if i.limitEnabled && !i.calibrating && stop < 100 {
            if i.percentage > stop && i.discharging { return .draining(to: stop) }
            if i.percentage >= stop { return .heldAtLimit(stop) }
            // Below the limit and not charging. With a real charge key that's the helper
            // coasting down its recharge band, which is the limit at work; under macOS's
            // limit it's the step having been set before current started, and macOS will
            // charge. Only the first is a hold worth naming.
            if i.pauseReason == "limit" && !i.usesNativeLimit { return .heldAtLimit(stop) }
        }

        if i.calibrating && i.percentage < 100 { return .calibrating(charging: false) }

        if i.isFullyCharged || i.percentage >= 100 { return .full }

        switch i.pauseReason {
        case "heat":     return .paused(.heat)
        case "settling": return .paused(.settling)
        case "schedule": return .paused(.schedule)
        case "sleep":    return .paused(.sleep)
        case "paused":   return .paused(.user)
        default:         return .pluggedIn
        }
    }

    // MARK: - What each surface shows

    /// The steady mark for the glyph.
    public var mark: ChargeMark { Self.steadyMark(for: state, percentage: input.percentage) }

    /// The mark a state wears. Full on the charger is just a full battery: nothing is
    /// paused, so there's nothing to say. Static so a view can ask about the state it just
    /// left, whose mark is the one that has to animate out.
    public static func steadyMark(for state: ChargeDisplayState, percentage: Int) -> ChargeMark {
        switch state {
        case .onBattery, .full: return .none
        case .charging: return .bolt
        case .calibrating(let charging): return charging ? .bolt : .pause
        case .heldAtLimit, .holding, .draining, .paused, .pluggedIn:
            return percentage < 100 ? .pause : .none
        }
    }

    /// Whether the level is drawn faded: eWiz is deliberately keeping charge off it.
    public var holdsLevel: Bool {
        switch state {
        case .heldAtLimit, .holding, .draining: return true
        case .paused(let why): return why != .sleep
        default: return false
        }
    }

    /// First segment of the header's detail line.
    public var statusLine: String {
        switch state {
        case .onBattery: return "On battery"
        case .full: return "Fully charged"
        case .charging, .calibrating(charging: true): return "Charging"
        // The cable is in and the helper has cut it; "Plugged in" would argue with the
        // menu bar's own battery icon, which says battery power.
        case .draining where !input.isPluggedIn: return "On battery"
        default: return "Plugged in, not charging"
        }
    }

    /// The line under the gauge: what the gauge can't draw. Nil when the gauge's own limit
    /// marker already says everything.
    public var headerNote: String? {
        let pct = input.percentage
        switch state {
        case .onBattery, .pluggedIn, .full:
            return nil
        case .paused(.user):
            return "Charging paused"
        case .paused(.heat):
            return "Charging paused, battery is warm"
        case .paused(.settling), .paused(.sleep), .paused(.schedule):
            return nil
        case .calibrating:
            return "Charging to 100% once"
        case .draining(let to):
            return "Draining to \(to)%"
        case .holding(let at):
            return "Holding at \(at)%"
        case .heldAtLimit(let at):
            if pct > at { return "Above the \(at)% limit" }
            if pct < at { return "Paused under the \(at)% limit" }
            return "Holding at \(at)%"
        case .charging(let to):
            guard pct < to else {
                return input.limitEnabled ? "Above the \(input.effectiveLimit)% limit" : nil
            }
            return "Charging to \(to)%"
        }
    }

    /// The live-state row under the charge controls, for whatever the header hasn't said.
    public var hint: String? {
        switch state {
        case .charging where input.pauseReason == "slow":
            return "Charging gently, at \(input.chargePower)% power"
        case .heldAtLimit:
            return "Charging paused to hold limit"
        case .holding:
            return input.discharging ? "Running off the battery to hold the level"
                                     : "Holding the level where it is"
        case .paused(.heat):
            return "Charging paused, battery is warm"
        case .paused(.settling):
            return "Charging resumes shortly after wake"
        case .paused(.schedule):
            return "A schedule is holding charging"
        // A user pause has its own row with a Resume button; a drain is the header's
        // line; the rest have nothing to add.
        default:
            return nil
        }
    }

    /// Caption under the "Don't charge" switch while it's on, nil while it's off.
    public var holdCaption: String? {
        guard input.holdCharge else { return nil }
        guard input.usesNativeLimit else { return "Holding the level" }
        let at = stop
        return at > input.percentage ? "Charges to \(at)%, then holds there"
                                     : "Holding at \(at)% on wall power"
    }

    /// The menu-bar tooltip.
    public var tooltip: String {
        let pct = input.percentage
        switch state {
        case .onBattery: return "On battery · \(pct)%"
        case .pluggedIn: return "Plugged in · \(pct)%"
        case .charging, .calibrating(charging: true): return "Charging · \(pct)%"
        case .calibrating: return "Charging to 100% once · \(pct)%"
        case .heldAtLimit(let at): return "Holding at \(at)% limit"
        case .holding(let at): return input.usesNativeLimit ? "Holding at \(at)%" : "Holding the level where it is"
        case .draining(let to): return "Draining to \(to)% · \(pct)%"
        case .paused(.user): return "Charging paused"
        case .paused(.heat): return "Charging paused, battery warm"
        case .paused(.settling): return "Settling after wake"
        case .paused(.schedule): return "A schedule is holding charging"
        case .paused(.sleep): return "Charging cut for sleep"
        case .full: return "Fully charged"
        }
    }

    /// A completion the level actually backs up. `heldAtLimit` also covers the helper
    /// coasting down its recharge band, and 77% is not "reached 80%".
    public var isComplete: Bool {
        state.isComplete && input.percentage >= (state.target ?? 0)
    }

    /// Whether arriving at this reading from `previous` is a charge finishing: it was
    /// heading somewhere, and it has stopped there. A hold switched on mid-charge, a
    /// limit reported at 49% while the charger negotiates, or a Mac that woke already
    /// held are none of them a finish.
    public func completes(from previous: ChargeDisplayState) -> Bool {
        guard isComplete else { return false }
        switch previous {
        case .charging(let to):            return state.target == to
        case .calibrating(charging: true): return state == .full
        default:                           return false
        }
    }
}
