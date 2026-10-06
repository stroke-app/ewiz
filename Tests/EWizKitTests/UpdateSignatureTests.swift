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

    @Test("Feeds with and without a signature both decode")
    func feedDecoding() throws {
        let signed = try UpdateChecker.decode(Data(#"{"version":"0.18.3","url":"https://x/eWiz-0.18.3.dmg","notes":"n","sha256":"ab","signature":"cd"}"#.utf8))
        #expect(signed.isSigned)
        let bare = try UpdateChecker.decode(Data(#"{"version":"0.18.2","url":"https://x/eWiz-0.18.2.dmg","notes":"n"}"#.utf8))
        #expect(!bare.isSigned)
    }
}
