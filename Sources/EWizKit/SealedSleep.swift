import Foundation

/// Sealed Sleep: the closed-lid contract. A MacBook you shut on Friday should read the
/// same number on Monday.
///
/// The reason a closed Mac drains at all is that it isn't really off. Default sleep keeps
/// memory powered — a continuous trickle for as long as the lid is shut — and macOS wakes
/// the machine on a timer to do maintenance, on the network, for a nearby phone, or
/// because a terminal session is open. Each of those is small. Together, over a weekend,
/// they are the difference between 84% and 60%.
///
/// There is exactly one lever that removes the trickle rather than trimming it: powering
/// memory down and writing it to disk (`hibernatemode 25`). A hibernated Mac isn't asleep,
/// it's off, holding a restore image — nothing to wake, nothing to maintain, nothing to
/// keep alive. Everything else in this file exists to stop something *else* holding the
/// machine up before it can get there.
///
/// The cost is the honest part: waking takes fifteen to thirty seconds instead of being
/// instant, because the whole of memory has to come back off disk. That is the trade, it
/// applies to every sleep and not just the long ones, and it is why this is a switch the
/// user throws rather than something done quietly on their behalf.
public enum SealedSleep {
    /// Instant wake, or absolute zero — the one real choice this feature asks you to make.
    ///
    /// Hibernation is the only lever that removes the memory trickle rather than trimming
    /// it, and it is also the only one with a cost you feel every single time: the whole of
    /// RAM has to come back off disk, which is fifteen to thirty seconds of looking at a
    /// closed laptop wondering if it died.
    ///
    /// The thing that makes this a genuine choice rather than an obvious one is that on
    /// recent Apple silicon the *other* levers already do most of the work. With Power Nap,
    /// wake-for-network and TCP keep-alive off, a closed MacBook can hold its charge for
    /// days on ordinary sleep — the machine this was built on sat shut for thirty hours,
    /// dark-waking hourly, and never moved off 84%. On hardware like that, hibernating buys
    /// a rounding error and charges half a minute for it.
    ///
    /// So: instant wake is the default, and hibernation is the opt-in for the case it
    /// genuinely answers — a Mac closed for a week or more, or older hardware whose sleep
    /// really does bleed. The panel reports what each close actually cost, so the decision
    /// can be made on evidence rather than on this paragraph.
    public static let fastWakeIsDefault = true

    /// `hibernatemode` with memory powered down (image on disk, RAM unpowered).
    public static let hibernateSealed = 25
    /// `hibernatemode` macOS ships with: memory stays powered, image written as a safety net.
    public static let hibernateDefault = 3
}

