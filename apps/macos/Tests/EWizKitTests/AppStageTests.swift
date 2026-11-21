import Testing
@testable import EWizKit

struct AppStageTests {
    @Test func zeroMajorIsBeta() {
        #expect(AppStage.isBeta(version: "0.20.1"))
        #expect(AppStage.isBeta(version: "0.1.0"))
    }

    @Test func oneAndAboveIsNotBeta() {
        #expect(!AppStage.isBeta(version: "1.0.0"))
        #expect(!AppStage.isBeta(version: "2.3.4"))
    }

    @Test func unreadableVersionCountsAsBeta() {
        #expect(AppStage.isBeta(version: ""))
        #expect(AppStage.isBeta(version: "dev"))
    }
}
