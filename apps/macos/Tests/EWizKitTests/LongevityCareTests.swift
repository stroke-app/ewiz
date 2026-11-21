import Testing
import Foundation
@testable import EWizKit

@Suite("Long-term care")
struct LongevityCareTests {

    /// Somebody plugged in at full with the usual 80% ceiling — the state this exists for.
    private var atFull: EWizConfig {
        EWizConfig(chargeLimitEnabled: true, chargeLimit: 80, holdCharge: true)
    }

    @Test func turningItOnParksTheBatteryRatherThanFreezingIt() {
        let cfg = atFull.applyingLongevityCare(true)
        #expect(cfg.chargeLimitEnabled)
        #expect(cfg.chargeLimit == LongevityCare.targetPercent)
        // Discharge is the half that distinguishes this from "don't charge": without it a
        // Mac plugged in at 100% would sit at 100% forever and the switch would do nothing.
        #expect(cfg.dischargeEnabled)
        // `holdCharge` pins the level exactly where it is, which is the 100% we're escaping.
        #expect(!cfg.holdCharge)
        #expect(cfg.heatAwareEnabled)
    }

    @Test func aPauseWouldOutrankItSoItIsCleared() {
        var cfg = atFull
        cfg.pauseUntil = Date.distantFuture
        #expect(cfg.applyingLongevityCare(true).pauseUntil == nil)
    }

    @Test func aRunningCalibrationIsCancelled() {
        // Calibration exists to charge to 100%. Leaving it armed would have the daemon
        // charging up and discharging down at the same time.
        var cfg = atFull
        cfg.calibrateToFull = true
        #expect(!cfg.applyingLongevityCare(true).calibrateToFull)
    }

    @Test func itIsRecognisedOnceApplied() {
        #expect(LongevityCare.isActive(atFull.applyingLongevityCare(true)))
        #expect(!LongevityCare.isActive(atFull))
    }

    @Test func movingTheLimitTurnsItOff() {
        // The state is derived from the three settings, never stored. Drag the limit
        // slider and the switch has to stop claiming to be on — a stored flag would sit
        // there reading "parked at 60%" over a Mac charging to 90%.
        var cfg = atFull.applyingLongevityCare(true)
        cfg.chargeLimit = 90
        #expect(!LongevityCare.isActive(cfg))
    }

    @Test func holdingTheChargeTurnsItOff() {
        var cfg = atFull.applyingLongevityCare(true)
        cfg.holdCharge = true
        #expect(!LongevityCare.isActive(cfg))
    }

    @Test func turningItOffGivesTheBatteryBackButKeepsALimit() {
        let round = atFull.applyingLongevityCare(true).applyingLongevityCare(false)
        #expect(!round.dischargeEnabled)
        #expect(round.chargeLimit == 80)
        // Limiting stays *on*. Leaving long-term care means wanting the capacity back, not
        // wanting the Mac to start charging to 100% unsupervised.
        #expect(round.chargeLimitEnabled)
        #expect(!LongevityCare.isActive(round))
    }

    @Test func theTargetSitsInTheFlatPartOfTheAgeingCurve() {
        // Not 100 (worst case for calendar ageing) and not so low the Mac is useless
        // unplugged. The number is a judgement call; that it stays in this band is not.
        #expect(LongevityCare.targetPercent >= 50)
        #expect(LongevityCare.targetPercent <= 70)
    }

    @Test func applyingItTwiceChangesNothingFurther() {
        let once = atFull.applyingLongevityCare(true)
        #expect(once.applyingLongevityCare(true) == once)
    }
}
