import Foundation
import Combine
import AppKit
import EWizKit

/// "Rest the Mac without closing the lid."
///
/// Closing the lid is the usual way to make a Mac stop spending power: the screen and the
/// keyboard backlight go out and the machine quiesces. This does the same thing with the
/// lid open — either on request, or once you've been away long enough — and puts back
/// exactly what it changed when you come back.
///
/// Automatic resting waits for more than a still keyboard: a film, a video call or a game
/// on a controller all leave the idle timer climbing, so `ScreenActivity` is consulted
/// before the screen goes anywhere. Resting on request never asks — that's an instruction.
///
/// What it can and can't touch, so the Settings copy can be honest:
///   - Display: `pmset displaysleepnow`, the same call the clamshell saver uses. The
///     keyboard backlight follows the display, so there's nothing separate to switch.
///   - Low Power Mode: through the root daemon, snapshotted first and restored on wake.
///   - Wi-Fi and Bluetooth: optional, off by default — losing the network while a
///     download or a call is running would be worse than the power it saves.
@MainActor
final class IdleSaverStore: ObservableObject {
    /// Rest automatically once the Mac has been idle for `afterMinutes`.
    @Published var autoEnabled: Bool {
        didSet { defaults.set(autoEnabled, forKey: Keys.auto); reschedule() }
    }
    /// Idle minutes before resting. 30 by default: long enough that a pause to read
    /// isn't mistaken for leaving.
    @Published var afterMinutes: Int {
        didSet { defaults.set(afterMinutes, forKey: Keys.after) }
    }
    /// Also drop to Low Power Mode while resting.
    @Published var lowPowerWhileResting: Bool {
        didSet { defaults.set(lowPowerWhileResting, forKey: Keys.lpm) }
    }
    /// Also switch the radios off. Off by default.
    @Published var radiosOffWhileResting: Bool {
        didSet { defaults.set(radiosOffWhileResting, forKey: Keys.radios) }
    }
    /// Minutes of resting after which the Mac sleeps outright. 0 = stay awake, screen off.
    @Published var sleepAfterMinutes: Int {
        didSet { defaults.set(sleepAfterMinutes, forKey: Keys.sleepAfter) }
    }

