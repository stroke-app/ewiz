import Foundation

/// macOS High Power Mode, via `pmset highpowermode`. Setting needs root; reading doesn't.
///
/// This is Apple's own sanctioned "run harder" switch — it raises the thermal and fan
/// ceiling so a sustained workload holds its clocks instead of settling to the quiet
/// steady state. There is no public API for it, so, like Low Power Mode next door, we
/// shell out to `pmset`.
///
/// The important part is that **most Macs don't have it.** Apple ships it only on the
/// Max-chip MacBook Pros and the desktops; on anything else `pmset` doesn't recognise the
/// key at all and answers with its usage text. A performance mode that silently no-ops on
/// the majority of Macs and says nothing is worse than one that admits it, so support is
/// probed and reported up to the UI rather than assumed.
enum HighPowerMode {

    /// Whether this Mac exposes the setting.
    ///
    /// Read-only detection, on purpose. Probing by attempting a write would mean changing
    /// a system-wide power setting to find out whether we're allowed to — and on the Macs
    /// where it *does* work, that probe is not a no-op. `pmset -g custom` lists the key
    /// only on hardware that has it, which answers the question for free.
    static func isSupported() -> Bool { state().supported }

    /// Support and current state together, from one `pmset -g custom` read. Pass the
    /// output in when the caller already has it — the daemon polls this alongside the
    /// other pmset-derived state and there's no reason to fork twice for one string.
    ///
    /// Enabled is false on a Mac without the feature, which is also the truth.
    static func state(from custom: String? = nil) -> (supported: Bool, enabled: Bool) {
        guard let out = custom ?? PowerSettings.readCustom() else { return (false, false) }
        var supported = false, enabled = false
        for line in out.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count >= 2, parts[parts.count - 2] == "highpowermode" else { continue }
            supported = true
            if parts[parts.count - 1] == "1" { enabled = true }
        }
        return (supported, enabled)
    }

    /// Turn it on or off for all power sources. Requires root.
    ///
    /// Returns false when the Mac doesn't have the feature. Turning it *off* on such a
    /// Mac still reports success: the requested end state — not in High Power Mode — is
    /// already true, and failing there would make every mode switch on an ordinary
    /// MacBook look like an error.
    @discardableResult
    static func set(_ on: Bool) -> Bool {
        guard isSupported() else { return !on }
        return Shell.run("/usr/bin/pmset", ["-a", "highpowermode", on ? "1" : "0"]) != nil
    }
}
