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
    /// Called just before sleep. `clamshellClosed` is true when the lid is shut.
    var onWillSleep: ((_ clamshellClosed: Bool) -> Void)?
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
            onWillSleep?(closed)
            // Must acknowledge so sleep can proceed.
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))

        case UInt32(kIOMessageSystemHasPoweredOn):
            onDidWake?()

        default:
            break
        }
    }

    /// Reads AppleClamshellState from IOPMrootDomain (true = lid closed).
    static func isClamshellClosed() -> Bool { SystemPower.isClamshellClosed() }
}
