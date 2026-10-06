import Testing
@testable import EWizKit

@Suite("macOS charge limit steps")
struct NativeChargeLimitStepTests {
    let steps = [80, 85, 90, 95, 100]

    @Test("A target on a step stops on that step")
    func onStep() {
        #expect(NativeChargeLimit.step(for: 80, in: steps) == 80)
        #expect(NativeChargeLimit.step(for: 90, in: steps) == 90)
    }

    /// Never fuller than asked: a hold thrown at 83% parks on 80, not 85.
    @Test("Between steps rounds down")
    func roundsDown() {
        #expect(NativeChargeLimit.step(for: 83, in: steps) == 80)
        #expect(NativeChargeLimit.step(for: 99, in: steps) == 95)
    }

    /// The floor is the lowest this Mac can hold at all; the app warns wherever this applies.
    @Test("Below the floor stops at the floor")
    func belowFloor() {
        #expect(NativeChargeLimit.step(for: 70, in: steps) == 80)
        #expect(NativeChargeLimit.step(for: 20, in: steps) == 80)
    }

    @Test("At the top step there's nothing to enforce")
    func top() {
        #expect(NativeChargeLimit.step(for: 100, in: steps) == nil)
    }

    @Test("No steps means no native limit")
    func unsupported() {
        #expect(NativeChargeLimit.step(for: 80, in: []) == nil)
    }
}

@Suite("MagSafe status colour")
struct MagSafeStatusTests {
    @Test("Taking charge is amber")
    func charging() {
        #expect(MagSafeLED.status(settling: false, onExternalPower: true,
                                  adapterCut: false, charging: true) == .orange)
    }

    /// Held at a limit, full, or macOS's own limit reached: plugged in and not charging.
    @Test("On the cable and not charging is green")
    func held() {
        #expect(MagSafeLED.status(settling: false, onExternalPower: true,
                                  adapterCut: false, charging: false) == .green)
    }

    /// The case that showed amber through a hold: the snapshot still said charging when
    /// the adapter had just been cut.
    @Test("A cut adapter is green whatever the snapshot says")
    func adapterCut() {
        #expect(MagSafeLED.status(settling: false, onExternalPower: true,
                                  adapterCut: true, charging: true) == .green)
    }

    @Test("Unplugged hands the light to macOS; settling turns it off")
    func unpluggedAndSettling() {
        #expect(MagSafeLED.status(settling: false, onExternalPower: false,
                                  adapterCut: false, charging: false) == .system)
        #expect(MagSafeLED.status(settling: true, onExternalPower: true,
                                  adapterCut: false, charging: true) == .off)
    }
}

@Suite("Hold and limit under macOS's charge limit")
struct NativeHoldTargetTests {
    let steps = [80, 85, 90, 95, 100]

    /// Each step is a setpoint: above it macOS drains the battery down to it. Rounding the
    /// hold down made "don't charge" at 85% drain to 80.
    @Test("The hold rounds up, never down")
    func roundsUp() {
        #expect(NativeChargeLimit.target(holdAnchor: 85, limit: nil, in: steps) == 85)
        #expect(NativeChargeLimit.target(holdAnchor: 83, limit: nil, in: steps) == 85)
        #expect(NativeChargeLimit.target(holdAnchor: 86, limit: nil, in: steps) == 90)
    }

    @Test("Above the top real step the hold is no limit, which macOS holds at full")
    func aboveTop() {
        #expect(NativeChargeLimit.target(holdAnchor: 95, limit: nil, in: steps) == 95)
        #expect(NativeChargeLimit.target(holdAnchor: 97, limit: nil, in: steps) == nil)
    }

    /// A lower limit would drain a held battery down to it.
    @Test("The hold wins over a lower limit")
    func holdWins() {
        #expect(NativeChargeLimit.target(holdAnchor: 85, limit: 80, in: steps) == 85)
    }

    @Test("Below the floor the hold stops at the floor")
    func belowFloor() {
        #expect(NativeChargeLimit.target(holdAnchor: 70, limit: nil, in: steps) == 80)
        #expect(NativeChargeLimit.target(holdAnchor: 80, limit: nil, in: steps) == 80)
    }

    @Test("No hold is just the limit; neither is nothing")
    func limitOnly() {
        #expect(NativeChargeLimit.target(holdAnchor: nil, limit: 80, in: steps) == 80)
        #expect(NativeChargeLimit.target(holdAnchor: nil, limit: 100, in: steps) == nil)
        #expect(NativeChargeLimit.target(holdAnchor: nil, limit: nil, in: steps) == nil)
    }
}
