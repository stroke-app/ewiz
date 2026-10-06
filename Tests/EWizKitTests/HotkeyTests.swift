import Testing
import Foundation
@testable import EWizKit

// MARK: - Display

@Test func modifiersRenderInMacOrder() {
    // macOS always shows ⌃⌥⇧⌘, whatever order they were pressed in.
    let all: HotkeyModifiers = [.command, .shift, .option, .control]
    #expect(all.symbols == "⌃⌥⇧⌘")
    #expect(HotkeyModifiers([.control, .option, .command]).symbols == "⌃⌥⌘")
    #expect(HotkeyModifiers([]).symbols == "")
}

@Test func displayStringNamesTheKey() {
    #expect(Hotkey(keyCode: 8, modifiers: [.control, .option, .command]).displayString == "⌃⌥⌘C")
    #expect(Hotkey(keyCode: 126, modifiers: [.command]).displayString == "⌘↑")
    #expect(Hotkey(keyCode: 49, modifiers: [.option]).displayString == "⌥Space")
}

@Test func unknownKeyCodeFallsBackToItsNumber() {
    // Never render an empty box for a code we don't have a name for.
    #expect(Hotkey(keyCode: 250, modifiers: [.command]).displayString == "⌘#250")
}

// MARK: - Validity

@Test func aShortcutNeedsAQualifyingModifier() {
    // Bare keys and shift-only would swallow ordinary typing system-wide.
    #expect(!Hotkey(keyCode: 8, modifiers: []).isValid)
    #expect(!Hotkey(keyCode: 8, modifiers: [.shift]).isValid)
    #expect(Hotkey(keyCode: 8, modifiers: [.command]).isValid)
    #expect(Hotkey(keyCode: 8, modifiers: [.control]).isValid)
    #expect(Hotkey(keyCode: 8, modifiers: [.option]).isValid)
    #expect(Hotkey(keyCode: 8, modifiers: [.shift, .command]).isValid)
}

// MARK: - Defaults

@Test func defaultsMatchTheActionsThatDeclareThem() {
    let bindings = HotkeyBindings.default
    for action in HotkeyAction.allCases {
        #expect(bindings.hotkey(for: action) == action.defaultHotkey,
                "\(action.rawValue) default binding doesn't match its declaration")
    }
    #expect(bindings.isDefault)
}

@Test func noTwoDefaultsShareACombination() {
    // Carbon refuses a duplicate registration, so a collision here would mean one of
    // the two shipped shortcuts silently never fires.
    var seen: Set<Hotkey> = []
    for action in HotkeyAction.allCases {
        guard let key = action.defaultHotkey else { continue }
        #expect(!seen.contains(key), "\(action.rawValue) reuses \(key.displayString)")
        seen.insert(key)
    }
}

@Test func everyDefaultIsRegisterable() {
    for action in HotkeyAction.allCases {
        guard let key = action.defaultHotkey else { continue }
        #expect(key.isValid, "\(action.rawValue) ships an unregisterable default")
    }
}

@Test func destructiveActionsShipUnbound() {
    // Sleeping the Mac or force-discharging shouldn't be one stray keystroke away.
    #expect(HotkeyAction.sleepNow.defaultHotkey == nil)
    #expect(HotkeyAction.toggleDischarge.defaultHotkey == nil)
}

// MARK: - Assignment

@Test func assigningACombinationTakesItFromItsPreviousOwner() {
    var bindings = HotkeyBindings()
    let key = Hotkey(keyCode: 8, modifiers: [.control, .option, .command])
    bindings.set(key, for: .toggleCaffeine)

    let displaced = bindings.set(key, for: .toggleLowPowerMode)

    #expect(displaced == .toggleCaffeine)
    #expect(bindings.hotkey(for: .toggleCaffeine) == nil)
    #expect(bindings.hotkey(for: .toggleLowPowerMode) == key)
    #expect(bindings.action(for: key) == .toggleLowPowerMode)
}

@Test func reassigningTheSameActionDisplacesNothing() {
    var bindings = HotkeyBindings()
    let key = Hotkey(keyCode: 8, modifiers: [.command])
    bindings.set(key, for: .toggleCaffeine)
    #expect(bindings.set(key, for: .toggleCaffeine) == nil)
    #expect(bindings.hotkey(for: .toggleCaffeine) == key)
}

@Test func invalidShortcutsAreRejectedNotStored() {
    var bindings = HotkeyBindings()
    bindings.set(Hotkey(keyCode: 8, modifiers: [.shift]), for: .toggleCaffeine)
    #expect(bindings.hotkey(for: .toggleCaffeine) == nil)
}

