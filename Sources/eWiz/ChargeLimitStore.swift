import Foundation
import Combine
import AppKit
import EWizKit

/// GUI-side charge-limit state. Socket I/O to the root daemon runs off the main
/// thread; published state is updated back on the main actor.
@MainActor
final class ChargeLimitStore: ObservableObject {
    @Published private(set) var daemonAvailable = false
    /// Protocol version the daemon reports (0 = pre-versioning).
    @Published private(set) var daemonProtocolVersion = 0
    /// Build version the daemon reports (0 = predates it).
    @Published private(set) var daemonBuildVersion = 0
    /// Installed helper is older than this build (protocol or behaviour). Triggers an
    /// automatic update (see autoInstallHelperIfNeeded).
    var daemonOutdated: Bool {
        daemonAvailable && (daemonProtocolVersion < ControlProtocol.version
                            || daemonBuildVersion < HelperBuild.version)
    }
    @Published private(set) var schemeDescription = ""
    @Published private(set) var chargingEnabled = true
    @Published private(set) var lowPowerMode = false
    /// Sleep/idle power-feature states, keyed by pmset key.
    @Published private(set) var powerToggles: [String: Bool] = [:]

    @Published private(set) var mode: SaveMode = .off
    /// Why charging is paused ("limit"/"heat"/nil).
    @Published private(set) var pauseReason: String?
    /// The levels macOS's own charge limit offers, when this Mac limits through it (its
    /// SMC charge keys are gated). Empty on a Mac with a real key.
    @Published private(set) var nativeLimitSteps: [Int] = []
    /// The step the helper has macOS enforcing right now, nil when none.
    @Published private(set) var nativeLimitApplied: Int?
    /// Whether this Mac has an SMC charge-inhibit key, which Charge Power needs.
    @Published private(set) var chargePowerSupported = true

    /// The lowest level this Mac can hold at, or nil when it can hold anywhere.
    var nativeLimitFloor: Int? { nativeLimitSteps.first }

    /// Where the limit actually stops on this Mac. The slider's value everywhere except
    /// under macOS's limit, which only stops on its own steps from 80%: a 70% setting
    /// stops at 80, and every "Holding at…" in the app has to say 80 or it's wrong.
    var effectiveLimit: Int {
        NativeChargeLimit.step(for: limit, in: nativeLimitSteps) ?? limit
    }

    /// The level being held right now: macOS's step when it's the one holding (the hold
    /// rounds up to one, so it isn't the limit), otherwise the limit.
    var holdingAt: Int { nativeLimitApplied ?? effectiveLimit }

    /// Mirror of the daemon's config. Edits are pushed via `apply`.
    @Published var limitEnabled = false
    @Published var limit = 80
    /// Charging resumes at limit - resumeMargin, so the battery cycles in a band
    /// instead of sitting pinned at the limit.
    @Published var resumeMargin = 5
    var recharge: Int { limit - resumeMargin }
    /// Whether the user opted into a custom recharge range; off = default hysteresis.
    @Published var rangeEnabled: Bool = UserDefaults.standard.bool(forKey: "chargeRange.enabled") {
        didSet { UserDefaults.standard.set(rangeEnabled, forKey: "chargeRange.enabled") }
    }
    private let defaultMargin = 5

