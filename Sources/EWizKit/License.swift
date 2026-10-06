import Foundation
import CryptoKit

/// Decoded contents of a license. Mirrors the payload the seller signs.
public struct LicenseInfo: Codable, Sendable, Equatable {
    public var email: String
    public var name: String
    public var issuedAt: Date
    public var expiresAt: Date?   // nil = perpetual
    public var product: String
    /// Device code the license is bound to. Required — `verify()` rejects unbound
    /// tokens (.missingDevice), so pre-device-locking keys must be re-issued.
    public var deviceID: String?

    enum CodingKeys: String, CodingKey {
        case email = "e", name = "n", issuedAt = "iat", expiresAt = "exp",
             product = "p", deviceID = "d"
    }

    public init(email: String, name: String, issuedAt: Date,
                expiresAt: Date?, product: String, deviceID: String? = nil) {
        self.email = email
        self.name = name
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.product = product
        self.deviceID = deviceID
    }
}

public enum LicenseError: Error, CustomStringConvertible {
    case malformed
    case badSignature
    case wrongProduct
    case expired
    case wrongDevice
    case missingDevice

    public var description: String {
        switch self {
        case .malformed: return "That license key isn't valid."
        case .badSignature: return "This license key couldn't be verified."
        case .wrongProduct: return "This key is for a different product."
        case .expired: return "This license has expired."
        case .wrongDevice: return "This license is registered to a different Mac."
        case .missingDevice:
            return "This key isn't linked to a Mac. Sign in at ewiz.app to get an updated key for this one."
        }
    }
}

/// Offline license verification with Ed25519: the seller signs tokens with the private
/// key, the app embeds only the public key and verifies locally — no phone-home.
///
/// Token format:  base64url(payloadJSON) "." base64url(signature)
public enum License {
    /// The app's name when the first keys were sold, and part of every key's signed
    /// payload. Not renamed with the app: changing it would void every key out there.
    public static let product = "battlify"

    /// Embedded Ed25519 public key (base64, 32 bytes). The private key lives on the
    /// license server as LICENSE_SIGNING_PRIVATE_KEY.
    public static let publicKeyBase64 = "+H12xfer/QAvW5xSQhB0L2rehNFuwm3SpwW3r66Bujc="

    /// Every license must carry a device binding — unbound tokens are rejected.
    /// - Parameter deviceID: this machine's code, matched against the license. Pass
    ///   nil only from seller-side tooling (skips the match, not the binding check).
    public static func verify(_ token: String,
                              now: Date = Date(),
                              deviceID: String? = nil,
                              publicKeyBase64: String = publicKeyBase64) throws -> LicenseInfo {
        let parts = token.split(separator: ".")
        guard parts.count == 2,
              let payload = base64urlDecode(String(parts[0])),
              let signature = base64urlDecode(String(parts[1])),
              let pubData = Data(base64Encoded: publicKeyBase64),
              let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData)
        else { throw LicenseError.malformed }

        guard pub.isValidSignature(signature, for: payload) else {
            throw LicenseError.badSignature
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard let info = try? decoder.decode(LicenseInfo.self, from: payload) else {
            throw LicenseError.malformed
        }
        guard info.product == product else { throw LicenseError.wrongProduct }
        if let exp = info.expiresAt, exp < now { throw LicenseError.expired }
        guard let bound = info.deviceID else { throw LicenseError.missingDevice }
        if let mine = deviceID {
            guard DeviceIdentity.normalize(bound) == DeviceIdentity.normalize(mine) else {
                throw LicenseError.wrongDevice
            }
        }
        return info
    }

    /// Sign a license. Used by the seller's key-minting tool — needs the private key.
    public static func sign(_ info: LicenseInfo, privateKeyBase64: String) throws -> String {
        guard let privData = Data(base64Encoded: privateKeyBase64),
              let priv = try? Curve25519.Signing.PrivateKey(rawRepresentation: privData)
        else { throw LicenseError.malformed }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(info)
        let signature = try priv.signature(for: payload)
        return base64urlEncode(payload) + "." + base64urlEncode(signature)
    }

    // MARK: - base64url

    static func base64urlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64urlDecode(_ s: String) -> Data? {
        var b = s.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        return Data(base64Encoded: b)
    }
}
