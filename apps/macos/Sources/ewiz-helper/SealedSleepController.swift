import Foundation
import EWizKit

/// Applies Sealed Sleep, verifies it landed, and puts macOS back when it's switched off.
///
/// Every setting here is system-wide, persistent, and written by `pmset`. Three
/// consequences shape this type:
///
///   - **It's set once, not enforced.** These survive the daemon, the app and a restart.
///     A loop re-asserting them every tick would be forking `pmset` forever to change
///     nothing.
///   - **It has to be undone.** A feature that quietly keeps `hibernatemode 25` after you
///     turn it off has changed the user's Mac permanently. The state it displaces is
///     snapshotted on the way in and written back on the way out.
///   - **`pmset` exits 0 for writes it ignores.** Same lesson the removed fan control
///     taught: a Mac that doesn't expose a key takes the write and drops it. So the apply
///     reads everything back and reports what didn't take, rather than claiming success.
enum SealedSleepController {

    /// The sleep/wake features Sealed Sleep switches off, in the order they're written.
    ///
    /// `tcpKeepAlive` is in here and it is the one with a real cost: with it off, Find My
    /// can't reach a sleeping Mac and Messages won't arrive until it wakes. That is not a
    /// side effect to bury — it's the price of the SoC not being kept half-alive, and the
    /// UI says so where the switch is.
    /// `proximityWake` is in here and absent from this Mac: it only exists where the
    /// hardware can be woken by a nearby iPhone or Watch, and on a machine in a bag that
    /// fires over and over. A write to a key `pmset` doesn't have is dropped, so listing it
    /// costs nothing on hardware that never had the problem.
    static let silenced: [PowerToggle] = [.powerNap, .wakeOnNetwork, .tcpKeepAlive,
                                          .ttysKeepAwake, .proximityWake]

    // MARK: - Reading

    /// What the Mac is doing right now, for the audit. `custom` lets a caller that has
    /// already run `pmset -g custom` avoid a second fork.
    static func observe(from custom: String? = nil,
                        wifiOffOnLidClose: Bool,
                        bluetoothOffOnLidClose: Bool,
                        keepAwakeOnBattery: Bool) -> SleepState {
        let values = PowerSettings.readValues(from: custom).battery
        func flag(_ key: String) -> Bool? { values[key].map { $0 == "1" } }

        return SleepState(
            hibernateMode: values["hibernatemode"].flatMap(Int.init),
            standby: flag("standby"),
            powerNap: flag(PowerToggle.powerNap.rawValue),
            wakeForNetwork: flag(PowerToggle.wakeOnNetwork.rawValue),
            networkInSleep: flag(PowerToggle.tcpKeepAlive.rawValue),
            terminalSessionsKeepAwake: flag(PowerToggle.ttysKeepAwake.rawValue),
            wifiOffOnLidClose: wifiOffOnLidClose,
            bluetoothOffOnLidClose: bluetoothOffOnLidClose,
            keepAwakeOnBattery: keepAwakeOnBattery)
    }

    /// Snapshot exactly what Sealed Sleep is about to displace.
    ///
    /// Absent keys fall back to what macOS ships with rather than to "off": restoring a
    /// Mac to a state it was never in is worse than restoring it to the default, and a key
    /// that isn't there wasn't doing anything anyway.
    static func snapshot(from custom: String? = nil) -> SealedSleepRestore {
        let values = PowerSettings.readValues(from: custom).battery
        func flag(_ key: String, default fallback: Bool) -> Bool {
            values[key].map { $0 == "1" } ?? fallback
        }
        // Only keys this Mac actually prints. An absent key was never changed, so writing
        // a guessed default back on the way out would be inventing a state it was never in.
        var extras: [String: String] = [:]
        for key in StandbyTiming.keys + [PowerToggle.proximityWake.rawValue] {
            if let value = values[key] { extras[key] = value }
        }

        return SealedSleepRestore(
            hibernateMode: values["hibernatemode"].flatMap(Int.init) ?? SealedSleep.hibernateDefault,
            standby: flag("standby", default: true),
            powerNap: flag(PowerToggle.powerNap.rawValue, default: true),
            wakeForNetwork: flag(PowerToggle.wakeOnNetwork.rawValue, default: false),
            networkInSleep: flag(PowerToggle.tcpKeepAlive.rawValue, default: true),
            terminalSessionsKeepAwake: flag(PowerToggle.ttysKeepAwake.rawValue, default: false),
            extras: extras)
    }

    // MARK: - Writing

