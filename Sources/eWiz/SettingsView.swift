import SwiftUI
import AppKit
import EWizKit

/// Detached preferences window for the "set once and forget" controls.
struct SettingsView: View {
    @EnvironmentObject private var battery: BatteryStore
    @EnvironmentObject private var chargeLimit: ChargeLimitStore
    @EnvironmentObject private var automation: AutomationStore
    @EnvironmentObject private var caffeine: CaffeineManager
    @EnvironmentObject private var overlay: ChargeOverlayController
    @EnvironmentObject private var idleSaver: IdleSaverStore
    @EnvironmentObject private var license: LicenseManager
    @EnvironmentObject private var startup: StartupManager
    @EnvironmentObject private var updater: UpdaterManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var notifier: NotificationManager
    @EnvironmentObject private var network: NetworkProfileStore
    @EnvironmentObject private var triggers: TriggerStore
    @EnvironmentObject private var hotkeys: HotkeyStore
    /// "Copied" beside Copy Diagnostics for a moment after it's pressed.
    @State private var copiedDiagnostics = false
    @Environment(\.openWindow) private var openWindow
    @State private var installError: String?
    @State private var selection: Tab = .charging
    /// Which shortcut row is capturing keys (nil = none). Held here rather than per
    /// row so starting one recording ends any other.
    @State private var recordingAction: HotkeyAction?
    /// Last shortcut reassignment, to explain which action lost its binding.
    @State private var displacedNote: String?
    /// Schedule being edited/added in the sheet (nil = sheet closed).
    @State private var editingSchedule: ChargeSchedule?
    @State private var editingIsNew = false
    /// Always Active window being edited/added in the sheet (nil = sheet closed).
    @State private var editingAwakeSchedule: AwakeSchedule?
    @State private var editingAwakeIsNew = false
    /// Automation rule being edited/added in the sheet (nil = sheet closed).
    @State private var editingRule: TriggerRule?
    @State private var editingRuleIsNew = false
    /// Whether the "pick running processes" sheet for keep-awake is open.
    @State private var showingProcessPicker = false

    /// Hand-rolled tab bar instead of `TabView`, which on recent macOS collapses
    /// into an overflow popup instead of showing real tabs.
    private enum Tab: String, CaseIterable, Identifiable {
        case charging, schedule, automation, sleepPower, shortcuts, general, about
        var id: String { rawValue }

