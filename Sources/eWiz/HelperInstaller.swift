import Foundation
import AppKit

/// Installs/uninstalls the root helper via a one-time admin prompt (osascript). Only
/// works from a built .app bundle (the scripts live in Resources).
enum HelperInstaller {
    static var canInstall: Bool { bundledScript("install-helper-bundled.sh") != nil }

    static func install() -> (ok: Bool, message: String) {
        run("install-helper-bundled.sh")
    }

    static func uninstall() -> (ok: Bool, message: String) {
        run("uninstall-helper.sh")
    }

    private static func bundledScript(_ name: String) -> String? {
        let base = (name as NSString).deletingPathExtension
        return Bundle.main.url(forResource: base, withExtension: "sh")?.path
    }

    private static func run(_ scriptName: String) -> (Bool, String) {
        guard let path = bundledScript(scriptName) else {
            return (false, "Installer not found. Build the app with package-app.sh.")
        }
        // Escape for AppleScript string literal.
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
                          .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"/bin/bash \\\"\(escaped)\\\"\" with administrator privileges"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", appleScript]
        let err = Pipe()
        proc.standardError = err
        proc.standardOutput = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 { return (true, "Helper installed.") }
            let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            return (false, msg.isEmpty ? "Install cancelled or failed." : msg)
        } catch {
            return (false, "\(error)")
        }
    }
}
