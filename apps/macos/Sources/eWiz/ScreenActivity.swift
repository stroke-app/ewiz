import Foundation
import AppKit
import IOKit.pwr_mgt

/// Is the Mac being *watched*, rather than merely untouched?
///
/// The idle timer only knows about the keyboard, the mouse and the trackpad — none of
/// which move during a film, a video call, or a game played on a controller. Resting on
/// that signal alone blanks the screen halfway through a movie, which is the one thing
/// this feature must never do. Two signals answer what the idle timer can't:
///
///   1. A display-sleep power assertion held by another process. Video players, browsers
///      playing video, video calls, presentations and most games take one for exactly
///      this reason — it is macOS's own "someone is looking at this, don't sleep it".
///   2. A full-screen window whose owner is burning CPU. Catches the games and the
///      players that never bother with the assertion. The CPU test is what keeps a
///      full-screen editor, left open and idle for an hour, from counting as activity.
enum ScreenActivity {
    /// Why resting should wait — phrased for the Settings status line.
    enum Reason {
        case displayAssertion
        case fullScreenApp

        var text: String {
            switch self {
            case .displayAssertion: return "an app is keeping the screen awake"
            case .fullScreenApp:    return "a full-screen app is busy"
            }
        }
    }

    /// Nil when nothing is holding the screen. Cheap enough for the once-a-minute idle
    /// poll: the assertion read is a single IOKit call, and only a genuinely full-screen
    /// window costs a `ps`.
    ///
    /// - Parameter includingFullScreen: pass `false` where only macOS's own rule applies
    ///   — a held assertion — and a busy full-screen app is not reason enough to stop.
    static func busyReason(includingFullScreen: Bool = true) -> Reason? {
        if hasForeignDisplayAssertion() { return .displayAssertion }
        if includingFullScreen, hasBusyFullScreenWindow() { return .fullScreenApp }
        return nil
    }

    // MARK: - Power assertions

    /// Both spellings: apps built against the modern type and the older one that a lot of
    /// shipping software still uses.
    private static let displayAssertionTypes: Set<String> = [
        kIOPMAssertionTypePreventUserIdleDisplaySleep as String,
        kIOPMAssertionTypeNoDisplaySleep as String,
    ]

    /// True if any process *other than ours* is holding the display awake. Our own holds
    /// are excluded deliberately: the eWiz daemon keeps a **system** idle-sleep
    /// assertion while it enforces a charge limit, and resting has always been allowed to
    /// run alongside that — counting it would mean a plugged-in Mac never rests at all.
    private static func hasForeignDisplayAssertion() -> Bool {
        var out: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&out) == kIOReturnSuccess,
              let byProcess = out?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return false }

        let mine = getpid()
        for (owner, assertions) in byProcess where owner.int32Value != mine {
            for assertion in assertions {
                // Level 0 is a registered-but-released assertion; it holds nothing.
                if let level = assertion[kIOPMAssertionLevelKey as String] as? Int, level == 0 { continue }
                guard let type = assertion[kIOPMAssertionTypeKey as String] as? String else { continue }
                if displayAssertionTypes.contains(type) { return true }
            }
        }
        return false
    }

    // MARK: - Full-screen apps

    /// CPU% (of one core, `ps`'s decaying average) above which a full-screen app is
    /// taken to be rendering something — a game or a player — rather than just sitting there.
    private static let busyCPU: Double = 20

    private static func hasBusyFullScreenWindow() -> Bool {
        guard let owner = fullScreenWindowOwner() else { return false }
        return cpuPercent(of: owner) >= busyCPU
    }

    /// The PID behind a window that exactly covers a display. A full-screen app covers the
    /// menu bar too, so its window matches the display frame outright — a merely zoomed
    /// window stops short of it and doesn't count.
    private static func fullScreenWindowOwner() -> pid_t? {
        let displays = Displays.onlineBounds()
        guard !displays.isEmpty,
              let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        else { return nil }

        let mine = Int(getpid())
        for window in windows {
            // Layer 0 is the normal window level: not the menu bar, the Dock, or an overlay.
            guard window[kCGWindowLayer as String] as? Int == 0,
                  let owner = window[kCGWindowOwnerPID as String] as? Int, owner != mine,
                  let raw = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  displays.contains(where: { covers($0, bounds) })
            else { continue }
            return pid_t(owner)
        }
        return nil
    }

    /// The window swallows the display whole, give or take the point that window and
    /// display geometry disagree by once scaling is involved. Containment rather than
    /// equality, so a full-screen window reported a hair larger than its display still
    /// counts — while a merely zoomed window, which stops below the menu bar, doesn't.
    private static func covers(_ display: CGRect, _ window: CGRect) -> Bool {
        window.insetBy(dx: -1, dy: -1).contains(display)
    }

    /// One process's CPU%, via `ps` — the same source the rest of the app uses, and cheap
    /// because it's only reached when a full-screen window actually exists.
    private static func cpuPercent(of pid: pid_t) -> Double {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-p", String(pid), "-o", "%cpu="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return 0 }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(text) ?? 0
    }
}

/// The attached displays, read once per call — no notifications to keep in sync.
enum Displays {
    static func onlineIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// Global (top-left origin) bounds, matching what `CGWindowListCopyWindowInfo` reports.
    static func onlineBounds() -> [CGRect] { onlineIDs().map(CGDisplayBounds) }

    /// True if any non-built-in display is online.
    static func hasExternal() -> Bool { onlineIDs().contains { CGDisplayIsBuiltin($0) == 0 } }
}
