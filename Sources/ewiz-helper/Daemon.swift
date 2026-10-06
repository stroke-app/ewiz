import Foundation
import IOKit
import IOKit.pwr_mgt
import EWizKit

/// Enforcement loop plus control server: holds the configured charge limit.
///
/// Safety: SIGTERM/SIGINT re-enables charging so the Mac is never left unable to
/// charge. SMC access is serialized with `lock` (tick loop and connection handler
/// both touch it); `@unchecked Sendable` is sound because mutable state is only
/// reached under `lock`.
final class Daemon: @unchecked Sendable {
    private let smc = SMC()
    private let charge: ChargeController
    private let lock = NSLock()

    // History sampling. Timed rather than counted in ticks, because the tick rate
    // itself varies (see `nextInterval`) and the graph's spacing shouldn't.
    private var lastSampleAt: Date?
    private let sampleInterval = 300.0   // ~5 min between history points

    // Why charging is currently paused ("limit"/"heat"/nil), for status reporting.
    private var lastPauseReason: String?
    // Charge-limit hysteresis, tracked explicitly rather than inferred from the raw
    // SMC charging flag — duty-cycling (Charge Power < 100) also toggles that flag,
    // and reading it back would latch the "hold at limit" branch during a rest phase,
    // stalling charging inside the band. Set at/above the limit, cleared below
    // (limit − resumeMargin); charging is held while true.
    private var holdingAtLimit = false
    // °C below maxChargeTempC at which heat-paused charging may resume.
    private let heatResumeMargin = 2.0
    // Have we ever read a battery temperature? Used to fail safe: if the sensor has
    // worked before but a read fails while heat-aware is on, we pause charging rather
    // than silently charge uncapped. Macs that never expose a temp sensor stay unblocked.
    private var sawTemperature = false
    // Last MagSafe LED we set, so handing the light back to macOS happens once.
    private var lastLed: MagSafeLED?

    // Post-wake settle: a tick gap ≫ interval implies we slept; hold charging + LED off briefly.
    private var lastTickAt: Date?
    private var settleUntil: Date?
    /// Our own sleep/wake hook, so the pre-sleep charge cut doesn't depend on the GUI.
    private let sleepWatcher = SleepWatcher()
    /// Held so the tick loop can notice the control socket being taken from under us.
    private var controlServer: ControlServer?
    /// What the run loop waits after the current tick; `nextInterval` sets it from
    /// `TickPolicy`, which is where the reasoning about cadence lives.
    private var tickInterval = TickPolicy.active
    private var wakeSettleDuration: Double { 15.0 }   // how long to settle after wake

    // DispatchSource fires cleanup on this queue in a normal context, not an async-signal handler.
    private let signalQueue = DispatchQueue(label: "com.ewiz.helper.signals")
    private var signalSources: [DispatchSourceSignal] = []

    // When the end-to-end socket probe last ran, and the rebinds it has provoked. The probe
    // is the only check that can see a dead accept loop, and it costs a round trip, so it
    // runs on a slow cadence rather than every tick.
    private var lastSocketProbe = Date()
    private var socketRebinds: [Date] = []

    // Deferred hibernation (see `DeferredHibernate`): the wake we booked on the way into a
    // closed-lid sleep, and whether that wake is the one we are expecting. Both live in
    // memory on purpose — hibernation restores the process image, so they survive the very
    // sleep they describe, and a daemon restart should forget a deferral it can't finish.
    private var deferredWakeStamp: String?
    private var deferredHibernateArmed = false
    /// When the booked wake is due, so the tick loop can finish a deferral the wake hook
    /// never reported.
    private var deferredHibernateDue: Date?
    private var handedOverToHibernation = false

    /// Level the adapter hold is parked at, remembered from the tick that armed it, and
    /// whether the adapter is currently cut to defend it. Only used on Macs with no
    /// charge-inhibit key, where the adapter is the one lever there is.
    private var holdAnchor: Int?
    private var adapterHolding = false
    /// The mark `adapterHolding` was worked out against; see `adapterHoldWanted`.
    private var adapterHoldMark: Int?
    /// How far the level may fall below the mark before the adapter comes back. Wide
    /// enough that the top-up isn't a permanent flutter between power sources, narrow
    /// enough that "held at 85%" means 85%.
    private let adapterHoldBand = 2
    /// Whether the adapter is cut once this tick's `manageDischarge` has run. The LED
    /// reads it, because the snapshot it would otherwise use was taken before the cut.
    private var adapterCut = false

    /// macOS's own charge limit, on a Mac whose SMC charge keys are gated (see
    /// `NativeChargeLimit`). nil everywhere else, including Macs with a real key.
    private var nativeLimit: NativeChargeLimit?
    /// The step eWiz has macOS enforcing; nil when it owns none. Persisted, so a
    /// restart still knows which limit is ours to take back.
    private var nativeApplied: Int?
    /// When PowerUIAgent was last asked what's in force. Each ask is a round trip.
    private var nativeCheckedAt: Date?
    /// Plugged in, not taking charge, because the native limit says so. What the app is
    /// told as "held", since there's no SMC flag on this Mac to report instead.
    private var nativeHolding = false
    /// On the cable but running off the battery, because the battery is above the step
    /// macOS is holding and macOS brings it down. `pmset` says "AC attached; not charging"
    /// throughout, so without this the app would show a draining battery as "held".
    private var nativeDraining = false

    /// Whether this Mac exposes an SMC charge-inhibit key. Resolved once the SMC is open.
    /// False disables charge enforcement only — the daemon still serves everything else,
    /// because Sealed Sleep, the pmset toggles and Always Active need no such key.
    private var chargeControlSupported = false

    // Held IOPMAssertion preventing idle sleep (0 = none held).
    private var idleSleepAssertion: IOPMAssertionID = 0

    // "Always Active" state; nil disablesleep = not yet written, so we pmset only on change.
    private var keepAwakeAssertion: IOPMAssertionID = 0
    /// Held only in docked clamshell — lid shut with a monitor attached — where the display
    /// the idle timer would put to sleep is the one being worked on (0 = none held).
    private var keepAwakeDisplayAssertion: IOPMAssertionID = 0
    private var lastDisableSleep: Bool?
    // Last scheduled-window verdict, so a window opening or closing is logged once.
    private var lastKeepAwakeArmed = false
    /// Last hold state the LED reacted to, so the engage blink fires once per change.
    private var lastHoldForLed = false
    // Force display off once per lid-closed spell while keep-awake holds; resets when the lid opens.
    private var displayForcedOffWhileClosed = false

    // Auto-sleep-when-task-done state. We only sleep once we've actually seen the
    // matching task running (so enabling the option while idle doesn't sleep), and
    // only after it's been gone for a few ticks (so a brief gap between a build's
    // sub-processes doesn't sleep prematurely).
    private var keepAwakeSawTask = false
    private var keepAwakeTaskIdleTicks = 0
    private let sleepAfterTaskIdleTicks = 3   // ~30s gone before we sleep

    // Charge-power duty cycle in long phases (≥ minChargeDwell) to avoid flicker/hardware thrash.
    private let minChargeDwell: TimeInterval = 120   // ≥ 2 min per phase
    private var chargeCycleCharging = true
    private var chargeCyclePhaseStart: Date?

    // Cache pmset-derived state briefly (each read forks pmset); invalidated when we change it.
    private var pmsetCacheAt: Date?
    private var pmsetCacheLPM = false
    private var pmsetCacheToggles: [String: Bool] = [:]
    private var pmsetCacheHighPower = (supported: false, enabled: false)
    private var pmsetCacheHibernate: Int?
    private var pmsetCacheStandby: Bool?
    /// pmset keys the last Sealed Sleep write asked for and didn't get, reported to the app.
    private var sealedSleepRefused: [String] = []
    // Longer than the GUI's 30s status poll so periodic refreshes hit the cache
    // instead of forking two `pmset` each time; we invalidate on any change we make.
    private let pmsetCacheTTL: TimeInterval = 60

