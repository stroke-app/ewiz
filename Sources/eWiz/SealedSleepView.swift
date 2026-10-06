import SwiftUI
import EWizKit

/// The closed-lid panel: one switch, an honest checklist of what's still costing power,
/// and the measured result of the last time the lid was shut.
///
/// The checklist is the point. A switch on its own asks to be trusted; a switch next to a
/// list of nine named causes, each either struck through or still standing, can be checked.
/// It's also the only way to be straight about the two things eWiz can't decide for
/// you — Find My reachability, and a keep-awake you deliberately turned on.
struct SealedSleepPanel: View {
    @ObservedObject var chargeLimit: ChargeLimitStore
    @ObservedObject var automation: AutomationStore

    /// Compact form, for the menu: the verdict, what it measured, and only the causes
    /// still costing something.
    ///
    /// Settings shows all nine whether or not they're leaking, because there the list is
    /// the explanation. In the menu the same list would be nine rows of green ticks
    /// restating a sentence directly above them, in a popover that has four other sections
    /// to fit — so here it shrinks to what's still wrong, and to nothing when the answer
    /// is nothing.
    var compact = false

    private var state: SleepState { automation.sleepState(with: chargeLimit) }

    /// The leaks this view lists and counts.
    ///
    /// The menu leaves out Always Active holding on battery while it's on. That's Lid mode,
    /// switched on from the tile right under this section, which already says so. Listed
    /// here it was a row inserted *above* the tile a moment after pressing it, and the tile
    /// slid out from under the pointer. Settings still lists it with the rest.
    private var leaks: [SleepLeak] {
        guard compact, chargeLimit.keepAwake else { return state.leaks }
        return state.leaks.filter { $0 != .keptAwakeOnBattery }
    }
    private var result: SealedSleepResult? {
        automation.lastLidSession.flatMap(SealedSleepResult.init)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? DS.Space.s : DS.Space.m) {
            header
            if !compact {
                Text(explanation).font(DS.Typo.note).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !chargeLimit.sealedSleepRefused.isEmpty { refusedNotice }
            if chargeLimit.sealedSleep && chargeLimit.daemonAvailable { wakeSpeedRow }
            checklist
            if let result { measured(result) }
        }
    }

    // MARK: - Header

