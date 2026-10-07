import SwiftUI
import AppKit
import EWizKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no app-switcher entry.
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct EWizApp: App {
    /// Before anything else: the stores below read their settings when they're created,
    /// which SwiftUI does after this returns, and those settings may still be Battlify's.
    init() {
        LegacyMigration.run()
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var battery = BatteryStore()
    @StateObject private var chargeLimit = ChargeLimitStore()
    @StateObject private var automation = AutomationStore()
    @StateObject private var processes = ProcessMonitor()
    @StateObject private var license = LicenseManager()
    @StateObject private var startup = StartupManager()
    @StateObject private var updater = UpdaterManager()
    @StateObject private var actions = SystemActions()
    // `sessionStore` is what lets a live keep-awake survive the app restarting to
    // install an update — see `CaffeineManager.restoreSessionIfNeeded`.
    @StateObject private var caffeine = CaffeineManager(sessionStore: .standard)
    @StateObject private var settings = AppSettings()
    @StateObject private var notifier = NotificationManager()
    @StateObject private var network = NetworkProfileStore()
    @StateObject private var triggers = TriggerStore()
    @StateObject private var hotkeys = HotkeyStore()
    @StateObject private var restReminder = RestReminder()
    @StateObject private var overlay = ChargeOverlayController()
    @StateObject private var idleSaver = IdleSaverStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(battery)
                .environmentObject(chargeLimit)
                .environmentObject(automation)
                .environmentObject(processes)
                .environmentObject(license)
                .environmentObject(startup)
                .environmentObject(updater)
                .environmentObject(actions)
                .environmentObject(caffeine)
                .environmentObject(settings)
                .environmentObject(notifier)
                .environmentObject(network)
                .environmentObject(triggers)
                .environmentObject(hotkeys)
                .environmentObject(restReminder)
                .environmentObject(idleSaver)
                .environmentObject(overlay)
                .onAppear {
                    network.chargeLimit = chargeLimit
                    automation.chargeLimit = chargeLimit
                }
        } label: {
            // Its own observing view so it re-renders reliably — a label closure that
            // reads the store inline can render once and go stale. It also renders at
            // launch, which is where the automation rules get started (the dropdown's
            // `onAppear` wouldn't run until you first opened the menu).
            MenuBarLabel(battery: battery, chargeLimit: chargeLimit,
                         settings: settings, notifier: notifier, triggers: triggers,
                         hotkeys: hotkeys, caffeine: caffeine, actions: actions,
                         license: license, restReminder: restReminder, overlay: overlay,
                         idleSaver: idleSaver)
        }
        .menuBarExtraStyle(.window)

        // Set-once controls live here so the menu dropdown stays focused on daily use.
        Window("eWiz Settings", id: "settings") {
            SettingsView()
                .environmentObject(battery)
                .environmentObject(chargeLimit)
                .environmentObject(automation)
                .environmentObject(caffeine)
                .environmentObject(license)
                .environmentObject(startup)
                .environmentObject(updater)
                .environmentObject(settings)
                .environmentObject(notifier)
                .environmentObject(network)
                .environmentObject(triggers)
                .environmentObject(hotkeys)
                .environmentObject(overlay)
                .environmentObject(idleSaver)
        }
        .windowResizability(.contentSize)

        Window("Battery Details", id: "details") {
            DetailsView()
                .environmentObject(battery)
                .environmentObject(processes)
                .environmentObject(chargeLimit)
                .environmentObject(automation)
        }
        .windowResizability(.contentSize)

        Window("Battery History", id: "history") {
            HistoryView()
        }
        .windowResizability(.contentMinSize)

        // Named for what it manages, not one of the two things it does: a licensed Mac
        // opening "Activate eWiz" reads as the purchase having been lost.
        Window("eWiz License", id: "license") {
            LicenseView()
                .environmentObject(license)
        }
        .windowResizability(.contentSize)
        // Centred, rather than wherever the last window of that size happened to sit,
        // which put it half off-screen behind Settings.
        .defaultPosition(.center)
    }
}

/// Its own View with @ObservedObject stores so SwiftUI re-renders on snapshot/charge
/// changes — a MenuBarExtra label closure reading a store inline can go stale/blank.
struct MenuBarLabel: View {
    @ObservedObject var battery: BatteryStore
    @ObservedObject var chargeLimit: ChargeLimitStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var notifier: NotificationManager
    let triggers: TriggerStore
    // Not observed: the label doesn't render from these. They're here because the
    // label is the one view that exists from launch, which is where global shortcuts
    // have to start listening — waiting for the dropdown's first open would mean the
    // shortcuts silently didn't work until you'd clicked the menu bar once. The rest
    // reminder and Caffeine's power policy start from here for the same reason.
    let hotkeys: HotkeyStore
    let caffeine: CaffeineManager
    let actions: SystemActions
    let license: LicenseManager
    let restReminder: RestReminder
    let overlay: ChargeOverlayController
    let idleSaver: IdleSaverStore
    @Environment(\.openWindow) private var openWindow