    /// Enabling seeds a sensible band; disabling reverts to default hysteresis.
    func setRangeEnabled(_ on: Bool) {
        rangeEnabled = on
        if on {
            if resumeMargin <= defaultMargin { resumeMargin = max(defaultMargin, min(20, limit - 20)) }
        } else {
            resumeMargin = defaultMargin
        }
        apply()
    }
    @Published var heatAwareEnabled = false
    @Published var maxChargeTempC = 35.0
    @Published var magSafeLedMode: MagSafeLEDMode = .status   // new-install default
    @Published private(set) var magSafeSupported = false
    @Published var dischargeEnabled = false
    /// "Don't charge while plugged in": hold the level exactly where it is.
    @Published var holdCharge = false
    /// Whether this Mac has macOS High Power Mode at all, and whether it's on. Most Macs
    /// don't — it's a Max-chip and desktop feature — so Extreme Performance has to be
    /// able to say which of its levers actually exist here.
    @Published private(set) var highPowerModeSupported = false
    @Published private(set) var highPowerMode = false
    /// Temperature sensors, warmest first.
    @Published private(set) var sensors: [SensorReading] = []
    @Published private(set) var dischargeSupported = false
    @Published private(set) var discharging = false
    @Published var disableChargingBeforeSleep = false
    @Published var preventIdleSleep = false
    /// "Always Active": keep the Mac awake with the lid closed (on AC power).
    @Published var keepAwake = false
    /// Opt-in: also keep awake with the lid closed on battery (drains fast / warm).
    @Published var keepAwakeOnBattery = false
    /// Keep-awake only while a matching task runs, then sleep.
    @Published var keepAwakeRequiresTask = false
    @Published var keepAwakeProcesses: [String] = []
    /// Any process at/above this %CPU counts as busy (0 = names only).
    @Published var keepAwakeMinCpu: Double = 0
    /// Release keep-awake above this °C (0 = no guardrail).
    @Published var keepAwakeMaxTempC: Double = 0
    /// Actively sleep the Mac once the monitored task finishes (task-gated keep-awake).
    @Published var sleepWhenTaskDone = false
    /// Sealed Sleep: memory powered down when the lid shuts, and nothing left to wake it.
    /// Read-only here — it goes through `setSealedSleep`, because the daemon has a
    /// transition to run in both directions.
    @Published private(set) var sealedSleep = false
    /// Instant wake while sealed (memory stays powered). See `SealedSleep.fastWakeIsDefault`.
    @Published private(set) var sealedSleepFastWake = SealedSleep.fastWakeIsDefault
    /// Minutes of closed-lid sleep before instant wake hands over to hibernation (0 = never).
    @Published var sealedSleepHibernateAfter = 20
    /// Live `hibernatemode` and `standby`, so the audit can tell "not sealed" from
    /// "this Mac has no such key".
    @Published private(set) var hibernateMode: Int?
    @Published private(set) var standbyEnabled: Bool?
    /// pmset keys this Mac refused on the last Sealed Sleep write.
    @Published private(set) var sealedSleepRefused: [String] = []
    /// Windows during which Always Active holds (empty = whenever the toggle is on).
    @Published var keepAwakeSchedules: [AwakeSchedule] = []
    /// When Always Active switches itself off (nil = no timer).
    @Published private(set) var keepAwakeUntil: Date?
    @Published var schedules: [ChargeSchedule] = []
    /// Once-daily "ready by" top-up target.
    @Published var readyBy = ReadyByTarget()
    /// Gentle (duty-cycled) charging near the top. Legacy; derived from chargePower.
    @Published var slowCharge = false
    /// Charge power as % of full rate via duty cycling (100 = full, 0 = don't charge).
    @Published var chargePower = 100
    /// One-shot calibration to 100% is in progress (auto-clears when full).
    @Published private(set) var calibrating = false
    /// When charging is scheduled to resume (nil = not paused).
    @Published private(set) var pauseUntil: Date?
    var isPaused: Bool { pauseUntil != nil }
    var isPausedIndefinitely: Bool { (pauseUntil ?? .distantPast) > Date().addingTimeInterval(3600 * 24 * 365) }

    /// Full config last seen from the daemon, so edits preserve unrelated fields.
    private var currentConfig = EWizConfig.default
    private var refreshTimer: Timer?