        var title: String {
            switch self {
            case .charging: return "Charging"
            case .schedule: return "Schedule"
            case .automation: return "Automation"
            case .sleepPower: return "Sleep & Power"
            case .shortcuts: return "Shortcuts"
            case .general: return "General"
            case .about: return "About"
            }
        }
        var icon: String {
            switch self {
            case .charging: return "charging"
            case .schedule: return "clock"
            case .automation: return "wand"
            case .sleepPower: return "sleep"
            case .shortcuts: return "key"
            case .general: return "settings"
            case .about: return "info"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch selection {
                case .charging:   chargingTab
                case .schedule:   scheduleTab
                case .automation: automationTab
                case .sleepPower: sleepPowerTab
                case .shortcuts:  shortcutsTab
                case .general:    generalTab
                case .about:      aboutTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Wide enough for all seven tabs to sit on one row without crowding —
        // "Sleep & Power" is the one that clips first when this shrinks.
        .frame(width: 580, height: 600)
        .sheet(item: $editingSchedule) { schedule in
            ScheduleEditorView(
                schedule: schedule,
                isNew: editingIsNew,
                onSave: { chargeLimit.updateOrAddSchedule($0) },
                onDelete: editingIsNew ? nil : { chargeLimit.removeSchedule(schedule) })
        }
        .sheet(item: $editingAwakeSchedule) { schedule in
            AwakeScheduleEditorView(
                schedule: schedule,
                isNew: editingAwakeIsNew,
                onSave: { chargeLimit.updateOrAddAwakeSchedule($0) },
                onDelete: editingAwakeIsNew ? nil : { chargeLimit.removeAwakeSchedule(schedule) })
        }
        .sheet(item: $editingRule) { rule in
            TriggerRuleEditorView(
                store: triggers,
                rule: rule,
                isNew: editingRuleIsNew,
                onSave: { triggers.updateOrAddRule($0) },
                onDelete: editingRuleIsNew ? nil : { triggers.removeRule(rule) })
        }
        .sheet(isPresented: $showingProcessPicker) {
            ProcessPickerView(existing: chargeLimit.keepAwakeProcesses) { picked in
                // Union with the existing list (case-insensitive), preserving order.
                var names = chargeLimit.keepAwakeProcesses
                let have = Set(names.map { $0.lowercased() })
                for name in picked where !have.contains(name.lowercased()) { names.append(name) }
                chargeLimit.keepAwakeProcesses = names
                chargeLimit.apply()
            }
        }
    }

    // MARK: - Tab bar

    /// Tabs share the bar equally. A fixed per-tab minimum would overflow the
    /// window once there were six of them, pushing the last pill off the edge.
    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private func tabButton(_ tab: Tab) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                HugeIcon(tab.icon, size: 19)
                    .frame(height: 20)
                Text(tab.title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // No focus ring: on a tab strip it reads as a stray outline, not focus.
        .focusEffectDisabled()
    }

    // MARK: - About

    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    AppIconView(size: 96)
                    Text("eWiz")
                        .font(.title2.weight(.semibold))
                    Text("Version \(updater.currentVersion)")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Created by Nischal Dahal")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)

                Divider()

                VStack(spacing: 0) {
                    licenseRow
                    divider
                    // Support carries its own diagnostics. A bare mailto got "it stopped
                    // working" and a week of asking which macOS, which Mac, which helper.
                    actionRow("Contact Support", systemImage: "mail") {
                        openURL(SupportInfo.emailURL(subject: "eWiz support",
                                                     summary: supportSummary))
                    }
                    divider
                    actionRow("Report a Bug", systemImage: "alert") {
                        openURL(SupportInfo.issueURL(summary: supportSummary))
                    }
                    divider
                    actionRow("Copy Diagnostics", systemImage: "copy",
                              trailing: copiedDiagnostics ? "Copied" : nil) {
                        let text = SupportInfo.diagnostics(chargeLimit: chargeLimit, license: license,
                                                           battery: battery.snapshot)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        copiedDiagnostics = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedDiagnostics = false }
                    }
                    divider
                    linkRow("Donate", systemImage: "heart",
                            url: EWizLinks.donate.absoluteString)
                    divider
                    linkRow("Check It Out on GitHub", systemImage: "code",
                            url: EWizLinks.source.absoluteString)
                    divider
                    linkRow("Visit the Website", systemImage: "compass",
                            url: EWizLinks.website.absoluteString)
                }
                .padding(.vertical, 20)

                Divider()

                Text("Made with care for Apple Silicon Macs.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 16)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    /// Always available so a licensed user can still manage the license after the
    /// trial banner is gone.
    private var licenseRow: some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "license")
        } label: {
            HStack(spacing: 10) {
                HugeIcon(license.isLicensed ? "check" : "key", size: 19)
                    .frame(width: 22)
                    .foregroundStyle(.tint)
                Text(license.isLicensed ? "Manage License" : "Activate License")
                    .foregroundStyle(.tint)
                Spacer()
                Text(license.statusText)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
                HugeIcon("chevronRight", size: 12)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var supportSummary: String {
        SupportInfo.summary(chargeLimit: chargeLimit, license: license, battery: battery.snapshot)
    }

    private func openURL(_ url: URL?) {
        if let url { NSWorkspace.shared.open(url) }
    }

    private func linkRow(_ title: String, systemImage: String, url: String) -> some View {
        actionRow(title, systemImage: systemImage) { openURL(URL(string: url)) }
    }

    /// A row in the About list. Leaves the app by default (the ↗); `trailing` replaces the
    /// arrow with a word of feedback for rows that act in place.
    private func actionRow(_ title: String, systemImage: String, trailing: String? = nil,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                HugeIcon(systemImage, size: 17)
                    .frame(width: 22)
                    .foregroundStyle(.tint)
                Text(title)
                    .foregroundStyle(.tint)
                Spacer()
                if let trailing {
                    Text(trailing).font(.caption).foregroundStyle(.secondary)
                } else {
                    HugeIcon("arrowUpRight", size: 13)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
            .padding(.horizontal, 24)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Charging

    private var chargingTab: some View {
        tab {
            if chargeLimit.daemonAvailable {
                proGate {
                    if chargeLimit.dischargeSupported {
                        card("Long-term care") {
                            toggleRow("Park the battery near \(LongevityCare.targetPercent)%",
                                      "Charges up to it, runs down to it, then holds there on the adapter.",
                                      isOn: Binding(get: { chargeLimit.longevityCare },
                                                    set: { chargeLimit.setLongevityCare($0) }))
                            if chargeLimit.longevityCare {
                                divider
                                infoRow("On. You give up the top \(100 - LongevityCare.targetPercent)% day to day, so turn it off before a trip.",
                                        systemImage: "heart")
                            }
                        }
                    }

                    card("Hold") {
                        toggleRow("Don't charge while plugged in",
                                  chargeLimit.nativeLimitFloor.map {
                                      "Stops charging and runs on wall power. macOS can only hold this Mac at \(chargeLimit.nativeLimitSteps.filter { $0 < 100 }.map(String.init).joined(separator: ", "))%, so it charges up to the next of those first, from \($0)% at the lowest."
                                  } ?? (chargeLimit.magSafeSupported
                                  ? "Leaves the battery where it is, whatever the limit says."
                                  : "Runs off the adapter and leaves the battery where it is, whatever the limit says."),
                                  isOn: bind(\.holdCharge))
                        if chargeLimit.holdCharge {
                            divider
                            infoRow("Held. The battery stays around the level it was at when you switched this on, instead of climbing to full.",
                                    systemImage: "pause")
                        }
                    }

                    card("Enforcement") {
                        toggleRow("Stop charging before sleep",
                                  chargeLimit.limitEnabled
                                  ? "Cuts charging at sleep even when no limit is set."
                                  : "Cuts charging as the Mac goes to sleep. With a charge limit set this happens anyway: the limit can't be enforced while asleep.",
                                  isOn: bind(\.disableChargingBeforeSleep))
                        divider
                        toggleRow("Prevent idle sleep while plugged in",
                                  "Keeps the Mac awake on power so the limit holds.",
                                  isOn: bind(\.preventIdleSleep))
                        divider
                        toggleRow("Always Active (keep awake with lid closed)",
                                  "Work keeps running with the lid shut. AC power only by default.",
                                  isOn: bind(\.keepAwake))
                        if chargeLimit.keepAwake {
                            divider
                            keepAwakeTimerRow
                            if chargeLimit.hasAwakeSchedules {
                                divider
                                keepAwakeWindowsRow
                            }
                            divider
                            toggleRow("Also keep awake on battery",
                                      "Drains fast and runs hot. Set a temperature guardrail below.",
                                      isOn: bind(\.keepAwakeOnBattery))
                            divider
                            toggleRow("Only while a task is running",
                                      "Holds while a matching process runs, then sleeps.",
                                      isOn: bind(\.keepAwakeRequiresTask))
                            if chargeLimit.keepAwakeRequiresTask {
                                divider
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Keep awake for these apps/processes").font(.callout)
                                        Spacer()
                                        Button {
                                            showingProcessPicker = true
                                        } label: {
                                            Label("Choose…", systemImage: "plus.circle")
                                        }
                                        .buttonStyle(.link)
                                    }
                                    TextField("e.g. ffmpeg, npm, docker, rsync",
                                              text: keepAwakeProcessText)
                                        .textFieldStyle(.roundedBorder)
                                    Text("Comma-separated names; matched against running commands. Use “Choose…” to pick from running processes.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                                divider
                                stepperRow("Or any process above",
                                           value: chargeLimit.keepAwakeMinCpu > 0
                                                ? "\(Int(chargeLimit.keepAwakeMinCpu))% CPU" : "Off",
                                           binding: Binding(
                                            get: { chargeLimit.keepAwakeMinCpu },
                                            set: { chargeLimit.keepAwakeMinCpu = $0; chargeLimit.apply() }),
                                           range: 0...100)
                                divider
                                toggleRow("Sleep when the task finishes",
                                          "Sleeps as soon as the task stops, rather than waiting for idle.",
                                          isOn: bind(\.sleepWhenTaskDone))
                            }
                            divider
                            toggleRow("Sleep if it gets too hot",
                                      "Releases keep-awake and sleeps if the Mac runs hot.",
                                      isOn: Binding(
                                        get: { chargeLimit.keepAwakeMaxTempC > 0 },
                                        set: { chargeLimit.keepAwakeMaxTempC = $0 ? 40 : 0; chargeLimit.apply() }))
                            if chargeLimit.keepAwakeMaxTempC > 0 {
                                divider
                                stepperRow("Temperature cutoff",
                                           value: "\(Int(chargeLimit.keepAwakeMaxTempC)) °C",
                                           binding: Binding(
                                            get: { chargeLimit.keepAwakeMaxTempC },
                                            set: { chargeLimit.keepAwakeMaxTempC = $0; chargeLimit.apply() }),
                                           range: 35...55)
                            }
                        }
                    }

                    card("Heat") {
                        toggleRow("Pause charging when hot",
                                  "Stops charging while the battery is warm.",
                                  isOn: bind(\.heatAwareEnabled))
                        if chargeLimit.heatAwareEnabled {
                            divider
                            stepperRow("Max temperature",
                                       value: "\(Int(chargeLimit.maxChargeTempC)) °C",
                                       binding: Binding(
                                        get: { chargeLimit.maxChargeTempC },
                                        set: { chargeLimit.maxChargeTempC = $0; chargeLimit.apply() }),
                                       range: 30...45)
                        }
                    }

                    if chargeLimit.dischargeSupported {
                        card("Discharge") {
                            toggleRow("Discharge to limit",
                                      "Runs off battery until it drops back to the limit.",
                                      isOn: bind(\.dischargeEnabled))
                        }
                    }

                    if chargeLimit.magSafeSupported {
                        card("MagSafe LED") {
                            pickerRow(magSafeHint) {
                                Picker("MagSafe LED behaviour", selection: Binding(
                                    get: { chargeLimit.magSafeLedMode },
                                    set: { chargeLimit.magSafeLedMode = $0; chargeLimit.apply() })) {
                                    ForEach(MagSafeLEDMode.allCases) { Text($0.title).tag($0) }
                                }
                                .pickerStyle(.segmented).labelsHidden()
                            }
                        }
                    }
                }
            } else {
                helperCard
            }
        }
    }

    // MARK: - Always Active timing

    /// Auto-off timer. The deadline lives in the daemon's config, so it still fires with
    /// the Mac asleep or eWiz quit — and it shows the wall-clock time it ends rather
    /// than a countdown, which would need a ticking timer to stay honest.
    private var keepAwakeTimerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Turn off automatically").font(.callout)
                Text(chargeLimit.keepAwakeUntil == nil
                     ? "Always Active stays on until you switch it off."
                     : "Always Active switches itself off then, even if the Mac is asleep or eWiz isn't running.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Menu(keepAwakeTimerLabel) {
                Button("Don't turn off") { chargeLimit.startKeepAwake(minutes: nil) }
                Divider()
                ForEach([30, 60, 120, 300, 480], id: \.self) { minutes in
                    Button(Self.durationLabel(minutes)) { chargeLimit.startKeepAwake(minutes: minutes) }
                }
            }
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
    }

    /// Caffeine's live state in one line, including how far the hold reaches — the
    /// difference between "screen on" and "tasks only" is the difference between
    /// percents per hour and almost nothing.
    private var caffeineStateHint: String {
        guard caffeine.active else {
            return "Caffeine is off. The Mac sleeps and dims normally. Turn it on from the menu bar."
        }
        let reach = (caffeine.hold ?? .displayOn).title.lowercased()
        guard let until = caffeine.expiresAt else { return "Caffeine is holding: \(reach)." }
        return "Caffeine is holding until \(Self.clockFormatter.string(from: until)): \(reach)."
    }

    private var keepAwakeTimerLabel: String {
        guard let until = chargeLimit.keepAwakeUntil else { return "Don't turn off" }
        return "Until \(Self.clockFormatter.string(from: until))"
    }

    private static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "After \(minutes) minutes" }
        let h = Double(minutes) / 60
        let text = h == h.rounded() ? "\(Int(h))" : String(format: "%.1f", h)
        return "After \(text) hour\(minutes == 60 ? "" : "s")"
    }

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// Shown once windows exist, so the switch's meaning is never a mystery: on means
    /// "hold during these hours", not "hold right now".
    private var keepAwakeWindowsRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Scheduled hours").font(.callout)
                    if chargeLimit.keepAwakeArmed { activeBadge("HOLDING") } else { waitingBadge }
                }
                ForEach(chargeLimit.keepAwakeSchedules.filter(\.enabled)) { window in
                    Text(window.scheduleSummary)
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Text("Outside these hours the Mac sleeps normally.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Edit…") { selection = .schedule }
                .controlSize(.small)
        }
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
    }

