import SwiftUI
import EWizKit

/// Minute-of-day ⇄ Date helpers so `DatePicker` can edit our stored
/// minutes-from-midnight values.
enum ClockTime {
    static func date(fromMinute minute: Int) -> Date {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        return cal.date(byAdding: .minute, value: minute, to: base) ?? base
    }
    static func minute(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

struct WeekdayPicker: View {
    @Binding var days: Weekdays
    private let bits: [(String, Weekdays)] = [
        ("S", .sun), ("M", .mon), ("T", .tue), ("W", .wed),
        ("T", .thu), ("F", .fri), ("S", .sat),
    ]

    var body: some View {
        HStack(spacing: 7) {
            ForEach(Array(bits.enumerated()), id: \.offset) { _, item in
                let on = days.contains(item.1)
                Button {
                    if on { days.subtract(item.1) } else { days.formUnion(item.1) }
                } label: {
                    Text(item.0)
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(on ? Color.accentColor
                                                     : Color.secondary.opacity(0.15)))
                        .overlay(Circle().strokeBorder(
                            on ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1))
                        .foregroundStyle(on ? Color.white : Color.primary.opacity(0.7))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The fields every recurring-window editor shares: name, start, length, repeat days
/// and the live window summary. Both sheets — charging windows and Always Active hours
/// — build on this so they stay identical in layout and behaviour; `extra` carries
/// whatever only one of them needs (the charge action picker).
struct ScheduleWindowFields<Extra: View>: View {
    @Binding var label: String
    @Binding var startMinute: Int
    @Binding var durationMinutes: Int
    @Binding var days: Weekdays
    let namePrompt: String
    /// "22:00–03:00 · Weekdays" — passed in so it tracks the caller's draft.
    let summary: String
    /// Sits directly under Name, where an editor needs a field of its own.
    @ViewBuilder var extra: Extra

    private let labelWidth: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("Name") {
                TextField(namePrompt, text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            extra

            row("Starts") {
                DatePicker("", selection: Binding(
                    get: { ClockTime.date(fromMinute: startMinute) },
                    set: { startMinute = ClockTime.minute(from: $0) }),
                    displayedComponents: .hourAndMinute)
                .labelsHidden()
                Spacer()
            }

            row("For") {
                Stepper(value: durationHours, in: 0.5...24, step: 0.5) {
                    Text(durationText).monospacedDigit()
                }
                .fixedSize()
                Spacer()
            }

            row("Repeat", alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    WeekdayPicker(days: $days)
                    HStack(spacing: 8) {
                        quickDays("Every day", .everyday)
                        quickDays("Weekdays", .weekdays)
                        quickDays("Weekends", .weekends)
                    }
                }
            }

            row("") {
                Text("Window: \(summary)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var durationHours: Binding<Double> {
        Binding(get: { Double(durationMinutes) / 60 },
                set: { durationMinutes = max(30, Int(($0 * 60).rounded())) })
    }

    private var durationText: String {
        let h = durationMinutes / 60, m = durationMinutes % 60
        if m == 0 { return "\(h) h" }
        if h == 0 { return "\(m) min" }
        return "\(h) h \(m) min"
    }

    /// Label in a fixed left column so every field's control lines up in the
    /// same value column.
    @ViewBuilder
    private func row<Content: View>(_ label: String,
                                    alignment: VerticalAlignment = .center,
                                    @ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: alignment, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            content()
        }
    }

    private func quickDays(_ title: String, _ set: Weekdays) -> some View {
        let active = days == set
        return Button(title) { days = set }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .tint(active ? Color.accentColor : Color.secondary)
    }
}

/// Cancel / Save (and Delete, when editing) for a window sheet. Save is disabled while
/// the window repeats on no day at all, which would be a schedule that never runs.
private struct ScheduleEditorFooter: View {
    let canSave: Bool
    let onDelete: (() -> Void)?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            Spacer()
            Button("Cancel", action: onCancel)
            Button("Save", action: onSave)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
    }
}

/// Modal editor for one charge schedule. Edits a local copy, committed via
/// `onSave`; `onDelete` is nil when adding.
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ChargeSchedule
    let isNew: Bool
    let onSave: (ChargeSchedule) -> Void
    let onDelete: (() -> Void)?

    init(schedule: ChargeSchedule, isNew: Bool,
         onSave: @escaping (ChargeSchedule) -> Void, onDelete: (() -> Void)?) {
        _draft = State(initialValue: schedule)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Schedule" : "Edit Schedule")
                .font(.title3.weight(.semibold))

            ScheduleWindowFields(
                label: $draft.label,
                startMinute: $draft.startMinute,
                durationMinutes: $draft.durationMinutes,
                days: $draft.days,
                namePrompt: "e.g. Overnight hold",
                summary: draft.scheduleSummary) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Action")
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Picker("", selection: $draft.action) {
                            ForEach(ScheduleAction.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden()
                    }
                }

            Divider()

            ScheduleEditorFooter(
                canSave: !draft.days.isEmpty,
                onDelete: onDelete.map { delete in { delete(); dismiss() } },
                onCancel: { dismiss() },
                onSave: {
                    if draft.label.trimmingCharacters(in: .whitespaces).isEmpty {
                        draft.label = draft.action.title
                    }
                    onSave(draft); dismiss()
                })
        }
        .padding(20)
        .frame(width: 420)
    }
}

/// Modal editor for one Always Active window — the hours during which the Mac is kept
/// awake with the lid closed.
struct AwakeScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AwakeSchedule
    let isNew: Bool
    let onSave: (AwakeSchedule) -> Void
    let onDelete: (() -> Void)?

    init(schedule: AwakeSchedule, isNew: Bool,
         onSave: @escaping (AwakeSchedule) -> Void, onDelete: (() -> Void)?) {
        _draft = State(initialValue: schedule)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Awake Window" : "Edit Awake Window")
                .font(.title3.weight(.semibold))

            ScheduleWindowFields(
                label: $draft.label,
                startMinute: $draft.startMinute,
                durationMinutes: $draft.durationMinutes,
                days: $draft.days,
                namePrompt: "e.g. Work hours",
                summary: draft.scheduleSummary) { EmptyView() }

            Text("Always Active holds inside this window and releases when it ends, so the Mac sleeps normally the rest of the time.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            ScheduleEditorFooter(
                canSave: !draft.days.isEmpty,
                onDelete: onDelete.map { delete in { delete(); dismiss() } },
                onCancel: { dismiss() },
                onSave: {
                    if draft.label.trimmingCharacters(in: .whitespaces).isEmpty {
                        draft.label = "Awake window"
                    }
                    onSave(draft); dismiss()
                })
        }
        .padding(20)
        .frame(width: 420)
    }
}