    init() {
        charge = ChargeController(smc: smc)
    }

    static func run() {
        Daemon().start()
    }

    private func start() {
        do { try smc.open() } catch {
            err("cannot open SMC: \(error)")
            exit(2)
        }
        // No charge-inhibit key is not a reason to quit. Up to build 20 this exited, launchd
        // respawned it forever, and the app — which knows the helper only by its socket —
        // reported "Helper not installed" however many times you installed it. Sealed Sleep,
        // the sleep/wake toggles, Low Power Mode and Always Active all work without it.
        chargeControlSupported = charge.isChargingControlSupported
        if !chargeControlSupported {
            let native = NativeChargeLimit()
            if native.isSupported {
                nativeLimit = native
                nativeApplied = NativeChargeLimitOwnership.load()
                log("no SMC charge-inhibit key; limiting through macOS's own charge limit (\(native.steps.map(String.init).joined(separator: "/"))%)")
            } else {
                log("no SMC charge-inhibit key on this Mac; charge limiting is off, everything else runs")
            }
        }

        // Fan control was removed, but forced fan mode lives in the SMC and outlives the
        // build that set it. Hand back anything an older helper left pinned, once, here.
        let releasedFans = FanRelease.releaseAll(smc)
        if releasedFans > 0 { log("handed \(releasedFans) forced fan(s) back to macOS") }

        reassertSealedSleepIfNeeded()

        installSignalHandlers()

        let server = ControlServer { [weak self] req in
            self?.handle(req) ?? Self.failureResponse()
        }
        server.start()
        controlServer = server

        // Our own sleep hook. Enforcement stops dead while the Mac is asleep, so the
        // last thing we tell the SMC has to be safe — and we can't rely on the GUI to
        // ask for that, since it may not be running.
        sleepWatcher.onWillSleep = { [weak self] in self?.cutChargingForSleep() }
        sleepWatcher.onDidWake = { [weak self] in self?.reevaluateAfterWake() }
        sleepWatcher.start()

        // A deferral that never finished — the daemon was killed, or the Mac was restarted
        // while hibernating was set — would otherwise leave every close taking 30 seconds
        // to open with nothing on screen explaining why.
        let startupConfig = ConfigStore.load()
        if startupConfig.sealedSleepFastWake, DeferredHibernate.isHibernating {
            DeferredHibernate.restoreFastWake()
            log("instant wake restored (a deferred hibernation was left applied)")
        }

        log("daemon started (scheme: \(charge.schemeDescription), displays: \(SystemPower.displays().rawValue))")

        while true {
            lock.lock()
            tick()
            let wait = tickInterval
            lock.unlock()
            // A daemon nobody can reach is worse than no daemon: the app blocks on a socket
            // that will never answer, and launchd sees a healthy job.
            //
            // Two ways that happens, and the second one shipped: another instance takes the
            // path (the inode check), or our own listener stops listening while the path
            // stays exactly where it was. The second leaves the socket file in place, so
            // every connection is refused by a daemon that still thinks it is serving —
            // which is what left a Mac unmanaged overnight and cost 6%.
            //
            // Rebinding first, because exiting throws away everything this process is
            // holding: the charge state, a hibernation deferral part-way through, the
            // sealed-sleep snapshot that says how to put the Mac back.
            if let controlServer, !controlServer.isReachable || dueForSocketProbe(controlServer) {
                if controlServer.rebind() {
                    log("control socket was unreachable; rebound in place")
                    // A rebind that keeps happening is a rebind that isn't fixing anything.
                    // Three inside five minutes means this process cannot hold a listener, and
                    // a restart is the honest answer — a daemon logging the same repair every
                    // tick is how a broken health check hides in plain sight for an hour.
                    socketRebinds.append(Date())
                    socketRebinds = socketRebinds.filter { $0 > Date().addingTimeInterval(-300) }
                    if socketRebinds.count >= 3 {
                        err("control socket rebound 3 times in five minutes; exiting so launchd restarts us")
                        exit(6)
                    }
                } else {
                    err("control socket unreachable and cannot be rebound; exiting so launchd restarts us")
                    exit(6)
                }
            }
            Thread.sleep(forTimeInterval: wait)
        }
    }

    /// Every two minutes, check that something is still accepting on the socket. The probe
    /// is answered on the accept thread without the daemon's lock, so a slow request can't
    /// make a live listener look dead.
    private func dueForSocketProbe(_ server: ControlServer) -> Bool {
        guard Date().timeIntervalSince(lastSocketProbe) >= 120 else { return false }
        lastSocketProbe = Date()
        guard !server.answersItsOwnCall() else { return false }
        err("control socket accepted a connection but answered nothing")
        return true
    }

    // MARK: - Control handler (called from server thread)

    private func handle(_ request: ControlRequest) -> ControlResponse {
        lock.lock()
        defer { lock.unlock() }

        switch request {
        case .getStatus:
            return status(ok: true)

        case .setConfig(let incoming):
            var cfg = incoming
            cfg.chargeLimit = min(100, max(20, cfg.chargeLimit))
            // wide recharge band (≤40%) but keep the floor (limit − margin) ≥ 20%
            cfg.resumeMargin = max(1, min(cfg.resumeMargin, 40, cfg.chargeLimit - 20))
            // Sealed Sleep has a transition to run, so a config write can't be allowed to
            // flip it: the snapshot it needs on the way in, and the restore on the way out,
            // both live in `setSealedSleep`. Keep whatever is actually in force.
            let inForce = ConfigStore.load()
            cfg.sealedSleep = inForce.sealedSleep
            cfg.sealedSleepFastWake = inForce.sealedSleepFastWake
            cfg.sealedSleepRestore = inForce.sealedSleepRestore
            do {
                try ConfigStore.save(cfg)
                tick() // apply immediately
                return status(ok: true, message: "saved")
            } catch {
                return status(ok: false, message: "save failed: \(error)")
            }

        case .setSealedSleep(let on):
            return setSealedSleep(on, fastWake: ConfigStore.load().sealedSleepFastWake)

        case .setSealedSleepFastWake(let fast):
            let cfg = ConfigStore.load()
            // Re-applying with the new choice is the whole operation: it rewrites
            // hibernatemode one way or the other and leaves everything else sealed.
            guard cfg.sealedSleep else {
                var next = cfg
                next.sealedSleepFastWake = fast
                do { try ConfigStore.save(next) } catch {
                    return status(ok: false, message: "save failed: \(error)")
                }
                return status(ok: true, message: "saved")
            }
            return setSealedSleep(true, fastWake: fast)

        case .setLowPowerMode(let on):
            let ok = LowPowerMode.set(on)
            invalidatePmsetCache()
            return status(ok: ok, message: ok ? "lowpowermode set" : "pmset failed")

        case .setPowerToggle(let toggle, let on):
            let ok = PowerSettings.set(toggle, on)
            invalidatePmsetCache()
            return status(ok: ok, message: ok ? "\(toggle.rawValue) set" : "pmset failed")

        case .applyMode(let mode):
            return applyMode(mode)

        case .pauseCharging(let minutes):
            var cfg = ConfigStore.load()
            if minutes == 0 {
                cfg.pauseUntil = nil
            } else if minutes < 0 {
                cfg.pauseUntil = Date.distantFuture
            } else {
                cfg.pauseUntil = Date().addingTimeInterval(Double(minutes) * 60)
            }
            do { try ConfigStore.save(cfg); tick(); return status(ok: true, message: "pause updated") }
            catch { return status(ok: false, message: "save failed: \(error)") }

        case .prepareForSleep:
            // The GUI asking for what the daemon now also does for itself. Kept so an
            // older app build still gets the cut, and because the app sees lid-close
            // sleeps the daemon's hook and this can race — both paths are idempotent.
            let cut = cutChargingForSleepLocked()
            releaseMemoryIfSealed()
            return status(ok: cut, message: "sleep handled")

        case .calibrateToFull(let on):
            var cfg = ConfigStore.load()
            cfg.calibrateToFull = on
            do { try ConfigStore.save(cfg); tick()
                 return status(ok: true, message: on ? "calibration started" : "calibration cancelled") }
            catch { return status(ok: false, message: "save failed: \(error)") }

        case .clearSamples:
            // GUI can't delete the root-owned history file; restart the sampling clock
            // so a cleared graph doesn't immediately re-append mid-tick.
            HistoryStore.clear()
            lastSampleAt = Date()
            return status(ok: true, message: "history cleared")

        case .installUpdate(let path):
            do { try HelperUpdate.apply(replacementAt: path) } catch {
                err("update refused: \(error)")
                return status(ok: false, message: "\(error)")
            }
            log("helper replaced on disk; restarting onto the new build")
            // Answer before going down. The client is still waiting on this connection, and
            // exiting inside the handler would reach it as a dropped socket — indistinguishable
            // from the daemon crashing on the request. The delay also gets us out from under
            // `lock`, which this handler holds and `performCleanupAndExit` takes again.
            // launchd's KeepAlive starts the replacement.
            Thread.detachNewThread { [self] in
                Thread.sleep(forTimeInterval: 0.5)
                performCleanupAndExit()
            }
            return status(ok: true, message: "helper updated")
        }
    }

