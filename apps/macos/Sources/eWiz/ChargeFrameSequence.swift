import AppKit

/// A charging animation supplied as image frames, so the built-in three aren't the limit.
///
/// This is the practical answer to "use a Rive animation": Rive, After Effects, Lottie and
/// every other motion tool can export a numbered image sequence, and an image sequence
/// needs no third-party runtime, no Metal view, and no binary format to parse — it just
/// draws. Export frames, drop them in the folder, pick "Custom" and they play.
///
/// Deliberate limits, because this runs over everything you're doing for about a second:
///   - 120 frames, loaded once and cached. A one-second animation is 60 frames at 60fps;
///     twice that is already more than the window is open for.
///   - Files are read in sorted filename order, which is what every exporter produces
///     (`frame_001.png`, `frame_002.png`, …).
///   - The sequence is scaled to fit the screen and centred, aspect preserved, so a
///     square export doesn't come out stretched on a 16:10 display.
enum ChargeFrameSequence {

    /// Where frames go. Under the user's own Application Support, not the daemon's
    /// system-wide directory: these are personal assets, not machine policy.
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/eWiz/ChargeAnimation",
                                    isDirectory: true)
    }

    static let maxFrames = 120

    private static let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "gif"]

    /// Cached frames plus the folder's modification date, so replacing the sequence takes
    /// effect without relaunching but a replay doesn't re-read the disk.
    @MainActor private static var cache: (stamp: Date, frames: [NSImage])?

    /// Frame files currently in the folder, in play order.
    static func frameURLs() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])) ?? []
        return urls
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(maxFrames)
            .map { $0 }
    }

    @MainActor static func frames() -> [NSImage] {
        let stamp = (try? folder.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
        if let cache, cache.stamp == stamp { return cache.frames }
        let loaded = frameURLs().compactMap { NSImage(contentsOf: $0) }
        cache = (stamp, loaded)
        return loaded
    }

    /// The frame to show at `t` (0…1) through the animation. Nil when there's nothing to
    /// play, which the overlay treats as "fall back to a built-in style" rather than
    /// showing an empty screen.
    @MainActor static func frame(at t: Double) -> NSImage? {
        let all = frames()
        guard !all.isEmpty else { return nil }
        let index = min(all.count - 1, max(0, Int(t * Double(all.count))))
        return all[index]
    }

    /// Create the folder if needed and show it in Finder, so "where do I put them" is one
    /// click rather than a path in a caption to be copied by hand.
    @MainActor static func revealInFinder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}