/// One way a closed Mac can still be spending power.
///
/// Deliberately an enum of *causes* rather than a list of pmset keys. Two of them aren't
/// pmset at all (the radios, and eWiz's own keep-awake), and the point of the audit is
/// to answer "why did my battery move overnight" in the user's terms — not to show them a
/// settings dump and let them work it out.
public enum SleepLeak: String, Codable, Sendable, CaseIterable, Identifiable {
    /// `hibernatemode` isn't 25 — memory is being held up the whole time the lid is shut.
    case memoryStaysPowered
    /// `standby` is off, so the deep state is never reached however long the Mac sits.
    case standbyDisabled
    /// Power Nap: scheduled wakes for mail, calendars, iCloud, Time Machine.
    case powerNap
    /// Wake for network access — anything on the LAN can bring the machine up.
    case wakeForNetwork
    /// TCP keep-alive: the network stack is kept alive through sleep for Find My and
    /// Messages, which means the SoC is kept partly alive too.
    case networkInSleep
    /// An open terminal/SSH session blocks sleep outright.
    case terminalSessions
    /// Wi-Fi left associated across the close.
    case wifiLeftOn
    /// Bluetooth left on, scanning for a mouse, a watch, a pair of earbuds.
    case bluetoothLeftOn
    /// eWiz's own "Always Active" is set to hold on battery, which is a direct
    /// instruction *not* to sleep. Listed because it is the one leak the app itself causes,
    /// and silently overriding a setting the user deliberately turned on would be worse
    /// than naming the conflict.
    case keptAwakeOnBattery

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .memoryStaysPowered: return "Memory stays powered"
        case .standbyDisabled:    return "Deep sleep is switched off"
        case .powerNap:           return "Power Nap"
        case .wakeForNetwork:     return "Wake for network access"
        case .networkInSleep:     return "Network kept alive in sleep"
        case .terminalSessions:   return "Terminal sessions block sleep"
        case .wifiLeftOn:         return "Wi-Fi stays on"
        case .bluetoothLeftOn:    return "Bluetooth stays on"
        case .keptAwakeOnBattery: return "Always Active holds on battery"
        }
    }

    /// What it costs, in the terms someone would actually notice.
    public var cost: String {
        switch self {
        case .memoryStaysPowered:
            return "The single largest one. Memory draws power continuously for as long as the lid is shut, whether or not anything wakes."
        case .standbyDisabled:
            return "Without standby the Mac never reaches its deep state, so hibernation has nothing to hand over to."
        case .powerNap:
            return "Wakes the Mac on a schedule to fetch mail and sync iCloud. Each wake is short; overnight there are dozens."
        case .wakeForNetwork:
            return "Any machine on the network can wake yours. A shared printer or a stray scan is enough."
        case .networkInSleep:
            return "Keeps Wi-Fi and part of the SoC alive through sleep so Find My and Messages keep working. That's the trade: locating a closed Mac costs power."
        case .terminalSessions:
            return "An open SSH or terminal session stops the Mac sleeping at all. The classic reason a laptop comes out of a bag warm and empty."
        case .wifiLeftOn:
            return "A radio holding an association, waking to re-associate whenever the access point moves on."
        case .bluetoothLeftOn:
            return "Scanning for accessories inside a shut bag, and waking the Mac when one answers."
        case .keptAwakeOnBattery:
            return "You've asked eWiz to keep this Mac running with the lid closed on battery. It will do exactly that, and the battery pays for it."
        }
    }

    /// Whether Sealed Sleep can fix this itself, or the user has to decide.
    ///
    /// The two it can't are the two where the *right* answer is genuinely theirs: a Mac
    /// you want findable has to stay reachable, and keep-awake on battery is a setting
    /// someone turned on for a reason. Everything else is a straightforward win.
    public var isAutomatic: Bool {
        switch self {
        case .keptAwakeOnBattery: return false
        default: return true
        }
    }

    /// Ordering for display: biggest saving first, then the ones the user must resolve.
    public var weight: Int {
        switch self {
        case .memoryStaysPowered: return 0
        case .standbyDisabled:    return 1
        case .terminalSessions:   return 2
        case .keptAwakeOnBattery: return 3
        case .networkInSleep:     return 4
        case .powerNap:           return 5
        case .wakeForNetwork:     return 6
        case .bluetoothLeftOn:    return 7
        case .wifiLeftOn:         return 8
        }
    }
}

/// The observed state the audit reasons about, gathered from the daemon (pmset),
/// the config, and the app (radio preferences).
///
/// A plain value with no I/O in it, so the rule — what counts as sealed — can be tested
/// without root, a socket, or a Mac that is actually asleep.
public struct SleepState: Sendable, Equatable {
    public var hibernateMode: Int?
    public var standby: Bool?
    public var powerNap: Bool?
    public var wakeForNetwork: Bool?
    public var networkInSleep: Bool?
    public var terminalSessionsKeepAwake: Bool?
    public var wifiOffOnLidClose: Bool
    public var bluetoothOffOnLidClose: Bool
    public var keepAwakeOnBattery: Bool
    /// The user has chosen instant wake over hibernation — see `SealedSleep.fastWake`.
    public var fastWake: Bool

    public init(hibernateMode: Int? = nil,
                standby: Bool? = nil,
                powerNap: Bool? = nil,
                wakeForNetwork: Bool? = nil,
                networkInSleep: Bool? = nil,
                terminalSessionsKeepAwake: Bool? = nil,
                wifiOffOnLidClose: Bool = false,
                bluetoothOffOnLidClose: Bool = false,
                keepAwakeOnBattery: Bool = false,
                fastWake: Bool = false) {
        self.hibernateMode = hibernateMode
        self.standby = standby
        self.powerNap = powerNap
        self.wakeForNetwork = wakeForNetwork
        self.networkInSleep = networkInSleep
        self.terminalSessionsKeepAwake = terminalSessionsKeepAwake
        self.wifiOffOnLidClose = wifiOffOnLidClose
        self.bluetoothOffOnLidClose = bluetoothOffOnLidClose
        self.keepAwakeOnBattery = keepAwakeOnBattery
        self.fastWake = fastWake
    }

