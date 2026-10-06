import Foundation
import Combine
import CoreGraphics
import IOKit.pwr_mgt

/// How far a keep-awake hold reaches.
public enum KeepAwakeHold: String, Sendable, Equatable {
    /// The screen stays lit too (what `caffeinate -d` holds).
    case displayOn
    /// Work keeps running but the screen may sleep (`caffeinate -i`). On battery this
    /// is the difference between several watts and a few tenths of one.
    case systemOnly

    public var title: String {
        switch self {
        case .displayOn:  return "Screen stays on"
        case .systemOnly: return "Tasks keep running, screen may sleep"
        }
    }
}

/// The OS "keep awake" primitive, abstracted so `CaffeineManager` can be unit-tested
/// without touching IOKit.
public protocol KeepAwakeAsserting: Sendable {
    /// Acquire a hold that stops idle-sleep. Returns a non-zero token, or 0 on failure.
    func acquire(kind: KeepAwakeHold, reason: String) -> UInt32
    func release(_ token: UInt32)

    /// Push back the screen-saver and lock-screen timers.
    ///
    /// A display-sleep assertion is *not* enough on its own: it stops the display idling
    /// out, but the screen saver runs off how long it's been since the user did anything,
    /// and locking follows the screen saver. Hold only the assertion and a Mac left alone
    /// still slides behind the lock screen — which is what "keep awake" is supposed to
    /// prevent. Declaring user activity is the one public lever that resets that clock,
    /// and it buys one display-sleep timer's worth, so it has to be repeated.
    ///
    /// Returns false when the backend can't do this at all, which tells the caller to
    /// stop asking.
    func keepUserActive(reason: String) -> Bool
    /// Drop the user-active declaration. The timers pick up from the last call.
    func endUserActive()
}

public extension KeepAwakeAsserting {
    func keepUserActive(reason: String) -> Bool { false }
    func endUserActive() {}
}

/// Real backend: an IOPM idle-sleep assertion, display-wide or system-only. Needs no
/// root; auto-released on process exit, so it can't strand the Mac awake.
///
/// A class, not a struct, because the user-activity declaration hands back an ID that
/// has to be given straight back on the next call — IOKit re-uses or re-issues it
/// depending on how long it's been.
public final class IOKitKeepAwake: KeepAwakeAsserting, @unchecked Sendable {
    private let lock = NSLock()
    private var activityID: IOPMAssertionID = 0

    public init() {}

    public func acquire(kind: KeepAwakeHold, reason: String) -> UInt32 {
        var id: IOPMAssertionID = 0
        let type = kind == .displayOn
            ? kIOPMAssertPreventUserIdleDisplaySleep
            : kIOPMAssertPreventUserIdleSystemSleep
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id)
        return result == kIOReturnSuccess ? id : 0
    }

    public func release(_ token: UInt32) {
        if token != 0 { IOPMAssertionRelease(token) }
    }

    public func keepUserActive(reason: String) -> Bool {
        // Declaring activity powers the display back on, so don't do it to a screen the
        // user just switched off deliberately — resting, the Off button, ⌃⇧⏻. Still
        // "supported", so the caller keeps checking back rather than giving up.
        guard CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return true }
        lock.withLock {
            var id = activityID
            // The name is distinct from the hold's: two assertions from one process, and
            // anything reading them back (tests included) should be able to tell them apart.
            if IOPMAssertionDeclareUserActivity("\(reason): user active" as CFString,
                                                kIOPMUserActiveLocal, &id) == kIOReturnSuccess {
                activityID = id
            }
        }
        return true
    }

    public func endUserActive() {
        lock.withLock {
            if activityID != 0 { IOPMAssertionRelease(activityID); activityID = 0 }
        }
    }

    deinit { endUserActive() }
}

/// "Caffeine" mode: keep the Mac awake (display on, no idle-sleep) until turned off
/// or a timer ends. Holds one user-space assertion — no root, works on battery and AC.
/// Intentionally does *not* stop lid-close sleep, matching Caffeine/Amphetamine.
@MainActor
public final class CaffeineManager: ObservableObject {
    @Published public private(set) var active = false
    /// When a timed session auto-releases (nil = indefinite or inactive).
    @Published public private(set) var expiresAt: Date?
    /// What the live hold currently covers (nil = nothing held).
    @Published public private(set) var hold: KeepAwakeHold?

