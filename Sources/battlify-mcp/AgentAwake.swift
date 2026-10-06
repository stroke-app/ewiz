import Foundation
import IOKit.pwr_mgt
import BattlifyKit

/// What a tool call hands back: prose for the model, the same facts as data, and whether
/// it failed. Failures are tool results rather than protocol errors so the agent can read
/// them and adjust.
struct ToolResult {
    var text: String
    var data: [String: Any] = [:]
    var isError = false
}

/// The keep-awake an agent holds through this server.
///
/// Two levers. The idle hold is a power assertion owned by this process: it carries its own
/// timeout and dies with the process, so a crashed or abandoned agent can't strand the Mac
/// awake. The lid hold is the user's "Always Active" switch on a timer (see `AgentLidHold`),
/// which needs the helper and outlives this process, so it's released on shutdown too.
///
/// Called from the request loop and from the signal handler, hence the lock.
final class AgentAwake: @unchecked Sendable {
    private let lock = NSLock()
    private var assertion: IOPMAssertionID = 0
    private var idleUntil: Date?
    private var idleReason: String?
    private var lidLease: AgentLidHold.Lease?

    static let maxMinutes = 720

    // MARK: - Tools

    func status() -> ToolResult {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        var data: [String: Any] = ["battery": batteryData()]
        var lines = [batteryLine()]

        let idleActive = idleUntil.map { $0 > now } ?? false
        data["idle_hold"] = idleActive
            ? ["active": true, "expires_at": iso(idleUntil!), "minutes_left": minutesLeft(idleUntil!, now),
               "reason": idleReason ?? ""] as [String: Any]
            : ["active": false]
        lines.append(idleActive
                     ? "Idle hold (this agent): on, \(minutesLeft(idleUntil!, now)) min left."
                     : "Idle hold (this agent): off.")

        do {
            let cfg = try ControlClient.send(.getStatus).config
            data["helper_reachable"] = true
            let lid = lidData(cfg, now: now)
            data["lid_hold"] = lid.data
            lines.append(lid.line)
        } catch {
            data["helper_reachable"] = false
            lines.append("Lid hold: unknown, the Battlify helper isn't answering (\(error)).")
        }
        return ToolResult(text: lines.joined(separator: "\n"), data: data)
    }

    func keepAwake(minutes: Int, allowLidClosed: Bool, onBattery: Bool?, reason: String) -> ToolResult {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let until = AgentLidHold.deadline(minutes: minutes, from: now)

        guard takeAssertion(until: until, now: now, reason: reason) else {
            return ToolResult(text: "macOS refused the power assertion; nothing is being held.",
                              isError: true)
        }
        var lines = ["Idle sleep held for \(minutes) min (until \(clock(until))). "
                     + "Call battlify_keep_awake again before then to extend, and "
                     + "battlify_release_awake when the work is done."]
        var data: [String: Any] = ["idle_hold": ["active": true, "expires_at": iso(until)]]

        guard allowLidClosed else {
            lines.append("The lid hold is not on: closing the lid will still sleep the Mac. "
                         + "Pass allow_lid_closed: true if the work must survive a closed lid.")
            return ToolResult(text: lines.joined(separator: "\n"), data: data)
        }

        let cfg: BattlifyConfig
        do { cfg = try ControlClient.send(.getStatus).config } catch {
            lines.append("Lid hold NOT taken: the Battlify helper isn't answering (\(error)). "
                         + "Closing the lid will sleep the Mac.")
            data["lid_hold"] = ["active": false, "error": "\(error)"]
            return ToolResult(text: lines.joined(separator: "\n"), data: data, isError: true)
        }

        switch AgentLidHold.plan(config: cfg, current: lidLease, wanted: until,
                                 onBattery: onBattery, now: now) {
        case .coveredByUser:
            lines.append("Lid hold: the user's own Always Active is already on with no timer, "
                         + "so it covers this. Left as it is.")
            data["lid_hold"] = ["active": true, "owner": "user"]
        case .coveredUntil(let userUntil):
            lines.append("Lid hold: the user's own Always Active timer already runs until "
                         + "\(clock(userUntil)), past what you asked for. Left as it is.")
            data["lid_hold"] = ["active": true, "owner": "user", "expires_at": iso(userUntil)]
        case .write(let next, let lease):
            do {
                let response = try ControlClient.send(.setConfig(next))
                guard response.ok, AgentLidHold.owns(lease, in: response.config) else {
                    throw ControlError.ioError(response.message ?? "the helper didn't keep the change")
                }
                lidLease = lease
                let lid = lidData(response.config, now: now)
                lines.append(lid.line)
                data["lid_hold"] = lid.data
            } catch {
                lines.append("Lid hold NOT taken: \(error). Closing the lid will sleep the Mac.")
                data["lid_hold"] = ["active": false, "error": "\(error)"]
                return ToolResult(text: lines.joined(separator: "\n"), data: data, isError: true)
            }
        }
        return ToolResult(text: lines.joined(separator: "\n"), data: data)
    }

    func release() -> ToolResult {
        lock.lock(); defer { lock.unlock() }
        var lines: [String] = []
        lines.append(dropAssertion() ? "Idle hold released." : "No idle hold was on.")
        do {
            let outcome = try releaseLid()
            lines.append(outcome)
        } catch {
            lines.append("Lid hold: couldn't reach the Battlify helper (\(error)). "
                         + "Any lid hold this agent took still ends at its deadline.")
            return ToolResult(text: lines.joined(separator: "\n"), isError: true)
        }
        return ToolResult(text: lines.joined(separator: "\n"))
    }

