import Foundation

/// Wakes booked through `pmset schedule`, for anything that has to happen while the lid is
/// shut and the Mac is asleep: the hibernation handover (`DeferredHibernate`) and the app's
/// delayed lid-close radios. Root only — `pmset` refuses to schedule for anyone else.
enum ScheduledWake {

    /// `pmset`'s own date format. It parses what it prints, and this is what it prints.
    private static let stampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "MM/dd/yyyy HH:mm:ss"
        return f
    }()

    /// Book a wake at `date`. Returns the stamp to cancel it by, which is the only handle
    /// `pmset` gives you — cancelling takes the same string that scheduled it, to the second.
    static func book(at date: Date) -> String? {
        let stamp = stampFormat.string(from: date)
        guard Shell.run("/usr/bin/pmset", ["schedule", "wake", stamp]) != nil else { return nil }
        return stamp
    }

    static func cancel(_ stamp: String) {
        _ = Shell.run("/usr/bin/pmset", ["schedule", "cancel", "wake", stamp])
    }

    /// Whether `stamp` is one `book` could have produced. The app hands stamps back to cancel,
    /// and nothing else should reach `pmset` as root.
    static func isStamp(_ stamp: String) -> Bool {
        stampFormat.date(from: stamp) != nil
    }
}
