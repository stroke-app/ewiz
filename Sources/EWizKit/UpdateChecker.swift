import Foundation

/// An available newer release, parsed from the update feed.
public struct AppUpdate: Sendable, Equatable {
    public let version: String
    public let url: URL          // DMG download
    public let notes: String
    public init(version: String, url: URL, notes: String) {
        self.version = version
        self.url = url
        self.notes = notes
    }
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

        struct Feed: Decodable { let version: String; let url: URL; let notes: String? }
        let feed = try JSONDecoder().decode(Feed.self, from: data)

        guard isNewer(feed.version, than: currentVersion) else { return nil }
        return AppUpdate(version: feed.version, url: feed.url, notes: feed.notes ?? "")
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