    /// The completion flash is on. Set and cleared only by `celebrate`/`endCelebration`,
    /// which own its clock — see `celebration`.
    @State private var celebrating = false
    /// The flash's own timer. It used to ride the icon's animation tick, which only runs
    /// while something animates: with the charging animation on, the tick's task was
    /// already running when the flash began, so its closure had captured `celebrating ==
    /// false` and never counted the flash down. The check mark then sat in the menu bar
    /// until the screens next slept — over a battery that had long since gone back to
    /// charging.
    @State private var celebration: Task<Void, Never>?
    /// The last state current was flowing in, and when it stopped. Charging and "stopped
    /// at the limit" can arrive a poll apart, so a finish is still a finish for a while
    /// after the bolt went out.
    @State private var lastCharging: (state: ChargeDisplayState, until: Date)?
    /// A one-off connect/disconnect animation, and how far through it we are.
    @State private var transition: IconTransition?

    /// How long a finished charge may trail the last charging reading and still flash.
    private static let completionGrace: TimeInterval = 120
    /// How long the check mark shows.
    private static let celebrationLength: UInt64 = 3_000_000_000

    var body: some View {
        let snap = battery.snapshot
        let display = chargeLimit.display(for: snap)
        // One source of truth for motion: the system's Reduce Motion, unless the user has
        // overridden it for this app. Read here so every animation below agrees.
        let motion = settings.motionAllowed
        // Only a state that is a completion may wear the check. The flag can't lag the
        // state (it is cleared in the same handler that notices the state change), but the
        // glyph still derives from one reading rather than two flags that might disagree.
        let celebratingNow = celebrating && motion && display.isComplete
        let mark: ChargeMark = celebratingNow ? .check : display.mark
        // The success flash uses the ramp's own full-charge colour — which is what the
        // flash means — rather than a stock green that matches nothing else here. Mono
        // blinks by alpha instead.
        let tint: MenuBarTint =
            celebratingNow && settings.colorMenuBarIcon
            ? .colored(NSColor(ChargePalette.legible(1)))
            : settings.colorMenuBarIcon ? tint(for: snap) : .neutral
        // Each tick re-renders the status item, and that relayout measured ~10% of a
        // core sustained — the entire time the Mac was plugged in. So the charging
        // animation is opt-in. The completion flash doesn't need the tick: the check
        // holds still, and its three seconds run on their own task.
        let animating = motion && settings.animateMenuBarIcon
            && (snap.isCharging || settings.batteryIconStyle.animatesOnBattery)
        // The label renders at launch — a reliable hook to start notification detection.
        notifier.startIfNeeded(settings: settings, battery: battery, chargeLimit: chargeLimit)
        // Same reason, and it has to be here rather than in `onAppear`: a status-item
        // label's `onAppear` doesn't fire at launch, so registering shortcuts there
        // left every one of them dead until the menu had been opened. `attach` is
        // idempotent, so calling it on each body evaluation costs nothing.
        hotkeys.attach(chargeLimit: chargeLimit, caffeine: caffeine,
                       systemActions: actions,
                       idleSaver: idleSaver, settings: settings, license: license,
                       openWindow: { id in
                           NSApplication.shared.activate(ignoringOtherApps: true)
                           openWindow(id: id)
                       })
        // The label re-renders on every snapshot change, which is exactly when Caffeine's
        // power policy needs re-evaluating (unplugging must stop it holding the screen
        // awake and draining). The call is idempotent, so re-sending costs nothing.
        // `|| discharging`: cutting the adapter to hold a level makes macOS report "Battery
        // Power" while the cable is still in, and Caffeine reads that as a real unplug —
        // narrowing its hold to system-only, or ending the session outright if "end on
        // battery" is set. The hold would have been switching off the very thing the user
        // asked to keep running, every time it engaged.
        // Before `applyPolicy`, so a restored hold is reconciled to the real power
        // source on this same pass rather than sitting at the assumed-AC default.
        caffeine.restoreSessionIfNeeded()
        caffeine.applyPolicy(keepDisplayOnBattery: settings.caffeineKeepDisplayOnBattery,
                             endOnBattery: settings.caffeineEndOnBattery,
                             onExternalPower: snap.onExternalPower || chargeLimit.discharging)
        restReminder.startIfNeeded(settings: settings, battery: battery)
        idleSaver.startIfNeeded(caffeine: caffeine)
        return HStack(spacing: 2) {
            // Its own view, and that is the whole point: the animation ticks four times a
            // second, and when the frame lived in this body every tick re-evaluated the
            // label — twelve observable objects read, five stores poked, the tint and the
            // help text recomputed — to change one small image. That measured around 13% of
            // a core, sustained, for as long as the Mac was plugged in. Now a frame change
            // invalidates the icon and nothing else.
            MenuBarIcon(style: settings.batteryIconStyle,
                        percentage: snap.percentage,
                        charging: snap.isCharging,
                        tint: tint,
                        mark: mark,
                        holding: display.holdsLevel,
                        animating: animating,
                        transition: $transition,
                        alarm: motion && settings.shakeOnLowBattery && display.state == .onBattery
                            ? LowBatteryAlarm(percentage: snap.percentage) : .none)
            if let text = labelText(snap) {
                // Monospaced digits so the item doesn't shift width as it ticks.
                Text(text).monospacedDigit()
            }
        }
        .help(display.tooltip)
        // Every reaction to the charge state hangs off this one change. It replaced four
        // handlers on four different flags that each fired in modifier order and shared
        // state through `@State` scratch variables: one recorded when charging stopped for
        // another to read, a third remembered which mark was showing for a fourth. Here
        // `old` is the mark that was showing, and whether it was a finish is a question
        // about the pair. `onChange` fires only on change, so at launch the glyph simply
        // draws the state it finds — a Mac woken already held at the limit gets the pause
        // mark and nothing springs.
        .onChange(of: display.state) { old, new in
            chargeStateChanged(from: old, to: display, motion: motion)
        }
        // Plug and unplug feedback. Driven off the snapshot rather than a power-source
        // callback of its own: this view already re-renders on every snapshot change, and
        // `onChange` fires once per real transition rather than on every poll.
        .onChange(of: snap.isPluggedIn) { was, isNow in
            guard was != isNow else { return }
            // The helper cutting the adapter to drain or hold flips this too, with the
            // cable still in. That isn't an unplug and shouldn't sound like one.
            guard isNow || !chargeLimit.discharging else { return }
            if settings.hapticsEnabled {
                isNow ? HapticFeedback.chargeConnected() : HapticFeedback.chargeDisconnected()
            }
            if settings.soundAllowed {
                ChargeSound.play(isNow ? .connect : .disconnect, volume: settings.soundVolume,
                                 theme: settings.soundTheme)
            }
            guard ChargeOverlayFeature.shipped, settings.chargeOverlayEnabled,
                  isNow || settings.chargeOverlayOnUnplug else { return }
            overlay.show(style: settings.chargeOverlayStyle,
                         duration: settings.chargeOverlayDuration,
                         percentage: snap.percentage,
                         plugging: isNow,
                         allowMotion: settings.motionAllowed)
        }
        // The status item exists from launch, so this is where the automation
        // rules start watching — they must run whether or not the menu is opened.
        .onAppear { triggers.attach(chargeLimit: chargeLimit, battery: battery) }
    }

