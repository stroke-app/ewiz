import Foundation

/// Modifier flags, using Carbon's `cmdKey`/`shiftKey`/`optionKey`/`controlKey`
/// bit values so the raw number can be handed straight to `RegisterEventHotKey`
/// without a conversion table. Defined here (rather than importing Carbon) to keep
/// this model free of AppKit/Carbon so it stays unit-testable.
public struct HotkeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    public static let command = HotkeyModifiers(rawValue: 1 << 8)   // cmdKey     256
    public static let shift   = HotkeyModifiers(rawValue: 1 << 9)   // shiftKey   512
    public static let option  = HotkeyModifiers(rawValue: 1 << 11)  // optionKey  2048
    public static let control = HotkeyModifiers(rawValue: 1 << 12)  // controlKey 4096

    /// Modifiers that make a key safe to grab globally. Shift alone doesn't count —
    /// binding ⇧A would swallow a capital A everywhere on the system.
    public static let qualifying: HotkeyModifiers = [.command, .option, .control]

    /// macOS renders modifiers in a fixed order regardless of press order: ⌃⌥⇧⌘.
    /// One glyph per element so a view can space them out — set solid they read as
    /// a single dense blob at small sizes.
    public var glyphs: [String] {
        var g: [String] = []
        if contains(.control) { g.append("⌃") }
        if contains(.option)  { g.append("⌥") }
        if contains(.shift)   { g.append("⇧") }
        if contains(.command) { g.append("⌘") }
        return g
    }

    /// The glyphs run together, for plain-text contexts (menus, help, warnings).
    public var symbols: String { glyphs.joined() }
}

/// A global keyboard shortcut: a virtual key code plus modifier flags.
public struct Hotkey: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: HotkeyModifiers

    public init(keyCode: UInt32, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// A shortcut with no ⌃/⌥/⌘ would intercept ordinary typing system-wide, so it's
    /// rejected at the recorder rather than registered and mysteriously eaten.
    public var isValid: Bool { !modifiers.isDisjoint(with: .qualifying) }

    /// True for chords built only from ⌘ and ⇧, like ⌘D or ⇧⌘D.
    ///
    /// Those are valid to register and useless in practice: a global grab happens before the
    /// frontmost app sees the keystroke, so binding ⌘D swallows Duplicate everywhere, and
    /// ⇧⌘D swallows Send in Mail. ⌃ or ⌥ in the chord is what keeps it out of the range
    /// ordinary app shortcuts live in. Reported rather than rejected: it's the user's
    /// keyboard, but it should be a deliberate choice.
    public var collidesWithAppShortcuts: Bool {
        modifiers.isDisjoint(with: [.control, .option])
    }

    /// "⌃⌥⌘C" — what the settings row and menu hints show.
    public var displayString: String { modifiers.symbols + Hotkey.keyName(keyCode) }

    /// Human label for a virtual key code (`kVK_*`). Unknown codes fall back to the
    /// number so a stored binding never renders as an empty box.
    public static func keyName(_ code: UInt32) -> String {
        if let name = keyNames[code] { return name }
        return "#\(code)"
    }

    /// `kVK_ANSI_*` / `kVK_*` codes. Keyboard-layout independent: these identify
    /// physical keys, so a binding recorded on QWERTY still fires on Dvorak at the
    /// same physical position — which is how every other macOS app behaves.
    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space",
        50: "`", 51: "⌫", 53: "⎋",
        // Keypad
        65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Clear", 75: "Keypad /",
        76: "Keypad ↩", 78: "Keypad -", 81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1",
        84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6",
        89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9",
        // Function / navigation
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
        115: "↖", 116: "⇞", 117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟",
        122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
}

/// Everything a global shortcut can drive. Each case is a single discrete command —
/// no parameters — so a binding is always one keystroke to one effect.
public enum HotkeyAction: String, Codable, CaseIterable, Identifiable, Sendable {
    // Charging
    case toggleChargeLimit
    case chargeLimitUp
    case chargeLimitDown
    case togglePauseCharging
    case cycleSaveMode
    case toggleLowPowerMode
    case toggleDischarge
    case toggleHoldCharge

    // Sleep & display
    case toggleCaffeine
    case toggleKeepAwake
    case toggleDimDisplay
    case brightnessUp
    case brightnessDown
    case displayOff
    case sleepNow

    // Power & radios
    case toggleRest
    case cycleIconStyle
    case toggleWiFi
    case toggleBluetooth

