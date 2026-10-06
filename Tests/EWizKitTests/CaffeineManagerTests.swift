import Testing
import Foundation
import CoreGraphics
import IOKit.pwr_mgt
@testable import EWizKit

// MARK: - Test doubles

/// Records acquire/release calls and tracks how many holds are live, so tests can
/// assert the manager never stacks assertions and always balances holds.
final class FakeKeepAwake: KeepAwakeAsserting, @unchecked Sendable {
    private let lock = NSLock()
    private var _acquireCount = 0
    private var _releaseCount = 0
    private var _held: Set<UInt32> = []
    private var _next: UInt32 = 1

    private var _kinds: [KeepAwakeHold] = []

    var acquireCount: Int { lock.withLock { _acquireCount } }
    var releaseCount: Int { lock.withLock { _releaseCount } }
    var heldCount: Int { lock.withLock { _held.count } }
    /// Every hold kind asked for, in order — so a test can assert on the swap.
    var kinds: [KeepAwakeHold] { lock.withLock { _kinds } }

    func acquire(kind: KeepAwakeHold, reason: String) -> UInt32 {
        lock.withLock {
            _acquireCount += 1
            _kinds.append(kind)
            let token = _next; _next += 1
            _held.insert(token)
            return token
        }
    }

    func release(_ token: UInt32) {
        lock.withLock {
            if _held.remove(token) != nil { _releaseCount += 1 }
        }
    }
}

/// Backend that always fails to acquire, to test the failure path.
struct FailingKeepAwake: KeepAwakeAsserting {
    func acquire(kind: KeepAwakeHold, reason: String) -> UInt32 { 0 }
    func release(_ token: UInt32) {}
}

/// Counts the user-activity declarations — the thing that keeps the screen saver and
/// the lock screen at bay, which a sleep assertion alone doesn't govern.
final class ActivityKeepAwake: KeepAwakeAsserting, @unchecked Sendable {
    private let lock = NSLock()
    private var _declared = 0
    private var _ended = 0

    var declaredCount: Int { lock.withLock { _declared } }
    var endedCount: Int { lock.withLock { _ended } }

    func acquire(kind: KeepAwakeHold, reason: String) -> UInt32 { 1 }
    func release(_ token: UInt32) {}
    func keepUserActive(reason: String) -> Bool {
        lock.withLock { _declared += 1 }
        return true
    }
    func endUserActive() { lock.withLock { _ended += 1 } }
}

/// A one-shot gate that makes injected timed-expiry deterministic: the manager
/// suspends in `wait()` until the test calls `open()`.
actor Gate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var opened = false

    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        let pending = waiters; waiters.removeAll()
        for w in pending { w.resume() }
    }
}

// MARK: - Suite

@MainActor
struct CaffeineManagerTests {

    // --- State machine (deterministic, fake backend) ---

