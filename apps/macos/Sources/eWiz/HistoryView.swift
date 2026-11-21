import SwiftUI
import Charts
import EWizKit

struct HistoryView: View {
    @StateObject private var model = HistoryViewModel()
    @State private var pendingClear: ClearTarget?

    private enum ClearTarget: Identifiable {
        case chart, lid, all
        var id: Int { hashValue }

        var title: String {
            switch self {
            case .chart: return "Clear chart history?"
            case .lid: return "Clear lid-closed sessions?"
            case .all: return "Clear all history?"
            }
        }
        var message: String {
            switch self {
            case .chart:
                return "Removes the charge samples behind the chart, charging and battery sessions, the daily summary, and the wear analysis. This can't be undone."
            case .lid:
                return "Removes the record of how much the battery drained while the lid was closed. This can't be undone."
            case .all:
                return "Removes every stored battery history: samples, sessions, and lid records. This can't be undone."
            }
        }
        var confirmLabel: String {
            switch self {
            case .chart: return "Clear Chart History"
            case .lid: return "Clear Lid Sessions"
            case .all: return "Clear Everything"
            }
        }
    }

    private var hasAnyHistory: Bool { !model.samples.isEmpty || !model.lidSessions.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Battery History")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Picker("", selection: $model.range) {
                        ForEach(HistoryViewModel.HistoryRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .onChange(of: model.range) { _, _ in model.reload() }

                    exportMenu
                    clearMenu
                }

                if hasAnyHistory { overviewTiles }

                if model.samples.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Samples are recorded every 5 minutes while eWiz runs.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    chargeChart
                    if model.samples.contains(where: { $0.temp != nil }) {
                        Text("Temperature").font(.callout.weight(.semibold))
                        temperatureChart
                    }
                }