    private var header: some View {
        // Centred rather than baseline-aligned: a switch has no baseline of its own, so
        // `.firstTextBaseline` aligned its bottom edge to the title's and sat it lower
        // than the switches on the rows above. See `statusRow` in `MenuContentView`.
        HStack(alignment: .center, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                // The shared row title, matching every other row in the panel. It was
                // `.medium`, which made this one row read as a heading among peers.
                Text("Sealed Sleep").font(DS.Typo.rowTitle)
                if !verdict.isEmpty {
                    Text(verdict)
                        .font(DS.Typo.rowCaption)
                        .foregroundStyle(sealedForReal ? DS.Status.good : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Space.s)
            // The setter is spelled out rather than passed as `set: setSealed`. A bare
            // method reference here makes the compiler build a reabstraction thunk across
            // the main-actor boundary, and Swift 6.3's IRGen crashes on it.
            // Off whenever nothing is enforcing it. The switch describes the state of the
            // Mac, not the state of a preference: a daemon that isn't there applies no
            // pmset keys, cancels no wake sources and hibernates nothing, so a panel
            // showing this on over "Helper not installed" is the exact lie the feature
            // exists to prevent. It cost a user 6% overnight before it was caught.
            Toggle("Sealed Sleep",
                   isOn: Binding(get: { chargeLimit.sealedSleep && chargeLimit.daemonAvailable },
                                 set: { setSealed($0) }))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .disabled(!chargeLimit.daemonAvailable)
        }
        .frame(minHeight: DS.Metric.row)
    }

    /// One line, and it has to be true. "Sealed" is claimed only when the switch is on
    /// *and* nothing in the audit is still leaking — a toggle that reads "on" over a Mac
    /// that is still waking hourly is the failure this whole panel exists to prevent.
    /// Short enough to hold one line at the panel's width. The long form said the same
    /// thing over two, and a verdict that wraps stops reading as a verdict.
    /// Sealed, and something is actually holding it that way.
    private var sealedForReal: Bool {
        chargeLimit.daemonAvailable && chargeLimit.sealedSleep && state.isSealed
    }

    private var verdict: String {
        guard chargeLimit.daemonAvailable else { return "Helper not installed" }
        guard chargeLimit.sealedSleep else { return "Ordinary macOS sleep" }
        let remaining = leaks.count
        // Nothing to say in the menu when it is simply working: the switch reads on, the
        // row is titled Sealed Sleep, and a line under it repeating that in other words is
        // the panel talking to itself. The leak counts stay, because those are news.
        if remaining == 0 { return compact ? "" : "Nothing can wake it" }
        return remaining == 1 ? "1 leak left" : "\(remaining) leaks left"
    }

    /// The one trade this feature asks the user to make, put where they can act on it.
    ///
    /// It sits under the main switch rather than in Settings because it is the thing people
    /// come back to change: they turn Sealed Sleep on, shut the lid, open it thirty seconds
    /// later and want to know what happened. Answering that in a tooltip on another screen
    /// is how a feature gets switched off instead of adjusted.
    private var wakeSpeedRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: DS.Space.s) {
                Text("Wake instantly").font(DS.Typo.rowTitle)
                Spacer(minLength: DS.Space.s)
                Toggle("Wake instantly",
                       isOn: Binding(get: { chargeLimit.sealedSleepFastWake },
                                     set: { chargeLimit.setSealedSleepFastWake($0) }))
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
            .frame(minHeight: DS.Metric.row)
            // Only the state that costs something to be in gets a caption. Instant wake is
            // the default and the label says what it does; spelling out that memory stays
            // powered is a line the menu spends to tell you nothing has changed.
            if !chargeLimit.sealedSleepFastWake {
                Text("Opening the lid takes 15 to 30 seconds.")
                    .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if chargeLimit.sealedSleepFastWake && !compact {
                hibernateAfterRow
                if handoverIsOff { handoverOffNote }
            }
        }
    }

    /// Instant wake, with nothing to hand over to.
    ///
    /// The one state where this panel's verdict is wrong. The switch reads on, the
    /// checklist is clear, the receipt says 0% lost — and a long close still pays the
    /// memory trickle for every hour of it, because "Then hibernate after" is set to
    /// Never and so nothing ever powers memory down.
    ///
    /// Settings only, next to the picker that fixes it. In the menu it was a
    /// two-line amber warning stacked directly on top of the one-line green
    /// receipt — two notes in two tints arguing about the same feature, in a panel
    /// whose whole layout is one line per fact. The place to say this is the place
    /// where the control is.
    ///
    /// Never is a legitimate choice, so this reports rather than warns.
    private var handoverIsOff: Bool {
        chargeLimit.daemonAvailable && chargeLimit.sealedSleep
            && chargeLimit.sealedSleepFastWake && chargeLimit.sealedSleepHibernateAfter == 0
    }

    private var handoverOffNote: some View {
        DSNote(icon: "alert", tint: DS.Status.attention) {
            Text("Memory stays powered however long the lid is shut. Pick a time above and a long close costs nothing.")
        }
    }

