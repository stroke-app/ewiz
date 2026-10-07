import Testing
@testable import EWizKit

/// The one reading every surface draws from. Each case here is a screen the app can
/// show; the assertions are what the glyph, header, hint and tooltip must agree on.
@Suite("Charge display state")
struct ChargeDisplayTests {
    /// A Mac that limits through macOS's own charge limit (no SMC charge key): the hold
    /// rounds up to a step, and the helper reports "limit"/"hold" whenever current isn't
    /// flowing, at any level.
    let steps = [80, 85, 90, 95, 100]

    @Test("On battery")
    func onBattery() {
        let d = ChargeDisplay(.init(percentage: 63, isCharging: false, isPluggedIn: false,
                                    limitEnabled: true, effectiveLimit: 80))
        #expect(d.state == .onBattery)
        #expect(d.mark == .none)
        #expect(!d.isComplete)
        #expect(d.headerNote == nil)
        #expect(d.statusLine == "On battery")
        #expect(d.tooltip == "On battery · 63%")
    }

    @Test("Charging below the limit")
    func chargingBelowLimit() {
        let d = ChargeDisplay(.init(percentage: 49, isCharging: true, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80))
        #expect(d.state == .charging(to: 80))
        #expect(d.mark == .bolt)
        #expect(!d.isComplete)
        #expect(d.headerNote == "Charging to 80%")
        #expect(d.hint == nil)
        #expect(d.statusLine == "Charging")
    }

    /// The reported bug. "Don't charge" switched on at 49% on a macOS-limit Mac: the
    /// helper parks on the 80% step, so the battery charges to 80 first. The header said
    /// "Charging to 80%" while the glyph wore the finished-charge check.
    @Test("Don't charge at 49%, plugged in, charges to the step and is not complete")
    func holdBelowStepCharges() {
        let d = ChargeDisplay(.init(percentage: 49, isCharging: true, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                    usesNativeLimit: true, holdCharge: true))
        #expect(d.state == .charging(to: 80))
        #expect(d.mark == .bolt)
        #expect(!d.isComplete)
        #expect(d.headerNote == "Charging to 80%")
        #expect(d.holdCaption == "Charges to 80%, then holds there")
    }

    /// Same Mac, the seconds after plugging in before current flows: the helper has
    /// applied the step and already says "hold" (or "limit") about a battery at 49%.
    @Test("A hold reported under its step before current flows is not a hold, let alone a finish")
    func holdReportedBelowStep() {
        for reason in ["hold", "limit"] {
            let d = ChargeDisplay(.init(percentage: 49, isCharging: false, isPluggedIn: true,
                                        limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                        usesNativeLimit: true, holdCharge: reason == "hold",
                                        pauseReason: reason))
            #expect(d.state == .pluggedIn, "reason \(reason)")
            #expect(!d.isComplete)
            #expect(d.headerNote == nil)
            #expect(d.hint == nil)
        }
    }

    @Test("Don't charge holding at its step")
    func holdAtStep() {
        let d = ChargeDisplay(.init(percentage: 80, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                    usesNativeLimit: true, holdCharge: true, pauseReason: "hold"))
        #expect(d.state == .holding(at: 80))
        #expect(d.mark == .pause)
        #expect(d.holdsLevel)
        #expect(d.isComplete)
        #expect(d.headerNote == "Holding at 80%")
        #expect(d.hint == "Holding the level where it is")
        #expect(d.holdCaption == "Holding at 80% on wall power")
        #expect(d.tooltip == "Holding at 80%")
    }

    /// With a real charge key the hold parks exactly where it was thrown.
    @Test("Don't charge with a charge key holds the level where it is")
    func holdWithChargeKey() {
        let d = ChargeDisplay(.init(percentage: 49, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80,
                                    holdCharge: true, pauseReason: "hold"))
        #expect(d.state == .holding(at: 49))
        #expect(d.headerNote == "Holding at 49%")
        #expect(d.holdCaption == "Holding the level")
        #expect(d.tooltip == "Holding the level where it is")
    }