                wearSection
                chargingSessionsSection
                lidSessionsSection
                batterySessionsSection
                highChargeSection
                dailySummarySection
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        // Resizable, with a floor rather than a fixed size. Six sections of charts and
        // tables in a 560x540 box is a scroll view with everything in it squeezed; the
        // charts in particular only start reading properly with width to spend.
        .frame(minWidth: 560, idealWidth: 720, maxWidth: .infinity,
               minHeight: 520, idealHeight: 660, maxHeight: .infinity)
        .onAppear { model.refresh() }
        .confirmationDialog(
            pendingClear?.title ?? "",
            isPresented: Binding(get: { pendingClear != nil },
                                 set: { if !$0 { pendingClear = nil } }),
            presenting: pendingClear
        ) { target in
            Button(target.confirmLabel, role: .destructive) { perform(target) }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text(target.message)
        }
    }

    // MARK: - Export

    /// Save what's on screen as CSV. Exports the currently selected range, so
    /// the file matches the charts rather than dumping the whole store.
    private var exportMenu: some View {
        Menu {
            Button("Export Samples (CSV)…") {
                save("ewiz-samples", HistoryExport.samplesCSV(model.samples))
            }
            .disabled(model.samples.isEmpty)
            Button("Export Daily Summary (CSV)…") {
                save("ewiz-daily", HistoryExport.dailySummaryCSV(model.dailySummaries))
            }
            .disabled(model.dailySummaries.isEmpty)
            Button("Export Lid Sessions (CSV)…") {
                save("ewiz-lid-sessions", HistoryExport.lidSessionsCSV(model.lidSessions))
            }
            .disabled(model.lidSessions.isEmpty)
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(!hasAnyHistory)
        .help("Export battery history as CSV")
    }

    private func save(_ basename: String, _ csv: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(basename).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.isExtensionHidden = false
        // The history window is a background (accessory) app window, so bring the
        // app forward or the panel can open behind whatever has focus.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.data(using: .utf8)?.write(to: url, options: .atomic)
    }

    // MARK: - Clear menu

    private var clearMenu: some View {
        Menu {
            Button("Clear Chart History…") { pendingClear = .chart }
                .disabled(model.samples.isEmpty)
            Button("Clear Lid Sessions…") { pendingClear = .lid }
                .disabled(model.lidSessions.isEmpty)
            Divider()
            Button("Clear Everything…", role: .destructive) { pendingClear = .all }
        } label: {
            Image(systemName: "trash")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(!hasAnyHistory)
        .help("Clear battery history")
    }

    private func perform(_ target: ClearTarget) {
        switch target {
        case .chart: model.clearChartHistory()
        case .lid: model.clearLidSessions()
        case .all: model.clearAll()
        }
    }

    // MARK: - Wear attribution

    @ViewBuilder
    private var wearSection: some View {
        let r = model.wearReport
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("What's Aging Your Battery")
                    .font(.title3.weight(.semibold))
                Spacer()
                if r.hasData {
                    Text("last 30 days").font(.caption).foregroundStyle(.secondary)
                }
            }

            if !r.hasData {
                Text("Not enough history yet. eWiz records a sample every 5 minutes. Check back after a day or two of use.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(r.contributors.enumerated()), id: \.element.id) { i, c in
                        if i > 0 { Divider() }
                        wearRow(c)
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func wearRow(_ c: WearContributor) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: wearIcon(c.severity))
                .foregroundStyle(wearColor(c.severity))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.title).font(.callout.weight(.medium))
                Text(c.detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func wearIcon(_ s: WearContributor.Severity) -> String {
        switch s {
        case .ok: return "checkmark.circle.fill"
        case .minor: return "exclamationmark.circle.fill"
        case .significant: return "exclamationmark.triangle.fill"
        }
    }
    private func wearColor(_ s: WearContributor.Severity) -> Color {
        switch s {
        case .ok: return .green
        case .minor: return .yellow
        case .significant: return .orange
        }
    }

    // MARK: - Overview

    private var overviewTiles: some View {
        let o = model.overview
        return HStack(spacing: 10) {
            statTile("On battery",
                     value: o.batteryTime > 0 ? durationText(o.batteryTime) : "–",
                     detail: o.drainPerHour.map { String(format: "%.1f%%/h awake", $0) }
                        ?? (o.batteryDropPct > 0 ? "−\(o.batteryDropPct)%" : "no use yet"))
            statTile("Lid closed",
                     value: o.lidCloses > 0 ? durationText(o.lidClosedTime) : "–",
                     detail: o.lidCloses == 0 ? "no closes"
                        : "\(o.lidCloses) close\(o.lidCloses == 1 ? "" : "s")")
            statTile("Asleep drain",
                     value: o.lidDrainPerHour.map { String(format: "%.1f%%/h", $0) } ?? "–",
                     detail: o.lidBatteryTime > 0
                        ? "−\(o.lidBatteryDropPct)% over \(durationText(o.lidBatteryTime))"
                        : "no closes on battery")
            statTile("Charged",
                     value: o.chargeGainPct > 0 ? "+\(o.chargeGainPct)%" : "–",
                     detail: o.chargingTime > 0 ? "in \(durationText(o.chargingTime))" : "not plugged in")
        }
    }

    private func statTile(_ title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Lid-closed sessions

    @ViewBuilder
    private var lidSessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("While Lid Was Closed")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !model.lidSessions.isEmpty {
                    Text("drain is measured on battery only")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if model.lidSessions.isEmpty {
                Text("No closed-lid sessions in this period yet. Close the lid and reopen it to see how much the battery drained.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.lidSessions.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Divider() }
                        lidSessionRow(s)
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func lidSessionRow(_ s: LidSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: s.onCharger ? "powerplug.fill" : "moon.zzz.fill")
                .foregroundStyle(s.onCharger ? Color(ChargePalette.accent) : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(closedRangeText(s)).font(.callout)
                Text("\(s.closeCharge)% → \(s.openCharge)% · \(durationText(s.duration)) · \(s.onCharger ? "on charger" : "on battery")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(lidHeadline(s))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(lidColor(s))
                    .monospacedDigit()
                if let detail = lidDetail(s) {
                    Text(detail)
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func lidHeadline(_ s: LidSession) -> String {
        if s.onCharger { return s.gainPercent > 0 ? "+\(s.gainPercent)%" : "held" }
        return s.dropPercent == 0 ? "no drop" : "−\(s.dropPercent)%"
    }

    private func lidDetail(_ s: LidSession) -> String? {
        if s.onCharger {
            return s.gainPerHour.map { String(format: "charged %.1f%%/h", $0) } ?? "charger in"
        }
        return s.dropPerHour.map { String(format: "%.1f%%/h · ~%.0f%%/night", $0, $0 * 8) }
    }

    private func lidColor(_ s: LidSession) -> Color {
        if s.onCharger { return s.gainPercent > 0 ? Color(ChargePalette.accent) : .secondary }
        return s.dropPercent == 0 ? .secondary : .primary
    }

    /// "Nov 11, 10:24 PM – 7:02 AM", with the open's date only when it differs.
    private func closedRangeText(_ s: LidSession) -> String {
        let start = DateFormatter()
        start.dateFormat = "MMM d, h:mm a"
        let end = DateFormatter()
        end.dateFormat = Calendar.current.isDate(s.closedAt, inSameDayAs: s.openedAt)
            ? "h:mm a" : "MMM d, h:mm a"
        return "\(start.string(from: s.closedAt)) – \(end.string(from: s.openedAt))"
    }

    private func durationText(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    // MARK: - Charging / battery sessions (derived from samples)

    @ViewBuilder
    private var chargingSessionsSection: some View {
        chargeSpanSection(
            title: "Charging Sessions",
            emptyText: "No charging sessions in this period yet. Plug in to see how fast the battery charges.",
            spans: model.chargeSessions)
    }

    @ViewBuilder
    private var batterySessionsSection: some View {
        chargeSpanSection(
            title: "On Battery",
            emptyText: "No on-battery sessions in this period yet. Unplug to see how fast the battery drains in real use.",
            spans: model.dischargeSessions)
    }

    @ViewBuilder
    private func chargeSpanSection(title: String, emptyText: String, spans: [ChargeSpan]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold))

            if spans.isEmpty {
                Text(emptyText)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(spans.enumerated()), id: \.element.id) { i, s in
                        if i > 0 { Divider() }
                        chargeSpanRow(s)
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func chargeSpanRow(_ s: ChargeSpan) -> some View {
        let charging = s.kind == .charging
        return HStack(spacing: 10) {
            Image(systemName: charging ? "bolt.fill" : "battery.75")
                .foregroundStyle(charging ? Color(ChargePalette.accent) : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText(s.startAt)).font(.callout)
                Text(spanDetail(s))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(deltaText(s))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(charging ? Color(ChargePalette.accent) : .primary)
                    .monospacedDigit()
                if let rate = s.ratePerHour {
                    Text(String(format: "%.1f%%/h", rate))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func spanDetail(_ s: ChargeSpan) -> String {
        var text = "\(s.startPct)% → \(s.endPct)% · \(durationText(s.duration))"
        let shut = SessionAnalysis.lidClosedTime(from: s.startAt, to: s.endAt,
                                                 sessions: model.lidSessions)
        if shut >= 60 { text += " · lid closed \(durationText(shut))" }
        return text
    }

    private func deltaText(_ s: ChargeSpan) -> String {
        let d = s.deltaPct
        if d == 0 { return "no change" }
        return d > 0 ? "+\(d)%" : "−\(-d)%"
    }

    // MARK: - Time at high charge (per day)

    @ViewBuilder
    private var highChargeSection: some View {
        let days = model.dailySummaries.filter { $0.highChargeTime > 0 }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Time at High Charge").font(.title3.weight(.semibold))
                Spacer()
                Text("above \(model.highChargeThreshold)%")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if days.isEmpty {
                Text("The battery hasn't spent time above \(model.highChargeThreshold)% in this period. Sitting at a high charge is a leading cause of wear, so less is better.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { i, d in
                        if i > 0 { Divider() }
                        HStack {
                            Text(dayText(d.day)).font(.callout)
                            Spacer()
                            Text(durationText(d.highChargeTime))
                                .font(.callout.weight(.semibold)).monospacedDigit()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Daily summary

    @ViewBuilder
    private var dailySummarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Summary").font(.title3.weight(.semibold))

            if model.dailySummaries.isEmpty {
                Text("No daily summary yet. eWiz rolls up each day's charge range, time on power, and temperature once it has a day of samples.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.dailySummaries.enumerated()), id: \.element.id) { i, d in
                        if i > 0 { Divider() }
                        dailyRow(d)
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func dailyRow(_ d: DailySummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayText(d.day)).font(.callout.weight(.medium))
                Text(powerTimeText(d)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(d.minPct)–\(d.maxPct)%")
                    .font(.callout.weight(.semibold)).monospacedDigit()
                if let peak = d.peakTemp {
                    Text(tempText(avg: d.avgTemp, peak: peak))
                        .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func powerTimeText(_ d: DailySummary) -> String {
        var parts: [String] = []
        if d.chargingTime > 0 { parts.append("charged \(durationText(d.chargingTime))") }
        if d.batteryTime > 0 { parts.append("on battery \(durationText(d.batteryTime))") }
        if d.lidClosedTime >= 60 {
            parts.append("lid closed \(durationText(d.lidClosedTime))"
                         + (d.lidDropPct > 0 ? " (−\(d.lidDropPct)%)" : ""))
        }
        return parts.isEmpty ? "–" : parts.joined(separator: " · ")
    }

    private func tempText(avg: Double?, peak: Double) -> String {
        if let avg { return String(format: "avg %.0f° · peak %.0f°", avg, peak) }
        return String(format: "peak %.0f°", peak)
    }

    // MARK: - Date formatting

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }

    private func dayText(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private var chargeChart: some View {
        Chart {
            // Lid-closed spells behind the line. The Mac records nothing while asleep, so
            // without these a night reads as one straight segment with no explanation.
            ForEach(model.lidSessions) { s in
                RectangleMark(
                    xStart: .value("Closed", max(s.closedAt, model.windowStart)),
                    xEnd: .value("Opened", s.openedAt),
                    yStart: .value("min", 0),
                    yEnd: .value("max", 100))
                .foregroundStyle(by: .value("Period", "Lid closed"))
                .opacity(0.12)
            }
            ForEach(model.samples) { s in
                chargeMarks(s)
            }
        }
        .chartForegroundStyleScale(["Lid closed": Color.indigo])
        .chartLegend(model.lidSessions.isEmpty ? .hidden : .visible)
        .chartLegend(position: .top, alignment: .trailing)
        .chartYScale(domain: 0...100)
        .chartYAxisLabel("Charge %")
        .frame(minHeight: 200)
    }

    @ChartContentBuilder
    private func chargeMarks(_ s: BatterySample) -> some ChartContent {
            if s.charging {
                AreaMark(
                    x: .value("Time", s.t),
                    yStart: .value("min", 0),
                    yEnd: .value("Charge", s.pct)
                )
                .foregroundStyle(.primary.opacity(0.06))
            }
            LineMark(
                x: .value("Time", s.t),
                y: .value("Charge", s.pct)
            )
            .foregroundStyle(.primary)
            .interpolationMethod(.monotone)
    }

    private var temperatureChart: some View {
        Chart(model.samples.filter { $0.temp != nil }) { s in
            LineMark(
                x: .value("Time", s.t),
                y: .value("°C", s.temp ?? 0)
            )
            .foregroundStyle(.secondary)
            .interpolationMethod(.monotone)
        }
        .chartYAxisLabel("°C")
        .frame(height: 120)
    }
}