    /// Everything this agent holds, dropped on the way out. Best effort: the assertion goes
    /// with the process anyway, and a lid hold that can't be released still has a deadline.
    func shutdown() {
        lock.lock(); defer { lock.unlock() }
        _ = dropAssertion()
        if lidLease != nil { _ = try? releaseLid() }
    }

    // MARK: - Levers (caller holds `lock`)

    private func takeAssertion(until: Date, now: Date, reason: String) -> Bool {
        let props: [String: Any] = [
            kIOPMAssertionTypeKey: kIOPMAssertPreventUserIdleSystemSleep,
            kIOPMAssertionLevelKey: NSNumber(value: kIOPMAssertionLevelOn),
            kIOPMAssertionNameKey: "Battlify MCP: \(reason)",
            kIOPMAssertionTimeoutKey: NSNumber(value: max(1, Int(until.timeIntervalSince(now).rounded()))),
            kIOPMAssertionTimeoutActionKey: kIOPMAssertionTimeoutActionRelease,
        ]
        var id: IOPMAssertionID = 0
        guard IOPMAssertionCreateWithProperties(props as CFDictionary, &id) == kIOReturnSuccess else {
            return false
        }
        // The new one first, so a renewal never leaves a gap with nothing held.
        if assertion != 0 { IOPMAssertionRelease(assertion) }
        assertion = id
        idleUntil = until
        idleReason = reason
        return true
    }

    private func dropAssertion() -> Bool {
        let wasOn = idleUntil.map { $0 > Date() } ?? false
        if assertion != 0 { IOPMAssertionRelease(assertion) }
        assertion = 0
        idleUntil = nil
        idleReason = nil
        return wasOn
    }

    private func releaseLid() throws -> String {
        guard let lease = lidLease else { return "No lid hold was taken by this agent." }
        let cfg = try ControlClient.send(.getStatus).config
        guard let next = AgentLidHold.release(config: cfg, lease: lease, now: Date()) else {
            lidLease = nil
            return "Lid hold: already ended or changed by the user since; left as it is."
        }
        let response = try ControlClient.send(.setConfig(next))
        guard response.ok else { throw ControlError.ioError(response.message ?? "refused") }
        lidLease = nil
        return next.keepAwake
            ? "Lid hold released; the user's own timer (until \(clock(next.keepAwakeUntil!))) is back in charge."
            : "Lid hold released; closing the lid will sleep the Mac again."
    }

    // MARK: - Reporting

    private func lidData(_ cfg: BattlifyConfig, now: Date) -> (data: [String: Any], line: String) {
        let armed = cfg.keepAwakeArmed(at: now)
        let ours = AgentLidHold.owns(lidLease, in: cfg)
        var data: [String: Any] = [
            "on": cfg.keepAwake,
            "owner": cfg.keepAwake ? (ours ? "agent" : "user") : "none",
            "user_indefinite": cfg.keepAwake && cfg.keepAwakeUntil == nil,
            "holds_on_battery": cfg.keepAwakeOnBattery,
        ]
        if let until = cfg.keepAwakeUntil { data["expires_at"] = iso(until) }

        guard cfg.keepAwake else { return (data, "Lid hold: off. Closing the lid sleeps the Mac.") }
        var line = "Lid hold: on (\(ours ? "this agent" : "the user's Always Active")"
        line += cfg.keepAwakeUntil.map { ", until \(clock($0)))." } ?? ", no timer)."

        // The switch being on isn't the same as the lid being held. Say what stands between.
        var caveats: [String] = []
        if !armed { caveats.append("outside the user's Always Active schedule, so not holding right now") }
        if cfg.keepAwakeRequiresTask {
            caveats.append("the user has it task-gated: it holds only while a watched process is busy")
        }
        if !cfg.keepAwakeOnBattery {
            caveats.append("AC power only: it lets go if the Mac is unplugged (pass on_battery: true to change that)")
        }
        if cfg.keepAwakeMaxTempC > 0 {
            caveats.append("lets go above \(Int(cfg.keepAwakeMaxTempC))°C")
        }
        data["caveats"] = caveats
        if !caveats.isEmpty { line += " Note: " + caveats.joined(separator: "; ") + "." }
        return (data, line)
    }

    private func batteryData() -> [String: Any] {
        let b = BatteryMonitor.read()
        var data: [String: Any] = ["percent": b.percentage, "plugged_in": b.isPluggedIn,
                                   "charging": b.isCharging]
        if let m = b.timeToEmpty { data["minutes_to_empty"] = m }
        return data
    }

    private func batteryLine() -> String {
        let b = BatteryMonitor.read()
        let source = b.isCharging ? "charging" : b.isPluggedIn ? "plugged in, not charging" : "on battery"
        let eta = (!b.isPluggedIn ? b.timeToEmpty : nil).map { ", about \($0 / 60)h \($0 % 60)m left" } ?? ""
        return "Battery: \(b.percentage)%, \(source)\(eta)."
    }

    private func minutesLeft(_ until: Date, _ now: Date) -> Int {
        max(1, Int((until.timeIntervalSince(now) / 60).rounded()))
    }

    private func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }

    private func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