    /// Apply the daemon-controlled parts of a save mode; the GUI applies lid-radio prefs separately.
    private func applyMode(_ mode: SaveMode) -> ControlResponse {
        let p = mode.profile
        let previous = ConfigStore.load()
        // The settings half of the switch is a pure function in EWizKit, where it can
        // be tested; everything below here is the side effects it implies.
        let cfg = previous.applying(mode)

        do { try ConfigStore.save(cfg) } catch {
            return status(ok: false, message: "save failed: \(error)")
        }

        LowPowerMode.set(p.lowPowerMode)
        // Sealed Sleep owns the sleep/wake toggles while it's on, and a mode must not take
        // them back. Every profile names a value for these, so without this guard picking
        // "Off" — whose profile turns Power Nap *on* — would quietly unseal the Mac and
        // leave the switch still reading sealed. The audit would eventually show the leak;
        // the user would have no idea what caused it.
        if !cfg.sealedSleep {
            PowerSettings.set(.powerNap, p.powerNap)
            PowerSettings.set(.wakeOnNetwork, p.wakeOnNetwork)
            PowerSettings.set(.tcpKeepAlive, p.tcpKeepAlive)
        }
        // Ordering matters on the way out: Low Power Mode and High Power Mode are two
        // faces of the same pmset key, so the last write wins. Low Power first, High
        // Power second, and a mode that wants neither writes 0 to both harmlessly.
        let highPowerApplied = HighPowerMode.set(p.highPowerMode)
        invalidatePmsetCache()

        tick() // enforce charge limit immediately

        // Report what the Mac couldn't do rather than claiming the whole mode landed. Only a
        // handful of Macs expose High Power Mode, and a mode that reports success on
        // hardware which ignored half of it is lying.
        let note = (p.highPowerMode && !highPowerApplied)
            ? "mode \(mode.rawValue): this Mac has no High Power Mode"
            : "mode \(mode.rawValue)"
        return status(ok: true, message: note)
    }

    /// pmset-derived state, cached for `pmsetCacheTTL` to avoid forking pmset on every status call.
    private func pmsetState() -> (lpm: Bool, toggles: [String: Bool],
                                  highPowerSupported: Bool, highPower: Bool,
                                  hibernateMode: Int?, standby: Bool?) {
        if pmsetCacheAt == nil || Date().timeIntervalSince(pmsetCacheAt!) >= pmsetCacheTTL {
            pmsetCacheLPM = LowPowerMode.isEnabled()
            // One read, every parse — high power, the toggles and the sleep keys all live
            // in the same output.
            let custom = PowerSettings.readCustom()
            pmsetCacheToggles = PowerSettings.readToggles(from: custom)
            pmsetCacheHighPower = HighPowerMode.state(from: custom)
            let values = PowerSettings.readValues(from: custom).battery
            pmsetCacheHibernate = values["hibernatemode"].flatMap(Int.init)
            pmsetCacheStandby = values["standby"].map { $0 == "1" }
            pmsetCacheAt = Date()
        }
        return (pmsetCacheLPM, pmsetCacheToggles,
                pmsetCacheHighPower.supported, pmsetCacheHighPower.enabled,
                pmsetCacheHibernate, pmsetCacheStandby)
    }

    private func invalidatePmsetCache() { pmsetCacheAt = nil }

    private func status(ok: Bool, message: String? = nil) -> ControlResponse {
        let snap = BatteryMonitor.read()
        let pmset = pmsetState()
        return ControlResponse(
            ok: ok,
            config: ConfigStore.load(),
            batteryPercent: snap.percentage,
            chargingEnabled: chargeControlSupported ? ((try? charge.isChargingEnabled()) ?? false) : !nativeHolding,
            schemeDescription: nativeLimit != nil ? "macOS charge limit" : charge.schemeDescription,
            lowPowerModeEnabled: pmset.lpm,
            powerToggles: pmset.toggles,
            pauseReason: lastPauseReason,
            magSafeSupported: charge.isMagSafeSupported,
            dischargeSupported: charge.isAdapterControlSupported,
            discharging: nativeDraining
                || (charge.isAdapterControlSupported && !((try? charge.isAdapterEnabled()) ?? true)),
            sensors: SensorReader.readAll(),
            hibernateMode: pmset.hibernateMode,
            standbyEnabled: pmset.standby,
            sealedSleepRefused: sealedSleepRefused,
            highPowerModeSupported: pmset.highPowerSupported,
            highPowerModeEnabled: pmset.highPower,
            nativeLimitSteps: nativeLimit?.steps ?? [],
            nativeLimitApplied: nativeApplied,
            chargeControlSupported: chargeControlSupported,
            message: message
        )
    }

    private static func failureResponse() -> ControlResponse {
        ControlResponse(ok: false, config: .default, batteryPercent: 0,
                        chargingEnabled: false, schemeDescription: "n/a",
                        lowPowerModeEnabled: false, powerToggles: [:],
                        pauseReason: nil, magSafeSupported: false,
                        dischargeSupported: false, discharging: false,
                        message: "daemon unavailable")
    }

    // MARK: - Enforcement (caller holds lock)

