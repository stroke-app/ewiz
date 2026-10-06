import Testing
import Foundation
@testable import EWizKit

@Suite("Sealed Sleep")
struct SealedSleepTests {

    /// A Mac with nothing left to fix: memory powered down, standby allowed, every
    /// wake source off, both radios dropped at the close, nothing holding it awake.
    private var sealedState: SleepState {
        SleepState(hibernateMode: SealedSleep.hibernateSealed,
                   standby: true,
                   powerNap: false,
                   wakeForNetwork: false,
                   networkInSleep: false,
                   terminalSessionsKeepAwake: false,
                   wifiOffOnLidClose: true,
                   bluetoothOffOnLidClose: true,
                   keepAwakeOnBattery: false)
    }

    // MARK: - The audit

    @Test func aFullySealedMacReportsNothing() {
        #expect(sealedState.isSealed)
        #expect(sealedState.leaks.isEmpty)
    }

    @Test func macOSDefaultsLeakOnEveryFront() {
        // What an untouched Mac looks like: memory held up, Power Nap and TCP keep-alive
        // on, radios left to their own devices.
        let state = SleepState(hibernateMode: SealedSleep.hibernateDefault,
                               standby: true,
                               powerNap: true,
                               wakeForNetwork: false,
                               networkInSleep: true,
                               terminalSessionsKeepAwake: false)
        #expect(!state.isSealed)
        #expect(state.leaks.contains(.memoryStaysPowered))
        #expect(state.leaks.contains(.powerNap))
        #expect(state.leaks.contains(.networkInSleep))
        #expect(state.leaks.contains(.wifiLeftOn))
        #expect(state.leaks.contains(.bluetoothLeftOn))
    }

    @Test func memoryIsTheFirstThingReported() {
        // The ordering is the advice. Powering memory down is worth more than every
        // other lever combined, so it can never be buried under Bluetooth.
        let state = SleepState(hibernateMode: SealedSleep.hibernateDefault,
                               standby: false, powerNap: true)
        #expect(state.leaks.first == .memoryStaysPowered)
    }

    @Test func aKeyThisMacDoesNotHaveIsNotALeak() {
        // nil means "pmset never printed this key", which is a Mac that cannot spend
        // power through it. Reporting it would put a permanent red mark on hardware
        // that is already doing everything it can.
        var state = sealedState
        state.powerNap = nil
        state.networkInSleep = nil
        state.terminalSessionsKeepAwake = nil
        state.standby = nil
        #expect(state.isSealed)
    }

    @Test func anyHibernateModeOtherThanSealedCounts() {
        // 0 and 3 both leave memory powered; only 25 takes it down. An earlier version
        // of this checked `!= 3`, which quietly called mode 0 sealed.
        for mode in [0, 3, 7] {
            var state = sealedState
            state.hibernateMode = mode
            #expect(state.leaks == [.memoryStaysPowered], "hibernatemode \(mode) read as sealed")
        }
    }

    @Test func keepAwakeOnBatteryIsTheUsersCallNotOurs() {
        var state = sealedState
        state.keepAwakeOnBattery = true
        #expect(state.leaks == [.keptAwakeOnBattery])
        #expect(state.automaticLeaks.isEmpty)
        #expect(state.manualLeaks == [.keptAwakeOnBattery])
    }

    @Test func everythingElseIsSomethingWeCanFixOurselves() {
        for leak in SleepLeak.allCases where leak != .keptAwakeOnBattery {
            #expect(leak.isAutomatic, "\(leak.rawValue) has no automatic fix")
        }
    }

    @Test func leakOrderingIsTotal() {
        // Two causes sharing a weight would sort unstably, and a checklist that
        // reshuffles itself between refreshes is unreadable.
        let weights = SleepLeak.allCases.map(\.weight)
        #expect(Set(weights).count == weights.count)
    }

    // MARK: - Config

    @Test func sealedSleepIsOffOnANewInstall() {
        // It trades instant wake for zero drain. That's a choice, not a default.
        #expect(!EWizConfig().sealedSleep)
        #expect(EWizConfig.default.sealedSleepRestore == nil)
    }

    @Test func aConfigThatChoseDeepSleepKeepsWhatItAskedFor() throws {
        // The old Normal/Deep picker wrote the same hibernatemode this does, so anyone
        // on Deep had already made this trade and must not be silently reverted.
        let json = #"{"chargeLimitEnabled":true,"chargeLimit":75,"sleepDepth":"deep"}"#
        let config = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(config.sealedSleep)
        #expect(config.chargeLimit == 75)
    }

