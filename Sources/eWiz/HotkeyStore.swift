import Foundation
import Combine
import AppKit
import EWizKit

/// Owns the global-shortcut bindings: persistence, registration, and running the
/// action when one fires. The stores it drives are the same ones the menu uses, so a
/// shortcut and a click take exactly the same path.
@MainActor
final class HotkeyStore: ObservableObject {
    /// Master switch — off unregisters everything without discarding the bindings.
    @Published var enabled: Bool {
        didSet {
            defaults.set(enabled, forKey: Keys.enabled)
            reregister()
        }
    }

    @Published var bindings: HotkeyBindings {
        didSet {
            persist()
            reregister()
        }
    }

    /// Shortcuts the window server refused because another app already owns the
    /// combination. Shown in Settings — a shortcut that does nothing needs a reason.
    @Published private(set) var unavailable: Set<HotkeyAction> = []

    private let monitor = HotkeyMonitor()
    private let defaults = UserDefaults.standard
    private enum Keys {
        static let enabled = "hotkeys.enabled"
        static let bindings = "hotkeys.bindings"
        /// Action ids this install has already been offered defaults for.
        static let seeded = "hotkeys.seededActions"
    }

    // Weak: the app owns these for its whole lifetime, and a strong ref here would
    // be a retain cycle once a store wants to call back into shortcuts.
    private weak var chargeLimit: ChargeLimitStore?
    private weak var caffeine: CaffeineManager?
    private weak var systemActions: SystemActions?
    private weak var idleSaver: IdleSaverStore?
    private weak var settings: AppSettings?
    private weak var license: LicenseManager?
    /// SwiftUI's `openWindow` only exists inside a View, so it's injected.
    private var openWindow: ((String) -> Void)?

    init() {
        enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        if let data = defaults.data(forKey: Keys.bindings),
           let saved = try? JSONDecoder().decode(HotkeyBindings.self, from: data) {
            bindings = saved
            repairDuplicates()
            seedNewActions()
        } else {
            // First launch: ship the defaults rather than nothing, so the feature is
            // discoverable without a trip to Settings.
            bindings = .default
            markAllSeeded()
        }
        monitor.onFire = { [weak self] action in self?.perform(action) }
    }

    /// Wire up the targets and start listening. Called from the menu bar label's body,
    /// the one thing that renders at launch, and idempotent so re-evaluating that body
    /// costs nothing.
    func attach(chargeLimit: ChargeLimitStore,
                caffeine: CaffeineManager,
                systemActions: SystemActions,
                idleSaver: IdleSaverStore,
                settings: AppSettings,
                license: LicenseManager,
                openWindow: @escaping (String) -> Void) {
        guard self.chargeLimit == nil else { return }
        self.chargeLimit = chargeLimit
        self.caffeine = caffeine
        self.systemActions = systemActions
        self.idleSaver = idleSaver
        self.settings = settings
        self.license = license
        self.openWindow = openWindow
        reregister()
    }

    /// Re-supply the window opener from a view that definitely has it. The menu bar
    /// label attaches at launch, but its environment is the less-tested one — the
    /// dropdown's `openWindow` is the same closure the Settings/Details buttons use.
    func setOpenWindow(_ open: @escaping (String) -> Void) { openWindow = open }

    // MARK: - Editing

    /// Assign a combination, moving it off whatever held it before. Returns the
    /// action that lost its shortcut, so the UI can say so.
    @discardableResult
    func set(_ hotkey: Hotkey, for action: HotkeyAction) -> HotkeyAction? {
        var next = bindings
        let displaced = next.set(hotkey, for: action)
        bindings = next
        return displaced
    }

    func clear(_ action: HotkeyAction) {
        var next = bindings
        next.clear(action)
        bindings = next
    }

    func resetToDefaults() { bindings = .default }

    // MARK: - Registration

    private func persist() {
        guard let data = try? JSONEncoder().encode(bindings) else { return }
        defaults.set(data, forKey: Keys.bindings)
    }

    /// Drop shortcuts that two actions somehow share.
    ///
    /// Assigning through the recorder moves a taken combination rather than duplicating it,
    /// but bindings saved by older builds can hold the same chord twice — and Carbon
    /// registers exactly one of them, so the other silently never fires. There's no way to
    /// tell which one the user meant, so the first in the canonical action order keeps it and
    /// the rest are cleared: an obviously unbound action can be fixed in Settings, whereas a
    /// bound-looking one that does nothing can't even be diagnosed.
    private func repairDuplicates() {
        var seen: [Hotkey: HotkeyAction] = [:]
        var repaired = false
        for action in HotkeyAction.allCases {
            guard let hotkey = bindings.hotkey(for: action) else { continue }
            if let owner = seen[hotkey], owner != action {
                bindings.clear(action)
                repaired = true
            } else {
                seen[hotkey] = action
            }
        }
        if repaired { persist() }
    }