    /// One state gave way to another: decide what the glyph does about it.
    private func chargeStateChanged(from old: ChargeDisplayState, to display: ChargeDisplay,
                                    motion: Bool) {
        let new = display.state
        // Remember where the charge was heading, so a finish that reports a poll later
        // still counts. Cleared (by expiry) rather than on every state so a hold switched
        // on and off again doesn't resurrect a stale target.
        if case .charging = old {
            lastCharging = (old, Date().addingTimeInterval(Self.completionGrace))
        } else if case .calibrating(charging: true) = old {
            lastCharging = (old, Date().addingTimeInterval(Self.completionGrace))
        }
        let recent = lastCharging.flatMap { $0.until > Date() ? $0.state : nil }

        // A flash outlives the state it celebrated only as a stuck one. Unplugged, level
        // dropped, hold released: the check goes with it.
        if !display.isComplete { endCelebration() }

        let finished = display.completes(from: old) || (recent.map(display.completes) ?? false)
        if finished {
            lastCharging = nil
            if settings.hapticsEnabled { HapticFeedback.limitReached() }
            if settings.soundAllowed {
                ChargeSound.play(.complete, volume: settings.soundVolume,
                                 theme: settings.soundTheme)
            }
            if motion { celebrate() }
        }

        guard motion else { return }
        if new == .onBattery {
            // Unplugged: whatever mark was showing shrinks away. `old` is what was
            // showing; the snapshot that reports the unplug has already lost it.
            switch ChargeDisplay.steadyMark(for: old, percentage: display.input.percentage) {
            case .bolt:        transition = .markOutBolt
            case .pause, .check: transition = .markOutPause
            case .none:        break
            }
        } else if finished || !old.sameKind(as: new) {
            // Something started — plugged in, charging began or stopped, a hold switched,
            // a charge finished — and the mark springs in so the menu bar is seen to
            // notice. A target moving (the limit slider) is not that.
            transition = .markIn
        }
    }

