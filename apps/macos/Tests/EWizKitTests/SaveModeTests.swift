import Testing
import Foundation
@testable import EWizKit

/// Extreme Performance is the one mode that spends battery health instead of saving it,
/// which makes it the one mode where a wrong default is actively harmful. These pin the
/// parts that are easy to break by accident and hard to notice afterwards.
@Suite struct SaveModeTests {

    @Test func extremeIsTheOnlyPerformanceMode() {
        #expect(SaveMode.extremePerformance.isPerformance)
        for mode in SaveMode.allCases where mode != .extremePerformance {
            #expect(!mode.isPerformance, "\(mode.rawValue) claims to be a performance mode")
        }
    }

    @Test func casesRunFromSpendingToSaving() {
        // `allCases` order is the segmented picker's left-to-right order, so it isn't
        // cosmetic: reversing it would show a saving ramp with the fastest mode filed at
        // the "most economical" end.
        #expect(SaveMode.allCases == [.extremePerformance, .off, .normal, .superSaver])
    }

    @Test func extremeRemovesTheChargeCeiling() {
        // The pack has to be free to fill: under peak load a MacBook draws more than the
        // adapter supplies and takes the rest from the battery, so a limit here is a
        // power cap on the SoC.
        let p = SaveMode.extremePerformance.profile
        #expect(!p.chargeLimitEnabled)
        #expect(p.chargeLimit == 100)
        #expect(p.fullChargePower)
    }

    @Test func extremeKeepsAHeatBackstop() {
        // Heat-aware charging stays on, just with the nuisance threshold moved out of the
        // way. Charging a lithium cell above ~45 °C damages it, and no performance mode is
        // worth that — so this is the assertion that stops a future "just turn it off".
        let p = SaveMode.extremePerformance.profile
        #expect(p.heatAwareEnabled)
        #expect(p.maxChargeTempC > SaveMode.normal.profile.maxChargeTempC)
        #expect(p.maxChargeTempC <= 45.0)
    }

    @Test func extremeAndLowPowerAreMutuallyExclusive() {
        let p = SaveMode.extremePerformance.profile
        #expect(p.highPowerMode)
        #expect(!p.lowPowerMode)
        // The two are faces of one pmset key, so no mode may ask for both.
        for mode in SaveMode.allCases {
            #expect(!(mode.profile.highPowerMode && mode.profile.lowPowerMode),
                    "\(mode.rawValue) asks for High and Low Power Mode at once")
        }
    }

    @Test func onlyExtremeBlocksIdleSleep() {
        #expect(SaveMode.extremePerformance.profile.preventIdleSleep)
        for mode in SaveMode.allCases where !mode.isPerformance {
            #expect(!mode.profile.preventIdleSleep)
        }
    }

    @Test func savingModesAreUnchangedByTheNewFields() {
        // The new profile fields default to off, so the three original modes must still
        // describe exactly what they did before.
        for mode in [SaveMode.off, .normal, .superSaver] {
            let p = mode.profile
            #expect(!p.highPowerMode)
            #expect(!p.preventIdleSleep)
            #expect(!p.fullChargePower)
        }
    }

    @Test func unknownModeDecodesToOffInsteadOfThrowing() throws {
        // A helper older than this case must not fail the whole config decode over one
        // unrecognised string — that would reset every other setting to its default.
        let decoded = try JSONDecoder().decode(SaveMode.self,
                                               from: Data(#""someFutureMode""#.utf8))
        #expect(decoded == .off)
    }

    @Test func knownModesStillRoundTrip() throws {
        for mode in SaveMode.allCases {
            let data = try JSONEncoder().encode(mode)
            #expect(try JSONDecoder().decode(SaveMode.self, from: data) == mode)
        }
    }

    // MARK: - Transitions

    /// Somebody mid-render: gentle charging on, a charge limit.
    private var busyUser: EWizConfig {
        EWizConfig(chargeLimitEnabled: true, chargeLimit: 80,
                       preventIdleSleep: false,
                       slowCharge: true, chargePower: 55,
                       mode: .off)
    }

    @Test func enteringExtremeTakesTheBrakesOff() {
        let cfg = busyUser.applying(.extremePerformance)
        #expect(cfg.mode == .extremePerformance)
        #expect(!cfg.chargeLimitEnabled)
        #expect(cfg.preventIdleSleep)
        #expect(cfg.chargePower == 100)
        #expect(!cfg.slowCharge)
    }

    @Test func leavingExtremePutsBackWhatItTook() {
        // The whole point: flip it on for a render, flip it off, and your charge rate is
        // exactly where you left it.
        let round = busyUser.applying(.extremePerformance).applying(.off)
        #expect(round.chargePower == 55)
        #expect(round.slowCharge)
        #expect(!round.preventIdleSleep)
        #expect(round.performanceRestore == nil)
    }

    @Test func reapplyingExtremeDoesNotClobberTheSnapshot() {
        // Re-applying the mode it's already in must not snapshot Extreme's own values —
        // that would make the exit restore full-rate charging as if the user had chosen it.
        let twice = busyUser.applying(.extremePerformance).applying(.extremePerformance)
        #expect(twice.performanceRestore?.chargePower == 55)
        #expect(twice.applying(.off).chargePower == 55)
    }

    @Test func leavingExtremeStillHonoursTheModeYouPicked() {
        // Restore covers only the settings no other mode owns. Charge limit and heat are
        // every mode's business, so Normal's own values must win over the snapshot.
        let toNormal = busyUser.applying(.extremePerformance).applying(.normal)
        #expect(toNormal.chargeLimitEnabled)
        #expect(toNormal.chargeLimit == 80)
        #expect(toNormal.heatAwareEnabled)
        #expect(toNormal.maxChargeTempC == SaveMode.normal.profile.maxChargeTempC)
        #expect(toNormal.chargePower == 55)     // still restored
    }

    @Test func switchingBetweenSavingModesLeavesChargeRateAlone() {
        // No performance mode involved, so nothing may touch the charge rate.
        for from in [SaveMode.off, .normal, .superSaver] {
            for to in [SaveMode.off, .normal, .superSaver] {
                var cfg = busyUser
                cfg.mode = from
                #expect(cfg.applying(to).chargePower == 55,
                        "\(from.rawValue) → \(to.rawValue) changed the charge rate")
                #expect(cfg.applying(to).performanceRestore == nil)
            }
        }
    }

    @Test func extremeClearsHoldsThatWouldStarveIt() {
        var cfg = busyUser
        cfg.holdCharge = true
        cfg.dischargeEnabled = true
        cfg.pauseUntil = Date(timeIntervalSince1970: 4_000_000_000)
        let hot = cfg.applying(.extremePerformance)
        #expect(!hot.holdCharge)
        #expect(!hot.dischargeEnabled)
        #expect(hot.pauseUntil == nil)
    }

    @Test func savingModesDoNotClearAPause() {
        // Only the performance mode has a reason to override an explicit pause.
        var cfg = busyUser
        cfg.pauseUntil = Date(timeIntervalSince1970: 4_000_000_000)
        #expect(cfg.applying(.normal).pauseUntil != nil)
    }

    @Test func configSurvivesAnUnknownMode() throws {
        // The real shape of the hazard: `EWizConfig` carries the mode, and an
        // unrecognised one used to take the charge limit down with it.
        let json = #"{"chargeLimitEnabled":true,"chargeLimit":73,"mode":"warpDrive"}"#
        let cfg = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(cfg.chargeLimit == 73)
        #expect(cfg.chargeLimitEnabled)
        #expect(cfg.mode == .off)
    }
}