    /// Seal the Mac. Returns the keys that refused to change, empty when everything took.
    ///
    /// Order matters once: `standby` before `hibernatemode`, because hibernation is the
    /// state standby hands over to, and writing the mode to a Mac that isn't allowed to
    /// stand by sets a mode that can never be entered.
    /// `fastWake` seals everything except memory: the wake sources still go, the radios
    /// still drop, but `hibernatemode` is left where the user had it so the lid opens
    /// instantly. It is the difference between "nothing wakes this Mac" and "nothing wakes
    /// this Mac and it takes half a minute to come back".
    static func apply(fastWake: Bool, restoring saved: SealedSleepRestore?) -> [String] {
        let wantedMode = fastWake
            ? (saved?.hibernateMode ?? SealedSleep.hibernateDefault)
            : SealedSleep.hibernateSealed
        PowerSettings.setKey("standby", "1")
        PowerSettings.setKey("hibernatemode", String(wantedMode))
        for toggle in silenced { PowerSettings.set(toggle, false) }
        // When the deep state is reached, on the Macs that let that be asked. Dropped
        // silently where the keys don't exist, which is every Apple silicon Mac.
        // Only meaningful when we're actually asking the Mac to reach hibernation.
        let timing = fastWake ? [] : StandbyTiming.settings
        for (key, value) in timing { PowerSettings.setKey(key, value) }
        return verify(hibernateMode: wantedMode,
                      standby: true,
                      toggles: silenced.map { ($0, false) },
                      raw: timing.map { ($0.key, $0.value) })
    }

    /// Free what doesn't need writing to disk, just before the lid closes.
    ///
    /// Hibernation writes memory to `/var/vm/sleepimage` and reads it all back on wake, so
    /// the size of that file is both the disk written on the way down and the seconds spent
    /// waiting on the way up. `purge` drops the inactive file cache — pages macOS is holding
    /// on the chance they're wanted again — which is exactly the part of memory there is no
    /// reason to preserve across a hibernation.
    ///
    /// The cost is a colder cache on wake, and it is the right trade here and almost nowhere
    /// else: the Mac is about to be shut for hours, and by the time it opens that cache would
    /// have been stale anyway. Only runs when Sealed Sleep is on; bounded, because it happens
    /// inside the short window macOS gives before it powers things down.
    @discardableResult
    static func releaseCachedMemory() -> Bool {
        // Nothing to shrink when memory isn't being written to disk.
        Shell.run("/usr/sbin/purge", []) != nil
    }

    /// Put back what was there before. Returns the keys that refused.
    static func restore(_ saved: SealedSleepRestore) -> [String] {
        PowerSettings.setKey("hibernatemode", String(saved.hibernateMode))
        PowerSettings.setKey("standby", saved.standby ? "1" : "0")
        for (key, value) in saved.extras { PowerSettings.setKey(key, value) }
        let wanted: [(PowerToggle, Bool)] = [
            (.powerNap, saved.powerNap),
            (.wakeOnNetwork, saved.wakeForNetwork),
            (.tcpKeepAlive, saved.networkInSleep),
            (.ttysKeepAwake, saved.terminalSessionsKeepAwake),
        ]
        for (toggle, on) in wanted { PowerSettings.set(toggle, on) }
        return verify(hibernateMode: saved.hibernateMode,
                      standby: saved.standby,
                      toggles: wanted,
                      raw: saved.extras.map { ($0.key, $0.value) })
    }

    /// Read everything back and name what didn't take.
    ///
    /// A key this Mac doesn't expose at all is *not* a failure — there's nothing there to
    /// refuse, and reporting it would put a permanent red mark on a machine that is doing
    /// everything it can. Only a key that exists and disagrees with what we asked for counts.
    private static func verify(hibernateMode: Int,
                               standby: Bool,
                               toggles: [(PowerToggle, Bool)],
                               raw: [(String, String)] = []) -> [String] {
        let values = PowerSettings.readValues().battery
        var refused: [String] = []

        if let actual = values["hibernatemode"].flatMap(Int.init), actual != hibernateMode {
            refused.append("hibernatemode")
        }
        if let actual = values["standby"], (actual == "1") != standby {
            refused.append("standby")
        }
        for (key, wanted) in raw where values[key] != nil && values[key] != wanted {
            refused.append(key)
        }
        for (toggle, wanted) in toggles {
            if let actual = values[toggle.rawValue], (actual == "1") != wanted {
                refused.append(toggle.rawValue)
            }
        }
        return refused
    }
}
