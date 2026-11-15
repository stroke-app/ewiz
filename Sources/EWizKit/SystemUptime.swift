import Foundation

/// Wall-clock time since the last boot (counts time spent asleep) — i.e. how long
/// since the Mac was last restarted or shut down.
public enum SystemUptime {
    public static func secondsSinceBoot() -> TimeInterval? {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0, boot.tv_sec != 0 else { return nil }
        let seconds = Date().timeIntervalSince(Date(timeIntervalSince1970: TimeInterval(boot.tv_sec)))
        return seconds > 0 ? seconds : nil
    }

    /// When this boot started, as seconds since 1970. Constant for the life of a boot, so it
    /// identifies one: two readings more than a second apart are different boots.
    public static func bootTimestamp() -> TimeInterval? {
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        var boot = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctl(&mib, 2, &boot, &size, nil, 0) == 0, boot.tv_sec != 0 else { return nil }
        return TimeInterval(boot.tv_sec)
    }
}
