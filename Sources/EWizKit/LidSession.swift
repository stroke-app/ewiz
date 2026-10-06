import Foundation

/// A lid-closed period: charge at close, charge at open, and the drain in between.
public struct LidSession: Codable, Sendable, Equatable, Identifiable {
    public var closedAt: Date
    public var closeCharge: Int
    public var openedAt: Date
    public var openCharge: Int

    public var id: Date { closedAt }

    /// Percentage points lost while closed (never negative; charging shows 0).
    public var dropPercent: Int { max(0, closeCharge - openCharge) }
    public var duration: TimeInterval { max(0, openedAt.timeIntervalSince(closedAt)) }

    /// Average drain rate in %/hour while closed (nil if duration too small).
    public var dropPerHour: Double? {
        let hours = duration / 3600
        guard hours >= 0.05 else { return nil }
        return Double(dropPercent) / hours
    }

    public init(closedAt: Date, closeCharge: Int, openedAt: Date, openCharge: Int) {
        self.closedAt = closedAt
        self.closeCharge = closeCharge
        self.openedAt = openedAt
        self.openCharge = openCharge
    }
}

/// Append-only JSON-lines store of lid-closed sessions (user-writable location).
public enum LidSessionStore {
    public static var file: URL {
        EWizPaths.userConfigDirectory.appendingPathComponent("lid-sessions.jsonl")
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()

    public static func append(_ session: LidSession) {
        guard let data = try? encoder.encode(session) else { return }
        var line = data; line.append(0x0A)
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let h = try? FileHandle(forWritingTo: file) {
            defer { try? h.close() }
            _ = try? h.seekToEnd(); try? h.write(contentsOf: line)
        } else {
            try? line.write(to: file, options: .atomic)
        }
        trim()
    }

    /// Cap the file so it can't grow unbounded. Size-guarded so the common small-file
    /// case skips the full read/parse entirely.
    private static func trim(keep: Int = 2000) {
        guard let size = (try? FileManager.default.attributesOfItem(atPath: file.path)[.size]) as? Int,
              size > keep * 200 else { return }
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        guard lines.count > keep else { return }
        let kept = lines.suffix(keep).joined(separator: "\n") + "\n"
        try? Data(kept.utf8).write(to: file, options: .atomic)
    }

    /// Delete the lid-sessions file. Best-effort; a missing file is success.
    public static func clear() {
        try? FileManager.default.removeItem(at: file)
    }

    /// Most recent sessions, newest first.
    public static func recent(limit: Int = 50) -> [LidSession] {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        let all = text.split(separator: "\n").compactMap {
            $0.data(using: .utf8).flatMap { try? decoder.decode(LidSession.self, from: $0) }
        }
        return Array(all.suffix(limit).reversed())
    }
}