    /// Give actions added by an update their default shortcut.
    ///
    /// Saved bindings were previously used exactly as stored, so every action added after a
    /// user's first launch arrived unbound — the shortcut existed in Settings with "Not set"
    /// beside it and nothing shipped it. Defaults are only applied to actions this install
    /// has never seen, tracked by id: a shortcut the user deliberately cleared must stay
    /// cleared, and re-seeding it on every launch would be worse than never seeding it.
    private func seedNewActions() {
        let seen = Set(defaults.stringArray(forKey: Keys.seeded) ?? [])
        var seeded = false
        for action in HotkeyAction.allCases where !seen.contains(action.id) {
            guard let candidate = action.defaultHotkey,
                  bindings.hotkey(for: action) == nil,
                  // Never take a combination the user has already given to something else.
                  bindings.action(for: candidate) == nil
            else { continue }
            _ = bindings.set(candidate, for: action)
            seeded = true
        }
        markAllSeeded()
        if seeded { persist() }
    }

    private func markAllSeeded() {
        defaults.set(HotkeyAction.allCases.map(\.id), forKey: Keys.seeded)
    }

    private func reregister() {
        monitor.apply(bindings, enabled: enabled)
        // Only publish a real change: `attach()` runs from a view body, and an
        // unconditional assignment there would notify SwiftUI mid-update for nothing.
        let rejected = monitor.rejected
        if rejected != unavailable { unavailable = rejected }
    }

    // MARK: - Dispatch

    private func perform(_ action: HotkeyAction) {
        // Every banner this action posts carries the action's own glyph — the same one
        // its row shows in Settings › Shortcuts — so the icon says what fired before
        // the text is read. Set once here rather than threaded through each handler.
        hudIcon = action.icon

        if action.requiresPro, license?.isPro != true {
            HotkeyHUD.shared.show("eWiz Pro", detail: "\(action.title) needs a licence.",
                                  icon: "lock")
            return
        }

        switch action {
        case .toggleChargeLimit:   toggleChargeLimit()
        case .chargeLimitUp:       nudgeChargeLimit(by: 5)
        case .chargeLimitDown:     nudgeChargeLimit(by: -5)
        case .togglePauseCharging: togglePauseCharging()
        case .cycleSaveMode:       cycleSaveMode()
        case .toggleLowPowerMode:  toggleLowPowerMode()
        case .toggleDischarge:     toggleDischarge()
        case .toggleHoldCharge:    toggleHoldCharge()
        case .toggleRest:          toggleRest()
        case .cycleIconStyle:      cycleIconStyle()
        case .brightnessUp:        nudgeBrightness(by: 0.1)
        case .brightnessDown:      nudgeBrightness(by: -0.1)

        case .toggleWiFi:
            let next = !RadioControl.isWiFiOn
            guard RadioControl.setWiFi(next) else {
                hud("Wi-Fi Unchanged", detail: "macOS refused the change.", icon: "alert")
                return
            }
            hud(next ? "Wi-Fi On" : "Wi-Fi Off")

        case .toggleBluetooth:
            let next = !RadioControl.isBluetoothOn
            RadioControl.setBluetooth(next)
            hud(next ? "Bluetooth On" : "Bluetooth Off")

        case .toggleCaffeine:
            guard let caffeine else { return }
            caffeine.toggle()
            hud(caffeine.active ? "Keep Awake On" : "Keep Awake Off",
                detail: caffeine.active
                    ? (caffeine.hold == .systemOnly
                       ? "Tasks keep running; the screen may still sleep"
                       : "Display and system won't sleep")
                    : nil)

        case .toggleKeepAwake:
            guard let charge = requireDaemon() else { return }
            charge.keepAwake.toggle()
            charge.apply()
            hud(charge.keepAwake ? "Always Active On" : "Always Active Off",
                detail: charge.keepAwake ? "Stays awake with the lid closed, on AC" : nil)

        case .toggleDimDisplay:
            guard let systemActions else { return }
            systemActions.toggleDim()
            hud(systemActions.dimmed ? "Display Dimmed" : "Brightness Restored")

        case .displayOff:
            systemActions?.turnDisplayOff()

        case .sleepNow:
            systemActions?.sleepNow()

        case .openSettings: open("settings")
        case .openDetails:  open("details")
        case .openHistory:  open("history")
        }
    }

    /// The charging actions all go through the root helper; without it they'd fail
    /// silently, so say so instead.
    private func requireDaemon() -> ChargeLimitStore? {
        guard let chargeLimit else { return nil }
        guard chargeLimit.daemonAvailable else {
            HotkeyHUD.shared.show("Helper Not Running",
                                  detail: "Install it in Settings › General.",
                                  icon: "alert")
            return nil
        }
        return chargeLimit
    }