    /// Start the completion flash, with its own bounded clock.
    private func celebrate() {
        celebration?.cancel()
        celebrating = true
        celebration = Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.celebrationLength)
            guard !Task.isCancelled else { return }
            celebrating = false
        }
    }

    private func endCelebration() {
        celebration?.cancel()
        celebration = nil
        celebrating = false
    }

    /// Red when warm or critically low, the red-yellow-green ramp on power, neutral on
    /// battery.
    ///
    /// Colour is reserved for the states it can say something about. On the adapter the
    /// ramp is a reading — how far up it has got, and whether that's good news. On battery
    /// the same green would be claiming everything is fine about a number that is only
    /// going down, which is why an unplugged Mac at 80% draws in the menu bar's own
    /// colour and says nothing until it drops far enough to be worth a red.
    private func tint(for snap: BatterySnapshot) -> MenuBarTint {
        if isWarm(snap) { return .colored(.systemRed) }
        if snap.percentage <= 20 && !snap.isPluggedIn { return .colored(.systemRed) }
        guard snap.isPluggedIn else { return .neutral }
        return .colored(NSColor(ChargePalette.legible(Double(snap.percentage) / 100)))
    }

    /// Held for heat, or genuinely hot (≥40 °C) even with heat-pause off.
    private func isWarm(_ snap: BatterySnapshot) -> Bool {
        if chargeLimit.pauseReason == "heat" { return true }
        if let t = snap.temperature, t >= 40 { return true }
        return false
    }

    /// Text beside the icon, per the display preference. Time-remaining falls back
    /// to the percentage when macOS has no estimate (right after a plug change, or
    /// while holding at the limit) rather than blanking out.
    private func labelText(_ snap: BatterySnapshot) -> String? {
        let mode = settings.menuBarDisplay
        let pct = mode.showsPercentage ? "\(snap.percentage)%" : nil
        let time = mode.showsTime ? remainingText(snap) : nil
        switch (pct, time) {
        case let (p?, t?):  return "\(p) · \(t)"
        case let (p?, nil): return p
        case let (nil, t?): return t
        case (nil, nil):    return mode.showsTime ? "\(snap.percentage)%" : nil
        }
    }

    /// "1:25" — time to full while charging, time to empty on battery. Nil when
    /// macOS hasn't got an estimate (it reports −1 while recalculating, which
    /// `BatteryMonitor` already drops).
    private func remainingText(_ snap: BatterySnapshot) -> String? {
        let minutes = snap.isCharging ? snap.timeToFull : snap.timeToEmpty
        guard let minutes, minutes > 0 else { return nil }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

}

enum MenuBarTint {
    case neutral            // adaptive monochrome (template)
    case colored(NSColor)

    var isNeutral: Bool {
        if case .neutral = self { return true }
        return false
    }

    var cacheKey: String {
        switch self {
        case .neutral: return "neutral"
        case .colored(let c): return "colored(\(c))"
        }
    }
}

extension BatterySnapshot {
    /// SF Symbol for the charge level. Bolt drawn separately — SF Symbols only ships
    /// a bolt variant for the full battery.
    var menuBarSymbol: String {
        switch percentage {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default:    return "battery.100"
        }
    }

    /// The ramp on power, red when critically low, neutral on battery. Mirrors
    /// `tint(for:)` — the two must agree or the preview lies about the menu bar.
    var menuBarTint: MenuBarTint {
        if percentage <= 20 && !isPluggedIn { return .colored(.systemRed) }
        guard isPluggedIn else { return .neutral }
        return .colored(NSColor(ChargePalette.legible(Double(percentage) / 100)))
    }
}

extension Notification.Name {
    /// Ask the menu-bar glyph for one low-battery shake, from Settings' Preview button.
    static let ewizPreviewLowBatteryShake = Notification.Name("EWizPreviewLowBatteryShake")
}

/// How urgently the battery is running out, on battery power only.
enum LowBatteryAlarm: Equatable {
    case none
    /// 20% and under: a gentle shake on the way in, then every five minutes.
    case low
    /// 10% and under: a harder shake every twenty seconds until it's plugged in.
    case critical

