import SwiftUI
import AppKit

/// The menu-bar item and its dropdown, owned here rather than by SwiftUI's `MenuBarExtra`.
///
/// `MenuBarExtra(.window)` builds its panel once and reuses that window for the life of the
/// process. After hours of running, that window could come loose from the view graph behind
/// it: clicks still arrived (AppKit tracked them and sent the action) but no SwiftUI action
/// ran and nothing redrew, so every control in the panel was dead until eWiz was relaunched.
/// Here the panel and its hosting view are built on every open and thrown away on close, so
/// there is no long-lived panel to go stale.
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var labelHost: StatusLabelHostingView?
    private var panel: MenuPanel?
    private var makePanelContent: (() -> AnyView)?
    private var outsideClickMonitor: Any?
    /// When the panel last closed because it lost focus. Clicking the status item while the
    /// panel is open takes focus first, closing it, and then delivers the click — which
    /// would open it straight back up.
    private var lastResignClose = Date.distantPast

    /// Idempotent: the App's body, which calls this, is evaluated more than once.
    func install(label: () -> AnyView, panel content: @escaping () -> AnyView) {
        guard statusItem == nil else { return }
        makePanelContent = content

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = item.button else { return }
        button.target = self
        button.action = #selector(togglePanel)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let host = StatusLabelHostingView(rootView: label())
        host.translatesAutoresizingMaskIntoConstraints = false
        host.onSizeChange = { [weak self] in self?.fitStatusItem() }
        button.addSubview(host)
        NSLayoutConstraint.activate([
            host.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            host.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        statusItem = item
        labelHost = host
        fitStatusItem()
    }

    /// The status item is as wide as the label plus the menu bar's usual side padding.
    private func fitStatusItem() {
        guard let item = statusItem, let host = labelHost else { return }
        let width = ceil(host.fittingSize.width) + 8
        if abs(item.length - width) > 0.5 { item.length = width }
        // A length change redraws the button and drops the open-panel highlight.
        if panel != nil { item.button?.highlight(true) }
    }

    @objc private func togglePanel() {
        if panel != nil {
            closePanel()
        } else if Date().timeIntervalSince(lastResignClose) > 0.3 {
            openPanel()
        }
    }

    private func openPanel() {
        guard let content = makePanelContent, let button = statusItem?.button,
              let buttonWindow = button.window else { return }

        // The window takes its size from the content's own constraints, in the same layout
        // pass as the content changes. Left to `WindowSizer`, which resizes on the next
        // runloop turn, every mode switch drew one frame of content in the old-size window.
        let host = NSHostingView(rootView: content())
        host.sizingOptions = [.minSize, .maxSize]
        let size = host.fittingSize

        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen ?? NSScreen.main
        var origin = NSPoint(x: anchor.minX, y: anchor.minY - 2 - size.height)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        }

        let panel = MenuPanel(contentRect: NSRect(origin: origin, size: size))
        panel.top = anchor.minY - 2
        panel.contentView = host
        panel.onResignKey = { [weak self] in
            self?.lastResignClose = Date()
            self?.closePanel()
        }
        panel.onCancel = { [weak self] in self?.closePanel() }
        self.panel = panel

        button.highlight(true)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)

        // Clicks in another app don't always take focus from us first (a menu bar, the
        // desktop), so close on any click outside our own windows too.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
    }

    private func closePanel() {
        guard let panel else { return }
        self.panel = nil
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        statusItem?.button?.highlight(false)
        panel.onResignKey = nil
        panel.orderOut(nil)
        // Detach the content so its `onDisappear` runs and the view graph goes with it.
        panel.contentView = nil
    }
}

/// Borderless, so the content draws its own rounded surface (`dsMenuPanel`), but able to
/// become key so the controls inside take clicks and keyboard focus.
private final class MenuPanel: NSPanel {
    var onResignKey: (() -> Void)?
    var onCancel: (() -> Void)?
    /// Where the panel hangs from, in screen coordinates. Every resize keeps this edge put,
    /// whatever drives it, so the panel grows and shrinks downwards from the menu bar.
    var top: CGFloat?

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
    }

    override var canBecomeKey: Bool { true }

    /// Keep it on screen whatever sets the frame. The content measures near zero before its
    /// first layout, so a clamp at open time saw no width, and `WindowSizer` then grew the
    /// panel rightwards off the edge.
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        var frame = frameRect
        if let top { frame.origin.y = top - frame.height }
        if let visible = (screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, visible.minX + 8),
                                 visible.maxX - frame.width - 8)
        }
        super.setFrame(frame, display: flag)
    }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    /// Esc closes it, as it does a menu.
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// The SwiftUI label inside the status item's button. Clicks pass through to the button,
/// and a size change re-fits the item so the percentage text never gets clipped.
private final class StatusLabelHostingView: NSHostingView<AnyView> {
    var onSizeChange: (() -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        DispatchQueue.main.async { [weak self] in self?.onSizeChange?() }
    }
}
