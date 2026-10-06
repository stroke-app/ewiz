import Foundation
import CPowerUI

/// macOS's own charge limit, System Settings › Battery › Charge Limit, driven through
/// PowerUIAgent the same way System Settings drives it.
///
/// The macOS 26.7 and 15.8 security firmware puts the SMC charge-inhibit keys (CH0B,
/// CH0C, CHTE) behind Apple's private `com.apple.private.iokit.soc-limit` entitlement,
/// root or not. On those Macs the adapter cut was the only lever left, and cutting the
/// adapter runs the Mac off its battery: "don't charge" drained 2% at a time and topped
/// back up, which is the opposite of what anyone switching it on wants. PowerUIAgent holds
/// that entitlement and serves the limit to root. It stops the charge and leaves the Mac
/// on wall power, which is what holding is supposed to mean.
///
/// The price is that Apple picks the levels: fixed steps from 80% (80, 85, … 100 today).
/// And a step is a setpoint, not a ceiling. Below it macOS charges up to it; at it macOS
/// holds on wall power; above it macOS runs the Mac off the battery down to it, while
/// `pmset` still says "AC attached" (measured: 85% on an 80% step, 0.1 W from the adapter,
/// −2.3 A from the battery).
public final class NativeChargeLimit {
    /// The limits this Mac accepts, ascending. Empty when the feature isn't there.
    public let steps: [Int]

    /// Probes once. PowerUI is loaded and asked for its steps here, so construct this only
    /// where the answer is needed.
    public init() {
        guard ewiz_powerui_supported() == 1 else { steps = []; return }
        var raw = [Int32](repeating: 0, count: 32)
        var count: Int32 = 0
        guard ewiz_powerui_available_limits(&raw, Int32(raw.count), &count) == 0 else {
            steps = []; return
        }
        steps = Array(raw.prefix(Int(count))).map(Int.init).filter { $0 > 0 && $0 <= 100 }.sorted()
    }

    public var isSupported: Bool { !steps.isEmpty }

    /// The lowest level macOS can hold at, or nil when there's no native limit.
    public var floor: Int? { steps.first }

    /// The step macOS should enforce for a eWiz target. See `NativeChargeLimit.step`.
    public func step(for target: Int) -> Int? { Self.step(for: target, in: steps) }

    /// What's configured right now: the limit and whether it's being enforced.
    public func current() -> (limit: Int, enabled: Bool)? {
        var limit: Int32 = 0, enabled: Int32 = 0
        guard ewiz_powerui_get_limit(&limit, &enabled) == 0 else { return nil }
        return (Int(limit), enabled == 1)
    }

    @discardableResult
    public func set(_ limit: Int) -> Bool { ewiz_powerui_set_limit(Int32(limit)) == 0 }

    @discardableResult
    public func disable() -> Bool { ewiz_powerui_disable() == 0 }

    /// The step to enforce for eWiz's hold and limit together, or nil for none.
    ///
    /// The hold rounds *up*: the first step at or above the level it was thrown at. Every
    /// step is a setpoint, so no step holds a level between two of them, and the choice is
    /// only which way to miss. Rounding down drains the battery to the step below, which is
    /// exactly the "battery drops while held" this feature exists to stop. Rounding up
    /// charges a few points and then holds on wall power with nothing taken from the
    /// battery. Above the top real step it's no limit at all, which macOS holds at full.
    ///
    /// The hold wins over the limit, as it does in the tick's own decision: a limit below
    /// the held level is a setpoint too, and would drain the battery down to it.
    public static func target(holdAnchor: Int?, limit: Int?, in steps: [Int]) -> Int? {
        guard let anchor = holdAnchor else { return limit.flatMap { step(for: $0, in: steps) } }
        guard let up = steps.first(where: { $0 >= anchor }), up != steps.last else { return nil }
        return up
    }

    /// The step to enforce for `target`, or nil for "no limit".
    ///
    /// The highest step at or below the target, so the battery never ends up fuller than
    /// asked. Below the floor it's the floor: the lowest this Mac can hold at all, and the
    /// app says so wherever that happens. At or above the top step there's nothing to
    /// enforce.
    public static func step(for target: Int, in steps: [Int]) -> Int? {
        guard let floor = steps.first, let top = steps.last else { return nil }
        if target >= top { return nil }
        return steps.last { $0 <= target } ?? floor
    }
}

/// Which native limit eWiz set, so it only ever turns off a limit it turned on.
///
/// On disk rather than in memory: the helper restarts on every update, and a daemon that
/// forgot it owned the limit would leave the Mac stopping at 80% after the user had
/// switched eWiz's limit off. And one the user set in System Settings is theirs.
public enum NativeChargeLimitOwnership {
    static let file = EWizPaths.configDirectory.appendingPathComponent("native-limit")

    public static func load() -> Int? {
        guard let s = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public static func save(_ limit: Int?) {
        guard let limit else { try? FileManager.default.removeItem(at: file); return }
        try? FileManager.default.createDirectory(at: EWizPaths.configDirectory,
                                                 withIntermediateDirectories: true)
        try? "\(limit)\n".write(to: file, atomically: true, encoding: .utf8)
    }
}
