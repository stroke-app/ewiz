import Foundation
import CSMC

/// A temperature sensor and its current reading.
public struct SensorReading: Codable, Sendable, Equatable, Identifiable {
    /// The raw SMC key, e.g. "Tp09".
    public let key: String
    /// A readable name where one is known, otherwise the key itself.
    public let name: String
    /// Degrees Celsius.
    public let celsius: Double

    public var id: String { key }
}

/// Discovers and reads the machine's temperature sensors.
///
/// Sensor keys differ by model — an M3 Pro publishes a different set from an M1 Air or any
/// Intel Mac — so the list is discovered by walking the SMC's own key table (`#KEY` plus
/// index lookups) rather than hardcoded. A fixed list is wrong on every Mac it wasn't
/// written for, which is the failure mode every "why does this show no sensors" bug report
/// about tools like this comes down to.
public enum SensorReader {

    /// Every temperature sensor the SMC publishes, warmest first.
    ///
    /// Keys beginning with `T` and typed `flt`/`sp78` are temperatures by SMC convention.
    /// Readings outside −20…150 °C are dropped: the table includes keys that are present but
    /// unpopulated on a given machine, and they come back as 0 or garbage rather than absent.
    public static func readAll(limit: Int = 40) -> [SensorReading] {
        let keys = temperatureKeys()
        var readings: [SensorReading] = []
        readings.reserveCapacity(keys.count)
        for key in keys {
            guard let celsius = temperature(of: key), celsius > -20, celsius < 150 else { continue }
            readings.append(SensorReading(key: key, name: friendlyName(for: key), celsius: celsius))
        }
        return Array(readings.sorted { $0.celsius > $1.celsius }.prefix(limit))
    }

    /// The hottest sensor, which is the one number a summary should show.
    public static func hottest() -> SensorReading? { readAll(limit: 1).first }

    // MARK: - Discovery

    /// Cached: the key table doesn't change while the machine is running, and walking a few
    /// hundred keys per refresh would be pointless work in an app that polls.
    nonisolated(unsafe) private static var cachedKeys: [String]?
    private static let cacheLock = NSLock()

    public static func temperatureKeys() -> [String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cachedKeys { return cachedKeys }

        let count = csmc_key_count()
        var found: [String] = []
        var buffer = [CChar](repeating: 0, count: 5)
        for index in 0..<count {
            guard csmc_key_at_index(index, &buffer) == 0 else { continue }
            let key = String(cString: buffer)
            guard key.hasPrefix("T"), key.count == 4 else { continue }
            found.append(key)
        }
        cachedKeys = found
        return found
    }

    private static func temperature(of key: String) -> Double? {
        var value = CSMCVal()
        guard csmc_read(key, &value) == 0 else { return nil }
        let type = withUnsafeBytes(of: value.dataType) { raw in
            String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
        }
        let bytes = withUnsafeBytes(of: value.bytes) { Array($0.prefix(Int(value.dataSize))) }

        switch type.trimmingCharacters(in: .whitespaces) {
        case "flt":
            guard bytes.count >= 4 else { return nil }
            return Double(bytes.prefix(4).withUnsafeBytes { $0.loadUnaligned(as: Float32.self) })
        case "sp78":
            // Signed fixed point, 7 integer bits and 8 fractional — the Intel-era encoding.
            guard bytes.count >= 2 else { return nil }
            return Double(Int8(bitPattern: bytes[0])) + Double(bytes[1]) / 256
        default:
            return nil
        }
    }

    // MARK: - Naming

    /// Readable names for the keys worth naming. Anything unnamed shows its key, which is
    /// more useful than inventing a label: the key is what every other tool and forum thread
    /// calls it.
    private static func friendlyName(for key: String) -> String {
        if let known = names[key] { return known }
        // Apple silicon publishes per-core keys in families: Tp0x/Tp1x are performance and
        // efficiency cores, Tg0x the GPU cluster.
        if key.hasPrefix("Tp") { return "CPU core \(key.suffix(2))" }
        if key.hasPrefix("Tg") { return "GPU \(key.suffix(2))" }
        if key.hasPrefix("Te") { return "SoC \(key.suffix(2))" }
        if key.hasPrefix("Ts") { return "Enclosure \(key.suffix(2))" }
        return key
    }

    private static let names: [String: String] = [
        "TB0T": "Battery",
        "TB1T": "Battery 2",
        "TB2T": "Battery 3",
        "TC0P": "CPU proximity",
        "TC0D": "CPU die",
        "TG0P": "GPU proximity",
        "TG0D": "GPU die",
        "Ts0P": "Palm rest",
        "Ts1P": "Palm rest 2",
        "TA0P": "Airflow",
        "TW0P": "Wi-Fi",
        "TH0P": "Drive",
        "TM0P": "Memory",
        "TPMP": "Power management",
    ]
}
