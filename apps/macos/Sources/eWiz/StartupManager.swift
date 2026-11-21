import Foundation
import Combine
import ServiceManagement

/// Manages "Launch at Login" via ServiceManagement (macOS 13+).
/// Only works from a built .app bundle (not `swift run`).
@MainActor
final class StartupManager: ObservableObject {
    @Published private(set) var launchAtLogin = false
    @Published private(set) var requiresApproval = false

    init() { refresh() }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true; requiresApproval = false
        case .requiresApproval:
            launchAtLogin = true; requiresApproval = true
        default:
            launchAtLogin = false; requiresApproval = false
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("eWiz: login item toggle failed: \(error)")
        }
        refresh()
    }
}
