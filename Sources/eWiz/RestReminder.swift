import Foundation
import Combine
import AppKit
import UserNotifications
import EWizKit

/// Occasionally suggests giving the Mac a rest once it's been running a long time —
/// surfaced as a menu banner and, if notifications are on, a notification. Uptime is
/// the signal; a warm battery makes the wording more pointed.
@MainActor
final class RestReminder: ObservableObject {
    @Published private(set) var isDue = false
    @Published private(set) var uptimeDays = 0

    private weak var settings: AppSettings?
    private weak var battery: BatteryStore?
    private let defaults = UserDefaults.standard
    private let center = UNUserNotificationCenter.current()
    private var timer: Timer?
    private var started = false

    private enum Keys {
        static let snoozeUntil = "rest.snoozeUntil"
        static let lastNotified = "rest.lastNotifiedAt"
    }

    func startIfNeeded(settings: AppSettings, battery: BatteryStore) {
        guard !started else { return }
        started = true
        self.settings = settings
        self.battery = battery
        // Called from a view body (the always-rendered menu-bar label); defer the first
        // evaluate so we don't publish `isDue` mid-render, which SwiftUI would drop.
        Task { @MainActor in self.evaluate() }
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
        t.tolerance = 3600
        RunLoop.main.add(t, forMode: .common)
        timer = t
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.evaluate() }
        }
    }

    /// Recompute whether a rest is due; the first time it is, post a notification (throttled).
    func evaluate() {
        guard let settings, settings.restReminderEnabled,
              let uptime = SystemUptime.secondsSinceBoot() else {
            isDue = false; return
        }
        uptimeDays = Int(uptime / 86_400)
        let now = Date()
        isDue = RestAdvisor.isDue(uptime: uptime, now: now,
                                  snoozeUntil: defaults.object(forKey: Keys.snoozeUntil) as? Date)

        guard isDue, settings.notificationsEnabled,
              RestAdvisor.shouldNotify(now: now,
                                       lastNotifiedAt: defaults.object(forKey: Keys.lastNotified) as? Date)
        else { return }
        // Don't drop "time to restart" over a film or a game. Nothing is recorded as
        // notified, so the next evaluate — six hours on, or the next wake — tries again.
        guard ScreenActivity.busyReason() == nil else { return }
        defaults.set(now, forKey: Keys.lastNotified)
        postNotification()
    }

    /// Hide the reminder for a few days (also suppresses the notification).
    func snooze(days: Int = 3) {
        defaults.set(Date().addingTimeInterval(Double(days) * 86_400), forKey: Keys.snoozeUntil)
        isDue = false
    }

    /// One-line rationale, sharpened when the battery is running warm.
    var message: String {
        if let t = battery?.snapshot.temperature, t >= WearAnalysis.hotThresholdC {
            return "Your Mac has been on for \(uptimeDays) days and is running warm. A restart clears memory and helps it cool down."
        }
        return "Your Mac has been on for \(uptimeDays) days. An occasional restart clears out memory and keeps it running smoothly."
    }

    /// Ask macOS to restart (user-initiated); the normal "save your work" flow runs.
    func restart() {
        let script = "tell application \"System Events\" to restart"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        p.standardOutput = Pipe(); p.standardError = Pipe()
        try? p.run()
    }

    private func postNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time to give your Mac a rest"
        content.body = message
        content.sound = .default
        content.threadIdentifier = "ewiz"
        let ident = "ewiz.rest"
        center.removeDeliveredNotifications(withIdentifiers: [ident])
        center.add(UNNotificationRequest(identifier: ident, content: content, trigger: nil))
    }
}
