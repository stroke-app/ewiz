import Foundation
import EWizKit

/// A stdio MCP server: newline-delimited JSON-RPC 2.0 in on stdin, out on stdout.
///
/// Dual-era. Clients on the 2025-11-25 revision and earlier open with an `initialize`
/// handshake; 2026-07-28 clients send no handshake, carry the protocol version in every
/// request's `_meta`, and may ask `server/discover` up front. Both are served.
final class MCPServer {
    static let modernVersions = ["2026-07-28"]
    static let legacyVersions = ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]
    private static let versionKey = "io.modelcontextprotocol/protocolVersion"
    private static let serverInfoKey = "io.modelcontextprotocol/serverInfo"

    private let awake: AgentAwake
    private let serverInfo: [String: Any]

    init(awake: AgentAwake, version: String) {
        self.awake = awake
        serverInfo = ["name": "ewiz", "title": "eWiz", "version": version]
    }

    static let instructions = """
        Keeps this Mac awake while you work. Before a long build, test run, render, download or \
        anything else that must not be cut short by sleep, call ewiz_keep_awake with a lease \
        a little longer than you expect to need, call it again to extend before it runs out, and \
        call ewiz_release_awake as soon as the work is done. Only ask for allow_lid_closed \
        when the work has to survive the lid being shut. ewiz_status shows what is held.
        """

    // MARK: - Transport

    /// One line in, at most one line out. Notifications (no `id`) never get a reply.
    func handle(line: String) -> String? {
        guard let data = line.data(using: .utf8),
              let message = try? JSONSerialization.jsonObject(with: data) else {
            return encode(error(id: NSNull(), code: -32700, "Parse error"))
        }
        if let batch = message as? [Any] {
            let replies = batch.compactMap { respond(to: $0) }
            return replies.isEmpty ? nil : encode(replies)
        }
        return respond(to: message).map(encode)
    }

    private func respond(to message: Any) -> [String: Any]? {
        guard let request = message as? [String: Any], let method = request["method"] as? String else {
            return error(id: (message as? [String: Any])?["id"] ?? NSNull(), code: -32600, "Invalid Request")
        }
        guard let id = request["id"], !(id is NSNull) else { return nil }   // a notification
        let params = request["params"] as? [String: Any] ?? [:]

        // A modern request names its version; refuse one we don't speak rather than guess.
        let meta = params["_meta"] as? [String: Any]
        let modern = meta?[Self.versionKey] as? String
        if let modern, !(Self.modernVersions + Self.legacyVersions).contains(modern) {
            return error(id: id, code: -32022, "Unsupported protocol version",
                         data: ["supported": Self.modernVersions + Self.legacyVersions,
                                "requested": modern])
        }

        let result: [String: Any]
        switch method {
        case "initialize":
            let asked = params["protocolVersion"] as? String
            result = [
                "protocolVersion": asked.flatMap { Self.legacyVersions.contains($0) ? $0 : nil }
                    ?? Self.legacyVersions[0],
                "capabilities": ["tools": ["listChanged": false]],
                "serverInfo": serverInfo,
                "instructions": Self.instructions,
            ]
        case "server/discover":
            result = [
                "supportedVersions": Self.modernVersions + Self.legacyVersions,
                "capabilities": ["tools": [String: Any]()],
                "instructions": Self.instructions,
            ]
        case "ping":
            result = [:]
        case "tools/list":
            result = ["tools": Self.tools]
        case "tools/call":
            guard let name = params["name"] as? String, Self.toolNames.contains(name) else {
                return error(id: id, code: -32602, "Unknown tool: \(params["name"] ?? "none")")
            }
            result = call(name, params["arguments"] as? [String: Any] ?? [:])
        default:
            return error(id: id, code: -32601, "Method not found: \(method)")
        }

        var body = result
        if modern != nil || method == "server/discover" {
            body["resultType"] = "complete"
            // 2026-07-28 requires caching hints on these; Claude Code rejects the list without
            // them. The tool set never changes within a build and carries nothing per-user.
            if method == "server/discover" || method == "tools/list" {
                body["ttlMs"] = 3_600_000
                body["cacheScope"] = "public"
            }
            var resultMeta = body["_meta"] as? [String: Any] ?? [:]
            resultMeta[Self.serverInfoKey] = serverInfo
            body["_meta"] = resultMeta
        }
        return ["jsonrpc": "2.0", "id": id, "result": body]
    }

    // MARK: - Tools

    private static let toolNames: Set<String> = ["ewiz_status", "ewiz_keep_awake",
                                                 "ewiz_release_awake"]

    static var tools: [[String: Any]] { [
        [
            "name": "ewiz_status",
            "title": "eWiz status",
            "description": """
                Battery level and power source, and what is keeping this Mac awake: your own \
                idle hold, and the lid-closed hold (yours, or the user's own Always Active). \
                Check it before a long task to see whether you need ewiz_keep_awake at all.
                """,
            "inputSchema": ["type": "object", "properties": [String: Any](), "additionalProperties": false],
            "annotations": ["readOnlyHint": true, "openWorldHint": false],
        ],
        [
            "name": "ewiz_keep_awake",
            "title": "Keep the Mac awake",
            "description": """
                Stop this Mac sleeping for the next `minutes` while a long build, test suite, \
                render, download or job runs. It's a lease: call again before it runs out to \
                extend it, and call ewiz_release_awake when the work is done. It ends on \
                its own at the deadline or when this MCP session ends, so ask for a little more \
                time than you expect rather than the maximum. By default only idle sleep is \
                held; closing the lid still sleeps the Mac. Set allow_lid_closed only when the \
                work must keep running with the lid shut: that switches on the user's Always \
                Active until the deadline (it never cuts short a hold the user set).
                """,
            "inputSchema": [
                "type": "object",
                "properties": [
                    "minutes": ["type": "integer", "minimum": 1, "maximum": AgentAwake.maxMinutes,
                                "description": "How long to hold, from now. 1–\(AgentAwake.maxMinutes)."],
                    "allow_lid_closed": ["type": "boolean", "default": false,
                                         "description": "Also keep running with the lid closed."],
                    "on_battery": ["type": "boolean",
                                   "description": "With allow_lid_closed: also hold the lid on battery. Omit to keep the user's setting (AC only by default)."],
                    "reason": ["type": "string", "maxLength": 80,
                               "description": "What the Mac is being kept awake for, e.g. \"cargo build --release\". Shown in macOS's power assertions."],
                ],
                "required": ["minutes"],
                "additionalProperties": false,
            ],
            "annotations": ["readOnlyHint": false, "destructiveHint": false,
                            "idempotentHint": true, "openWorldHint": false],
        ],
        [
            "name": "ewiz_release_awake",
            "title": "Let the Mac sleep again",
            "description": """
                Drop the keep-awake this agent took with ewiz_keep_awake, as soon as the \
                work is finished. Leaves any hold the user set themselves untouched.
                """,
            "inputSchema": ["type": "object", "properties": [String: Any](), "additionalProperties": false],
            "annotations": ["readOnlyHint": false, "destructiveHint": false,
                            "idempotentHint": true, "openWorldHint": false],
        ],
    ] }

    private func call(_ name: String, _ args: [String: Any]) -> [String: Any] {
        let outcome: ToolResult
        switch name {
        case "ewiz_status":
            outcome = awake.status()
        case "ewiz_keep_awake":
            outcome = keepAwake(args)
        default:
            outcome = awake.release()
        }
        var result: [String: Any] = ["content": [["type": "text", "text": outcome.text]],
                                     "isError": outcome.isError]
        if !outcome.data.isEmpty { result["structuredContent"] = outcome.data }
        return result
    }

    private func keepAwake(_ args: [String: Any]) -> ToolResult {
        // JSON numbers arrive as NSNumber; accept 30 and 30.0, refuse 30.5, "30" and true.
        // (`is Bool` can't tell: Swift bridges an NSNumber 1 to Bool happily.)
        guard let number = args["minutes"] as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue == number.doubleValue.rounded(),
              (1...AgentAwake.maxMinutes).contains(number.intValue) else {
            return ToolResult(text: "minutes must be a whole number from 1 to \(AgentAwake.maxMinutes).",
                              isError: true)
        }
        let reason = (args["reason"] as? String)
            .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? "agent task"
        return awake.keepAwake(minutes: number.intValue,
                               allowLidClosed: args["allow_lid_closed"] as? Bool ?? false,
                               onBattery: args["on_battery"] as? Bool,
                               reason: reason)
    }

    // MARK: - JSON-RPC

    private func error(id: Any, code: Int, _ message: String, data: Any? = nil) -> [String: Any] {
        var body: [String: Any] = ["code": code, "message": message]
        if let data { body["data"] = data }
        return ["jsonrpc": "2.0", "id": id, "error": body]
    }

    private func encode(_ object: Any) -> String {
        // No pretty-printing: one message per line is the whole framing.
        guard let data = try? JSONSerialization.data(withJSONObject: object,
                                                     options: [.withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}"#
        }
        return text
    }
}
