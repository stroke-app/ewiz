import AppKit
import Carbon.HIToolbox
import EWizKit

/// 'BTLF' — the four-char code tagging our hotkey registrations so the shared
/// application event target can tell ours apart from any other client's.
private let hotkeySignature: OSType = 0x4254_4C46

/// Carbon delivers hot-key events to a C callback, which can't be a method. The
/// monitor instance is passed through as `userData`.
private func hotkeyEventHandler(_ callRef: EventHandlerCallRef?,
                                _ event: EventRef?,
                                _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var id = EventHotKeyID()
    let status = GetEventParameter(event,
                                   EventParamName(kEventParamDirectObject),
                                   EventParamType(typeEventHotKeyID),
                                   nil,
                                   MemoryLayout<EventHotKeyID>.size,
                                   nil,
                                   &id)
    guard status == noErr, id.signature == hotkeySignature else {
        return OSStatus(eventNotHandledErr)
    }
    Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue().fire(id: id.id)
    return noErr
}

/// Registers system-wide keyboard shortcuts through Carbon's `RegisterEventHotKey`.
///
/// Deliberately Carbon rather than `NSEvent.addGlobalMonitorForEvents`: the NSEvent
/// route needs Accessibility permission (and sees every keystroke the user types),
/// while `RegisterEventHotKey` asks the window server to deliver only the specific
/// combinations we claim — no TCC prompt, and nothing else is observable.
@MainActor
final class HotkeyMonitor {
    /// Called on the main actor when a registered shortcut fires.
    var onFire: ((HotkeyAction) -> Void)?

    private var handler: EventHandlerRef?
    /// Live registrations, keyed by the id we handed Carbon.
    private var registered: [UInt32: (ref: EventHotKeyRef, action: HotkeyAction)] = [:]
    /// Combinations another app already owns — surfaced in Settings so a shortcut
    /// that silently does nothing is explainable rather than a mystery.
    private(set) var rejected: Set<HotkeyAction> = []

    /// Replace all registrations with `bindings`. Cheap enough to call on every edit:
    /// a dozen unregister + register calls are microseconds of window-server IPC.
    func apply(_ bindings: HotkeyBindings, enabled: Bool) {
        unregisterAll()
        guard enabled else { return }
        installHandlerIfNeeded()

        // Carbon ids are 1-based and assigned in `active` order, which is sorted by
        // action — so the same binding set always produces the same ids.
        for (index, entry) in bindings.active.enumerated() {
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(entry.hotkey.keyCode,
                                             entry.hotkey.modifiers.rawValue,
                                             EventHotKeyID(signature: hotkeySignature, id: id),
                                             GetApplicationEventTarget(),
                                             0,
                                             &ref)
            if status == noErr, let ref {
                registered[id] = (ref, entry.action)
            } else {
                // Almost always eventHotKeyExistsErr: something else holds the combo.
                rejected.insert(entry.action)
            }
        }
    }

    func unregisterAll() {
        for (_, entry) in registered { UnregisterEventHotKey(entry.ref) }
        registered.removeAll()
        rejected.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            hotkeyEventHandler,
                            1,
                            &spec,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &handler)
    }

    /// Entry point from the C callback. Carbon delivers on the main thread, but hop
    /// through the main actor explicitly rather than asserting it — an unchecked
    /// assumption here would be a crash instead of a one-tick delay.
    nonisolated func fire(id: UInt32) {
        Task { @MainActor [weak self] in
            guard let self, let entry = self.registered[id] else { return }
            self.onFire?(entry.action)
        }
    }

    // No deinit cleanup: the monitor is owned by `HotkeyStore` for the whole app
    // lifetime, and Carbon registrations belong to the process — they're released when
    // it exits. (A `deinit` couldn't touch this isolated state anyway.) Turning
    // shortcuts off goes through `unregisterAll()`, which is the path that matters.
}
