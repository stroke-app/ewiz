import CryptoKit
import Foundation

/// Ed25519 signatures over release disk images: how a build with no Apple Developer ID
/// still checks its own update before swapping it in.
///
/// The updater used to have one way to trust a download: the replacement had to carry the
/// same Developer ID team as the running app. eWiz is signed ad hoc, so there was no team,
/// and every update stopped at "won't replace itself automatically" and a browser
/// download. This is the Sparkle model instead: the release job signs the DMG's SHA-256
/// with a key only CI holds, the feed carries the digest and signature, and the app checks
/// both against the public key below before it touches the bundle.
public enum UpdateSignature {
    /// Public half of the release signing key. The private half is the
    /// `UPDATE_SIGNING_PRIVATE_KEY` repo secret (a copy sits in the maintainer's Keychain as
    /// "eWiz update signing key"). Replacing it means every installed copy from before the
    /// change stops trusting new releases until it's updated by hand once.
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
}
