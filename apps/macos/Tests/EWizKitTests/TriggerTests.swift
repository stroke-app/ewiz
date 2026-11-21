import Testing
import Foundation
@testable import EWizKit

/// A snapshot with a bit of everything, so tests only override what they care about.
private func snapshot(
    externalDisplays: Int = 0,
    usbDevices: [String] = [],
    bluetoothDevices: [String] = [],
    runningApps: [String] = [],
    frontmostApp: [String] = [],
    isCharging: Bool = false,
    isPluggedIn: Bool = false,
    batteryPercent: Int = 50,
    ipAddresses: [String] = [],
    ssid: String? = nil,
    vpnInterfaces: [String] = [],
    audioOutput: String = "",
    audioOutputIsExternal: Bool = false,
    externalVolumes: [String] = [],
    cpuPercent: Double = 0
) -> TriggerSnapshot {
    var s = TriggerSnapshot()
    s.externalDisplays = externalDisplays
    s.usbDevices = usbDevices
    s.bluetoothDevices = bluetoothDevices
    s.runningApps = runningApps
    s.frontmostApp = frontmostApp
    s.isCharging = isCharging
    s.isPluggedIn = isPluggedIn
    s.batteryPercent = batteryPercent
    s.ipAddresses = ipAddresses
    s.ssid = ssid
    s.vpnInterfaces = vpnInterfaces
    s.audioOutput = audioOutput
    s.audioOutputIsExternal = audioOutputIsExternal
    s.externalVolumes = externalVolumes
    s.cpuPercent = cpuPercent
    return s
}

// MARK: - Conditions

@Suite("Trigger conditions")
struct TriggerConditionTests {

    @Test("External display counts against the threshold")
    func externalDisplay() {
        let one = TriggerCondition(kind: .externalDisplay, threshold: 1)
        #expect(!one.isSatisfied(by: snapshot(externalDisplays: 0)))
        #expect(one.isSatisfied(by: snapshot(externalDisplays: 1)))
        #expect(one.isSatisfied(by: snapshot(externalDisplays: 3)))

        let two = TriggerCondition(kind: .externalDisplay, threshold: 2)
        #expect(!two.isSatisfied(by: snapshot(externalDisplays: 1)))
        #expect(two.isSatisfied(by: snapshot(externalDisplays: 2)))
    }

    @Test("An empty name means 'any device' where that makes sense")
    func anyDevice() {
        let anyUSB = TriggerCondition(kind: .usbDevice)
        #expect(!anyUSB.isSatisfied(by: snapshot()))
        #expect(anyUSB.isSatisfied(by: snapshot(usbDevices: ["CalDigit TS4"])))

        let anyBT = TriggerCondition(kind: .bluetoothDevice)
        #expect(!anyBT.isSatisfied(by: snapshot()))
        #expect(anyBT.isSatisfied(by: snapshot(bluetoothDevices: ["Magic Trackpad"])))

        let anyVolume = TriggerCondition(kind: .volumeMounted)
        #expect(!anyVolume.isSatisfied(by: snapshot()))
        #expect(anyVolume.isSatisfied(by: snapshot(externalVolumes: ["Backup"])))
    }

