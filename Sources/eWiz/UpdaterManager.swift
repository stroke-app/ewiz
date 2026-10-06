import Foundation
import Combine
import AppKit
import Security
import EWizKit

/// In-app update checks against a public JSON feed: on launch, daily, and on demand.
@MainActor
final class UpdaterManager: ObservableObject {
    @Published private(set) var available: AppUpdate?
    @Published private(set) var checking = false
    @Published private(set) var installing = false
    @Published private(set) var lastResult: String?

    /// Public update feed (any host reachable without auth).
    let feedURL = EWizLinks.updateFeed

    let currentVersion: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"

    private var timer: Timer?

    init() {
        check(userInitiated: false)
        let t = Timer(timeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check(userInitiated: false) }
        }
        t.tolerance = 3600   // daily check; an hour of slack lets the OS batch it
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func check(userInitiated: Bool) {
        guard !checking else { return }
        checking = true
        let feed = feedURL
        let current = currentVersion
        Task.detached {
            var found: AppUpdate?
            var message: String?
            do {
                found = try await UpdateChecker.check(feedURL: feed, currentVersion: current)
                message = found == nil ? "You're up to date (v\(current))." : nil
            } catch {
                message = "Couldn't check for updates."
            }
            let result = found
            let msg = message
            await MainActor.run {
                self.available = result
                self.lastResult = msg
                self.checking = false
                if userInitiated, result == nil {
                    self.showInfoAlert(msg ?? "You're up to date.")
                }
            }
        }
    }

    /// Open the DMG in the browser — manual fallback when the in-place installer can't run.
    func downloadAvailable() {
        guard let u = available?.url else { return }
        NSWorkspace.shared.open(u)
    }

    /// Download and install the update in place, then relaunch. Falls back to opening
    /// the DMG if the automatic path is blocked (e.g. app lives somewhere unwritable).
    func installUpdate() {
        guard !installing, let url = available?.url else { return }
        let bundlePath = Bundle.main.bundlePath
        let parent = (bundlePath as NSString).deletingLastPathComponent

        // Fail fast (before we download or quit) if we can't replace the bundle.
        guard FileManager.default.isWritableFile(atPath: parent) else {
            showInfoAlert("eWiz can't update itself here because \(parent) isn't writable. Opening the download so you can install it manually.")
            downloadAvailable()
            return
        }

        // No signing identity means nothing to verify the replacement against, and a
        // signature check with nothing to check against is decoration. Hand it to the
        // browser instead, where the user downloads it themselves and Gatekeeper applies.
        guard let team = HelperService.teamIdentifier else {
            showInfoAlert("This build isn't Developer ID signed, so eWiz won't replace itself automatically. Opening the download so you can install it manually.")
            downloadAvailable()
            return
        }

        installing = true
        lastResult = nil
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundleID = Bundle.main.bundleIdentifier ?? "com.ewiz.app"
        Task.detached {
            do {
                try await Self.performInstall(from: url, bundlePath: bundlePath, pid: pid,
                                              bundleID: bundleID, team: team)
                // The swap script now waits for us to quit, then relaunches.
                await MainActor.run { NSApplication.shared.terminate(nil) }
            } catch {
                await MainActor.run {
                    self.installing = false
                    self.showInfoAlert("Couldn't install the update automatically (\(error.localizedDescription)). Opening the download so you can install it manually.")
                    self.downloadAvailable()
                }
            }
        }
    }

    // MARK: - In-place install (Sparkle-lite)

    private enum UpdaterError: LocalizedError {
        case appNotFoundInDMG
        case rejected(String)
        case tool(String, String)

        var errorDescription: String? {
            switch self {
            case .appNotFoundInDMG: return "the update disk image didn't contain eWiz.app"
            case .rejected(let why): return "the downloaded update was rejected: \(why)"
            case .tool(let name, let msg):
                let detail = msg.trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(name) failed" + (detail.isEmpty ? "" : ": \(detail)")
            }
        }
    }

    // MARK: - Trust

    /// Refuse to install anything not signed by the team that signed what's running.
    ///
    /// This is the check the helper's own update path has had all along, and the reason it
    /// gives applies with more force here: `HelperUpdate` says "a path from a client is a
    /// claim, not evidence", and a URL out of a JSON feed is exactly the same kind of
    /// claim. Up to now the only thing standing between that feed and `ditto` over the
    /// running app was TLS to raw.githubusercontent.com — and the script then stripped
    /// `com.apple.quarantine`, so Gatekeeper never looked at the result either. Whoever
    /// could write to the release repo could replace the app on every install, silently.
    ///
    /// `anchor apple generic` pins the chain to Apple's Developer ID root, so a self-signed
    /// certificate carrying the right OU doesn't pass. Evaluated by the Security framework
    /// against the bundle on disk, not against anything the feed said about it.
    nonisolated private static func verify(bundleAt path: String, matchesTeam team: String) throws {
        var candidate: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &candidate)
                == errSecSuccess, let candidate else {
            throw UpdaterError.rejected("the update has no readable code signature")
        }

        var requirement: SecRequirement?
        let text = "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess,
              let requirement else {
            throw UpdaterError.rejected("could not build a signing requirement")
        }

