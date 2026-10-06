import Foundation
import EWizKit

/// Instant wake for a short close, no drain for a long one.
///
/// Apple silicon has one lever and no dial. `hibernatemode 3` keeps memory powered: the lid
/// opens straight away and the trickle costs roughly 0.1% an hour, which is the 2% a
/// 22-hour close shows up as. `hibernatemode 25` powers memory down: nothing to keep alive,
/// nothing to lose, and 15 to 30 seconds to come back. Intel Macs had `standbydelay` to get
/// both — stay in ordinary sleep for a while, hibernate once the sleep turns out to be a
/// long one — and those keys are simply not there on this hardware. `pmset -g custom` on an
/// M3 Pro prints no `standbydelay` and no `autopoweroff`; writes to them are accepted and
/// dropped.
///
/// So the delay is implemented instead of configured. On the way into a closed-lid sleep the
/// daemon books a wake a few minutes out. If the Mac is still shut when that wake lands,
/// memory is switched off and it goes straight back down — hibernating this time. A close
/// shorter than the deferral never reaches it and still opens instantly. The cost is one
/// dark wake of a few seconds; the saving is every hour after it.
enum DeferredHibernate {

    /// `pmset`'s own date format. It parses what it prints, and this is what it prints.
    private static let stampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "MM/dd/yyyy HH:mm:ss"
        return f
    }()

    /// Book the wake. Returns the stamp to cancel it by, which is the only handle `pmset`
    /// gives you — cancelling takes the same string that scheduled it, to the second.
    static func schedule(after minutes: Int) -> String? {
        let stamp = stampFormat.string(from: Date().addingTimeInterval(Double(minutes) * 60))
        guard Shell.run("/usr/bin/pmset", ["schedule", "wake", stamp]) != nil else { return nil }
        return stamp
    }

    static func cancel(_ stamp: String) {
        _ = Shell.run("/usr/bin/pmset", ["schedule", "cancel", "wake", stamp])
    }

    /// Switch memory off and go straight back down.
    ///
    /// The purge comes first because hibernation writes memory to disk and reads all of it
    /// back: the inactive file cache is the part there is no reason to carry through, and
    /// dropping it is both a smaller write now and a shorter wait on the way up.
    static func handoff() -> Bool {
        guard PowerSettings.setKey("hibernatemode", String(SealedSleep.hibernateSealed)) else {
            return false
        }
        _ = SealedSleepController.releaseCachedMemory()
        return PowerSettings.sleepNow()
    }

    /// Put instant wake back, so the next short close is short again.
    @discardableResult
    static func restoreFastWake() -> Bool {
        PowerSettings.setKey("hibernatemode", String(SealedSleep.hibernateDefault))
    }

    /// Whether the Mac is currently set to hibernate. Used on startup to undo a deferral
    /// that a crash or a forced quit left half-applied.
    static var isHibernating: Bool {
        PowerSettings.readHibernateMode() == SealedSleep.hibernateSealed
    }
}
