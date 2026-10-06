import Foundation
import CryptoKit
import EWizKit

// Seller-side tool: generate the signing keypair and mint license tokens.
// NOT shipped in the app bundle. The private key must stay secret.
//
//   licensetool genkey
//   licensetool sign --priv <base64> --email a@b.com --device XXXX-XXXX-XXXX [--name "A B"] [--days 365]

let args = Array(CommandLine.arguments.dropFirst())

func value(_ flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

switch args.first {
case "genkey":
    let priv = Curve25519.Signing.PrivateKey()
    print("PRIVATE KEY (keep secret, give to your license server):")
    print("  " + priv.rawRepresentation.base64EncodedString())
    print("PUBLIC KEY (paste into License.publicKeyBase64 in the app):")
    print("  " + priv.publicKey.rawRepresentation.base64EncodedString())

case "sign":
    guard let priv = value("--priv"),
          let email = value("--email"),
          let deviceRaw = value("--device") else {
        FileHandle.standardError.write(Data(
            "usage: licensetool sign --priv <base64> --email <e> --device <code> [--name <n>] [--days <n>]\n".utf8))
        exit(64)
    }
    let name = value("--name") ?? ""
    var expires: Date? = nil
    if let days = value("--days").flatMap({ Int($0) }) {
        expires = Date().addingTimeInterval(Double(days) * 86_400)
    }
    // The app rejects unbound licenses, so minting one would only create support load.
    let device = DeviceIdentity.normalize(deviceRaw)
    guard device.count == 12 else {
        FileHandle.standardError.write(Data(
            "error: --device must be a 12-hex-digit code like 7F3A-92C1-D04B\n".utf8))
        exit(64)
    }
    let info = LicenseInfo(email: email, name: name, issuedAt: Date(),
                           expiresAt: expires, product: License.product,
                           deviceID: device)
    do {
        let token = try License.sign(info, privateKeyBase64: priv)
        print(token)
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(1)
    }

case "sign-update":
    // Release tooling: sign a DMG for the update feed. The key comes from
    // UPDATE_SIGNING_PRIVATE_KEY, so it never sits on a command line or in a log.
    guard let path = value("--file"),
          let priv = ProcessInfo.processInfo.environment["UPDATE_SIGNING_PRIVATE_KEY"], !priv.isEmpty else {
        FileHandle.standardError.write(Data(
            "usage: UPDATE_SIGNING_PRIVATE_KEY=<b64> licensetool sign-update --file <dmg>\n".utf8))
        exit(64)
    }
    do {
        let signed = try UpdateSignature.sign(fileAt: URL(fileURLWithPath: path), privateKeyBase64: priv)
        // Checked against the key the app ships with before it's printed, so a release
        // signed with the wrong key fails here rather than on every user's Mac.
        try UpdateSignature.verify(fileAt: URL(fileURLWithPath: path), sha256: signed.sha256,
                                   signature: signed.signature)
        print("\(signed.sha256) \(signed.signature)")
    } catch {
        FileHandle.standardError.write(Data("error: \(error) (is this the key matching UpdateSignature.publicKeyBase64?)\n".utf8))
        exit(1)
    }

case "device":
    if let code = DeviceIdentity.deviceCode() {
        print(code)
    } else {
        FileHandle.standardError.write(Data("error: could not read this Mac's hardware UUID\n".utf8))
        exit(1)
    }

case "verify":
    guard let token = value("--token") else {
        FileHandle.standardError.write(Data("usage: licensetool verify --token <token>\n".utf8))
        exit(64)
    }
    // Verify against the app's public key (or --pub); pass --device to also check the binding.
    do {
        let info = try License.verify(token, deviceID: value("--device"),
                                      publicKeyBase64: value("--pub") ?? License.publicKeyBase64)
        print("VALID: \(info.name.isEmpty ? info.email : "\(info.name) <\(info.email)>")")
        print("  issued:  \(info.issuedAt)")
        print("  expires: \(info.expiresAt.map { "\($0)" } ?? "never")")
        print("  device:  \(info.deviceID ?? "?")")
    } catch {
        print("INVALID: \(error)")
        exit(1)
    }

default:
    print("""
    licensetool — eWiz license keys

      genkey                              Generate an Ed25519 keypair
      sign-update --file <dmg>            Sign a release DMG for the update feed
                                          (key in UPDATE_SIGNING_PRIVATE_KEY)
      sign --priv <b64> --email <e>       Mint a license token bound to one Mac
           --device <code>                (device code shown in the app's license window)
           [--name <n>] [--days <n>]      (omit --days for a perpetual license)
      verify --token <token>              Verify a token against the app's public key
             [--device <code>] [--pub <b64>]   Also check the device binding / other key
      device                              Print this Mac's device code
    """)
}
