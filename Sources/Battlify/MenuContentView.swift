import SwiftUI
import AppKit
import BattlifyKit

struct MenuContentView: View {
    @EnvironmentObject private var battery: BatteryStore
    @EnvironmentObject private var chargeLimit: ChargeLimitStore
    @EnvironmentObject private var automation: AutomationStore
    @EnvironmentObject private var license: LicenseManager
    @EnvironmentObject private var updater: UpdaterManager
    @EnvironmentObject private var actions: SystemActions
    @EnvironmentObject private var caffeine: CaffeineManager
    @EnvironmentObject private var triggers: TriggerStore
    @EnvironmentObject private var hotkeys: HotkeyStore
    @EnvironmentObject private var restReminder: RestReminder
    @EnvironmentObject private var idleSaver: IdleSaverStore
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @State private var installError: String?
    /// A performance mode waiting on confirmation — see `requestMode`.
    @State private var pendingPerformanceMode: SaveMode?
    // Deliberately an under-estimate. `MenuBarExtra(.window)` sizes its window to this
    // frame, and a window taller than the panel drawn in it leaves a transparent band above
    // the content — which is exactly what a too-generous starting guess produced. Growing
    // into the measured height on the first layout pass is invisible; shrinking is not.
    @State private var contentHeight: CGFloat = 320

    // The system's own menu-bar panels (Bluetooth, Wi-Fi, Sound) are ~320pt wide with a
    // 16pt margin. Matching them is most of what makes a panel read as part of the menu
    // bar rather than as a window someone parked under it.
    private let popoverWidth: CGFloat = 320
    /// One horizontal inset for everything in the panel, so the header, every label and
    /// every control start on the same vertical line. Rules deliberately ignore it and run
    /// edge to edge — that full-width line is what a macOS menu uses in place of a box.
    /// Taken from the spacing scale rather than eyeballed, so it can't drift from the
    /// vertical rhythm the sections are built on.
    private let inset = DS.Space.l