    private func toggleChargeLimit() {
        guard let charge = requireDaemon() else { return }
        charge.limitEnabled.toggle()
        charge.apply()
        hud(charge.limitEnabled ? "Charge Limit On" : "Charge Limit Off",
            detail: charge.limitEnabled ? "Holding at \(charge.effectiveLimit)%" : "Charges to 100%")
    }

    /// Steps within the same 50–100% range the sliders allow, and turns the limit on
    /// if it was off — pressing "lower the limit" should limit something.
    private func nudgeChargeLimit(by delta: Int) {
        guard let charge = requireDaemon() else { return }
        let next = min(100, max(50, charge.limit + delta))
        guard next != charge.limit || !charge.limitEnabled else {
            hud("Charge Limit \(charge.limit)%", detail: delta > 0 ? "Already at the top"
                                                                  : "Already at the bottom")
            return
        }
        charge.limit = next
        charge.limitEnabled = true
        charge.apply()
        hud("Charge Limit \(next)%")
    }

    private func togglePauseCharging() {
        guard let charge = requireDaemon() else { return }
        if charge.isPaused {
            charge.resumeCharging()
            hud("Charging Resumed")
        } else {
            charge.pauseCharging(minutes: -1)   // -1 = until resumed
            hud("Charging Paused", detail: "Until you resume")
        }
    }

    /// Cycles the saving modes only.
    ///
    /// Extreme Performance is left out deliberately. It drops the charge limit and stops
    /// the Mac sleeping — neither of which should ever be the result of a
    /// keystroke you meant for something else. From Extreme, the first press lands on Off,
    /// so the shortcut is still a way *out*.
    private func cycleSaveMode() {
        guard let charge = requireDaemon() else { return }
        let all = SaveMode.allCases.filter { !$0.isPerformance }
        let next: SaveMode
        if let index = all.firstIndex(of: charge.mode) {
            next = all[(index + 1) % all.count]
        } else {
            next = .off
        }
        charge.applyMode(next)
        hud("Save Mode: \(next.title)", detail: next.summary)
    }

    private func toggleLowPowerMode() {
        guard let charge = requireDaemon() else { return }
        let next = !charge.lowPowerMode
        charge.setLowPowerMode(next)
        hud(next ? "Low Power Mode On" : "Low Power Mode Off")
    }

    private func toggleDischarge() {
        guard let charge = requireDaemon() else { return }
        guard charge.dischargeSupported else {
            hud("Not Supported", detail: "This Mac has no adapter control.", icon: "alert")
            return
        }
        charge.dischargeEnabled.toggle()
        charge.apply()
        hud(charge.dischargeEnabled ? "Force Discharge On" : "Force Discharge Off",
            detail: charge.dischargeEnabled ? "Running off the battery while plugged in" : nil)
    }

    private func toggleHoldCharge() {
        guard let charge = requireDaemon() else { return }
        charge.holdCharge.toggle()
        charge.apply()
        hud(charge.holdCharge ? "Don't Charge On" : "Don't Charge Off",
            detail: charge.holdCharge ? "Plugged in, battery held where it is" : nil)
    }

    /// Brightness in 10% steps, reported as a percentage so the HUD says what happened
    /// even when the change is at the top or bottom of the range.
    private func nudgeBrightness(by delta: Float) {
        guard BrightnessControl.isSupported, let current = BrightnessControl.current() else {
            hud("Not Supported", detail: "This Mac's display brightness isn't controllable.",
                icon: "alert")
            return
        }
        let next = min(1, max(0, current + delta))
        guard BrightnessControl.set(next) else {
            hud("Brightness Unchanged", detail: "macOS refused the change.", icon: "alert")
            return
        }
        hud("Brightness \(Int((next * 100).rounded()))%")
    }

    private func toggleRest() {
        guard let idleSaver else { hud("Resting Unavailable", icon: "alert"); return }
        if idleSaver.resting {
            idleSaver.wake()
            hud("Awake")
        } else {
            // The HUD has to be up before the screen goes dark, or it's a banner nobody sees.
            hud("Resting", detail: "Screen off, settings held. Press any key to come back")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { idleSaver.restNow() }
        }
    }

    private func cycleIconStyle() {
        guard let settings else { hud("Style Unavailable", icon: "alert"); return }
        let all = BatteryIconStyle.allCases
        let next = all[((all.firstIndex(of: settings.batteryIconStyle) ?? 0) + 1) % all.count]
        settings.batteryIconStyle = next
        hud("Icon: \(next.displayName)")
    }

    private func open(_ id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow?(id)
    }

    /// The glyph for the action being performed, so handlers don't each have to pass one.
    private var hudIcon: String?

    private func hud(_ title: String, detail: String? = nil, icon: String? = nil) {
        HotkeyHUD.shared.show(title, detail: detail, icon: icon ?? hudIcon)
    }
}
