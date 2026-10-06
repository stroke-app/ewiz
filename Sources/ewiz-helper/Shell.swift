import Foundation

/// Minimal synchronous command runner used by the daemon's root actions.
enum Shell {
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = args
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do {
            try proc.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            return proc.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
        } catch {
            return nil
        }
    }
}
