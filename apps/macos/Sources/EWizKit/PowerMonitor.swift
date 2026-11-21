import Foundation
import IOKit

/// Identity and capability of the connected power adapter, read from the
/// `AdapterDetails` dictionary the battery firmware publishes. Everything is
/// optional — third-party and older adapters report wildly different subsets.
public struct AdapterInfo: Equatable, Sendable {
    /// Marketing name, e.g. "96W USB-C Power Adapter" (Apple adapters only).
    public var name: String?
    public var manufacturer: String?
    public var model: String?
    public var serial: String?
    /// Wattage the Mac negotiated with the adapter.
    public var watts: Int?
    /// Negotiated supply voltage / current limit.
    public var voltageMv: Int?
    public var currentMa: Int?
    public var isWireless: Bool = false
    /// Best wattage the adapter advertises across its USB-PD profiles. When this
    /// is higher than `watts`, something between the two — usually the cable or
    /// the port — is capping the negotiated power.
    public var maxAvailableWatts: Int?

    /// Whether the adapter reported anything worth showing.
    public var hasDetail: Bool {
        watts != nil || name != nil || manufacturer != nil || model != nil
    }

    /// The adapter can supply meaningfully more than was negotiated (>5 W of
    /// headroom, to ignore rounding and profile granularity).
    public var isUnderNegotiated: Bool {
        guard let w = watts, let m = maxAvailableWatts else { return false }
        return m > w + 5
    }
}

/// A snapshot of live power flow, in watts.
///
///   adapter ──▶ [ system ]
///           └─▶ [ battery ]   (or battery ──▶ system when unplugged)
///
/// `batteryWatts` is signed: positive = power flowing *into* the battery
/// (charging), negative = flowing *out* (discharging). `systemWatts` is the
/// estimated draw of everything else (SoC, display, peripherals).
public struct PowerFlow: Equatable, Sendable {
    /// Power the adapter is delivering right now (nil when unplugged / unknown). Measured
    /// where the firmware publishes it; otherwise the negotiated rating, which is the most
    /// the adapter could deliver rather than what it is.
    public var adapterWatts: Double?
    /// What the adapter negotiated: its ceiling, not its output ("68 W" on a 70 W brick).
    public var adapterRatedWatts: Double?
    /// Whether the numbers are the firmware's measurements (`PowerTelemetryData`) rather
    /// than derived from the rating.
    public var isMeasured = false
    /// Signed battery power: + charging, − discharging.
    public var batteryWatts: Double
    /// Estimated system consumption (nil if it can't be derived).
    public var systemWatts: Double?
    /// Human label for the adapter, e.g. "96W" (nil when unplugged/unknown).
    public var adapterDescription: String?
    /// Identity/capability of the connected adapter (nil when unplugged or when
    /// the firmware reports nothing useful).
    public var adapter: AdapterInfo?
    public var isPluggedIn: Bool

    public static let unknown = PowerFlow(
        adapterWatts: nil, adapterRatedWatts: nil, batteryWatts: 0, systemWatts: nil,
        adapterDescription: nil, adapter: nil, isPluggedIn: false)

    /// Battery power going *into* the pack (0 when discharging).
    public var chargeWatts: Double { max(0, batteryWatts) }
    /// Battery power coming *out* of the pack (0 when charging).
    public var dischargeWatts: Double { max(0, -batteryWatts) }
}

/// Reads instantaneous power flow from the `AppleSmartBattery` IORegistry entry.
/// Read-only — needs no root, so the GUI can poll it directly.
public enum PowerMonitor {

    public static func read() -> PowerFlow {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return .unknown }
        defer { IOObjectRelease(service) }