    @Test func initiallyInactiveHoldsNothing() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        #expect(m.active == false)
        #expect(m.expiresAt == nil)
        #expect(fake.acquireCount == 0)
        #expect(fake.heldCount == 0)
    }

    // --- Power policy: what the hold covers on battery ---

    @Test func onBatteryTheHoldDropsTheDisplayButKeepsWorkRunning() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate()
        #expect(m.hold == .displayOn, "on AC the screen stays lit")

        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: false, onExternalPower: false)
        #expect(m.active, "unplugging must not end the session")
        #expect(m.hold == .systemOnly)
        #expect(fake.heldCount == 1, "swapped, not stacked")
        #expect(fake.kinds == [.displayOn, .systemOnly])

        // Plugging back in restores the full hold.
        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: false, onExternalPower: true)
        #expect(m.hold == .displayOn)
        #expect(fake.heldCount == 1)
    }

    // --- Screen saver and lock screen ---

    /// The complaint this exists for: keep-awake was on and the Mac locked itself anyway.
    /// A display-sleep assertion doesn't touch the screen-saver clock, so the hold has to
    /// declare user activity as well.
    @Test func displayHoldPushesBackTheLockClock() async {
        let backend = ActivityKeepAwake()
        let m = CaffeineManager(backend: backend)
        m.activate()
        await waitUntil { backend.declaredCount >= 1 }
        #expect(backend.declaredCount >= 1, "holding the screen on must hold off the lock")
    }

    /// A system-only hold lets the screen sleep by design, so locking behind it is the
    /// user's own setting — insisting they're active would light the screen back up.
    @Test func systemOnlyHoldLeavesTheLockClockAlone() async {
        let backend = ActivityKeepAwake()
        let m = CaffeineManager(backend: backend)
        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: false, onExternalPower: false)
        m.activate()
        #expect(m.hold == .systemOnly)
        for _ in 0..<50 { await Task.yield() }
        #expect(backend.declaredCount == 0)
    }

    @Test func deactivateStopsDeclaringActivity() async {
        let backend = ActivityKeepAwake()
        let m = CaffeineManager(backend: backend)
        m.activate()
        await waitUntil { backend.declaredCount >= 1 }
        m.deactivate()
        let after = backend.declaredCount
        #expect(backend.endedCount >= 1, "the declaration must be dropped, not left running")
        for _ in 0..<50 { await Task.yield() }
        #expect(backend.declaredCount == after, "no declarations once the session is over")
    }

    /// Unplugging narrows the hold to system-only: the screen is then free to sleep, so
    /// the activity declaration has to stop with it.
    @Test func unpluggingStopsTheActivityDeclaration() async {
        let backend = ActivityKeepAwake()
        let m = CaffeineManager(backend: backend)
        m.activate()
        await waitUntil { backend.declaredCount >= 1 }
        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: false, onExternalPower: false)
        let after = backend.declaredCount
        #expect(backend.endedCount >= 1)
        for _ in 0..<50 { await Task.yield() }
        #expect(backend.declaredCount == after)
    }

    @Test func keepDisplayOnBatteryOptsOutOfTheDowngrade() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate()
        m.applyPolicy(keepDisplayOnBattery: true, endOnBattery: false, onExternalPower: false)
        #expect(m.hold == .displayOn)
        #expect(fake.acquireCount == 1, "nothing to swap")
    }

    @Test func endOnBatteryReleasesEverythingWhenUnplugged() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate(.hours2)
        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: true, onExternalPower: false)
        #expect(m.active == false)
        #expect(m.hold == nil)
        #expect(m.expiresAt == nil, "the timer goes with the session")
        #expect(fake.heldCount == 0)
    }

    @Test func policyIsInertWhileInactive() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: true, onExternalPower: false)
        #expect(m.active == false)
        #expect(fake.acquireCount == 0)
        // A session started on battery takes the downgraded hold from the outset.
        m.applyPolicy(keepDisplayOnBattery: false, endOnBattery: false, onExternalPower: false)
        m.activate()
        #expect(m.hold == .systemOnly)
    }

    @Test func activateIndefiniteHoldsExactlyOne() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate()
        #expect(m.active)
        #expect(m.expiresAt == nil, "indefinite session has no expiry")
        #expect(fake.acquireCount == 1)
        #expect(fake.heldCount == 1)
    }

    @Test func activateIsIdempotent() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate(); m.activate(); m.activate()
        #expect(m.active)
        #expect(fake.acquireCount == 1, "must not stack assertions")
        #expect(fake.heldCount == 1)
    }

    @Test func deactivateReleases() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate()
        m.deactivate()
        #expect(m.active == false)
        #expect(m.expiresAt == nil)
        #expect(fake.releaseCount == 1)
        #expect(fake.heldCount == 0)
    }

    @Test func deactivateWhenInactiveIsNoOp() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.deactivate()
        #expect(m.active == false)
        #expect(fake.acquireCount == 0)
        #expect(fake.releaseCount == 0)
    }

    @Test func toggleFlipsState() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.toggle()
        #expect(m.active)
        #expect(fake.heldCount == 1)
        m.toggle()
        #expect(m.active == false)
        #expect(fake.heldCount == 0)
    }

    @Test func timedActivateSetsExpiryInFuture() throws {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        let before = Date()
        m.activate(.hour1)
        #expect(m.active)
        let expires = try #require(m.expiresAt)
        // ~1 hour out, within a wide tolerance.
        #expect(abs(expires.timeIntervalSince(before) - 3600) < 5)
        #expect(fake.heldCount == 1)
    }

    @Test func reArmUpdatesExpiryWithoutStackingAssertions() throws {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        m.activate(.min30)
        let first = try #require(m.expiresAt)
        m.activate(.hours5)
        #expect(fake.acquireCount == 1, "re-arming must reuse the single assertion")
        #expect(fake.heldCount == 1)
        let second = try #require(m.expiresAt)
        #expect(second > first, "5h expiry should be later than 30m")
    }

    @Test func manyCyclesBalanceHolds() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        for _ in 0..<1_000 { m.activate(); m.deactivate() }
        #expect(m.active == false)
        #expect(fake.acquireCount == 1_000)
        #expect(fake.releaseCount == 1_000)
        #expect(fake.heldCount == 0, "no leaked assertions")
    }

    @Test func acquireFailureLeavesInactive() {
        let m = CaffeineManager(backend: FailingKeepAwake())
        m.activate()
        #expect(m.active == false, "must not report active when the assertion couldn't be held")
        #expect(m.expiresAt == nil)
    }

    // --- Timed expiry (deterministic via injected gate) ---

    @Test func timedExpiryReleasesAssertion() async {
        let fake = FakeKeepAwake()
        let gate = Gate()
        let m = CaffeineManager(backend: fake, sleepFor: { _ in await gate.wait() })
        m.activate(.min30)
        #expect(m.active)
        #expect(fake.heldCount == 1)

        await gate.open()                       // "timer" fires
        await waitUntil { !m.active }           // expiry task hops back to main actor

        #expect(m.active == false)
        #expect(m.expiresAt == nil)
        #expect(fake.heldCount == 0)
    }

    @Test func deactivateCancelsPendingExpiry() async {
        let fake = FakeKeepAwake()
        let gate = Gate()
        let m = CaffeineManager(backend: fake, sleepFor: { _ in await gate.wait() })
        m.activate(.min30)
        m.deactivate()                          // cancels the expiry task
        #expect(fake.heldCount == 0)

        await gate.open()                       // cancelled task wakes…
        await Task.yield()
        // …and its `guard !Task.isCancelled` must prevent a second release.
        #expect(m.active == false)
        #expect(fake.releaseCount == 1, "expiry must not release twice")
        #expect(fake.heldCount == 0)
    }

    // --- Integration: the real OS assertion ---

    /// Proves the production `IOKitKeepAwake` backend registers a real
    /// `PreventUserIdleDisplaySleep` assertion the system can see, and clears it on
    /// release. Silently passes if this environment can't create assertions at all.
    @Test func realBackendRegistersAndClearsSystemAssertion() {
        let reason = "EWizKitTest-\(UUID().uuidString)"
        let m = CaffeineManager(backend: IOKitKeepAwake(), reason: reason)

        m.activate()
        guard m.active else { return }   // assertions unavailable → nothing to prove
        #expect(Self.processHoldsAssertion(named: reason),
                "system should report our display-sleep assertion while active")

        m.deactivate()
        #expect(Self.processHoldsAssertion(named: reason) == false,
                "assertion should be gone after deactivate")
    }

    /// The other half of the real hold: a `UserIsActive` declaration, which is what the
    /// screen saver and the lock screen actually watch. Skipped if the display is asleep —
    /// the backend deliberately declines to light it back up.
    @Test func realBackendDeclaresUserActivity() async {
        guard CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return }
        let reason = "EWizKitTest-\(UUID().uuidString)"
        let m = CaffeineManager(backend: IOKitKeepAwake(), reason: reason)

        m.activate()
        guard m.active else { return }   // assertions unavailable → nothing to prove
        let activity = "\(reason): user active"
        await waitUntil { Self.processHoldsAssertion(named: activity) }
        #expect(Self.processHoldsAssertion(named: activity),
                "keeping the screen on must also declare the user active, or it locks anyway")

        m.deactivate()
        #expect(Self.processHoldsAssertion(named: activity) == false,
                "the declaration must be dropped with the session")
    }

    // --- Benchmarks ---

    /// Benchmark: pure toggle throughput (fake backend, no OS calls). Prints ns/op
    /// and trips only on a gross regression.
    @Test func benchmarkToggleThroughput() {
        let fake = FakeKeepAwake()
        let m = CaffeineManager(backend: fake)
        let iterations = 100_000
        let elapsed = ContinuousClock().measure {
            for _ in 0..<iterations { m.activate(); m.deactivate() }
        }
        let nsPerOp = Double(elapsed.components.attoseconds) / 1e9 / Double(iterations)
        print("BENCHMARK toggle-throughput: \(iterations) activate+deactivate in \(elapsed) (~\(String(format: "%.0f", nsPerOp)) ns/op)")
        #expect(fake.heldCount == 0)
        #expect(elapsed < .seconds(5), "gross toggle-throughput regression")
    }

    /// Benchmark: real IOKit assertion acquire/release round-trips — the per-toggle OS
    /// cost, so a regression there is visible. No-op if assertions are unavailable.
    @Test func benchmarkRealAssertionCycle() {
        let m = CaffeineManager(backend: IOKitKeepAwake())
        m.activate(); let ok = m.active; m.deactivate()
        guard ok else { return }
        let iterations = 500
        let elapsed = ContinuousClock().measure {
            for _ in 0..<iterations { m.activate(); m.deactivate() }
        }
        let usPerOp = Double(elapsed.components.attoseconds) / 1e12 / Double(iterations)
        print("BENCHMARK real-IOKit-cycle: \(iterations) acquire+release in \(elapsed) (~\(String(format: "%.1f", usPerOp)) µs/op)")
    }

    // --- Helpers ---

    /// Poll main-actor state until `cond` holds (bounded), for async expiry hops.
    private func waitUntil(_ cond: () -> Bool, tries: Int = 500) async {
        var n = 0
        while !cond() && n < tries { await Task.yield(); n += 1 }
    }

    /// True if *this* process currently holds a power assertion with the given name.
    nonisolated static func processHoldsAssertion(named name: String) -> Bool {
        var out: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&out) == kIOReturnSuccess,
              let byPID = out?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        else { return false }
        let mine = byPID[NSNumber(value: getpid())] ?? []
        return mine.contains { ($0[kIOPMAssertionNameKey as String] as? String) == name }
    }
}

