import Foundation
import IOKit
import IOKit.pwr_mgt
import EWizKit

// kIOMessage* are C macros not exported to Swift; these are their constant values
// from <IOKit/IOMessage.h>.
private let kIOMessageCanSystemSleep: UInt32 = 0xE000_0270
private let kIOMessageSystemWillSleep: UInt32 = 0xE000_0280
private let kIOMessageSystemHasPoweredOn: UInt32 = 0xE000_0300

/// Observes sleep/wake via IOKit and reports lid-close (clamshell) sleeps. macOS
/// sleeps on lid close, so "lid closed" is detected at the will-sleep moment.
final class LidMonitor {
    /// Called just before sleep. `clamshellClosed` is true when the lid is shut. Sleep waits
    /// until `done` is called — macOS stops waiting after 30 seconds — so whatever has to land
    /// before the Mac goes down can finish on the main actor first.
    var onWillSleep: ((_ clamshellClosed: Bool, _ done: @escaping @Sendable () -> Void) -> Void)?
    var onDidWake: (() -> Void)?

    private var rootPort: io_connect_t = 0
    private var notifierObject: io_object_t = 0
    private var notifyPort: IONotificationPortRef?

    func start() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var notifier: io_object_t = 0
        var port: IONotificationPortRef?

        rootPort = IORegisterForSystemPower(refcon, &port, { refcon, _, messageType, messageArgument in
            guard let refcon else { return }
            let monitor = Unmanaged<LidMonitor>.fromOpaque(refcon).takeUnretainedValue()
            monitor.handle(messageType, messageArgument)
        }, &notifier)

        guard rootPort != 0, let port else {
            NSLog("eWiz: IORegisterForSystemPower failed")
            return
        }
        notifyPort = port
        notifierObject = notifier

        CFRunLoopAddSource(CFRunLoopGetMain(),
                           IONotificationPortGetRunLoopSource(port).takeUnretainedValue(),
                           .commonModes)
    }

    deinit {
        if let notifyPort {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                                  IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue(),
                                  .commonModes)
        }
        if notifierObject != 0 { IODeregisterForSystemPower(&notifierObject) }
        if rootPort != 0 { IOServiceClose(rootPort) }
        if let notifyPort { IONotificationPortDestroy(notifyPort) }
    }

    private func handle(_ messageType: natural_t, _ argument: UnsafeMutableRawPointer?) {
        switch messageType {
        case UInt32(kIOMessageCanSystemSleep):
            // Don't veto idle sleep.
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))

        case UInt32(kIOMessageSystemWillSleep):
            let closed = Self.isClamshellClosed()
            // Must acknowledge so sleep can proceed — but only once the handler is through.
            // Acknowledging straight away let sleep start before the handler's main-actor
            // task had run, so the radios went off whenever that task got its turn, which
            // could be the next wake.
            let port = rootPort, token = Int(bitPattern: argument)
            let allow: @Sendable () -> Void = { IOAllowPowerChange(port, token) }
            if let onWillSleep { onWillSleep(closed, allow) } else { allow() }

        case UInt32(kIOMessageSystemHasPoweredOn):
            onDidWake?()

        default:
            break
        }
    }

    /// Reads AppleClamshellState from IOPMrootDomain (true = lid closed).
    static func isClamshellClosed() -> Bool { SystemPower.isClamshellClosed() }
}
