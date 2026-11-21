import CryptoKit
import Foundation

/// Ed25519 signatures over release disk images, in the two forms the feeds carry.
///
/// Sparkle installs updates now, and what it checks is `sparkle:edSignature` in
/// appcast.xml: the release key's Ed25519 signature over the DMG's bytes, checked against
/// `SUPublicEDKey` in Info.plist (`publicKeyBase64` below). That is the only thing standing
/// between the feed and the running app, because an ad-hoc build has no Developer ID for
/// Sparkle to match. `sparkleSignature(fileAt:)` produces it with the same key Sparkle's
/// own `sign_update` would take (a 32-byte Ed25519 seed, base64) over the same input, so
/// the release job needs no extra binary. The bytes differ from `sign_update`'s — CryptoKit
/// randomizes Ed25519 signatures, Sparkle's implementation is deterministic — and each
/// verifies under the other's public key; that was checked both ways against the
/// `sign_update` in Sparkle 2.10.0 before this shipped.
///
/// Before Sparkle, the app's own updater read appcast.json, whose `signature` is the same
/// key's signature over the DMG's SHA-256 *as a hex string*, not over the bytes. Copies up
/// to 0.18.5 still poll that feed, and they can only reach a Sparkle build through it, so
/// `sign(fileAt:)`/`verify(fileAt:)` stay and CI keeps publishing both feeds.
public enum UpdateSignature {
    /// Public half of the release signing key, and the app's `SUPublicEDKey`. The private
    /// half is the `UPDATE_SIGNING_PRIVATE_KEY` repo secret, the base64 of the 32-byte seed
    /// (a copy sits in the maintainer's Keychain as "eWiz update signing key"). Sparkle only
    /// supports rotating this key, never dropping it, and a rotated key has to sign the
    /// release that introduces it with the old key too.
    public static let publicKeyBase64 = "cDHo+nn97ixS/aCGAdfFWXfdCMd/oc3EO3CCUonSVgc="

    public enum Failure: Error, Equatable {
        case unreadable
        case digestMismatch
        case badSignature
    }

    /// The file's SHA-256, lowercase hex. Read in chunks, so a large image isn't loaded whole.
    public static func sha256(fileAt url: URL) throws -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { throw Failure.unreadable }
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The digest and its signature for the feed. Release tooling only: needs the private key.
    public static func sign(fileAt url: URL, privateKeyBase64: String) throws -> (sha256: String, signature: String) {
        guard let raw = Data(base64Encoded: privateKeyBase64),
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
            throw Failure.badSignature
        }
        let digest = try sha256(fileAt: url)
        let signature = try key.signature(for: Data(digest.utf8))
        return (digest, signature.base64EncodedString())
    }

    /// Throws unless the file hashes to `sha256` and `signature` is the release key's
    /// signature over that digest.
    public static func verify(fileAt url: URL, sha256 expected: String, signature: String,
                              publicKeyBase64: String = publicKeyBase64) throws {
        guard try sha256(fileAt: url) == expected.lowercased() else { throw Failure.digestMismatch }
        guard let raw = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw),
              let sig = Data(base64Encoded: signature),
              key.isValidSignature(sig, for: Data(expected.lowercased().utf8)) else {
            throw Failure.badSignature
        }
    }

    // MARK: - Sparkle (appcast.xml)

    /// What Sparkle's `sign_update` prints: the Ed25519 signature over the file's bytes,
    /// base64, and the file's length, for the enclosure's `sparkle:edSignature` and
    /// `length`. The whole image is read into memory, as `sign_update` does; release
    /// tooling only.
    public static func sparkleSignature(fileAt url: URL, privateKeyBase64: String) throws
        -> (edSignature: String, length: Int)
    {
        guard let raw = Data(base64Encoded: privateKeyBase64),
              let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
            throw Failure.badSignature
        }
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable }
        return (try key.signature(for: data).base64EncodedString(), data.count)
    }

    /// Checks a `sparkle:edSignature` the way Sparkle will: against the file's bytes and
    /// `SUPublicEDKey`.
    public static func verifySparkleSignature(fileAt url: URL, edSignature: String,
                                              publicKeyBase64: String = publicKeyBase64) throws {
        guard let data = try? Data(contentsOf: url) else { throw Failure.unreadable }
        guard let raw = Data(base64Encoded: publicKeyBase64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw),
              let sig = Data(base64Encoded: edSignature),
              key.isValidSignature(sig, for: data) else {
            throw Failure.badSignature
        }
    }
}