    @Published private(set) var resting = false
    /// When resting began, for the menu's "resting since…" line.
    @Published private(set) var restingSince: Date?
    /// Set when the idle threshold has passed but something on screen says otherwise —
    /// a film, a call, a game. Nil the rest of the time. Drives the Settings status line
    /// so "why hasn't it rested?" has an answer.
    @Published private(set) var waitingBecause: String?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let auto = "idleSaver.auto"
        static let after = "idleSaver.afterMinutes"
        static let lpm = "idleSaver.lowPower"
        static let radios = "idleSaver.radios"
        static let sleepAfter = "idleSaver.sleepAfterMinutes"
    }

    /// What we changed, so waking restores it rather than imposing a default.
    private var savedLowPowerMode: Bool?
    private var savedWiFi: Bool?
    private var savedBluetooth: Bool?

    private var timer: Timer?
    private var started = false
    /// Caffeine, so automatic resting can't undo it. Weak: the app owns both.
    private weak var caffeine: CaffeineManager?

    init() {
        autoEnabled = defaults.bool(forKey: Keys.auto)
        let storedAfter = defaults.integer(forKey: Keys.after)
        afterMinutes = storedAfter > 0 ? storedAfter : 30
        lowPowerWhileResting = defaults.object(forKey: Keys.lpm) as? Bool ?? true
        radiosOffWhileResting = defaults.bool(forKey: Keys.radios)
        sleepAfterMinutes = defaults.integer(forKey: Keys.sleepAfter)
    }

    /// Idempotent; called from the always-rendered menu-bar label.
    func startIfNeeded(caffeine: CaffeineManager) {
        self.caffeine = caffeine
        guard !started else { return }
        started = true
        reschedule()
    }

    // MARK: - Manual control

    /// Rest now, whatever the idle time. The screen goes out immediately.
    func restNow() {
        guard !resting else { return }
        beginResting()
    }

    /// Stop resting and put everything back. Any input already woke the display; this is
    /// about the things macOS won't undo for us.
    func wake() {
        guard resting else { return }
        endResting()
    }

    // MARK: - Idle watching

    /// Seconds since the last keyboard, mouse or trackpad event. `hidSystemState` covers
    /// the whole session rather than this process, which is the difference between "the
    /// user is away" and "the user isn't using eWiz".
    static func idleSeconds() -> TimeInterval {
        // kCGAnyInputEventType — not exposed to Swift as a named case.
        let anyInput = CGEventType(rawValue: ~0) ?? .null
        return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyInput)
    }

    private func reschedule() {
        timer?.invalidate()
        timer = nil
        // Runs while watching for idleness *or* while resting — resting needs the timer even
        // with the automatic trigger off, because that's what notices you're back.
        guard autoEnabled || resting else { return }
        // Two cadences, for two jobs. Waiting for a 30-minute threshold needs no better than
        // a minute's resolution, and a fast timer for that in an app whose job is saving
        // power would be absurd. Coming *back* is different: the display has already woken on
        // the keypress, so anything still held — Low Power Mode, the radios — has to be put
        // back promptly or the Mac feels throttled after you've returned to it.
        let interval: TimeInterval = resting ? 2 : 60
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        t.tolerance = resting ? 0.5 : 15
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    private func tick() {
        let idle = Self.idleSeconds()

        if resting {
            // The click or keystroke that started resting is itself activity — pressing
            // ⌃⌥⌘R leaves idle at zero — so without this the first poll would wake it
            // straight back up. Four seconds is longer than two polls and shorter than
            // anyone's patience.
            if let since = restingSince, Date().timeIntervalSince(since) < 4 { return }
            // After that, any input at all means they're back: the display has already woken
            // on the keypress, so whatever is still held has to be put back with it. The
            // threshold sits just above the 2s poll — long enough that the poll can't race a
            // genuine wake, short enough to land within a couple of seconds of the keypress.
            if idle < 3 { endResting(); return }
            if sleepAfterMinutes > 0, let since = restingSince,
               Date().timeIntervalSince(since) >= Double(sleepAfterMinutes) * 60 {
                // Forcing sleep out from under a held assertion would cut off the very
                // thing it's protecting — a download, a call, playback that's still
                // running with the screen dark. Only the assertion counts here: a busy
                // full-screen app is what *stops* resting, not what postpones sleep once
                // the Mac is already resting.
                guard ScreenActivity.busyReason(includingFullScreen: false) == nil else { return }
                sleepNow()
            }
            return
        }

        guard autoEnabled, idle >= Double(afterMinutes) * 60 else {
            waitingBecause = nil
            return
        }
        // Caffeine wins outright. Resting a Mac the user has explicitly asked to stay
        // awake would blank the screen, lock it behind the password, and cut the radios —
        // the exact things they turned Caffeine on to prevent.
        guard caffeine?.active != true else {
            waitingBecause = "Caffeine is keeping the Mac awake"
            return
        }
        // Never rest a Mac that's mid-presentation: an external display usually means
        // someone is looking at something.
        guard !Displays.hasExternal() else {
            waitingBecause = "an external display is connected"
            return
        }
        // Nor one that's being watched. Idle time counts key presses and mouse moves, and
        // a film, a video call or a controller-played game produces none of them — so
        // without this the screen goes black mid-scene once the threshold passes.
        if let reason = ScreenActivity.busyReason() {
            waitingBecause = reason.text
            return
        }
        waitingBecause = nil
        beginResting()
    }

    // MARK: - Applying / restoring

    private func beginResting() {
        resting = true
        restingSince = Date()
        waitingBecause = nil
        reschedule()   // switch to the fast poll that notices you coming back

        // Off the main actor. `ControlClient.send` is a blocking socket round trip with a
        // five-second timeout, and the daemon answers it under the same lock its tick loop
        // holds — so two of them in a row, on the main thread, is the app frozen for as
        // long as the helper takes to get round to them. This runs from a timer while
        // nobody is looking, which is exactly when a hang goes unnoticed until the user
        // comes back to a beachball.
        let wantLowPower = lowPowerWhileResting
        let wantRadios = radiosOffWhileResting
        Task.detached { [weak self] in
            var lowPower: Bool?
            if wantLowPower {
                if let status = try? ControlClient.send(.getStatus) {
                    lowPower = status.lowPowerModeEnabled
                }
                _ = try? ControlClient.send(.setLowPowerMode(true))
            }
            var wifi: Bool?
            var bluetooth: Bool?
            if wantRadios {
                wifi = RadioControl.isWiFiOn
                if wifi == true { _ = RadioControl.setWiFi(false) }
                bluetooth = RadioControl.isBluetoothOn
                if bluetooth == true { RadioControl.setBluetooth(false) }
            }
            await MainActor.run {
                guard let self, self.resting else { return }
                self.savedLowPowerMode = lowPower
                self.savedWiFi = wifi
                self.savedBluetooth = bluetooth
                // Display last, and still last now that the rest is asynchronous: doing it
                // first would darken the screen while the work it's waiting on is still
                // running, which reads as resting having stalled.
                self.displayOff()
            }
        }
    }

    private func endResting() {
        resting = false
        restingSince = nil
        reschedule()   // back to the slow idle watch (or no timer, if that's off)

        // Same reasoning as `beginResting`, and it matters more here: this runs on the
        // keystroke that says the user is back, so a blocking round trip lands squarely in
        // the moment they're looking at the screen.
        let previousLowPower = savedLowPowerMode
        let previousWiFi = savedWiFi
        let previousBluetooth = savedBluetooth
        savedLowPowerMode = nil
        savedWiFi = nil
        savedBluetooth = nil
        Task.detached {
            if let previousLowPower {
                _ = try? ControlClient.send(.setLowPowerMode(previousLowPower))
            }
            // Radios come back only if we were the ones who switched them off.
            if previousWiFi == true, !RadioControl.isWiFiOn { _ = RadioControl.setWiFi(true) }
            if previousBluetooth == true, !RadioControl.isBluetoothOn { RadioControl.setBluetooth(true) }
        }
    }

    private func displayOff() { run("/usr/bin/pmset", ["displaysleepnow"]) }
    private func sleepNow() { run("/usr/bin/pmset", ["sleepnow"]) }

    private func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try? p.run()
    }
}