    /// Keep the screen lit on battery too. Off by default: an idle Mac with its display
    /// on is the most expensive thing this app can do to a battery (several watts, so
    /// percents per hour), while holding only the system awake still finishes the work
    /// for almost nothing.
    public private(set) var keepDisplayOnBattery = false
    /// End the session outright when unplugged — for a Mac that should never lose charge
    /// while left alone.
    public private(set) var endOnBattery = false
    /// Assume AC until the app says otherwise, so a hold is never silently weakened.
    public private(set) var onExternalPower = true

    private let backend: KeepAwakeAsserting
    private let reason: String
    /// Where a live session is remembered across launches, or nil to remember nothing.
    ///
    /// Nil by default on purpose: the tests build their own manager per case, and a
    /// default of `.standard` would have them reading and writing the real app's session.
    private let sessionStore: UserDefaults?
    private static let sessionKey = "caffeine.session"
    private var didRestore = false
    /// Injectable delay so timed-expiry can be driven deterministically in tests.
    private let sleepFor: @Sendable (TimeInterval) async -> Void
    private var token: UInt32 = 0
    private var expiryTask: Task<Void, Never>?
    /// How often the screen-saver/lock clock gets pushed back while the screen is held on.
    /// Comfortably under the shortest screen-saver setting macOS offers (one minute).
    private let userActivityInterval: TimeInterval
    private var activityTask: Task<Void, Never>?

    public init(backend: KeepAwakeAsserting = IOKitKeepAwake(),
                reason: String = "eWiz: Caffeine (keep awake)",
                sessionStore: UserDefaults? = nil,
                userActivityInterval: TimeInterval = 30,
                sleepFor: @escaping @Sendable (TimeInterval) async -> Void = { seconds in
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }) {
        self.backend = backend
        self.reason = reason
        self.sessionStore = sessionStore
        self.userActivityInterval = userActivityInterval
        self.sleepFor = sleepFor
    }

    /// Preset keep-awake durations offered in the menu.
    public enum Duration: String, Identifiable, CaseIterable, Sendable {
        case indefinite, min30, hour1, hours2, hours5

        public var id: String { rawValue }

        /// Seconds to hold, or nil for "until turned off".
        public var seconds: TimeInterval? {
            switch self {
            case .indefinite: return nil
            case .min30:      return 30 * 60
            case .hour1:      return 60 * 60
            case .hours2:     return 2 * 3600
            case .hours5:     return 5 * 3600
            }
        }

        public var title: String {
            switch self {
            case .indefinite: return "Until I turn it off"
            case .min30:      return "For 30 minutes"
            case .hour1:      return "For 1 hour"
            case .hours2:     return "For 2 hours"
            case .hours5:     return "For 5 hours"
            }
        }
    }

    public func toggle() { active ? deactivate() : activate(.indefinite) }

    /// Start keep-awake (or re-arm the timer with a new duration if already on).
    /// Idempotent: never stacks more than one assertion.
    public func activate(_ duration: Duration = .indefinite) {
        engage(holdingFor: duration.seconds)
    }