    private func tick() {
        var cfg = ConfigStore.load()
        var snap = BatteryMonitor.read()
        let level = snap.percentage
        let now = Date()

        // Prefer raw SMC AC-W for adapter presence: it survives force-discharge (OS
        // flips to "battery"), keeping onExternalPower-gated decisions stable while draining.
        if let ac = charge.isACPresent() { snap.isExternalConnected = ac }

        recordHistoryIfDue(snap, now: now)

        // Detect wake: a tick gap much larger than the interval we asked for means the
        // clock ran on without us, i.e. we were frozen. Scaled off the interval in
        // force, so backing off to a slow tick doesn't read as a wake every time.
        if let last = lastTickAt, now.timeIntervalSince(last) > tickInterval * 3 {
            settleUntil = now.addingTimeInterval(wakeSettleDuration)
            log("woke from sleep; settling for \(Int(wakeSettleDuration))s")
        }
        lastTickAt = now

        if let until = cfg.pauseUntil, now >= until {
            cfg.pauseUntil = nil
            try? ConfigStore.save(cfg)
        }
        let paused = cfg.pauseUntil != nil

        // A keep-awake timer that has run out clears the toggle too, so the GUI shows
        // "off" rather than an on switch that no longer holds anything. Written back
        // here (not just evaluated) because the deadline may have passed while the Mac
        // was asleep, or with no GUI running at all.
        if let until = cfg.keepAwakeUntil, now >= until {
            cfg.keepAwakeUntil = nil
            cfg.keepAwake = false
            try? ConfigStore.save(cfg)
            log("keep-awake timer elapsed; Always Active turned off")
        }

        // One-shot calibration ends the moment the battery reaches full.
        if cfg.calibrateToFull && (snap.isFullyCharged || level >= 100) {
            cfg.calibrateToFull = false
            try? ConfigStore.save(cfg)
            log("calibration complete (battery full)")
        }

        // We only actively manage charging when limiting or heat-pausing is on.
        let managing = cfg.chargeLimitEnabled || cfg.heatAwareEnabled
        // Settling only holds charging when we'd otherwise be managing it.
        let settling = managing && (settleUntil.map { now < $0 } ?? false)

        let charging = chargeControlSupported ? ((try? charge.isChargingEnabled()) ?? true) : true
        // active schedule window (first match wins) + ready-by top-up; both feed the decision below
        let activeSchedule = cfg.schedules.first { $0.isActive(at: now) }
        let topUp = topUpBypassActive(cfg, level: level, now: now)
        var desired = true
        var reason: String? = nil

        if paused {
            // pause overrides everything
            desired = false; reason = "paused"
        } else if cfg.holdCharge && snap.onExternalPower {
            // "Don't charge while plugged in": hold the level wherever it is. Sits above
            // the limit, schedules and top-ups on purpose — it's the switch you reach for
            // when you want the battery left alone, and it shouldn't be second-guessed.
            desired = false; reason = "hold"
        } else if settling {
            desired = false; reason = "settling"
        } else if let s = activeSchedule, s.action == .hold || s.action == .discharge {
            // hold/discharge window keeps charging off (discharge itself is driven in manageDischarge)
            desired = false; reason = "schedule"
        } else {
            // charge windows, ready-by top-up, and calibration all bypass the limit ceiling
            let bypassLimit = cfg.calibrateToFull || topUp || (activeSchedule?.action == .charge)

            // Hysteresis band, tracked via `holdingAtLimit` (not the raw SMC flag, which
            // duty-cycling toggles): hold once we reach the limit, and keep holding while
            // coasting down through the band until we drop below (limit − resumeMargin),
            // then resume charging back up to the limit.
            if cfg.chargeLimitEnabled && !bypassLimit {
                if level >= cfg.chargeLimit {
                    holdingAtLimit = true
                } else if level < cfg.chargeLimit - cfg.resumeMargin {
                    holdingAtLimit = false
                }
                if holdingAtLimit { desired = false; reason = "limit" }
            } else {
                holdingAtLimit = false   // not enforcing the ceiling right now
            }
            // heat constraint, only while we'd otherwise charge
            if desired, cfg.heatAwareEnabled {
                if let t = snap.temperature {
                    sawTemperature = true
                    if t >= cfg.maxChargeTempC {
                        desired = false; reason = "heat"
                    } else if t >= cfg.maxChargeTempC - heatResumeMargin
                                && !charging && lastPauseReason == "heat" {
                        desired = false; reason = "heat"
                    }
                } else if sawTemperature {
                    // Sensor worked before but this read failed: fail safe (pause)
                    // rather than charge with the thermal cap silently disabled.
                    desired = false; reason = "heat"
                    if lastPauseReason != "heat" {
                        log("heat-aware: temperature unreadable; pausing charging as a precaution")
                    }
                }
            }
        }

        // Duty-cycle to the requested power.
        let enable = chargeDutyGate(desired: desired, power: cfg.chargePower, now: now)

        // Nothing is being held when there's no key to hold it with; reporting a reason
        // would have the app explain a pause that isn't happening.
        lastPauseReason = chargeControlSupported ? (desired ? (enable ? nil : "slow") : reason) : nil
        ensure(enabled: enable, current: charging)
        updateHoldAnchor(cfg, snap)
        applyNativeLimit(nativeLimitWanted(cfg, bypass: cfg.calibrateToFull || topUp
                                               || activeSchedule?.action == .charge), now: now)
        manageDischarge(cfg, snap, scheduleDischarge: activeSchedule?.action == .discharge)
        // With no charge-inhibit key the branch above has no lever and deliberately reports
        // nothing, so the answer to "why has it stopped" comes from the lever this Mac does
        // have: macOS's limit, or failing that the adapter hold.
        nativeHolding = nativeApplied != nil && snap.onExternalPower && !adapterCut && !snap.isCharging
        nativeDraining = nativeHolding && PowerMonitor.read().dischargeWatts > 2
        if !chargeControlSupported {
            lastPauseReason = adapterHolding ? "hold"
                : nativeHolding ? (paused ? "paused" : cfg.holdCharge ? "hold" : "limit") : nil
        }
        updateMagSafeLED(cfg, snap, takingCharge: takingCharge(cfg, snap, desired: desired, enable: enable),
                         settling: settling)
        completeDeferredHibernateIfDue()
        updateIdleSleepAssertion(cfg, snap)
        updateKeepAwake(cfg, snap)
        tickInterval = nextInterval(cfg, snap)
    }

    /// How long to wait before the next tick (see `TickPolicy`). The clamshell read is
    /// skipped unless the config could actually allow a back-off, so the common case
    /// costs nothing.
    private func nextInterval(_ cfg: EWizConfig, _ snap: BatterySnapshot) -> Double {
        guard TickPolicy.hasNothingToManage(cfg, onExternalPower: snap.onExternalPower)
        else { return TickPolicy.active }
        return TickPolicy.interval(cfg, onExternalPower: snap.onExternalPower,
                                   lidClosed: SystemPower.isClamshellClosed())
    }

    /// Whether the battery is taking charge, for the LED: what it is doing, not what the
    /// daemon meant it to do.
    ///
    /// The LED used to follow `desired`, which is intent. On a Mac with no charge-inhibit
    /// key intent and reality part company all the time: the limit's hysteresis said "held"
    /// while the adapter hold had already brought the adapter back for a top-up, so the
    /// battery charged under a green light, and a full battery with no limit set showed
    /// amber because charging was "allowed". The snapshot predates this tick's writes, so
    /// anything cut this tick is taken from the write, not the snapshot.
    private func takingCharge(_ cfg: EWizConfig, _ snap: BatterySnapshot,
                              desired: Bool, enable: Bool) -> Bool {
        if adapterCut { return false }
        if chargeControlSupported, desired, cfg.chargePower < 100 {
            // Duty-cycling: the rest phases are part of a charge in progress, and a light
            // that changed colour every two minutes would be reporting the mechanism.
            return cfg.chargePower > 0 && !snap.isFullyCharged
        }
        if chargeControlSupported, !enable { return false }
        return snap.isCharging
    }

    /// Whether to charge this tick for the requested power (0–100%): 100% passes
    /// through, below 100% duty-cycles in long phases (≥ `minChargeDwell`) to avoid flicker.
    private func chargeDutyGate(desired: Bool, power: Int, now: Date) -> Bool {
        // reset when not charging so it resumes promptly in a fresh charge phase
        guard desired else {
            chargeCyclePhaseStart = nil; chargeCycleCharging = true; return false
        }
        let p = min(100, max(0, power))
        if p >= 100 { chargeCyclePhaseStart = nil; chargeCycleCharging = true; return true }
        if p <= 0  { chargeCyclePhaseStart = nil; chargeCycleCharging = false; return false }

        // minority phase gets the 2-min floor; majority is stretched to hit the ratio (both ≥ 2 min)
        let onTime: TimeInterval
        let offTime: TimeInterval
        if p <= 50 {
            onTime = minChargeDwell
            offTime = minChargeDwell * Double(100 - p) / Double(p)
        } else {
            offTime = minChargeDwell
            onTime = minChargeDwell * Double(p) / Double(100 - p)
        }

        guard let start = chargeCyclePhaseStart else {
            chargeCyclePhaseStart = now; chargeCycleCharging = true; return true
        }
        let elapsed = now.timeIntervalSince(start)
        if chargeCycleCharging {
            if elapsed >= onTime { chargeCycleCharging = false; chargeCyclePhaseStart = now; return false }
            return true
        } else {
            if elapsed >= offTime { chargeCycleCharging = true; chargeCyclePhaseStart = now; return true }
            return false
        }
    }

