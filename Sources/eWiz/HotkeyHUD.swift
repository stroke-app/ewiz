import SwiftUI
import AppKit

/// What a shortcut notification is showing. Kept in a model rather than rebuilt as a
/// new view each time so a second shortcut swaps the text inside the panel that's
/// already on screen — no teardown, no re-entrance, nothing moves.
@MainActor
private final class NotificationModel: ObservableObject {
    @Published var title = ""
    @Published var detail: String?
    /// HugeIcons key for the glyph in the icon tile (nil = fall back to the app icon).
    @Published var icon: String?
}

/// The notification a global shortcut posts so it's obvious it fired.
///
/// Without it, a shortcut for something invisible — Low Power Mode, force discharge —
/// is indistinguishable from a shortcut that isn't registered at all. Shaped like a
/// real macOS notification (app icon, title, body, top-right) rather than a bespoke
/// HUD, because that's the language the user already reads as "the system told me
/// something".
///
/// Geometry is fixed: one width, one height, one position, for every message. Nothing
/// resizes or reflows between notifications — the only thing that changes is the text.
@MainActor
final class HotkeyHUD {
    static let shared = HotkeyHUD()

    /// Real notification metrics: 344pt wide is what Notification Center uses, and a
    /// fixed height means a title-only message and a title+body message occupy exactly
    /// the same box.
    private let size = CGSize(width: 344, height: 74)
    private let screenInset: CGFloat = 14
    private let visibleFor: TimeInterval = 1.9
    /// How far it slides in from, and back out to.
    private let slide: CGFloat = 20

    private let model = NotificationModel()
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    private init() {}

    func show(_ title: String, detail: String? = nil, icon: String? = nil) {
        dismissal?.cancel()

        model.title = title
        model.detail = detail
        model.icon = icon

        let panel = self.panel ?? makePanel()
        self.panel = panel

        // Already up: just swap the text and restart the clock. Re-animating an
        // on-screen notification would make a second shortcut look like a glitch.
        let wasVisible = panel.isVisible && panel.alphaValue > 0.01
        if !wasVisible { animateIn(panel) }

        dismissal = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.visibleFor ?? 1.9) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.animateOut()
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isFloatingPanel = true
        // Above everything including full-screen apps, like a real notification.
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // The window shadow, not a drawn one — it's what every other floating panel
        // on the system casts, so this sits in the same visual plane as them.
        panel.hasShadow = true
        // Never take focus or swallow a click: the user is in another app when this
        // fires, and a notification they can't click through is a notification in
        // the way.
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle,
                                   .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: NotificationView(model: model))
        panel.setContentSize(size)
        return panel
    }

    /// Top-right of whichever screen has the mouse — where notifications live.
    /// `visibleFrame` already excludes the menu bar.
    private func restingOrigin() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return .zero }
        return NSPoint(x: frame.maxX - size.width - screenInset,
                       y: frame.maxY - size.height - screenInset)
    }

    private func animateIn(_ panel: NSPanel) {
        let resting = restingOrigin()
        guard !reduceMotion else {
            panel.setFrameOrigin(resting)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            return
        }
        // Enters from the right edge it lives on, so the motion reads as "arriving
        // from off-screen" — and it leaves the same way. Never from scale(0): it
        // starts already the right size, just displaced.
        panel.setFrameOrigin(NSPoint(x: resting.x + slide, y: resting.y))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = .easeOutStrong
            panel.animator().setFrameOrigin(resting)
            panel.animator().alphaValue = 1
        }
    }

    private func animateOut() {
        guard let panel, panel.isVisible else { return }
        guard !reduceMotion else { panel.orderOut(nil); return }
        // Exit is quicker and shorter than the entrance: arriving deserves attention,
        // leaving shouldn't ask for any.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = .easeOutStrong
            panel.animator().setFrameOrigin(NSPoint(x: panel.frame.origin.x + slide * 0.6,
                                                    y: panel.frame.origin.y))
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            // Guard against a notification that arrived mid-fade being hidden.
            if let panel, panel.alphaValue < 0.01 { panel.orderOut(nil) }
        }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

private extension CAMediaTimingFunction {
    /// The built-in easings are too weak to read as intentional at 200ms. Computed
    /// rather than stored: `CAMediaTimingFunction` isn't `Sendable`, so a static
    /// instance would be shared mutable state.
    static var easeOutStrong: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
    }
}

private struct NotificationView: View {
    @ObservedObject var model: NotificationModel

    var body: some View {
        HStack(spacing: 12) {
            iconTile

            VStack(alignment: .leading, spacing: 1) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let detail = model.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            // Centred, so a title-only message sits in the middle of the same box a
            // title+body message fills — the height never changes either way.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .frame(width: 344, height: 74)
        .background(.regularMaterial, in: shape)
        .overlay(shape.strokeBorder(.primary.opacity(0.07), lineWidth: 1))
        // Clip so the material can't bleed past the corners over the window shadow.
        .clipShape(shape)
    }

    /// A tile the size and shape of the app icon a notification would show, holding the
    /// glyph of whatever just happened — the icon says "force discharge" or "charge
    /// limit" before the title is read, which the app icon (identical every time)
    /// never could. Same geometry either way, so nothing shifts when a message has no
    /// glyph and falls back to the app icon.
    @ViewBuilder
    private var iconTile: some View {
        if let key = model.icon {
            HugeIcon(key, size: 21, weight: 1.9)
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(.primary.opacity(0.06), in: tileShape)
                // Pure white/black at low opacity — a tinted outline picks up the
                // material behind it and reads as grime on the tile's edge.
                .overlay(tileShape.strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        } else {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 38, height: 38)
                .clipShape(tileShape)
                .overlay(tileShape.strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        }
    }

    /// Concentric with the banner: 18 outer − 14 of padding ≈ 9 at the icon.
    private var tileShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
    }

    /// Matches the radius the system uses on notification banners.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }
}