    @Test("An empty name never matches where a name is required")
    func requiredText() {
        for kind in TriggerKind.allCases where kind.requiresText {
            let condition = TriggerCondition(kind: kind)
            #expect(!condition.isSatisfied(by: snapshot(
                runningApps: ["xcode"], frontmostApp: ["xcode"], ipAddresses: ["10.0.0.2"])),
                    "\(kind) should not match on an empty parameter")
        }
    }

    @Test("Device and app names match case-insensitively on a substring")
    func nameMatching() {
        let usb = TriggerCondition(kind: .usbDevice, text: "caldigit")
        #expect(usb.isSatisfied(by: snapshot(usbDevices: ["CalDigit TS4 Dock"])))
        #expect(!usb.isSatisfied(by: snapshot(usbDevices: ["Keychron K3"])))

        // Apps are matched by display name or bundle id.
        let app = TriggerCondition(kind: .appRunning, text: "com.apple.dt.Xcode")
        #expect(app.isSatisfied(by: snapshot(runningApps: ["xcode", "com.apple.dt.xcode"])))

        let front = TriggerCondition(kind: .appFrontmost, text: "Xcode")
        #expect(front.isSatisfied(by: snapshot(frontmostApp: ["xcode", "com.apple.dt.xcode"])))
        // Running but not frontmost.
        #expect(!front.isSatisfied(by: snapshot(runningApps: ["xcode"], frontmostApp: ["mail"])))
    }

    @Test("Battery and CPU thresholds are strict 'above'")
    func thresholds() {
        let battery = TriggerCondition(kind: .batteryAbove, threshold: 80)
        #expect(!battery.isSatisfied(by: snapshot(batteryPercent: 80)))
        #expect(battery.isSatisfied(by: snapshot(batteryPercent: 81)))

        let cpu = TriggerCondition(kind: .cpuAbove, threshold: 60)
        #expect(!cpu.isSatisfied(by: snapshot(cpuPercent: 60)))
        #expect(cpu.isSatisfied(by: snapshot(cpuPercent: 60.5)))
    }

    @Test("Power conditions read the battery state")
    func power() {
        let charging = TriggerCondition(kind: .charging)
        let ac = TriggerCondition(kind: .acPower)
        let plugged = snapshot(isCharging: false, isPluggedIn: true)
        #expect(!charging.isSatisfied(by: plugged))
        #expect(ac.isSatisfied(by: plugged))
        #expect(charging.isSatisfied(by: snapshot(isCharging: true, isPluggedIn: true)))
    }

    @Test("An IP matches exactly, or by subnet prefix ending in a dot")
    func ipMatching() {
        let exact = TriggerCondition(kind: .ipAddress, text: "192.168.1.42")
        #expect(exact.isSatisfied(by: snapshot(ipAddresses: ["192.168.1.42"])))
        #expect(!exact.isSatisfied(by: snapshot(ipAddresses: ["192.168.1.4"])))
        // A trailing dot means "anything on this subnet" — and must not match a
        // longer address that merely starts the same way.
        let subnet = TriggerCondition(kind: .ipAddress, text: "192.168.1.")
        #expect(subnet.isSatisfied(by: snapshot(ipAddresses: ["192.168.1.99"])))
        #expect(!subnet.isSatisfied(by: snapshot(ipAddresses: ["192.168.11.5"])))
    }

    @Test("Wi-Fi matches any network when no name is given")
    func wifi() {
        let any = TriggerCondition(kind: .wifiNetwork)
        #expect(!any.isSatisfied(by: snapshot(ssid: nil)))
        #expect(any.isSatisfied(by: snapshot(ssid: "Home")))

        let named = TriggerCondition(kind: .wifiNetwork, text: "office")
        #expect(named.isSatisfied(by: snapshot(ssid: "Office 5G")))
        #expect(!named.isSatisfied(by: snapshot(ssid: "Home")))
    }

    @Test("Audio falls back to 'anything but the built-in speakers'")
    func audio() {
        let any = TriggerCondition(kind: .audioOutput)
        #expect(!any.isSatisfied(by: snapshot(audioOutput: "MacBook Pro Speakers")))
        #expect(any.isSatisfied(by: snapshot(audioOutput: "AirPods Pro",
                                             audioOutputIsExternal: true)))

        let named = TriggerCondition(kind: .audioOutput, text: "airpods")
        #expect(named.isSatisfied(by: snapshot(audioOutput: "AirPods Pro",
                                               audioOutputIsExternal: true)))
        #expect(!named.isSatisfied(by: snapshot(audioOutput: "Studio Display Speakers",
                                                audioOutputIsExternal: true)))
    }

    @Test("VPN matches any live tunnel, or one by interface name")
    func vpn() {
        let any = TriggerCondition(kind: .vpn)
        #expect(!any.isSatisfied(by: snapshot()))
        #expect(any.isSatisfied(by: snapshot(vpnInterfaces: ["utun4"])))

        let named = TriggerCondition(kind: .vpn, text: "ipsec")
        #expect(!named.isSatisfied(by: snapshot(vpnInterfaces: ["utun4"])))
        #expect(named.isSatisfied(by: snapshot(vpnInterfaces: ["ipsec0"])))
    }

    @Test("Inverting flips the result")
    func negation() {
        var condition = TriggerCondition(kind: .acPower, negated: true)
        #expect(condition.isSatisfied(by: snapshot(isPluggedIn: false)))
        #expect(!condition.isSatisfied(by: snapshot(isPluggedIn: true)))

        // Inverting a "requires a name" condition with no name still inverts the
        // (always false) result, so it's always true — matching what the UI shows.
        condition = TriggerCondition(kind: .appRunning, negated: true)
        #expect(condition.isSatisfied(by: snapshot()))
    }

    @Test("Each threshold default sits inside its allowed range")
    func defaults() {
        for kind in TriggerKind.allCases where kind.usesThreshold {
            #expect(kind.thresholdRange.contains(kind.defaultThreshold),
                    "\(kind) default \(kind.defaultThreshold) is outside \(kind.thresholdRange)")
        }
    }
}

