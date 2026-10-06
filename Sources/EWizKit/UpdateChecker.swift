import Foundation

/// An available newer release, parsed from the update feed.
public struct AppUpdate: Sendable, Equatable {
    public let version: String
    public let url: URL          // DMG download
    public let notes: String
    /// The DMG's SHA-256 and the release key's signature over it, when the release was
    /// signed. Together they let an ad-hoc build install the update itself; see
    /// `UpdateSignature`. Absent from feeds written before signing existed.
    public let sha256: String?
    public let signature: String?
    public init(version: String, url: URL, notes: String,
                sha256: String? = nil, signature: String? = nil) {
        self.version = version
        self.url = url
        self.notes = notes
        self.sha256 = sha256
        self.signature = signature
    }

    /// Whether this release can be checked without a Developer ID.
    public var isSigned: Bool { sha256 != nil && signature != nil }
}

/// Checks a public JSON "appcast" for a newer version. The feed looks like:
///   { "version": "0.2.0",
///     "url": "https://…/eWiz-0.2.0.dmg",
///     "notes": "What's new…" }
public enum UpdateChecker {

    public static func check(feedURL: URL, currentVersion: String) async throws -> AppUpdate? {
        var req = URLRequest(url: feedURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, _) = try await URLSession.shared.data(for: req)

        let feed = try decode(data)
        guard isNewer(feed.version, than: currentVersion) else { return nil }
        return feed
    }

    /// The feed's contents. Unknown fields are ignored, so a feed can grow without breaking
    /// the copies already installed.
    public static func decode(_ data: Data) throws -> AppUpdate {
        struct Feed: Decodable {
            let version: String; let url: URL; let notes: String?
            let sha256: String?; let signature: String?
        }
        let feed = try JSONDecoder().decode(Feed.self, from: data)
        return AppUpdate(version: feed.version, url: feed.url, notes: feed.notes ?? "",
                         sha256: feed.sha256, signature: feed.signature)
    }

    /// Numeric semver comparison: "0.2.0" > "0.1.9". Non-numeric parts are ignored.
    public static func isNewer(_ remote: String, than current: String) -> Bool {
        let r = parts(remote), c = parts(current)
        for i in 0..<max(r.count, c.count) {
            let a = i < r.count ? r[i] : 0
            let b = i < c.count ? c[i] : 0
            if a != b { return a > b }
        }
        return false
    }

    private static func parts(_ v: String) -> [Int] {
        v.split(whereSeparator: { $0 == "." || $0 == "-" })
            .map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
