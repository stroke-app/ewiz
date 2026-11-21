import Foundation
import Combine
import AppKit
import CoreGraphics

// Private DisplayServices brightness control (no public API exists; used by apps
// like MonitorControl). Runs as the user — no root, no TCC prompt.
@_silgen_name("DisplayServicesGetBrightness")
private func DisplayServicesGetBrightness(_ id: CGDirectDisplayID, _ b: UnsafeMutablePointer<Float>) -> Int32
@_silgen_name("DisplayServicesSetBrightness")
private func DisplayServicesSetBrightness(_ id: CGDirectDisplayID, _ b: Float) -> Int32

@MainActor
final class SystemActions: ObservableObject {
    @Published private(set) var dimmed = false

    private var savedBrightness: Float?
    private let dimLevel: Float = 0.2

    // MARK: - Brightness

    private func brightness() -> Float? {
        var value: Float = 0
        return DisplayServicesGetBrightness(CGMainDisplayID(), &value) == 0 ? value : nil
    }

    func dimDisplay() {
        if let cur = brightness() { savedBrightness = cur }
        _ = DisplayServicesSetBrightness(CGMainDisplayID(), dimLevel)
        dimmed = true
    }

    func restoreBrightness() {
        let target = savedBrightness ?? 0.7
        _ = DisplayServicesSetBrightness(CGMainDisplayID(), target)
        dimmed = false
    }

    func toggleDim() { dimmed ? restoreBrightness() : dimDisplay() }

    // MARK: - Display off / sleep (pmset, no root needed for *now actions)

    func turnDisplayOff() {
        // Delay before sleeping: the triggering click plus the popover closing count as
        // user activity and would wake the display right back up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.run("/usr/bin/pmset", ["displaysleepnow"])
        }
    }

    func sleepNow() { run("/usr/bin/pmset", ["sleepnow"]) }

    private func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try? p.run()
    }
}
