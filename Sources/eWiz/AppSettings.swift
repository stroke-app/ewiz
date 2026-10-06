import Foundation
import Combine
import AppKit

/// What text (if any) sits next to the menu-bar battery icon.
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    /// Icon only.
    case icon
    /// "82%"
    case percentage
    /// "2:15" — time to full while charging, time to empty on battery.
    case timeRemaining
    /// "82% · 2:15"
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .icon:          return "Icon only"
        case .percentage:    return "Percentage"
        case .timeRemaining: return "Time remaining"
        case .both:          return "Percentage & time"
        }
    }

    var showsPercentage: Bool { self == .percentage || self == .both }
    var showsTime: Bool { self == .timeRemaining || self == .both }
}

/// GUI-only display preferences (UserDefaults), separate from the daemon's charge policy.
@MainActor
final class AppSettings: ObservableObject {
    /// What the menu-bar item shows next to the icon.
    @Published var menuBarDisplay: MenuBarDisplay {
        didSet { defaults.set(menuBarDisplay.rawValue, forKey: Keys.display) }
    }
    @Published var colorMenuBarIcon: Bool {
        didSet { defaults.set(colorMenuBarIcon, forKey: Keys.colorIcon) }
    }
    /// Animate the glyph while charging. Off by default: the tick re-renders the
    /// status item twice a second, and a status-item relayout is expensive enough
    /// that it measured ~10% of a core for the whole time the Mac was plugged in.
    /// A battery app shouldn't spend that on a moving picture unless asked.
    @Published var animateMenuBarIcon: Bool {
        didSet { defaults.set(animateMenuBarIcon, forKey: Keys.animateIcon) }
    }
    @Published var batteryIconStyle: BatteryIconStyle {
        didSet { defaults.set(batteryIconStyle.rawValue, forKey: Keys.iconStyle) }
    }
    /// Shake the menu-bar glyph as the battery runs out. See `LowBatteryAlarm`.
    @Published var shakeOnLowBattery: Bool {
        didSet { defaults.set(shakeOnLowBattery, forKey: Keys.shakeOnLow) }
    }
    /// Off by default so we don't prompt for notification permission until opt-in.
    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) }
    }
    /// Caffeine: end the session the moment you unplug. Off by default — work keeps
    /// running on battery, just without the screen (see below).
    @Published var caffeineEndOnBattery: Bool {
        didSet { defaults.set(caffeineEndOnBattery, forKey: Keys.caffeineEndOnBattery) }
    }
    /// Caffeine: keep the screen lit on battery too. On by default.
    ///
    /// It was off, on the argument that a lit idle screen costs percents per hour and a
    /// system-only hold finishes the same work. True, and beside the point: the control is
    /// a coffee cup labelled "Awake", and a Mac whose screen has gone dark and locked
    /// itself is not awake by any reading a user would recognise. Turning it on and
    /// watching the display sleep anyway reads as the feature being broken, which is a
    /// worse outcome than the watts. The saving is still one click away, on the tile
    /// itself — see `caffeineButton`.
    @Published var caffeineKeepDisplayOnBattery: Bool {
        didSet { defaults.set(caffeineKeepDisplayOnBattery, forKey: Keys.caffeineDisplayOnBattery) }
    }
    /// Occasionally suggest a restart once the Mac has been running a long time.
    @Published var restReminderEnabled: Bool {
        didSet { defaults.set(restReminderEnabled, forKey: Keys.restReminder) }
    }
    /// Experimental: flash an animation over the screen when the adapter connects.
    @Published var chargeOverlayEnabled: Bool {
        didSet { defaults.set(chargeOverlayEnabled, forKey: Keys.overlayEnabled) }
    }
    @Published var chargeOverlayStyle: ChargeOverlayStyle {
        didSet { defaults.set(chargeOverlayStyle.rawValue, forKey: Keys.overlayStyle) }
    }
    /// How long the animation runs, in seconds. Capped low on purpose — it covers the
    /// screen, so it has to be over before it becomes something to wait out.
    @Published var chargeOverlayDuration: Double {
        didSet { defaults.set(chargeOverlayDuration, forKey: Keys.overlayDuration) }
    }
    /// Also play it (in its cooler variant) when the adapter is pulled out.
    @Published var chargeOverlayOnUnplug: Bool {
        didSet { defaults.set(chargeOverlayOnUnplug, forKey: Keys.overlayOnUnplug) }
    }
    /// Tap the trackpad on plug and unplug.
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }
    /// Play a short synthesised cue on plug, unplug and charge complete. Off by default:
    /// a sound is the one kind of feedback you can't look away from.
    @Published var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.sound) }
    }
    /// Cue volume, independent of system volume, 0…1.
    ///
    /// Its own control rather than "however loud your Mac is": system volume is set for
    /// whatever you're listening to, and a notification chime riding along at that level
    /// is how apps end up being muted entirely.
    @Published var soundVolume: Double {
        didSet { defaults.set(soundVolume, forKey: Keys.soundVolume) }
    }
    /// Which of the cue voicings to play. See `ChargeSound.Theme`.
    @Published var soundTheme: ChargeSound.Theme {
        didSet { defaults.set(soundTheme.rawValue, forKey: Keys.soundTheme) }
    }
    /// Play eWiz's animations even when macOS's Reduce Motion is on.
    ///
    /// Reduce Motion is respected by default, as it should be. But it's a system-wide
    /// preference, and someone who turns on a charging animation *in this app* has said
    /// what they want for this app — without an override, every animation here silently
    /// does nothing and looks broken instead of considerate.
    @Published var animateWithReduceMotion: Bool {
        didSet { defaults.set(animateWithReduceMotion, forKey: Keys.animateAnyway) }
    }

    /// Whether motion is allowed right now: either the system isn't asking us to reduce
    /// it, or the user has explicitly overridden that for eWiz.
    var motionAllowed: Bool {
        animateWithReduceMotion || !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Whether a cue may sound right now.
    ///
    /// Reduce Motion gates audio as well as animation. It isn't a sound setting, but it's
    /// the closest thing macOS has to one: people who turn it on are usually saying they
    /// don't want to be startled, not just that they dislike parallax. Gating on it costs
    /// nothing here because the "Animate anyway" override already exists for anyone who
    /// does want the feedback — and it's spelled out in Settings rather than left as a
    /// surprise.
    var soundAllowed: Bool { soundEnabled && motionAllowed }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let showPct = "menubar.showPercentage"   // legacy Bool, migrated below
        static let display = "menubar.display"
        static let colorIcon = "menubar.colorIcon"
        static let animateIcon = "menubar.animateIcon"
        static let iconStyle = "menubar.iconStyle"
        static let notifications = "notifications.enabled"
        static let shakeOnLow = "menubar.shakeOnLowBattery"
        static let caffeineEndOnBattery = "caffeine.endOnBattery"
        static let caffeineDisplayOnBattery = "caffeine.keepDisplayOnBattery"
        static let caffeineDisplayMigrated = "caffeine.keepDisplayOnBattery.defaultedOn"
        static let restReminder = "rest.reminderEnabled"
        static let overlayEnabled = "overlay.enabled"
        static let overlayStyle = "overlay.style"
        static let overlayDuration = "overlay.duration"
        static let overlayOnUnplug = "overlay.onUnplug"
        static let haptics = "feedback.haptics"
        static let sound = "feedback.sound"
        static let soundVolume = "feedback.soundVolume"
        static let soundTheme = "feedback.soundTheme"
        static let animateAnyway = "motion.overrideReduceMotion"
    }

    init() {
        // Migrate the old show-percentage Bool: off → icon only, on (or unset,
        // the first-run default) → percentage.
        if let raw = defaults.string(forKey: Keys.display),
           let mode = MenuBarDisplay(rawValue: raw) {
            menuBarDisplay = mode
        } else {
            menuBarDisplay = (defaults.object(forKey: Keys.showPct) as? Bool ?? true)
                ? .percentage : .icon
        }
        colorMenuBarIcon = defaults.object(forKey: Keys.colorIcon) as? Bool ?? true
        animateMenuBarIcon = defaults.bool(forKey: Keys.animateIcon)
        batteryIconStyle = (defaults.string(forKey: Keys.iconStyle))
            .flatMap(BatteryIconStyle.init(rawValue:)) ?? .rounded
        notificationsEnabled = defaults.bool(forKey: Keys.notifications)
        shakeOnLowBattery = defaults.object(forKey: Keys.shakeOnLow) as? Bool ?? true
        caffeineEndOnBattery = defaults.bool(forKey: Keys.caffeineEndOnBattery)
        // Migrated once, not simply re-defaulted. Anyone who ran an earlier build has a
        // `false` on disk — written either by the old default or by trying the switch and
        // putting it back — and reading that straight back would leave the old behaviour
        // in place for exactly the people this change is for. The flag makes it a
        // one-time correction: whatever is set after this migration is the user's.
        if defaults.object(forKey: Keys.caffeineDisplayMigrated) == nil {
            defaults.set(true, forKey: Keys.caffeineDisplayOnBattery)
            defaults.set(true, forKey: Keys.caffeineDisplayMigrated)
        }
        caffeineKeepDisplayOnBattery =
            defaults.object(forKey: Keys.caffeineDisplayOnBattery) as? Bool ?? true
        restReminderEnabled = defaults.object(forKey: Keys.restReminder) as? Bool ?? true
        chargeOverlayEnabled = defaults.bool(forKey: Keys.overlayEnabled)
        chargeOverlayStyle = defaults.string(forKey: Keys.overlayStyle)
            .flatMap(ChargeOverlayStyle.init(rawValue:)) ?? .dotGrid
        // 0 means "never set" — a fresh install gets the default, not an instant flash.
        let storedDuration = defaults.double(forKey: Keys.overlayDuration)
        chargeOverlayDuration = storedDuration > 0 ? min(2.0, max(0.5, storedDuration)) : 1.0
        chargeOverlayOnUnplug = defaults.bool(forKey: Keys.overlayOnUnplug)
        hapticsEnabled = defaults.bool(forKey: Keys.haptics)
        soundEnabled = defaults.bool(forKey: Keys.sound)
        // 0 means "never set", same as the overlay duration above — a fresh install gets
        // the subtle default rather than a silent toggle that looks broken when switched on.
        let storedVolume = defaults.double(forKey: Keys.soundVolume)
        soundVolume = storedVolume > 0 ? min(1, storedVolume) : ChargeSound.defaultVolume
        soundTheme = defaults.string(forKey: Keys.soundTheme)
            .flatMap(ChargeSound.Theme.init(rawValue:)) ?? ChargeSound.defaultTheme
        animateWithReduceMotion = defaults.bool(forKey: Keys.animateAnyway)
    }
}
