import Foundation
import IOKit
import CoreGraphics

/// Small IOKit helpers for system power state, shared by the GUI and daemon.
public enum SystemPower {
    /// Reads `AppleClamshellState` from IOPMrootDomain (true = lid closed).
    /// Returns false if the property is missing (e.g. desktops).
    public static func isClamshellClosed() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard let value = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Bool
        else { return false }
        return value
    }

    /// What the Mac is currently driving, as far as it can be established.
    public enum DisplaySet: String, Sendable {
        /// The built-in panel and nothing else.
        case builtInOnly
        /// At least one display that isn't the built-in panel.
        case externalAttached
        /// Nothing could be read — no window-server session to ask, typically.
        case unknown
    }

    /// Which displays are online.
    ///
    /// Asked by anything that wants to blank "the display" while the lid is shut, because
    /// `pmset displaysleepnow` blanks *every* display: with a monitor on the desk, the one
    /// it turns off is the one being looked at. A root daemon has no window-server session
    /// and may not be able to answer at all, so `unknown` is a real outcome and callers
    /// must decide what to do with it rather than reading it as "no monitor".
    public static func displays() -> DisplaySet {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return .unknown }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success, count > 0 else { return .unknown }
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
            ? .externalAttached : .builtInOnly
    }
}
