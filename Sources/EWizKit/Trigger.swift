import Foundation

/// A point-in-time reading of everything the automation rules can test. Probing
/// lives in the GUI (it needs AppKit/CoreWLAN/CoreAudio); this is the plain data
/// it produces, so rule evaluation stays pure and testable.
public struct TriggerSnapshot: Sendable, Equatable {
    /// Displays attached that aren't the built-in panel.
    public var externalDisplays: Int = 0
    /// Product names of currently-attached USB devices.
    public var usbDevices: [String] = []
    /// Names of paired Bluetooth devices that are connected right now.
    public var bluetoothDevices: [String] = []
    /// Lowercased names *and* bundle identifiers of running apps.
    public var runningApps: [String] = []
    /// Lowercased name + bundle identifier of the frontmost app.
    public var frontmostApp: [String] = []
    public var isCharging = false
    public var isPluggedIn = false
    public var batteryPercent = 0
    /// Non-link-local IPv4/IPv6 addresses on all up, non-loopback interfaces.
    public var ipAddresses: [String] = []
    /// Joined Wi-Fi network, if any (needs Location access to read).
    public var ssid: String?
    /// Tunnel interfaces carrying a routable address (utun/ppp/ipsec/tun/tap).
    public var vpnInterfaces: [String] = []
    /// Friendly name of the current default audio output.
    public var audioOutput: String = ""
    /// True when output is going somewhere other than the built-in speakers
    /// (headphones, USB/Bluetooth device, HDMI, AirPlay…).
    public var audioOutputIsExternal = false
    /// Names of mounted volumes that aren't on the internal disk.
    public var externalVolumes: [String] = []
    /// System-wide CPU utilization, 0–100.
    public var cpuPercent: Double = 0

    public init() {}
}

/// A thing a rule can watch. One case per "while …" condition.
public enum TriggerKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case externalDisplay
    case usbDevice
    case bluetoothDevice
    case appRunning
    case appFrontmost
    case charging
    case batteryAbove
    case acPower
    case ipAddress
    case wifiNetwork
    case vpn
    case audioOutput
    case volumeMounted
    case cpuAbove

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .externalDisplay:  return "External display connected"
        case .usbDevice:        return "USB device connected"
        case .bluetoothDevice:  return "Bluetooth device connected"
        case .appRunning:       return "App is running"
        case .appFrontmost:     return "App is running and frontmost"
        case .charging:         return "Battery is charging"
        case .batteryAbove:     return "Battery is above"
        case .acPower:          return "Power adapter connected"
        case .ipAddress:        return "Has IP address"
        case .wifiNetwork:      return "On Wi-Fi network"
        case .vpn:              return "Connected to a VPN"
        case .audioOutput:      return "Headphones / audio output in use"
        case .volumeMounted:    return "Drive or volume mounted"
        case .cpuAbove:         return "CPU usage above"
        }
    }

    /// HugeIcons catalog key (see `HugeIconsData`).
    public var icon: String {
        switch self {
        case .externalDisplay:  return "display"
        case .usbDevice:        return "usb"
        case .bluetoothDevice:  return "bluetooth"
        case .appRunning:       return "app"
        case .appFrontmost:     return "appFront"
        case .charging:         return "charging"
        case .batteryAbove:     return "battery"
        case .acPower:          return "plug"
        case .ipAddress:        return "globe"
        case .wifiNetwork:      return "wifi"
        case .vpn:              return "shield"
        case .audioOutput:      return "headphones"
        case .volumeMounted:    return "drive"
        case .cpuAbove:         return "cpu"
        }
    }

    /// Takes a free-text parameter (device/app/network name, address…).
    public var usesText: Bool {
        switch self {
        case .usbDevice, .bluetoothDevice, .appRunning, .appFrontmost,
             .ipAddress, .wifiNetwork, .vpn, .audioOutput, .volumeMounted:
            return true
        default:
            return false
        }
    }

    /// Meaningless without a value — an empty parameter never matches.
    public var requiresText: Bool {
        switch self {
        case .appRunning, .appFrontmost, .ipAddress: return true
        default: return false
        }
    }

    /// Takes a numeric parameter.
    public var usesThreshold: Bool {
        switch self {
        case .externalDisplay, .batteryAbove, .cpuAbove: return true
        default: return false
        }
    }

    public var thresholdRange: ClosedRange<Int> {
        switch self {
        case .externalDisplay: return 1...4
        default: return 1...100
        }
    }

    public var thresholdUnit: String { self == .externalDisplay ? "" : "%" }

    public var defaultThreshold: Int {
        switch self {
        case .externalDisplay: return 1
        case .batteryAbove:    return 80
        case .cpuAbove:        return 60
        default:               return 0
        }
    }

    /// Hint shown in the parameter field.
    public var textPlaceholder: String {
        switch self {
        case .usbDevice:       return "Any USB device"
        case .bluetoothDevice: return "Any connected device"
        case .appRunning,
             .appFrontmost:    return "e.g. Final Cut Pro"
        case .ipAddress:       return "e.g. 192.168.1.42"
        case .wifiNetwork:     return "Any Wi-Fi network"
        case .vpn:             return "Any VPN"
        case .audioOutput:     return "Any non-built-in output"
        case .volumeMounted:   return "Any external volume"
        default:               return ""
        }
    }

    /// Values that move in small steps need a second confirming poll before the
    /// rule flips, so a brief CPU spike or a % wobble can't cause flapping.
    public var needsConfirmation: Bool {
        self == .cpuAbove || self == .batteryAbove
    }
}

