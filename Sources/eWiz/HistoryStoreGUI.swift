import Foundation
import Combine
import EWizKit

/// GUI-side history: records samples to the user file, and loads merged samples
/// (daemon + user files) for charting.
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var samples: [BatterySample] = []
    @Published private(set) var lidSessions: [LidSession] = []
    /// Charging runs derived from `samples`, newest first.
    @Published private(set) var chargeSessions: [ChargeSpan] = []
    /// On-battery runs derived from `samples`, newest first.
    @Published private(set) var dischargeSessions: [ChargeSpan] = []
    /// Per-day rollups derived from `samples`, newest day first.
    @Published private(set) var dailySummaries: [DailySummary] = []
    /// 30-day wear attribution, independent of the chart's `range`.
    @Published private(set) var wearReport: WearReport = .empty
    @Published var range: HistoryRange = .day

    let highChargeThreshold = SessionAnalysis.highChargeThreshold

    enum HistoryRange: String, CaseIterable, Identifiable {
        case sixHours = "6h"
        case day = "24h"
        case week = "7d"
        var id: String { rawValue }
        var interval: TimeInterval {
            switch self {
            case .sixHours: return 6 * 3600
            case .day: return 24 * 3600
            case .week: return 7 * 24 * 3600
            }
        }
    }

    private var recordTimer: Timer?

    init() {
        refresh()
        let t = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        t.tolerance = 60   // 5-min history sampling; a minute of drift is harmless
        RunLoop.main.add(t, forMode: .common)
        recordTimer = t
    }

    /// Record then load in one task so the load can't race ahead of the append.
    func refresh() {
        let snap = BatteryMonitor.read()
        let sample = BatterySample(t: Date(), pct: snap.percentage,
                                   charging: snap.isCharging, temp: snap.temperature)
        let since = Date().addingTimeInterval(-range.interval)
        Task.detached {
            HistoryStore.append(sample, to: EWizPaths.userHistoryFile)
            HistoryStore.trim(at: EWizPaths.userHistoryFile)
            await self.performLoad(since: since)
        }
    }

    /// Reload the current range without recording a new sample.
    func reload() {
        let since = Date().addingTimeInterval(-range.interval)
        Task.detached { await self.performLoad(since: since) }
    }

    /// Runs off the main thread (nonisolated) so file I/O never blocks the UI.
    private nonisolated func performLoad(since: Date) async {
        // Wear needs 30 days (a superset of any chart range), so read each file
        // once and derive the chart window in memory.
        let wearSince = Date().addingTimeInterval(-30 * 86_400)
        var all = HistoryStore.load(since: wearSince, from: EWizPaths.historyFile)
        all += HistoryStore.load(since: wearSince, from: EWizPaths.userHistoryFile)
        all.sort { $0.t < $1.t }

        let merged = all.filter { $0.t >= since }   // the chart window
        let sessions = LidSessionStore.recent(limit: 30).filter { $0.closedAt >= since }

        let spans = SessionAnalysis.spans(from: merged)
        let charge = spans
            .filter { $0.kind == .charging && $0.duration >= 180 }
            .reversed().prefix(30).map { $0 }
        let discharge = spans
            .filter { $0.kind == .discharging && $0.duration >= 600 && $0.deltaPct < 0 }
            .reversed().prefix(30).map { $0 }
        let daily = SessionAnalysis.dailySummaries(from: merged)

        let report = WearAnalysis.analyze(samples: all, now: Date())

        await MainActor.run {
            self.samples = merged
            self.lidSessions = sessions
            self.chargeSessions = charge
            self.dischargeSessions = discharge
            self.dailySummaries = daily
            self.wearReport = report
        }
    }

    // MARK: - Clearing history

    /// Erase charge samples: the user file directly, the root-owned daemon file
    /// via the helper. All derived views clear with them.
    func clearChartHistory() {
        Task.detached {
            HistoryStore.clear(at: EWizPaths.userHistoryFile)
            _ = try? ControlClient.send(.clearSamples)   // daemon deletes its own file
            await MainActor.run { self.reload() }
        }
    }

    /// Erase the lid-closed session history (user-writable; no helper needed).
    func clearLidSessions() {
        Task.detached {
            LidSessionStore.clear()
            await MainActor.run { self.reload() }
        }
    }

    func clearAll() {
        Task.detached {
            HistoryStore.clear(at: EWizPaths.userHistoryFile)
            _ = try? ControlClient.send(.clearSamples)
            LidSessionStore.clear()
            await MainActor.run { self.reload() }
        }
    }
}
