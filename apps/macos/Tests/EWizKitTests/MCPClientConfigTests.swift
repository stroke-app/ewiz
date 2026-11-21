import Foundation
import Testing
@testable import EWizKit

@Suite("Adding eWiz to an MCP client config")
struct MCPClientConfigTests {
    private let command = "/Applications/eWiz.app/Contents/MacOS/ewiz-mcp"

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("A missing file starts a new config")
    func fresh() throws {
        let data = try MCPClientConfig.merged(nil, command: command)
        #expect(MCPClientConfig.registeredCommand(in: data) == command)
    }

    /// Claude Desktop keeps its own preferences in the same file. Losing them, or the
    /// user's other servers, would be worse than not connecting at all.
    @Test("Other servers and keys survive")
    func keepsEverythingElse() throws {
        let existing = Data(#"{"globalShortcut":"Cmd+Space","mcpServers":{"github":{"command":"gh-mcp"}}}"#.utf8)
        let root = try object(MCPClientConfig.merged(existing, command: command))
        #expect(root["globalShortcut"] as? String == "Cmd+Space")
        let servers = try #require(root["mcpServers"] as? [String: Any])
        #expect((servers["github"] as? [String: Any])?["command"] as? String == "gh-mcp")
        #expect((servers["ewiz"] as? [String: Any])?["command"] as? String == command)
    }

    @Test("An existing ewiz entry is repointed, not duplicated")
    func repoints() throws {
        let existing = Data(#"{"mcpServers":{"ewiz":{"command":"/old/path/ewiz-mcp"}}}"#.utf8)
        let merged = try MCPClientConfig.merged(existing, command: command)
        #expect(MCPClientConfig.registeredCommand(in: merged) == command)
        #expect((try object(merged)["mcpServers"] as? [String: Any])?.count == 1)
    }

    @Test("A file that isn't JSON is refused, never overwritten")
    func refusesGarbage() {
        #expect(throws: MCPClientConfig.MergeError.unreadable) {
            try MCPClientConfig.merged(Data("{ not json".utf8), command: command)
        }
    }

    @Test("An empty file counts as missing")
    func emptyFile() throws {
        let data = try MCPClientConfig.merged(Data("  \n".utf8), command: command)
        #expect(MCPClientConfig.registeredCommand(in: data) == command)
    }
}
