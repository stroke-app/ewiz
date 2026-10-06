import Foundation

/// Decides when to nudge the user to give the Mac a rest (a restart), from uptime and
/// throttle state. Pure — no I/O — so the policy is unit-tested.
public enum RestAdvisor {
    /// Uptime past which a restart is worth suggesting.
    public static let defaultThreshold: TimeInterval = 7 * 86_400
    /// Minimum gap between notifications, so it never nags.
    public static let notifyInterval: TimeInterval = 3 * 86_400

    /// Whether a rest is currently due — drives the in-app banner. True once uptime
    /// crosses the threshold, unless the user snoozed past `now`.
    public static func isDue(uptime: TimeInterval,
                             now: Date,
                             snoozeUntil: Date?,
                             threshold: TimeInterval = defaultThreshold) -> Bool {
        guard uptime >= threshold else { return false }
        if let snoozeUntil, now < snoozeUntil { return false }
        return true
    }

    /// Whether to also post a notification now — throttled separately from the banner.
    public static func shouldNotify(now: Date,
                                    lastNotifiedAt: Date?,
                                    interval: TimeInterval = notifyInterval) -> Bool {
        guard let lastNotifiedAt else { return true }
        return now.timeIntervalSince(lastNotifiedAt) >= interval
    }
}
