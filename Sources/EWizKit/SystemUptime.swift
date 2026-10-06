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
}
