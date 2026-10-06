import Foundation
import Combine
import AppKit
import EWizKit

/// Lid-close radio automation, and the record of what each closed-lid stretch cost.
///
/// Runs as the user, so its preferences live in UserDefaults rather than the root config —
/// switching a radio off is something only a logged-in session can do.
///
/// The radios are the half of Sealed Sleep that isn't `pmset`. Everything else that feature
/// does is a system setting written once by the daemon; Wi-Fi and Bluetooth have to be
/// switched off as the lid actually closes and put back when it opens, which is what the
/// sleep hook below is for.
@MainActor
final class AutomationStore: ObservableObject {
    @Published var wifiOffOnLidClose: Bool {
        didSet { defaults.set(wifiOffOnLidClose, forKey: Keys.wifi) }
    }
    @Published var bluetoothOffOnLidClose: Bool {
        didSet { defaults.set(bluetoothOffOnLidClose, forKey: Keys.bt) }
    }
    @Published var restoreOnWake: Bool {
        didSet { defaults.set(restoreOnWake, forKey: Keys.restore) }
    }

    @Published private(set) var isLidClosed = false
    @Published private(set) var externalDisplayCount = 0

    /// Lid shut but the Mac is awake (docked to an external display on power).
    var isClamshellMode: Bool { isLidClosed }

    @Published private(set) var lastLidSession: LidSession?

    /// Read to know whether "Always Active" is actually holding the Mac awake.
    weak var chargeLimit: ChargeLimitStore?

    private let defaults = UserDefaults.standard
    private let lid = LidMonitor()
    private var lidPollTimer: Timer?
    private var clamshellSaverTimer: Timer?

    // Radio states captured at sleep, to restore on wake.
    private var wifiWasOn = false
    private var bluetoothWasOn = false

    private enum Keys {
        static let wifi = "automation.wifiOffOnLidClose"
        static let bt = "automation.bluetoothOffOnLidClose"
        static let restore = "automation.restoreOnWake"
        // What the radio preferences were before Sealed Sleep took them over.
        static let sealedRadioRestore = "automation.sealedRadioRestore"
        // Pending lid session (persisted so it survives the sleep).
        static let pendingCloseAt = "lidsession.closedAt"
        static let pendingCloseCharge = "lidsession.closeCharge"
    }

