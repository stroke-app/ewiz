import Foundation

/// One periodic battery measurement, stored as a line of JSON in history.jsonl.
public struct BatterySample: Codable, Sendable, Identifiable {
    public var t: Date
    public var pct: Int         // charge %
    public var charging: Bool
    public var temp: Double?    // °C

    public var id: Date { t }

    public init(t: Date, pct: Int, charging: Bool, temp: Double?) {
        self.t = t
        self.pct = pct
        self.charging = charging
        self.temp = temp
    }
}

/// Append-only JSON-lines history store: the daemon appends (runs as root under /Library), the GUI reads.
public enum HistoryStore {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Append one sample. Best-effort; failures are ignored (history is non-critical).
    public static func append(_ sample: BatterySample,
                              to url: URL = EWizPaths.historyFile) {
        guard let data = try? encoder.encode(sample) else { return }
        var line = data
        line.append(0x0A)

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: url, options: .atomic)
        }
    }

    /// Load samples newer than `since`. Reads the whole file and filters.
    public static func load(since: Date = .distantPast,
                            from url: URL = EWizPaths.historyFile) -> [BatterySample] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        var out: [BatterySample] = []
        for line in text.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let sample = try? decoder.decode(BatterySample.self, from: data) else { continue }
            if sample.t >= since { out.append(sample) }
        }
        return out
    }

    /// Delete the history file. Best-effort; a missing file is success.
    public static func clear(at url: URL = EWizPaths.historyFile) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Trim the file to the most recent `keep` samples, to bound growth.
    public static func trim(keep: Int = 4000, at url: URL = EWizPaths.historyFile) {
        // Cheap size guard: a line is < 200 bytes, so a file under keep×200 can't hold
        // more than `keep` samples — skip the full read+parse (runs after every append).
        if let size = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int,
           size < keep * 200 {
            return
        }
        let all = load(from: url)
        guard all.count > keep else { return }
        let recent = all.suffix(keep)
        let lines = recent.compactMap { try? encoder.encode($0) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined(separator: "\n")
        try? (lines + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