    /// Everything still costing power with the lid shut, worst first.
    ///
    /// Unknown values (a key this Mac doesn't expose, or a daemon too old to report it)
    /// count as *not* leaking. Listing a leak we can't see is how a checklist starts
    /// lying, and a Mac without the key can't be spending power through it either.
    public var leaks: [SleepLeak] {
        var found: [SleepLeak] = []
        // Powered memory is only a leak if you didn't choose it. With instant wake on it's
        // a trade the user made deliberately, and on hardware where ordinary sleep already
        // holds its charge it costs nothing — so reporting it would be the checklist
        // nagging about a setting that is working exactly as asked.
        if !fastWake, let mode = hibernateMode, mode != SealedSleep.hibernateSealed {
            found.append(.memoryStaysPowered)
        }
        if standby == false { found.append(.standbyDisabled) }
        if powerNap == true { found.append(.powerNap) }
        if wakeForNetwork == true { found.append(.wakeForNetwork) }
        if networkInSleep == true { found.append(.networkInSleep) }
        if terminalSessionsKeepAwake == true { found.append(.terminalSessions) }
        if !wifiOffOnLidClose { found.append(.wifiLeftOn) }
        if !bluetoothOffOnLidClose { found.append(.bluetoothLeftOn) }
        if keepAwakeOnBattery { found.append(.keptAwakeOnBattery) }
        return found.sorted { $0.weight < $1.weight }
    }

    /// True when nothing is left to fix.
    public var isSealed: Bool { leaks.isEmpty }

    /// Leaks Sealed Sleep will close on its own, and the ones it won't.
    public var automaticLeaks: [SleepLeak] { leaks.filter(\.isAutomatic) }
    public var manualLeaks: [SleepLeak] { leaks.filter { !$0.isAutomatic } }
}

/// What Sealed Sleep displaced on the way in, so switching it off puts macOS back as it was.
///
/// Same shape and same reasoning as `PerformanceRestore`: these are system-wide, persistent
/// `pmset` settings, and a feature that silently keeps them after you turn it off is a
/// feature that changed your Mac permanently. Captured once, on the transition in.
public struct SealedSleepRestore: Codable, Sendable, Equatable {
    public var hibernateMode: Int
    public var standby: Bool
    public var powerNap: Bool
    public var wakeForNetwork: Bool
    public var networkInSleep: Bool
    public var terminalSessionsKeepAwake: Bool
    /// Raw `pmset` keys this Mac happens to expose, captured verbatim.
    ///
    /// The named fields above are the keys every Mac has. These are the ones that only
    /// exist on some — the standby delays and auto-power-off on Intel, proximity wake
    /// where the hardware supports it. Held as strings rather than as six more optional
    /// properties because the set is hardware-dependent and this type has no business
    /// knowing which Mac it's on; whatever was read is what gets written back.
    public var extras: [String: String]

    public init(hibernateMode: Int, standby: Bool, powerNap: Bool,
                wakeForNetwork: Bool, networkInSleep: Bool,
                terminalSessionsKeepAwake: Bool,
                extras: [String: String] = [:]) {
        self.hibernateMode = hibernateMode
        self.standby = standby
        self.powerNap = powerNap
        self.wakeForNetwork = wakeForNetwork
        self.networkInSleep = networkInSleep
        self.terminalSessionsKeepAwake = terminalSessionsKeepAwake
        self.extras = extras
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hibernateMode = try c.decodeIfPresent(Int.self, forKey: .hibernateMode) ?? SealedSleep.hibernateDefault
        standby = try c.decodeIfPresent(Bool.self, forKey: .standby) ?? true
        powerNap = try c.decodeIfPresent(Bool.self, forKey: .powerNap) ?? true
        wakeForNetwork = try c.decodeIfPresent(Bool.self, forKey: .wakeForNetwork) ?? false
        networkInSleep = try c.decodeIfPresent(Bool.self, forKey: .networkInSleep) ?? true
        terminalSessionsKeepAwake = try c.decodeIfPresent(Bool.self, forKey: .terminalSessionsKeepAwake) ?? false
        // Absent in snapshots taken before this existed; an empty set restores nothing,
        // which is right — nothing was changed to restore.
        extras = try c.decodeIfPresent([String: String].self, forKey: .extras) ?? [:]
    }
}

