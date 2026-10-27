import Foundation
import Testing
@testable import EWizKit

@Suite("Hold anchor on disk")
struct HoldAnchorStoreTests {
    private func scratch() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ewiz-hold-anchor-\(UUID().uuidString)")
            .appendingPathComponent("hold-anchor")
    }

    @Test("A saved anchor is read back after a restart")
    func roundTrip() {
        let file = scratch()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        #expect(HoldAnchorStore.load(from: file) == nil)
        HoldAnchorStore.save(80, to: file)
        #expect(HoldAnchorStore.load(from: file) == 80)
    }

    @Test("Releasing the hold removes the file")
    func release() {
        let file = scratch()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        HoldAnchorStore.save(76, to: file)
        HoldAnchorStore.save(nil, to: file)
        #expect(HoldAnchorStore.load(from: file) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Garbage in the file reads as no anchor")
    func garbage() {
        let file = scratch()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? "not a number\n".write(to: file, atomically: true, encoding: .utf8)
        #expect(HoldAnchorStore.load(from: file) == nil)
    }
}
