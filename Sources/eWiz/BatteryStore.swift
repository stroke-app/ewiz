import Foundation
import IOKit.ps
import Combine
import AppKit
import EWizKit

extension Notification.Name {
    /// Posted when charging toggles so views can re-read without waiting for the slow poll.
    static let ewizChargeStateChanged = Notification.Name("EWizChargeStateChanged")
}

/// Observable wrapper around BatteryMonitor: instant updates via an IOKit run-loop
/// source, plus a slow fallback timer for values IOKit doesn't notify (temp, cycles).
@MainActor
final class BatteryStore: ObservableObject {
    @Published private(set) var snapshot: BatterySnapshot = .unknown
    /// Live power flow (adapter/battery/system watts).
    @Published private(set) var powerFlow: PowerFlow = .unknown

    private var timer: Timer?
    private var powerTimer: Timer?
    private var powerViewers = 0
    private var runLoopSource: CFRunLoopSource?

    init() {
        refresh()
        startPolling()
        startPowerSourceNotifications()
        // Refresh right after the Mac wakes so the menu isn't stale.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        // SMC change takes a moment to surface in IOKit, so poll a few times over a few seconds.
        NotificationCenter.default.addObserver(
            forName: .ewizChargeStateChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refreshSoon() }
        }
    }

    /// Refresh now and again over the next ten seconds, to catch a change once IOKit
    /// reflects it.
    ///
    /// Two seconds wasn't enough. When the adapter comes back the charger negotiates
    /// before current flows, and `IsCharging` turns over several seconds later with no
    /// notification of its own, so the last read landed on "not charging" and the panel
    /// kept it until the 30 s poll.
    func refreshSoon() {
        refresh()
        for delay in [0.5, 2.0, 5.0, 10.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }

    // No deinit cleanup: owned by the App for the process lifetime.

    func refresh() {
        var new = BatteryMonitor.read()
        // The sensor jitters by hundredths of a degree. Round to what's actually
        // displayed, so idle noise can't make every poll look like a change.
        if let celsius = new.temperature { new.temperature = (celsius * 10).rounded() / 10 }
        // Republishing an identical snapshot costs a full status-item relayout —
        // and, via the notification manager's objectWillChange sink, a main-actor
        // hop per subscriber. Only publish real changes.
        if new != snapshot { snapshot = new }

        // Live watts only appear in the popover and Details window. With neither
        // open, skip the IORegistry walk and the publish entirely.
        guard powerViewers > 0 else { return }
        let flow = PowerMonitor.read()
        if flow != powerFlow { powerFlow = flow }
    }

    private func startPolling() {
        // Fallback for values IOKit doesn't notify (temp, cycles); IOPS handles instant changes.
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 15   // this is only a fallback poll; let the OS coalesce it
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Live watts only show in the open popover and the Details window, so poll for
    /// them only while one is visible (call from `.onAppear`). Off-screen this saves
    /// a 5s IOKit read + publish + menu-bar re-render for the app's whole lifetime.
    func beginPowerFlowObserving() {
        powerViewers += 1
        guard powerTimer == nil else { return }
        powerFlow = PowerMonitor.read()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.powerFlow = PowerMonitor.read() }
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        powerTimer = t
    }

    /// Call from `.onDisappear`.
    func endPowerFlowObserving() {
        powerViewers = max(0, powerViewers - 1)
        if powerViewers == 0 {
            powerTimer?.invalidate()
            powerTimer = nil
        }
    }

    private func startPowerSourceNotifications() {
        // Pass `self` through an opaque pointer so the C callback can call back in.
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let store = Unmanaged<BatteryStore>.fromOpaque(ctx).takeUnretainedValue()
            // IOKit's charging/plugged flags can trail the actual plug/unplug, so read a few times.
            Task { @MainActor in store.refreshSoon() }
        }, context)?.takeRetainedValue() else { return }

        // Common modes, like the poll timer: in the default mode alone the source is
        // held off while a menu or the status item is tracking, which is exactly when
        // someone is looking at the numbers.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
    }
}
