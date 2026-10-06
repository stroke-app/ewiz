import Foundation
import Combine
import AppKit
import EWizKit

/// Runs the "while … " automation rules.
///
/// Each tick it probes the system, works out which rules hold, and reconciles the
/// settings they own: the first active rule that targets a setting wins, its value
/// is applied, and the value from before the rule fired is put back once no rule
/// wants it any more. Restoring is skipped if you changed that setting yourself in
/// the meantime, so a rule can never undo a deliberate choice.
///
/// Rules are evaluated in the GUI (they need AppKit, CoreWLAN, CoreAudio) and
/// carried out through the root daemon via `ChargeLimitStore`, so they live in
/// UserDefaults rather than the daemon's config.
@MainActor
final class TriggerStore: ObservableObject {
    @Published var rules: [TriggerRule] = [] {
        didSet {
            guard rules != oldValue else { return }
            persist()
            reconfigure()
        }
    }
    /// Latest system reading (only the sensors in use are populated).
    @Published private(set) var snapshot = TriggerSnapshot()
    /// Rules whose conditions currently hold.
    @Published private(set) var activeRuleIDs: Set<UUID> = []
    /// When each active rule last became active, for the "Active for 12 min" label.
    @Published private(set) var activeSince: [UUID: Date] = [:]

    /// Set by the app at launch.
    weak var chargeLimit: ChargeLimitStore?
    weak var battery: BatteryStore?

    private let defaults = UserDefaults.standard
    private let cpu = CPUSampler()
    private var timer: Timer?
    private var pendingEvaluation: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    /// Extra sensors to read while a settings view is showing live state.
    private var viewers = 0

    private enum Keys { static let rules = "triggers.rules" }

    init() {
        rules = Self.load(defaults)
    }

    /// Wire up the stores the actions run through, then start evaluating.
    func attach(chargeLimit: ChargeLimitStore, battery: BatteryStore) {
        guard self.chargeLimit == nil else { return }
        self.chargeLimit = chargeLimit
        self.battery = battery

        // React the moment power state changes rather than waiting for a poll.
        battery.$snapshot
            .map { [$0.isCharging, $0.isPluggedIn] }
            .removeDuplicates()
            .sink { [weak self] _ in self?.evaluateSoon() }
            .store(in: &cancellables)

        observeSystemEvents()
        reconfigure()
    }

    // MARK: - Rule editing

    func addRule(_ rule: TriggerRule) { rules.append(rule) }

