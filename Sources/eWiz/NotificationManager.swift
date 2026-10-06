import Foundation
import Combine
import AppKit
import UserNotifications
import EWizKit

/// Posts macOS notifications on charge-state transitions. Edge-triggered — tracks
/// the last state and only fires on change, so it never spams.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var authRequested = false
    private var started = false
    private var cancellables = Set<AnyCancellable>()
    private weak var settingsRef: AppSettings?
    private weak var batteryRef: BatteryStore?
    private weak var chargeLimitRef: ChargeLimitStore?

    override init() {
        super.init()
        // Present banners even when a eWiz window happens to be frontmost.
        center.delegate = self
    }

    /// Detect transitions via Combine — SwiftUI onChange/onAppear on a status-item
    /// label don't fire dependably. Idempotent; call once from the always-rendered label.
    func startIfNeeded(settings: AppSettings, battery: BatteryStore, chargeLimit: ChargeLimitStore) {
        guard !started else { return }
        started = true
        settingsRef = settings; batteryRef = battery; chargeLimitRef = chargeLimit
        // Baseline the current state so pre-existing conditions don't fire retroactively.
        evaluate(settings: settings, battery: battery, chargeLimit: chargeLimit)
        // If already enabled from a previous launch, register now so the app appears in
        // System Settings › Notifications and can deliver, instead of at some random transition.
        if settings.notificationsEnabled { ensureAuthorized(promptIfDenied: false) }
        // objectWillChange fires before the value updates, so hop to the main actor with
        // a Task to read settled values. assumeIsolated would trap on macOS 26 off-main.
        Publishers.Merge(
            battery.objectWillChange.map { _ in () },
            chargeLimit.objectWillChange.map { _ in () }
        )
        .sink { [weak self] in
            Task { @MainActor in self?.reevaluate() }
        }
        .store(in: &cancellables)
    }

    private func reevaluate() {
        guard let settings = settingsRef, let battery = batteryRef, let chargeLimit = chargeLimitRef else { return }
        evaluate(settings: settings, battery: battery, chargeLimit: chargeLimit)
    }

    /// User turned notifications on — request permission, or point to Settings if denied.
    func enableRequested() {
        ensureAuthorized(promptIfDenied: true)
    }

    /// Resolve authorization. When promptIfDenied (explicit user action) a denial opens
    /// Settings; at launch it stays silent. Hops via Task { @MainActor } to stay isolation-safe.
    private func ensureAuthorized(promptIfDenied: Bool) {
        center.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .notDetermined:
                    self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        Task { @MainActor in if !granted && promptIfDenied { self.showDeniedAlert() } }
                    }
                case .denied:
                    if promptIfDenied { self.showDeniedAlert() }
                default:
                    break   // already authorized
                }
            }
        }
    }

    /// Post a test notification. Resolves authorization first — posting before the
    /// prompt is answered drops the notification.
    func sendTest() {
        center.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                guard let self else { return }
                switch status {
                case .authorized, .provisional:
                    self.post("test", "eWiz", "Notifications are working.", icon: "check")
                case .notDetermined:
                    self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        Task { @MainActor in
                            if granted {
                                self.post("test", "eWiz", "Notifications are working.",
                                          icon: "check")
                            }
                            else { self.showDeniedAlert() }
                        }
                    }
                default:   // .denied
                    self.showDeniedAlert()
                }
            }
        }
    }

    private func showDeniedAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Notifications are turned off"
        alert.informativeText = "Turn on notifications for eWiz in System Settings › Notifications to receive charge alerts."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // Last-seen state, for edge detection.
    private var initialized = false
    private var lastReason: String?
    private var lastLow = false
    private var lastFull = false

    /// Battery %, at or below which (on battery) we warn about low charge.
    private let lowThreshold = 20

    /// Ask for notification permission, once.
    func requestAuthorization() {
        guard !authRequested else { return }
        authRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Evaluate current state and fire notifications for new transitions. Idempotent.
    func evaluate(settings: AppSettings, battery: BatteryStore, chargeLimit: ChargeLimitStore) {
        let snap = battery.snapshot
        // `isHoldingCharge`, not `!chargingEnabled`. A Mac with no SMC charge-inhibit key
        // always reports charging as enabled, so `reason` was permanently nil there and
        // neither "Charge limit reached" nor "Charging paused, battery warm" could ever
        // fire — on the hardware that holds the level by cutting the adapter instead.
        let reason = chargeLimit.isHoldingCharge ? chargeLimit.pauseReason : nil
        let low = !snap.isPluggedIn && snap.percentage <= lowThreshold
        let full = snap.isFullyCharged

        // Always advance the baseline so events while off don't fire retroactively later.
        defer {
            lastReason = reason
            lastLow = low
            lastFull = full
            initialized = true
        }

        guard settings.notificationsEnabled, initialized else { return }
        requestAuthorization()

        if reason != lastReason {
            switch reason {
            case "heat":
                post("heat", "Charging paused",
                     "Your battery is warm, so charging is paused to protect it.",
                     icon: "thermometer")
            case "limit":
                post("limit", "Charge limit reached",
                     "Holding at \(chargeLimit.effectiveLimit)% to reduce battery wear.",
                     icon: "battery")
            default:
                break   // "paused"/"settling"/"sleep" are user- or system-driven
            }
        }

        if low && !lastLow {
            post("low", "Low battery", "\(snap.percentage)% remaining. Plug in soon.",
                 icon: "batteryLow")
        }
        if full && !lastFull {
            post("full", "Battery full", "Charged to 100%.", icon: "check")
        }
    }

    /// Deliver a notification, replacing any prior one of the same category.
    private func post(_ id: String, _ title: String, _ body: String, icon: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // A glyph for what happened. macOS owns the big left-hand icon — that's always the
        // app's — so this lands as the thumbnail on the right, the only per-notification
        // image an app is allowed. Better than four identical banners.
        if let icon, let attachment = NotificationIcon.attachment(icon, identifier: "ewiz.\(id).icon") {
            content.attachments = [attachment]
        }
        // Group all eWiz alerts under one thread in Notification Center.
        content.threadIdentifier = "ewiz"
        let ident = "ewiz.\(id)"
        center.removePendingNotificationRequests(withIdentifiers: [ident])
        center.removeDeliveredNotifications(withIdentifiers: [ident])
        center.add(UNNotificationRequest(identifier: ident, content: content, trigger: nil))
    }
}
