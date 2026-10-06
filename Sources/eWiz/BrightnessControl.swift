import Foundation
import CoreGraphics

/// Reads/sets display brightness via the private DisplayServices framework — the
/// same path tools like `brightness` use. Loaded with dlopen/dlsym so we don't link
/// a private framework, and degrade gracefully if the symbols ever move (isSupported
/// goes false, callers no-op). Works on built-in and many external displays across
/// macOS 12–15 on both Apple Silicon and Intel. No root needed — runs in the GUI.
enum BrightnessControl {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    // Loaded once, read-only thereafter — safe to share across threads.
    nonisolated(unsafe) private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)

    nonisolated(unsafe) private static let getFn: GetFn? = handle
        .flatMap { dlsym($0, "DisplayServicesGetBrightness") }
        .map { unsafeBitCast($0, to: GetFn.self) }
    nonisolated(unsafe) private static let setFn: SetFn? = handle
        .flatMap { dlsym($0, "DisplayServicesSetBrightness") }
        .map { unsafeBitCast($0, to: SetFn.self) }

    static var isSupported: Bool { getFn != nil && setFn != nil }

    /// Brightness of the main display, 0…1, or nil if it can't be read.
    static func current() -> Float? {
        guard let getFn else { return nil }
        var value: Float = 0
        return getFn(CGMainDisplayID(), &value) == 0 ? value : nil
    }

    /// Set brightness (0…1) on every active display. Returns true if any accepted it.
    @discardableResult
    static func set(_ value: Float) -> Bool {
        guard let setFn else { return false }
        let clamped = min(1, max(0, value))
        var ok = false
        for id in activeDisplays() where setFn(id, clamped) == 0 { ok = true }
        return ok
    }

    private static func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return [CGMainDisplayID()] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return Array(ids.prefix(Int(count)))
    }
}
