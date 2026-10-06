import SwiftUI

/// A sheet that lists the currently running processes so the user can pick which
/// ones keep the Mac awake, instead of typing command names by hand. Multi-select;
/// tapping "Add" appends the checked names to the keep-awake list (union — it never
/// removes existing entries). Names already in the list are shown as "Added".
struct ProcessPickerView: View {
    /// Names already in the keep-awake list (shown as added, not re-selectable).
    let existing: [String]
    /// Called with the newly picked names when the user taps Add.
    let onAdd: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var processes: [RunningProcess] = []
    @State private var selected: Set<String> = []
    @State private var query = ""
    @State private var loading = true

    private var existingLower: Set<String> { Set(existing.map { $0.lowercased() }) }

    private var filtered: [RunningProcess] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return processes }
        return processes.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 420, height: 480)
        .onAppear(perform: load)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose processes to keep awake")
                .font(.headline)
            Text("Pick the apps or tools whose activity should keep the Mac awake.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search running processes", text: $query)
                    .textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
        }
        .padding(16)
    }

    @ViewBuilder private var content: some View {
        if loading {
            VStack { Spacer(); ProgressView("Scanning processes…"); Spacer() }
                .frame(maxWidth: .infinity)
        } else if filtered.isEmpty {
            VStack { Spacer(); Text("No matching processes").foregroundStyle(.secondary); Spacer() }
                .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { proc in row(proc) }
                }
            }
        }
    }

    private func row(_ proc: RunningProcess) -> some View {
        let alreadyAdded = existingLower.contains(proc.name.lowercased())
        let isSelected = selected.contains(proc.name)
        return Button {
            guard !alreadyAdded else { return }
            if isSelected { selected.remove(proc.name) } else { selected.insert(proc.name) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: alreadyAdded ? "checkmark.circle.fill"
                        : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .foregroundStyle(alreadyAdded ? Color.secondary : (isSelected ? Color.accentColor : Color.secondary))
                Text(proc.name).lineLimit(1).truncationMode(.middle)
                Spacer()
                if alreadyAdded {
                    Text("Added").font(.caption).foregroundStyle(.secondary)
                } else if proc.cpu >= 0.1 {
                    Text("\(Int(proc.cpu.rounded()))% CPU")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(alreadyAdded ? 0.5 : 1)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button(selected.isEmpty ? "Add" : "Add \(selected.count)") {
                onAdd(selected.sorted())
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selected.isEmpty)
        }
        .padding(16)
    }

    private func load() {
        loading = true
        Task.detached {
            let list = ProcessMonitor.runningProcessNames()
            await MainActor.run { processes = list; loading = false }
        }
    }
}
