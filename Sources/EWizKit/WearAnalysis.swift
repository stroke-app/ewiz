import Foundation

/// A single attributed cause of battery wear over the analysis window.
public struct WearContributor: Identifiable, Sendable, Equatable {
    public enum Severity: Int, Sendable, Comparable {
        case ok = 0, minor = 1, significant = 2
        public static func < (l: Severity, r: Severity) -> Bool { l.rawValue < r.rawValue }
    }
    public var id: String
    public var title: String
    public var detail: String
    public var severity: Severity
}

/// A wear summary derived from recorded history — what actually aged the battery,
/// not just a cycle count. Time-weighted between samples.
public struct WearReport: Sendable, Equatable {
    public var windowDays: Int
    public var trackedHours: Double        // total time covered by samples
    public var highChargeHours: Double     // time spent ≥ 90%
    public var hotHours: Double            // time spent ≥ hot threshold
    public var pluggedHighHours: Double    // time ≥ 90% while charging (worst case)
    public var deepDischarges: Int         // excursions below the low threshold
    public var maxTemp: Double?
    public var avgTemp: Double?
    public var contributors: [WearContributor]
    public var hasData: Bool

    public static let empty = WearReport(
        windowDays: 0, trackedHours: 0, highChargeHours: 0, hotHours: 0,
        pluggedHighHours: 0, deepDischarges: 0, maxTemp: nil, avgTemp: nil,
        contributors: [], hasData: false)
}

public enum WearAnalysis {
    public static let hotThresholdC = 35.0
    static let highChargePct = 90
    static let deepDischargePct = 15
    // Gaps longer than this (Mac asleep) don't accrue time — we don't know what happened.
    static let maxGapSeconds = 30.0 * 60

    public static func analyze(samples: [BatterySample],
                               now: Date,
                               windowDays: Int = 30) -> WearReport {
        let since = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let pts = samples.filter { $0.t >= since }.sorted { $0.t < $1.t }
        guard pts.count >= 2 else { return .empty }

        var tracked = 0.0, high = 0.0, hot = 0.0, pluggedHigh = 0.0
        var tempSum = 0.0, tempCount = 0
        var maxTemp: Double? = nil
        var deep = 0
        var wasLow = false

        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let dt = b.t.timeIntervalSince(a.t)
            if dt > 0, dt <= maxGapSeconds {
                let hours = dt / 3600
                tracked += hours
                if a.pct >= highChargePct { high += hours }
                if a.pct >= highChargePct && a.charging { pluggedHigh += hours }
                if let t = a.temp, t >= hotThresholdC { hot += hours }
            }
            if let t = a.temp {
                tempSum += t; tempCount += 1
                maxTemp = max(maxTemp ?? t, t)
            }
            // Deep-discharge excursion: count each time we dip below the threshold.
            if b.pct < deepDischargePct && !wasLow { deep += 1; wasLow = true }
            if b.pct >= deepDischargePct + 5 { wasLow = false }
        }

        let avg = tempCount > 0 ? tempSum / Double(tempCount) : nil
        let report = WearReport(
            windowDays: windowDays, trackedHours: tracked,
            highChargeHours: high, hotHours: hot, pluggedHighHours: pluggedHigh,
            deepDischarges: deep, maxTemp: maxTemp, avgTemp: avg,
            contributors: [], hasData: true)
        return report.withContributors(makeContributors(report))
    }

    private static func makeContributors(_ r: WearReport) -> [WearContributor] {
        var out: [WearContributor] = []
        let highPct = r.trackedHours > 0 ? r.highChargeHours / r.trackedHours : 0
        let hotPct = r.trackedHours > 0 ? r.hotHours / r.trackedHours : 0

        let highSev: WearContributor.Severity = highPct >= 0.4 ? .significant : (highPct >= 0.15 ? .minor : .ok)
        out.append(WearContributor(
            id: "high",
            title: "Time at high charge",
            detail: highSev == .ok
                ? String(format: "Only %.0f h ≥ 90%%. Good.", r.highChargeHours)
                : String(format: "%.0f h ≥ 90%% (%.0f%% of tracked time). A charge limit cuts this.", r.highChargeHours, highPct * 100),
            severity: highSev))

        let hotSev: WearContributor.Severity = hotPct >= 0.25 ? .significant : (hotPct >= 0.08 ? .minor : .ok)
        out.append(WearContributor(
            id: "heat",
            title: "Heat exposure",
            detail: hotSev == .ok
                ? String(format: "Ran warm (≥%.0f°C) only %.0f h.", hotThresholdC, r.hotHours)
                : String(format: "%.0f h ≥ %.0f°C%@. Heat is the biggest wear factor.", r.hotHours, hotThresholdC,
                         r.maxTemp.map { String(format: ", peak %.0f°C", $0) } ?? ""),
            severity: hotSev))

        let deepSev: WearContributor.Severity = r.deepDischarges >= 8 ? .significant : (r.deepDischarges >= 3 ? .minor : .ok)
        out.append(WearContributor(
            id: "deep",
            title: "Deep discharges",
            detail: deepSev == .ok
                ? "Rarely dropped below \(deepDischargePct)%. Good."
                : "Dropped below \(deepDischargePct)% \(r.deepDischarges) times. Frequent deep drains add wear.",
            severity: deepSev))

        // Worst first.
        return out.sorted { $0.severity > $1.severity }
    }
}

private extension WearReport {
    func withContributors(_ c: [WearContributor]) -> WearReport {
        var copy = self; copy.contributors = c; return copy
    }
}