    func updateOrAddRule(_ rule: TriggerRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
        } else {
            rules.append(rule)
        }
    }

    func removeRule(_ rule: TriggerRule) {
        rules.removeAll { $0.id == rule.id }
        // Drop anything it was holding so the previous settings come back now.
        releaseOwnership(of: rule.id)
    }

    func setEnabled(_ enabled: Bool, for rule: TriggerRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index].enabled = enabled
        if !enabled { releaseOwnership(of: rule.id) }
    }

    func isActive(_ rule: TriggerRule) -> Bool { activeRuleIDs.contains(rule.id) }

    /// Rules currently holding a setting, in the order they're applied.
    var activeRules: [TriggerRule] { rules.filter { activeRuleIDs.contains($0.id) } }

    // MARK: - Live state for the settings UI

    /// Called from `.onAppear` of a view showing live system state: while it's up
    /// we read every sensor (not just the ones rules use) on a faster tick.
    func beginObserving() {
        viewers += 1
        reconfigure()
    }

    /// Called from `.onDisappear`.
    func endObserving() {
        viewers = max(0, viewers - 1)
        reconfigure()
    }

    // MARK: - Scheduling

    /// Sensors we need this tick: everything while a live view is open, otherwise
    /// only what the enabled rules actually reference.
    private var kindsInUse: Set<TriggerKind> {
        if viewers > 0 { return Set(TriggerKind.allCases) }
        return Set(rules.filter(\.enabled).flatMap { $0.conditions.map(\.kind) })
    }

    /// Start, retime, or stop the poll depending on what's needed right now.
    private func reconfigure() {
        timer?.invalidate()
        timer = nil
        guard chargeLimit != nil else { return }

        let kinds = kindsInUse
        guard !kinds.isEmpty else {
            // Nothing to watch — make sure nothing is left applied.
            releaseAllOwnership()
            snapshot = TriggerSnapshot()
            activeRuleIDs = []
            activeSince = [:]
            return
        }

        cpu.reset()   // the interval changed; start a fresh CPU measurement
        let interval: TimeInterval = viewers > 0 ? 4 : 12
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        t.tolerance = interval / 4
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // Deliberately not synchronous: `reconfigure` runs from `rules`' `didSet`,
        // and evaluating there would publish more changes from inside that write.
        evaluateSoon()
    }

    /// Re-evaluate shortly, coalescing bursts of events (an app launch storm, a
    /// display waking) into a single pass.
    private func evaluateSoon() {
        pendingEvaluation?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.evaluate() }
        }
        pendingEvaluation = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        let workspaceEvents: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didWakeNotification,
        ]
        for name in workspaceEvents {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                Task { @MainActor in self?.evaluateSoon() }
            })
        }
        // Display attach/detach, resolution changes, clamshell docking.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluateSoon() }
        })
    }

    // MARK: - Evaluation

    /// Flip-flop guard: a rule only changes state once its raw result repeats.
    private var lastRawMatch: [UUID: Bool] = [:]
    private var matchStreak: [UUID: Int] = [:]

    private func evaluate() {
        let kinds = kindsInUse
        guard !kinds.isEmpty else { return }

        let reading = TriggerSensors.probe(
            kinds: kinds,
            battery: battery?.snapshot ?? BatteryMonitor.read(),
            cpu: cpu)
        // Only publish when something actually moved.
        if reading != snapshot { snapshot = reading }

        var active: Set<UUID> = []
        for rule in rules where rule.enabled {
            if settled(rule, matches: rule.isSatisfied(by: reading)) { active.insert(rule.id) }
        }

        if active != activeRuleIDs {
            let now = Date()
            for id in active.subtracting(activeRuleIDs) { activeSince[id] = now }
            for id in activeRuleIDs.subtracting(active) { activeSince[id] = nil }
            activeRuleIDs = active
        }
        // Forget state for rules that no longer exist.
        let known = Set(rules.map(\.id))
        lastRawMatch = lastRawMatch.filter { known.contains($0.key) }
        matchStreak = matchStreak.filter { known.contains($0.key) }

        reconcileActions()
    }

    /// Whether a rule's raw result has held long enough to act on. Thresholds on
    /// noisy values (CPU, battery %) need two consecutive polls; everything else
    /// is event-driven and acts immediately.
    private func settled(_ rule: TriggerRule, matches raw: Bool) -> Bool {
        let wasActive = activeRuleIDs.contains(rule.id)
        if raw == wasActive {
            lastRawMatch[rule.id] = raw
            matchStreak[rule.id] = 0
            return wasActive
        }
        // The raw result disagrees with the current state — count how long for.
        if lastRawMatch[rule.id] == raw {
            matchStreak[rule.id, default: 0] += 1
        } else {
            lastRawMatch[rule.id] = raw
            matchStreak[rule.id] = 1
        }
        let required = rule.needsConfirmation ? 2 : 1
        return (matchStreak[rule.id] ?? 0) >= required ? raw : wasActive
    }

    // MARK: - Applying actions

    /// A setting a rule can take over. One owner at a time.
    private enum Field: CaseIterable {
        case mode, chargeLimit, hold, keepAwake, lowPower, chargePower
    }

    private enum FieldValue: Equatable {
        case mode(SaveMode)
        case int(Int)
        case flag(Bool)
    }

    /// What the setting was before a rule took it over.
    private var baseline: [Field: FieldValue] = [:]
    /// What we last pushed, so a manual change afterwards is detectable.
    private var applied: [Field: FieldValue] = [:]
    /// Which rule owns each field.
    private var owner: [Field: UUID] = [:]

    /// Bring every setting in line with the active rules.
    private func reconcileActions() {
        guard let charge = chargeLimit, charge.daemonAvailable else { return }
        let active = activeRules

        for field in Field.allCases {
            guard let rule = active.first(where: { Self.field(for: $0.action) == field }) else {
                restore(field)
                continue
            }
            let wanted = value(of: rule)
            if baseline[field] == nil {
                baseline[field] = current(field, charge)
            }
            owner[field] = rule.id
            guard applied[field] != wanted else { continue }
            apply(field, wanted, charge)
            applied[field] = wanted
        }
    }

    /// Put a field back the way it was, unless it's been changed by hand since.
    private func restore(_ field: Field) {
        guard let charge = chargeLimit,
              let original = baseline[field] else { return }
        defer {
            baseline[field] = nil
            applied[field] = nil
            owner[field] = nil
        }
        // Only revert what we actually set — if the value moved since, that was
        // the user (or another feature), and their choice stands.
        guard applied[field] == nil || current(field, charge) == applied[field] else { return }
        // Never re-impose a pause that was in force before the rule ran: it may
        // have been a timed pause we can't reproduce.
        if field == .hold, original == .flag(true) { return }
        guard original != current(field, charge) else { return }
        apply(field, original, charge)
    }

    /// Release everything a rule was holding (it was deleted or switched off).
    private func releaseOwnership(of ruleID: UUID) {
        for (field, holder) in owner where holder == ruleID { restore(field) }
        activeRuleIDs.remove(ruleID)
        activeSince[ruleID] = nil
    }

    private func releaseAllOwnership() {
        for field in Field.allCases where owner[field] != nil { restore(field) }
    }

    private static func field(for action: TriggerAction) -> Field {
        switch action {
        case .mode:         return .mode
        case .chargeLimit:  return .chargeLimit
        case .holdCharging: return .hold
        case .keepAwake:    return .keepAwake
        case .lowPowerMode: return .lowPower
        case .chargePower:  return .chargePower
        }
    }

    private func value(of rule: TriggerRule) -> FieldValue {
        switch rule.action {
        case .mode:         return .mode(rule.mode)
        case .chargeLimit:  return .int(rule.percent)
        case .holdCharging: return .flag(true)
        case .keepAwake:    return .flag(true)
        case .lowPowerMode: return .flag(true)
        case .chargePower:  return .int(rule.percent)
        }
    }

    private func current(_ field: Field, _ charge: ChargeLimitStore) -> FieldValue {
        switch field {
        case .mode:        return .mode(charge.mode)
        // 0 stands for "limit off", matching a rule's percent of 0.
        case .chargeLimit: return .int(charge.limitEnabled ? charge.limit : 0)
        case .hold:        return .flag(charge.isPausedIndefinitely)
        case .keepAwake:   return .flag(charge.keepAwake)
        case .lowPower:    return .flag(charge.lowPowerMode)
        case .chargePower: return .int(charge.chargePower)
        }
    }

    private func apply(_ field: Field, _ value: FieldValue, _ charge: ChargeLimitStore) {
        switch (field, value) {
        case (.mode, .mode(let mode)):
            charge.applyMode(mode)
        case (.chargeLimit, .int(let percent)):
            if percent > 0 {
                charge.limitEnabled = true
                charge.limit = percent
            } else {
                charge.limitEnabled = false
            }
            charge.apply()
        case (.hold, .flag(let on)):
            if on { charge.pauseCharging(minutes: -1) } else { charge.resumeCharging() }
        case (.keepAwake, .flag(let on)):
            charge.keepAwake = on
            charge.apply()
        case (.lowPower, .flag(let on)):
            charge.setLowPowerMode(on)
        case (.chargePower, .int(let percent)):
            charge.chargePower = percent
            charge.apply()
        default:
            break
        }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Keys.rules)
    }

    private static func load(_ defaults: UserDefaults) -> [TriggerRule] {
        guard let data = defaults.data(forKey: Keys.rules),
              let list = try? JSONDecoder().decode([TriggerRule].self, from: data)
        else { return [] }
        return list
    }
}

extension TriggerStore {
    /// Ready-made starting points offered in the "Start from an example" menu.
    /// Built once so the menu rows keep a stable identity; picking one takes a
    /// copy with a fresh id, so the same example can be used twice.
    static let templates: [TriggerRule] = [
        TriggerRule(label: "Docked at a display",
                    conditions: [TriggerCondition(kind: .externalDisplay)],
                    action: .chargeLimit, percent: 80),
        TriggerRule(label: "Heavy app: charge to full",
                    conditions: [TriggerCondition(kind: .appRunning, text: "Final Cut Pro")],
                    action: .chargeLimit, percent: 100),
        TriggerRule(label: "Long build: stay awake",
                    conditions: [TriggerCondition(kind: .cpuAbove, threshold: 60)],
                    action: .keepAwake),
        TriggerRule(label: "On a specific Wi-Fi network",
                    conditions: [TriggerCondition(kind: .wifiNetwork)],
                    action: .mode, mode: .normal),
    ]
}
