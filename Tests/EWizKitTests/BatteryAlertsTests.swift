import Testing
@testable import EWizKit

@Suite struct BatteryAlertsTests {
    func r(_ percent: Int, plugged: Bool = false, left: Int? = nil) -> BatteryAlerts.Reading {
        .init(percent: percent, pluggedIn: plugged, minutesToEmpty: left)
    }

    @Test func oneDischargeIsLowThenCriticalThenCharger() {
        var t = BatteryAlerts.Tracker()
        #expect(t.update(r(50), threshold: 20) == nil)
        #expect(t.update(r(20, left: 42), threshold: 20)?.event == "battery_low")
        #expect(t.update(r(19), threshold: 20) == nil)
        #expect(t.update(r(10), threshold: 20)?.event == "battery_critical")
        #expect(t.update(r(9), threshold: 20) == nil)
        #expect(t.update(r(9, plugged: true), threshold: 20)?.event == "charger_connected")
        #expect(t.update(r(9, plugged: true), threshold: 20) == nil)
    }

    @Test func aReadingThatBobsUpDoesNotReAnnounce() {
        var t = BatteryAlerts.Tracker()
        #expect(t.update(r(20), threshold: 20)?.event == "battery_low")
        #expect(t.update(r(21), threshold: 20) == nil)
        #expect(t.update(r(20), threshold: 20) == nil)
    }

    @Test func startingCriticalSkipsLow() {
        var t = BatteryAlerts.Tracker()
        #expect(t.update(r(5), threshold: 20)?.event == "battery_critical")
    }

    @Test func pluggedInNeverWarnsAndChargerNeedsAPriorWarning() {
        var t = BatteryAlerts.Tracker()
        #expect(t.update(r(3, plugged: true), threshold: 20) == nil)
    }

    @Test func aThresholdAtTheCriticalLevelIsOneWarning() {
        var t = BatteryAlerts.Tracker()
        #expect(t.update(r(10), threshold: 10)?.event == "battery_critical")
        #expect(t.update(r(5), threshold: 10) == nil)
    }

    @Test func textCarriesPercentAndTimeLeft() {
        var t = BatteryAlerts.Tracker()
        let text = t.update(r(18, left: 75), threshold: 20)?.text ?? ""
        #expect(text.contains("18%"))
        #expect(text.contains("1h 15m left"))
    }
}
