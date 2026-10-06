import SwiftUI
import AppKit
import Carbon.HIToolbox
import EWizKit

extension HotkeyModifiers {
    /// Only the four modifiers a shortcut can use. `.function` and `.numericPad`
    /// arrive set for arrow and keypad keys and must be dropped, or ⌃⌥⌘↑ would
    /// register with flags Carbon doesn't recognise and never fire.
    init(_ flags: NSEvent.ModifierFlags) {
        var m: HotkeyModifiers = []
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.option)  { m.insert(.option) }
        if flags.contains(.shift)   { m.insert(.shift) }
        if flags.contains(.command) { m.insert(.command) }
        self = m
    }
}

/// The click-to-record shortcut field used by each row in the Shortcuts tab.
///
/// Every state — set, unset, recording, needs-a-modifier, taken by another app — is
/// drawn inside one fixed-size pill, and the clear button is overlaid rather than
/// placed beside it. So nothing in the row moves as the state changes: no reflow when
/// a warning appears, no gap where an absent button used to be.
///
/// Which row is recording is owned by the parent, so starting a new recording ends
/// any other — two fields can't both hold first responder.
struct HotkeyRecorderField: View {
    let hotkey: Hotkey?
    let isRecording: Bool
    /// True when another app owns this combination, so it can't be registered.
    let unavailable: Bool
    let onBegin: () -> Void
    let onCapture: (Hotkey) -> Void
    let onCancel: () -> Void
    let onClear: () -> Void

    /// Set when the user types something without ⌃/⌥/⌘, which we won't accept.
    @State private var needsModifier = false
    @State private var hovering = false

    // Sized to hold the longest label ("Needs ⌃⌥⌘") without the text having to
    // shrink, so every row's pill is the same width and the column stays straight.
    private let pillWidth: CGFloat = 112
    private let pillHeight: CGFloat = 26

    var body: some View {
        Button {
            needsModifier = false
            isRecording ? onCancel() : onBegin()
        } label: {
            labelContent
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(foreground)
                // Room on the right for the clear button so a long shortcut never
                // runs underneath it.
                .padding(.leading, 8)
                .padding(.trailing, hotkey != nil ? 20 : 8)
                .frame(width: pillWidth, height: pillHeight)
                .background(background, in: shape)
                .overlay(shape.strokeBorder(border, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(PressableShortcutStyle())
        .help(helpText)
        // Overlaid, not adjacent: an inline button would leave a hole in the row
        // whenever there was no shortcut to clear.
        .overlay(alignment: .trailing) {
            if hotkey != nil, !isRecording {
                Button {
                    needsModifier = false
                    onClear()
                } label: {
                    HugeIcon("cancel", size: 11)
                        .foregroundStyle(hovering ? Color.primary.opacity(0.7) : .secondary)
                        .frame(width: 22, height: pillHeight)  // hit area, not visual size
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Remove this shortcut")
                // Fades rather than appears: the pill is a single object, and a
                // button blinking into existence inside it reads as a glitch.
                .opacity(hovering ? 1 : 0)
                .padding(.trailing, 3)
                .animation(.easeOut(duration: 0.12), value: hovering)
            }
        }
        // The zero-sized catcher exists only to hold first responder while recording.
        .overlay(alignment: .trailing) {
            if isRecording {
                KeyCatcher(
                    onCapture: { candidate in
                        guard candidate.isValid else {
                            needsModifier = true
                            NSSound.beep()
                            return
                        }
                        needsModifier = false
                        onCapture(candidate)
                    },
                    onClear: { needsModifier = false; onClear() },
                    onCancel: { needsModifier = false; onCancel() })
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
        }
        .onHover { hovering = $0 }
        .onChange(of: isRecording) { _, recording in
            if !recording { needsModifier = false }
        }
    }

    private var shape: RoundedRectangle {
        // Concentric with the 12pt card it sits in, minus the row's inset.
        RoundedRectangle(cornerRadius: 8, style: .continuous)
    }

    /// A set shortcut is drawn glyph by glyph with real gaps between the modifiers:
    /// "⌃⌥⌘P" set solid at 12pt collapses into one dense mark where no single
    /// modifier is legible. The key name sits a touch further out again, so the combo
    /// parses as "modifiers, then key" at a glance. The system font (not monospaced)
    /// draws these glyphs at the widths macOS uses everywhere else — the pill is a
    /// fixed width anyway, so monospacing bought nothing but crowding.
    @ViewBuilder
    private var labelContent: some View {
        if let hotkey, !isRecording, !needsModifier {
            HStack(spacing: 2.5) {
                ForEach(Array(hotkey.modifiers.glyphs.enumerated()), id: \.offset) { _, glyph in
                    Text(glyph)
                }
                Text(Hotkey.keyName(hotkey.keyCode))
                    .padding(.leading, 1.5)
            }
            .font(.system(size: 12, weight: .medium))
        } else {
            Text(label).font(.system(size: 12))
        }
    }

    /// Every state reads out here, so the row never has to grow to explain itself.
    private var label: String {
        if needsModifier { return "Needs ⌃⌥⌘" }
        if isRecording { return "Type…" }
        return hotkey?.displayString ?? "Not set"
    }

    private var foreground: Color {
        if needsModifier { return .orange }
        if isRecording { return .accentColor }
        if unavailable { return .orange }
        return hotkey == nil ? .secondary : .primary
    }

    private var background: AnyShapeStyle {
        if isRecording { return AnyShapeStyle(Color.accentColor.opacity(0.12)) }
        if unavailable { return AnyShapeStyle(Color.orange.opacity(0.10)) }
        return AnyShapeStyle(.quaternary.opacity(0.6))
    }

    private var border: Color {
        if isRecording { return .accentColor.opacity(0.9) }
        if unavailable { return .orange.opacity(0.45) }
        return .clear
    }

    private var helpText: String {
        if isRecording { return "Type the shortcut, or press ⎋ to cancel" }
        if unavailable {
            return "Another app already owns \(hotkey?.displayString ?? "this shortcut"). Pick a different one."
        }
        return hotkey == nil ? "Click to set a shortcut" : "Click to change this shortcut"
    }
}

/// Scale-on-press so the pill acknowledges the click that starts recording.
private struct PressableShortcutStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Key capture

private struct KeyCatcher: NSViewRepresentable {
    let onCapture: (Hotkey) -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCatcherView {
        let view = KeyCatcherView()
        view.onCapture = onCapture
        view.onClear = onClear
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ view: KeyCatcherView, context: Context) {
        view.onCapture = onCapture
        view.onClear = onClear
        view.onCancel = onCancel
    }
}

/// Takes first responder and swallows one keystroke.
final class KeyCatcherView: NSView {
    var onCapture: ((Hotkey) -> Void)?
    var onClear: (() -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if !handle(event) { super.keyDown(with: event) }
    }

    /// Combinations including ⌘ are offered as key equivalents before `keyDown`, and
    /// would otherwise be eaten by the main menu (⌘W closing the window, say).
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event)
    }

    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = HotkeyModifiers(event.modifierFlags.intersection(.deviceIndependentFlagsMask))

        // Bare ⎋ cancels and bare ⌫ clears — both are more useful as recorder controls
        // than as bindings. With modifiers held they're recordable like any other key.
        if modifiers.isEmpty {
            switch Int(event.keyCode) {
            case kVK_Escape:
                onCancel?()
                return true
            case kVK_Delete, kVK_ForwardDelete:
                onClear?()
                return true
            default:
                break
            }
        }

        onCapture?(Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers))
        return true
    }
}
