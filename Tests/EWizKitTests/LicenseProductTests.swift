import CryptoKit
import Foundation
import Testing
@testable import EWizKit

@Suite("License products across the rename")
struct LicenseProductTests {
    private let key = Curve25519.Signing.PrivateKey()

    private func token(product: String) throws -> String {
        let info = LicenseInfo(email: "a@b.com", name: "A", issuedAt: Date(timeIntervalSince1970: 1_700_000_000),
                               expiresAt: nil, product: product, deviceID: "ABCD-1234-EF56")
        return try License.sign(info, privateKeyBase64: key.rawRepresentation.base64EncodedString())
    }

    private func verify(_ token: String) throws -> LicenseInfo {
        try License.verify(token, deviceID: "abcd-1234-ef56",
                           publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString())
    }

    /// Every key sold before the rename names `battlify`; they have to keep working.
    @Test("Keys minted as battlify still verify")
    func legacyProduct() throws {
        #expect(try verify(token(product: "battlify")).product == "battlify")
    }

    @Test("Keys minted as ewiz verify")
    func newProduct() throws {
        #expect(try verify(token(product: "ewiz")).product == "ewiz")
    }

    @Test("Any other product is refused")
    func otherProduct() throws {
        #expect(throws: LicenseError.self) { try verify(token(product: "other-app")) }
    }
}
