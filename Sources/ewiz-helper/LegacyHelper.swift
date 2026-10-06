import Foundation
import EWizKit

/// Takes over from the helper this app shipped as Battlify.
///
/// The installer scripts evict the old daemon already, but a signed build registers its
/// helper with `SMAppService` and runs no script at all, so the daemon does it too, before
/// it touches anything. Two helpers left loaded would both drive the charge limit on their
/// own timers, and whichever wrote last would win.
enum LegacyHelper {
    static func evictAndMigrate() {
        // Never evict ourselves: an old app's quiet updater could have started this binary
        // under the old label.
        guard !CommandLine.arguments[0].contains("battlify") else { return }
        let fm = FileManager.default
        let label = LegacyBattlify.helperLabel

        if Shell.run("/bin/launchctl", ["print", "system/\(label)"]) != nil {
            HelperLog.info("taking over from the Battlify helper")
            Shell.run("/bin/launchctl", ["bootout", "system/\(label)"])
            for _ in 0..<50 where Shell.run("/bin/launchctl", ["print", "system/\(label)"]) != nil {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        Shell.run("/usr/bin/pkill", ["-f", "^\(LegacyBattlify.helperBinary)"])

        // Its config, history, sealed-sleep snapshot and charge-limit ownership come with
        // us, so the handover is invisible: same limit, same history, and the macOS limit
        // it set is still known to be ours to release.
        let moved = LegacyBattlify.merge(LegacyBattlify.systemSupportDirectory,
                                         into: EWizPaths.configDirectory)
        if !moved.isEmpty {
            HelperLog.info("carried over from Battlify: \(moved.sorted().joined(separator: ", "))")
        }

        for path in [LegacyBattlify.helperPlist, LegacyBattlify.helperBinary, LegacyBattlify.socketPath]
        where fm.fileExists(atPath: path) {
            try? fm.removeItem(atPath: path)
        }
    }
}
