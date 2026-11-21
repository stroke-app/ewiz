import Testing
import Foundation
@testable import EWizKit

@Suite("Config compatibility")
struct ConfigCompatibilityTests {

    @Test("A config written while fan control existed still loads")
    func decodesConfigWithRemovedFanKeys() throws {
        // Two generations of fan feature wrote keys here — fan boost, then fan control.
        // Both are gone, and removing them must not brick the configs they left behind:
        // the rest has to decode as normal.
        let json = #"""
        {"chargeLimitEnabled":true,"chargeLimit":75,"sleepDepth":"deep",
         "fanMode":{"manual":{"percent":40}},"fanAutoAboveTempC":85,
         "fanBoostEnabled":true,"fanBoostPercent":70,
         "fanBoostMinCpu":40,"fanBoostOnlyWhenKeepAwake":true}
        """#
        let config = try JSONDecoder().decode(EWizConfig.self, from: Data(json.utf8))
        #expect(config.chargeLimitEnabled)
        #expect(config.chargeLimit == 75)
        #expect(config.sealedSleep)   // migrated from the old sleepDepth key
    }
}