/// One "while …" test inside a rule.
public struct TriggerCondition: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var kind: TriggerKind
    /// Name / SSID / address to match, case-insensitive substring. Empty means
    /// "any" for the kinds that allow it (see `TriggerKind.requiresText`).
    public var text: String
    /// Numeric parameter for threshold kinds.
    public var threshold: Int
    /// Invert the test ("while NOT …").
    public var negated: Bool

    public init(id: UUID = UUID(), kind: TriggerKind = .externalDisplay,
                text: String = "", threshold: Int? = nil, negated: Bool = false) {
        self.id = id
        self.kind = kind
        self.text = text
        self.threshold = threshold ?? kind.defaultThreshold
        self.negated = negated
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(TriggerKind.self, forKey: .kind) ?? .externalDisplay
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        threshold = try c.decodeIfPresent(Int.self, forKey: .threshold) ?? kind.defaultThreshold
        negated = try c.decodeIfPresent(Bool.self, forKey: .negated) ?? false
    }

    /// The parameter with surrounding whitespace removed.
    public var value: String { text.trimmingCharacters(in: .whitespaces) }

    /// Evaluate against a system snapshot.
    public func isSatisfied(by s: TriggerSnapshot) -> Bool {
        let raw = rawMatch(s)
        return negated ? !raw : raw
    }

    private func rawMatch(_ s: TriggerSnapshot) -> Bool {
        let needle = value
        if kind.requiresText && needle.isEmpty { return false }

        switch kind {
        case .externalDisplay:
            return s.externalDisplays >= max(1, threshold)
        case .usbDevice:
            return needle.isEmpty ? !s.usbDevices.isEmpty : Self.contains(s.usbDevices, needle)
        case .bluetoothDevice:
            return needle.isEmpty ? !s.bluetoothDevices.isEmpty
                                  : Self.contains(s.bluetoothDevices, needle)
        case .appRunning:
            return Self.contains(s.runningApps, needle)
        case .appFrontmost:
            return Self.contains(s.frontmostApp, needle)
        case .charging:
            return s.isCharging
        case .batteryAbove:
            return s.batteryPercent > threshold
        case .acPower:
            return s.isPluggedIn
        case .ipAddress:
            // Exact address, or a prefix like "192.168.1." to match a subnet.
            return s.ipAddresses.contains { $0.caseInsensitiveCompare(needle) == .orderedSame }
                || (needle.hasSuffix(".") && s.ipAddresses.contains { $0.hasPrefix(needle) })
        case .wifiNetwork:
            guard let ssid = s.ssid else { return false }
            return needle.isEmpty || ssid.localizedCaseInsensitiveContains(needle)
        case .vpn:
            return needle.isEmpty ? !s.vpnInterfaces.isEmpty
                                  : Self.contains(s.vpnInterfaces, needle)
        case .audioOutput:
            return needle.isEmpty ? s.audioOutputIsExternal
                                  : s.audioOutput.localizedCaseInsensitiveContains(needle)
        case .volumeMounted:
            return needle.isEmpty ? !s.externalVolumes.isEmpty
                                  : Self.contains(s.externalVolumes, needle)
        case .cpuAbove:
            return s.cpuPercent > Double(threshold)
        }
    }

    private static func contains(_ haystack: [String], _ needle: String) -> Bool {
        haystack.contains { $0.localizedCaseInsensitiveContains(needle) }
    }

    /// One-line description, e.g. "While App is running and frontmost: Xcode".
    public var summary: String {
        var line = negated ? "Not: \(kind.title)" : kind.title
        if kind.usesThreshold { line += " \(threshold)\(kind.thresholdUnit)" }
        if kind.usesText {
            let v = value
            line += v.isEmpty ? "" : " · \(v)"
        }
        return line
    }
}