    @Test("Held at the limit")
    func heldAtLimit() {
        let d = ChargeDisplay(.init(percentage: 80, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                    usesNativeLimit: true, pauseReason: "limit"))
        #expect(d.state == .heldAtLimit(80))
        #expect(d.mark == .pause)
        #expect(d.holdsLevel)
        #expect(d.isComplete)
        #expect(d.headerNote == "Holding at 80%")
        #expect(d.hint == "Charging paused to hold limit")
        #expect(d.statusLine == "Plugged in, not charging")
        #expect(d.tooltip == "Holding at 80% limit")
    }

    /// The level is the fact; the helper's status is polled and can be up to half a
    /// minute behind it.
    @Test("At the limit with charging stopped is held, before the helper says so")
    func heldAtLimitBeforeReason() {
        let d = ChargeDisplay(.init(percentage: 80, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80))
        #expect(d.state == .heldAtLimit(80))
        #expect(d.isComplete)
    }

    /// And the other way round: a stale "limit" over a battery visibly charging is charging.
    @Test("Current flowing outranks a stale hold reason")
    func chargingOutranksStaleReason() {
        let d = ChargeDisplay(.init(percentage: 52, isCharging: true, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                    usesNativeLimit: true, pauseReason: "limit"))
        #expect(d.state == .charging(to: 80))
        #expect(!d.isComplete)
        #expect(d.hint == nil)
    }

    /// A charge-key Mac coasting down its recharge band: the limit is still at work, but
    /// 77% is not "reached 80%".
    @Test("Coasting under the limit is held, not complete")
    func coastingUnderLimit() {
        let d = ChargeDisplay(.init(percentage: 77, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, pauseReason: "limit"))
        #expect(d.state == .heldAtLimit(80))
        #expect(!d.isComplete)
        #expect(d.headerNote == "Paused under the 80% limit")
    }

    @Test("Above the limit, draining to it")
    func draining() {
        let d = ChargeDisplay(.init(percentage: 86, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                    usesNativeLimit: true, pauseReason: "limit", discharging: true))
        #expect(d.state == .draining(to: 80))
        #expect(d.mark == .pause)
        #expect(!d.isComplete)
        #expect(d.headerNote == "Draining to 80%")
        #expect(d.hint == nil)
    }

    /// Adapter cut on a charge-key Mac: macOS says battery power with the cable in.
    @Test("An adapter cut to drain is not an unplug")
    func drainingWithAdapterCut() {
        let d = ChargeDisplay(.init(percentage: 86, isCharging: false, isPluggedIn: false,
                                    limitEnabled: true, effectiveLimit: 80, discharging: true))
        #expect(d.state == .draining(to: 80))
        #expect(d.statusLine == "On battery")
    }

    @Test("Above the limit and sitting there")
    func aboveLimitHeld() {
        let d = ChargeDisplay(.init(percentage: 86, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, pauseReason: "limit"))
        #expect(d.state == .heldAtLimit(80))
        #expect(d.headerNote == "Above the 80% limit")
    }

    @Test("Charging past the limit")
    func chargingPastLimit() {
        let d = ChargeDisplay(.init(percentage: 86, isCharging: true, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80))
        #expect(d.state == .charging(to: 80))
        #expect(d.headerNote == "Above the 80% limit")
    }

    @Test("Full")
    func full() {
        let d = ChargeDisplay(.init(percentage: 100, isCharging: false, isPluggedIn: true,
                                    isFullyCharged: true))
        #expect(d.state == .full)
        #expect(d.mark == .none)
        #expect(d.isComplete)
        #expect(d.headerNote == nil)
        #expect(d.statusLine == "Fully charged")
    }

