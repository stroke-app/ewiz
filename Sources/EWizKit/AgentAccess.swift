import Foundation

/// Whether AI agents may use eWiz through `ewiz-mcp`: Settings › Automation › AI Agents.
///
/// Kept in the app's own preferences domain. The MCP server is a separate process the
/// agent starts, running as the same user, so it reads the switches straight from there
/// on every request: turning access off takes effect at the agent's next call, with no
/// restart of anything.
public enum AgentAccess {
    public static let domain = "com.ewiz.app"
    public static let enabledKey = "agents.enabled"
    public static let lidClosedKey = "agents.allowLidClosed"

    /// The idle-sleep assertion `ewiz-mcp` holds is named this plus the agent's reason,
    /// which is how the app finds it to say who is keeping the Mac awake.
    public static let assertionPrefix = "eWiz MCP: "

    /// Off only when switched off: an agent can't use eWiz until someone registers the
    /// server with it, and that's already a deliberate yes.
    public static var isEnabled: Bool { read(enabledKey) ?? true }
    /// The lid-closed hold changes how the Mac sleeps, so it has a switch of its own.
    public static var allowsLidClosed: Bool { read(lidClosedKey) ?? true }

    private static func read(_ key: String) -> Bool? {
        // Another process wrote it; without the sync this can read a cached value.
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool
    }
}

/// Adding eWiz to an MCP client's config file: the `mcpServers` JSON that Claude Desktop,
/// Cursor and most other clients read.
public enum MCPClientConfig {
    public static let serverName = "ewiz"

    public enum MergeError: Error, Equatable {
        /// The file is there but isn't a JSON object. Never overwritten: it's someone's
        /// config, and a parse failure is no licence to replace it.
        case unreadable
    }

    /// `existing` with an `mcpServers.ewiz` entry pointing at `command`, every other key
    /// and server left as it was. A missing or empty file starts a new one.
    public static func merged(_ existing: Data?, command: String) throws -> Data {
        var root: [String: Any] = [:]
        if let existing, !existing.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
            guard let object = try? JSONSerialization.jsonObject(with: existing) as? [String: Any] else {
                throw MergeError.unreadable
            }
            root = object
        }
        var servers = root["mcpServers"] as? [String: Any] ?? [:]
        servers[serverName] = ["command": command, "args": [String]()]
        root["mcpServers"] = servers
        return try JSONSerialization.data(withJSONObject: root,
                                          options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Whether `data` already has an `ewiz` server, and the command it runs.
    public static func registeredCommand(in data: Data?) -> String? {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let server = (root["mcpServers"] as? [String: Any])?[serverName] as? [String: Any] else {
            return nil
        }
        return server["command"] as? String
    }

    /// The JSON block to paste into any other client's config.
    public static func snippet(command: String) -> String {
        let data = (try? merged(nil, command: command)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
