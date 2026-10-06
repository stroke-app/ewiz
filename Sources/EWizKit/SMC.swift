import Foundation
import CSMC

public struct SMCValue: Sendable {
    public let key: String
    public let dataType: String
    public let bytes: [UInt8]
}

public enum SMCError: Error, CustomStringConvertible {
    case openFailed
    case readFailed(String)
    case writeFailed(String)

    public var description: String {
        switch self {
        case .openFailed: return "Could not open AppleSMC connection"
        case .readFailed(let k): return "Failed to read SMC key \(k)"
        case .writeFailed(let k): return "Failed to write SMC key \(k) (need root?)"
        }
    }
}

/// Thin Swift wrapper over the C SMC layer. Writing requires the process to run
/// as root; reading generally does not.
public final class SMC {
    public init() {}

    public func open() throws {
        if csmc_open() != 0 { throw SMCError.openFailed }
    }

    public func close() {
        csmc_close()
    }

    public func keyExists(_ key: String) -> Bool {
        csmc_key_exists(key)
    }

    public func read(_ key: String) throws -> SMCValue {
        var v = CSMCVal()
        guard csmc_read(key, &v) == 0 else { throw SMCError.readFailed(key) }
        let size = Int(v.dataSize)
        let bytes = withUnsafeBytes(of: v.bytes) { Array($0.prefix(min(size, 32))) }
        let dataType = withUnsafeBytes(of: v.dataType) { raw -> String in
            let bytes = raw.prefix(4).prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        return SMCValue(key: key, dataType: dataType, bytes: bytes)
    }

    public func write(_ key: String, _ bytes: [UInt8]) throws {
        let ok = bytes.withUnsafeBufferPointer { buf in
            csmc_write(key, buf.baseAddress, UInt32(buf.count)) == 0
        }
        if !ok { throw SMCError.writeFailed(key) }
    }
}