    @Test("Full at 100% with a limit at 100 is full, not held")
    func fullWithLimitAtTop() {
        let d = ChargeDisplay(.init(percentage: 100, isCharging: false, isPluggedIn: true,
                                    isFullyCharged: true, limitEnabled: true, effectiveLimit: 100))
        #expect(d.state == .full)
        #expect(d.isComplete)
        #expect(d.mark == .none)
        #expect(d.headerNote == nil)
    }

    @Test("Paused by the user")
    func paused() {
        let d = ChargeDisplay(.init(percentage: 60, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, pauseReason: "paused",
                                    isPaused: true))
        #expect(d.state == .paused(.user))
        #expect(d.mark == .pause)
        #expect(d.holdsLevel)
        #expect(!d.isComplete)
        #expect(d.headerNote == "Charging paused")
        #expect(d.hint == nil)   // the pause has its own row with a Resume button
        #expect(d.tooltip == "Charging paused")
    }

    @Test("Paused for heat")
    func heat() {
        let d = ChargeDisplay(.init(percentage: 60, isCharging: false, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, pauseReason: "heat"))
        #expect(d.state == .paused(.heat))
        #expect(d.hint == "Charging paused, battery is warm")
        #expect(d.tooltip == "Charging paused, battery warm")
    }

    @Test("Settling after wake and a schedule hold")
    func settlingAndSchedule() {
        let settling = ChargeDisplay(.init(percentage: 60, isCharging: false, isPluggedIn: true,
                                           limitEnabled: true, effectiveLimit: 80, pauseReason: "settling"))
        #expect(settling.state == .paused(.settling))
        #expect(settling.hint == "Charging resumes shortly after wake")
        let schedule = ChargeDisplay(.init(percentage: 60, isCharging: false, isPluggedIn: true,
                                           pauseReason: "schedule"))
        #expect(schedule.state == .paused(.schedule))
        #expect(schedule.hint == "A schedule is holding charging")
    }

    @Test("Calibrating to 100% once")
    func calibrating() {
        let charging = ChargeDisplay(.init(percentage: 85, isCharging: true, isPluggedIn: true,
                                           limitEnabled: true, effectiveLimit: 80, calibrating: true))
        #expect(charging.state == .calibrating(charging: true))
        #expect(charging.mark == .bolt)
        #expect(!charging.isComplete)
        #expect(charging.headerNote == "Charging to 100% once")
        #expect(charging.statusLine == "Charging")

        let gap = ChargeDisplay(.init(percentage: 85, isCharging: false, isPluggedIn: true,
                                      limitEnabled: true, effectiveLimit: 80, calibrating: true))
        #expect(gap.state == .calibrating(charging: false))
        #expect(gap.mark == .pause)
    }

    @Test("Charging gently is charging, with the hint")
    func slow() {
        let d = ChargeDisplay(.init(percentage: 70, isCharging: true, isPluggedIn: true,
                                    limitEnabled: true, effectiveLimit: 80, pauseReason: "slow",
                                    chargePower: 40))
        #expect(d.state == .charging(to: 80))
        #expect(d.hint == "Charging gently, at 40% power")
    }

    @Test("Unplugged while held")
    func unpluggedWhileHeld() {
        let d = ChargeDisplay(.init(percentage: 80, isCharging: false, isPluggedIn: false,
                                    limitEnabled: true, effectiveLimit: 80, nativeLimitApplied: 80,
                                    usesNativeLimit: true, holdCharge: true, pauseReason: "hold"))
        #expect(d.state == .onBattery)
        #expect(d.mark == .none)
        #expect(!d.isComplete)
        #expect(d.holdCaption == "Holding at 80% on wall power")   // what the switch will do
    }

    @Test("Plugged in with no limit and current not yet flowing")
    func pluggedIn() {
        let d = ChargeDisplay(.init(percentage: 60, isCharging: false, isPluggedIn: true))
        #expect(d.state == .pluggedIn)
        #expect(d.mark == .pause)
        #expect(!d.holdsLevel)
        #expect(d.statusLine == "Plugged in, not charging")
        #expect(d.tooltip == "Plugged in · 60%")
    }
}

