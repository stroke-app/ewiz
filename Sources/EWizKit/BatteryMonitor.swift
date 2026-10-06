import Foundation
import IOKit
import IOKit.ps

/// A snapshot of the system's battery state at a point in time.
public struct BatterySnapshot: Equatable, Sendable {
    public var percentage: Int
    public var isCharging: Bool
    public var isPluggedIn: Bool        // external power *providing* (macOS' view)
    /// Physical adapter presence (AppleSmartBattery `ExternalConnected`). Stays true
    /// during force-discharge, when we cut the adapter and macOS flips `isPluggedIn`
    /// to false. Falls back to `isPluggedIn` when the key is unavailable.
    public var isExternalConnected: Bool
    public var isFullyCharged: Bool
    public var timeToEmpty: Int?        // minutes, nil if unknown/charging
    public var timeToFull: Int?         // minutes, nil if unknown/not charging
    public var cycleCount: Int?
    public var temperature: Double?     // degrees Celsius
    public var healthPercent: Int?      // maxCapacity / designCapacity * 100
    public var designCapacity: Int?     // mAh
    public var maxCapacity: Int?        // mAh (current full-charge capacity)
    public var powerSource: String      // "Battery Power" / "AC Power"

    /// Charger physically connected, regardless of whether macOS draws from it. Use
    /// for AC-power gating so force-discharge doesn't read as "unplugged".
    public var onExternalPower: Bool { isExternalConnected || isPluggedIn }

    public static let unknown = BatterySnapshot(
        percentage: 0, isCharging: false, isPluggedIn: false,
        isExternalConnected: false, isFullyCharged: false,
        timeToEmpty: nil, timeToFull: nil, cycleCount: nil, temperature: nil,
        healthPercent: nil, designCapacity: nil, maxCapacity: nil, powerSource: "Unknown"
    )
}

/// Reads battery state from IOKit: `IOPSCopyPowerSourcesInfo` for live state and the
/// `AppleSmartBattery` IORegistry entry for hardware detail (cycles, temp, capacities).
public enum BatteryMonitor {

    public static func read() -> BatterySnapshot {
        var snap = BatterySnapshot.unknown
        readPowerSources(into: &snap)
        readSmartBattery(into: &snap)
        return snap
    }

    // MARK: - IOPowerSources (live state)

    private static func readPowerSources(into snap: inout BatterySnapshot) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return }

        if let providing = IOPSGetProvidingPowerSourceType(blob)?.takeRetainedValue() as String? {
            snap.powerSource = providing
            snap.isPluggedIn = (providing == kIOPMACPowerKey)
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue()
                as? [String: Any] else { continue }

            if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
               let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                snap.percentage = Int((Double(cur) / Double(max) * 100).rounded())
            }

            if let state = desc[kIOPSPowerSourceStateKey] as? String {
                snap.isPluggedIn = (state == kIOPSACPowerValue)
            }
            if let charging = desc[kIOPSIsChargingKey] as? Bool {
                snap.isCharging = charging
            }
            if let charged = desc[kIOPSIsChargedKey] as? Bool {
                snap.isFullyCharged = charged
            }

            // Time estimates: -1 means "still calculating", values are in minutes.
            if let tte = desc[kIOPSTimeToEmptyKey] as? Int, tte > 0 {
                snap.timeToEmpty = tte
            }
            if let ttf = desc[kIOPSTimeToFullChargeKey] as? Int, ttf > 0 {
                snap.timeToFull = ttf
            }
        }

        // Baseline; readSmartBattery overrides with the hardware `ExternalConnected` key.
        snap.isExternalConnected = snap.isPluggedIn
    }

    // MARK: - AppleSmartBattery (hardware detail)

    private static func readSmartBattery(into snap: inout BatterySnapshot) {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0)
            == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any]
        else { return }

        // Physical adapter presence — true even while force-discharging, unlike the
        // providing-source flag. Overrides the baseline.
        if let ext = props["ExternalConnected"] as? Bool {
            snap.isExternalConnected = ext
        }

        if let cycles = props["CycleCount"] as? Int {
            snap.cycleCount = cycles
        }
        // Temperature is reported in 1/100 °C.
        if let temp = props["Temperature"] as? Int {
            snap.temperature = Double(temp) / 100.0
        }

        let design = props["DesignCapacity"] as? Int
        // Use NominalChargeCapacity for both health % and displayed mAh: it's what
        // macOS derives "Maximum Capacity" from, so the ratio matches the health %
        // shown beside it. Fall back to legacy keys only if absent.
        let maxCap = (props["NominalChargeCapacity"] as? Int)
            ?? (props["AppleRawMaxCapacity"] as? Int)
            ?? (props["MaxCapacity"] as? Int)

        snap.designCapacity = design
        snap.maxCapacity = maxCap

        if let d = design, let m = maxCap, d > 0 {
            snap.healthPercent = Int((Double(m) / Double(d) * 100).rounded())
        }
    }
}
