import SwiftUI
import EWizKit

/// Detached window, moved out of the menu to keep the dropdown uncluttered.
struct DetailsView: View {
    @EnvironmentObject private var battery: BatteryStore
    @EnvironmentObject private var processes: ProcessMonitor
    @EnvironmentObject private var chargeLimit: ChargeLimitStore
    @EnvironmentObject private var automation: AutomationStore

    var body: some View {
        let snap = battery.snapshot

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsCard(snap)
                powerFlowCard
                adapterCard
                systemCard
                healthCard(snap)
                energyCard
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .frame(width: 380, height: 600)
        .onAppear { processes.beginObserving(); battery.beginPowerFlowObserving() }
        .onDisappear { processes.endObserving(); battery.endPowerFlowObserving() }
    }

    // MARK: - Power flow

    private var powerFlowCard: some View {
        let f = battery.powerFlow
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Power Flow").font(.title3.weight(.semibold))
                Spacer()
                if let d = f.adapterDescription {
                    Text(d).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            // Proportional split of adapter power between system and battery
            // (only meaningful while charging on wall power).
            if let adapter = f.adapterWatts, adapter > 0.5 {
                let sys = max(0, f.systemWatts ?? 0)
                let chg = f.chargeWatts
                let total = max(sys + chg, 0.01)
                VStack(alignment: .leading, spacing: 7) {
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            Rectangle().fill(Color(ChargePalette.systemDraw))
                                .frame(width: geo.size.width * sys / total)
                            Rectangle().fill(Color(ChargePalette.accent))
                                .frame(width: geo.size.width * chg / total)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .frame(height: 10)
                    HStack(spacing: 16) {
                        splitTag(Color(ChargePalette.systemDraw), "System", sys, total)
                        splitTag(Color(ChargePalette.accent), "Into battery", chg, total)
                        Spacer()
                    }
                }

                if chg > 0.5 {
                    Text("\(watts(chg)) of the \(watts(adapter)) from the adapter is charging the battery, \(pct(chg, of: total)); the rest runs your Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 0) {
                if let adapter = f.adapterWatts {
                    flowRow("bolt.fill", .yellow, "Adapter in", watts(adapter))
                    Divider()
                }
                if let sys = f.systemWatts {
                    flowRow("cpu", .orange, "System draw", watts(sys))
                    Divider()
                }
                flowRow(batteryIcon(f), batteryColor(f), batteryLabel(f), watts(abs(f.batteryWatts)))
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if chargeLimit.chargePowerSupported {
                Text("You can't split adapter wattage in hardware, but you can hold a lower average charge power with Gentle charging in Schedule.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func flowRow(_ icon: String, _ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).frame(width: 20).foregroundStyle(color)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func watts(_ w: Double) -> String { String(format: "%.1f W", w) }

    private func pct(_ w: Double, of total: Double) -> String {
        String(format: "%.0f%%", total > 0 ? (w / total) * 100 : 0)
    }

    private func splitTag(_ color: Color, _ label: String, _ w: Double, _ total: Double) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundStyle(.secondary)
            Text("\(watts(w)) · \(pct(w, of: total))").fontWeight(.medium).monospacedDigit()
        }
        .font(.caption)
    }

    private func batteryIcon(_ f: PowerFlow) -> String {
        if f.batteryWatts > 0.5 { return "battery.100.bolt" }
        if f.batteryWatts < -0.5 { return "battery.50" }
        return "battery.100"
    }
    private func batteryColor(_ f: PowerFlow) -> Color {
        if f.batteryWatts > 0.5 { return Color(ChargePalette.accent) }
        if f.batteryWatts < -0.5 { return .red }
        return .secondary
    }
    private func batteryLabel(_ f: PowerFlow) -> String {
        if f.batteryWatts > 0.5 { return "Battery charging" }
        if f.batteryWatts < -0.5 { return "Battery draining" }
        return "Battery idle"
    }

    // MARK: - Adapter

    /// Who's actually supplying the power: adapter identity, the wattage the Mac
    /// negotiated, and a warning when the adapter could give more than it's being
    /// asked for (nearly always a cable or port limit). Hidden when nothing is
    /// plugged in — there's nothing to say.
    @ViewBuilder
    private var adapterCard: some View {
        if let a = battery.powerFlow.adapter {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Power Adapter").font(.title3.weight(.semibold))
                    Spacer()
                    if let w = a.watts {
                        Text("\(w) W").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 0) {
                    statRow("Adapter", a.name ?? a.manufacturer ?? "Connected")
                    // The USB-PD contract, not a measurement: the live figure is "Adapter in".
                    if let v = supplyText(a) { Divider(); statRow("Negotiated", v) }
                    if let m = a.maxAvailableWatts { Divider(); statRow("Adapter maximum", "\(m) W") }
                    if a.name != nil, let mfg = a.manufacturer { Divider(); statRow("Manufacturer", mfg) }
                    if let model = a.model { Divider(); statRow("Model", model) }
                    if let serial = a.serial { Divider(); statRow("Serial", serial) }
                    if a.isWireless { Divider(); statRow("Connection", "Wireless") }
                }
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if a.isUnderNegotiated, let w = a.watts, let m = a.maxAvailableWatts {
                    Label("This adapter can supply \(m) W but the Mac negotiated \(w) W. That's usually the cable: a charge cable rated below the adapter caps the whole chain.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// "20.0 V · 3.0 A" from the negotiated supply, when the adapter reports both.
    private func supplyText(_ a: AdapterInfo) -> String? {
        guard let mv = a.voltageMv, let ma = a.currentMa else { return nil }
        return String(format: "%.1f V · %.1f A", Double(mv) / 1000, Double(ma) / 1000)
    }

    // MARK: - System (lid sensor)

    private var systemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System")
                .font(.title3.weight(.semibold))

            VStack(spacing: 0) {
                statRow("Lid", automation.isLidClosed ? "Closed" : "Open")
                Divider()
                statRow("Clamshell mode", automation.isClamshellMode ? "Active" : "Off")
                Divider()
                statRow("External displays", "\(automation.externalDisplayCount)")
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if automation.isClamshellMode {
                Label("In clamshell (docked) mode the battery tends to sit at 100% and run hot, the two biggest causes of wear. Keep a charge limit and heat-pause enabled.",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Health & tips

    private func healthCard(_ snap: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Battery Health")
                    .font(.title3.weight(.semibold))
                Spacer()
                if let h = snap.healthPercent {
                    Text(condition(h))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if let h = snap.healthPercent {
                HStack(spacing: 12) {
                    Text("\(h)%")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Maximum capacity")
                            .font(.callout).foregroundStyle(.secondary)
                        if let c = snap.cycleCount {
                            Text("\(c) charge cycles")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            let tips = healthTips(snap)
            if !tips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tips, id: \.self) { tip in
                        Label {
                            Text(tip).font(.callout).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "lightbulb").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private func condition(_ health: Int) -> String {
        health >= 80 ? "Normal" : "Service Recommended"
    }

    private func healthTips(_ snap: BatterySnapshot) -> [String] {
        var tips: [String] = []

        if let t = snap.temperature, t >= 35 {
            tips.append(String(format: "Battery is warm (%.0f°C). Heat is the biggest wear factor, so avoid charging in hot spots.", t))
        }
        if snap.percentage >= 95 && snap.isPluggedIn {
            tips.append("Sitting at ~100% while plugged in ages the battery faster. A charge limit keeps it lower.")
        }
        if chargeLimit.daemonAvailable {
            if !chargeLimit.limitEnabled {
                tips.append("Turn on a charge limit (80%) to cut time at high charge and slow wear.")
            }
            if !chargeLimit.heatAwareEnabled {
                tips.append("Enable “Pause charging when hot” to protect the battery from heat while charging.")
            }
        }
        if let h = snap.healthPercent, h < 80 {
            tips.append("Maximum capacity is \(h)%. Apple considers under 80% as service-recommended.")
        }
        if tips.isEmpty {
            tips.append("Your battery settings look healthy. Nice work keeping it cool and capped.")
        }
        return tips
    }

    // MARK: - Stats

    private func statsCard(_ snap: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Battery")
                .font(.title3.weight(.semibold))

            VStack(spacing: 0) {
                if let h = snap.healthPercent { statRow("Health", "\(h)%") }
                if let c = snap.cycleCount { Divider(); statRow("Cycle count", "\(c)") }
                if let t = snap.temperature { Divider(); statRow("Temperature", String(format: "%.1f °C", t)) }
                if let m = snap.maxCapacity, let d = snap.designCapacity {
                    Divider(); statRow("Capacity", "\(m) / \(d) mAh")
                }
                Divider(); statRow("Power source", snap.powerSource)
                Divider(); statRow("Charge", "\(snap.percentage)%")
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Energy users

    private var energyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Energy Users")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("CPU")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if processes.top.isEmpty {
                Text("No data yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(processes.top.enumerated()), id: \.element.id) { index, p in
                        if index > 0 { Divider() }
                        energyRow(p)
                    }
                }
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Suspend pauses a process (SIGSTOP); resume continues it. Only your own processes can be paused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func energyRow(_ p: ProcessUsage) -> some View {
        HStack(spacing: 10) {
            Text(p.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(String(format: "%.0f%%", p.cpu))
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
            Button {
                processes.toggle(p)
            } label: {
                Image(systemName: processes.suspended.contains(p.id) ? "play.fill" : "pause.fill")
                    .frame(width: 16)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(processes.suspended.contains(p.id) ? Color.primary : .secondary)
            .help(processes.suspended.contains(p.id) ? "Resume" : "Suspend")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
