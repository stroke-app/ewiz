import AppKit
import IOKit.pwr_mgt
import EWizKit

/// Settings › Automation › AI Agents: which MCP clients have eWiz, and what agents are
/// holding the Mac awake right now.
///
/// The MCP server ships inside the app (`Contents/MacOS/ewiz-mcp`) and an agent's client
/// starts it. Nothing here runs it; this only connects clients to it and reports on it.
@MainActor
final class AgentStore: ObservableObject {
    /// A keep-awake an agent is holding through `ewiz-mcp`.
    struct Hold: Identifiable, Equatable {
        let id: Int
        let reason: String
        let endsAt: Date?
    }

    /// MCP clients whose config eWiz can write itself.
    enum Client: String, CaseIterable, Identifiable {
        case claudeDesktop, cursor
        var id: String { rawValue }

        var name: String {
            switch self {
            case .claudeDesktop: return "Claude Desktop"
            case .cursor:        return "Cursor"
            }
        }

        var configURL: URL {
            let home = FileManager.default.homeDirectoryForCurrentUser
            switch self {
            case .claudeDesktop:
                return home.appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
            case .cursor:
                return home.appendingPathComponent(".cursor/mcp.json")
            }
        }

        fileprivate var bundleIDs: [String] {
            switch self {
            case .claudeDesktop: return ["com.anthropic.claudefordesktop"]
            case .cursor:        return ["com.todesktop.230313mzl4w4u92"]
            }
        }

        /// The app is on this Mac, or has left its config folder behind.
        var isInstalled: Bool {
            bundleIDs.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
                || FileManager.default.fileExists(atPath: configURL.deletingLastPathComponent().path)
        }
    }

    enum Connection: Equatable {
        case notInstalled
        case notConnected
        case connected
        /// Has an `ewiz` server, pointing at some other copy of the app.
        case elsewhere
    }

    @Published private(set) var holds: [Hold] = []
    @Published private(set) var connections: [Client: Connection] = [:]
    @Published private(set) var claudeCode: Connection = .notConnected
    /// The outcome of the last Connect, shown under the rows.
    @Published var note: String?

    /// This copy's MCP server. Clients run it from here, so it updates with the app.
    var serverPath: String {
        Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/ewiz-mcp").path
    }

    var claudeCodeCommand: String {
        "claude mcp add --scope user \(MCPClientConfig.serverName) -- \"\(serverPath)\""
    }

    var configSnippet: String { MCPClientConfig.snippet(command: serverPath) }

    // MARK: - Holds

    /// Agents holding the Mac awake, from the power assertions `ewiz-mcp` takes. Each one is
    /// named after the task the agent gave, and times out on its own.
    func refreshHolds() {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let byProcess = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else {
            if !holds.isEmpty { holds = [] }
            return
        }
        let found = byProcess.values.joined().compactMap { assertion -> Hold? in
            guard let name = assertion["AssertName"] as? String,
                  name.hasPrefix(AgentAccess.assertionPrefix) else { return nil }
            var endsAt: Date?
            if let left = assertion["AssertTimeoutTimeLeft"] as? Double,
               let since = assertion["AssertTimeoutUpdateTime"] as? Date {
                endsAt = since.addingTimeInterval(left)
            }
            return Hold(id: (assertion["AssertionId"] as? Int) ?? name.hashValue,
                        reason: String(name.dropFirst(AgentAccess.assertionPrefix.count)),
                        endsAt: endsAt)
        }.sorted { ($0.endsAt ?? .distantFuture) < ($1.endsAt ?? .distantFuture) }
        if found != holds { holds = found }
    }

    // MARK: - Clients

    func refreshClients() {
        var next: [Client: Connection] = [:]
        for client in Client.allCases {
            guard client.isInstalled else { next[client] = .notInstalled; continue }
            next[client] = connection(for: MCPClientConfig.registeredCommand(
                in: try? Data(contentsOf: client.configURL)))
        }
        connections = next
        // Claude Code's user-scope servers live in ~/.claude.json. Only read: that file is
        // rewritten constantly by every running session, so eWiz never writes to it.
        let claudeJSON = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
        claudeCode = connection(for: MCPClientConfig.registeredCommand(in: try? Data(contentsOf: claudeJSON)))
    }

    private func connection(for command: String?) -> Connection {
        guard let command else { return .notConnected }
        return command == serverPath ? .connected : .elsewhere
    }

    /// Add eWiz to `client`'s config, keeping everything else in the file.
    func connect(_ client: Client) {
        let url = client.configURL
        do {
            let merged = try MCPClientConfig.merged(try? Data(contentsOf: url), command: serverPath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try merged.write(to: url, options: .atomic)
            note = "Added to \(client.name). Quit and reopen it to load eWiz."
        } catch MCPClientConfig.MergeError.unreadable {
            note = "\(client.name)'s config isn't valid JSON, so it was left alone. Copy the config below and add it by hand."
        } catch {
            note = "Couldn't write \(client.name)'s config: \(error.localizedDescription)"
        }
        refreshClients()
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