    @Test func aConfigThatChoseNormalSleepStaysUnsealed() throws {
        let json = #"{"chargeLimit":75,"sleepDepth":"normal"}"#
        let config = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(!config.sealedSleep)
    }

    @Test func theNewKeyWinsOverTheLegacyOne() throws {
        // A config written by this build carries both while it still has the old key
        // from a previous save. The explicit flag is the answer.
        let json = #"{"sealedSleep":false,"sleepDepth":"deep"}"#
        let config = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(!config.sealedSleep)
    }

    @Test func theRestoreSnapshotRoundTrips() throws {
        var config = EWizConfig()
        config.sealedSleep = true
        config.sealedSleepRestore = SealedSleepRestore(
            hibernateMode: 3, standby: true, powerNap: true,
            wakeForNetwork: false, networkInSleep: true,
            terminalSessionsKeepAwake: false)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(EWizConfig.self, from: data)
        #expect(decoded.sealedSleep)
        #expect(decoded.sealedSleepRestore == config.sealedSleepRestore)
    }

    // MARK: - The measured result

    @Test func aSessionThatLostNothingReadsAsZero() {
        let closed = Date()
        let session = LidSession(closedAt: closed, closeCharge: 84,
                                 openedAt: closed.addingTimeInterval(11 * 3600),
                                 openCharge: 84)
        let result = try! #require(SealedSleepResult(session))
        #expect(result.isEssentiallyZero)
        #expect(result.perHour == 0)
    }

    @Test func drainIsReportedPerHourAndPerNight() {
        let closed = Date()
        // 8 points over 8 hours: one an hour, and by definition 8 overnight.
        let session = LidSession(closedAt: closed, closeCharge: 80,
                                 openedAt: closed.addingTimeInterval(8 * 3600),
                                 openCharge: 72)
        let result = try! #require(SealedSleepResult(session))
        #expect(!result.isEssentiallyZero)
        #expect(abs(result.perHour - 1) < 0.001)
        #expect(abs(result.overnightPercent - 8) < 0.01)
    }

    @Test func aBlinkOfALidCloseHasNoUsefulRate() {
        // Two minutes shut can't distinguish 0%/hour from 30%/hour, so it reports nothing
        // rather than a number derived from one tick of an integer gauge.
        let closed = Date()
        let session = LidSession(closedAt: closed, closeCharge: 80,
                                 openedAt: closed.addingTimeInterval(120),
                                 openCharge: 79)
        #expect(SealedSleepResult(session) == nil)
    }

    @Test func chargingWhileClosedIsNotNegativeDrain() {
        let closed = Date()
        let session = LidSession(closedAt: closed, closeCharge: 60,
                                 openedAt: closed.addingTimeInterval(3600),
                                 openCharge: 80)
        let result = try! #require(SealedSleepResult(session))
        #expect(result.perHour == 0)
        #expect(result.isEssentiallyZero)
    }

    // MARK: - Standby timing

    @Test func standbyTimingNamesEveryKeyItWrites() {
        // `keys` drives both the snapshot and the restore. If it ever drifts from what
        // `settings` writes, Sealed Sleep changes a key it will never put back.
        #expect(Set(StandbyTiming.keys) == Set(StandbyTiming.settings.map(\.key)))
        #expect(StandbyTiming.keys.count == StandbyTiming.settings.count)
    }

    @Test func standbyDelaysAreShortAndEqual() {
        // The bug this exists to fix: stock `standbydelayhigh` is 24 hours and
        // `highstandbythreshold` 50, so a Mac closed above half charge spends the whole
        // weekend in ordinary sleep with memory powered — hibernatemode set, never engaged.
        // Both delays have to be short, and the threshold has to stop choosing the long one.
        let values = Dictionary(uniqueKeysWithValues: StandbyTiming.settings.map { ($0.key, $0.value) })
        #expect(values["standbydelaylow"] == values["standbydelayhigh"])
        #expect(Int(values["standbydelaylow"] ?? "") ?? .max <= 900)
        #expect(values["highstandbythreshold"] == "0")
        #expect(values["autopoweroff"] == "1")
    }

    @Test func aSnapshotWithoutExtrasRestoresNothingExtra() {
        // Snapshots written before `extras` existed decode with an empty set. Empty is the
        // correct answer, not a guessed default: nothing was changed, so nothing is undone.
        let json = #"{"hibernateMode":3,"standby":true,"powerNap":true,"wakeForNetwork":false,"networkInSleep":true,"terminalSessionsKeepAwake":false}"#
        let restore = try! JSONDecoder().decode(SealedSleepRestore.self, from: Data(json.utf8))
        #expect(restore.extras.isEmpty)
        #expect(restore.hibernateMode == 3)
    }

