import Foundation

/// Low-battery warnings for AI agents: what `ewiz-mcp` pushes into a Claude Code session
/// over a channel, and what `ewiz-mcp hook` adds to an agent's context from a hook.
///
/// Both use the same tracker so they say the same thing at the same moments: once when the
/// battery drops to the low threshold while unplugged, once more at the critical one, and
/// once when the charger goes back in. A reading that bobs back up a percent doesn't re-arm
/// anything; only plugging in does, so one discharge is at most three messages.
public enum BatteryAlerts {
    /// Settings › AI Agents › "Tell agents when the battery runs low".
    public static let enabledKey = "agents.batteryAlerts"
    /// The low threshold, in percent.
    public static let thresholdKey = "agents.batteryAlertPercent"

    public static let defaultThreshold = 20
    public static let thresholdRange = 10...50
    /// The second, last-call warning. Skipped when the low threshold is already at or below it.
    public static let criticalPercent = 10

    public static var isEnabled: Bool {
        CFPreferencesAppSynchronize(AgentAccess.domain as CFString)
        return CFPreferencesCopyAppValue(enabledKey as CFString, AgentAccess.domain as CFString) as? Bool ?? true
    }

    public static var threshold: Int {
        CFPreferencesAppSynchronize(AgentAccess.domain as CFString)
        let stored = (CFPreferencesCopyAppValue(thresholdKey as CFString, AgentAccess.domain as CFString)
                      as? NSNumber)?.intValue ?? defaultThreshold
        return min(thresholdRange.upperBound, max(thresholdRange.lowerBound, stored))
    }

    public enum Level: Int, Comparable, Sendable {
        case none, low, critical
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    public struct Reading: Sendable, Equatable {
        public var percent: Int
        public var pluggedIn: Bool
        public var minutesToEmpty: Int?
        public init(percent: Int, pluggedIn: Bool, minutesToEmpty: Int?) {
            self.percent = percent; self.pluggedIn = pluggedIn; self.minutesToEmpty = minutesToEmpty
        }
    }

    /// The battery as it is now.
    public static func currentReading() -> Reading {
        #if DEBUG
        // Debug builds only: EWIZ_FAKE_BATTERY="18,unplugged,42" (percent, plugged|unplugged,
        // minutes left) so the channel and hook can be exercised without draining a battery.
        if let fake = ProcessInfo.processInfo.environment["EWIZ_FAKE_BATTERY"] {
            let parts = fake.split(separator: ",").map(String.init)
            if let percent = parts.first.flatMap({ Int($0) }) {
                return Reading(percent: percent, pluggedIn: parts.count > 1 && parts[1] == "plugged",
                               minutesToEmpty: parts.count > 2 ? Int(parts[2]) : nil)
            }
        }
        #endif
        let b = BatteryMonitor.read()
        return Reading(percent: b.percentage, pluggedIn: b.isPluggedIn, minutesToEmpty: b.timeToEmpty)
    }

    public struct Alert: Sendable, Equatable {
        /// Short machine name: battery_low, battery_critical, charger_connected.
        public var event: String
        public var text: String
    }

    public static func level(_ r: Reading, threshold: Int) -> Level {
        guard !r.pluggedIn else { return .none }
        if threshold > criticalPercent, r.percent <= criticalPercent { return .critical }
        if r.percent <= threshold { return threshold <= criticalPercent ? .critical : .low }
        return .none
    }

    /// The highest level already announced this discharge. Persisted by the hook between runs.
    public struct Tracker: Sendable, Equatable {
        public var announced: Level
        public init(announced: Level = .none) { self.announced = announced }

        /// What to say about this reading, if anything.
        public mutating func update(_ r: Reading, threshold: Int) -> Alert? {
            if r.pluggedIn {
                defer { announced = .none }
                guard announced > .none else { return nil }
                return Alert(event: "charger_connected",
                             text: "Charger connected (battery \(r.percent)%). The low-battery warning is over.")
            }
            let now = BatteryAlerts.level(r, threshold: threshold)
            guard now > announced else { return nil }
            announced = now
            return BatteryAlerts.alert(now, r)
        }
    }

    static func alert(_ level: Level, _ r: Reading) -> Alert? {
        let left = r.minutesToEmpty.map { ", about \(duration($0)) left" } ?? ""
        switch level {
        case .none:
            return nil
        case .low:
            return Alert(event: "battery_low", text: """
                This Mac's battery is low: \(r.percent)%, unplugged\(left). Keep work saved and \
                committed as you go, and don't start long jobs without telling the user. If the \
                task needs more time, ask them to plug in.
                """)
        case .critical:
            return Alert(event: "battery_critical", text: """
                This Mac's battery is critically low: \(r.percent)%, unplugged\(left). It may shut \
                down soon. Save and commit work in progress now, finish or pause the task, and \
                tell the user to plug in.
                """)
        }
    }

    static func duration(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes) min"
    }
}
