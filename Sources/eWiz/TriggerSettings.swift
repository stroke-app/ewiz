import SwiftUI
import EWizKit

/// One row in the rules list: what it does, what it's waiting for, and whether
/// it's holding right now.
struct TriggerRuleRow: View {
    @ObservedObject var store: TriggerStore
    let rule: TriggerRule
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                HugeIcon(rule.action.icon, size: 17)
                    .frame(width: 22)
                    .foregroundStyle(rule.enabled ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(rule.displayName).font(.callout)
                        if store.isActive(rule) {
                            Text("ACTIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.green.opacity(0.25), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text("While \(rule.conditionSummary.lowercasedFirst) → \(rule.actionSummary)")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { rule.enabled },
                    set: { store.setEnabled($0, for: rule) }))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                HugeIcon("chevronRight", size: 12).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Live readout of everything the rules can watch. Doubles as the reference for
/// filling in a condition — the names shown here are the names to match.
struct TriggerLiveStateView: View {
    @ObservedObject var store: TriggerStore

    var body: some View {
        let s = store.snapshot
        VStack(spacing: 0) {
            row("Power", powerText(s))
            Divider().padding(.leading, 12)
            row("External displays", s.externalDisplays == 0
                ? "None" : "\(s.externalDisplays) connected")
            Divider().padding(.leading, 12)
            row("Wi-Fi", s.ssid ?? "Not joined (or no Location access)")
            Divider().padding(.leading, 12)
            row("IP address", list(s.ipAddresses, empty: "None"))
            Divider().padding(.leading, 12)
            row("VPN", s.vpnInterfaces.isEmpty
                ? "Not connected" : "Connected · \(s.vpnInterfaces.joined(separator: ", "))")
            Divider().padding(.leading, 12)
            row("Audio output", s.audioOutput.isEmpty ? "Unknown"
                : s.audioOutput + (s.audioOutputIsExternal ? "" : " (built-in)"))
            Divider().padding(.leading, 12)
            row("USB devices", list(s.usbDevices, empty: "None"))
            Divider().padding(.leading, 12)
            row("Bluetooth", store.observesBluetooth
                ? list(s.bluetoothDevices, empty: "None connected")
                : "Read when a rule uses it (needs Bluetooth access)")
            Divider().padding(.leading, 12)
            row("Volumes", list(s.externalVolumes, empty: "None mounted"))
            Divider().padding(.leading, 12)
            row("CPU", String(format: "%.0f%%", s.cpuPercent))
        }
        .onAppear { store.beginObserving() }
        .onDisappear { store.endObserving() }
    }

    private func powerText(_ s: TriggerSnapshot) -> String {
        let source = s.isCharging ? "Charging" : (s.isPluggedIn ? "Plugged in" : "On battery")
        return "\(source) · \(s.batteryPercent)%"
    }

    private func list(_ items: [String], empty: String) -> String {
        items.isEmpty ? empty : items.prefix(3).joined(separator: ", ")
            + (items.count > 3 ? " +\(items.count - 3)" : "")
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

/// Modal editor for one automation rule. Works on a local copy and commits via
/// `onSave`; `onDelete` is nil when adding.
struct TriggerRuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: TriggerStore
    @State private var draft: TriggerRule
    /// Snapshot of the running apps, taken once — the pick-list is read during
    /// every re-render, and enumerating the workspace per keystroke is wasteful.
    @State private var appNames: [String] = []
    let isNew: Bool
    let onSave: (TriggerRule) -> Void
    let onDelete: (() -> Void)?

    init(store: TriggerStore, rule: TriggerRule, isNew: Bool,
         onSave: @escaping (TriggerRule) -> Void, onDelete: (() -> Void)?) {
        self.store = store
        _draft = State(initialValue: rule)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isNew ? "New Rule" : "Edit Rule")
                .font(.title3.weight(.semibold))
                .padding(.bottom, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    conditionsSection
                    actionSection
                }
                .padding(.bottom, 4)
            }
            .frame(maxHeight: 420)
            .scrollIndicators(.automatic)

            Divider().padding(.vertical, 12)

            HStack {
                if let onDelete {
                    Button(role: .destructive) { onDelete(); dismiss() } label: {
                        HStack(spacing: 5) {
                            HugeIcon("delete", size: 13)
                            Text("Delete")
                        }
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(normalized(draft))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.conditions.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 520)
        .onAppear {
            store.beginObserving()
            appNames = TriggerSensors.runningAppNames()
        }
        .onDisappear { store.endObserving() }
    }

    // MARK: - Sections

    private var nameField: some View {
        HStack(spacing: 12) {
            Text("Name")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            TextField("e.g. Docked at my desk", text: $draft.label)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
        }
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("While").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                // Only meaningful once there's more than one condition to combine.
                if draft.conditions.count > 1 {
                    Picker("", selection: $draft.matchAll) {
                        Text("All are true").tag(true)
                        Text("Any is true").tag(false)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    .controlSize(.small)
                }
            }

            VStack(spacing: 0) {
                if draft.conditions.isEmpty {
                    Text("No conditions yet. Pick what eWiz should watch for. The rule applies the whole time it's true, and undoes itself when it stops.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 10)
                } else {
                    ForEach($draft.conditions) { $condition in
                        if condition.id != draft.conditions.first?.id {
                            Divider().padding(.leading, 12)
                        }
                        conditionRow($condition)
                    }
                }

                Divider().padding(.leading, 12)

                // Footer: add on the left, live verdict on the right.
                HStack(spacing: 8) {
                    Menu {
                        ForEach(TriggerKind.allCases) { kind in
                            Button(kind.title) {
                                draft.conditions.append(TriggerCondition(kind: kind))
                            }
                        }
                    } label: {
                        Text("Add Condition")
                    }
                    .fixedSize()
                    .controlSize(.small)

                    Spacer(minLength: 8)
                    matchesNowLine
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func conditionRow(_ condition: Binding<TriggerCondition>) -> some View {
        let kind = condition.wrappedValue.kind
        let holds = condition.wrappedValue.isSatisfied(by: store.snapshot)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                truthDot(holds)
                    .help(holds ? "True right now" : "Not true right now")

                Picker("", selection: condition.kind) {
                    ForEach(TriggerKind.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .onChange(of: condition.wrappedValue.kind) { _, new in
                    // Parameters don't carry across kinds.
                    condition.wrappedValue.text = ""
                    condition.wrappedValue.threshold = new.defaultThreshold
                }

                Spacer(minLength: 0)

                Toggle("Invert", isOn: condition.negated)
                    .toggleStyle(.button).controlSize(.small)
                    .help("Apply while this is NOT true")

                Button {
                    draft.conditions.removeAll { $0.id == condition.wrappedValue.id }
                } label: { HugeIcon("minus", size: 15) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Remove this condition")
            }

            if kind.usesThreshold || kind.usesText {
                HStack(spacing: 8) {
                    Spacer().frame(width: 20)
                    if kind.usesThreshold { thresholdField(condition, kind: kind) }
                    if kind.usesText { textField(condition, kind: kind) }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    private func thresholdField(_ condition: Binding<TriggerCondition>,
                                kind: TriggerKind) -> some View {
        let range = kind.thresholdRange
        return Stepper(value: Binding(
            get: { Double(condition.wrappedValue.threshold) },
            set: { condition.wrappedValue.threshold = Int($0) }),
                       in: Double(range.lowerBound)...Double(range.upperBound),
                       step: kind == .externalDisplay ? 1 : 5) {
            Text("\(condition.wrappedValue.threshold)\(kind.thresholdUnit)")
                .font(.callout).monospacedDigit()
        }
        .controlSize(.small)
        .fixedSize()
    }

    private func textField(_ condition: Binding<TriggerCondition>,
                           kind: TriggerKind) -> some View {
        HStack(spacing: 6) {
            TextField(kind.textPlaceholder, text: condition.text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
            let options = suggestions(for: kind)
            if !options.isEmpty {
                Menu {
                    ForEach(options, id: \.self) { option in
                        Button(option) { condition.wrappedValue.text = option }
                    }
                } label: {
                    Image(systemName: "list.bullet")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Pick from what's connected right now")
            }
        }
    }

    /// Values detected on this Mac right now, offered as a pick-list so the user
    /// doesn't have to guess how a device or network is named.
    private func suggestions(for kind: TriggerKind) -> [String] {
        let s = store.snapshot
        switch kind {
        case .appRunning, .appFrontmost: return appNames
        case .usbDevice:                 return s.usbDevices
        case .bluetoothDevice:           return s.bluetoothDevices
        case .ipAddress:                 return s.ipAddresses
        case .wifiNetwork:               return [s.ssid].compactMap { $0 }
        case .vpn:                       return s.vpnInterfaces
        case .audioOutput:               return s.audioOutput.isEmpty ? [] : [s.audioOutput]
        case .volumeMounted:             return s.externalVolumes
        default:                         return []
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Then").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HugeIcon(draft.action.icon, size: 16)
                        .frame(width: 20).foregroundStyle(Color.accentColor)
                    Picker("", selection: $draft.action) {
                        ForEach(TriggerAction.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)

                if draft.action.usesMode {
                    Divider().padding(.leading, 12)
                    HStack {
                        Text("Mode").font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $draft.mode) {
                            ForEach(SaveMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }

                if draft.action.usesPercent {
                    Divider().padding(.leading, 12)
                    HStack {
                        Text(draft.action == .chargeLimit ? "Limit" : "Power")
                            .font(.callout).foregroundStyle(.secondary)
                        Spacer()
                        Text(percentLabel)
                            .font(.callout.weight(.semibold)).monospacedDigit()
                        Stepper("", value: Binding(
                            get: { Double(draft.percent) },
                            set: { draft.percent = Int($0) }),
                                in: draft.action == .chargeLimit ? 0...100 : 0...100,
                                step: 5)
                        .labelsHidden().controlSize(.small)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                }

                Divider().padding(.leading, 12)
                Text(actionHint)
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
            .background(.quaternary.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var percentLabel: String {
        if draft.percent == 0 { return draft.action == .chargeLimit ? "Off" : "Hold" }
        return "\(draft.percent)%"
    }

    private var actionHint: String {
        switch draft.action {
        case .mode:
            return "Switches to \(draft.mode.title) while the rule holds, then restores the mode you were in."
        case .chargeLimit:
            return draft.percent == 0
                ? "Turns the charge limit off (charge to full) while the rule holds."
                : "Holds the battery at \(draft.percent)% while the rule holds, then restores your usual limit."
        case .holdCharging:
            return "Stops charging entirely while the rule holds: the battery neither charges nor is used, so the adapter runs your Mac."
        case .keepAwake:
            return "Keeps the Mac fully awake (lid open or closed) while the rule holds. Applies on AC power only."
        case .lowPowerMode:
            return "Turns Low Power Mode on while the rule holds, and back off afterwards."
        case .chargePower:
            return draft.percent == 0
                ? "Sends all adapter power to your Mac and none to the battery."
                : "Duty-cycles charging to about \(draft.percent)% of full power, cooler and gentler but slower to fill."
        }
    }

    @ViewBuilder
    private var matchesNowLine: some View {
        if !draft.conditions.isEmpty {
            let matches = normalized(draft).isSatisfied(by: store.snapshot)
            HStack(spacing: 5) {
                truthDot(matches)
                Text(matches ? "Matches now" : "Not matching now")
                    .font(.caption).foregroundStyle(matches ? Color.green : .secondary)
            }
        }
    }

    /// Green tick when a condition (or the whole rule) holds right now, hollow
    /// ring when it doesn't — the live feedback that makes a rule easy to trust.
    @ViewBuilder
    private func truthDot(_ on: Bool) -> some View {
        ZStack {
            Circle()
                .strokeBorder(on ? Color.green.opacity(0.35) : Color.secondary.opacity(0.35),
                              lineWidth: 1)
                .background(Circle().fill(on ? Color.green.opacity(0.18) : Color.clear))
            if on {
                HugeIcon("check", size: 9, weight: 2.6).foregroundStyle(Color.green)
            }
        }
        .frame(width: 15, height: 15)
    }

    /// Fill in a name and force the rule enabled-state through unchanged.
    private func normalized(_ rule: TriggerRule) -> TriggerRule {
        var copy = rule
        copy.label = copy.label.trimmingCharacters(in: .whitespaces)
        if copy.label.isEmpty { copy.label = copy.actionSummary }
        copy.conditions = copy.conditions.map { condition in
            var c = condition
            c.text = c.value
            return c
        }
        return copy
    }
}

extension String {
    /// "External display connected" → "external display connected", for use
    /// mid-sentence. Leaves acronyms and names (USB, Wi-Fi) alone.
    var lowercasedFirst: String {
        guard let first = first, !isEmpty else { return self }
        let rest = dropFirst()
        // Don't touch words that start with two capitals — CPU, USB, IP…
        if let second = rest.first, second.isUppercase { return self }
        return first.lowercased() + rest
    }
}