    @Test func extrasSurviveARoundTrip() {
        let saved = SealedSleepRestore(
            hibernateMode: 3, standby: true, powerNap: true,
            wakeForNetwork: false, networkInSleep: true,
            terminalSessionsKeepAwake: false,
            extras: ["standbydelayhigh": "86400", "highstandbythreshold": "50"])
        let data = try! JSONEncoder().encode(saved)
        let back = try! JSONDecoder().decode(SealedSleepRestore.self, from: data)
        #expect(back == saved)
        #expect(back.extras["standbydelayhigh"] == "86400")
    }

    // MARK: - Instant wake

    @Test func instantWakeIsTheDefaultForANewInstall() {
        // The other levers already hold the charge on recent hardware; hibernation is the
        // opt-in for the case that actually needs it, not the price of entry.
        #expect(SealedSleep.fastWakeIsDefault)
        #expect(EWizConfig().sealedSleepFastWake)
    }

    @Test func poweredMemoryIsNotALeakWhenInstantWakeWasChosen() {
        var state = sealedState
        state.hibernateMode = SealedSleep.hibernateDefault
        state.fastWake = true
        // Nothing to report: the user asked for powered memory and got it.
        #expect(state.isSealed)
    }

    @Test func poweredMemoryIsStillALeakWhenHibernationWasChosen() {
        var state = sealedState
        state.hibernateMode = SealedSleep.hibernateDefault
        state.fastWake = false
        #expect(state.leaks == [.memoryStaysPowered])
    }

    @Test func instantWakeDoesNotExcuseAnyOtherLeak() {
        // It is one specific trade, not a way to silence the checklist.
        var state = sealedState
        state.fastWake = true
        state.powerNap = true
        state.networkInSleep = true
        #expect(state.leaks.contains(.powerNap))
        #expect(state.leaks.contains(.networkInSleep))
        #expect(!state.leaks.contains(.memoryStaysPowered))
    }

    @Test func anExistingSealedConfigKeepsHibernating() throws {
        // Anyone already sealed chose it under the old behaviour, where sealed meant
        // hibernating. Flipping their Mac to a different sleep mode on upgrade, silently,
        // is worse than leaving them on the slower setting until they pick for themselves.
        let json = #"{"sealedSleep":true}"#
        let cfg = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(cfg.sealedSleep)
        #expect(!cfg.sealedSleepFastWake)
    }

    @Test func anUnsealedConfigTakesTheNewDefault() throws {
        let json = #"{"sealedSleep":false}"#
        let cfg = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(cfg.sealedSleepFastWake)
    }

    @Test func anExplicitChoiceWinsOverBothDefaults() throws {
        let json = #"{"sealedSleep":true,"sealedSleepFastWake":true}"#
        let cfg = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(cfg.sealedSleepFastWake)
    }
}

// MARK: - Handover verdict

/// The receipt used to report the drop and nothing else, so a deferral that was booked
/// and never delivered looked exactly like one that was switched off.
@Suite("Handover verdict from the measured drop")
struct HandoverVerdictTests {

    private func result(hours: Double, drop: Int) -> SealedSleepResult {
        let closedAt = Date(timeIntervalSince1970: 1_000_000)
        return SealedSleepResult(LidSession(closedAt: closedAt,
                                            closeCharge: 80,
                                            openedAt: closedAt.addingTimeInterval(hours * 3600),
                                            openCharge: 80 - drop))!
    }

    @Test("no deferral booked means the trickle is expected, not a fault")
    func neverConfigured() {
        #expect(result(hours: 7, drop: 1).handover(afterMinutes: 0) == .notConfigured)
    }

    @Test("a close inside the window has nothing to hand over")
    func shorterThanTheWindow() {
        #expect(result(hours: 0.2, drop: 0).handover(afterMinutes: 20) == .tooShortToMatter)
    }

    @Test("a close only just past the deadline is not judged")
    func justPastTheDeadline() {
        // 25 minutes against a 20-minute window: barely any hibernated time to show up in
        // a whole percentage point.
        #expect(result(hours: 25.0 / 60.0, drop: 0).handover(afterMinutes: 20) == .tooShortToMatter)
    }

    @Test("a long close with a flat line means the handover worked")
    func longAndFlat() {
        #expect(result(hours: 7, drop: 0).handover(afterMinutes: 20) == .worked)
    }

    @Test("a long close that still lost a point means memory stayed powered")
    func longAndDraining() {
        #expect(result(hours: 7, drop: 1).handover(afterMinutes: 20) == .didNotFire)
        #expect(result(hours: 22, drop: 2).handover(afterMinutes: 5) == .didNotFire)
    }
}
