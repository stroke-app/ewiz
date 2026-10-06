import Foundation

/// The lid-closed hold an AI agent takes through `ewiz-mcp`, written as a lease on the
/// user's own "Always Active" switch (`keepAwake` + `keepAwakeUntil`).
///
/// The helper already knows how to end a timed hold (it clears both fields once the deadline
/// passes), so an agent's hold is just a deadline it set and keeps pushing forward. What this
/// type decides is the part that touches the user: never cut short or take over a hold they
/// set themselves, and on release only undo what the agent did.
public enum AgentLidHold {
    /// What the agent changed, so release can put back exactly that and nothing more.
    public struct Lease: Equatable, Sendable {
        /// The `keepAwakeUntil` the agent wrote. Release only acts while it's still there.
        public var deadline: Date
        /// A timed hold of the user's that the agent extended past, restored on release if
        /// it hasn't run out by then. nil when Always Active was off.
        public var userDeadline: Date?
        /// `keepAwakeOnBattery` before the agent changed it, nil when it didn't.
        public var userOnBattery: Bool?

        public init(deadline: Date, userDeadline: Date? = nil, userOnBattery: Bool? = nil) {
            self.deadline = deadline
            self.userDeadline = userDeadline
            self.userOnBattery = userOnBattery
        }
    }

    public enum Plan: Equatable, Sendable {
        /// The user's Always Active is on with no timer; it already covers any task.
        case coveredByUser
        /// The user's own timed hold already runs past the requested deadline.
        case coveredUntil(Date)
        /// Write this config and remember this lease.
        case write(EWizConfig, Lease)
    }

    /// Whole seconds, so the deadline survives the JSON round trip to the helper and back
    /// and still compares equal.
    public static func deadline(minutes: Int, from now: Date) -> Date {
        Date(timeIntervalSinceReferenceDate:
                (now.timeIntervalSinceReferenceDate + Double(minutes) * 60).rounded(.up))
    }

    /// Whether `config` still carries the hold `lease` wrote.
    public static func owns(_ lease: Lease?, in config: EWizConfig) -> Bool {
        guard let lease, config.keepAwake, let until = config.keepAwakeUntil else { return false }
        return abs(until.timeIntervalSince(lease.deadline)) < 1
    }

    /// How to hold the lid until `wanted`. `onBattery` nil leaves the user's setting alone.
    public static func plan(config: EWizConfig, current: Lease?, wanted: Date,
                            onBattery: Bool?, now: Date) -> Plan {
        var next = config
        var lease: Lease

        if owns(current, in: config), let current {
            // A renewal of our own hold, which may move the deadline either way.
            lease = current
            lease.deadline = wanted
        } else if config.keepAwake, config.keepAwakeUntil == nil {
            return .coveredByUser
        } else if config.keepAwake, let until = config.keepAwakeUntil, until > now {
            if until >= wanted { return .coveredUntil(until) }
            lease = Lease(deadline: wanted, userDeadline: until)
        } else {
            lease = Lease(deadline: wanted)
        }

        next.keepAwake = true
        next.keepAwakeUntil = wanted
        if let onBattery, onBattery != config.keepAwakeOnBattery {
            if lease.userOnBattery == nil { lease.userOnBattery = config.keepAwakeOnBattery }
            next.keepAwakeOnBattery = onBattery
        }
        return .write(next, lease)
    }

    /// The config that undoes `lease`, or nil when the hold in `config` isn't the agent's
    /// any more (it ran out, or the user changed it since).
    public static func release(config: EWizConfig, lease: Lease?, now: Date) -> EWizConfig? {
        guard let lease, owns(lease, in: config) else { return nil }
        var next = config
        if let user = lease.userDeadline, user > now {
            next.keepAwakeUntil = user
        } else {
            next.keepAwake = false
            next.keepAwakeUntil = nil
        }
        if let onBattery = lease.userOnBattery { next.keepAwakeOnBattery = onBattery }
        return next
    }
}
