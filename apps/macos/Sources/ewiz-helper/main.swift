import Foundation
import EWizKit

// ewiz-helper: the privileged component. Writing SMC keys requires root, so this
// runs as root (sudo for testing, LaunchDaemon in production). The GUI never writes SMC.

let args = Array(CommandLine.arguments.dropFirst())
let command = args.first ?? "help"

func openSMC() -> (SMC, ChargeController) {
    let smc = SMC()
    do {
        try smc.open()
    } catch {
        FileHandle.standardError.write(Data("error: \(error)\n".utf8))
        exit(2)
    }
    return (smc, ChargeController(smc: smc))
}

func requireRoot() {
    if getuid() != 0 {
        FileHandle.standardError.write(
            Data("error: this command needs root. Re-run with sudo.\n".utf8))
        exit(13)
    }
}

switch command {

case "dump":
    // Diagnostics: no writes, safe to run without root.
    let (smc, charge) = openSMC()
    defer { smc.close() }
    let snap = BatteryMonitor.read()
    print("Battery: \(snap.percentage)%  (\(snap.powerSource), charging=\(snap.isCharging))")
    print("Charge-control scheme: \(charge.schemeDescription)")
    print("Charge control supported: \(charge.isChargingControlSupported)")
    for key in ["CH0B", "CH0C", "CHTE", "CH0I", "CH0J", "CHIE", "ACLC"] {
        if smc.keyExists(key), let v = try? smc.read(key) {
            let hex = v.bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("  \(key) [\(v.dataType)] = \(hex)")
        } else {
            print("  \(key) = (absent)")
        }
    }
    if charge.isChargingControlSupported {
        print("Charging currently enabled: \((try? charge.isChargingEnabled()).map(String.init(describing:)) ?? "unknown")")
    }
    let native = NativeChargeLimit()
    if native.isSupported {
        let now = native.current().map { $0.enabled ? "\($0.limit)%" : "off" } ?? "unreadable"
        let owner = NativeChargeLimitOwnership.load().map { " (eWiz set \($0)%)" } ?? ""
        print("macOS charge limit: \(now)\(owner), steps \(native.steps.map(String.init).joined(separator: "/"))%")
    } else {
        print("macOS charge limit: not offered on this Mac")
    }

case "status":
    let (smc, charge) = openSMC()
    defer { smc.close() }
    let cfg = ConfigStore.load()
    let snap = BatteryMonitor.read()
    print("battery=\(snap.percentage)% limitEnabled=\(cfg.chargeLimitEnabled) limit=\(cfg.chargeLimit)% chargingEnabled=\((try? charge.isChargingEnabled()) ?? false)")

case "enable":
    requireRoot()
    // Uninstall runs this as the last word, after the daemon is gone, so it has to take
    // back macOS's limit as well as the SMC keys, or the Mac keeps stopping at 80% with
    // nothing left that knows why. Only a limit eWiz set; one the user set is theirs.
    if let owned = NativeChargeLimitOwnership.load() {
        let native = NativeChargeLimit()
        if native.current()?.limit == owned { native.disable() }
        NativeChargeLimitOwnership.save(nil)
        print("macOS charge limit released")
    }
    let (smc, charge) = openSMC()
    defer { smc.close() }
    do { try charge.enableCharging(); print("charging enabled") }
    catch { FileHandle.standardError.write(Data("error: \(error)\n".utf8)); exit(1) }

case "disable":
    requireRoot()
    let (smc, charge) = openSMC()
    defer { smc.close() }
    do { try charge.disableCharging(); print("charging disabled") }
    catch { FileHandle.standardError.write(Data("error: \(error)\n".utf8)); exit(1) }

case "limit":
    // Set the limit and enable limiting; the GUI normally does this via config, but the CLI helps testing.
    requireRoot()
    guard let n = args.dropFirst().first.flatMap({ Int($0) }), (20...100).contains(n) else {
        FileHandle.standardError.write(Data("usage: ewiz-helper limit <20-100>\n".utf8))
        exit(64)
    }
    var cfg = ConfigStore.load()
    cfg.chargeLimit = n
    cfg.chargeLimitEnabled = true
    do { try ConfigStore.save(cfg); print("limit set to \(n)% (enabled)") }
    catch { FileHandle.standardError.write(Data("error: \(error)\n".utf8)); exit(1) }

case "daemon":
    requireRoot()
    LegacyHelper.evictAndMigrate()
    Daemon.run()

default:
    print("""
    ewiz-helper — privileged battery control

    Commands:
      dump            Show SMC/charge diagnostics (no root needed)
      status          Show current battery + limit state
      enable          Allow charging (root)
      disable         Stop charging (root)
      limit <20-100>  Set charge limit and enable limiting (root)
      daemon          Run the enforcement loop (root, used by LaunchDaemon)
    """)
}
