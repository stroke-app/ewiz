import AppKit
import EWizKit

/// The one-time move from Battlify to eWiz, on the user's side. The helper has its own,
/// see `LegacyHelper`.
///
/// Runs first thing in `EWizApp.init`, before any store reads its settings.
@MainActor
enum LegacyMigration {
    private static let doneKey = "migration.fromBattlify"

    static func run() {
        quitOldApp()
        watchForOldApp()
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        migrateDefaults()
        LegacyBattlify.merge(LegacyBattlify.userSupportDirectory, into: EWizPaths.userConfigDirectory)
        UserDefaults.standard.set(true, forKey: doneKey)
    }

    /// Settings, the license key and the hotkeys: the whole preferences domain the app
    /// kept as `com.battlify.app`, copied across key by key. Anything already set under
    /// the new ID wins.
    private static func migrateDefaults() {
        let defaults = UserDefaults.standard
        guard let old = defaults.persistentDomain(forName: LegacyBattlify.bundleID) else { return }
        for (key, value) in old where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
    }

    /// A Battlify still running beside eWiz would drive its own helper against ours.
    /// Killed rather than asked to quit: an old copy installs any update it has
    /// downloaded on the way out, which would put Battlify straight back.
    private static func quitOldApp() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: LegacyBattlify.bundleID) {
            app.forceTerminate()
        }
    }

    /// And one that starts later. Battlify's login item outlives the rename (macOS ties it
    /// to the old bundle ID, and only that app can remove it), so on a Mac where someone
    /// dragged eWiz in beside Battlify rather than over it, every login started Battlify
    /// too, found its helper gone and asked for a password to put it back.
    private static func watchForOldApp() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.bundleIdentifier == LegacyBattlify.bundleID { app?.forceTerminate() }
        }
    }
}
