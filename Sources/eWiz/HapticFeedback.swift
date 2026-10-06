import AppKit

/// Trackpad taps for power events — the small physical "clunk" that says the電 adapter
/// took hold, without looking at the screen.
///
/// Uses `NSHapticFeedbackManager`, which drives the Force Touch trackpad's haptic engine.
/// Two things to know, and both are said plainly in Settings rather than hidden:
/// it does nothing on a Mac without a Force Touch trackpad (a desktop, or a laptop driven
/// by an external keyboard), and nothing while the lid is shut, because the trackpad is
/// asleep with it. There is no API to ask whether the hardware is there, so the setting
/// can only be offered, not gated.
enum HapticFeedback {

    /// Plugged in: two taps, a beat apart. One tap reads as a click; two read as
    /// "connected", the same way a latch closing does.
    @MainActor static func chargeConnected() {
        tap(.levelChange)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { tap(.levelChange) }
    }

    /// Unplugged: a single, softer tap. Losing power shouldn't feel like an event you
    /// have to look up from.
    @MainActor static func chargeDisconnected() {
        tap(.generic)
    }

    /// Charge limit reached — a triple tick, distinct from plugging in.
    @MainActor static func limitReached() {
        tap(.alignment)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { tap(.alignment) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { tap(.alignment) }
    }

    @MainActor private static func tap(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        // `.now` rather than `.drawCompleted`: there's no drawing to wait for, and
        // deferring would land the tap after the moment it's describing.
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