    private func activeBadge(_ text: String = "ACTIVE") -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.green.opacity(0.25), in: Capsule())
            .foregroundStyle(.green)
    }

    private var waitingBadge: some View {
        Text("WAITING")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(Color.secondary.opacity(0.2), in: Capsule())
            .foregroundStyle(.secondary)
    }

    private func awakeScheduleRow(_ s: AwakeSchedule) -> some View {
        Button {
            editingAwakeIsNew = false
            editingAwakeSchedule = s
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "cup.and.saucer.fill")
                    .frame(width: 22)
                    .foregroundStyle(s.enabled ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(s.label.isEmpty ? "Awake window" : s.label).font(.callout)
                        if s.enabled, chargeLimit.activeAwakeSchedule?.id == s.id { activeBadge() }
                    }
                    Text(s.scheduleSummary)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enable this Always Active window", isOn: Binding(
                    get: { s.enabled },
                    set: { var c = s; c.enabled = $0; chargeLimit.updateAwakeSchedule(c) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule

    private var scheduleTab: some View {
        tab {
            if chargeLimit.daemonAvailable {
                proGate {
                    card("Charging schedules") {
                        if chargeLimit.schedules.isEmpty {
                            infoRow("None yet. A schedule charges, holds or discharges on a weekly timetable.",
                                    systemImage: "clock")
                        } else {
                            ForEach(chargeLimit.schedules) { s in
                                scheduleRow(s)
                                divider
                            }
                        }
                        HStack {
                            Button {
                                editingIsNew = true
                                editingSchedule = ChargeSchedule()
                            } label: { Label("Add Schedule", systemImage: "plus") }
                                .controlSize(.small)
                            Spacer()
                        }
                        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                    }

                    card("Always Active hours") {
                        if chargeLimit.keepAwakeSchedules.isEmpty {
                            infoRow("None set. Always Active holds whenever its switch is on.",
                                    systemImage: "clock")
                        } else {
                            ForEach(chargeLimit.keepAwakeSchedules) { window in
                                awakeScheduleRow(window)
                                divider
                            }
                            if !chargeLimit.keepAwake {
                                infoRow("Always Active is off, so these hours do nothing yet.",
                                        systemImage: "info")
                                divider
                            }
                        }
                        HStack {
                            Button {
                                editingAwakeIsNew = true
                                editingAwakeSchedule = AwakeSchedule()
                            } label: { Label("Add Hours", systemImage: "plus") }
                                .controlSize(.small)
                            Spacer()
                        }
                        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                    }

                    card("Ready by") {
                        toggleRow("Charge to a target by a set time",
                                  "Holds overnight, then tops up to be ready on time.",
                                  isOn: Binding(
                                    get: { chargeLimit.readyBy.enabled },
                                    set: { chargeLimit.readyBy.enabled = $0; chargeLimit.apply() }))
                        if chargeLimit.readyBy.enabled {
                            divider
                            HStack {
                                Text("Ready by").font(.callout)
                                Spacer()
                                DatePicker("Ready-by time", selection: Binding(
                                    get: { ClockTime.date(fromMinute: chargeLimit.readyBy.targetMinute) },
                                    set: { chargeLimit.readyBy.targetMinute = ClockTime.minute(from: $0); chargeLimit.apply() }),
                                    displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            }
                            .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                            divider
                            stepperRow("Charge to",
                                       value: "\(chargeLimit.readyBy.targetPercent)%",
                                       binding: Binding(
                                        get: { Double(chargeLimit.readyBy.targetPercent) },
                                        set: { chargeLimit.readyBy.targetPercent = Int($0); chargeLimit.apply() }),
                                       range: 50...100)
                            divider
                            VStack(alignment: .leading, spacing: 8) {
                                Text("On these days").font(.callout)
                                WeekdayPicker(days: Binding(
                                    get: { chargeLimit.readyBy.days },
                                    set: { chargeLimit.readyBy.days = $0; chargeLimit.apply() }))
                            }
                            .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                        }
                    }

                    card("Charge power") {
                        chargePowerRow
                    }
                }
            } else {
                helperCard
            }
        }
    }

    private func scheduleRow(_ s: ChargeSchedule) -> some View {
        Button {
            editingIsNew = false
            editingSchedule = s
        } label: {
            HStack(spacing: 10) {
                Image(systemName: scheduleIcon(s.action))
                    .frame(width: 22)
                    .foregroundStyle(s.enabled ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(s.label.isEmpty ? s.action.title : s.label)
                            .font(.callout)
                        if chargeLimit.activeSchedule?.id == s.id { activeBadge() }
                    }
                    Text("\(s.windowLabel()) · \(s.days.summary)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enable this charging schedule", isOn: Binding(
                    get: { s.enabled },
                    set: { var c = s; c.enabled = $0; chargeLimit.updateSchedule(c) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func scheduleIcon(_ a: ScheduleAction) -> String {
        switch a {
        case .charge: return "bolt.fill"
        case .hold: return "pause.fill"
        case .discharge: return "battery.25"
        }
    }

    // MARK: - Automation

    /// Condition-driven rules: apply a charging or power setting while something
    /// is true of the Mac, and put it back when it stops being true.
    private var automationTab: some View {
        tab {
            if chargeLimit.daemonAvailable {
                proGate {
                    card("Rules") {
                        if triggers.rules.isEmpty {
                            infoRow("None yet. A rule applies a setting while something is true, and undoes it after.",
                                    systemImage: "wand")
                            divider
                        } else {
                            ForEach(triggers.rules) { rule in
                                TriggerRuleRow(store: triggers, rule: rule) {
                                    editingRuleIsNew = false
                                    editingRule = rule
                                }
                                divider
                            }
                        }
                        HStack(spacing: 10) {
                            Button {
                                editingRuleIsNew = true
                                editingRule = TriggerRule()
                            } label: {
                                HStack(spacing: 5) {
                                    HugeIcon("plus", size: 12)
                                    Text("Add Rule")
                                }
                            }
                            .controlSize(.small)

                            Menu("Start from an example") {
                                ForEach(TriggerStore.templates) { template in
                                    Button(template.label) {
                                        // A fresh id, so the same example can be
                                        // added more than once.
                                        var rule = template
                                        rule.id = UUID()
                                        editingRuleIsNew = true
                                        editingRule = rule
                                    }
                                }
                            }
                            .controlSize(.small)
                            .fixedSize()

                            Spacer()
                        }
                        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                    }

                    if needsLocationForWiFiRule {
                        card("Permission needed") {
                            infoRow("macOS treats the network name as location data. Allow Location access to match on Wi-Fi.",
                                    systemImage: "location")
                            divider
                            HStack {
                                Button("Grant Location Access…") { network.requestLocationAccess() }
                                    .controlSize(.small)
                                Spacer()
                            }
                            .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                        }
                    }

                    card("Right now") {
                        TriggerLiveStateView(store: triggers)
                    }
                }
            } else {
                helperCard
            }
        }
    }

    /// A Wi-Fi rule is set up, but macOS won't hand over the network name yet.
    private var needsLocationForWiFiRule: Bool {
        !network.locationAuthorized && triggers.rules.contains { rule in
            rule.enabled && rule.conditions.contains { $0.kind == .wifiNetwork }
        }
    }

    // MARK: - Sleep & Power

    private var sleepPowerTab: some View {
        tab {
            proGate {
                // The closed-lid section is deliberately one thing, not three. It used to
                // be a "deep sleep" picker, a "super save" switch and a pair of radio
                // checkboxes — all aimed at the same outcome, none of them sufficient
                // alone, and easy to leave half-set. `SealedSleepPanel` carries its own
                // group styling, so it sits directly in the tab rather than in a `card`.
                SealedSleepPanel(chargeLimit: chargeLimit, automation: automation)
                    .padding(.horizontal, rowInset)

                // Clamshell: the switch that means "I'm shutting the lid and I want the
                // Mac to carry on", put where someone looking for lid behaviour will look.
                // The individual knobs it sets — Always Active and its battery permission
                // — stay on the Charging tab, where they belong among the other holds;
                // this is the one control that sets them as the pair they have to be.
                card("Work with the lid closed") {
                    toggleRow("Clamshell mode",
                              "Shut the lid and the Mac keeps running: builds, downloads, a sync, an external display. The built-in screen goes dark; nothing else stops.",
                              isOn: Binding(
                                get: { ClamshellMode.isOn(charge: chargeLimit) },
                                set: { ClamshellMode.set($0, charge: chargeLimit, caffeine: caffeine) }))
                    if ClamshellMode.isOn(charge: chargeLimit) {
                        divider
                        toggleRow("Keep going on battery",
                                  "On by default: a lid-closed mode that ends the moment you unplug isn't one. Off lets the Mac sleep as soon as the charger comes out.",
                                  isOn: bind(\.keepAwakeOnBattery))
                        divider
                        infoRow(clamshellHint, systemImage: "laptop")
                    }
                }

                card("When the lid closes") {
                    toggleRow("Turn off Wi-Fi", isOn: $automation.wifiOffOnLidClose)
                    divider
                    toggleRow("Turn off Bluetooth", isOn: $automation.bluetoothOffOnLidClose)
                    divider
                    toggleRow("Restore Wi-Fi & Bluetooth on wake", isOn: $automation.restoreOnWake)
                    if chargeLimit.sealedSleep {
                        divider
                        infoRow("Sealed Sleep holds these on. Turning it off hands them back.",
                                systemImage: "lock")
                    }
                }
                .disabled(chargeLimit.sealedSleep)
                .opacity(chargeLimit.sealedSleep ? 0.55 : 1)

                card("Rest without closing the lid") {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rest now").font(.callout)
                            Text(idleSaver.resting
                                 ? "Resting. The screen is off and settings are held. Touch anything to come back."
                                 : "Screen and keyboard backlight off, and the settings below applied, without shutting the lid.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Button(idleSaver.resting ? "Wake" : "Rest Now") {
                            idleSaver.resting ? idleSaver.wake() : idleSaver.restNow()
                        }
                        .controlSize(.small)
                    }
                    .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                    divider
                    toggleRow("Rest automatically when I'm away",
                              "Waits for no input at all, and holds off during calls, films and games.",
                              isOn: $idleSaver.autoEnabled)
                    if idleSaver.autoEnabled {
                        if let waiting = idleSaver.waitingBecause {
                            divider
                            infoRow("You've been away long enough to rest, but \(waiting). Resting will start once that stops.",
                                    systemImage: "info")
                        }
                        divider
                        stepperRow("After",
                                   value: "\(idleSaver.afterMinutes) min",
                                   binding: Binding(
                                    get: { Double(idleSaver.afterMinutes) },
                                    set: { idleSaver.afterMinutes = max(5, Int($0)) }),
                                   range: 5...120)
                        divider
                        stepperRow("Then sleep after",
                                   value: idleSaver.sleepAfterMinutes > 0
                                        ? "\(idleSaver.sleepAfterMinutes) min more" : "Never",
                                   binding: Binding(
                                    get: { Double(idleSaver.sleepAfterMinutes) },
                                    set: { idleSaver.sleepAfterMinutes = max(0, Int($0)) }),
                                   range: 0...180)
                    }
                    divider
                    toggleRow("Low Power Mode while resting",
                              "Put back when you return.",
                              isOn: $idleSaver.lowPowerWhileResting)
                    divider
                    toggleRow("Wi-Fi and Bluetooth off while resting",
                              "Off by default: losing the network mid-call costs more than it saves.",
                              isOn: $idleSaver.radiosOffWhileResting)
                    divider
                }

                card("Caffeine (keep awake now)") {
                    infoRow(caffeineStateHint, systemImage: "coffee")
                    divider
                    toggleRow("End it when I unplug",
                              "Caffeine stops the moment you switch to battery.",
                              isOn: $settings.caffeineEndOnBattery)
                    if !settings.caffeineEndOnBattery {
                        divider
                        toggleRow("Keep the screen on when on battery",
                                  "On by default: on the charger the screen is held either way. Off lets it sleep and lock while tasks keep running, which saves several watts.",
                                  isOn: $settings.caffeineKeepDisplayOnBattery)
                    }
                }

                if chargeLimit.daemonAvailable {
                    powerToggleCard("On Battery", category: .batteryOptions)

                    // Sealed Sleep holds these off and the daemon keeps them that way, so
                    // leaving them live would offer switches that flip back — worse than
                    // no switch at all. Greyed, with the reason, and one place to undo it.
                    VStack(alignment: .leading, spacing: DS.Space.s) {
                        powerToggleCard("Wake while closed", category: .sleepWake)
                            .disabled(chargeLimit.sealedSleep)
                            .opacity(chargeLimit.sealedSleep ? 0.55 : 1)
                        if chargeLimit.sealedSleep {
                            Text("Sealed Sleep holds these off. Turn it off above to get them back.")
                                .font(.caption2).foregroundStyle(.secondary)
                                .padding(.leading, DS.Space.xs)
                        }
                    }

                    card("Power") {
                        toggleRow("Low Power Mode",
                                  "Also lowers the refresh rate on ProMotion Macs.",
                                  isOn: Binding(
                                    get: { chargeLimit.lowPowerMode },
                                    set: { chargeLimit.setLowPowerMode($0) }))
                    }

                    networkCard
                }
            }
        }
    }

    // MARK: - Network profiles

    private var networkCard: some View {
        card("Network profiles") {
            toggleRow("Switch mode by Wi-Fi network",
                      "Pick a save mode from the network you join.",
                      isOn: Binding(get: { network.enabled },
                                    set: { network.enabled = $0 }))
            if network.enabled {
                divider
                labelRow("Current network", network.currentSSID ?? "Not connected")
                if !network.locationAuthorized {
                    divider
                    infoRow("Allow Location access in System Settings › Privacy & Security.",
                            systemImage: "location.slash")
                }
                divider
                ForEach(network.profiles) { p in
                    HStack(spacing: 10) {
                        Image(systemName: "wifi").frame(width: 20).foregroundStyle(.tint)
                        Text(p.ssid).font(.callout).lineLimit(1)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { p.mode },
                            set: { m in
                                if let i = network.profiles.firstIndex(where: { $0.id == p.id }) {
                                    network.profiles[i].mode = m
                                }
                            })) {
                            ForEach(SaveMode.allCases) { Text($0.title).tag($0) }
                        }
                        .labelsHidden().frame(width: 130)
                        Button {
                            network.removeProfile(p)
                        } label: { Image(systemName: "minus.circle.fill") }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s)
                    divider
                }
                HStack {
                    Button {
                        if let ssid = network.currentSSID {
                            network.addProfile(ssid: ssid, mode: chargeLimit.mode)
                        }
                    } label: { Label("Add current network", systemImage: "plus") }
                        .controlSize(.small)
                        .disabled(network.currentSSID == nil)
                    Spacer()
                }
                .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s)
            }
        }
    }

    // MARK: - General

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        tab {
            card("Global Shortcuts") {
                toggleRow("Enable keyboard shortcuts",
                          "Works from any app. eWiz claims only the combinations below.",
                          isOn: $hotkeys.enabled)
                if let displacedNote {
                    divider
                    infoRow(displacedNote, systemImage: "info")
                }
            }

            ForEach(HotkeyAction.Category.allCases) { category in
                card(category.title) {
                    let actions = HotkeyAction.inCategory(category)
                    ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                        if index > 0 { divider }
                        shortcutRow(action)
                    }
                }
            }

            HStack {
                Button("Reset to Defaults") {
                    recordingAction = nil
                    displacedNote = nil
                    hotkeys.resetToDefaults()
                }
                .disabled(hotkeys.bindings.isDefault)
                Spacer()
                Text("⌫ removes a shortcut · ⎋ cancels")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        // Recording grabs the keyboard, so it must not survive leaving the tab.
        .onChange(of: selection) { _, _ in recordingAction = nil }
    }

    private func shortcutRow(_ action: HotkeyAction) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HugeIcon(action.icon, size: 16, weight: 2)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title).font(.callout)
                if !action.subtitle.isEmpty {
                    Text(action.subtitle).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // A global grab beats the frontmost app to the keystroke, so a chord built
                // only from ⌘ and ⇧ takes it away from every app that uses it.
                if let key = hotkeys.bindings.hotkey(for: action), key.collidesWithAppShortcuts {
                    Text("\(key.displayString) has no ⌃ or ⌥, so eWiz takes it from every app that uses it: ⌘D stops being Duplicate, ⇧⌘D stops being Send.")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            HotkeyRecorderField(
                hotkey: hotkeys.bindings.hotkey(for: action),
                isRecording: recordingAction == action,
                unavailable: hotkeys.unavailable.contains(action),
                onBegin: { recordingAction = action },
                onCapture: { key in
                    let displaced = hotkeys.set(key, for: action)
                    displacedNote = displaced.map {
                        "\(key.displayString) moved to “\(action.title)”. “\($0.title)” now has no shortcut."
                    }
                    recordingAction = nil
                },
                onCancel: { recordingAction = nil },
                onClear: {
                    hotkeys.clear(action)
                    recordingAction = nil
                })
        }
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
        .opacity(hotkeys.enabled ? 1 : 0.5)
        .disabled(!hotkeys.enabled)
    }

    private var generalTab: some View {
        tab {
            helperCard

            card("Menu Bar") {
                pickerRow("Pick how the battery looks in the menu bar. The fill tracks your exact charge.") {
                    BatteryStylePicker(selection: $settings.batteryIconStyle,
                                       percentage: battery.snapshot.percentage)
                }
                divider
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show").font(.callout)
                        Text("Time remaining is time to full while charging, time to empty on battery.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Picker("", selection: $settings.menuBarDisplay) {
                        ForEach(MenuBarDisplay.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden().frame(width: 160)
                }
                .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                divider
                toggleRow("Color icon by charge state",
                          "Green charging, red when low or warm.",
                          isOn: $settings.colorMenuBarIcon)
                divider
                toggleRow("Animate the icon while charging",
                          "Costs about a tenth of a core while plugged in.",
                          isOn: $settings.animateMenuBarIcon)
                divider
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shake when the battery runs low").font(.callout)
                        Text("A short tremble at 20%, then every 20 seconds under 10%.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Preview") {
                        NotificationCenter.default.post(name: .ewizPreviewLowBatteryShake, object: nil)
                    }
                    .controlSize(.small)
                    Toggle("", isOn: $settings.shakeOnLowBattery)
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }
                .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
            }

            card("Notifications") {
                toggleRow("Notify me about charge events",
                          "Limit reached, paused for heat, low battery, fully charged.",
                          isOn: Binding(
                            get: { settings.notificationsEnabled },
                            set: { on in
                                settings.notificationsEnabled = on
                                if on { notifier.enableRequested() }
                            }))
                divider
                toggleRow("Suggest an occasional restart",
                          "Reminds you after a week of uptime.",
                          isOn: Binding(
                            get: { settings.restReminderEnabled },
                            set: { settings.restReminderEnabled = $0 }))
                if settings.notificationsEnabled {
                    divider
                    HStack {
                        Text("Test").font(.callout)
                        Spacer()
                        Button("Send Test Notification") { notifier.sendTest() }
                            .controlSize(.small)
                    }
                    .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                }
            }

                card("Plug-in feedback (experimental)") {
                    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                        toggleRow("Animate anyway",
                                  "Reduce Motion is on. eWiz's animations stay off unless you allow them.",
                                  isOn: $settings.animateWithReduceMotion)
                        divider
                    }
                    toggleRow("Tap the trackpad when you plug in",
                              "Two taps on connect, one on unplug, three at the limit.",
                              isOn: $settings.hapticsEnabled)
                    divider
                    toggleRow("Play a sound when you plug in",
                              "A short cue on connect, a smaller one on unplug.",
                              isOn: $settings.soundEnabled)
                    if settings.soundEnabled {
                        divider
                        HStack(spacing: 10) {
                            Text("Sound").font(.callout)
                            Spacer(minLength: DS.Space.s)
                            // Plays on change. Choosing a sound by reading five words is
                            // not choosing a sound.
                            Picker("", selection: Binding(
                                get: { settings.soundTheme },
                                set: {
                                    settings.soundTheme = $0
                                    ChargeSound.play(.connect, volume: settings.soundVolume,
                                                     theme: $0)
                                }
                            )) {
                                ForEach(ChargeSound.Theme.allCases) {
                                    Text($0.displayName).tag($0)
                                }
                            }
                            .labelsHidden().fixedSize()
                        }
                        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                        divider
                        HStack(spacing: 10) {
                            Text("Volume").font(.callout)
                            Slider(value: $settings.soundVolume, in: 0.05...1)
                                .controlSize(.small)
                            Text("\(Int(settings.soundVolume * 100))%")
                                .font(.callout).monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                            Menu("Test") {
                                Button("Plugged in") {
                                    ChargeSound.play(.connect, volume: settings.soundVolume,
                                                     theme: settings.soundTheme)
                                }
                                Button("Unplugged") {
                                    ChargeSound.play(.disconnect, volume: settings.soundVolume,
                                                     theme: settings.soundTheme)
                                }
                                Button("Charge complete") {
                                    ChargeSound.play(.complete, volume: settings.soundVolume,
                                                     theme: settings.soundTheme)
                                }
                            }
                            .menuStyle(.borderlessButton)
                            .controlSize(.small)
                            .fixedSize()
                        }
                        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                    }
                    divider
                    if ChargeOverlayFeature.shipped {
                        toggleRow("Show an animation when you plug in",
                                  "Flashes for about a second, then gets out of the way.",
                                  isOn: $settings.chargeOverlayEnabled)
                    } else {
                        comingSoonRow("Show an animation when you plug in",
                                      "Being rebuilt. It plays over whatever you're doing, so it ships when it's right.")
                    }
                    if ChargeOverlayFeature.shipped, settings.chargeOverlayEnabled {
                        divider
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Animation").font(.callout)
                                Spacer()
                                Picker("", selection: $settings.chargeOverlayStyle) {
                                    ForEach(ChargeOverlayStyle.allCases) {
                                        Text($0.displayName).tag($0)
                                    }
                                }
                                .labelsHidden().frame(width: 160)
                                Button("Preview") {
                                    overlay.show(style: settings.chargeOverlayStyle,
                                                 duration: settings.chargeOverlayDuration,
                                                 percentage: battery.snapshot.percentage,
                                                 allowMotion: settings.motionAllowed)
                                }
                                .controlSize(.small)
                            }
                            Text(settings.chargeOverlayStyle.summary)
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if settings.chargeOverlayStyle == .custom {
                                let count = ChargeFrameSequence.frameURLs().count
                                HStack(spacing: 8) {
                                    Button("Reveal Frames Folder…") {
                                        ChargeFrameSequence.revealInFinder()
                                    }
                                    .controlSize(.small)
                                    Text(count == 0
                                         ? "No frames yet. The dot grid plays until you add some."
                                         : "\(count) frame\(count == 1 ? "" : "s") found, played in filename order.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Text("Export a numbered image sequence (frame_001.png, frame_002.png, …) from Rive, Lottie or After Effects. Up to \(ChargeFrameSequence.maxFrames) frames, scaled to fit and centred. No plug-in or runtime needed.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                        divider
                        stepperRow("How long",
                                   value: String(format: "%.1f s", settings.chargeOverlayDuration),
                                   binding: Binding(
                                    get: { settings.chargeOverlayDuration * 10 },
                                    set: { settings.chargeOverlayDuration = ($0.rounded() / 10) }),
                                   range: 5...20)
                        divider
                        toggleRow("Play it when you unplug too",
                                  "The same animation in a cooler colour.",
                                  isOn: $settings.chargeOverlayOnUnplug)
                    }
                }

            card("Startup") {
                toggleRow("Launch at login", isOn: Binding(
                    get: { startup.launchAtLogin },
                    set: { startup.setLaunchAtLogin($0) }))
                if startup.requiresApproval {
                    divider
                    infoRow("Approve eWiz in System Settings › General › Login Items.",
                            systemImage: "exclamationmark.triangle.fill")
                }
            }

            card("System") {
                labelRow("Lid", automation.isLidClosed ? "Closed · clamshell" : "Open")
                if let s = automation.lastLidSession {
                    divider
                    labelRow("Last closed", lastClosedText(s))
                }
            }

            card("Updates") {
                if let update = updater.available {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Update available · v\(update.version)")
                                .font(.callout.weight(.medium))
                            Text("You have v\(updater.currentVersion)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(updater.installing ? "Installing…" : "Update Now") {
                            updater.installUpdate()
                        }
                        .disabled(updater.installing)
                    }
                    .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                } else {
                    HStack {
                        Button(updater.checking ? "Checking…" : "Check for Updates…") {
                            updater.check(userInitiated: true)
                        }
                        .disabled(updater.checking)
                        Spacer()
                        Text("v\(updater.currentVersion)")
                            .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
                }
            }
        }
    }

    // MARK: - Layout scaffolding

    /// The column every tab's content sits in.
    ///
    /// `contentWidth` is the fix for what taking the group boxes away exposed. The window
    /// is as wide as seven tabs need it to be, and with the boxes gone every row stretched
    /// to that full width — so a switch ended up five hundred points from the label it
    /// belongs to, with nothing in between. Proximity is what pairs a control with its
    /// name, and a box was doing that job by accident; a measured column does it on purpose.
    ///
    /// `Space.l` between groups, not `Space.xl`. The larger value was chosen when a filled
    /// box was also marking each boundary; without one, the same gap just reads as a hole.
    private func tab<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) { content() }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.vertical, DS.Space.l)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
    }

    /// Narrower than the window on purpose — see `tab`.
    private let contentWidth: CGFloat = 468

    @ViewBuilder
    private func proGate<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        // Matches `tab`'s own spacing. Two different values here meant the gap between
        // groups changed depending on whether the pro gate happened to wrap them.
        VStack(alignment: .leading, spacing: DS.Space.l) { content() }
            .disabled(!license.isPro)
            .opacity(license.isPro ? 1 : 0.45)
    }

    /// A titled group of rows: an uppercase label, then the rows, separated by hairlines.
    ///
    /// No surface. Every group used to sit in a filled, bordered, shadowed box, and this
    /// window has twenty-five of them — several wrapping a single switch, which is a box
    /// drawn around one thing. Worse, the box and the label were doing the same job twice:
    /// the heading already says where the group starts, so the border is a second boundary
    /// announcing the same fact, and a column of them reads as a stack of containers rather
    /// than as a page of settings.
    ///
    /// What separates groups now is space and the label — `better-layout`'s order, space
    /// first and background shapes second. The tab puts `Space.xl` between groups against
    /// nothing between rows inside one, which clears the 2× rule comfortably.
    ///
    /// The label is inset to `rowInset` rather than hugging the edge, so it starts on the
    /// same vertical line as the row text beneath it. With the box gone, that shared edge
    /// is the only thing left holding the group together, and one stray indent undoes it.
    private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            DSSectionLabel(title: title)
                .padding(.leading, rowInset)
                // A heading belongs to what comes *after* it, and the gaps have to say so.
                // Rows carry their own vertical padding, so the bare `Space.l` between
                // groups left roughly 16pt above each label against 14pt below it — near
                // enough to equal that the label read as floating between two groups
                // rather than introducing one. This buys the gap above a clear margin.
                .padding(.top, DS.Space.s)
            VStack(spacing: 0) { content() }
        }
    }

    /// The one horizontal inset every row and every group label uses.
    private let rowInset = DS.Space.m

    private var divider: some View { DSSeparator() }

    private func powerToggleCard(_ title: String, category: PowerToggle.Category) -> some View {
        let toggles = PowerToggle.allCases.filter { $0.category == category }
        return card(title) {
            ForEach(Array(toggles.enumerated()), id: \.element) { index, toggle in
                if index > 0 { divider }
                toggleRow(toggle.title, toggle.hint, isOn: Binding(
                    get: { chargeLimit.isPowerToggleOn(toggle) },
                    set: { chargeLimit.setPowerToggle(toggle, $0) }))
            }
        }
    }

    // MARK: - Helper management

    private var helperCard: some View {
        card("Helper") {
            VStack(alignment: .leading, spacing: 10) {
                Label(helperStatus.title, systemImage: helperStatus.icon)
                    .font(.callout)
                    .foregroundStyle(helperStatus.installed ? Color.primary : .secondary)
                Text(helperStatus.detail)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if HelperInstaller.canInstall {
                    HStack(spacing: 8) {
                        Button(chargeLimit.daemonAvailable ? "Reinstall Helper…" : "Install Helper…") {
                            installHelper()
                        }
                        if chargeLimit.daemonAvailable {
                            Button("Uninstall…", role: .destructive) { uninstallHelper() }
                        }
                    }
                } else {
                    Text("Run scripts/install-helper.sh from the source checkout.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                // A cancelled automatic install is reported here too, so the reason the
                // helper is still missing is visible next to the button that fixes it.
                if let message = installError ?? chargeLimit.helperInstallFailure {
                    Text(message).font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true).lineLimit(3)
                }
            }
            .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
        }
    }

    private var helperStatus: (title: String, detail: String, icon: String, installed: Bool) {
        if chargeLimit.helperInstalling {
            return ("Installing…",
                    "Approve the administrator prompt to finish. This is asked once. After that the helper starts at boot and keeps itself current.",
                    "arrow.down.circle", false)
        }
        if !chargeLimit.daemonAvailable {
            return ("Not installed",
                    "The root helper enforces the charge limit, heat pause, and sleep settings. Install it once to enable them. It runs at boot on its own.",
                    "exclamationmark.triangle.fill", false)
        }
        if chargeLimit.daemonOutdated {
            return ("Update required",
                    "A newer helper ships with this app. Reinstall it so pause/resume and the latest features work.",
                    "arrow.triangle.2.circlepath", true)
        }
        return ("Installed and running",
                "Enforcing your charge policy in the background. It re-enables charging if ever stopped.",
                "checkmark.circle.fill", true)
    }

    private func installHelper() {
        installError = nil
        let result = HelperInstaller.install()
        if result.ok {
            chargeLimit.clearAutoInstallRefusal()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { chargeLimit.refresh() }
        } else {
            installError = result.message
        }
    }

    private func uninstallHelper() {
        installError = nil
        chargeLimit.suppressAutoInstall()
        // A bundle-registered daemon was never written to /Library/LaunchDaemons, so the
        // script can't see it and unregistering is the only thing that stops it. Conversely
        // the script costs an admin prompt, so it only runs when there's a legacy install
        // for it to remove.
        HelperService.unregisterBundledDaemon()
        let result = HelperService.legacyInstallPresent
            ? HelperInstaller.uninstall()
            : (ok: true, message: "Helper removed.")
        if result.ok {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { chargeLimit.refresh() }
        } else {
            installError = result.message
        }
    }

    // MARK: - Rows

    /// A real `Toggle` carrying its own label, rather than a `Text` sitting next to a
    /// `Toggle("")`.
    ///
    /// Two things come free from doing it the platform's way, and both were missing.
    /// The switch gets an accessible name — an unlabelled `Toggle("")` announces itself to
    /// VoiceOver as a switch and nothing else, so every setting in this window was a row
    /// of anonymous switches. And the label becomes part of the control, so clicking the
    /// text flips it; before, the words were dead space and only the 30pt switch worked.
    ///
    /// The switch sits centred against the label, which is what `Toggle` does on its own.
    ///
    /// It was pinned to the first line for a while, via an `alignmentGuide` that redefined
    /// the row's own centre. That was the wrong tool and it broke the page: the guide moves
    /// the row within its parent stack, so rows overlapped their neighbours and the hairline
    /// between two of them came out drawn through the middle of a subtitle.
    ///
    /// The reason for pinning it is gone anyway. It was there because some subtitles ran
    /// four and five lines, and a switch floating halfway down a paragraph doesn't read as
    /// belonging to the sentence at the top. Those subtitles are one line now.
    private func toggleRow(_ title: String, _ subtitle: String? = nil,
                           isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, DS.Space.s)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
        .frame(minHeight: 34)
    }

    private func stepperRow(_ title: String, value: String,
                            binding: Binding<Double>, range: ClosedRange<Double>) -> some View {
        Stepper(value: binding, in: range, step: 1) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text(value).font(.callout).fontWeight(.semibold).monospacedDigit()
            }
        }
        .controlSize(.small)
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
        .frame(minHeight: 34)
    }

    /// Applies on release so dragging doesn't spam the daemon.
    private var chargePowerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Power to the battery").font(.callout)
                Spacer()
                Text(chargeLimit.chargePower == 0 ? "Off" : "\(chargeLimit.chargePower)%")
                    .font(.callout.weight(.semibold)).monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(chargeLimit.chargePower) },
                    set: { chargeLimit.chargePower = Int($0) }
                ),
                in: 0...100, step: 5,
                onEditingChanged: { $0 ? chargeLimit.beginEditing() : chargeLimit.endEditing() }
            )
            .controlSize(.small)
            // Charge Power works by switching the SMC charge key on and off. Without the
            // key the slider moved, the caption promised "about 15%", and the battery took
            // the full 30 W regardless.
            .disabled(!chargeLimit.chargePowerSupported)

            liveSplitReadout

            Text(chargeLimit.chargePowerSupported
                 ? "How much of the charger goes to the battery rather than to your Mac. Lower is cooler and slower; 0% holds the battery entirely."
                 : "Not available on this Mac. macOS 26.7 doesn't let apps control charging speed, so the battery always charges at full power. The charge limit still works, from 80%.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
    }

    @ViewBuilder
    private var liveSplitReadout: some View {
        let f = battery.powerFlow
        let cycling = chargeLimit.chargePowerSupported
            && chargeLimit.chargePower > 0 && chargeLimit.chargePower < 100
        if f.isPluggedIn {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    wattStat(.green, cycling ? "Into battery (now)" : "Into battery", f.chargeWatts)
                    wattStat(.orange, "To your Mac", max(0, f.systemWatts ?? 0))
                    Spacer()
                    if let a = f.adapterWatts {
                        Text(String(format: f.isMeasured ? "Adapter in %.0f W" : "Adapter %.0f W", a))
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                if cycling {
                    Text("Charging runs in long on/off cycles, so this reads full or zero, averaging about \(chargeLimit.chargePower)%.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // No fill. It was the last boxed thing on a page that no longer boxes
            // anything, which made a live readout look like the one setting worth framing.
            .padding(.vertical, DS.Space.xs)
        } else {
            Text("On battery. Plug in the charger to see the live power split.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func wattStat(_ color: Color, _ label: String, _ w: Double) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(String(format: "%.1f W", w))
                    .font(.callout.weight(.semibold)).monospacedDigit()
            }
        }
    }

    private func pickerRow<Content: View>(_ hint: String,
                                          @ViewBuilder _ content: () -> Content) -> some View {
        // Width was the bug here: with no `Spacer` and no explicit width, the stack sized
        // itself to the segmented control and the group around it came out visibly
        // narrower than every other group on the page.
        VStack(alignment: .leading, spacing: DS.Space.s - 2) {
            content()
            Text(hint).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
    }

    /// Label on the left, value on the right. Values are always tabular: these rows sit in
    /// vertical runs, and proportional digits make a column of numbers ripple as they
    /// change — the one place where the type is doing visible harm.
    private func labelRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }
        .font(.callout)
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
        .frame(minHeight: 34)
    }

    private func infoRow(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text).font(.caption).fixedSize(horizontal: false, vertical: true)
        } icon: {
            HugeIcon(systemImage, size: DS.Icon.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, rowInset).padding(.vertical, DS.Space.s + 2)
    }

    // MARK: - Helpers

    private var keepAwakeProcessText: Binding<String> {
        Binding(
            get: { chargeLimit.keepAwakeProcesses.joined(separator: ", ") },
            set: {
                chargeLimit.keepAwakeProcesses = $0
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                chargeLimit.apply()
            })
    }

    /// Binding that re-applies the policy on change.
    /// A setting that isn't here yet, said once and without ceremony.
    ///
    /// Left in place rather than removed: a control that vanishes reads as a feature that was
    /// taken away, and someone who turned the animation on in the last build deserves to know
    /// where it went and that it's coming back.
    private func comingSoonRow(_ title: String, _ detail: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout).foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Space.s)
            Text("Next version")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
        }
        .padding(.horizontal, rowInset)
        .padding(.vertical, DS.Space.s + 2)
    }

    private func bind(_ keyPath: ReferenceWritableKeyPath<ChargeLimitStore, Bool>) -> Binding<Bool> {
        Binding(
            get: { chargeLimit[keyPath: keyPath] },
            set: { chargeLimit[keyPath: keyPath] = $0; chargeLimit.apply() })
    }

    /// What the mode is doing right now, and — on battery — what it costs. The warning is
    /// the point: a Mac held awake in a bag is the single most expensive mistake this app
    /// can help someone make, and the cutoff that stops it lives on another tab.
    private var clamshellHint: String {
        guard chargeLimit.keepAwakeOnBattery else {
            return "Holding only while plugged in. Unplug and the Mac sleeps as usual when the lid shuts."
        }
        if battery.snapshot.onExternalPower {
            return "Holding. Shut the lid whenever you like; it keeps going on battery too."
        }
        if chargeLimit.keepAwakeMaxTempC > 0 {
            return "Holding on battery. It drains fast; the Mac sleeps if it passes \(Int(chargeLimit.keepAwakeMaxTempC))\u{00A0}°C."
        }
        return "Holding on battery. It drains fast and runs hot with the lid shut. Set a temperature cutoff under Charging › Enforcement."
    }

    private var magSafeHint: String {
        switch chargeLimit.magSafeLedMode {
        case .system: return "macOS controls the LED."
        case .status: return "Orange charging · green holding limit · off briefly after wake."
        case .off:    return "Keeps the MagSafe LED off."
        }
    }

    private func lastClosedText(_ s: LidSession) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        let ago = f.localizedString(for: s.openedAt, relativeTo: Date())
        let drop = s.dropPercent == 0 ? "no drop" : "−\(s.dropPercent)%"
        return "\(ago) · \(drop)"
    }
}

/// Mirrors the menu-bar rendering so what you pick is what you get.
struct BatteryStylePicker: View {
    @Binding var selection: BatteryIconStyle
    let percentage: Int

    @State private var hovering: BatteryIconStyle?

    /// A grid, not a row: nine styles in one line would squeeze each tile below the
    /// width its glyph needs to be recognisable.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(BatteryIconStyle.allCases) { style in
                let isSelected = style == selection
                let isHovering = hovering == style
                VStack(spacing: 6) {
                    Image(nsImage: BatteryIconRenderer.image(
                        style: style, percentage: previewPct, charging: false,
                        tint: .neutral, height: 22))
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                        .frame(height: 24)
                    Text(style.displayName)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.14)
                              : Color.secondary.opacity(isHovering ? 0.12 : 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
                .scaleEffect(isSelected ? 1.0 : (isHovering ? 1.04 : 1.0))
                .contentShape(Rectangle())
                .onHover { hovering = $0 ? style : (hovering == style ? nil : hovering) }
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.7)) { selection = style }
                }
                .help("\(style.displayName) battery")
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selection)
    }

    // Show a representative level so the styles are easy to tell apart even at 0%.
    private var previewPct: Int { max(35, min(100, percentage)) }
}
