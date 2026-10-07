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
// `awake` is bound to a local first. Top-level variables in main.swift are main-actor
// isolated under Swift 6, and reading one from the signal source's global queue tripped
// the runtime's isolation assertion: every SIGTERM from a client ending its session
// crashed the server (EXC_BREAKPOINT in dispatch_assert_queue) instead of releasing the
// hold. AgentAwake is Sendable and guards itself with a lock, so the local is safe anywhere.
let awakeForSignals = awake
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
    source.setEventHandler {
        awakeForSignals.shutdown()
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

FileHandle.standardError.write(Data("ewiz-mcp \(version) ready on stdio\n".utf8))

while let line = readLine(strippingNewline: true) {
    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
    if let reply = server.handle(line: line) {
        print(reply)
    }
}
awake.shutdown()
