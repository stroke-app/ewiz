import Foundation
import EWizKit

/// Working with the lid shut, as one switch.
///
/// Three settings that only mean anything together: the daemon's keep-awake carries the
/// hold through the lid closing, its permission to hold on battery stops the whole thing
/// quietly ending the moment the charger comes out, and the app's own assertion keeps the
/// session from idling out while you're still using it. Anyone setting this up by hand
/// sets all three, so the mode sets all three.
///
/// It lives here rather than in either view because the menu's "Lid" tile and the
/// Sleep & Power setting are the same switch in two places, and two copies of this
/// would drift — one of them would be the one that forgot the battery permission.
@MainActor
enum ClamshellMode {
    /// On when the hold that survives a lid close is in force — which is the daemon's,
    /// and only the daemon's.
    ///
    /// The other two are deliberately not part of this reading. `keepAwakeOnBattery` is an
    /// option *of* the mode, not a way of switching it off. And the app's own assertion
    /// dies with the app: keying the switch to it meant that quitting and reopening
    /// eWiz showed the mode as off over a Mac the helper was still holding wide awake
    /// — the lid shut, the fans up, and a switch saying nothing was happening.
    static func isOn(charge: ChargeLimitStore) -> Bool { charge.keepAwake }

    /// Turning it on allows the hold on battery too — a lid-closed mode that ends the
    /// moment you unplug is not the mode anyone asks for. Narrow it afterwards if the
    /// drain matters more than the work.
    static func set(_ on: Bool, charge: ChargeLimitStore, caffeine: CaffeineManager) {
        on ? caffeine.activate(.indefinite) : caffeine.deactivate()
        charge.keepAwake = on
        charge.keepAwakeOnBattery = on
        charge.apply()
    }
}
