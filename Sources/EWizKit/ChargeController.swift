import Foundation

/// MagSafe / charge-status LED states (SMC key ACLC).
public enum MagSafeLED: UInt8, Sendable {
    case system = 0x00   // macOS controls it (default)
    case off    = 0x01
    case green  = 0x03   // charged / holding at limit
    case orange = 0x04   // charging
}

extension MagSafeLED {
    /// The colour Status mode shows, the way a Mac's own light reads: amber while the
    /// battery takes charge, green on the cable when it doesn't, whatever the reason
    /// (full, held at a limit, or the adapter cut to hold the level).
    ///
    /// Hold is green rather than amber because amber is charging; using it for
    /// "deliberately not charging" made the two states identical. The SMC offers only
    /// off, green and amber.
    public static func status(settling: Bool, onExternalPower: Bool,
                              adapterCut: Bool, charging: Bool) -> MagSafeLED {
        if settling { return .off }                  // waiting after wake
        if !onExternalPower { return .system }       // truly unplugged
        if adapterCut { return .green }              // cable in, running off the battery
        return charging ? .orange : .green
    }
}

/// Controls whether the battery is allowed to charge, abstracting over the two
/// SMC schemes Apple Silicon uses:
///   - Pre-Tahoe: 1-byte keys CH0B + CH0C (0x00 = charge, 0x02 = stop)
///   - Tahoe (macOS 26+): 4-byte key CHTE (00 00 00 00 = charge, 01 00 00 00 = stop)
public final class ChargeController {
    private let smc: SMC

    private let ch0b = "CH0B"
    private let ch0c = "CH0C"
    private let chte = "CHTE"
    private let aclc = "ACLC"   // MagSafe LED
    // Adapter keys (force discharge): legacy CH0I/CH0J, Tahoe CHIE.
    private let ch0i = "CH0I"
    private let ch0j = "CH0J"
    private let chie = "CHIE"
    private let acw = "AC-W"    // raw AC/wall power present

    public init(smc: SMC) {
        self.smc = smc
    }

    // Key presence is fixed for the process lifetime, so cache each `keyExists` probe
    // once — avoids a dozen redundant IOKit calls every daemon tick. The daemon's lock
    // serializes access, so lazy init is safe.
    private lazy var cachedAdapterKey: String? = {
        if smc.keyExists(ch0i) { return ch0i }
        if smc.keyExists(ch0j) { return ch0j }
        if smc.keyExists(chie) { return chie }
        return nil
    }()
    private lazy var cachedUsesLegacyKeys: Bool = smc.keyExists(ch0b) && smc.keyExists(ch0c)
    private lazy var cachedHasChte: Bool = smc.keyExists(chte)
    private lazy var cachedMagSafeSupported: Bool = smc.keyExists(aclc)
    /// The same key set `isChargingEnabled`, `enableCharging` and `disableCharging`
    /// actually use — both legacy keys, or CHTE.
    ///
    /// It was `ch0b || ch0c || chte`, which is a different question. A Mac exposing only
    /// one of the legacy pair answered yes here and then failed every read and write: the
    /// legacy path needs both, so `usesLegacyKeys` was false and all three calls went to a
    /// CHTE that isn't there. The daemon reported charge control as supported, the app
    /// offered the limit, and every enforcement attempt threw into a `try?`.
    /// `schemeDescription` already told the truth about that Mac — it says "unsupported"
    /// for exactly this case — so the two were contradicting each other.
    private lazy var cachedChargingControlSupported: Bool = cachedUsesLegacyKeys || cachedHasChte
    private lazy var cachedHasAcw: Bool = smc.keyExists(acw)

    // MARK: - AC / wall power presence
    //
    // Raw SMC `AC-W`. Unlike the IOKit providing-source flag, this survives
    // force-discharge — `AC-W` still reads the cable as attached while the OS thinks
    // it's on battery, which lets discharge run to the limit instead of oscillating.

    public var isACPowerReadSupported: Bool { cachedHasAcw }

    /// True when the charger is physically connected, from `AC-W`. Returns nil if
    /// the key isn't available (caller should fall back to IOKit power state).
    public func isACPresent() -> Bool? {
        guard cachedHasAcw, let b = try? smc.read(acw).bytes.first else { return nil }
        return Int8(bitPattern: b) > 0
    }

    // MARK: - Adapter / force discharge
    //
    // Disabling the adapter runs the Mac off battery while plugged in — used to bring
    // the level down to the limit when you plug in above it.

    private var adapterKey: String? { cachedAdapterKey }

    public var isAdapterControlSupported: Bool { cachedAdapterKey != nil }

    /// True when the adapter is supplying power normally (not force-discharging).
    public func isAdapterEnabled() throws -> Bool {
        guard let k = adapterKey else { return true }
        let v = try smc.read(k)
        return v.bytes.first == 0x00
    }

    public func enableAdapter() throws {
        guard let k = adapterKey else { return }
        try smc.write(k, [0x00])
    }

    /// Force discharge by cutting the adapter. CHIE (Tahoe) uses 0x08; others 0x01.
    public func disableAdapter() throws {
        guard let k = adapterKey else { return }
        try smc.write(k, [k == chie ? 0x08 : 0x01])
    }

    // MARK: - MagSafe LED

    public var isMagSafeSupported: Bool { cachedMagSafeSupported }

    public func setMagSafeLED(_ state: MagSafeLED) throws {
        try smc.write(aclc, [state.rawValue])
    }

    /// Current MagSafe LED state (nil if it's a value we don't model, e.g. an
    /// error-blink state). Used to detect macOS overriding our setting.
    public func magSafeLED() -> MagSafeLED? {
        guard let raw = try? smc.read(aclc).bytes.first else { return nil }
        return MagSafeLED(rawValue: raw)
    }

    private var usesLegacyKeys: Bool { cachedUsesLegacyKeys }

    public var isChargingControlSupported: Bool { cachedChargingControlSupported }

    public func isChargingEnabled() throws -> Bool {
        if usesLegacyKeys {
            // Read BOTH inhibit keys, not just CH0B: charging is enabled if *either*
            // still allows it. A non-atomic stop that set CH0B but not CH0C would
            // otherwise read as "stopped" while the battery keeps charging — so this
            // reports still-charging and the caller retries the stop (no overshoot).
            let b = try smc.read(ch0b).bytes.first
            let c = try smc.read(ch0c).bytes.first
            return b == 0x00 || c == 0x00
        } else {
            let v = try smc.read(chte)
            return v.bytes.prefix(4).allSatisfy { $0 == 0x00 }
        }
    }

    public func enableCharging() throws {
        if usesLegacyKeys {
            try smc.write(ch0b, [0x00])
            try smc.write(ch0c, [0x00])
        } else {
            try smc.write(chte, [0x00, 0x00, 0x00, 0x00])
        }
    }

    public func disableCharging() throws {
        if usesLegacyKeys {
            try smc.write(ch0b, [0x02])
            try smc.write(ch0c, [0x02])
        } else {
            try smc.write(chte, [0x01, 0x00, 0x00, 0x00])
        }
    }

    public var schemeDescription: String {
        if usesLegacyKeys { return "legacy (CH0B/CH0C)" }
        if cachedHasChte { return "tahoe (CHTE)" }
        return "unsupported"
    }
}