// MARK: - Session persistence

/// The hold is a power assertion owned by the process, so it dies when the app restarts to
/// install an update. Without these, that was silent: the tile read on over a Mac whose
/// screen went dark half an hour later.
@Suite("Caffeine session survives a restart")
@MainActor
struct CaffeineSessionRestoreTests {

    /// A throwaway defaults suite, so a test never reads or writes the real app's session.
    private func store(_ name: String = UUID().uuidString) -> UserDefaults {
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test("an indefinite session comes back after a restart")
    func indefiniteSessionIsRestored() {
        let defaults = store()
        let first = FakeKeepAwake()
        // Held, not a temporary: `CaffeineManager.deinit` releases the assertion, which is
        // right for a process going away and would otherwise be measured as a failure here.
        let original = CaffeineManager(backend: first, sessionStore: defaults)
        original.activate(.indefinite)
        #expect(first.heldCount == 1)

        // A new manager over the same defaults is what launching again looks like.
        let second = FakeKeepAwake()
        let relaunched = CaffeineManager(backend: second, sessionStore: defaults)
        #expect(!relaunched.active, "nothing is held until the launch hook runs")
        relaunched.restoreSessionIfNeeded()
        #expect(relaunched.active)
        #expect(relaunched.expiresAt == nil, "indefinite must not come back as a timed session")
        #expect(second.heldCount == 1)
    }

    @Test("a timed session comes back with only its remaining time")
    func timedSessionKeepsItsDeadline() {
        let defaults = store()
        let first = CaffeineManager(backend: FakeKeepAwake(), sessionStore: defaults)
        first.activate(.hour1)
        let deadline = first.expiresAt

        let relaunched = CaffeineManager(backend: FakeKeepAwake(), sessionStore: defaults)
        relaunched.restoreSessionIfNeeded()
        #expect(relaunched.active)
        if let restored = relaunched.expiresAt, let original = deadline {
            #expect(abs(restored.timeIntervalSince(original)) < 2,
                    "it resumes to the original deadline, not a fresh hour")
        } else {
            Issue.record("a timed session must come back with a deadline")
        }
    }

