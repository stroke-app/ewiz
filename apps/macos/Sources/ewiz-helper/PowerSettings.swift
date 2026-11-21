import Foundation
import EWizKit

/// Reads/writes system sleep/idle settings via `pmset` (writing needs root). These
/// persist system-wide, so set once — no continuous enforcement.
enum PowerSettings {

    /// One `pmset -g custom` read, so the several things parsed out of it cost one fork
    /// between them rather than one each.
    static func readCustom() -> String? {
        Shell.run("/usr/bin/pmset", ["-g", "custom"])
    }

    /// Every key `pmset -g custom` prints, split by power source.
    ///
    /// Raw strings rather than parsed values: the keys here are a mix of booleans,
    /// minutes and mode numbers, and the callers know which is which. A missing key means
    /// this Mac doesn't expose the setting at all — `pmset -g cap` and this agree, and an
    /// absent key is very different from one reading 0.
    static func readValues(from custom: String? = nil) -> (battery: [String: String], ac: [String: String]) {
        guard let out = custom ?? readCustom() else { return ([:], [:]) }
        var battery: [String: String] = [:]
        var ac: [String: String] = [:]
        var section = 0 // 0 = none, 1 = battery, 2 = AC

        for raw in out.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            if line.hasPrefix("Battery Power:") { section = 1; continue }
            if line.hasPrefix("AC Power:") { section = 2; continue }
            guard section != 0 else { continue }

            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2 else { continue }
            let key = String(parts[parts.count - 2])
            let value = String(parts[parts.count - 1])
            if section == 1 { battery[key] = value } else { ac[key] = value }
        }
        return (battery, ac)
    }

    /// Current values for the exposed toggles; each is read from the section matching
    /// its scope (battery/AC).
    static func readToggles(from custom: String? = nil) -> [String: Bool] {
        let values = readValues(from: custom)
        var result: [String: Bool] = [:]
        for toggle in PowerToggle.allCases {
            let source = toggle.scope == .ac ? values.ac : values.battery
            if let value = source[toggle.rawValue] {
                result[toggle.rawValue] = (value == "1")
            }
        }
        return result
    }

    /// Set a toggle on its relevant power source(s). Requires root.
    @discardableResult
    static func set(_ toggle: PowerToggle, _ on: Bool) -> Bool {
        Shell.run("/usr/bin/pmset", [toggle.scope.rawValue, toggle.rawValue, on ? "1" : "0"]) != nil
    }

    /// Current `hibernatemode`, parsed from `pmset -g`. Reading needs no root.
    static func readHibernateMode() -> Int? {
        guard let out = Shell.run("/usr/bin/pmset", ["-g"]) else { return nil }
        for raw in out.split(separator: "\n") {
            let parts = raw.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2, parts[parts.count - 2] == "hibernatemode" else { continue }
            return Int(parts[parts.count - 1])
        }
        return nil
    }

    /// Write one `pmset` key on every power source. Requires root.
    ///
    /// The return value says the call succeeded, which is not the same as the setting
    /// having changed — `pmset` exits 0 for keys a Mac silently ignores. Anything that
    /// cares reads the value back; see `SealedSleepController.apply`.
    @discardableResult
    static func setKey(_ key: String, _ value: String, scope: PowerToggle.Scope = .all) -> Bool {
        Shell.run("/usr/bin/pmset", [scope.rawValue, key, value]) != nil
    }

    /// Disable *all* sleep — idle and clamshell — the only way to keep running with the
    /// lid shut (no IOPMAssertion prevents clamshell sleep). Requires root; does NOT
    /// persist across reboots, so the daemon re-applies it on startup.
    @discardableResult
    static func setDisableSleep(_ on: Bool) -> Bool {
        Shell.run("/usr/bin/pmset", ["-a", "disablesleep", on ? "1" : "0"]) != nil
    }

    /// Force the display to sleep now (the keyboard backlight follows). Display sleep is
    /// independent of `disablesleep`, so it works while keep-awake holds the Mac awake with the lid shut.
    @discardableResult
    static func displaySleepNow() -> Bool {
        Shell.run("/usr/bin/pmset", ["displaysleepnow"]) != nil
    }

    /// Put the whole system to sleep now. The caller must first clear `disablesleep`
    /// (otherwise sleep is blocked); used to sleep the Mac once a keep-awake task finishes.
    @discardableResult
    static func sleepNow() -> Bool {
        Shell.run("/usr/bin/pmset", ["sleepnow"]) != nil
    }
}