    /// Ready-by top-up: charge past the limit within the estimated lead time so the
    /// battery hits the target right around the target time. Lead time is estimated
    /// from the gap to target (`timeToFull` is unavailable while holding).
    private func topUpBypassActive(_ cfg: EWizConfig, level: Int, now: Date) -> Bool {
        let r = cfg.readyBy
        guard r.enabled, r.days.contains(now), level < r.targetPercent else { return false }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        guard nowMin <= r.targetMinute else { return false }   // target already passed today
        let minutesUntil = r.targetMinute - nowMin
        // ~1.5 min per percentage point to charge, plus a 15-minute safety buffer.
        let minutesNeeded = Double(r.targetPercent - level) * 1.5 + 15
        return Double(minutesUntil) <= minutesNeeded
    }

    // MARK: - Sleep / wake

    /// Cut charging on the way into sleep, so the battery can't cross the limit while
    /// nothing is watching. Called from the watcher's thread — takes the same lock the
    /// tick loop uses, because both talk to the SMC.
    private func cutChargingForSleep() {
        lock.lock()
        defer { lock.unlock() }
        _ = cutChargingForSleepLocked()
        releaseMemoryIfSealed()
        armDeferredHibernate()
    }

    /// Finish a deferral from the tick loop, for the wakes the sleep hook doesn't see.
    ///
    /// `reevaluateAfterWake` is driven by IOKit's wake notification, and a scheduled dark
    /// wake does not always deliver one to a daemon — the Mac comes up, does its business and
    /// goes back down without our hook running. The deferral then sits armed forever: the
    /// booked wake is spent, nothing hands over to hibernation, and the close costs the full
    /// memory trickle. Which is exactly what one 23-hour close did.
    ///
    /// So the tick checks too. Whichever path notices first, the handover happens once.
    /// Caller must hold `lock`.
    private func completeDeferredHibernateIfDue() {
        guard deferredHibernateArmed, let due = deferredHibernateDue, Date() >= due else { return }
        resolveDeferredHibernate()
    }

    /// Book the wake that turns a long close into a hibernated one. Caller must hold `lock`.
    ///
    /// Battery only, lid only. At a desk the trickle is paid for by the adapter and a
    /// 30-second wake would be the only thing you'd notice, and an idle sleep with the lid
    /// open is someone stepping away from a machine they expect to find awake-ish.
    private func armDeferredHibernate() {
        let cfg = ConfigStore.load()
        // Say so when the deferral is switched off. "Never" is a legitimate choice, but a
        // config holding 0 while Sealed Sleep promises a flat battery line is the difference
        // between a close costing nothing and a close costing 6%, and nothing anywhere said
        // which of the two this Mac was set up for.
        if cfg.sealedSleep, cfg.sealedSleepFastWake, cfg.sealedSleepHibernateAfter == 0 {
            log("hibernation deferral is off; a long close will cost the memory trickle")
        }
        guard cfg.sealedSleep, cfg.sealedSleepFastWake,
              cfg.sealedSleepHibernateAfter > 0, !cfg.keepAwake,
              SystemPower.isClamshellClosed(),
              !BatteryMonitor.read().onExternalPower else { return }

        if let stale = deferredWakeStamp { DeferredHibernate.cancel(stale) }
        deferredWakeStamp = DeferredHibernate.schedule(after: cfg.sealedSleepHibernateAfter)
        deferredHibernateArmed = deferredWakeStamp != nil
        deferredHibernateDue = deferredHibernateArmed
            ? Date().addingTimeInterval(Double(cfg.sealedSleepHibernateAfter) * 60)
            : nil
        if deferredHibernateArmed {
            log("hibernation deferred by \(cfg.sealedSleepHibernateAfter)m")
        } else {
            err("could not book the deferred-hibernate wake; staying in ordinary sleep")
        }
    }

    /// The other half: we asked to be woken, we're awake, so decide which kind of wake this
    /// is. Still shut and off the charger means the close outlasted the deferral, and memory
    /// has nothing left to stay powered for. Caller must hold `lock`.
    private func resolveDeferredHibernate() {
        if let stamp = deferredWakeStamp {
            DeferredHibernate.cancel(stamp)
            deferredWakeStamp = nil
        }

        let lidShut = SystemPower.isClamshellClosed()

        if deferredHibernateArmed {
            deferredHibernateArmed = false
            deferredHibernateDue = nil
            let cfg = ConfigStore.load()
            if lidShut, cfg.sealedSleep, cfg.sealedSleepFastWake,
               !BatteryMonitor.read().onExternalPower {
                _ = cutChargingForSleepLocked()
                handedOverToHibernation = true
                if DeferredHibernate.handoff() {
                    log("still shut past the deferral; memory off, hibernating")
                } else {
                    handedOverToHibernation = false
                    err("hibernation handover refused; staying in ordinary sleep")
                }
                return
            }
        }

        // Opened again: instant wake goes back on, so the next short close is short.
        if handedOverToHibernation, !lidShut {
            handedOverToHibernation = false
            DeferredHibernate.restoreFastWake()
            log("lid open; instant wake restored")
        }
    }

    /// Drop the inactive file cache on the way into a sealed sleep.
    ///
    /// Only when Sealed Sleep is on, because only then is memory about to be written to
    /// disk and read back: with ordinary sleep the pages stay powered where they are and
    /// purging them buys nothing but a cold cache. Caller must hold `lock`.
    private func releaseMemoryIfSealed() {
        let cfg = ConfigStore.load()
        // Nothing is being written to disk with fast wake on, so there is no image to shrink.
        guard cfg.sealedSleep, !cfg.sealedSleepFastWake else { return }
        if SealedSleepController.releaseCachedMemory() {
            log("released cached memory before hibernating")
        }
    }

    /// The cut itself. Applies whenever a limit is being enforced, not only when the
    /// "stop charging before sleep" option is on: the limit exists precisely to keep the
    /// battery off full, and the daemon is frozen through sleep, so leaving charging
    /// enabled hands macOS an unsupervised run to 100%. Charge still creeps up towards
    /// the limit during the maintenance wakes macOS takes anyway, since the tick runs
    /// then and re-enables while below the resume threshold.
    ///
    /// Caller must hold `lock`. Returns whether anything was cut.
    private func cutChargingForSleepLocked() -> Bool {
        guard chargeControlSupported else { return false }
        let cfg = ConfigStore.load()
        guard cfg.chargeLimitEnabled || cfg.disableChargingBeforeSleep else { return false }
        // Charging past the limit is only possible when it's allowed right now.
        guard ((try? charge.isChargingEnabled()) ?? true) else { return true }
        do {
            try charge.disableCharging()
            lastPauseReason = "sleep"
            log("charging cut for sleep (limit \(cfg.chargeLimit)%)")
            return true
        } catch {
            err("failed to cut charging for sleep: \(error)")
            return false
        }
    }

    /// Re-enforce as soon as the Mac is back, rather than waiting out the tick interval
    /// — the wake itself may be the moment the adapter starts pushing charge again.
    private func reevaluateAfterWake() {
        lock.lock()
        defer { lock.unlock() }
        settleUntil = Date().addingTimeInterval(wakeSettleDuration)
        resolveDeferredHibernate()
        tick()
    }

    // MARK: - Sealed Sleep