    /// Re-engage a session that was still running when the app last quit.
    ///
    /// The hold is a power assertion owned by this process, so it dies with the process —
    /// and this app restarts itself to install updates. That silently dropped the hold:
    /// the tile still read on, nothing in the panel changed, and the screen went dark
    /// half an hour later with the user certain they had turned Awake on. It also went
    /// for a crash, and for every `pkill` during development, which is how it stayed
    /// invisible. Idempotent, because the only reliable launch hook in a menu-bar app is
    /// the status-item label's body, which runs many times.
    public func restoreSessionIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        guard let sessionStore,
              let stored = sessionStore.object(forKey: Self.sessionKey) as? Double else { return }
        // 0 is the indefinite session; anything else is a deadline.
        guard stored != 0 else { engage(holdingFor: nil); return }
        let remaining = Date(timeIntervalSince1970: stored).timeIntervalSinceNow
        guard remaining > 0 else {
            sessionStore.removeObject(forKey: Self.sessionKey)
            return
        }
        engage(holdingFor: remaining)
    }

    /// Take the hold, for a number of seconds or until told otherwise.
    private func engage(holdingFor seconds: TimeInterval?) {
        expiryTask?.cancel(); expiryTask = nil

        if token == 0 {
            token = backend.acquire(kind: desiredHold, reason: reason)
            guard token != 0 else { active = false; expiresAt = nil; hold = nil; return }
            hold = desiredHold
        }
        active = true
        syncUserActivity()

        guard let seconds else { expiresAt = nil; saveSession(); return }
        expiresAt = Date().addingTimeInterval(seconds)
        saveSession()
        // Runs on the main actor; the cancel + isCancelled check drops it if state changes.
        expiryTask = Task { [weak self, sleepFor] in
            await sleepFor(seconds)
            guard !Task.isCancelled else { return }
            self?.deactivate()
        }
    }

    /// Remember the session across launches, or forget it. See `restoreSessionIfNeeded`.
    private func saveSession() {
        guard let sessionStore else { return }
        guard active else {
            sessionStore.removeObject(forKey: Self.sessionKey)
            return
        }
        sessionStore.set(expiresAt?.timeIntervalSince1970 ?? 0, forKey: Self.sessionKey)
    }

    /// Release keep-awake and let the Mac sleep/dim normally again. No-op if inactive.
    public func deactivate() {
        expiryTask?.cancel(); expiryTask = nil
        if token != 0 { backend.release(token); token = 0 }
        active = false
        expiresAt = nil
        hold = nil
        // Before `syncUserActivity`, so a session ended by its own timer is forgotten
        // even if releasing the activity declaration throws.
        saveSession()
        syncUserActivity()
    }

    /// Keep the screen-saver and lock clocks pushed back for as long as — and only as
    /// long as — the screen itself is being held on. A system-only hold means the screen
    /// is *allowed* to sleep, so locking behind it is the user's own setting, not a bug.
    private func syncUserActivity() {
        activityTask?.cancel()
        guard active, hold == .displayOn else {
            activityTask = nil
            backend.endUserActive()
            return
        }
        activityTask = Task { [backend, reason, sleepFor, userActivityInterval] in
            while !Task.isCancelled {
                // Declare first, so turning Caffeine on resets the clock immediately —
                // and a backend that can't do this at all drops out here rather than
                // spinning on a call that does nothing.
                guard backend.keepUserActive(reason: reason) else { return }
                await sleepFor(userActivityInterval)
            }
        }
    }

    /// Push the policy and the current power source in one idempotent call, so the app
    /// can hand it over on every render instead of wiring up another observer.
    public func applyPolicy(keepDisplayOnBattery: Bool,
                            endOnBattery: Bool,
                            onExternalPower: Bool) {
        guard keepDisplayOnBattery != self.keepDisplayOnBattery
                || endOnBattery != self.endOnBattery
                || onExternalPower != self.onExternalPower else { return }
        self.keepDisplayOnBattery = keepDisplayOnBattery
        self.endOnBattery = endOnBattery
        self.onExternalPower = onExternalPower
        reconcileHold()
    }

    private var desiredHold: KeepAwakeHold {
        (onExternalPower || keepDisplayOnBattery) ? .displayOn : .systemOnly
    }

    /// Bring the live hold in line with the policy: end the session on battery if asked,
    /// otherwise swap the assertion for the right kind. The replacement is acquired
    /// before the old one is released, so there's never a gap the display can sleep in,
    /// and the expiry timer keeps running — the session continues, only its reach changes.
    private func reconcileHold() {
        guard active, token != 0 else { return }
        if endOnBattery, !onExternalPower { deactivate(); return }
        guard hold != desiredHold else { return }
        let replacement = backend.acquire(kind: desiredHold, reason: reason)
        guard replacement != 0 else { return }   // keep what we have if the swap fails
        backend.release(token)
        token = replacement
        hold = desiredHold
        // Unplugging narrows the hold to system-only; the screen is then free to sleep
        // and lock, so stop insisting the user is active.
        syncUserActivity()
    }

    deinit {
        activityTask?.cancel()
        backend.endUserActive()
        if token != 0 { backend.release(token) }
    }
}