/// The `pmset` keys that decide *how soon* a closed Mac reaches its deep state, and the
/// values Sealed Sleep wants them at.
///
/// This is the half of the feature that only matters away from Apple silicon, and it is
/// the half that used to be missing. `hibernatemode 25` says what state to end up in; on a
/// Mac that has these keys, nothing says *when*. The stock `standbydelayhigh` is 24 hours,
/// and `highstandbythreshold 50` means a Mac closed above 50% charge uses it — so a laptop
/// shut on Friday at 80% spends the entire weekend in ordinary sleep with memory powered,
/// reaching hibernation around Sunday. The mode was set; it simply never engaged.
///
/// Ten minutes, on both delays, with the threshold out of the way. Apple silicon exposes
/// none of these, and writes to keys a Mac doesn't have are dropped — `pmset` prints
/// nothing for them and the verify step skips what it can't read back.
public enum StandbyTiming {
    /// How long a closed Mac waits before powering memory down, in seconds.
    public static let delaySeconds = 600

    /// Key/value pairs, in the order they're written.
    public static var settings: [(key: String, value: String)] {
        [("standbydelaylow", String(delaySeconds)),
         ("standbydelayhigh", String(delaySeconds)),
         // 0 = never prefer the long delay, whatever the charge level.
         ("highstandbythreshold", "0"),
         // Intel's deepest state: cut power to everything but the RTC after the delay.
         ("autopoweroff", "1"),
         ("autopoweroffdelay", String(delaySeconds))]
    }

    public static var keys: [String] { settings.map(\.key) }
}

/// How well the last stretch of closed-lid sleep actually went.
///
/// The claim this feature makes is measurable, so it gets measured. Nothing here is a
/// prediction: every number comes from a `LidSession` the app recorded by reading the
/// charge at close and again at open.
public struct SealedSleepResult: Sendable, Equatable {
    /// Points lost per hour with the lid shut.
    public let perHour: Double
    public let session: LidSession

    public init?(_ session: LidSession) {
        guard let rate = session.dropPerHour else { return nil }
        self.perHour = rate
        self.session = session
    }

    /// A drain small enough that the reading is dominated by the battery gauge's own
    /// 1% granularity rather than by anything the Mac did. That is what "zero" means for
    /// a number derived from an integer percentage, and claiming more precision than the
    /// gauge has would be a lie told with a decimal point.
    public var isEssentiallyZero: Bool { session.dropPercent == 0 }

    /// What a night of this costs, for the one comparison people actually make.
    public var overnightPercent: Double { perHour * 8 }

    /// Whether this close drained like one that handed over to hibernation.
    ///
    /// The receipt could only ever report the drop, never whether the mechanism that is
    /// supposed to stop it did anything. Those two failures look identical from the
    /// outside: a deferral switched off and a deferral that was booked and never
    /// delivered both show up as the memory trickle, and the only place the difference
    /// was recorded is a root-owned log. This makes the measurement check the promise.
    public enum Handover: Sendable, Equatable {
        /// Instant wake with no handover booked: the trickle is the expected outcome,
        /// not a fault.
        case notConfigured
        /// The close never outlasted the window, so there was nothing to hand over.
        case tooShortToMatter
        /// A long close with a flat line. The handover did its job.
        case worked
        /// A long close that drained as though memory stayed powered the whole time.
        case didNotFire
    }

    /// - Parameter afterMinutes: the configured deferral, 0 meaning never.
    public func handover(afterMinutes: Int) -> Handover {
        guard afterMinutes > 0 else { return .notConfigured }
        // Twice the window before judging: a close that ends just past the deadline has
        // barely any hibernated time in it to show up in an integer percentage.
        guard session.duration > Double(afterMinutes) * 60 * 2 else { return .tooShortToMatter }
        // The gauge reports whole points, and the window's own trickle is a fraction of
        // one - 20 minutes at 0.2%/h is 0.07%. So on a close this long, any whole point
        // lost is memory that stayed powered past the deadline.
        return session.dropPercent == 0 ? .worked : .didNotFire
    }
}
