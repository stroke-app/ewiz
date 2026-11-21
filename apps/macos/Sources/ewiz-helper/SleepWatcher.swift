import Foundation
import IOKit
import IOKit.pwr_mgt

// kIOMessage* are C macros not exported to Swift; these are their values from
// <IOKit/IOMessage.h>.
private let kIOMessageCanSystemSleep: UInt32 = 0xE000_0270
private let kIOMessageSystemWillSleep: UInt32 = 0xE000_0280
private let kIOMessageSystemHasPoweredOn: UInt32 = 0xE000_0300

/// Sleep/wake notifications for the *daemon*.
///
/// The charge limit is enforced by a tick loop, and that loop is frozen while the Mac
/// sleeps — so whatever the SMC was told last is what holds for the whole sleep. If the
/// Mac sleeps while charging below the limit, macOS keeps charging and the battery sails
/// past the limit to full, with nothing awake to stop it.
///
/// The GUI also asks for a pre-sleep cut, but it can only do that while it is running:
/// quit the app, log out, or let it crash, and the protection silently disappears. This
/// watcher puts the same hook in the root daemon, which launchd keeps alive, so cutting
/// charging before sleep no longer depends on a user-space process being there.
///
/// Runs its own thread and run loop: the daemon's main loop blocks on a timed wait and
/// would never service the notification source.
final class SleepWatcher {
    /// Called on the watcher's thread just before the system sleeps. Must return before
    /// sleep is acknowledged, so keep it short and synchronous.
    var onWillSleep: (() -> Void)?
    /// Called after the Mac powers back on.
    var onDidWake: (() -> Void)?

    private var rootPort: io_connect_t = 0
    private var notifierObject: io_object_t = 0
    private var notifyPort: IONotificationPortRef?
    private var thread: Thread?

    func start() {
        let thread = Thread { [weak self] in self?.run() }
        thread.name = "com.ewiz.helper.sleepwatcher"
        thread.qualityOfService = .utility
        self.thread = thread
        thread.start()
    }

    private func run() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var notifier: io_object_t = 0
        var port: IONotificationPortRef?

        rootPort = IORegisterForSystemPower(refcon, &port, { refcon, _, messageType, argument in
            guard let refcon else { return }
            Unmanaged<SleepWatcher>.fromOpaque(refcon)
                .takeUnretainedValue()
                .handle(messageType, argument)
        }, &notifier)

        guard rootPort != 0, let port else {
            HelperLog.error("IORegisterForSystemPower failed")
            return
        }
        notifyPort = port
        notifierObject = notifier

        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
                           .defaultMode)
        CFRunLoopRun()
    }

    private func handle(_ messageType: natural_t, _ argument: UnsafeMutableRawPointer?) {
        switch messageType {
        case UInt32(kIOMessageCanSystemSleep):
            // Never veto sleep — that would be a battery app keeping the Mac awake.
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))

        case UInt32(kIOMessageSystemWillSleep):
            onWillSleep?()
            // Acknowledge, or macOS waits out the full timeout before sleeping.
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))

        case UInt32(kIOMessageSystemHasPoweredOn):
            onDidWake?()

        default:
            break
        }
    }
}