    init(percentage: Int) {
        self = percentage <= 10 ? .critical : percentage <= 20 ? .low : .none
    }

    /// Seconds between shakes, nil for none.
    var interval: Double? {
        switch self {
        case .none:     return nil
        case .low:      return 300
        case .critical: return 20
        }
    }

    /// Peak sideways travel, in viewBox units.
    var strength: Double { self == .critical ? 1.1 : 0.7 }

    /// Frames in one shake, 40ms apart: about half a second.
    static let shakeSteps = 12
}

/// The menu-bar glyph and its clocks, kept apart from the label that surrounds it.
///
/// Two reasons it is its own view. The animation ticks four times a second, and a frame
/// number living in the parent meant the entire label re-evaluated on every tick — every
/// observable object it reads, every store call it makes — to change one 24pt image; that
/// was around 13% of a core for as long as the Mac was plugged in. And the tick now stops
/// when the screens are asleep: a lid shut on a charger was animating a glyph that nobody
/// could see, four times a second, until it was opened again.
private struct MenuBarIcon: View {
    let style: BatteryIconStyle
    let percentage: Int
    let charging: Bool
    let tint: MenuBarTint
    /// What the glyph says, decided by the label from the shared charge state.
    let mark: ChargeMark
    let holding: Bool
    let animating: Bool
    @Binding var transition: IconTransition?
    /// How hard the battery is running out, which decides how often the glyph shakes.
    var alarm: LowBatteryAlarm = .none

    @State private var animFrame = 0
    @State private var shake: CGFloat = 0
    @State private var transitionStep = 0
    @State private var screensAsleep = false

    private var running: Bool { animating && !screensAsleep }

    var body: some View {
        // Drawn as an NSImage: SwiftUI's .foregroundStyle is overridden for status-item
        // labels, and the renderer draws the charging bolt inside the glyph.
        let glyph = BatteryIconRenderer.image(
            style: style,
            percentage: percentage,
            charging: charging,
            tint: tint,
            frame: animFrame,
            mark: mark,
            holding: holding,
            transition: transition,
            transitionStep: transitionStep,
            shake: shake)
        Image(nsImage: glyph)
        // One shared tick; task(id:) cancels it when nothing animates. 250ms — twice the
        // rate of the old 500ms, because a six-step sweep at 2fps reads as a slideshow no
        // matter how it's eased. Nothing but the frame counter lives in here: the task's
        // closure captures this struct's `let`s as they were when it started, so any flag
        // read inside it is a flag frozen at that moment.
        .task(id: running) {
            guard running else { animFrame = 0; return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                animFrame &+= 1
            }
        }
        // The transition runs on its own clock: the shared tick is far too slow to read as
        // a morph, and this only lasts about half a second.
        .task(id: transition) {
            guard transition != nil else { transitionStep = 0; return }
            for step in 0..<BatteryIconRenderer.transitionSteps {
                transitionStep = step
                try? await Task.sleep(
                    nanoseconds: UInt64(BatteryIconRenderer.transitionStepDuration * 1_000_000_000))
                if Task.isCancelled { return }
            }
            transition = nil
            transitionStep = 0
        }
        // Low battery: the glyph trembles, once on the way into each band and then on a
        // timer, more often the lower it gets. Not a loop: a half-second of motion every
        // so often costs nothing, where a glyph that never stops is both a CPU bill and
        // the kind of alarm people learn to stop seeing.
        .task(id: alarm) {
            shake = 0
            guard let every = alarm.interval else { return }
            while !Task.isCancelled {
                if !screensAsleep { await runShake(strength: alarm.strength) }
                try? await Task.sleep(nanoseconds: UInt64(every * 1_000_000_000))
            }
        }
        // Settings' Preview: one critical-strength shake, whatever the battery says.
        .onReceive(NotificationCenter.default.publisher(for: .ewizPreviewLowBatteryShake)) { _ in
            Task { await runShake(strength: LowBatteryAlarm.critical.strength) }
        }
        .onReceive(NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidSleepNotification)) { _ in screensAsleep = true }
        .onReceive(NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.screensDidWakeNotification)) { _ in screensAsleep = false }
    }

    /// One shake: about half a second of damped side-to-side, then still.
    private func runShake(strength: Double) async {
        for step in 0...LowBatteryAlarm.shakeSteps {
            shake = BatteryIconRenderer.shakeOffset(
                Double(step) / Double(LowBatteryAlarm.shakeSteps), strength: strength)
            try? await Task.sleep(nanoseconds: 40_000_000)
            if Task.isCancelled { break }
        }
        shake = 0
    }
}