    init() {
        wifiOffOnLidClose = defaults.bool(forKey: Keys.wifi)
        bluetoothOffOnLidClose = defaults.bool(forKey: Keys.bt)
        restoreOnWake = defaults.object(forKey: Keys.restore) as? Bool ?? true
        lastLidSession = LidSessionStore.recent(limit: 1).first

        lid.onWillSleep = { [weak self] clamshellClosed in
            // assumeIsolated traps on macOS 26 when the IOKit callback isn't on the main actor's executor.
            Task { @MainActor in self?.handleWillSleep(clamshellClosed) }
        }
        lid.onDidWake = { [weak self] in
            Task { @MainActor in self?.handleWake() }
        }
        lid.start()

        pollLidState()
        // Lid state changes are rare and reads are cheap — poll slowly to save CPU.
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollLidState() }
        }
        t.tolerance = 5   // lid state also updates on sleep/wake; slack is fine
        RunLoop.main.add(t, forMode: .common)
        lidPollTimer = t
    }

    private func pollLidState() {
        let closed = LidMonitor.isClamshellClosed()
        // NSScreen import via AppKit; count displays beyond the built-in.
        let externals = max(0, NSScreen.screens.count - (closed ? 0 : 1))
        // Both are unchanged on almost every poll; publishing anyway would relayout
        // the menu bar item four times a minute for nothing.
        if closed != isLidClosed { isLidClosed = closed }
        if externals != externalDisplayCount { externalDisplayCount = externals }
        updateClamshellSaver()
    }

    // MARK: - Clamshell display saver

    // With "Always Active" holding the Mac awake, closing the lid skips macOS's normal
    // clamshell display-off, so the internal panel + keyboard backlight stay lit (and
    // hot) inside the shut lid. Re-issue a forced display sleep while the lid is shut so
    // a wake can't leave it on; the keyboard backlight follows display sleep. Never runs
    // with an external display attached (that would blank the user's monitor).
    private func updateClamshellSaver() {
        if shouldSaveClamshell() { startClamshellSaver() } else { stopClamshellSaver() }
    }

    private func shouldSaveClamshell() -> Bool {
        // keepAwakeArmed, not the raw toggle: outside a scheduled window (or past an
        // auto-off timer) nothing is holding the Mac awake, so macOS handles the lid
        // and we must not be forcing the display off.
        guard let cl = chargeLimit, cl.keepAwakeArmed else { return false }
        guard SystemPower.isClamshellClosed(), !Self.hasExternalDisplay() else { return false }
        return cl.keepAwakeOnBattery || BatteryMonitor.read().onExternalPower
    }

    private func startClamshellSaver() {
        guard clamshellSaverTimer == nil else { return }
        forceInternalDisplayOff()
        // Every 30s, not every 10. The re-issue exists because a maintenance wake can turn
        // the panel back on inside a shut lid, and that is a once-in-a-while event — at 10s
        // this forked `pmset` 360 times an hour, for hours, in an app whose whole argument
        // is that background work costs battery. A backlight lit for up to half a minute
        // after a dark wake is cheaper than the polling was.
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.clamshellSaverTick() }
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        clamshellSaverTimer = t
    }

    private func clamshellSaverTick() {
        // Re-read live so opening the lid or attaching a display stops us within one tick.
        guard shouldSaveClamshell() else { stopClamshellSaver(); return }
        forceInternalDisplayOff()
    }

    private func stopClamshellSaver() {
        clamshellSaverTimer?.invalidate()
        clamshellSaverTimer = nil
    }

    private func forceInternalDisplayOff() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["displaysleepnow"]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try? p.run()
    }

    /// True if any non-built-in display is online — then we must not force display sleep.
    private static func hasExternalDisplay() -> Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return false }
        return ids.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }

    /// Apply only the lid-radio parts of a save mode's profile.
    ///
    /// Skipped entirely while Sealed Sleep is on — it owns these, and the daemon makes the
    /// same exception for the `pmset` half. Every profile names a value for both radios, so
    /// without this, switching to any mode but Super Saver would silently reopen two of the
    /// leaks the switch above claims to have closed.
    func apply(_ profile: SaveProfile) {
        guard chargeLimit?.sealedSleep != true else { return }
        wifiOffOnLidClose = profile.wifiOffOnLidClose
        bluetoothOffOnLidClose = profile.bluetoothOffOnLidClose
        restoreOnWake = profile.restoreOnWake
    }

    /// Runs just before any sleep; synchronous so it finishes before the system powers down.
    private func handleWillSleep(_ clamshellClosed: Bool) {
        // Daemon decides based on its config, so this is a cheap no-op when disabled.
        _ = try? ControlClient.send(.prepareForSleep)
        handleLidClose(clamshellClosed)
    }

    private func handleLidClose(_ clamshellClosed: Bool) {
        guard clamshellClosed else { return }

        // Record the charge at close so we can measure the drop on wake.
        defaults.set(Date(), forKey: Keys.pendingCloseAt)
        defaults.set(BatteryMonitor.read().percentage, forKey: Keys.pendingCloseCharge)

        if wifiOffOnLidClose {
            wifiWasOn = RadioControl.isWiFiOn
            if wifiWasOn { RadioControl.setWiFi(false) }
        }
        if bluetoothOffOnLidClose {
            bluetoothWasOn = RadioControl.isBluetoothOn
            if bluetoothWasOn { RadioControl.setBluetooth(false) }
        }
    }

    private func handleWake() {
        pollLidState()        // reflect "lid open" immediately
        completeLidSession()
        if restoreOnWake { restoreRadios() }
    }

    private func completeLidSession() {
        guard let closedAt = defaults.object(forKey: Keys.pendingCloseAt) as? Date else { return }
        let closeCharge = defaults.integer(forKey: Keys.pendingCloseCharge)
        defaults.removeObject(forKey: Keys.pendingCloseAt)
        defaults.removeObject(forKey: Keys.pendingCloseCharge)

        let openCharge = BatteryMonitor.read().percentage
        let session = LidSession(closedAt: closedAt, closeCharge: closeCharge,
                                 openedAt: Date(), openCharge: openCharge)
        // Skip blips shorter than a minute.
        guard session.duration >= 60 else { return }
        LidSessionStore.append(session)
        lastLidSession = session
    }

    /// Switch the radios back on after a wake. Asks the system at most twice.
    ///
    /// It used to re-issue the write on every one of seven retries, two seconds
    /// apart, for as long as the radio still read as off. Turning Bluetooth on goes
    /// through `IOBluetoothPreferenceSetControllerPowerState`, which sits behind
    /// macOS's Bluetooth consent — so an unanswered prompt left the radio off, which
    /// kept the loop writing, which raised the prompt again. Opening the lid asked
    /// for Bluetooth permission up to seven times, every single time.
    ///
    /// The retry existed for a real reason: macOS is slow to ready the controllers
    /// after a wake and a write issued too early is dropped. One write once things
    /// have settled, one more if it demonstrably didn't take, and then stop. A radio
    /// that won't come back after two asks isn't going to on the seventh, and the
    /// user can flip it from the menu bar — which is a better outcome than a
    /// permission dialog on every lid open.
    private func restoreRadios() {
        let wantWifi = wifiWasOn
        let wantBT = bluetoothWasOn
        guard wantWifi || wantBT else { return }
        // Cleared up front: whatever happens below, this wake's restore is spent, and
        // leaving them set would let a later wake re-run it.
        wifiWasOn = false
        bluetoothWasOn = false

        func issue() {
            if wantWifi && !RadioControl.isWiFiOn { RadioControl.setWiFi(true) }
            if wantBT && !RadioControl.isBluetoothOn { RadioControl.setBluetooth(true) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            issue()
            // The controller can still be coming up; give it longer than the old 2s
            // before the one and only retry.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { issue() }
        }
    }

    // MARK: - Sealed Sleep's half of the job

    /// Sealed Sleep takes the radio preferences over while it's on, and hands them back
    /// when it's switched off.
    ///
    /// Same contract the daemon keeps for the `pmset` half: capture what was there, and
    /// put it back. Without the snapshot, turning the feature off would leave two settings
    /// switched on that the user never chose — small, invisible, and exactly the kind of
    /// residue that makes people stop trusting a power utility.
    func setSealed(_ on: Bool) {
        if on {
            if defaults.object(forKey: Keys.sealedRadioRestore) == nil {
                defaults.set([wifiOffOnLidClose, bluetoothOffOnLidClose],
                             forKey: Keys.sealedRadioRestore)
            }
            wifiOffOnLidClose = true
            bluetoothOffOnLidClose = true
            restoreOnWake = true
        } else {
            if let saved = defaults.array(forKey: Keys.sealedRadioRestore) as? [Bool],
               saved.count == 2 {
                wifiOffOnLidClose = saved[0]
                bluetoothOffOnLidClose = saved[1]
            }
            defaults.removeObject(forKey: Keys.sealedRadioRestore)
        }
    }
}
