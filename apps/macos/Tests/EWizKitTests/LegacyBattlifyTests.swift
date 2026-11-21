import Foundation
import Testing
@testable import EWizKit

@Suite("Battlify → eWiz folder handover")
struct LegacyBattlifyTests {
    private func scratch() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ewiz-legacy-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write(_ text: String, _ url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("Everything moves across and the old folder goes")
    func movesAll() throws {
        let root = scratch(), old = root.appendingPathComponent("Battlify"),
            new = root.appendingPathComponent("eWiz")
        write("{}", old.appendingPathComponent("config.json"))
        write("80", old.appendingPathComponent("native-limit"))

        let moved = LegacyBattlify.merge(old, into: new)
        #expect(Set(moved) == ["config.json", "native-limit"])
        #expect(try String(contentsOf: new.appendingPathComponent("native-limit"), encoding: .utf8) == "80")
        #expect(!FileManager.default.fileExists(atPath: old.path))
    }

    /// The installer creates the new folder before the daemon first runs, sometimes with
    /// a fresh config in it. What's there wins; the old copy stays rather than vanishing.
    @Test("An existing file in the new folder wins")
    func keepsExisting() throws {
        let root = scratch(), old = root.appendingPathComponent("Battlify"),
            new = root.appendingPathComponent("eWiz")
        write("old", old.appendingPathComponent("config.json"))
        write("history", old.appendingPathComponent("history.jsonl"))
        write("new", new.appendingPathComponent("config.json"))

        #expect(LegacyBattlify.merge(old, into: new) == ["history.jsonl"])
        #expect(try String(contentsOf: new.appendingPathComponent("config.json"), encoding: .utf8) == "new")
        #expect(FileManager.default.fileExists(atPath: old.appendingPathComponent("config.json").path))
    }

    @Test("No old folder is a no-op")
    func nothingToMove() {
        let root = scratch()
        #expect(LegacyBattlify.merge(root.appendingPathComponent("Battlify"),
                                     into: root.appendingPathComponent("eWiz")).isEmpty)
    }
}