    /// How long instant wake lasts before the close is treated as a long one.
    ///
    /// Settings only. It is the answer to "why did a 20-minute close open instantly and an
    /// overnight one take half a minute", and that question doesn't come up often enough to
    /// spend a row of the menu on. See `DeferredHibernate` for what it drives.
    private var hibernateAfterRow: some View {
        HStack(alignment: .center, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Then hibernate after").font(DS.Typo.rowTitle)
                Text("Memory powers down once the lid has been shut this long, so a long close costs nothing.")
                    .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Space.s)
            Picker("", selection: Binding(
                get: { chargeLimit.sealedSleepHibernateAfter },
                set: { chargeLimit.sealedSleepHibernateAfter = $0; chargeLimit.apply() }
            )) {
                Text("Never").tag(0)
                Text("5 min").tag(5)
                Text("20 min").tag(20)
                Text("1 hour").tag(60)
                Text("3 hours").tag(180)
            }
            .labelsHidden().fixedSize()
        }
    }

    private var explanation: String {
        "A closed Mac isn't off. macOS keeps waking it on a timer for maintenance, the "
        + "network and Find My. Sealed Sleep switches all of that off, so nothing brings it "
        + "up until you open the lid. Find My can't reach it while it's shut."
    }

    private var refusedNotice: some View {
        DSNote(icon: "alert", tint: DS.Status.attention) {
            Text("This Mac refused: \(chargeLimit.sealedSleepRefused.joined(separator: ", ")). "
                 + "Those settings are unchanged; everything else applied.")
        }
    }

    // MARK: - Checklist

    /// Every cause, sealed ones included, so the list doesn't shrink as things are fixed.
    ///
    /// A checklist that removes its finished items tells you what's wrong and hides what
    /// it did for you; keeping them makes the switch's effect visible in one glance, which
    /// is the difference between a claim and a receipt.
    /// No surface, in either place.
    ///
    /// The popover is already a rounded, bordered, shadowed panel, so a box inside it
    /// draws a second border a few points in from the first and the eye reads the nesting
    /// before the content. Settings no longer boxes its groups at all — see `card` there —
    /// so a box here would be the only one on the page. Both arguments land in the same
    /// place: a label, rows, and space.
    @ViewBuilder
    private var checklist: some View {
        let leaking = Set(leaks)
        let shown = compact
            ? leaks
            : SleepLeak.allCases.sorted { $0.weight < $1.weight }
        if !shown.isEmpty {
            VStack(spacing: compact ? DS.Space.s : 0) {
                ForEach(Array(shown.enumerated()), id: \.element) { index, leak in
                    if index > 0 && !compact { DSSeparator(inset: 0) }
                    row(leak, leaking: leaking.contains(leak))
                }
            }
        }
    }

    private func row(_ leak: SleepLeak, leaking: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            // The glyph column `DSNote` uses, not a `DS.Icon.row`-wide one: a leak and the
            // receipt printed under it are both notes about this section, so they start on
            // the same line rather than at two different indents.
            HugeIcon(leaking ? leak.icon : "check", size: DS.Icon.caption)
                .foregroundStyle(leaking ? (leak.isAutomatic ? Color.secondary : DS.Status.attention) : DS.Status.good)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            VStack(alignment: .leading, spacing: 1) {
                Text(leak.title)
                    .font(DS.Typo.note)
                    .foregroundStyle(leaking ? Color.primary : .secondary)
                    .strikethrough(!leaking, color: .secondary)
                if leaking && !compact {
                    Text(leak.cost).font(DS.Typo.rowCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Space.s)
            if leaking && !leak.isAutomatic { manualFix(leak) }
        }
        .padding(.vertical, compact ? 0 : DS.Space.s - 2)
    }

    /// The one leak with no automatic answer gets its own button, because the fix is a
    /// decision rather than a setting: turning off keep-awake-on-battery is switching off
    /// something the user asked for.
    @ViewBuilder
    private func manualFix(_ leak: SleepLeak) -> some View {
        if leak == .keptAwakeOnBattery {
            Button("Release") {
                chargeLimit.keepAwakeOnBattery = false
                chargeLimit.apply()
            }
            .buttonStyle(.link).font(DS.Typo.note)
        }
    }

    // MARK: - Measured result

    /// What the last closed-lid stretch actually cost. No projection, no estimate — the
    /// charge was read when the lid shut and again when it opened.
    private func measured(_ result: SealedSleepResult) -> some View {
        let verdict = result.handover(afterMinutes: chargeLimit.sealedSleepHibernateAfter)
        // A long close that still drained is the one case where the receipt has to argue
        // with itself: the switch reads on, the checklist is clear, and the number says
        // memory stayed powered anyway. Amber, and it says which.
        let failed = verdict == .didNotFire
        return DSNote(icon: failed ? "alert" : (result.isEssentiallyZero ? "check" : "chart"),
                      tint: failed ? DS.Status.attention
                                   : (result.isEssentiallyZero ? DS.Status.good : .secondary)) {
            Text(measuredText(result) + handoverSuffix(verdict))
        }
    }

    /// What the measurement says about the handover, in the fewest words that are true.
    private func handoverSuffix(_ verdict: SealedSleepResult.Handover) -> String {
        switch verdict {
        case .worked:           return " · hibernated"
        case .didNotFire:       return " · memory stayed powered"
        // Nothing to add. "No handover booked" is what the row above already says, and a
        // close shorter than the window behaving like a short close is not news.
        case .notConfigured, .tooShortToMatter: return ""
        }
    }

    /// One line, telegraphic: "Last close: 34h shut · 0% lost".
    ///
    /// It was a sentence, and at this width a sentence is two lines — which put more panel
    /// behind the receipt than behind the switch it vouches for.
    private func measuredText(_ result: SealedSleepResult) -> String {
        let hours = result.session.duration / 3600
        let span = hours >= 1
            ? String(format: "%.0fh", hours)
            : String(format: "%.0fm", result.session.duration / 60)
        let lost = result.isEssentiallyZero
            ? "0% lost"
            : String(format: "%d%% lost · %.1f%%/h", result.session.dropPercent, result.perHour)
        return "Last close: \(span) shut · \(lost)"
    }

    // MARK: - Actions

    /// The switch owns both halves: the daemon's `pmset` settings and the app's radio
    /// preferences. Splitting them across two controls was the old design, and it let a
    /// Mac sit in a state where half the feature was on.
    private func setSealed(_ on: Bool) {
        chargeLimit.setSealedSleep(on)
        automation.setSealed(on)
    }
}