/// When the check mark may flash: only a charge that was going somewhere and got there.
@Suite("Charge completion")
struct ChargeCompletionTests {
    func display(_ pct: Int, charging: Bool, plugged: Bool = true, hold: Bool = false,
                 reason: String? = nil, full: Bool = false, limit: Bool = true) -> ChargeDisplay {
        ChargeDisplay(.init(percentage: pct, isCharging: charging, isPluggedIn: plugged,
                            isFullyCharged: full, limitEnabled: limit, effectiveLimit: 80,
                            nativeLimitApplied: limit || hold ? 80 : nil, usesNativeLimit: true,
                            holdCharge: hold, pauseReason: reason))
    }

    @Test("Charging to the limit and stopping there finishes")
    func reachesLimit() {
        let now = display(80, charging: false, reason: "limit")
        #expect(now.completes(from: .charging(to: 80)))
    }

    @Test("Charging to the hold's step and stopping there finishes")
    func reachesHoldStep() {
        let now = display(80, charging: false, hold: true, reason: "hold")
        #expect(now.completes(from: .charging(to: 80)))
    }

    @Test("Charging to full finishes, from a plain charge or a calibration")
    func reachesFull() {
        let now = display(100, charging: false, full: true, limit: false)
        #expect(now.completes(from: .charging(to: 100)))
        #expect(now.completes(from: .calibrating(charging: true)))
    }

    /// Switching "Don't charge" on mid-charge stops the charge where it is. Nothing was
    /// reached.
    @Test("A hold thrown mid-charge is not a finish")
    func holdMidCharge() {
        let smcHold = ChargeDisplay(.init(percentage: 49, isCharging: false, isPluggedIn: true,
                                          limitEnabled: true, effectiveLimit: 80,
                                          holdCharge: true, pauseReason: "hold"))
        #expect(smcHold.state == .holding(at: 49))
        #expect(!smcHold.completes(from: .charging(to: 80)))
        #expect(!smcHold.completes(from: .charging(to: 100)))
    }

    @Test("A hold reported at 49% while the charger negotiates is not a finish")
    func transientHold() {
        let now = display(49, charging: false, hold: true, reason: "hold")
        #expect(!now.completes(from: .charging(to: 80)))
        #expect(!now.completes(from: .charging(to: 100)))
    }

    @Test("Waking already held is not a finish")
    func wokeHeld() {
        let now = display(80, charging: false, reason: "limit")
        #expect(!now.completes(from: .onBattery))
        #expect(!now.completes(from: .pluggedIn))
        #expect(!now.completes(from: .heldAtLimit(80)))
    }

    @Test("Stopping short of where it was going is not a finish")
    func stoppedShort() {
        let now = display(80, charging: false, reason: "limit")
        #expect(!now.completes(from: .charging(to: 100)))
    }

    @Test("Leaving a completion cancels it: unplugged, level dropped, hold released")
    func leavesCompletion() {
        #expect(!display(80, charging: false, plugged: false).isComplete)
        #expect(!display(78, charging: false, reason: "limit").isComplete)
        #expect(!display(80, charging: true).isComplete)
        let released = ChargeDisplay(.init(percentage: 60, isCharging: false, isPluggedIn: true))
        #expect(!released.isComplete)
    }

    @Test("Same kind ignores the target, so a moving slider doesn't read as a new state")
    func sameKind() {
        #expect(ChargeDisplayState.charging(to: 80).sameKind(as: .charging(to: 85)))
        #expect(ChargeDisplayState.holding(at: 80).sameKind(as: .holding(at: 85)))
        #expect(!ChargeDisplayState.holding(at: 80).sameKind(as: .heldAtLimit(80)))
        #expect(!ChargeDisplayState.charging(to: 80).sameKind(as: .pluggedIn))
    }
}