/// What a rule does while its conditions hold.
public enum TriggerAction: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Switch to a save mode.
    case mode
    /// Set (or clear) the charge limit.
    case chargeLimit
    /// Stop charging entirely until the rule ends.
    case holdCharging
    /// Keep the Mac awake ("Always Active").
    case keepAwake
    /// Turn Low Power Mode on.
    case lowPowerMode
    /// Duty-cycle charging down to a chosen power.
    case chargePower

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .mode:         return "Switch save mode"
        case .chargeLimit:  return "Set charge limit"
        case .holdCharging: return "Hold charging"
        case .keepAwake:    return "Keep the Mac awake"
        case .lowPowerMode: return "Low Power Mode on"
        case .chargePower:  return "Set charge power"
        }
    }

    /// HugeIcons catalog key (see `HugeIconsData`).
    public var icon: String {
        switch self {
        case .mode:         return "gauge"
        case .chargeLimit:  return "battery"
        case .holdCharging: return "pause"
        case .keepAwake:    return "eye"
        case .lowPowerMode: return "batteryLow"
        case .chargePower:  return "bolt"
        }
    }

    public var usesMode: Bool { self == .mode }
    public var usesPercent: Bool { self == .chargeLimit || self == .chargePower }

    /// Needs the root helper to carry it out.
    public var needsDaemon: Bool { true }
}

/// "While ⟨conditions⟩ hold, do ⟨action⟩" — and undo it when they stop holding.
public struct TriggerRule: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var enabled: Bool
    public var label: String
    /// true = every condition must hold; false = any one of them.
    public var matchAll: Bool
    public var conditions: [TriggerCondition]
    public var action: TriggerAction
    /// Target for `.mode`.
    public var mode: SaveMode
    /// Target for `.chargeLimit` (0 = turn the limit off) and `.chargePower`.
    public var percent: Int

    public init(id: UUID = UUID(), enabled: Bool = true, label: String = "",
                matchAll: Bool = true, conditions: [TriggerCondition] = [],
                action: TriggerAction = .chargeLimit, mode: SaveMode = .normal,
                percent: Int = 80) {
        self.id = id
        self.enabled = enabled
        self.label = label
        self.matchAll = matchAll
        self.conditions = conditions
        self.action = action
        self.mode = mode
        self.percent = max(0, min(100, percent))
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        matchAll = try c.decodeIfPresent(Bool.self, forKey: .matchAll) ?? true
        conditions = try c.decodeIfPresent([TriggerCondition].self, forKey: .conditions) ?? []
        action = try c.decodeIfPresent(TriggerAction.self, forKey: .action) ?? .chargeLimit
        mode = try c.decodeIfPresent(SaveMode.self, forKey: .mode) ?? .normal
        percent = max(0, min(100, try c.decodeIfPresent(Int.self, forKey: .percent) ?? 80))
    }

    /// A rule with no conditions never fires (rather than firing always).
    public func isSatisfied(by s: TriggerSnapshot) -> Bool {
        guard enabled, !conditions.isEmpty else { return false }
        return matchAll ? conditions.allSatisfy { $0.isSatisfied(by: s) }
                        : conditions.contains { $0.isSatisfied(by: s) }
    }

    /// True when any condition wants a confirming second poll before flipping.
    public var needsConfirmation: Bool {
        conditions.contains { $0.kind.needsConfirmation }
    }

    public var displayName: String {
        label.trimmingCharacters(in: .whitespaces).isEmpty ? actionSummary : label
    }

    public var actionSummary: String {
        switch action {
        case .mode:         return "Switch to \(mode.title)"
        case .chargeLimit:  return percent == 0 ? "Turn the charge limit off"
                                                : "Charge limit \(percent)%"
        case .holdCharging: return "Hold charging"
        case .keepAwake:    return "Keep the Mac awake"
        case .lowPowerMode: return "Low Power Mode on"
        case .chargePower:  return percent == 0 ? "Charge power off"
                                                : "Charge power \(percent)%"
        }
    }

    /// "While external display connected · Dell U2723 and app is running · Xcode".
    public var conditionSummary: String {
        guard !conditions.isEmpty else { return "No conditions yet" }
        return conditions.map(\.summary).joined(separator: matchAll ? " and " : " or ")
    }
}
