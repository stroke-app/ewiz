import Foundation
import Testing
@testable import BattlifyKit

@Suite struct AgentLidHoldTests {
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func config(keepAwake: Bool = false, until: Date? = nil, onBattery: Bool = false) -> BattlifyConfig {
        var c = BattlifyConfig.default
        c.keepAwake = keepAwake
        c.keepAwakeUntil = until
        c.keepAwakeOnBattery = onBattery
        return c
    }

    @Test func offTurnsOnWithTheAgentsDeadline() {
        let wanted = AgentLidHold.deadline(minutes: 30, from: now)
        guard case let .write(cfg, lease) = AgentLidHold.plan(
            config: config(), current: nil, wanted: wanted, onBattery: nil, now: now) else {
            Issue.record("expected a write"); return
        }
        #expect(cfg.keepAwake && cfg.keepAwakeUntil == wanted)
        #expect(lease == AgentLidHold.Lease(deadline: wanted))
    }

    @Test func usersIndefiniteHoldIsLeftAlone() {
        let plan = AgentLidHold.plan(config: config(keepAwake: true), current: nil,
                                     wanted: now.addingTimeInterval(600), onBattery: true, now: now)
        #expect(plan == .coveredByUser)
    }

    @Test func usersLongerTimerCoversIt() {
        let user = now.addingTimeInterval(7200)
        let plan = AgentLidHold.plan(config: config(keepAwake: true, until: user), current: nil,
                                     wanted: now.addingTimeInterval(600), onBattery: nil, now: now)
        #expect(plan == .coveredUntil(user))
    }

    @Test func usersShorterTimerIsExtendedThenRestored() {
        let user = now.addingTimeInterval(600)
        let wanted = now.addingTimeInterval(3600)
        guard case let .write(cfg, lease) = AgentLidHold.plan(
            config: config(keepAwake: true, until: user), current: nil, wanted: wanted,
            onBattery: nil, now: now) else {
            Issue.record("expected a write"); return
        }
        #expect(lease.userDeadline == user)
        let released = AgentLidHold.release(config: cfg, lease: lease, now: now.addingTimeInterval(60))
        #expect(released?.keepAwake == true && released?.keepAwakeUntil == user)
        // Released after the user's own timer would have run out: off, not resurrected.
        let late = AgentLidHold.release(config: cfg, lease: lease, now: now.addingTimeInterval(900))
        #expect(late?.keepAwake == false && late?.keepAwakeUntil == nil)
    }

    @Test func renewalMovesOnlyTheAgentsDeadline() {
        let first = AgentLidHold.Lease(deadline: now.addingTimeInterval(600), userOnBattery: false)
        let cfg = config(keepAwake: true, until: first.deadline, onBattery: true)
        let wanted = now.addingTimeInterval(1800)
        guard case let .write(next, lease) = AgentLidHold.plan(
            config: cfg, current: first, wanted: wanted, onBattery: nil, now: now) else {
            Issue.record("expected a write"); return
        }
        #expect(next.keepAwakeUntil == wanted && next.keepAwakeOnBattery)
        #expect(lease.userOnBattery == false)   // the original setting survives the renewal
    }

    @Test func onBatteryIsRestoredOnRelease() {
        guard case let .write(cfg, lease) = AgentLidHold.plan(
            config: config(), current: nil, wanted: now.addingTimeInterval(600),
            onBattery: true, now: now) else {
            Issue.record("expected a write"); return
        }
        #expect(cfg.keepAwakeOnBattery && lease.userOnBattery == false)
        #expect(AgentLidHold.release(config: cfg, lease: lease, now: now)?.keepAwakeOnBattery == false)
    }

    @Test func releaseLeavesAHoldThatIsNoLongerOurs() {
        let lease = AgentLidHold.Lease(deadline: now.addingTimeInterval(600))
        // The user switched Always Active on indefinitely since.
        #expect(AgentLidHold.release(config: config(keepAwake: true), lease: lease, now: now) == nil)
        // The helper already cleared it at the deadline.
        #expect(AgentLidHold.release(config: config(), lease: lease, now: now) == nil)
    }

    @Test func deadlineSurvivesTheJSONRoundTrip() throws {
        let lease = AgentLidHold.Lease(
            deadline: AgentLidHold.deadline(minutes: 7, from: now.addingTimeInterval(0.37)))
        let cfg = config(keepAwake: true, until: lease.deadline)
        let back = try JSONDecoder().decode(BattlifyConfig.self, from: JSONEncoder().encode(cfg))
        #expect(AgentLidHold.owns(lease, in: back))
    }
}