        var error: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(
            candidate, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement, &error)
        guard status == errSecSuccess else {
            throw UpdaterError.rejected(error?.takeRetainedValue().localizedDescription
                                        ?? "it isn't signed by team \(team)")
        }
    }

    /// Download, mount, and hand off to a detached script that waits for this process
    /// to exit, swaps the bundle, and relaunches. Off the main actor — local files only.
    nonisolated private static func performInstall(from url: URL, bundlePath: String, pid: Int32,
                                                   bundleID: String, team: String) async throws {
        let fm = FileManager.default
        let tmp = NSTemporaryDirectory()
        let stamp = UUID().uuidString

        // 1. Download the DMG to a stable temp path.
        let (downloaded, _) = try await URLSession.shared.download(from: url)
        let dmgPath = tmp + "ewiz-update-\(stamp).dmg"
        try? fm.removeItem(atPath: dmgPath)
        try fm.moveItem(atPath: downloaded.path, toPath: dmgPath)

        // 2. Mount it on a private, non-browsable mount point.
        let mountPoint = tmp + "ewiz-mnt-\(stamp)"
        try fm.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)
        try runTool("/usr/bin/hdiutil",
                    ["attach", dmgPath, "-nobrowse", "-noverify", "-mountpoint", mountPoint])

        // 3. Locate the .app inside the image.
        let appName = (bundlePath as NSString).lastPathComponent   // e.g. "eWiz.app"
        let srcApp = mountPoint + "/" + appName
        guard fm.fileExists(atPath: srcApp) else {
            try? runTool("/usr/bin/hdiutil", ["detach", mountPoint, "-quiet"])
            throw UpdaterError.appNotFoundInDMG
        }

        // 3a. Before a swap script is even written. Everything past this point runs
        //     detached, after this process has exited, with nobody left to refuse.
        do {
            try verify(bundleAt: srcApp, matchesTeam: team)
        } catch {
            try? runTool("/usr/bin/hdiutil", ["detach", mountPoint, "-quiet"])
            try? fm.removeItem(atPath: dmgPath)
            throw error
        }

        // 4. Swap-and-relaunch script: waits for THIS pid to exit so it never overwrites
        //    a running bundle, keeps a .bak to roll back, refreshes Launch Services (else
        //    the new bundle is shadowed by a stale registration). Output goes to a log
        //    file so the parent's closing pipes can't SIGPIPE it.
        let logPath = tmp + "ewiz-update.log"
        let script = """
        #!/bin/bash
        exec >>"\(logPath)" 2>&1
        echo "=== $(date) eWiz updater (pid \(pid)) ==="
        while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.2; done
        echo "app exited; installing update"
        if /usr/bin/ditto "\(srcApp)" "\(bundlePath).new"; then
          /usr/bin/xattr -dr com.apple.quarantine "\(bundlePath).new" 2>/dev/null || true
          /bin/rm -rf "\(bundlePath).bak"
          # This `mv` has to succeed before the next one runs. `mv new old` where `old` is
          # still a directory does not fail — it moves `new` *inside* it — so a tolerated
          # failure here left a eWiz.app/eWiz.app.new, printed "swap ok" and threw
          # the backup away.
          if /bin/mv "\(bundlePath)" "\(bundlePath).bak"; then
            if /bin/mv "\(bundlePath).new" "\(bundlePath)"; then
              echo "swap ok"
              /bin/rm -rf "\(bundlePath).bak"
            else
              echo "swap failed; restoring backup"
              /bin/rm -rf "\(bundlePath)"
              /bin/mv "\(bundlePath).bak" "\(bundlePath)" 2>/dev/null || true
            fi
          else
            echo "could not move the old bundle aside; leaving it where it is"
            /bin/rm -rf "\(bundlePath).new"
          fi
        else
          echo "ditto failed"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "\(bundlePath)" 2>/dev/null || true
        /usr/bin/hdiutil detach "\(mountPoint)" -quiet 2>/dev/null || /usr/bin/hdiutil detach "\(mountPoint)" -force 2>/dev/null || true
        /bin/rm -f "\(dmgPath)"
        /bin/rmdir "\(mountPoint)" 2>/dev/null || true
        LSREG="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
        "$LSREG" -f "\(bundlePath)" 2>/dev/null || true
        # Give LaunchServices a moment to settle after the swap+re-register, then
        # relaunch with verification: `open` occasionally reports success without
        # actually bringing the app up (freshly-swapped bundle, lingering launch
        # state). Retry until the process is visible, checking first so we never
        # spawn a duplicate. `-n` forces a new instance rather than trying to
        # activate a stale record of the app that just quit; fall back to a plain
        # open and finally a launch by bundle id.
        EXEC="\(bundlePath)/Contents/MacOS"
        /bin/sleep 1
        for i in 1 2 3 4 5 6; do
          if /usr/bin/pgrep -f "$EXEC/" >/dev/null 2>&1; then echo "relaunch confirmed (try $i)"; break; fi
          echo "relaunch attempt $i"
          /usr/bin/open -n "\(bundlePath)" 2>/dev/null \
            || /usr/bin/open "\(bundlePath)" 2>/dev/null \
            || /usr/bin/open -b "\(bundleID)" 2>/dev/null || true
          /bin/sleep 1.5
        done
        /usr/bin/pgrep -f "$EXEC/" >/dev/null 2>&1 || echo "warning: app not visibly running after relaunch attempts"
        echo "done"
        /bin/rm -f "$0"
        """
        let scriptPath = tmp + "ewiz-update-\(stamp).sh"
        try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

        // 5. Launch fully detached (nohup) so it survives this app terminating — a direct
        //    child can be torn down with the parent before finishing the swap/relaunch.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "/usr/bin/nohup /bin/bash \"\(scriptPath)\" >/dev/null 2>&1 &"]
        try p.run()
    }

    nonisolated private static func runTool(_ path: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let err = Pipe()
        p.standardError = err
        p.standardOutput = Pipe()
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw UpdaterError.tool((path as NSString).lastPathComponent, msg)
        }
    }

    private func showInfoAlert(_ text: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "eWiz"
        alert.informativeText = text
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
