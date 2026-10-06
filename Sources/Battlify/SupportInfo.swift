import AppKit
import BattlifyKit

/// What support needs to know, gathered in one place so the email, the bug report and the
/// clipboard all say the same thing.
///
/// "It stopped holding at 80%" is unanswerable on its own: the answer depends on the macOS
/// build, whether the Mac has a charge key, which helper build is running and what it last
/// logged. Asking for each of those by email is a week of back-and-forth, so the app writes
/// them out itself.
@MainActor
enum SupportInfo {
    static let email = "nischaldahal01395@gmail.com"
    private static let newIssue = "https://github.com/broisnischal/battlify/issues/new"
    private static let logPath = "/var/log/battlify-helper.log"

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    /// App, system, helper, battery and license kind. No key, no name and no device code,
    /// so it can go into a public bug report as it stands.
    static func summary(chargeLimit: ChargeLimitStore, license: LicenseManager,
                        battery: BatterySnapshot) -> String {
        var lines = [
            "Battlify \(version)",
            "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Mac: \(sysctl("hw.model") ?? "unknown") · \(sysctl("machdep.cpu.brand_string") ?? "unknown")",
        ]
        if chargeLimit.daemonAvailable {
            lines.append("Helper: build \(chargeLimit.daemonBuildVersion), protocol \(chargeLimit.daemonProtocolVersion)"
                         + (chargeLimit.daemonOutdated ? " (outdated)" : ""))
            let steps = chargeLimit.nativeLimitSteps.isEmpty
                ? "" : " (\(chargeLimit.nativeLimitSteps.map(String.init).joined(separator: "/"))%)"
            lines.append("Charge control: \(chargeLimit.schemeDescription)\(steps)")
        } else {
            lines.append("Helper: not responding"
                         + (chargeLimit.helperInstallFailure.map { ". \($0)" } ?? ""))
        }
        var power = ["\(battery.percentage)%", battery.isCharging ? "charging"
                     : battery.isPluggedIn ? "on power, not charging" : "on battery"]
        if let health = battery.healthPercent { power.append("health \(health)%") }
        if let cycles = battery.cycleCount { power.append("\(cycles) cycles") }
        lines.append("Battery: " + power.joined(separator: " · "))
        lines.append("Settings: limit \(chargeLimit.limitEnabled ? "\(chargeLimit.limit)%" : "off")"
                     + (chargeLimit.holdCharge ? " · don't charge" : "")
                     + (chargeLimit.isPaused ? " · paused" : "")
                     + (chargeLimit.sealedSleep ? " · sealed sleep" : "")
                     + (chargeLimit.keepAwake ? " · always active" : ""))
        lines.append("License: " + {
            switch license.state {
            case .licensed:          return "licensed"
            case .trial(let left):   return "trial, \(left) day\(left == 1 ? "" : "s") left"
            case .expired:           return "trial ended"
            }
        }())
        return lines.joined(separator: "\n")
    }

    /// The summary plus the helper's recent log: what "Copy Diagnostics" puts on the
    /// clipboard, for pasting into an email or an issue.
    static func diagnostics(chargeLimit: ChargeLimitStore, license: LicenseManager,
                            battery: BatterySnapshot) -> String {
        let log = logTail(lines: 40)
        return summary(chargeLimit: chargeLimit, license: license, battery: battery)
            + "\n\nRecent helper log:\n" + (log.isEmpty ? "(unavailable)" : log)
    }

    /// A new email to support with the summary filled in.
    static func emailURL(subject: String, summary: String, extra: [String] = []) -> URL? {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = email
        let body = "What happened:\n\n\n\n---\n" + ([summary] + extra).joined(separator: "\n")
        parts.queryItems = [URLQueryItem(name: "subject", value: subject),
                            URLQueryItem(name: "body", value: body)]
        return parts.url
    }

    /// A new GitHub issue with a template and the summary filled in.
    static func issueURL(summary: String) -> URL? {
        var parts = URLComponents(string: newIssue)
        let body = """
            **What happened**


            **What you expected**


            **Steps to reproduce**
            1.

            **Diagnostics**
            ```
            \(summary)
            ```
            """
        parts?.queryItems = [URLQueryItem(name: "body", value: body)]
        return parts?.url
    }

    /// The last `lines` lines of the helper's log. Read from the end, so a log that has
    /// grown for months costs the same as a fresh one.
    private static func logTail(lines: Int) -> String {
        guard let handle = FileHandle(forReadingAtPath: logPath) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.seek(toOffset: size > 16_384 ? size - 16_384 : 0)
        guard let data = try? handle.readToEnd(), let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(lines).joined(separator: "\n")
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
