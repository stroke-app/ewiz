import Foundation

/// A contiguous run of samples in one power state (charging or on battery).
public struct ChargeSpan: Codable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case charging, discharging }

    public var kind: Kind
    public var startAt: Date
    public var endAt: Date
    public var startPct: Int
    public var endPct: Int

    public var id: Date { startAt }
    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
    /// Signed change over the span: positive gained, negative lost.
    public var deltaPct: Int { endPct - startPct }

    /// Magnitude of change in %/hour (nil when the span is too short to be meaningful).
    public var ratePerHour: Double? {
        let hours = duration / 3600
        guard hours >= 0.05 else { return nil }
        return abs(Double(deltaPct)) / hours
    }

    public init(kind: Kind, startAt: Date, endAt: Date, startPct: Int, endPct: Int) {
        self.kind = kind
        self.startAt = startAt
        self.endAt = endAt
        self.startPct = startPct
        self.endPct = endPct
    }
}

/// A per-day rollup of battery activity, derived from the sample history.
public struct DailySummary: Codable, Sendable, Identifiable {
    public var day: Date            // start of the calendar day
    public var minPct: Int
    public var maxPct: Int
    public var chargingTime: TimeInterval
    public var batteryTime: TimeInterval
    public var avgTemp: Double?
    public var peakTemp: Double?
    /// Time spent at or above the high-charge threshold (a wear driver).
    public var highChargeTime: TimeInterval

    public var id: Date { day }

    public init(day: Date, minPct: Int, maxPct: Int,
                chargingTime: TimeInterval, batteryTime: TimeInterval,
                avgTemp: Double?, peakTemp: Double?, highChargeTime: TimeInterval) {
        self.day = day
        self.minPct = minPct
        self.maxPct = maxPct
        self.chargingTime = chargingTime
        self.batteryTime = batteryTime
        self.avgTemp = avgTemp
        self.peakTemp = peakTemp
        self.highChargeTime = highChargeTime
    }
}

/// Derives sessions and daily rollups from sorted `BatterySample`s. Pure — runs off-thread.
public enum SessionAnalysis {
    /// A gap larger than this (samples are ~5 min apart) means the Mac was asleep/off;
    /// it breaks a run and isn't counted as time.
    public static let maxGap: TimeInterval = 20 * 60
    /// Charge level considered "high" for wear-tracking purposes.
    public static let highChargeThreshold = 80

    /// Split samples into contiguous same-state runs (charging vs. on battery).
    /// `samples` must be sorted ascending by time.
    public static func spans(from samples: [BatterySample]) -> [ChargeSpan] {
        guard samples.count >= 2 else { return [] }
        var out: [ChargeSpan] = []
        var runStart = 0

        func flush(through endIdx: Int) {
            guard endIdx > runStart else { return }   // need ≥ 2 samples for a span
            let a = samples[runStart], b = samples[endIdx]
            out.append(ChargeSpan(
                kind: a.charging ? .charging : .discharging,
                startAt: a.t, endAt: b.t, startPct: a.pct, endPct: b.pct))
        }

        for i in 1..<samples.count {
            let prev = samples[i - 1], cur = samples[i]
            let gap = cur.t.timeIntervalSince(prev.t)
            if cur.charging != prev.charging || gap > maxGap {
                flush(through: i - 1)
                runStart = i
            }
        }
        flush(through: samples.count - 1)
        return out
    }

    /// Per-day rollups, newest day first. `samples` must be sorted ascending.
    public static func dailySummaries(
        from samples: [BatterySample],
        calendar: Calendar = .current,
        highChargeThreshold: Int = highChargeThreshold
    ) -> [DailySummary] {
        guard !samples.isEmpty else { return [] }

        var byDay: [Date: [BatterySample]] = [:]
        for s in samples {
            byDay[calendar.startOfDay(for: s.t), default: []].append(s)
        }

        // Durations are attributed to the day of the interval's *start* sample.
        var chargingTime: [Date: TimeInterval] = [:]
        var batteryTime: [Date: TimeInterval] = [:]
        var highChargeTime: [Date: TimeInterval] = [:]
        if samples.count >= 2 {
            for i in 1..<samples.count {
                let a = samples[i - 1], b = samples[i]
                let gap = b.t.timeIntervalSince(a.t)
                guard gap > 0, gap <= maxGap else { continue }
                let day = calendar.startOfDay(for: a.t)
                if a.charging { chargingTime[day, default: 0] += gap }
                else { batteryTime[day, default: 0] += gap }
                if a.pct >= highChargeThreshold { highChargeTime[day, default: 0] += gap }
            }
        }

        return byDay.map { day, daySamples in
            let pcts = daySamples.map(\.pct)
            let temps = daySamples.compactMap(\.temp)
            return DailySummary(
                day: day,
                minPct: pcts.min() ?? 0,
                maxPct: pcts.max() ?? 0,
                chargingTime: chargingTime[day] ?? 0,
                batteryTime: batteryTime[day] ?? 0,
                avgTemp: temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count),
                peakTemp: temps.max(),
                highChargeTime: highChargeTime[day] ?? 0)
        }
        .sorted { $0.day > $1.day }
    }
}