    var body: some View {
        let snap = battery.snapshot
        // Read unconditionally so SwiftUI reliably re-renders the popover when it flips
        // (a read only inside the `if` below doesn't, under MenuBarExtra).
        let restDue = restReminder.isDue

        // As tall as the content, but never taller than the screen.
        ScrollView {
            // No cards in here. The popover is already a container — a rounded, bordered,
            // shadowed panel — so a card inside it draws a second border a few points in
            // from the first, and the eye reads the nesting before it reads the content.
            // Four of them stacked also meant four competing edges and no hierarchy at
            // all. Sections are separated the way the system's own menus separate them:
            // one full-width hairline, and nothing else.
            VStack(alignment: .leading, spacing: 0) {
                header(snap)
                    .padding(.horizontal, inset)
                    .padding(.top, DS.Space.m)
                    .padding(.bottom, DS.Space.m)

                if let update = updater.available { notice { updateBanner(update) } }
                if !license.isLicensed { notice { licenseBanner } }
                if restDue { notice { restBanner } }

                Group {
                    section { modeSection }
                    section { chargeLimitSection }
                    section { closedLidSection }
                    if !triggers.activeRules.isEmpty {
                        section { activeRulesSection }
                    }
                }
                .disabled(!license.isPro)
                .opacity(license.isPro ? 1 : 0.45)

                section { quickActionsSection }

                DSSeparator(inset: 0)
                    .padding(.horizontal, inset)
                footer
                    .padding(.horizontal, inset)
                    .padding(.vertical, DS.Space.s)
            }
            .background(GeometryReader { g in
                Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
            })
        }
        .scrollIndicators(.hidden)
        // `NSScrollView` draws an opaque background unless told not to, and it sits *over*
        // the panel material — so the vibrancy was being rendered and then painted out by
        // the scroll view in front of it. This is the line that lets the material through.
        .scrollContentBackground(.hidden)
        .frame(width: popoverWidth, height: min(contentHeight, maxPopoverHeight))
        // And make the window agree with that frame — it doesn't on its own. See `WindowSizer`.
        .background(WindowSizer(size: CGSize(width: popoverWidth,
                                             height: min(contentHeight, maxPopoverHeight)),
                                radius: DS.Radius.group))
        // The panel's surface. Without it `MenuBarExtra(.window)` is an opaque grey
        // rectangle; with it the panel picks up what's behind it the way every other
        // menu-bar panel on the system does.
        .dsMenuPanel()
        // `MenuBarExtra(.window)` opens as a key window and hands first responder to the
        // first focusable control, which then wears a focus ring the moment the panel
        // appears. No system menu-bar panel does that, so the ring reads as a rendering
        // artifact rather than as focus. Drop it panel-wide.
        .focusEffectDisabled()
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        // Re-sync every time the menu opens so it never shows stale state.
        .onAppear {
            battery.refresh()
            battery.beginPowerFlowObserving()
            chargeLimit.refresh()
            license.refresh()
            // The dropdown's `openWindow` is the one the footer buttons already use,
            // so hand it to the shortcut store in place of the label's.
            hotkeys.setOpenWindow { id in
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: id)
            }
        }
        .onDisappear { battery.endPowerFlowObserving() }
    }

    private var maxPopoverHeight: CGFloat {
        // The popover opens on the screen under the cursor, not necessarily
        // `NSScreen.main`, so resolve it or multi-monitor sizing clips the popover.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let usable = screen?.visibleFrame.height ?? 800
        return max(360, usable - 24)
    }

    // MARK: - Update banner

    private func updateBanner(_ update: AppUpdate) -> some View {
        HStack(spacing: DS.Space.s) {
            HugeIcon("download", size: DS.Icon.row).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Update available: v\(update.version)")
                    .font(DS.Typo.rowTitle.weight(.medium))
                Text("You have v\(updater.currentVersion)")
                    .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Space.s)
            Button(updater.installing ? "Installing…" : "Update") { updater.installUpdate() }
                .controlSize(.small)
                .disabled(updater.installing)
        }
    }

    // MARK: - Rest reminder banner

    @ViewBuilder
    private var restBanner: some View {
        HStack(alignment: .top, spacing: DS.Space.s) {
            HugeIcon("sleep", size: DS.Icon.row).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Give your Mac a rest").font(DS.Typo.rowTitle.weight(.medium))
                Text(restReminder.message)
                    .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DS.Space.s) {
                    Button("Restart…") { confirmRestart() }.controlSize(.small)
                    Button("Later") { restReminder.snooze() }.controlSize(.small)
                }
            }
        }
    }

    private func confirmRestart() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Restart your Mac now?"
        alert.informativeText = "Save any open work first. Your apps will be asked to close."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { restReminder.restart() }
    }

    // MARK: - License banner

    @ViewBuilder
    private var licenseBanner: some View {
        let expired = !license.isPro
        HStack(spacing: DS.Space.s) {
            HugeIcon(expired ? "lock" : "sparkles", size: DS.Icon.row)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(expired ? "Trial ended, controls locked" : license.statusText)
                    .font(DS.Typo.rowTitle.weight(.medium))
                Text(expired ? "Activate to keep using Battlify."
                             : "Activate any time to unlock permanently.")
                    .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
            }
            Spacer(minLength: DS.Space.s)
            Button("Activate") { openDetached("license") }
                .controlSize(.small)
        }
    }

    // MARK: - Header

    /// The number, one line of context, and the gauge. Nothing else.
    ///
    /// It used to stack three right-hand lines — source, estimate, draw — beside the
    /// percentage, then repeat the limit under the gauge in a fourth. Four lines of
    /// supporting text around one number is the number losing an argument with its own
    /// caption, so the three are now a single dot-separated line and the gauge draws the
    /// limit itself.
    private func header(_ snap: BatterySnapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
                (Text("\(snap.percentage)")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                 + Text("%")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(snap.percentage)))
                    .animation(.spring(response: 0.45, dampingFraction: 0.9), value: snap.percentage)
                Spacer(minLength: DS.Space.s)
                Text(headerDetail(snap))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            chargeGauge(snap)

            // Only when it says something the gauge can't. "Limit 80%" is the marker the
            // gauge already draws; "Charging paused — warm" is not.
            if let note = limitNote(snap) {
                Text(note)
                    .font(DS.Typo.note).foregroundStyle(.secondary)
            }
        }
    }

    private func chargeGauge(_ snap: BatterySnapshot) -> some View {
        ChargeGauge(percentage: snap.percentage,
                    color: chargeColor(snap),
                    limitEnabled: chargeLimit.limitEnabled,
                    limit: chargeLimit.limit,
                    charging: snap.isCharging)
    }

    /// Source, estimate and draw on one line, joined by middots and dropping whatever
    /// isn't known. On battery: "On battery · 2h 38m · 32.2 W".
    private func headerDetail(_ snap: BatterySnapshot) -> String {
        [statusLine(snap), etaLine(snap), liveWattsLine(snap)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// What the gauge can't draw. Returns nil for the ordinary "limit is set and being
    /// honoured" case, because the gauge's own marker already says that.
    private func limitNote(_ snap: BatterySnapshot) -> String? {
        if chargeLimit.isPaused { return "Charging paused" }
        if chargeLimit.calibrating { return "Charging to 100% once" }
        guard chargeLimit.limitEnabled else { return nil }
        let stop = chargeLimit.holdingAt
        // Above the stop, both levers run the Mac off the battery down to it. "Holding at
        // 80%" over a gauge reading 85 was the panel contradicting itself.
        if chargeLimit.discharging, chargeLimit.pauseReason != "hold", snap.percentage > stop {
            return "Draining to \(stop)%"
        }
        if chargeLimit.isHoldingCharge { return "Holding at \(stop)%" }
        if snap.isCharging {
            let limit = chargeLimit.effectiveLimit
            return snap.percentage >= limit ? "Above the \(limit)% limit" : "Charging to \(limit)%"
        }
        return nil
    }

    /// Red, yellow, green off the level while on power; plain foreground on battery.
    ///
    /// The ramp is the same one the menu-bar glyph and the plug-in animation use, so the
    /// three never disagree about what a given charge looks like — including about when to
    /// say nothing. Green on a battery that's draining is reassurance about a number going
    /// the wrong way, so unplugged draws in the ordinary text colour until it's low enough
    /// to have earned a red.
    ///
    /// Heat overrides everything. A battery too warm to charge is a warning whatever its
    /// level reads, and it would otherwise be drawn in the green of a healthy one.
    private func chargeColor(_ snap: BatterySnapshot) -> Color {
        if isWarm(snap) { return .red }
        if snap.percentage <= 20 && !snap.isPluggedIn { return .red }
        guard snap.isPluggedIn else { return .primary }
        return Color(ChargePalette.legible(Double(snap.percentage) / 100))
    }

    private func isWarm(_ snap: BatterySnapshot) -> Bool {
        if chargeLimit.pauseReason == "heat" { return true }
        if let t = snap.temperature, t >= 40 { return true }
        return false
    }

    // MARK: - Save mode

    /// Just the picker.
    ///
    /// The paragraph under it described whichever mode was selected — four lines of prose
    /// restating a word the user had just read off the control, re-wrapping every time they
    /// touched it. The same text lives in Settings, where there's room for it. The one case
    /// that still earns prose is Extreme, because what it does depends on the hardware and
    /// nothing on screen says so.
    @ViewBuilder
    private var modeSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            if chargeLimit.daemonAvailable {
                DSSegmentedControl(items: SaveMode.allCases,
                                   title: { $0.title },
                                   selection: Binding(
                                    get: { chargeLimit.mode },
                                    set: { requestMode($0) }
                                   ))
                .accessibilityLabel("Save mode")

                if let pending = pendingPerformanceMode {
                    performanceConfirmation(for: pending)
                } else if chargeLimit.mode.isPerformance {
                    Text(performanceReality)
                        .font(DS.Typo.note)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Install the helper to use save modes.")
                    .font(DS.Typo.note)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The "are you sure" for Extreme Performance. See `DSConfirmCard` for why it's
    /// inline content rather than a `confirmationDialog`.
    private func performanceConfirmation(for mode: SaveMode) -> some View {
        DSConfirmCard(
            title: "Turn on Extreme Performance?",
            message: "Your charge limit comes off, the battery charges to 100%, and the Mac won't idle-sleep. Hotter, and harder on the battery.\n\nSwitching to another mode puts your charging settings back.",
            onConfirm: {
                pendingPerformanceMode = nil
                applyMode(mode)
            },
            onCancel: { pendingPerformanceMode = nil })
    }

    /// Route a picker selection: entering a performance mode asks first, everything else
    /// applies straight away.
    ///
    /// The confirmation isn't ceremony. Extreme Performance drops the charge limit and
    /// blocks idle sleep — consequences you should not be able to reach by
    /// mis-clicking a four-segment control, and it sits in the first segment, which is
    /// also the one a picker writes back if its binding ever goes out of sync. Leaving the
    /// mode is never gated: getting *out* of it must always be one click.
    private func requestMode(_ mode: SaveMode) {
        guard mode != chargeLimit.mode else { return }
        if mode.isPerformance {
            pendingPerformanceMode = mode
        } else {
            // Picking anything else answers the question by walking away from it.
            pendingPerformanceMode = nil
            applyMode(mode)
        }
    }

    private func applyMode(_ mode: SaveMode) {
        automation.apply(mode.profile)
        chargeLimit.applyMode(mode)
    }

    /// Which of Extreme Performance's levers this Mac actually has, named plainly.
    private var performanceReality: String {
        var active = ["Low Power Mode off", "charging to 100%", "no idle sleep"]
        var missing: [String] = []
        if chargeLimit.highPowerModeSupported { active.append("High Power Mode") }
        else { missing.append("no High Power Mode on this Mac") }

        let on = active.joined(separator: ", ") + "."
        guard !missing.isEmpty else { return on }
        return on + " " + missing.joined(separator: "; ").prefix(1).uppercased()
             + missing.joined(separator: "; ").dropFirst() + "."
    }

    // MARK: - Closed lid

    /// What shutting the lid costs, and the switch that makes the answer zero.
    ///
    /// It sits directly under the charge limit because the two are the app's whole
    /// argument: the limit looks after the battery's life, this looks after its charge.
    /// Everything below is a convenience by comparison.
    private var closedLidSection: some View {
        SealedSleepPanel(chargeLimit: chargeLimit, automation: automation, compact: true)
    }

    // MARK: - Pause charging (idle / resume after N hours)

    @ViewBuilder
    private var pauseChargingControl: some View {
        if chargeLimit.isPaused {
            statusRow("Charging paused", pauseCaption()) {
                Button("Resume") { chargeLimit.resumeCharging() }.controlSize(.small)
            }
        }
    }

    /// The one-off charging actions, folded behind a `⋯` on the row they belong to.
    ///
    /// They were two full-width buttons on a row of their own — 36pt of panel spent on two
    /// things nobody does daily, sitting at the same visual weight as the limit itself.
    /// Behind the ellipsis they cost nothing until wanted, which is the whole trade a menu
    /// exists to make.
    @ViewBuilder
    private var chargeOverflowMenu: some View {
        if !chargeLimit.isPaused && !chargeLimit.calibrating {
            Menu {
                Button("Pause 1 hour") { chargeLimit.pauseCharging(minutes: 60) }
                Button("Pause 3 hours") { chargeLimit.pauseCharging(minutes: 180) }
                Button("Pause 5 hours") { chargeLimit.pauseCharging(minutes: 300) }
                Button("Pause until I resume") { chargeLimit.pauseCharging(minutes: -1) }
                if chargeLimit.limitEnabled {
                    Divider()
                    Button("Charge to 100% once") { chargeLimit.startCalibration() }
                }
                if chargeLimit.dischargeSupported {
                    Divider()
                    Toggle("Park near \(LongevityCare.targetPercent)% (long-term care)",
                           isOn: Binding(get: { chargeLimit.longevityCare },
                                         set: { chargeLimit.setLongevityCare($0) }))
                }
            } label: {
                // A 4pt glyph is a 4pt target unless it's given one, and a menu indicator
                // beside it would be a second arrow pointing at a row that has a switch.
                Image(systemName: "ellipsis")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Pause charging, or charge to 100% once")
        }
    }

    /// "Don't charge" as a switch rather than a timed pause: the level stays put for as
    /// long as it's on, and the MagSafe light goes green so it's visible from outside
    /// the app.
    private var holdChargeControl: some View {
        // No caption while it's off. "Don't charge" with a switch beside it needs no
        // gloss; the explanation lives in Settings.
        statusRow("Don't charge", chargeLimit.holdCharge ? holdCaption : nil) {
            Toggle("Don't charge", isOn: Binding(
                get: { chargeLimit.holdCharge },
                set: { chargeLimit.holdCharge = $0; chargeLimit.apply() }))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }

    /// What the hold is doing. Under macOS's limit it can only park on a step (80, 85, 90,
    /// 95), so it rounds up and charges to the step first, and saying "Holding the level"
    /// while the battery climbs would be the panel contradicting the gauge above it.
    private var holdCaption: String {
        guard !chargeLimit.nativeLimitSteps.isEmpty else { return "Holding the level" }
        let level = battery.snapshot.percentage
        let at = chargeLimit.nativeLimitApplied ?? 100
        return at > level ? "Charges to \(at)%, then holds there" : "Holding at \(at)% on wall power"
    }

    @ViewBuilder
    private var calibrationControl: some View {
        if chargeLimit.calibrating {
            statusRow("Charging to 100%", "Limit resumes automatically once full.") {
                Button("Cancel") { chargeLimit.cancelCalibration() }.controlSize(.small)
            }
        }
    }

    /// A title, a caption under it, and a control on the trailing edge.
    ///
    /// The shape every row in the panel now takes. Its one job is that the title starts on
    /// the panel inset — no icon column, no indent — so a column of rows has a single
    /// leading edge whatever mix of switches, buttons and captions it happens to hold.
    private func statusRow<Trailing: View>(_ title: String, _ caption: String?,
                                           @ViewBuilder trailing: () -> Trailing) -> some View {
        // Centred, not baseline-aligned. A switch has no baseline, so `.firstTextBaseline`
        // lined its *bottom edge* up with the title's baseline and dropped it a couple of
        // points lower than the switch on the row above — which was most of what made two
        // adjacent rows look like they came from different screens.
        HStack(alignment: .center, spacing: DS.Space.s) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(DS.Typo.rowTitle)
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DS.Space.s)
            trailing()
        }
        .frame(minHeight: DS.Metric.row)
    }

    private func pauseCaption() -> String {
        guard let until = chargeLimit.pauseUntil else { return "" }
        if chargeLimit.isPausedIndefinitely { return "Until you resume" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return "Resumes \(f.localizedString(for: until, relativeTo: Date()))"
    }

    // MARK: - Charge limit

    /// The section reads top-down in order of how much it matters: the limit itself, the
    /// band under it, then the override that suspends both, then whatever the daemon is
    /// doing about it right now, then the one-off actions.
    ///
    /// "Don't charge" used to lead, which put an override above the thing it overrides.
    @ViewBuilder
    private var chargeLimitSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            if chargeLimit.daemonAvailable {
                // The update is automatic now, so only send someone to Settings once the
                // app has actually stopped trying (prompt cancelled, or installer missing).
                if chargeLimit.daemonOutdated {
                    hintLabel(chargeLimit.helperInstalling
                              ? "Updating the helper. Approve the prompt."
                              : "Helper is outdated. Reinstall it from Settings.",
                              systemImage: "alert")
                }

                switchRow("Limit charging", Binding(
                    get: { chargeLimit.limitEnabled },
                    set: { chargeLimit.limitEnabled = $0; chargeLimit.apply() }
                ), trailing: { chargeOverflowMenu })

                if chargeLimit.limitEnabled {
                    sliderRow("Stop at", value: chargeLimit.limit,
                              binding: Binding(
                                get: { Double(chargeLimit.limit) },
                                set: {
                                    chargeLimit.limit = Int($0)
                                    // Keep the recharge floor valid as the top moves.
                                    chargeLimit.resumeMargin = min(chargeLimit.resumeMargin,
                                                                   max(5, chargeLimit.limit - 20))
                                }),
                              range: 50...100)

                    // Said where the number is set, not after the battery has gone past it.
                    if let floor = chargeLimit.nativeLimitFloor, chargeLimit.limit < floor {
                        hintLabel("This Mac can only hold from \(floor)%, so it stops at \(floor)%.",
                                  systemImage: "info")
                    }

                    // Under macOS's own limit, macOS decides when charging resumes, so a
                    // recharge floor here would be a slider that moves and changes nothing.
                    if chargeLimit.nativeLimitSteps.isEmpty {
                        switchRow("Recharge range", Binding(
                            get: { chargeLimit.rangeEnabled },
                            set: { chargeLimit.setRangeEnabled($0) }
                        ))

                        if chargeLimit.rangeEnabled {
                            sliderRow("Recharge at", value: chargeLimit.recharge,
                                      binding: Binding(
                                        get: { Double(chargeLimit.recharge) },
                                        set: { chargeLimit.resumeMargin = chargeLimit.limit - Int($0) }),
                                      range: Double(max(20, chargeLimit.limit - 40))...Double(chargeLimit.limit - 5))
                                .help("Battery drains to this level before charging back up to the limit, instead of sitting pinned at the limit.")
                        }
                    }
                }

                holdChargeControl
                pauseChargingControl
                calibrationControl

                // Live state: why charging is currently paused.
                //
                // Gated on `pauseReason` alone. It used to require `!chargingEnabled` as
                // well, which reads as a tautology and isn't: a Mac with no charge-inhibit
                // key always reports charging as enabled, so on that hardware this whole
                // block was dead and the panel explained nothing it was doing.
                if chargeLimit.discharging {
                    // A run down to the limit is the header's line ("Draining to 80%").
                    // Repeated here it sat under "Don't charge", which it has nothing to do with.
                    if chargeLimit.pauseReason == "hold" {
                        hintLabel("Running off the battery to hold the level", systemImage: "batteryLow")
                    }
                } else if let reason = chargeLimit.pauseReason {
                    switch reason {
                    case "heat":     hintLabel("Charging paused, battery is warm", systemImage: "thermometer")
                    case "limit":    hintLabel("Charging paused to hold limit", systemImage: "pause")
                    case "settling": hintLabel("Charging resumes shortly after wake", systemImage: "sleep")
                    case "hold":     hintLabel("Holding the level where it is", systemImage: "pause")
                    case "schedule": hintLabel("A schedule is holding charging", systemImage: "clock")
                    case "slow":     hintLabel("Charging gently, at \(chargeLimit.chargePower)% power",
                                               systemImage: "batteryLow")
                    // "paused" has its own row with a Resume button; "sleep" is the cut on
                    // the way into sleep and is gone by the time anyone can read it.
                    default:         EmptyView()
                    }
                }
            } else {
                helperMissingView
            }
        }
    }

    /// A labelled slider: caption and value on one line, the track directly under it.
    ///
    /// The two are one control, so they're spaced `Space.xs` apart while the rows around
    /// them sit `Space.m` apart — the gap between groups has to beat the gap inside one,
    /// or a label ends up looking like it belongs to the track above rather than below.
    private func sliderRow(_ title: String, value: Int,
                           binding: Binding<Double>,
                           range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text("\(value)%").fontWeight(.semibold).monospacedDigit()
            }
            .font(DS.Typo.rowTitle)

            Slider(value: binding, in: range, step: 5,
                   onEditingChanged: { $0 ? chargeLimit.beginEditing() : chargeLimit.endEditing() })
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var helperMissingView: some View {
        DSNote(icon: "alert", font: DS.Typo.rowTitle, iconSize: DS.Icon.row) {
            Text(chargeLimit.helperInstalling ? "Installing helper…" : "Helper not installed")
        }
        Text(chargeLimit.helperInstalling
             ? "Approve the administrator prompt to finish."
             : "Charge limiting, Low Power Mode, and sleep settings need the root helper.")
            .font(DS.Typo.note)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        // Offering the button mid-install would start a second osascript behind the first.
        if HelperInstaller.canInstall {
            if !chargeLimit.helperInstalling {
                Button("Install Helper…") {
                    let result = HelperInstaller.install()
                    if result.ok {
                        chargeLimit.clearAutoInstallRefusal()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { chargeLimit.refresh() }
                    } else {
                        installError = result.message
                    }
                }
                .controlSize(.small)
            }
        } else {
            Text("Or run scripts/install-helper.sh")
                .font(DS.Typo.note).foregroundStyle(.secondary)
        }
        if let installError {
            Text(installError).font(DS.Typo.note).foregroundStyle(.red).lineLimit(3)
        }
    }

    // MARK: - Quick actions

    @ViewBuilder
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            HStack(spacing: DS.Space.xs) {
                actionButton(actions.dimmed ? "Brighten" : "Dim",
                             systemImage: actions.dimmed ? "sun" : "sunLow",
                             help: (actions.dimmed ? "Restore the previous brightness"
                                                   : "Dim the display to save power")
                                   + shortcutHint(.toggleDimDisplay)) {
                    actions.toggleDim()
                }
                actionButton("Off", systemImage: "display",
                             help: "Turn the display off now (the Mac stays awake)"
                                   + shortcutHint(.displayOff)) {
                    actions.turnDisplayOff()
                }
                // Resting is more than the display: it also holds Low Power Mode and,
                // if asked, the radios — so it gets its own button rather than hiding
                // behind "Off".
                actionButton(idleSaver.resting ? "Wake" : "Rest",
                             systemImage: idleSaver.resting ? "sun" : "moon",
                             help: idleSaver.resting
                                 ? "Stop resting and put back what was changed"
                                 : "Screen off and settings held, without closing the lid") {
                    idleSaver.resting ? idleSaver.wake() : idleSaver.restNow()
                }
                lidClosedButton
                caffeineButton
            }
            // Always one line, whatever is on. It used to appear with Awake and vanish
            // without it, so every press of a tile changed the panel's height and moved
            // everything below the pointer. Now a press changes the words, not the layout.
            DSNote(icon: actionStatus.icon) {
                Text(actionStatus.text).lineLimit(1).truncationMode(.tail)
            }
        }
    }

    /// What the tiles are doing, most consequential first.
    private var actionStatus: (icon: String, text: String) {
        if ClamshellMode.isOn(charge: chargeLimit) {
            return ("laptop", chargeLimit.keepAwakeOnBattery
                    ? "Lid mode · runs with the lid shut, on battery too"
                    : "Lid mode · runs with the lid shut on power")
        }
        if caffeine.active { return ("coffee", caffeineStatusText) }
        if idleSaver.resting { return ("moon", "Resting · screen off, settings held") }
        return ("moon", "Sleeps as usual")
    }

    /// Working with the lid shut, as one press.
    ///
    /// Three switches that only mean anything together: caffeine holds the display and the
    /// system, Always Active carries that through the lid closing, and the battery
    /// permission stops the whole thing quietly ending the moment the charger comes out.
    /// Anyone setting this up by hand sets all three — so the tile sets all three.
    ///
    /// It replaced "Sleep", which sat in a row of things that keep the Mac *running* and
    /// was one mis-click away from ending whatever the other four were protecting. Sleep
    /// is still on its shortcut.
    private var lidClosedButton: some View {
        let on = ClamshellMode.isOn(charge: chargeLimit)
        return Button {
            ClamshellMode.set(!on, charge: chargeLimit, caffeine: caffeine)
        } label: {
            VStack(spacing: DS.Space.xs) {
                HugeIcon("laptop", size: DS.Icon.row)
                Text("Lid").font(DS.Typo.rowCaption).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.s)
        }
        .buttonStyle(QuickActionButtonStyle(active: on, activeTint: .accentColor))
        .help(on
              ? "Stop working with the lid closed. Caffeine off, Always Active off."
              : "Keep working with the lid closed: caffeine on, Always Active on, and allowed to hold on battery. Drains fast and runs hot.")
    }

    /// Built as a plain button (not a Menu) so it stays the same width as the
    /// other Quick Action tiles.
    private var caffeineButton: some View {
        Button {
            caffeine.toggle()
        } label: {
            VStack(spacing: DS.Space.xs) {
                HugeIcon("coffee", size: DS.Icon.row)
                Text("Awake").font(DS.Typo.rowCaption).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.s)
        }
        .buttonStyle(QuickActionButtonStyle(active: caffeine.active, activeTint: .yellow))
        .help((caffeine.active
               ? (caffeine.hold == .systemOnly
                  ? "Keeping the Mac awake, but the screen is free to sleep and lock. Right-click and tick \"Keep the screen on\" to hold it too. Click to turn off."
                  : "Keeping the Mac awake. The display won't sleep or lock. Click to turn off; right-click for a timer.")
               : "Keep the Mac awake. Display and system won't sleep. Click for on; right-click to set a timer.")
              + shortcutHint(.toggleCaffeine))
        .contextMenu {
            if caffeine.active {
                Button("Turn Off") { caffeine.deactivate() }
                Divider()
            }
            // How far the hold reaches, on the control it belongs to rather than three
            // clicks away in Settings. On the charger the display is held whatever this
            // says, so the switch is only ever about what happens on battery — and it
            // takes effect on the live session, not just the next one.
            Toggle("Keep the screen on", isOn: $settings.caffeineKeepDisplayOnBattery)
                .help("Off lets the screen sleep and lock on battery while tasks keep running. Saves several watts.")
            Divider()
            ForEach(CaffeineManager.Duration.allCases) { duration in
                Button(duration.title) { caffeine.activate(duration) }
            }
        }
    }

    /// Middot-joined, like the header's status line, and it always says how far the hold
    /// reaches.
    ///
    /// It used to name the reach only when the hold had narrowed, which meant the one
    /// state worth being sure about — the screen is being held — was the state that said
    /// nothing. "Keeping awake" over a screen that then locked itself is how the feature
    /// came to look broken.
    private var caffeineStatusText: String {
        let reach = caffeine.hold == .systemOnly ? "screen may sleep and lock" : "screen stays on"
        return ["Keeping awake", reach, caffeineTimeLeft()]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func caffeineTimeLeft() -> String? {
        guard let until = caffeine.expiresAt else { return nil }
        let mins = Int((max(0, until.timeIntervalSinceNow) / 60).rounded())
        guard mins >= 60 else { return "\(max(1, mins))m left" }
        let h = mins / 60, m = mins % 60
        return m > 0 ? "\(h)h \(m)m left" : "\(h)h left"
    }

    /// " · ⌃⌥⌘C" for a bound action, or nothing — appended to tooltips so the
    /// shortcuts are discoverable from the menu instead of only in Settings.
    private func shortcutHint(_ action: HotkeyAction) -> String {
        guard hotkeys.enabled, let key = hotkeys.bindings.hotkey(for: action) else { return "" }
        return " · \(key.displayString)"
    }

    private func actionButton(_ title: String, systemImage: String, help: String,
                              _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: DS.Space.xs) {
                HugeIcon(systemImage, size: DS.Icon.row)
                // Five tiles across 288pt leaves ~54pt each, and "Brighten" is wider than
                // that at `.caption2`. Scaling the one long label down a hair is invisible;
                // letting it wrap moves that tile's icon off the row's shared centre line.
                Text(title).font(DS.Typo.rowCaption).lineLimit(1).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Space.s)
        }
        .buttonStyle(QuickActionButtonStyle())
        .help(help)
    }

    // MARK: - Footer

    private var footer: some View {
        // Three labels and two icon buttons across 276pt is tight enough that the default
        // 16pt spacing pushed it over and SwiftUI resolved it by hyphenating "Settings"
        // into two lines. `lineLimit(1)` is the guarantee: a row of navigation labels is
        // never allowed to wrap, whatever the locale does to their width.
        HStack(spacing: DS.Space.m) {
            Button("Settings") { openDetached("settings") }
            Button("Details") { openDetached("details") }
                .disabled(!license.isPro)
            Button("History") { openDetached("history") }
                .disabled(!license.isPro)
            Spacer(minLength: DS.Space.s)
            // A 15pt glyph is a 15pt target unless it's given one. The frame costs
            // nothing visually and roughly doubles what you have to hit.
            Button { battery.refresh(); chargeLimit.refresh() } label: {
                HugeIcon("refresh", size: DS.Icon.row)
                    .frame(width: DS.Metric.hit, height: DS.Metric.hit)
                    .contentShape(Rectangle())
            }
            .help("Refresh")
            .foregroundStyle(.secondary)
            Button { NSApplication.shared.terminate(nil) } label: {
                HugeIcon("power", size: DS.Icon.row)
                    .frame(width: DS.Metric.hit, height: DS.Metric.hit)
                    .contentShape(Rectangle())
            }
            .help("Quit Battlify")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        // Was `.body`, which made the row that leaves the panel the largest text in it
        // after the percentage. Navigation is never bigger than what it navigates to.
        .font(DS.Typo.nav)
        .imageScale(.medium)
        .lineLimit(1)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func openDetached(_ id: String) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }

    // MARK: - Automation

    /// Lists any rule currently holding a setting, so an automatic change to the
    /// limit or mode is never a mystery.
    @ViewBuilder
    private var activeRulesSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ForEach(triggers.activeRules) { rule in
                // Same glyph column as every note and checklist row in the panel, so an
                // active rule lines up with them rather than starting on its own indent.
                HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
                    HugeIcon(rule.action.icon, size: DS.Icon.caption, weight: 2)
                        .foregroundStyle(Color.accentColor)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rule.displayName).font(DS.Typo.rowTitle)
                        Text(rule.actionSummary)
                            .font(DS.Typo.rowCaption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: DS.Space.s)
                }
                .frame(minHeight: DS.Metric.row)
            }
        }
    }

    // MARK: - Reusable bits

    /// A section: the rule that closes off whatever came before, then content on the
    /// shared inset. The rule leads rather than trails so the last section never leaves a
    /// line hanging under it with nothing beneath.
    private func section<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inset to the content margin, both sides. A full-bleed rule cuts the panel
            // into bands; the system's own menu panels stop their rules where the text
            // starts, which separates the groups without boxing them.
            DSSeparator(inset: 0)
                .padding(.horizontal, inset)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, inset)
                // Rows inside a section sit `Space.s` apart, so a section's own margin has
                // to be the next step up or the last row of one group and the first row of
                // the next read as neighbours with a line accidentally between them.
                .padding(.vertical, DS.Space.m)
        }
    }

    /// A banner: a full-bleed tinted band, not a floating card. Running it edge to edge is
    /// what separates "the app is telling you something" from "here is another box of
    /// settings" — and it's the one thing above the fold that isn't on the inset grid, so
    /// it reads as an interruption without needing a border to say so.
    private func notice<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, inset)
            .padding(.vertical, DS.Space.m)
            .background(Color.primary.opacity(0.05))
    }

    /// A title and a switch, with room for one more control before the switch.
    ///
    /// The extra slot is where a row's own overflow goes, so an action that belongs to a
    /// setting sits on that setting rather than in a strip of buttons further down.
    private func switchRow<Trailing: View>(
        _ title: String, _ value: Binding<Bool>,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        HStack(alignment: .center, spacing: DS.Space.xs) {
            Text(title).font(DS.Typo.rowTitle)
            Spacer(minLength: DS.Space.s)
            trailing()
                .padding(.trailing, DS.Space.hair)
            // The title is passed to the `Toggle` as well as drawn beside it. `labelsHidden`
            // hides it visually and keeps it as the switch's accessible name; a `Toggle("")`
            // announces itself as a switch and nothing else.
            Toggle(title, isOn: value)
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        // One height for every row in the app — see `DS.Metric.row`.
        .frame(minHeight: DS.Metric.row)
    }

    private func hintLabel(_ text: String, systemImage: String) -> some View {
        DSNote(icon: systemImage) { Text(text) }
    }

    // MARK: - Formatting

    private func statusLine(_ snap: BatterySnapshot) -> String {
        if snap.isFullyCharged { return "Fully charged" }
        if snap.isCharging { return "Charging" }
        if snap.isPluggedIn { return "Plugged in, not charging" }
        return "On battery"
    }

    /// Trailing words dropped ("2h 38m", not "2h 38m left"). They sit in a middot-joined
    /// line beside "On battery" or "Charging", which has already said which direction the
    /// number is going — repeating it is the sort of padding that makes one line into two.
    private func etaLine(_ snap: BatterySnapshot) -> String? {
        if snap.isCharging, let m = snap.timeToFull { return formatMinutes(m) }
        if !snap.isPluggedIn, let m = snap.timeToEmpty { return formatMinutes(m) }
        return nil
    }

    private func liveWattsLine(_ snap: BatterySnapshot) -> String? {
        let f = battery.powerFlow
        if snap.isPluggedIn, f.chargeWatts > 0.5 { return String(format: "%.1f W", f.chargeWatts) }
        if !snap.isPluggedIn, f.dischargeWatts > 0.5 { return String(format: "%.1f W", f.dischargeWatts) }
        return nil
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

/// Own view so it can hold the charging-pulse state. Motion is all in-place so
/// the popover never resizes mid-animation; the pulse runs only while charging
/// and the popover is open, so there's no idle cost.
private struct ChargeGauge: View {
    let percentage: Int
    let color: Color
    let limitEnabled: Bool
    let limit: Int
    let charging: Bool

    @State private var pulsing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let frac = max(0, min(1, CGFloat(percentage) / 100))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.10)).frame(height: 8)
                Capsule().fill(color)
                    .frame(width: max(8, w * frac), height: 8)
                    // Gentle breathing glow while charging (GPU-only opacity anim).
                    .opacity(charging && pulsing ? 0.55 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85), value: percentage)
                    .animation(.easeInOut(duration: 0.35), value: charging)
                    .animation(charging ? .easeInOut(duration: 1.15).repeatForever(autoreverses: true)
                                        : .default,
                               value: pulsing)
                if limitEnabled {
                    let x = w * CGFloat(limit) / 100
                    Rectangle()
                        .fill(Color.primary.opacity(0.65))
                        .frame(width: 2, height: 12)
                        .position(x: min(max(1, x), w - 1), y: 6)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: limit)
                        .transition(.opacity)
                }
            }
            .frame(height: 12)
        }
        // 12, not 15: the marker overhangs the 8pt track by 2pt on each side and nothing
        // else in here is taller, so the extra 3pt was blank panel above and below a bar
        // that is meant to sit tight under the percentage it belongs to.
        .frame(height: 12)
        .onAppear { pulsing = charging }
        .onChange(of: charging) { _, now in pulsing = now }
        .help(limitEnabled
              ? "Charge \(percentage)%. The marker shows your \(limit)% limit."
              : "Charge \(percentage)%.")
    }
}

