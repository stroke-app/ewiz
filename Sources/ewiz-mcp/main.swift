import Foundation
import EWizKit

// ewiz-mcp: lets an AI agent keep this Mac awake for a long task, over MCP on stdio.
//
// Register with Claude Code:
//   claude mcp add ewiz -- /Applications/eWiz.app/Contents/MacOS/ewiz-mcp
//
// stdout carries protocol messages only; anything for a human goes to stderr.

setvbuf(stdout, nil, _IOLBF, 0)

// Inside eWiz.app/Contents/MacOS, Bundle.main is the app, so this is the app's version.
let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
let awake = AgentAwake()
let server = MCPServer(awake: awake, version: version)

// A lid hold outlives this process, so it's handed back however the session ends: the
// client closing stdin (below) or a signal (here).
//
// The handler must not inherit the main actor. Top-level code in main.swift is main-actor
// isolated, and against the macOS 26.5 SDK the release is built with, a closure written
// there and handed to setEventHandler inherits that isolation. The runtime then checks it
// on the signal source's global queue and traps (EXC_BREAKPOINT in dispatch_assert_queue),
// so every client ending its session crashed the server instead of releasing the hold.
// Newer SDKs don't, which is why local builds never showed it. An explicitly @Sendable
// closure is nonisolated on every toolchain, and taking `awake` as a parameter keeps it off
// main-actor globals. AgentAwake is Sendable and guards itself with a lock.
func releaseOnSignals(_ awake: AgentAwake) -> [DispatchSourceSignal] {
    [SIGTERM, SIGINT, SIGHUP].map { sig in
        signal(sig, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
        source.setEventHandler { @Sendable in
            awake.shutdown()
            exit(0)
        }
        source.resume()
        return source
    }
}
let signalSources = releaseOnSignals(awake)

FileHandle.standardError.write(Data("ewiz-mcp \(version) ready on stdio\n".utf8))

while let line = readLine(strippingNewline: true) {
    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
    if let reply = server.handle(line: line) {
        print(reply)
    }
}
awake.shutdown()
