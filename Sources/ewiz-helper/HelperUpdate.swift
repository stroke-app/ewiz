import Foundation
import MachO
import Security
import CryptoKit

/// Replacing the root helper's own binary at the request of an unprivileged client.
///
/// This exists so a helper installed the legacy way — `/usr/local/bin` plus a LaunchDaemon —
/// can pick up a new build without an administrator prompt every single time. It is also,
/// plainly, the most dangerous thing this daemon can be asked to do: *become this binary*,
/// asked by something that isn't root. Three things have to hold before it will:
///
///   - the connection already passed the peer check in `ControlServer` (root, or the user
///     logged in at the screen);
///   - the running daemon is signed with a certificate, so there is a real identity to
///     compare against — an ad-hoc or unsigned daemon refuses outright, because a signature
///     check with nothing to check against is decoration, and dev builds have the admin
///     installer already;
///   - the candidate binary satisfies a requirement naming that identity, evaluated by the
///     Security framework against the file on disk rather than anything the caller said
///     about it. A Developer ID build names *our own team* under Apple's anchor; a
///     self-signed build pins *the exact certificate* this daemon was signed with, which
///     nobody without its private key can sign as.
///
/// The last one is the whole point. A path from a client is a claim, not evidence.
enum HelperUpdate {
    enum Failure: Error, CustomStringConvertible {
        case notSigned
        case unreadable(String)
        case rejected(String)
        case replaceFailed(String)

        var description: String {
            switch self {
            case .notSigned:
                return "this helper is not signed with a certificate, so it cannot verify a replacement; reinstall with the installer instead"
            case .unreadable(let path):
                return "cannot read a replacement helper at \(path)"
            case .rejected(let why):
                return "replacement rejected: \(why)"
            case .replaceFailed(let why):
                return "could not replace the helper: \(why)"
            }
        }
    }

    /// Verify `path` really is a newer copy of us, then put it in our place.
    ///
    /// Returns once the binary on disk is the new one. The caller is expected to exit so
    /// launchd starts the replacement — a running process keeps its original inode, so this
    /// does not affect the daemon until it restarts.
    static func apply(replacementAt path: String) throws {
        guard let identity = runningIdentity() else { throw Failure.notSigned }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue else { throw Failure.unreadable(path) }

        try verify(path: path, against: identity)
        try replaceSelf(with: path)
    }

    // MARK: - Trust

    /// Who a replacement has to be signed by.
    enum Identity: Equatable {
        /// Developer ID: any build from this team, so a renewed certificate still passes.
        case team(String)
        /// Self-signed: the same signing identifier under the very certificate (SHA-1 of
        /// its DER, the form code requirements take) that signed the running daemon.
        case certificate(identifier: String, sha1: String)

        /// The code requirement a candidate must satisfy.
        ///
        /// `anchor apple generic` pins the team case to Apple's Developer ID root, so a
        /// self-signed certificate claiming the same OU doesn't pass — without it anyone
        /// could mint a leaf with the right subject. The certificate case needs no anchor:
        /// a hash of the whole certificate can't be matched by minting another one.
        var requirement: String {
            switch self {
            case .team(let team):
                return "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
            case .certificate(let identifier, let sha1):
                return "identifier \"\(identifier)\" and certificate leaf = H\"\(sha1)\""
            }
        }
    }

    /// The identity of the code currently running, or nil when ad-hoc/unsigned.
    private static func runningIdentity() -> Identity? {
        var me: SecCode?
        guard SecCodeCopySelf([], &me) == errSecSuccess, let me else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(me, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(
                staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return nil }
        return identity(fromSigningInfo: dict)
    }

    /// Split out from `runningIdentity` so the choice can be tested without signing a binary.
    static func identity(fromSigningInfo dict: [String: Any]) -> Identity? {
        if let team = dict[kSecCodeInfoTeamIdentifier as String] as? String, !team.isEmpty {
            return .team(team)
        }
        // Ad-hoc code has no certificate chain, and must stay refused.
        guard let identifier = dict[kSecCodeInfoIdentifier as String] as? String,
              let chain = dict[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = chain.first else { return nil }
        let der = SecCertificateCopyData(leaf) as Data
        let sha1 = Insecure.SHA1.hash(data: der).map { String(format: "%02x", $0) }.joined()
        return .certificate(identifier: identifier, sha1: sha1)
    }

    /// Full signature validation of the file on disk against `identity`.
    private static func verify(path: String, against identity: Identity) throws {
        var candidate: SecStaticCode?
        let url = URL(fileURLWithPath: path) as CFURL
        guard SecStaticCodeCreateWithPath(url, [], &candidate) == errSecSuccess,
              let candidate else { throw Failure.unreadable(path) }
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(identity.requirement as CFString, [], &requirement) == errSecSuccess,
              let requirement else {
            throw Failure.rejected("could not build a signing requirement")
        }
        var error: Unmanaged<CFError>?
        let status = SecStaticCodeCheckValidityWithErrors(
            candidate, SecCSFlags(rawValue: kSecCSCheckAllArchitectures), requirement, &error)
        guard status == errSecSuccess else {
            let detail = error?.takeRetainedValue().localizedDescription
                ?? "signature does not match \(identity.requirement)"
            throw Failure.rejected(detail)
        }
    }

    // MARK: - Replacement

    private static func replaceSelf(with path: String) throws {
        let destination = currentExecutablePath()
        let staging = destination + ".incoming"

        // Copy then rename, rather than writing over the destination. A rename is atomic
        // within a filesystem, so a crash or a full disk mid-copy leaves the old working
        // helper in place instead of a truncated root binary that launchd would keep
        // trying to execute.
        try? FileManager.default.removeItem(atPath: staging)
        do {
            try FileManager.default.copyItem(atPath: path, toPath: staging)
        } catch {
            throw Failure.replaceFailed("\(error)")
        }

        // The source lives inside an app bundle owned by the user who installed it; what
        // lands in our place has to be root-owned and non-writable by them, or the next
        // update could be swapped out from under the check that just passed.
        guard chown(staging, 0, 0) == 0, chmod(staging, 0o755) == 0 else {
            try? FileManager.default.removeItem(atPath: staging)
            throw Failure.replaceFailed("cannot set ownership on the replacement")
        }
        guard rename(staging, destination) == 0 else {
            try? FileManager.default.removeItem(atPath: staging)
            throw Failure.replaceFailed(String(cString: strerror(errno)))
        }
    }

    /// Where this process's own binary lives. `argv[0]` can be relative or a lie; the kernel's
    /// answer is neither.
    private static func currentExecutablePath() -> String {
        var size = UInt32(0)
        _ = _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size) + 1)
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { return CommandLine.arguments[0] }
        let path = String(cString: buffer)
        return URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }
}
