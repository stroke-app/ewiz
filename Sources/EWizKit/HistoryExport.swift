import Foundation

/// Renders recorded history as CSV, for spreadsheets or a support bundle.
/// Pure string building — no file or UI access — so it's callable from anywhere
/// (GUI export, a future CLI) and testable on its own.
public enum HistoryExport {

    /// ISO-8601 with the local offset: sortable, unambiguous, and something
    /// Excel/Numbers both parse. Built per export (formatters aren't `Sendable`,
    /// and an export runs once on demand).
    private static func timestampFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    /// One row per battery sample: `timestamp,percent,charging,temperature_c`.
    public static func samplesCSV(_ samples: [BatterySample]) -> String {
        let timestamp = timestampFormatter()
        var out = "timestamp,percent,charging,temperature_c\n"
        for s in samples {
            let temp = s.temp.map { String(format: "%.2f", $0) } ?? ""
            out += "\(timestamp.string(from: s.t)),\(s.pct),\(s.charging ? 1 : 0),\(temp)\n"
        }
        return out
    }

    /// One row per lid-closed session, including the derived drain rate.
    public static func lidSessionsCSV(_ sessions: [LidSession]) -> String {
        let timestamp = timestampFormatter()
        var out = "closed_at,opened_at,duration_minutes,close_percent,open_percent,drop_percent,drop_per_hour\n"
        for s in sessions {
            let minutes = String(format: "%.1f", s.duration / 60)
            let rate = s.dropPerHour.map { String(format: "%.2f", $0) } ?? ""
            out += "\(timestamp.string(from: s.closedAt)),\(timestamp.string(from: s.openedAt)),"
            out += "\(minutes),\(s.closeCharge),\(s.openCharge),\(s.dropPercent),\(rate)\n"
        }
        return out
    }

    /// One row per day of the rollup.
    public static func dailySummaryCSV(_ days: [DailySummary]) -> String {
        var out = "day,min_percent,max_percent,charging_hours,battery_hours,high_charge_hours,avg_temp_c,peak_temp_c\n"
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        for d in days {
            let hours = { (t: TimeInterval) in String(format: "%.2f", t / 3600) }
            let avg = d.avgTemp.map { String(format: "%.2f", $0) } ?? ""
            let peak = d.peakTemp.map { String(format: "%.2f", $0) } ?? ""
            out += "\(day.string(from: d.day)),\(d.minPct),\(d.maxPct),"
            out += "\(hours(d.chargingTime)),\(hours(d.batteryTime)),\(hours(d.highChargeTime)),\(avg),\(peak)\n"
        }
        return out
    }
}