        var propsRef: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &propsRef, kCFAllocatorDefault, 0)
            == KERN_SUCCESS,
              let props = propsRef?.takeRetainedValue() as? [String: Any]
        else { return .unknown }
        return flow(from: props)
    }

    /// The flow from an `AppleSmartBattery` property dictionary. Split out so it can be
    /// tested against captured dictionaries.
    static func flow(from props: [String: Any]) -> PowerFlow {
        var flow = PowerFlow.unknown
        flow.isPluggedIn = (props["ExternalConnected"] as? Bool) ?? false

        // Battery instantaneous power: V (mV) × A (mA, signed) → W.
        let voltage = Double((props["Voltage"] as? Int) ?? 0) / 1000.0        // volts
        let amperageRaw = (props["InstantAmperage"] as? Int)
            ?? (props["Amperage"] as? Int) ?? 0
        // Amperage is signed but packed as unsigned in some firmwares (see signedMilliamps).
        let amperage = Double(signedMilliamps(amperageRaw)) / 1000.0          // amps
        flow.batteryWatts = (voltage * amperage)

        if let adapter = props["AdapterDetails"] as? [String: Any] {
            if let w = adapter["Watts"] as? Int, w > 0 {
                flow.adapterRatedWatts = Double(w)
                flow.adapterDescription = "\(w)W"
            } else if let mv = adapter["AdapterVoltage"] as? Int,
                      let ma = adapter["Current"] as? Int, mv > 0, ma > 0 {
                let w = Double(mv) / 1000.0 * Double(ma) / 1000.0
                flow.adapterRatedWatts = w
                flow.adapterDescription = "\(Int(w.rounded()))W"
            }
            flow.adapterWatts = flow.adapterRatedWatts
            if flow.adapterDescription == nil,
               let name = adapter["Name"] as? String, !name.isEmpty {
                flow.adapterDescription = name
            }
            let info = adapterInfo(from: adapter, negotiatedWatts: flow.adapterRatedWatts)
            flow.adapter = info.hasDetail ? info : nil
        }

        // On the charger, the firmware's own measurements where it publishes them (Apple
        // silicon): power in at the port and what the Mac is using, in mW. The battery is
        // the difference, so the three always add up.
        //
        // The fallback below subtracts the battery from the adapter's *rating*. The rating
        // is a ceiling, so every watt the adapter wasn't delivering was booked to the
        // system: a Mac idling on a held battery showed "System draw 68.0 W" on a 70 W
        // brick, and "Adapter in" read 68.0 W whatever was actually coming in. On battery
        // the fallback is already exact (the system is what the battery gives out), so the
        // telemetry is only used where it corrects something.
        if flow.isPluggedIn,
           let t = props["PowerTelemetryData"] as? [String: Any],
           let load = t["SystemLoad"] as? Int, load > 0,
           let powerIn = t["SystemPowerIn"] as? Int, powerIn >= 0 {
            let system = Double(load) / 1000.0
            let adapterIn = Double(powerIn) / 1000.0
            flow.isMeasured = true
            flow.systemWatts = system
            flow.adapterWatts = adapterIn
            flow.batteryWatts = adapterIn - system
            return flow
        }

        // System draw = adapter − batteryWatts (what the adapter delivers minus what
        // charges the battery). Unplugged: system = |dischargeWatts|.
        if let adapterW = flow.adapterWatts {
            flow.systemWatts = max(0, adapterW - flow.batteryWatts)
        } else if !flow.isPluggedIn {
            flow.systemWatts = flow.dischargeWatts
        }

        return flow
    }

    /// Pull the adapter's identity out of `AdapterDetails`. Keys vary by adapter
    /// and firmware, so every field is best-effort.
    private static func adapterInfo(from d: [String: Any],
                                    negotiatedWatts: Double?) -> AdapterInfo {
        var info = AdapterInfo(isWireless: (d["IsWireless"] as? Bool) ?? false)

        info.name = nonEmpty(d["Name"] as? String)
        info.manufacturer = nonEmpty(d["Manufacturer"] as? String)
        info.serial = nonEmpty(d["SerialString"] as? String)
        // Model can arrive as a string or as a numeric ID; render the number as
        // hex, which is how Apple's own tooling shows it.
        if let m = nonEmpty(d["Model"] as? String) {
            info.model = m
        } else if let m = d["Model"] as? Int, m != 0 {
            info.model = String(format: "0x%04X", m)
        }

        if let w = d["Watts"] as? Int, w > 0 {
            info.watts = w
        } else if let w = negotiatedWatts, w > 0 {
            info.watts = Int(w.rounded())
        }
        if let mv = d["AdapterVoltage"] as? Int, mv > 0 { info.voltageMv = mv }
        if let ma = d["Current"] as? Int, ma > 0 { info.currentMa = ma }

        // USB-PD adapters advertise their supported profiles; the best one is the
        // ceiling this adapter could deliver over an unrestricted cable.
        if let menu = d["UsbHvcMenu"] as? [[String: Any]] {
            let best = menu.compactMap { profile -> Int? in
                guard let mv = profile["MaxVoltage"] as? Int,
                      let ma = profile["MaxCurrent"] as? Int, mv > 0, ma > 0
                else { return nil }
                return Int((Double(mv) * Double(ma) / 1_000_000).rounded())
            }.max()
            if let best, best > 0 { info.maxAvailableWatts = best }
        }

        return info
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return s
    }

    /// Interpret raw amperage as signed milliamps: IOKit sometimes returns a negative
    /// as a large unsigned (two's-complement), so fold values above 32-bit range back.
    private static func signedMilliamps(_ raw: Int) -> Int {
        if raw > Int(Int32.max) { return raw - (1 << 32) }
        return raw
    }
}
