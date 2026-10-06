import Testing
@testable import EWizKit

@Suite("Power flow")
struct PowerFlowTests {
    /// Captured from a 14" M3 Pro on a 70 W adapter, charging at 80%.
    let charging: [String: Any] = [
        "ExternalConnected": true,
        "Voltage": 12635, "InstantAmperage": 2969,
        "AdapterDetails": ["Watts": 68, "Name": "70W USB-C Power Adapter "],
        "PowerTelemetryData": ["SystemPowerIn": 66259, "SystemLoad": 32256, "BatteryPower": 34003],
    ]

    @Test("On the charger the measured numbers are used, and they add up")
    func measured() {
        let f = PowerMonitor.flow(from: charging)
        #expect(f.isMeasured)
        #expect(f.adapterWatts == 66.259)
        #expect(f.adapterRatedWatts == 68)
        #expect(f.systemWatts == 32.256)
        #expect(abs(f.chargeWatts - 34.003) < 0.001)
    }

    /// The bug: rating minus battery booked the unused headroom to the system.
    @Test("A held battery doesn't turn the adapter rating into system draw")
    func heldBatteryIsNotSixtyEightWatts() {
        var held = charging
        held["InstantAmperage"] = 0
        held["PowerTelemetryData"] = ["SystemPowerIn": 12100, "SystemLoad": 12100]
        let f = PowerMonitor.flow(from: held)
        #expect(f.systemWatts == 12.1)
        #expect(f.adapterWatts == 12.1)
        #expect(f.chargeWatts == 0)
    }

    @Test("Without telemetry it falls back to the rating")
    func fallback() {
        var old = charging
        old["PowerTelemetryData"] = nil
        let f = PowerMonitor.flow(from: old)
        #expect(!f.isMeasured)
        #expect(f.adapterWatts == 68)
    }

    @Test("On battery the system is what the battery gives out")
    func onBattery() {
        let f = PowerMonitor.flow(from: [
            "ExternalConnected": false, "Voltage": 12000, "InstantAmperage": -1500,
            "PowerTelemetryData": ["SystemPowerIn": 0, "SystemLoad": 18000],
        ])
        #expect(!f.isMeasured)
        #expect(f.adapterWatts == nil)
        #expect(f.dischargeWatts == 18)
        #expect(f.systemWatts == 18)
    }
}