    // Windows
    case openSettings
    case openDetails
    case openHistory

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .toggleChargeLimit:   return "Toggle charge limit"
        case .chargeLimitUp:       return "Raise charge limit"
        case .chargeLimitDown:     return "Lower charge limit"
        case .togglePauseCharging: return "Pause / resume charging"
        case .cycleSaveMode:       return "Cycle save mode"
        case .toggleLowPowerMode:  return "Toggle Low Power Mode"
        case .toggleDischarge:     return "Toggle force discharge"
        case .toggleHoldCharge:    return "Toggle don't-charge"
        case .toggleCaffeine:      return "Toggle Caffeine"
        case .toggleKeepAwake:     return "Toggle Always Active"
        case .toggleDimDisplay:    return "Dim / restore display"
        case .brightnessUp:        return "Brightness up"
        case .brightnessDown:      return "Brightness down"
        case .toggleRest:          return "Rest / wake the Mac"
        case .cycleIconStyle:      return "Next menu-bar icon style"
        case .toggleWiFi:          return "Toggle Wi-Fi"
        case .toggleBluetooth:     return "Toggle Bluetooth"
        case .displayOff:          return "Turn display off"
        case .sleepNow:            return "Sleep now"
        case .openSettings:        return "Open Settings"
        case .openDetails:         return "Open Battery Details"
        case .openHistory:         return "Open Battery History"
        }
    }

    public var subtitle: String {
        switch self {
        case .toggleChargeLimit:   return "Turn the limit on or off without changing the percentage."
        case .chargeLimitUp:       return "In 5% steps, up to 100%."
        case .chargeLimitDown:     return "In 5% steps, down to 50%."
        case .togglePauseCharging: return "Stop charging until you resume, or resume now."
        case .cycleSaveMode:       return "Off → Normal → Super Saver → Off. Skips Extreme Performance; that one you pick on purpose."
        case .toggleLowPowerMode:  return "The system Low Power Mode setting."
        case .toggleDischarge:     return "Run off the battery while plugged in. Needs adapter control."
        case .toggleHoldCharge:    return "Stay plugged in without charging. The battery holds where it is."
        case .toggleCaffeine:      return "Keep the Mac awake. Display and system won't sleep."
        case .toggleKeepAwake:     return "Keep working with the lid closed (AC only)."
        case .toggleDimDisplay:    return "Drop to 20% brightness, or back to where it was."
        case .brightnessUp:        return "Raise the built-in display by 10%."
        case .brightnessDown:      return "Lower the built-in display by 10%, the cheapest watts you can save."
        case .toggleRest:          return "Screen off and settings held, without closing the lid. Any key wakes it."
        case .cycleIconStyle:      return "Cycle through the battery glyphs in the menu bar."
        case .toggleWiFi:          return "Turn Wi-Fi on or off."
        case .toggleBluetooth:     return "Turn Bluetooth on or off."
        case .displayOff:          return "Sleep the display now; the Mac stays awake."
        case .sleepNow:            return "Put the Mac to sleep."
        case .openSettings:        return ""
        case .openDetails:         return ""
        case .openHistory:         return ""
        }
    }

    /// HugeIcons catalog key (see `HugeIconsData`).
    public var icon: String {
        switch self {
        case .toggleChargeLimit:   return "battery"
        case .chargeLimitUp:       return "plus"
        case .chargeLimitDown:     return "minus"
        case .togglePauseCharging: return "pause"
        case .cycleSaveMode:       return "gauge"
        case .toggleLowPowerMode:  return "batteryLow"
        case .toggleDischarge:     return "bolt"
        case .toggleHoldCharge:    return "plug"
        case .toggleCaffeine:      return "coffee"
        case .toggleKeepAwake:     return "eye"
        case .toggleDimDisplay:    return "sunLow"
        case .brightnessUp:        return "sun"
        case .brightnessDown:      return "sunLow"
        case .toggleRest:          return "sleep"
        case .cycleIconStyle:      return "battery"
        case .toggleWiFi:          return "wifi"
        case .toggleBluetooth:     return "bluetooth"
        case .displayOff:          return "moon"
        case .sleepNow:            return "sleep"
        case .openSettings:        return "settings"
        case .openDetails:         return "info"
        case .openHistory:         return "chart"
        }
    }

    public enum Category: String, CaseIterable, Identifiable, Sendable {
        case charging, sleep, radios, windows
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .charging: return "Charging"
            case .sleep:    return "Sleep & Display"
            case .radios:   return "Wi-Fi & Bluetooth"
            case .windows:  return "Windows"
            }
        }
    }

    public var category: Category {
        switch self {
        case .toggleChargeLimit, .chargeLimitUp, .chargeLimitDown, .togglePauseCharging,
             .cycleSaveMode, .toggleLowPowerMode, .toggleDischarge, .toggleHoldCharge:
            return .charging
        case .toggleCaffeine, .toggleKeepAwake, .toggleDimDisplay, .displayOff, .sleepNow,
             .brightnessUp, .brightnessDown, .toggleRest:
            return .sleep
        case .toggleWiFi, .toggleBluetooth:
            return .radios
        case .cycleIconStyle:
            return .windows
        case .openSettings, .openDetails, .openHistory:
            return .windows
        }
    }

    public static func inCategory(_ category: Category) -> [HotkeyAction] {
        allCases.filter { $0.category == category }
    }

    /// Only the pro features are gated; everything else works unlicensed.
    public var requiresPro: Bool {
        self == .openDetails || self == .openHistory
    }

    /// Shipped bindings, all on ⌃⌥⌘ — a combination macOS itself leaves alone and
    /// few apps claim. Actions that are disruptive to hit by accident (sleep, force
    /// discharge) ship unbound; the destructive ones stay opt-in.
    public var defaultHotkey: Hotkey? {
        let base: HotkeyModifiers = [.control, .option, .command]
        switch self {
        case .toggleChargeLimit:   return Hotkey(keyCode: 11, modifiers: base)  // B
        case .chargeLimitUp:       return Hotkey(keyCode: 126, modifiers: base) // ↑
        case .chargeLimitDown:     return Hotkey(keyCode: 125, modifiers: base) // ↓
        case .togglePauseCharging: return Hotkey(keyCode: 35, modifiers: base)  // P
        case .cycleSaveMode:       return Hotkey(keyCode: 46, modifiers: base)  // M
        case .toggleLowPowerMode:  return Hotkey(keyCode: 37, modifiers: base)  // L
        case .toggleCaffeine:      return Hotkey(keyCode: 8, modifiers: base)   // C
        case .toggleKeepAwake:     return Hotkey(keyCode: 40, modifiers: base)  // K
        case .toggleDimDisplay:    return Hotkey(keyCode: 2, modifiers: base)   // D
        case .openSettings:        return Hotkey(keyCode: 1, modifiers: base)   // S
        case .toggleHoldCharge:    return Hotkey(keyCode: 4, modifiers: base)   // H
        case .brightnessUp:        return Hotkey(keyCode: 30, modifiers: base)  // ]
        case .brightnessDown:      return Hotkey(keyCode: 33, modifiers: base)  // [
        case .toggleRest:          return Hotkey(keyCode: 15, modifiers: base)  // R
        case .cycleIconStyle:      return Hotkey(keyCode: 34, modifiers: base)  // I
        // Unbound on purpose: cutting Wi-Fi or Bluetooth by a mistyped chord is the kind
        // of surprise a shortcut should never spring on you.
        case .toggleWiFi, .toggleBluetooth:
            return nil
        case .displayOff, .sleepNow, .toggleDischarge, .openDetails, .openHistory:
            return nil
        }
    }
}

