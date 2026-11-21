import Foundation

/// Low Power Mode control via `pmset`. There is no public API to toggle it, so we
/// shell out. Setting requires root (which the daemon has); reading does not.
enum LowPowerMode {

    /// Current Low Power Mode state, parsed from `pmset -g`.
    static func isEnabled() -> Bool {
        guard let out = Shell.run("/usr/bin/pmset", ["-g"]) else { return false }
        // Look for a line like "  lowpowermode         1"
        for line in out.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            if parts.first == "lowpowermode", let last = parts.last {
                return last == "1"
            }
        }
        return false
    }

    /// Enable/disable Low Power Mode for all power sources. Requires root.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        Shell.run("/usr/bin/pmset", ["-a", "lowpowermode", on ? "1" : "0"]) != nil
    }
}