    /// Turn Sealed Sleep on or off, snapshotting what it displaces so the exit is exact.
    ///
    /// Caller must hold `lock`. Re-applying while already on is not a no-op — it rewrites
    /// the keys — but it deliberately does not re-snapshot, for the same reason
    /// `applying(_:)` doesn't: the snapshot has to describe the Mac *before* the feature,
    /// and overwriting it with the feature's own values would make the exit restore nothing.
    private func setSealedSleep(_ on: Bool, fastWake: Bool) -> ControlResponse {
        var cfg = ConfigStore.load()
        cfg.sealedSleepFastWake = fastWake

        if on {
            if cfg.sealedSleepRestore == nil { cfg.sealedSleepRestore = SealedSleepController.snapshot() }
            sealedSleepRefused = SealedSleepController.apply(fastWake: fastWake,
                                                             restoring: cfg.sealedSleepRestore)
        } else {
            // A missing snapshot means the feature was switched on by a build that didn't
            // keep one, or the config was hand-edited. Fall back to what macOS ships with:
            // leaving the Mac hibernating after the switch is off is the one outcome that
            // is definitely wrong.
            let saved = cfg.sealedSleepRestore
                ?? SealedSleepRestore(hibernateMode: SealedSleep.hibernateDefault,
                                      standby: true, powerNap: true,
                                      wakeForNetwork: false, networkInSleep: true,
                                      terminalSessionsKeepAwake: false)
            sealedSleepRefused = SealedSleepController.restore(saved)
            cfg.sealedSleepRestore = nil
        }
        cfg.sealedSleep = on
        invalidatePmsetCache()

        do { try ConfigStore.save(cfg) } catch {
            return status(ok: false, message: "sealed sleep applied but save failed: \(error)")
        }

        if sealedSleepRefused.isEmpty {
            log("sealed sleep \(on ? (fastWake ? "on (fast wake)" : "on (hibernating)") : "off")")
            return status(ok: true, message: on ? "sealed" : "unsealed")
        }
        let refused = sealedSleepRefused.joined(separator: ", ")
        err("sealed sleep: this Mac refused \(refused)")
        return status(ok: false, message: "this Mac refused \(refused)")
    }

    /// Re-assert Sealed Sleep at startup if the system has drifted from it.
    ///
    /// These are `pmset` settings, so they normally outlive everything and need no
    /// enforcement. "Normally" is the catch: a macOS update rewrites power management
    /// defaults, and a user who turned this on months ago would otherwise find it quietly
    /// stopped working, with the switch still showing on. Checked once, here, not per tick.
    private func reassertSealedSleepIfNeeded() {
        let cfg = ConfigStore.load()
        guard cfg.sealedSleep else { return }
        var state = SealedSleepController.observe(wifiOffOnLidClose: true,
                                                  bluetoothOffOnLidClose: true,
                                                  keepAwakeOnBattery: false)
        state.fastWake = cfg.sealedSleepFastWake
        guard !state.isSealed else { return }
        log("sealed sleep had drifted (\(state.leaks.map(\.rawValue).joined(separator: ", "))); re-applying")
        sealedSleepRefused = SealedSleepController.apply(fastWake: cfg.sealedSleepFastWake,
                                                         restoring: cfg.sealedSleepRestore)
        invalidatePmsetCache()
    }

    /// "Always Active": keep the Mac awake with the lid closed. `pmset disablesleep`
    /// is the only thing that prevents clamshell sleep, paired with a PreventSystemSleep
    /// assertion for idle sleep. It doesn't survive a reboot, so the first tick re-applies
    /// it (`lastDisableSleep` starts nil).
    private func updateKeepAwake(_ cfg: EWizConfig, _ snap: BatterySnapshot) {
        // `keepAwakeArmed` folds in the timetable and any auto-off timer, so a window
        // closing releases the hold on the next tick without the user touching anything.
        let armed = cfg.keepAwakeArmed()
        if armed != lastKeepAwakeArmed, !cfg.keepAwakeSchedules.filter(\.enabled).isEmpty {
            log("keep-awake schedule window \(armed ? "opened" : "closed")")
        }
        lastKeepAwakeArmed = armed

        // AC by default (onExternalPower survives force-discharge but releases on a real
        // unplug); keepAwakeOnBattery opts out, guarded by the thermal limit below.
        var want = armed && (cfg.keepAwakeOnBattery || snap.onExternalPower)

        // Task-gated: only hold while a matching task runs, so the Mac sleeps when work finishes.
        let taskGated = want && cfg.keepAwakeRequiresTask
        // `ps` is the expensive part of the tick, so only scan when task-gating needs it.
        let scan = taskGated
            ? ProcessScan.scan(names: cfg.keepAwakeProcesses)
            : ProcessScan.Reading()
        let taskBusy = taskGated
            && (scan.matchedName || (cfg.keepAwakeMinCpu > 0 && scan.topCPU >= cfg.keepAwakeMinCpu))
        if taskGated { want = taskBusy }
        // Thermal guardrail: release keep-awake once a closed Mac crosses the temp limit.
        if want, cfg.keepAwakeMaxTempC > 0, let t = snap.temperature, t >= cfg.keepAwakeMaxTempC {
            want = false
            log("keep-awake released: temperature \(String(format: "%.1f", t))°C ≥ guardrail \(cfg.keepAwakeMaxTempC)°C")
        }

        if lastDisableSleep != want {
            if PowerSettings.setDisableSleep(want) {
                lastDisableSleep = want
                log("keep-awake (disablesleep) \(want ? "enabled" : "disabled")")
            }
        }

        if want && keepAwakeAssertion == 0 {
            var id: IOPMAssertionID = 0
            let ok = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "eWiz: keep awake (Always Active)" as CFString,
                &id)
            if ok == kIOReturnSuccess { keepAwakeAssertion = id }
        } else if !want && keepAwakeAssertion != 0 {
            IOPMAssertionRelease(keepAwakeAssertion)
            keepAwakeAssertion = 0
        }