@Test func clearRemovesOnlyThatBinding() {
    var bindings = HotkeyBindings.default
    let kept = bindings.hotkey(for: .toggleLowPowerMode)
    bindings.clear(.toggleCaffeine)
    #expect(bindings.hotkey(for: .toggleCaffeine) == nil)
    #expect(bindings.hotkey(for: .toggleLowPowerMode) == kept)
    #expect(!bindings.isDefault)
}

@Test func activeListsEveryBindingInAStableOrder() {
    let bindings = HotkeyBindings.default
    let first = bindings.active.map(\.action)
    let second = bindings.active.map(\.action)
    // Registration ids are derived from this order, so it must not vary run to run.
    #expect(first == second)
    #expect(first == HotkeyAction.allCases.filter { bindings.hotkey(for: $0) != nil })
}

// MARK: - Persistence

@Test func bindingsSurviveACodableRoundTrip() throws {
    var bindings = HotkeyBindings.default
    bindings.set(Hotkey(keyCode: 49, modifiers: [.control, .command]), for: .sleepNow)
    bindings.clear(.toggleCaffeine)

    let data = try JSONEncoder().encode(bindings)
    let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: data)

    #expect(decoded == bindings)
    #expect(decoded.hotkey(for: .sleepNow)?.displayString == "⌃⌘Space")
    #expect(decoded.hotkey(for: .toggleCaffeine) == nil)
}

@Test func decodingSkipsUnknownActionsInsteadOfFailing() throws {
    // A binding saved by a newer build must not make the whole file undecodable and
    // reset every shortcut the user set.
    // `modifiers` is a bare number: OptionSet gets its Codable from RawRepresentable,
    // which encodes as a single value rather than a keyed container.
    let json = """
    {"map":{"toggleCaffeine":{"keyCode":8,"modifiers":256},
            "somethingFromTheFuture":{"keyCode":9,"modifiers":256}}}
    """
    let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: Data(json.utf8))
    #expect(decoded.hotkey(for: .toggleCaffeine)?.displayString == "⌘C")
    #expect(decoded.active.count == 1)
}

@Test func decodingDropsStoredShortcutsThatAreNoLongerValid() throws {
    // 512 = shift alone, which isn't a shortcut we'll register.
    let json = """
    {"map":{"toggleCaffeine":{"keyCode":8,"modifiers":512}}}
    """
    let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: Data(json.utf8))
    #expect(decoded.hotkey(for: .toggleCaffeine) == nil)
}

@Test func missingMapDecodesToNoBindings() throws {
    let decoded = try JSONDecoder().decode(HotkeyBindings.self, from: Data("{}".utf8))
    #expect(decoded.active.isEmpty)
}

// MARK: - Catalogue

@Test func everyActionIsInExactlyOneCategory() {
    let grouped = HotkeyAction.Category.allCases.flatMap { HotkeyAction.inCategory($0) }
    #expect(Set(grouped) == Set(HotkeyAction.allCases))
    #expect(grouped.count == HotkeyAction.allCases.count)
}

@Test func everyActionHasATitleAndIcon() {
    for action in HotkeyAction.allCases {
        #expect(!action.title.isEmpty)
        #expect(!action.icon.isEmpty)
    }
}

@Test func onlyTheProWindowsAreGated() {
    let gated = HotkeyAction.allCases.filter(\.requiresPro)
    #expect(Set(gated) == [.openDetails, .openHistory])
}

@Suite struct HotkeyCollisionTests {
    private let d: UInt32 = 2   // kVK_ANSI_D

    @Test func chordsOfOnlyCommandAndShiftAreFlagged() {
        // Grabbed globally, these land before the frontmost app sees them: ⌘D stops being
        // Duplicate everywhere, ⇧⌘D stops being Send.
        #expect(Hotkey(keyCode: d, modifiers: [.command]).collidesWithAppShortcuts)
        #expect(Hotkey(keyCode: d, modifiers: [.command, .shift]).collidesWithAppShortcuts)
    }

    @Test func controlOrOptionKeepsItOutOfTheWay() {
        #expect(!Hotkey(keyCode: d, modifiers: [.control, .option, .command]).collidesWithAppShortcuts)
        #expect(!Hotkey(keyCode: d, modifiers: [.option, .command]).collidesWithAppShortcuts)
        #expect(!Hotkey(keyCode: d, modifiers: [.control, .command]).collidesWithAppShortcuts)
    }
}
