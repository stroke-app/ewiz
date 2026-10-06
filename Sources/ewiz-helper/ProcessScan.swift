import Foundation

/// Is a "keep me awake" task running now? Runs `ps` once per tick, matching by command
/// name and/or CPU. As root it sees every user's processes.
enum ProcessScan {
    /// What one `ps` pass saw: the name match and the busiest process, so callers
    /// can apply their own threshold without scanning twice per tick.
    struct Reading {
        /// Highest %CPU any single process is using.
        var topCPU: Double = 0
        /// Whether a process matching the configured names is running.
        var matchedName = false
    }

    /// Single `ps` pass. As root it sees every user's processes.
    static func scan(names: [String]) -> Reading {
        let wantNames = names
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        var reading = Reading()
        guard let out = Shell.run("/bin/ps", ["-Acro", "pid,pcpu,comm"]) else { return reading }
        for line in out.split(separator: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let cpu = Double(parts[1]) else { continue }
            reading.topCPU = max(reading.topCPU, cpu)
            guard !reading.matchedName, !wantNames.isEmpty else { continue }
            let comm = String(parts[2]).lowercased()
            let name = (comm as NSString).lastPathComponent
            if wantNames.contains(where: { name.contains($0) || comm.contains($0) }) {
                reading.matchedName = true
            }
        }
        return reading
    }

    /// True if any process matches one of `names` (case-insensitive substring of
    /// the command) or, when `minCpu > 0`, uses at least `minCpu` %CPU.
    static func isBusy(names: [String], minCpu: Double) -> Bool {
        let wantNames = names
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard !wantNames.isEmpty || minCpu > 0 else { return false }

        guard let out = Shell.run("/bin/ps", ["-Acro", "pid,pcpu,comm"]) else { return false }
        for line in out.split(separator: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let cpu = Double(parts[1]) else { continue }
            let comm = String(parts[2]).lowercased()
            let name = (comm as NSString).lastPathComponent

            if minCpu > 0, cpu >= minCpu { return true }
            if wantNames.contains(where: { name.contains($0) || comm.contains($0) }) {
                return true
            }
        }
        return false
    }
}
