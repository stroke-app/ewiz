import Foundation
import Combine

struct ProcessUsage: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let cpu: Double  // percent
}

/// A distinct running process name (deduped across PIDs), with its highest current
/// CPU%. Backs the keep-awake process picker.
struct RunningProcess: Identifiable, Equatable {
    let name: String
    let cpu: Double
    var id: String { name }
}

/// Lists top CPU-consuming processes and can suspend/resume them (SIGSTOP/SIGCONT,
/// this user's processes). Polling is on-demand — only while a view observes.
@MainActor
final class ProcessMonitor: ObservableObject {
    @Published private(set) var top: [ProcessUsage] = []
    @Published private(set) var suspended: Set<pid_t> = []

    private var timer: Timer?
    private var viewers = 0

    init() {}   // nothing runs until a view asks for it

    /// Call from `.onAppear` of a view that shows process info.
    func beginObserving() {
        viewers += 1
        guard timer == nil else { return }
        refresh()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 1   // live view; keep responsive but allow slight coalescing
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Call from `.onDisappear`.
    func endObserving() {
        viewers = max(0, viewers - 1)
        if viewers == 0 {
            timer?.invalidate()
            timer = nil
        }
    }

    func refresh() {
        Task.detached {
            let list = Self.sampleTopProcesses(limit: 6)
            await MainActor.run { self.top = list }
        }
    }

    func suspend(_ pid: pid_t) { if kill(pid, SIGSTOP) == 0 { suspended.insert(pid) } }
    func resume(_ pid: pid_t) { if kill(pid, SIGCONT) == 0 { suspended.remove(pid) } }
    func toggle(_ usage: ProcessUsage) {
        if suspended.contains(usage.id) { resume(usage.id) } else { suspend(usage.id) }
    }

    /// Distinct running process names (deduped, keeping the highest CPU per name),
    /// sorted by CPU desc then name. For the keep-awake picker; run off the main thread.
    nonisolated static func runningProcessNames(limit: Int = 250) -> [RunningProcess] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-Acro", "pid,pcpu,comm"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
        var byName: [String: Double] = [:]
        let myPID = getpid()
        for line in text.split(separator: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = pid_t(parts[0]), let cpu = Double(parts[1]) else { continue }
            if pid == myPID { continue }
            let name = (String(parts[2]) as NSString).lastPathComponent
            if name.isEmpty { continue }
            byName[name] = max(byName[name] ?? 0, cpu)
        }
        var list: [RunningProcess] = byName.map { RunningProcess(name: $0.key, cpu: $0.value) }
        list.sort { a, b in
            if a.cpu != b.cpu { return a.cpu > b.cpu }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return Array(list.prefix(limit))
    }

    /// Parse ps output sorted by CPU — cheap, good enough to surface what's draining.
    private nonisolated static func sampleTopProcesses(limit: Int) -> [ProcessUsage] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-Acro", "pid,pcpu,comm"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        let text = String(decoding: data, as: UTF8.self)
        var result: [ProcessUsage] = []
        let myPID = getpid()
        for line in text.split(separator: "\n").dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3, let pid = pid_t(parts[0]), let cpu = Double(parts[1]) else { continue }
            if pid == myPID { continue }
            let name = (String(parts[2]) as NSString).lastPathComponent
            result.append(ProcessUsage(id: pid, name: name, cpu: cpu))
            if result.count >= limit { break }
        }
        return result
    }
}