/// The quick-action tile, and the only filled surface left in the panel.
///
/// Flat on purpose: in a panel with no cards, a tile carrying a gloss highlight and a drop
/// shadow would be the one thing pretending to float, and five of them in a row would put
/// the heaviest chrome in the panel on its least important controls. Fill and hairline
/// only; motion carries the feedback.
///
/// Hover changes fill, not size. These sit 8pt apart in a five-across row — scaling one up
/// visibly breaks the alignment of the row it's in, which is fine for a lone button and
/// wrong here. Press still scales, because that's the tile answering the click.
private struct QuickActionButtonStyle: ButtonStyle {
    var active: Bool = false
    var activeTint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        Tile(configuration: configuration, active: active, activeTint: activeTint)
    }

    private struct Tile: View {
        let configuration: Configuration
        let active: Bool
        let activeTint: Color
        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous)
            configuration.label
                .foregroundStyle(active ? AnyShapeStyle(activeTint) : AnyShapeStyle(.primary))
                .background {
                    shape.fill(active
                               ? AnyShapeStyle(activeTint.opacity(hovering ? 0.24 : 0.16))
                               : AnyShapeStyle(.quaternary.opacity(hovering ? 0.7 : 0.35)))
                }
                .overlay {
                    shape.strokeBorder((active ? activeTint : Color.primary)
                        .opacity(active ? 0.32 : (hovering ? 0.12 : 0.05)), lineWidth: 1)
                }
                // The whole tile is the target, including the gap between icon and label.
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
                .animation(.easeOut(duration: DS.Duration.hover), value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

