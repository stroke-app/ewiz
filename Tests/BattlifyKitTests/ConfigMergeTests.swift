import Foundation
import Testing
@testable import BattlifyKit

@Suite("Three-way config merge")
struct ConfigMergeTests {
    /// The bug: an agent took the lid hold, the app (still holding the old config) toggled
    /// something unrelated, and its write switched the hold off.
    @Test("A remote change survives an unrelated local edit")
    func remoteSurvives() {
        let base = BattlifyConfig.default
        var local = base
        local.chargeLimitEnabled = true
        var remote = base
        remote.keepAwake = true
        remote.keepAwakeUntil = Date(timeIntervalSince1970: 2_000_000_000)

        let merged = BattlifyConfig.merge(base: base, local: local, remote: remote)
        #expect(merged.chargeLimitEnabled)
        #expect(merged.keepAwake)
        #expect(merged.keepAwakeUntil == remote.keepAwakeUntil)
    }

    @Test("A field the user changed wins over the remote one")
    func localWins() {
        var base = BattlifyConfig.default
        base.chargeLimit = 80
        var local = base
        local.chargeLimit = 90
        var remote = base
        remote.chargeLimit = 85

        #expect(BattlifyConfig.merge(base: base, local: local, remote: remote).chargeLimit == 90)
    }

    /// The daemon's timer cleared Always Active; a stale copy must not switch it back on.
    @Test("A field the daemon cleared stays cleared")
    func remoteClearSurvives() {
        var base = BattlifyConfig.default
        base.keepAwake = true
        base.keepAwakeUntil = Date(timeIntervalSince1970: 1_900_000_000)
        var local = base
        local.heatAwareEnabled.toggle()
        var remote = base
        remote.keepAwake = false
        remote.keepAwakeUntil = nil

        let merged = BattlifyConfig.merge(base: base, local: local, remote: remote)
        #expect(!merged.keepAwake)
        #expect(merged.keepAwakeUntil == nil)
        #expect(merged.heatAwareEnabled == local.heatAwareEnabled)
    }

    @Test("Setting an optional to nil locally is a change")
    func localNilIsAChange() {
        var base = BattlifyConfig.default
        base.keepAwakeUntil = Date(timeIntervalSince1970: 1_900_000_000)
        var local = base
        local.keepAwakeUntil = nil
        let remote = base

        #expect(BattlifyConfig.merge(base: base, local: local, remote: remote).keepAwakeUntil == nil)
    }
}
