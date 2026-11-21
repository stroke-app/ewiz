import Foundation

/// A set of weekdays a schedule applies to. Bit 0 = Sunday … bit 6 = Saturday,
/// matching `Calendar`'s 1-based `weekday` (Sunday = 1) shifted to 0-based.
public struct Weekdays: OptionSet, Codable, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let sun = Weekdays(rawValue: 1 << 0)
    public static let mon = Weekdays(rawValue: 1 << 1)
    public static let tue = Weekdays(rawValue: 1 << 2)
    public static let wed = Weekdays(rawValue: 1 << 3)
    public static let thu = Weekdays(rawValue: 1 << 4)
    public static let fri = Weekdays(rawValue: 1 << 5)
    public static let sat = Weekdays(rawValue: 1 << 6)

    public static let everyday: Weekdays = [.sun, .mon, .tue, .wed, .thu, .fri, .sat]
    public static let weekdays: Weekdays = [.mon, .tue, .wed, .thu, .fri]
    public static let weekends: Weekdays = [.sun, .sat]

    /// True if `date`'s weekday is in the set (uses the given calendar's `weekday`).
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let wd = calendar.component(.weekday, from: date) // 1 = Sunday
        return contains(Weekdays(rawValue: 1 << (wd - 1)))
    }

    /// Short labels for the days that are set, in week order ("Mon", "Tue", …).
    public var shortLabels: [String] {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (0..<7).compactMap { contains(Weekdays(rawValue: 1 << $0)) ? names[$0] : nil }
    }

    /// A friendly summary: "Every day", "Weekdays", "Weekends", or the day list.
    public var summary: String {
        switch self {
        case .everyday: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        default:
            let labels = shortLabels
            return labels.isEmpty ? "Never" : labels.joined(separator: ", ")
        }
    }
}

/// What a charging schedule does while its window is active.
public enum ScheduleAction: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Allow charging (up to the configured limit) during the window.
    case charge
    /// Hold — stop charging so the battery level stays put.
    case hold
    /// Run off battery (force-discharge, where supported) during the window.
    case discharge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .charge: return "Charge"
        case .hold: return "Hold (don't charge)"
        case .discharge: return "Run on battery"
        }
    }
}

/// A weekly repeating time window — the shape shared by every timetable in the app
/// (charging windows, keep-awake windows). Times are minutes-from-midnight in the
/// user's local time, and a window may wrap past midnight (start + duration > 1440).
public protocol RecurringWindow {
    var enabled: Bool { get }
    var days: Weekdays { get }
    /// Window start, minutes from local midnight (0…1439).
    var startMinute: Int { get }
    /// Window length in minutes. Clamped to 1…1440 by conformers' initialisers.
    var durationMinutes: Int { get }
}

extension RecurringWindow {
    public var endMinute: Int { startMinute + durationMinutes } // may exceed 1440

    /// Whether this window is open at `date`, handling windows that wrap past
    /// midnight (the post-midnight tail belongs to the previous day's start).
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        // Same-day portion: start day's weekday must match.
        if days.contains(date, calendar: calendar),
           nowMin >= startMinute, nowMin < min(endMinute, 1440) {
            return true
        }
        // Wrapped tail after midnight belongs to *yesterday's* start day.
        if endMinute > 1440 {
            let wrapEnd = endMinute - 1440
            if nowMin < wrapEnd,
               let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
               days.contains(yesterday, calendar: calendar) {
                return true
            }
        }
        return false
    }

    /// "22:00–03:00" style window label in local time.
    public func windowLabel() -> String {
        func fmt(_ m: Int) -> String {
            let mm = ((m % 1440) + 1440) % 1440
            return String(format: "%02d:%02d", mm / 60, mm % 60)
        }
        return "\(fmt(startMinute))–\(fmt(endMinute))"
    }

    /// "22:00–03:00 · Weekdays" — the one-line summary a settings row shows.
    public var scheduleSummary: String { "\(windowLabel()) · \(days.summary)" }
}

/// A recurring charging window, e.g. "every day, starting 22:00, for 5 hours, hold".
public struct ChargeSchedule: Codable, Sendable, Identifiable, Equatable, RecurringWindow {
    public var id: UUID
    public var enabled: Bool
    public var label: String
    public var days: Weekdays
    /// Window start, minutes from local midnight (0…1439).
    public var startMinute: Int
    /// Window length in minutes (e.g. 5 h = 300). Clamped to 1…1440.
    public var durationMinutes: Int
    public var action: ScheduleAction

    public init(id: UUID = UUID(), enabled: Bool = true, label: String = "",
                days: Weekdays = .everyday, startMinute: Int = 22 * 60,
                durationMinutes: Int = 5 * 60, action: ScheduleAction = .hold) {
        self.id = id
        self.enabled = enabled
        self.label = label
        self.days = days
        self.startMinute = max(0, min(1439, startMinute))
        self.durationMinutes = max(1, min(1440, durationMinutes))
        self.action = action
    }
}

/// A recurring window that switches "Always Active" on and off on a timetable, e.g.
/// "weekdays, 09:00, for 9 hours". While at least one is enabled, keep-awake holds
/// only inside a window and the Mac sleeps normally outside it.
public struct AwakeSchedule: Codable, Sendable, Identifiable, Equatable, RecurringWindow {
    public var id: UUID
    public var enabled: Bool
    public var label: String
    public var days: Weekdays
    public var startMinute: Int
    public var durationMinutes: Int

    public init(id: UUID = UUID(), enabled: Bool = true, label: String = "",
                days: Weekdays = .weekdays, startMinute: Int = 9 * 60,
                durationMinutes: Int = 9 * 60) {
        self.id = id
        self.enabled = enabled
        self.label = label
        self.days = days
        self.startMinute = max(0, min(1439, startMinute))
        self.durationMinutes = max(1, min(1440, durationMinutes))
    }
}

/// A once-daily "have it charged by" target: hold at the limit, then top up to
/// `targetPercent` timed to be ready by `targetMinute` on the selected days.
public struct ReadyByTarget: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var days: Weekdays
    /// Target ready time, minutes from local midnight.
    public var targetMinute: Int
    /// Charge level to reach by the target time (typically 100).
    public var targetPercent: Int

    public init(enabled: Bool = false, days: Weekdays = .weekdays,
                targetMinute: Int = 8 * 60, targetPercent: Int = 100) {
        self.enabled = enabled
        self.days = days
        self.targetMinute = max(0, min(1439, targetMinute))
        self.targetPercent = max(50, min(100, targetPercent))
    }
}