    @Test("a session whose timer ran out while the app was closed stays off")
    func expiredSessionIsNotRestored() {
        let defaults = store()
        defaults.set(Date().addingTimeInterval(-60).timeIntervalSince1970, forKey: "caffeine.session")
        let backend = FakeKeepAwake()
        let relaunched = CaffeineManager(backend: backend, sessionStore: defaults)
        relaunched.restoreSessionIfNeeded()
        #expect(!relaunched.active)
        #expect(backend.heldCount == 0)
    }

    @Test("turning it off is remembered too")
    func deactivateClearsTheSession() {
        let defaults = store()
        let manager = CaffeineManager(backend: FakeKeepAwake(), sessionStore: defaults)
        manager.activate(.indefinite)
        manager.deactivate()

        let relaunched = CaffeineManager(backend: FakeKeepAwake(), sessionStore: defaults)
        relaunched.restoreSessionIfNeeded()
        #expect(!relaunched.active, "a session switched off must not come back")
    }

    @Test("restoring twice holds one assertion")
    func restoreIsIdempotent() {
        let defaults = store()
        CaffeineManager(backend: FakeKeepAwake(), sessionStore: defaults).activate(.indefinite)

        let backend = FakeKeepAwake()
        let relaunched = CaffeineManager(backend: backend, sessionStore: defaults)
        // The only reliable launch hook is the status-item label's body, which runs often.
        for _ in 0..<5 { relaunched.restoreSessionIfNeeded() }
        #expect(backend.heldCount == 1)
    }

    @Test("no store means no persistence")
    func withoutAStoreNothingIsRemembered() {
        let manager = CaffeineManager(backend: FakeKeepAwake())
        manager.activate(.indefinite)
        let other = CaffeineManager(backend: FakeKeepAwake())
        other.restoreSessionIfNeeded()
        #expect(!other.active)
    }
}