        // Docked clamshell: lid shut, monitor attached, hold awake. `disablesleep` and the
        // system assertion above keep the Mac running, but neither touches the *display*
        // timer — so after `displaysleep` minutes of no input the one screen left goes
        // dark, and with the lid already shut there is nothing obvious to wake it with.
        // Every report of this ends the same way: the user opens the laptop again.
        //
        // Only in that exact shape. Lid open, or no external display, and the idle display
        // timer is left alone: a screen held lit over an empty desk is the most expensive
        // thing this app can do to a battery.
        let docked = want && SystemPower.isClamshellClosed()
            && SystemPower.displays() == .externalAttached
        if docked && keepAwakeDisplayAssertion == 0 {
            var id: IOPMAssertionID = 0
            let ok = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "eWiz: lid closed with an external display" as CFString,
                &id)
            if ok == kIOReturnSuccess {
                keepAwakeDisplayAssertion = id
                log("keep-awake: holding the external display on while the lid is shut")
            }
        } else if !docked && keepAwakeDisplayAssertion != 0 {
            IOPMAssertionRelease(keepAwakeDisplayAssertion)
            keepAwakeDisplayAssertion = 0
            log("keep-awake: external display released to the idle timer")
        }

        // Lid shut + awake: force the display off (keyboard backlight follows) once per
        // close; nothing can wake it. Reset when the lid opens or keep-awake stops holding.
        let lidClosed = want && SystemPower.isClamshellClosed()
        if lidClosed {
            if !displayForcedOffWhileClosed {
                // Only when the closed lid means nothing is being looked at. Docked, the
                // lid is shut *because* there's a monitor on the desk, and
                // `pmset displaysleepnow` blanks every display — so the one it turned off
                // was the one being worked on, and it stayed off. `unknown` counts as a
                // monitor: a backlight left burning costs some power, a dark desk costs
                // the session.
                switch SystemPower.displays() {
                case .builtInOnly:
                    PowerSettings.displaySleepNow()
                    log("keep-awake: lid closed, display + keyboard backlight off")
                case .externalAttached, .unknown:
                    log("keep-awake: lid closed with an external display, leaving it lit")
                }
                displayForcedOffWhileClosed = true
            }
        } else {
            displayForcedOffWhileClosed = false
        }

        // Auto-sleep once the monitored task finishes. `want`/the hold above are
        // already released when the task isn't busy, so `pmset sleepnow` isn't
        // blocked by our own disablesleep. Debounced so a brief gap between a
        // build's sub-processes doesn't sleep mid-job, and only after we've seen
        // the task actually run this session.
        if taskGated {
            if taskBusy {
                keepAwakeSawTask = true
                keepAwakeTaskIdleTicks = 0
            } else if keepAwakeSawTask {
                keepAwakeTaskIdleTicks += 1
                if cfg.sleepWhenTaskDone && keepAwakeTaskIdleTicks >= sleepAfterTaskIdleTicks {
                    log("keep-awake task finished, sleeping now")
                    keepAwakeSawTask = false
                    keepAwakeTaskIdleTicks = 0
                    PowerSettings.sleepNow()
                }
            }
        } else {
            keepAwakeSawTask = false
            keepAwakeTaskIdleTicks = 0
        }
    }

    /// Hold an idle-sleep assertion while prevent-idle-sleep is on and the Mac is on wall
    /// power (never keep draining on battery).
    ///
    /// It used to require `chargeLimitEnabled` as well, on the reasoning that the assertion
    /// existed so the limit could keep being enforced. That quietly broke the one mode that
    /// wants it most: Extreme Performance asks for `preventIdleSleep` *and* turns the charge
    /// limit off, so the two conditions could never both hold and the Mac idled out from
    /// under a long render. The switch says "keeps the Mac awake on power" — so it does.
    private func updateIdleSleepAssertion(_ cfg: EWizConfig, _ snap: BatterySnapshot) {
        // onExternalPower (not isPluggedIn) so a force-discharge doesn't drop the
        // assertion and let the daemon freeze mid-drain.
        let want = cfg.preventIdleSleep && snap.onExternalPower
        if want && idleSleepAssertion == 0 {
            var id: IOPMAssertionID = 0
            let ok = IOPMAssertionCreateWithName(
                kIOPMAssertPreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "eWiz: enforcing charge limit" as CFString,
                &id)
            if ok == kIOReturnSuccess { idleSleepAssertion = id; log("idle-sleep assertion held") }
        } else if !want && idleSleepAssertion != 0 {
            IOPMAssertionRelease(idleSleepAssertion)
            idleSleepAssertion = 0
            log("idle-sleep assertion released")
        }
    }

    /// Force-discharge down to the limit when plugged in above it; otherwise keep the adapter on.
    private func manageDischarge(_ cfg: EWizConfig, _ snap: BatterySnapshot,
                                 scheduleDischarge: Bool) {
        guard charge.isAdapterControlSupported else { return }

        // Down to the level this Mac actually stops at. Under macOS's limit a 70% setting
        // stops at 80%, and draining to 70 would only have macOS charge it straight back.
        let stopsAt = nativeLimit.flatMap { $0.step(for: cfg.chargeLimit) } ?? cfg.chargeLimit
        let limitDischarge = cfg.dischargeEnabled
            && cfg.chargeLimitEnabled
            && !cfg.calibrateToFull   // calibration is charging up, don't fight it
            && snap.percentage > stopsAt

        // The adapter hold. On a Mac that exposes no charge-inhibit key there is nothing
        // to inhibit charging with, so "don't charge" and the limit had no way to bite at
        // all — the switch read "Held" while the battery climbed to full. The adapter is
        // the one lever this hardware does give us, so a hold is built out of it: sit on
        // the battery while the level is at or above the mark, take the adapter back for a
        // short top-up once it has fallen `adapterHoldBand` points below it.
        //
        // It is not the same thing as inhibiting the charge — the Mac runs off the battery
        // through the held phase, so this trades a shallow cycle every so often for not
        // sitting at 100%. That is the better of the two for the cell, and it is the only
        // trade available here.
        //
        // Only where macOS has no limit of its own to offer. Where it does, that limit
        // stops the charge and keeps the Mac on wall power, and this drain-and-top-up
        // cycle is exactly what someone switching on "don't charge" is trying to avoid.
        let adapterHold = !chargeControlSupported && nativeLimit == nil && !cfg.calibrateToFull
            && adapterHoldWanted(cfg, snap)
        // Gate on onExternalPower, NOT isPluggedIn: cutting the adapter makes macOS report
        // "Battery Power", so isPluggedIn would flip false next tick and we'd restore the
        // adapter — oscillating instead of draining. onExternalPower stays true while the cable is in.
        let shouldDischarge = snap.onExternalPower
            && (limitDischarge || scheduleDischarge || adapterHold)

        let adapterOn = (try? charge.isAdapterEnabled()) ?? true
        var cut = !adapterOn
        if shouldDischarge {
            if adapterOn {
                if (try? charge.disableAdapter()) != nil { cut = true }
                log(adapterHold && !limitDischarge && !scheduleDischarge
                    ? "hold: on the battery at \(snap.percentage)%, adapter back at \((holdAnchor ?? cfg.chargeLimit) - adapterHoldBand)%"
                    : "discharging to limit")
            }
        } else if !adapterOn {
            if (try? charge.enableAdapter()) != nil { cut = false }
            log("adapter restored")
        }
        if cut != adapterCut {
            adapterCut = cut
            bookLedFollowUps()
        }
    }

    /// The level "don't charge" was thrown at, on a Mac with no charge-inhibit key.
    ///
    /// Anchored the first time it's seen on the charger, and kept across an unplug: the
    /// switch means "leave it where it was when I asked", not wherever it has drifted to
    /// since the cable was last pulled. Both levers this hardware has read it.
    ///
    /// Caller holds `lock`.
    private func updateHoldAnchor(_ cfg: EWizConfig, _ snap: BatterySnapshot) {
        guard !chargeControlSupported else { return }
        // A pause is a hold with an end time. With no charge key it has no lever of its own,
        // so it used to do nothing at all: "Charging paused" in the panel while the battery
        // climbed. It parks the same way the hold does.
        if cfg.holdCharge || cfg.pauseUntil != nil {
            guard holdAnchor == nil, snap.onExternalPower else { return }
            holdAnchor = snap.percentage
            if let native = nativeLimit {
                let step = NativeChargeLimit.target(holdAnchor: snap.percentage, limit: nil,
                                                    in: native.steps) ?? 100
                log(step > snap.percentage
                    ? "hold: macOS can't hold \(snap.percentage)%; charging to \(step)% and holding there"
                    : "hold: parking the battery at \(snap.percentage)% (macOS charge limit \(step)%)")
            } else {
                log("hold: parking the battery at \(snap.percentage)% (no charge-inhibit key; using the adapter)")
            }
        } else if holdAnchor != nil {
            holdAnchor = nil
            log("hold: released")
        }
    }

    /// The step macOS should hold for eWiz this tick, nil for none.
    ///
    /// The hold wins over everything, as it does in the tick's own decision; the limit
    /// gives way to a top-up, a charge window or calibration, which all mean "charge past
    /// it this once". Below the lowest step this is the lowest step, and the app says so.
    ///
    /// Caller holds `lock`.
    private func nativeLimitWanted(_ cfg: EWizConfig, bypass: Bool) -> Int? {
        guard let native = nativeLimit else { return nil }
        // A bypass lifts the limit; it never lifts the hold, which wins over the limit anyway.
        return NativeChargeLimit.target(holdAnchor: cfg.holdCharge || cfg.pauseUntil != nil ? holdAnchor : nil,
                                        limit: cfg.chargeLimitEnabled && !bypass ? cfg.chargeLimit : nil,
                                        in: native.steps)
    }

    /// Point macOS's limit at `want`, and only ever take back a limit eWiz set.
    ///
    /// Asked again once a minute so a change made in System Settings is noticed, and
    /// otherwise only when the target moves: each ask is a round trip to PowerUIAgent.
    /// A limit that no longer matches the one we set is the user's, and is left alone.
    ///
    /// Caller holds `lock`.
    private func applyNativeLimit(_ want: Int?, now: Date) {
        guard let native = nativeLimit else { return }
        let due = nativeCheckedAt.map { now.timeIntervalSince($0) >= 60 } ?? true
        guard want != nativeApplied || (due && (want != nil || nativeApplied != nil)) else { return }
        nativeCheckedAt = now
        let current = native.current()

        if let want {
            if let current, current.enabled, current.limit == want {
                if nativeApplied != want { nativeApplied = want; NativeChargeLimitOwnership.save(want) }
                return
            }
            if native.set(want) {
                nativeApplied = want
                NativeChargeLimitOwnership.save(want)
                log("macOS charge limit set to \(want)%")
            } else {
                err("macOS refused a charge limit of \(want)%")
            }
        } else if let owned = nativeApplied {
            if current?.limit == owned {
                guard native.disable() else { err("could not release the macOS charge limit"); return }
                log("macOS charge limit released")
            }
            nativeApplied = nil
            NativeChargeLimitOwnership.save(nil)
        }
    }

    /// Whether the adapter hold wants the adapter cut this tick.
    ///
    /// The mark is the charge limit when one is set, and otherwise the level the "don't
    /// charge" switch was thrown at — that switch means "leave it where it is", and where
    /// it is can only be read at the moment it's asked for. Hysteresis is tracked in
    /// `adapterHolding` rather than inferred from the level, so a Mac sitting exactly on
    /// the mark doesn't flip power source on every reading.
    ///
    /// The hysteresis belongs to one mark. Carried over when the mark moved, it kept the
    /// adapter cut after "don't charge" was switched off: the hold had set it at 79%, the
    /// limit above was 80, 79 is neither at the limit nor two under it, so nothing cleared
    /// it and the Mac sat on its battery instead of charging to the limit it was asked for.
    ///
    /// Caller holds `lock`.
    private func adapterHoldWanted(_ cfg: EWizConfig, _ snap: BatterySnapshot) -> Bool {
        let mark = cfg.holdCharge ? holdAnchor : (cfg.chargeLimitEnabled ? cfg.chargeLimit : nil)
        guard let target = mark else { adapterHolding = false; adapterHoldMark = nil; return false }
        if target != adapterHoldMark {
            adapterHoldMark = target
            adapterHolding = snap.percentage >= target
        }

        if snap.percentage >= target {
            adapterHolding = true
        } else if snap.percentage <= target - adapterHoldBand {
            adapterHolding = false
        }
        return adapterHolding
    }

    /// Drive the MagSafe LED per mode.
    private func updateMagSafeLED(_ cfg: EWizConfig, _ snap: BatterySnapshot,
                                  takingCharge: Bool, settling: Bool) {
        guard charge.isMagSafeSupported else { return }

        // Tracked before the mode switch, not inside the `.status` branch that uses it.
        // Parked there, a hold thrown while the LED was off or system-managed never updated
        // it — so the next switch to `.status` compared today's hold against a stale `false`
        // and fired the three-blink "hold just engaged" announcement for a hold that had
        // engaged hours earlier.
        let holdChanged = cfg.holdCharge != lastHoldForLed
        lastHoldForLed = cfg.holdCharge

        let target: MagSafeLED
        switch cfg.magSafeLedMode {
        case .system:
            // hand control back to macOS once, then leave it alone
            if let last = lastLed, last != .system {
                try? charge.setMagSafeLED(.system)
                lastLed = .system
            }
            return
        case .off:
            target = .off
        case .status:
            target = MagSafeLED.status(settling: settling, onExternalPower: snap.onExternalPower,
                                       adapterCut: adapterCut, charging: takingCharge)
        }

        // Announce the moment hold engages: three quick green/off blinks, then settle on
        // the steady colour. Green because that's what a hold looks like; blinking amber
        // announced "don't charge" in the colour of charging. One-off and only on the
        // transition — a light that blinks forever is a fault indicator, not a status.
        if cfg.magSafeLedMode == .status, holdChanged {
            if cfg.holdCharge, snap.onExternalPower {
                for _ in 0..<3 {
                    try? charge.setMagSafeLED(.off)
                    usleep(120_000)
                    try? charge.setMagSafeLED(.green)
                    usleep(120_000)
                }
            }
        }

        // Written every tick, not only when the readback differs. macOS repaints the light
        // on a power change without touching ACLC, so the key still reads what we wrote
        // while the connector shows something else. It did exactly that through a hold:
        // ACLC read green, the light was amber, and the drift check never fired. One byte
        // every tick is the only check that can't be fooled by the readback. `.system` is
        // the exception: it's macOS's light then, and rewriting it would only reset it.
        if target != .system || lastLed != .system {
            try? charge.setMagSafeLED(target)
        }
        lastLed = target
    }

    /// Run the tick again a few seconds after the power source changes under it.
    ///
    /// Two things trail a change: macOS repaints the MagSafe light, and IOKit's charging
    /// flag catches up with what the charger is doing. A follow-up tick rewrites the light
    /// over the repaint and reads the flag once it's true, instead of leaving the wrong
    /// colour up until the next ordinary tick. Caller holds `lock`.
    private func bookLedFollowUps() {
        guard charge.isMagSafeSupported else { return }
        for delay in [2.0, 6.0] {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                defer { self.lock.unlock() }
                self.tick()
            }
        }
    }

    private func recordHistoryIfDue(_ snap: BatterySnapshot, now: Date) {
        if let last = lastSampleAt, now.timeIntervalSince(last) < sampleInterval { return }
        lastSampleAt = now

        HistoryStore.append(BatterySample(
            t: Date(), pct: snap.percentage,
            charging: snap.isCharging, temp: snap.temperature))
        HistoryStore.trim()
    }

    private func ensure(enabled desired: Bool, current: Bool) {
        guard chargeControlSupported else { return }
        if current == desired { return }
        do {
            if desired { try charge.enableCharging() } else { try charge.disableCharging() }
            log("charging \(desired ? "enabled" : "disabled")")
            bookLedFollowUps()
        } catch {
            log("error setting charging=\(desired): \(error)")
        }
    }

    // MARK: - Signals & logging

    private func installSignalHandlers() {
        // DispatchSource, not a C signal handler: cleanup forks pmset, writes the SMC
        // and allocates — none async-signal-safe. The source's handler runs as an
        // ordinary block on signalQueue and takes `lock` to serialize with the tick loop.
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)   // ignore default disposition; the source owns it
            let src = DispatchSource.makeSignalSource(signal: sig, queue: signalQueue)
            src.setEventHandler { self.performCleanupAndExit() }
            src.resume()
            signalSources.append(src)
        }
    }

    /// Restore a safe state and exit: preserve the charge limit across shutdown,
    /// restore the adapter, hand the LED to macOS, clear disablesleep. Serialized
    /// with the tick loop via `lock`.
    ///
    /// launchd sends SIGTERM on every shutdown/restart, so this runs then. The SMC
    /// charge-inhibit key persists while the Mac is powered off but plugged in (the
    /// same property `prepareForSleep` relies on), so if we cleared it here the
    /// battery would charge straight past the limit — to full — while the Mac is
    /// off. So when limiting is on we leave the inhibit *set*; only when limiting is
    /// off do we re-enable charging, to never leave a Mac unable to charge.
    /// (Uninstall re-enables explicitly, after unloading this daemon.)
    private func performCleanupAndExit() -> Never {
        lock.lock()   // hold through exit; serialize SMC access with tick()
        PowerSettings.setDisableSleep(false)
        if chargeControlSupported {
            if ConfigStore.load().chargeLimitEnabled {
                try? charge.disableCharging()
            } else {
                try? charge.enableCharging()
            }
        }
        if charge.isAdapterControlSupported { try? charge.enableAdapter() }
        if charge.isMagSafeSupported { try? charge.setMagSafeLED(.system) }
        exit(0)
    }

    private func log(_ m: String) { HelperLog.info(m) }
    private func err(_ m: String) { HelperLog.error(m) }
}
