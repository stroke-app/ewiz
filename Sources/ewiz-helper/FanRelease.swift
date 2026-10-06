import Foundation
import EWizKit

/// Hands the fans back to macOS, once, at daemon start.
///
/// This is all that remains of fan control, and it exists only because the feature that
/// was removed could leave hardware changed. Forced fan mode lives in the SMC, and the SMC
/// keeps it across quit, log-out and restart — exactly like the charge inhibit. A Mac
/// pinned at 6,800 RPM by a build that no longer exists stays pinned until something
/// writes the byte back, and deleting the code that could do that would strand it for good.
///
/// So the release stays and the control doesn't. It writes `F<i>Md = 0` only for a fan
/// actually sitting in forced mode, and only on the way up: nothing is enforced, polled or
/// re-asserted afterwards. On a Mac where nothing was ever forced — which is every Apple
/// silicon Mac, since they refuse the write in the first place — it reads two keys and
/// does nothing at all.
enum FanRelease {
    /// The `F<i>Md` value the removed feature wrote to take a fan over. Not a general test
    /// of who is driving the fans (an M3 Pro reports 3 with macOS plainly in charge) — it
    /// identifies our own forcing and nothing else.
    private static let forcedMode: UInt8 = 1

    /// Number of fans; 0 on a fanless Mac or when the key is missing.
    private static func count(_ smc: SMC) -> Int {
        guard let value = try? smc.read("FNum"), let first = value.bytes.first else { return 0 }
        return Int(first)
    }

    /// Returns how many fans were handed back, so the caller can log a release that
    /// actually did something and stay quiet otherwise.
    @discardableResult
    static func releaseAll(_ smc: SMC) -> Int {
        var released = 0
        for index in 0..<count(smc) {
            guard let mode = (try? smc.read("F\(index)Md"))?.bytes.first,
                  mode == forcedMode else { continue }
            if (try? smc.write("F\(index)Md", [0])) != nil { released += 1 }
        }
        return released
    }
}
