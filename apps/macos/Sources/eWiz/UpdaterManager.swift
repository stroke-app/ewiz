import Combine
import Foundation
import Sparkle

/// In-app updates, through Sparkle: a check on launch and daily, or on demand; then its
/// window takes over (checking → what's new → download progress → installing), the app
/// quits, and the new version comes back up. This is the thin layer SwiftUI observes:
/// whether a check can start, and whether the last one found something.
///
/// Everything that decides whether an update is trusted lives in Info.plist and
/// `UpdateSignature`: `SUPublicEDKey` is the release key, and Sparkle refuses a download
/// whose `sparkle:edSignature` the key doesn't verify. The app is ad-hoc signed, so that
/// signature is the whole chain of trust. Sparkle allows that: its Developer ID match is
/// one of two accepted proofs ("Either DSA must be valid, or Apple Code Signing must be
/// valid" — SUUpdateValidator.m), and with no team on either side only EdDSA can pass.
@MainActor
final class UpdaterManager: ObservableObject {
    /// Whether "Check for Updates…" can start a check right now; false while one runs.
    @Published private(set) var canCheckForUpdates = false
    /// The version the last check found, for the banners; nil once the app is up to date.
    @Published private(set) var availableVersion: String?

    let currentVersion: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"

    private let controller: SPUStandardUpdaterController
    private let observer = UpdateObserver()

    init() {
        controller = SPUStandardUpdaterController(startingUpdater: false,
                                                  updaterDelegate: observer,
                                                  userDriverDelegate: nil)
        observer.onChange = { [weak self] version in self?.availableVersion = version }
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        // Sparkle reads SUFeedURL and SUPublicEDKey from the bundle, which only the
        // packaged app has (scripts/package-app.sh writes them). A bare `swift run` binary
        // would get a "misconfigured" alert a second after launch; leave its updater
        // unstarted instead, so the buttons stay disabled and nothing else changes.
        if Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil {
            controller.startUpdater()
        }
    }

    /// A check the user asked for. Sparkle's window handles it from here, and says so
    /// when there is nothing new. While an update is already waiting (the banner), this
    /// brings that window forward rather than starting over.
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Sparkle's delegate, apart from the manager because the updater takes its delegate when
/// it's created, before `self` exists. Sparkle calls these on the main thread.
private final class UpdateObserver: NSObject, SPUUpdaterDelegate {
    var onChange: (@MainActor (String?) -> Void)?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        MainActor.assumeIsolated { onChange?(version) }
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        MainActor.assumeIsolated { onChange?(nil) }
    }
}
