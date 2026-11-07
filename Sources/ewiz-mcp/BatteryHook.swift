import Foundation
import EWizKit

/// `ewiz-mcp hook`: a Claude Code command hook that adds low-battery warnings to the
/// agent's context.
///
/// The fallback for sessions without the battery channel. A hook can't wake an idle session,
/// so it speaks at the next prompt or tool batch. Register it for UserPromptSubmit and
/// PostToolBatch. It prints nothing unless there is something new to say: each process is
/// fresh, so the tracker is saved per session and the same warning isn't repeated every
/// tool call.
enum BatteryHook {
    static func run(input: Data, reading: BatteryAlerts.Reading = BatteryAlerts.currentReading(),
                    stateDir: URL = defaultStateDir) -> String? {
        guard BatteryAlerts.isEnabled else { return nil }
        let object = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
        let event = object["hook_event_name"] as? String ?? "UserPromptSubmit"
        let session = sanitized(object["session_id"] as? String ?? "default")

        try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        let file = stateDir.appendingPathComponent(session)
        let saved = (try? String(contentsOf: file, encoding: .utf8)).flatMap { Int($0) }
        var tracker = BatteryAlerts.Tracker(announced: saved.flatMap(BatteryAlerts.Level.init) ?? .none)
        let alert = tracker.update(reading, threshold: BatteryAlerts.threshold)
        try? String(tracker.announced.rawValue).write(to: file, atomically: true, encoding: .utf8)
        pruneOldState(in: stateDir)

        guard let alert else { return nil }
        let output: [String: Any] = ["hookSpecificOutput": [
            "hookEventName": event,
            "additionalContext": "eWiz battery warning (\(alert.event)): \(alert.text)",
        ]]
        guard let data = try? JSONSerialization.data(withJSONObject: output, options: [.withoutEscapingSlashes])
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static var defaultStateDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.ewiz.app/agent-hook", isDirectory: true)
    }

    /// A session id becomes a file name; keep it to a safe alphabet.
    private static func sanitized(_ id: String) -> String {
        let safe = id.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
        let name = String(String.UnicodeScalarView(safe)).prefix(80)
        return name.isEmpty ? "default" : String(name)
    }

    /// Sessions end without telling hooks; drop state nobody has touched for two days.
    private static func pruneOldState(in dir: URL) {
        let cutoff = Date().addingTimeInterval(-2 * 86_400)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }
}
