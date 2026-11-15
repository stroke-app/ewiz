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

@Suite("Charging from current, not only the flag")
struct ChargingFromCurrentTests {
    @Test("current flowing in counts before macOS's flag turns over")
    func currentBeatsALaggingFlag() {
        #expect(BatteryMonitor.isCharging(flag: false, amperage: 1063, cableIn: true, full: false))
    }

    @Test("a trickle on the adapter is not charging")
    func trickleIsNot() {
        #expect(!BatteryMonitor.isCharging(flag: false, amperage: 120, cableIn: true, full: false))
    }

    @Test("no cable, or a full battery, is never charging from current alone")
    func needsCableAndRoom() {
        #expect(!BatteryMonitor.isCharging(flag: false, amperage: 2000, cableIn: false, full: false))
        #expect(!BatteryMonitor.isCharging(flag: false, amperage: 2000, cableIn: true, full: true))
    }

    @Test("the flag saying yes is kept")
    func flagWins() {
        #expect(BatteryMonitor.isCharging(flag: true, amperage: -500, cableIn: true, full: false))
    }
}

@Suite("Cable presence through an adapter cut")
struct CablePresenceTests {
    @Test("a cut that clears ExternalConnected is still a cable in")
    func cutIsNotAnUnplug() {
        #expect(BatteryMonitor.cablePresent(externalConnected: false, chargeCapable: true))
    }

    @Test("a real unplug clears both")
    func unplug() {
        #expect(!BatteryMonitor.cablePresent(externalConnected: false, chargeCapable: false))
        #expect(!BatteryMonitor.cablePresent(externalConnected: false, chargeCapable: nil))
    }

    @Test("connected is connected")
    func connected() {
        #expect(BatteryMonitor.cablePresent(externalConnected: true, chargeCapable: false))
    }
}
