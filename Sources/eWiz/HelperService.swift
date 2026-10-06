import Foundation
import ServiceManagement
import Security
import EWizKit

/// Chooses how the root helper gets installed and kept current.
///
/// There are three mechanisms, and the only thing that really separates them is how often
/// they interrupt someone:
///
///   1. **SMAppService** — the daemon runs straight out of the app bundle. Approved once,
///      and because the executable that runs *is* the one inside the app, shipping a new
///      app ships a new helper. There is no update step at all after that. Needs a real
///      Developer ID signature; an ad-hoc build cannot register.
///   2. **Quiet self-update** — for a helper already installed the legacy way, hand the
///      running daemon the new binary over the control socket and let it verify our
///      signature and swap itself (see `HelperUpdate` on the daemon side). No password.
///      Needs protocol v6+ and a signing identity on both ends.
///   3. **The admin installer** — one osascript password prompt. Works for anything,
///      including unsigned local builds, so it stays as the floor under the other two.
///
/// A fresh install on a signed build takes route 1. An existing legacy install stays where
/// it is and takes route 2 — migrating it would itself cost the prompt this is all trying
/// to avoid, and a legacy install that quietly updates is already the goal.
enum HelperService {
    static let daemonPlistName = "com.ewiz.helper.plist"

    // MARK: - Identity

    /// This app's Developer ID team, or nil when ad-hoc/unsigned.
    ///
    /// Both quiet routes hinge on it: SMAppService won't register unsigned code, and the
    /// daemon refuses a replacement it can't attribute to the team it already trusts.
    static var teamIdentifier: String? {
        var me: SecCode?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me else { return nil }
        var code: SecStaticCode?
        guard SecCodeCopyStaticCode(me, [], &code) == errSecSuccess, let code else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
                code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return dict[kSecCodeInfoTeamIdentifier as String] as? String
    }

    static var isSigned: Bool { teamIdentifier != nil }

    /// The helper binary shipped inside this bundle, if this is a packaged build.
    static var bundledHelperPath: String? {
        let path = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/ewiz-helper").path
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    // MARK: - Legacy install detection

    /// Whether a helper is installed the old way. Its presence is what decides between
    /// registering the bundled daemon and quietly updating the one already there.
    static var legacyInstallPresent: Bool {
        FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.ewiz.helper.plist")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/ewiz-helper")
    }

    // MARK: - SMAppService

    private static var service: SMAppService { SMAppService.daemon(plistName: daemonPlistName) }

    static var registrationStatus: SMAppService.Status { service.status }

    /// Register the bundled daemon. Returns nil on success, or why it couldn't.
    ///
    /// Approval is asked for once, by the system, and then the registration persists across
    /// app updates — which is exactly the property that makes every later helper build free.
    static func registerBundledDaemon() -> String? {
        guard isSigned else {
            return "This build isn't Developer ID signed, so macOS won't register its daemon."
        }
        let s = service
        if s.status == .enabled { return nil }
        do {
            try s.register()
            return nil
        } catch {
            return "\(error)"
        }
    }

    static func unregisterBundledDaemon() {
        try? service.unregister()
    }

    // MARK: - Quiet self-update

    /// Whether the installed daemon can swap its own binary on request.
    static func canSelfUpdate(daemonProtocolVersion: Int) -> Bool {
        isSigned && bundledHelperPath != nil && daemonProtocolVersion >= 6
    }

    /// Ask the running daemon to replace itself with the binary in this bundle.
    ///
    /// The daemon re-verifies the signature itself — passing a path is a claim, and the side
    /// holding root privileges is the side that has to check it.
    static func requestQuietUpdate() -> (ok: Bool, message: String) {
        guard let path = bundledHelperPath else {
            return (false, "No bundled helper to update from.")
        }
        guard let response = try? ControlClient.send(.installUpdate(path: path)) else {
            return (false, "The helper didn't answer the update request.")
        }
        return (response.ok, response.message ?? (response.ok ? "Helper updated." : "Update refused."))
    }
}