// MARK: - Rules

@Suite("Trigger rules")
struct TriggerRuleTests {

    private var docked: TriggerCondition { TriggerCondition(kind: .externalDisplay) }
    private var onAC: TriggerCondition { TriggerCondition(kind: .acPower) }

    @Test("Match-all needs every condition; match-any needs one")
    func matching() {
        let all = TriggerRule(matchAll: true, conditions: [docked, onAC])
        #expect(all.isSatisfied(by: snapshot(externalDisplays: 1, isPluggedIn: true)))
        #expect(!all.isSatisfied(by: snapshot(externalDisplays: 1, isPluggedIn: false)))

        let any = TriggerRule(matchAll: false, conditions: [docked, onAC])
        #expect(any.isSatisfied(by: snapshot(externalDisplays: 1, isPluggedIn: false)))
        #expect(!any.isSatisfied(by: snapshot(externalDisplays: 0, isPluggedIn: false)))
    }

    @Test("A rule with no conditions never fires")
    func emptyRuleNeverFires() {
        let rule = TriggerRule(conditions: [])
        #expect(!rule.isSatisfied(by: snapshot(externalDisplays: 2, isPluggedIn: true)))
    }

    @Test("A disabled rule never fires")
    func disabledRuleNeverFires() {
        let rule = TriggerRule(enabled: false, conditions: [docked])
        #expect(!rule.isSatisfied(by: snapshot(externalDisplays: 1)))
    }

    @Test("Only noisy numeric conditions ask for a confirming poll")
    func confirmation() {
        #expect(TriggerRule(conditions: [TriggerCondition(kind: .cpuAbove)]).needsConfirmation)
        #expect(TriggerRule(conditions: [TriggerCondition(kind: .batteryAbove)]).needsConfirmation)
        #expect(!TriggerRule(conditions: [docked, onAC]).needsConfirmation)
        // One noisy condition in the set is enough.
        #expect(TriggerRule(conditions: [docked, TriggerCondition(kind: .cpuAbove)])
            .needsConfirmation)
    }

    @Test("Percent is clamped to 0…100")
    func percentClamped() {
        #expect(TriggerRule(percent: 140).percent == 100)
        #expect(TriggerRule(percent: -5).percent == 0)
    }

    @Test("An unnamed rule falls back to describing its action")
    func displayName() {
        let rule = TriggerRule(label: "  ", action: .chargeLimit, percent: 70)
        #expect(rule.displayName == "Charge limit 70%")
        #expect(TriggerRule(label: "At my desk").displayName == "At my desk")
    }

    @Test("Rules survive a JSON round trip")
    func codableRoundTrip() throws {
        let rule = TriggerRule(
            label: "Docked", matchAll: false,
            conditions: [docked, TriggerCondition(kind: .wifiNetwork, text: "Office",
                                                  negated: true)],
            action: .mode, mode: .superSaver, percent: 90)
        let data = try JSONEncoder().encode([rule])
        let decoded = try JSONDecoder().decode([TriggerRule].self, from: data)
        #expect(decoded == [rule])
    }

    @Test("Rules written by an older version still load")
    func decodesPartialJSON() throws {
        // Only the fields an early version wrote; everything else takes a default.
        let json = """
        [{"id":"3F2504E0-4F89-11D3-9A0C-0305E82C3301","label":"Old",
          "conditions":[{"kind":"acPower"}],"action":"holdCharging"}]
        """
        let rules = try JSONDecoder().decode([TriggerRule].self, from: Data(json.utf8))
        #expect(rules.count == 1)
        #expect(rules[0].enabled)                       // defaults to on
        #expect(rules[0].matchAll)                      // defaults to "all"
        #expect(rules[0].conditions[0].kind == .acPower)
        #expect(rules[0].conditions[0].threshold == TriggerKind.acPower.defaultThreshold)
        #expect(rules[0].isSatisfied(by: snapshot(isPluggedIn: true)))
    }
}
