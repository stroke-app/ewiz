import Foundation

/// Where an install made before the rename keeps things: eWiz shipped as Battlify up to
/// 0.17, under its own bundle ID, helper label, socket and folders.
///
/// Read by the one-time handover (the app's `LegacyMigration`, the helper's
/// `LegacyHelper`) and nowhere else. Two more Battlify identifiers are still live and
/// deliberately not here: `License.product` and the device-code seed in `DeviceIdentity`.
/// Every key sold was signed against them, so renaming either would void them all.
public enum LegacyBattlify {
    public static let bundleID = "com.battlify.app"
    /// The bundle's file name. An older copy's updater looks for exactly this inside the
    /// update's disk image, which is why releases carry a hidden copy under it.
    public static let appBundleName = "Battlify.app"
    public static let helperLabel = "com.battlify.helper"
    public static let helperBinary = "/usr/local/bin/battlify-helper"
    public static let helperPlist = "/Library/LaunchDaemons/com.battlify.helper.plist"
    public static let socketPath = "/var/run/battlify.sock"
    public static let systemSupportDirectory =
        URL(fileURLWithPath: "/Library/Application Support/Battlify", isDirectory: true)
    public static var userSupportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Battlify", isDirectory: true)
    }

    /// Move whatever `old` holds into `new`, keeping anything `new` already has, then drop
    /// `old` if that emptied it.
    ///
    /// Item by item rather than one rename, because `new` may already exist: the installer
    /// creates it before the daemon first runs, and the app creates its own on first launch.
    /// Returns the names moved.
    @discardableResult
    public static func merge(_ old: URL, into new: URL) -> [String] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: old.path), !items.isEmpty else {
            try? fm.removeItem(at: old)
            return []
        }
        try? fm.createDirectory(at: new, withIntermediateDirectories: true)
        var moved: [String] = []
        for name in items where !fm.fileExists(atPath: new.appendingPathComponent(name).path) {
            if (try? fm.moveItem(at: old.appendingPathComponent(name),
                                 to: new.appendingPathComponent(name))) != nil {
                moved.append(name)
            }
        }
        if (try? fm.contentsOfDirectory(atPath: old.path))?.isEmpty == true {
            try? fm.removeItem(at: old)
        }
        return moved
    }
}