    init() {
        refresh()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 15   // periodic status sync; exact timing doesn't matter
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
        // After wake the daemon may have changed things (deep-save restore); re-sync promptly.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                Task { @MainActor in self?.refresh() }
            }
        }
        // The 30s poll carries 15s of tolerance, so a window brought forward could show
        // state most of a minute old. Refreshing on activation costs one socket round-trip
        // and means what you're looking at is what the daemon currently thinks.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    /// Config writes in flight. While > 0 the periodic refresh must not ingest, or a
    /// stale response could clobber a fresh edit.
    private var pendingWrites = 0
    /// Requests in a row that got no answer. See `ingest`.
    private var failedPolls = 0
    /// Whether the daemon's config has been read at least once. See `apply`.
    private var hasSynced = false

    /// Pull status from the daemon (skipped while a write is outstanding, or while a
    /// control is being dragged — see `editingControls`).
    func refresh() {
        guard pendingWrites == 0, editingControls == 0 else { return }
        Task.detached {
            let result = try? ControlClient.send(.getStatus)
            await self.ingestFromRefresh(result)
        }
    }

    /// Ingest a getStatus response only if no config write started meanwhile, and nothing
    /// is being dragged — a refresh in flight when the drag began still lands here.
    private func ingestFromRefresh(_ response: ControlResponse?) {
        guard pendingWrites == 0, editingControls == 0 else { return }
        ingest(response)
    }

    /// Send a config-changing request and ingest its authoritative response.
    private func command(_ request: ControlRequest) {
        pendingWrites += 1
        Task.detached {
            let result = try? ControlClient.send(request)
            await self.finishCommand(result)
        }
    }

    private func finishCommand(_ response: ControlResponse?) {
        ingest(response)
        pendingWrites = max(0, pendingWrites - 1)
    }

    private var didAttemptHelperUpdate = false

    /// True while the installer is running, so the UI can say "installing" instead of
    /// showing the "not installed" warning behind the admin prompt.
    @Published private(set) var helperInstalling = false
    /// Why the last automatic install didn't happen, if it didn't. Cleared by a success.
    @Published private(set) var helperInstallFailure: String?

    /// Remembers a cancelled admin prompt, stamped with the helper build this app ships.
    ///
    /// Auto-install must not become a password dialog on every single launch: someone who
    /// says no once means it. But a newer helper is a genuinely new question — and the
    /// build number is exactly what "newer" means here — so a bump asks again.
    private static let declinedKey = "helper.autoInstallDeclinedForBuild"
    private var autoInstallDeclined: Bool {
        get { UserDefaults.standard.integer(forKey: Self.declinedKey) == HelperBuild.version }
        set { UserDefaults.standard.set(newValue ? HelperBuild.version : 0, forKey: Self.declinedKey) }
    }

    /// Put the root helper in place without making anyone find a button.
    ///
    /// Two situations land here, and only the second was ever handled automatically:
    ///   - **nothing installed at all** — every charge-limit, heat and sleep feature sits
    ///     inert until someone opens Settings and notices the banner. The app looks broken
    ///     rather than uninstalled, which is the worse of the two.
    ///   - **an installed helper older than the one bundled here**, where the daemon fixes
    ///     that shipped with this build never reach the Mac that needs them.
    ///
    /// Packaged .app only (the scripts live in Resources), at most once per launch, and
    /// never again for this build once the prompt has been cancelled.
    private func autoInstallHelperIfNeeded(missing: Bool) {
        guard missing || daemonOutdated else { return }
        guard !didAttemptHelperUpdate, !autoInstallDeclined else { return }
        // Every route needs something only a packaged build has — the bundled binary, a
        // signature, or the installer script. A bare `swift run` has none of them and is
        // better left alone than nagged.
        guard HelperInstaller.canInstall || HelperService.bundledHelperPath != nil else { return }
        didAttemptHelperUpdate = true
        helperInstalling = true

        let protocolVersion = daemonProtocolVersion
        Task.detached { [weak self] in
            let result = Self.installByCheapestRoute(missing: missing,
                                                    daemonProtocolVersion: protocolVersion)
            // A main-actor method rather than `MainActor.run { guard let self … }`: sending
            // the weak capture into that closure is a data-race error on the Swift that CI
            // builds with, though newer compilers accept it.
            await self?.finishAutoInstall(result)
            guard result.ok else { return }
            await self?.resyncAfterInstall()
        }
    }

    private func finishAutoInstall(_ result: (ok: Bool, message: String)) {
        helperInstalling = false
        guard result.ok else {
            // A cancelled prompt and a broken installer are indistinguishable from
            // here, and re-prompting helps neither. Record it and leave the button.
            autoInstallDeclined = true
            helperInstallFailure = result.message
            return
        }
        helperInstallFailure = nil
        autoInstallDeclined = false
    }

    /// Take the least intrusive route that can actually work on this machine.
    ///
    /// Order matters, and it's ordered by who gets interrupted rather than by elegance: the
    /// two quiet routes cost nothing to attempt, and only the last one puts a password
    /// dialog in front of somebody. Anything that fails falls through to the next, because a
    /// working helper installed the plain way beats a clever one that didn't install.
    private nonisolated static func installByCheapestRoute(
        missing: Bool, daemonProtocolVersion: Int) -> (ok: Bool, message: String) {

        // A daemon already running that can verify and swap its own binary never needs to
        // ask for anything.
        if !missing, HelperService.canSelfUpdate(daemonProtocolVersion: daemonProtocolVersion) {
            let quiet = HelperService.requestQuietUpdate()
            if quiet.ok { return quiet }
        }

        // Nothing installed, and this build is signed: let macOS run the daemon out of the
        // app bundle. That is approved once and then no future build needs installing at
        // all. Skipped when a legacy install is present — replacing it would cost the very
        // prompt this is avoiding, and route one already keeps it current.
        if missing, HelperService.isSigned, !HelperService.legacyInstallPresent,
           HelperService.registerBundledDaemon() == nil {
            return (true, "Helper registered with macOS.")
        }

        guard HelperInstaller.canInstall else {
            return (false, "This build has no way to install the helper.")
        }
        return HelperInstaller.install()
    }

    /// Poll until the newly installed daemon answers, then refresh.
    ///
    /// This replaced a flat two-second sleep, which had to be either optimistic or slow:
    /// launchd still has to start the helper and the helper binds its socket before it
    /// serves, so a fixed wait raced the daemon on a busy Mac and idled on a quick one.
    private nonisolated func resyncAfterInstall(attempts: Int = 20) async {
        var answered = false
        for _ in 0..<attempts {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if (try? ControlClient.send(.getStatus)) != nil { answered = true; break }
        }
        await MainActor.run {
            // Installed fine, yet nothing is serving the socket: on this Mac the daemon
            // can't come up — charge control the SMC doesn't expose, a Gatekeeper kill, a
            // bootstrap that didn't take. Left alone this is the one path that would ask
            // for a password on every single launch and never get anywhere, so it counts
            // as a refusal and the log gets named instead.
            if !answered {
                self.autoInstallDeclined = true
                self.helperInstallFailure =
                    "The helper installed but isn't responding. See /var/log/ewiz-helper.log."
            }
            self.refresh()
        }
    }

    /// Pressing the button is an explicit yes, so it clears a remembered refusal and lets
    /// later launches go back to keeping the helper current on their own.
    func clearAutoInstallRefusal() {
        autoInstallDeclined = false
        helperInstallFailure = nil
    }

    /// Uninstalling is an explicit no, and has to be recorded as one.
    ///
    /// Otherwise the very next status poll finds no daemon, decides that's a fresh machine
    /// wanting a helper, and installs it straight back — turning "remove this" into a loop
    /// that argues with the person using it.
    func suppressAutoInstall() {
        didAttemptHelperUpdate = true
        autoInstallDeclined = true
        helperInstallFailure = nil
    }

    /// Push GUI settings to the daemon, preserving fields the menu doesn't edit (mode).
    func apply() {
        // Before the first answer every field here is a placeholder, and this sends the whole
        // config: a hotkey or an automation firing in that window switched the charge limit
        // off, because `limitEnabled` still held its default. Fetch the real one instead.
        guard hasSynced else { refresh(); return }
        var cfg = currentConfig
        cfg.chargeLimitEnabled = limitEnabled
        cfg.chargeLimit = limit
        cfg.resumeMargin = resumeMargin
        cfg.heatAwareEnabled = heatAwareEnabled
        cfg.maxChargeTempC = maxChargeTempC
        cfg.magSafeLedMode = magSafeLedMode
        cfg.magSafeLedEnabled = (magSafeLedMode == .status) // keep legacy flag in sync
        cfg.dischargeEnabled = dischargeEnabled
        cfg.holdCharge = holdCharge
        cfg.disableChargingBeforeSleep = disableChargingBeforeSleep
        cfg.preventIdleSleep = preventIdleSleep
        cfg.sealedSleepHibernateAfter = sealedSleepHibernateAfter
        // An auto-off deadline means nothing once the toggle is off (switched off by
        // hand, or by a schedule edit), and a stale countdown in the UI would be a lie.
        if !keepAwake { keepAwakeUntil = nil }
        cfg.keepAwake = keepAwake
        cfg.keepAwakeOnBattery = keepAwakeOnBattery
        cfg.keepAwakeRequiresTask = keepAwakeRequiresTask
        cfg.keepAwakeProcesses = keepAwakeProcesses
        cfg.keepAwakeMinCpu = keepAwakeMinCpu
        cfg.keepAwakeMaxTempC = keepAwakeMaxTempC
        cfg.sleepWhenTaskDone = sleepWhenTaskDone
        cfg.keepAwakeSchedules = keepAwakeSchedules
        cfg.keepAwakeUntil = keepAwakeUntil
        cfg.schedules = schedules
        cfg.readyBy = readyBy
        cfg.chargePower = chargePower
        cfg.slowCharge = chargePower < 100   // keep the legacy flag in sync
        let base = currentConfig
        currentConfig = cfg
        // Merged against what the daemon has now, not sent as built: everything here except
        // the field just edited is as of the last poll, up to 30 seconds old, and anything
        // the daemon or an agent changed since would go back stale. See `EWizConfig.merge`.
        pendingWrites += 1
        Task.detached {
            let now = try? ControlClient.send(.getStatus)
            let merged = now.map { EWizConfig.merge(base: base, local: cfg, remote: $0.config) } ?? cfg
            let result = try? ControlClient.send(.setConfig(merged))
            await self.finishCommand(result)
        }
    }

    func setLowPowerMode(_ on: Bool) {
        command(.setLowPowerMode(on))
    }

    /// Long-term care: park the battery near 60% and run off the adapter.
    ///
    /// Composes settings the daemon already enforces rather than adding a mode of its own —
    /// see `LongevityCare` for why 60 and why this isn't the same as "don't charge".
    var longevityCare: Bool { LongevityCare.isActive(currentConfig) }

    func setLongevityCare(_ on: Bool) {
        let cfg = currentConfig.applyingLongevityCare(on)
        // Mirror into the published fields the rest of the UI reads, or the sliders and
        // switches would keep showing the old values until the next daemon refresh.
        limitEnabled = cfg.chargeLimitEnabled
        limit = cfg.chargeLimit
        dischargeEnabled = cfg.dischargeEnabled
        heatAwareEnabled = cfg.heatAwareEnabled
        holdCharge = cfg.holdCharge
        apply()
    }

    /// Seal the Mac for closed-lid sleep, or hand the settings back to macOS.
    ///
    /// Its own request rather than part of `apply()`: switching it on has to snapshot the
    /// pmset state it displaces, and switching it off has to write that state back. A
    /// config save has no transition to hang either on. Optimistic locally, corrected by
    /// the refresh if the Mac refused.
    func setSealedSleep(_ on: Bool) {
        sealedSleep = on
        command(.setSealedSleep(on))
    }

    /// Instant wake, or hibernation. Re-applies the whole seal, because the choice *is*
    /// which `hibernatemode` the seal writes.
    func setSealedSleepFastWake(_ fast: Bool) {
        sealedSleepFastWake = fast
        command(.setSealedSleepFastWake(fast))
    }

    /// Pause charging: minutes > 0 = for that long; 0 = resume; -1 = indefinitely.
    func pauseCharging(minutes: Int) {
        command(.pauseCharging(minutes))
    }
    func resumeCharging() { pauseCharging(minutes: 0) }

    /// Start / cancel a one-shot charge-to-100% calibration.
    func startCalibration() { setCalibration(true) }
    func cancelCalibration() { setCalibration(false) }
    private func setCalibration(_ on: Bool) {
        calibrating = on // optimistic
        command(.calibrateToFull(on))
    }

    /// Apply a preset save mode; state refreshes when the daemon replies.
    func applyMode(_ newMode: SaveMode) {
        mode = newMode // optimistic
        command(.applyMode(newMode))
    }

    /// Whether the daemon is keeping charge off the battery right now, by whichever lever
    /// this Mac gives it.
    ///
    /// Not `!chargingEnabled`. A Mac with no SMC charge-inhibit key has nothing to inhibit
    /// charging with, so the daemon reports charging as enabled there and holds the level by
    /// cutting the adapter instead — which made every "Holding at 80%" in the app
    /// unreachable on exactly the hardware whose owners most need telling that the limit is
    /// doing something. `discharging` is that adapter cut; `pauseReason == "hold"` is the
    /// daemon naming it.
    var isHoldingCharge: Bool {
        !chargingEnabled || discharging || pauseReason == "hold"
    }

    /// The one reading of what charging is doing that every surface draws from — the
    /// glyph, the header, the hint rows, the tooltip and the notifications. See
    /// `ChargeDisplay` for why it isn't each view's own arithmetic.
    func display(for snap: BatterySnapshot) -> ChargeDisplay {
        ChargeDisplay(ChargeDisplayInput(
            percentage: snap.percentage,
            isCharging: snap.isCharging,
            isPluggedIn: snap.isPluggedIn,
            isFullyCharged: snap.isFullyCharged,
            limitEnabled: limitEnabled,
            effectiveLimit: effectiveLimit,
            nativeLimitApplied: nativeLimitApplied,
            usesNativeLimit: !nativeLimitSteps.isEmpty,
            holdCharge: holdCharge,
            pauseReason: pauseReason,
            discharging: discharging,
            isPaused: isPaused,
            calibrating: calibrating,
            chargePower: chargePower))
    }

    // MARK: - Editing

    /// Controls the user has hold of right now (a slider mid-drag).
    ///
    /// The periodic status poll ingests the daemon's config wholesale, and the sliders only
    /// send their value on mouse-up — so a poll landing mid-drag wrote the daemon's number
    /// straight over the one under the user's finger and the knob jumped back. Counted
    /// rather than a flag, because two controls can be live at once in Settings.
    private var editingControls = 0

    func beginEditing() { editingControls += 1 }

    /// Ends the hold *and* commits — the two always happened together, and splitting them
    /// is how a slider ends up silently not saving.
    func endEditing() {
        editingControls = max(0, editingControls - 1)
        apply()
    }

    func isPowerToggleOn(_ toggle: PowerToggle) -> Bool {
        powerToggles[toggle.rawValue] ?? false
    }

    /// The toggle's state, or nil when this Mac doesn't expose the key at all.
    ///
    /// The distinction `isPowerToggleOn` flattens. For a switch, "missing" and "off" are
    /// the same thing; for the closed-lid audit they are opposites — a key that isn't there
    /// can't be leaking, and listing it as a problem would put a permanent mark against a
    /// Mac doing everything it can.
    func powerToggleState(_ toggle: PowerToggle) -> Bool? {
        powerToggles[toggle.rawValue]
    }

    // MARK: - Charging schedules

    func addSchedule(_ schedule: ChargeSchedule = ChargeSchedule()) {
        schedules.append(schedule)
        apply()
    }

    func updateSchedule(_ schedule: ChargeSchedule) {
        guard let i = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[i] = schedule
        apply()
    }

    func updateOrAddSchedule(_ schedule: ChargeSchedule) {
        if let i = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[i] = schedule
        } else {
            schedules.append(schedule)
        }
        apply()
    }

    func removeSchedule(_ schedule: ChargeSchedule) {
        schedules.removeAll { $0.id == schedule.id }
        apply()
    }

    var activeSchedule: ChargeSchedule? {
        schedules.first { $0.isActive(at: Date()) }
    }

    // MARK: - Always Active windows and timer

    func updateOrAddAwakeSchedule(_ schedule: AwakeSchedule) {
        if let i = keepAwakeSchedules.firstIndex(where: { $0.id == schedule.id }) {
            keepAwakeSchedules[i] = schedule
        } else {
            keepAwakeSchedules.append(schedule)
        }
        apply()
    }

    func updateAwakeSchedule(_ schedule: AwakeSchedule) {
        guard let i = keepAwakeSchedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        keepAwakeSchedules[i] = schedule
        apply()
    }

    func removeAwakeSchedule(_ schedule: AwakeSchedule) {
        keepAwakeSchedules.removeAll { $0.id == schedule.id }
        apply()
    }

    /// The window holding the Mac awake right now, if any (first match wins).
    var activeAwakeSchedule: AwakeSchedule? {
        keepAwakeSchedules.first { $0.isActive(at: Date()) }
    }

    /// True once any window is armed, at which point the timetable — not just the
    /// toggle — decides when Always Active holds.
    var hasAwakeSchedules: Bool { keepAwakeSchedules.contains { $0.enabled } }

    /// Whether Always Active is holding as far as the timetable and timer are concerned.
    /// The daemon layers the power, task and heat gates on top of this.
    var keepAwakeArmed: Bool {
        EWizConfig.keepAwakeArmed(enabled: keepAwake, until: keepAwakeUntil,
                                      schedules: keepAwakeSchedules)
    }

    /// Turn Always Active on, optionally with an auto-off deadline (nil = until turned
    /// off). The daemon owns the expiry, so the timer still fires with the Mac asleep
    /// or the app quit.
    func startKeepAwake(minutes: Int? = nil) {
        keepAwakeUntil = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
        keepAwake = true
        apply()
    }

    func stopKeepAwake() {
        keepAwake = false   // apply() clears the deadline
        apply()
    }

    func setPowerToggle(_ toggle: PowerToggle, _ on: Bool) {
        command(.setPowerToggle(toggle, on))
    }

    /// Assign only when the value actually changed, so a status poll that returns
    /// identical state doesn't fire a burst of objectWillChange (and needless redraws).
    private func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<ChargeLimitStore, T>, _ newValue: T) {
        if self[keyPath: keyPath] != newValue { self[keyPath: keyPath] = newValue }
    }

    private func ingest(_ response: ControlResponse?) {
        guard let r = response else {
            // One missed answer is a busy daemon, not a missing one: a sleep transition holds
            // its lock for seconds. Treating it as missing swapped the whole limit section for
            // the install banner mid-click, and on launch put an admin prompt up to reinstall
            // a helper that was installed and running.
            failedPolls += 1
            guard failedPolls >= 2 else {
                // Ask again soon rather than at the next 30s poll, so a missing helper still
                // gets found within seconds.
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    Task { @MainActor in self?.refresh() }
                }
                return
            }
            set(\.daemonAvailable, false)
            // Nothing is listening. If this bundle carries the installer, put the helper in
            // place now rather than waiting to be asked from a settings pane.
            autoInstallHelperIfNeeded(missing: true)
            return
        }
        failedPolls = 0
        hasSynced = true
        set(\.daemonAvailable, true)
        set(\.daemonProtocolVersion, r.daemonProtocolVersion)
        set(\.daemonBuildVersion, r.daemonBuildVersion)
        autoInstallHelperIfNeeded(missing: false)
        set(\.currentConfig, r.config)
        set(\.schemeDescription, r.schemeDescription)
        let before = (chargingEnabled, discharging, pauseReason)
        set(\.chargingEnabled, r.chargingEnabled)
        set(\.lowPowerMode, r.lowPowerModeEnabled)
        set(\.powerToggles, r.powerToggles)
        set(\.pauseReason, r.pauseReason)
        set(\.nativeLimitSteps, r.nativeLimitSteps)
        set(\.nativeLimitApplied, r.nativeLimitApplied)
        set(\.chargePowerSupported, r.chargeControlSupported)
        set(\.mode, r.config.mode)
        set(\.limitEnabled, r.config.chargeLimitEnabled)
        set(\.limit, r.config.chargeLimit)
        set(\.resumeMargin, r.config.resumeMargin)
        set(\.heatAwareEnabled, r.config.heatAwareEnabled)
        set(\.maxChargeTempC, r.config.maxChargeTempC)
        set(\.magSafeLedMode, r.config.magSafeLedMode)
        set(\.magSafeSupported, r.magSafeSupported)
        set(\.dischargeEnabled, r.config.dischargeEnabled)
        set(\.holdCharge, r.config.holdCharge)
        set(\.highPowerModeSupported, r.highPowerModeSupported)
        set(\.highPowerMode, r.highPowerModeEnabled)
        set(\.sensors, r.sensors)
        set(\.dischargeSupported, r.dischargeSupported)
        set(\.discharging, r.discharging)
        set(\.disableChargingBeforeSleep, r.config.disableChargingBeforeSleep)
        set(\.preventIdleSleep, r.config.preventIdleSleep)
        set(\.keepAwake, r.config.keepAwake)
        set(\.keepAwakeOnBattery, r.config.keepAwakeOnBattery)
        set(\.keepAwakeRequiresTask, r.config.keepAwakeRequiresTask)
        set(\.keepAwakeProcesses, r.config.keepAwakeProcesses)
        set(\.keepAwakeMinCpu, r.config.keepAwakeMinCpu)
        set(\.keepAwakeMaxTempC, r.config.keepAwakeMaxTempC)
        set(\.sleepWhenTaskDone, r.config.sleepWhenTaskDone)
        set(\.sealedSleep, r.config.sealedSleep)
        set(\.sealedSleepFastWake, r.config.sealedSleepFastWake)
        set(\.sealedSleepHibernateAfter, r.config.sealedSleepHibernateAfter)
        set(\.hibernateMode, r.hibernateMode)
        set(\.standbyEnabled, r.standbyEnabled)
        set(\.sealedSleepRefused, r.sealedSleepRefused)
        set(\.keepAwakeSchedules, r.config.keepAwakeSchedules)
        set(\.keepAwakeUntil, r.config.keepAwakeUntil)
        set(\.schedules, r.config.schedules)
        set(\.readyBy, r.config.readyBy)
        set(\.slowCharge, r.config.slowCharge)
        set(\.chargePower, r.config.chargePower)
        set(\.calibrating, r.config.calibrateToFull)
        set(\.pauseUntil, r.config.pauseUntil)

        // The helper changed what the battery is doing → nudge the battery store so the
        // panel and the menu-bar icon catch up now, not on the next slow poll.
        //
        // It watched `chargingEnabled` alone, which never changes on a Mac with no SMC
        // charge key: the hold there is the adapter or macOS's limit. So releasing a hold
        // brought the adapter back, the battery started charging and the MagSafe light
        // went amber, while the panel said "Plugged in, not charging" for up to 45 s.
        if before != (chargingEnabled, discharging, pauseReason) {
            NotificationCenter.default.post(name: .ewizChargeStateChanged, object: nil)
        }
    }
}