/// The action → shortcut map. A combination drives at most one action, so assigning
/// one that's already taken moves it: the previous owner is left unbound rather than
/// both firing (or neither registering, which is what Carbon does with a duplicate).
public struct HotkeyBindings: Codable, Equatable, Sendable {
    private var map: [HotkeyAction: Hotkey]

    public init(_ map: [HotkeyAction: Hotkey] = [:]) { self.map = map }

    public static var `default`: HotkeyBindings {
        var m: [HotkeyAction: Hotkey] = [:]
        for action in HotkeyAction.allCases {
            if let key = action.defaultHotkey { m[action] = key }
        }
        return HotkeyBindings(m)
    }

    public func hotkey(for action: HotkeyAction) -> Hotkey? { map[action] }

    /// The action a pressed combination should run, if any.
    public func action(for hotkey: Hotkey) -> HotkeyAction? {
        map.first { $0.value == hotkey }?.key
    }

    /// Assign, taking the combination off whatever else held it. Invalid shortcuts
    /// (no ⌃/⌥/⌘) are ignored so an unusable binding can't be persisted.
    @discardableResult
    public mutating func set(_ hotkey: Hotkey, for action: HotkeyAction) -> HotkeyAction? {
        guard hotkey.isValid else { return nil }
        let displaced = map.first { $0.key != action && $0.value == hotkey }?.key
        if let displaced { map[displaced] = nil }
        map[action] = hotkey
        return displaced
    }

    public mutating func clear(_ action: HotkeyAction) { map[action] = nil }

    /// Every binding that should be registered, as (action, hotkey) pairs.
    public var active: [(action: HotkeyAction, hotkey: Hotkey)] {
        // Sorted by action so registration order — and therefore the Carbon hotkey
        // ids — is stable between launches, which keeps debugging sane.
        HotkeyAction.allCases.compactMap { a in map[a].map { (a, $0) } }
    }

    public var isDefault: Bool { self == .default }

    // Encoded with raw-string keys so the JSON stays readable and an unknown action
    // from a newer build is skipped instead of failing the whole decode.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.container(keyedBy: CodingKeys.self)
            .decodeIfPresent([String: Hotkey].self, forKey: .map) ?? [:]
        var m: [HotkeyAction: Hotkey] = [:]
        for (key, value) in raw {
            if let action = HotkeyAction(rawValue: key), value.isValid { m[action] = value }
        }
        map = m
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value) }),
                     forKey: .map)
    }

    private enum CodingKeys: String, CodingKey { case map }
}
