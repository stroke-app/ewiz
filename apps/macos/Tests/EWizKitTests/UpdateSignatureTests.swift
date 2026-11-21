import CryptoKit
import Foundation
import Testing
@testable import EWizKit

@Suite("Signed updates")
struct UpdateSignatureTests {
    private let key = Curve25519.Signing.PrivateKey()
    private var priv: String { key.rawRepresentation.base64EncodedString() }
    private var pub: String { key.publicKey.rawRepresentation.base64EncodedString() }

    private func file(_ bytes: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ewiz-update-\(UUID().uuidString).dmg")
        try? Data(bytes.utf8).write(to: url)
        return url
    }

    @Test("A signed image verifies")
    func roundTrip() throws {
        let dmg = file("eWiz 0.18.3")
        let signed = try UpdateSignature.sign(fileAt: dmg, privateKeyBase64: priv)
        try UpdateSignature.verify(fileAt: dmg, sha256: signed.sha256, signature: signed.signature,
                                   publicKeyBase64: pub)
    }

    /// The download is what's checked, not the feed: a swapped file fails on its digest.
    @Test("A different file is refused")
    func tamperedFile() throws {
        let signed = try UpdateSignature.sign(fileAt: file("eWiz 0.18.3"), privateKeyBase64: priv)
        #expect(throws: UpdateSignature.Failure.digestMismatch) {
            try UpdateSignature.verify(fileAt: file("something else"), sha256: signed.sha256,
                                       signature: signed.signature, publicKeyBase64: pub)
        }
    }

    /// A feed that names a new file's digest still needs the release key to sign it.
    @Test("A digest signed with another key is refused")
    func otherKey() throws {
        let dmg = file("eWiz 0.18.3")
        let forged = try UpdateSignature.sign(fileAt: dmg,
                                              privateKeyBase64: Curve25519.Signing.PrivateKey().rawRepresentation.base64EncodedString())
        #expect(throws: UpdateSignature.Failure.badSignature) {
            try UpdateSignature.verify(fileAt: dmg, sha256: forged.sha256, signature: forged.signature,
                                       publicKeyBase64: pub)
        }
    }

    @Test("The shipped public key is a valid Ed25519 key")
    func shippedKey() throws {
        let raw = try #require(Data(base64Encoded: UpdateSignature.publicKeyBase64))
        _ = try Curve25519.Signing.PublicKey(rawRepresentation: raw)
    }

    // MARK: Sparkle

    /// `sparkle:edSignature` is Ed25519 over the file's bytes, which is what Sparkle checks
    /// against `SUPublicEDKey`: verify it the way Sparkle does, with nothing but the public
    /// key and the bytes.
    @Test("The Sparkle signature is Ed25519 over the file's bytes")
    func sparkleSignature() throws {
        let bytes = "eWiz 0.19.0"
        let dmg = file(bytes)
        let signed = try UpdateSignature.sparkleSignature(fileAt: dmg, privateKeyBase64: priv)
        #expect(signed.length == bytes.utf8.count)
        let sig = try #require(Data(base64Encoded: signed.edSignature))
        #expect(sig.count == 64)
        #expect(key.publicKey.isValidSignature(sig, for: Data(bytes.utf8)))
        try UpdateSignature.verifySparkleSignature(fileAt: dmg, edSignature: signed.edSignature,
                                                   publicKeyBase64: pub)
    }

    @Test("A Sparkle signature from another key, or over other bytes, is refused")
    func sparkleSignatureRefused() throws {
        let dmg = file("eWiz 0.19.0")
        let forged = try UpdateSignature.sparkleSignature(
            fileAt: dmg,
            privateKeyBase64: Curve25519.Signing.PrivateKey().rawRepresentation.base64EncodedString())
        #expect(throws: UpdateSignature.Failure.badSignature) {
            try UpdateSignature.verifySparkleSignature(fileAt: dmg, edSignature: forged.edSignature,
                                                       publicKeyBase64: pub)
        }
        let genuine = try UpdateSignature.sparkleSignature(fileAt: dmg, privateKeyBase64: priv)
        #expect(throws: UpdateSignature.Failure.badSignature) {
            try UpdateSignature.verifySparkleSignature(fileAt: file("something else"),
                                                       edSignature: genuine.edSignature,
                                                       publicKeyBase64: pub)
        }
    }

    /// The legacy feed signs the digest's hex, Sparkle signs the bytes: two different
    /// signatures from one key, and neither verifies as the other.
    @Test("The two feed signatures are distinct")
    func distinctSignatures() throws {
        let dmg = file("eWiz 0.19.0")
        let legacy = try UpdateSignature.sign(fileAt: dmg, privateKeyBase64: priv)
        let sparkle = try UpdateSignature.sparkleSignature(fileAt: dmg, privateKeyBase64: priv)
        #expect(legacy.signature != sparkle.edSignature)
        #expect(throws: UpdateSignature.Failure.badSignature) {
            try UpdateSignature.verifySparkleSignature(fileAt: dmg, edSignature: legacy.signature,
                                                       publicKeyBase64: pub)
        }
    }
}