/// Which icon stands for each cause. Kept here rather than on `SleepLeak` — the model
/// lives in EWizKit, which has no business knowing what this app draws with.
private extension SleepLeak {
    var icon: String {
        switch self {
        case .memoryStaysPowered: return "cpu"
        case .standbyDisabled:    return "moon"
        case .powerNap:           return "refresh"
        case .wakeForNetwork:     return "globe"
        case .networkInSleep:     return "wifi"
        case .terminalSessions:   return "code"
        case .wifiLeftOn:         return "wifi"
        case .bluetoothLeftOn:    return "bluetooth"
        case .keptAwakeOnBattery: return "coffee"
        }
    }
}

extension AutomationStore {
    /// Assemble the audit from both halves of the app: the daemon reports what `pmset`
    /// says, and this store owns the radio preferences.
    func sleepState(with chargeLimit: ChargeLimitStore) -> SleepState {
        SleepState(
            hibernateMode: chargeLimit.hibernateMode,
            standby: chargeLimit.standbyEnabled,
            powerNap: chargeLimit.powerToggleState(.powerNap),
            wakeForNetwork: chargeLimit.powerToggleState(.wakeOnNetwork),
            networkInSleep: chargeLimit.powerToggleState(.tcpKeepAlive),
            terminalSessionsKeepAwake: chargeLimit.powerToggleState(.ttysKeepAwake),
            wifiOffOnLidClose: wifiOffOnLidClose,
            bluetoothOffOnLidClose: bluetoothOffOnLidClose,
            keepAwakeOnBattery: chargeLimit.keepAwake && chargeLimit.keepAwakeOnBattery,
            fastWake: chargeLimit.sealedSleepFastWake)
    }
}
