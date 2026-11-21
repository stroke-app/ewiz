import Foundation
import EWizKit

/// The power-settings tools: what an agent can change on this Mac through the eWiz helper.
///
/// Each one is a single request the app's own controls already send, so the helper applies
/// it exactly as if the user had clicked, and the app shows the change at its next poll.
/// All of them sit behind Settings › Automation › AI Agents › "Allow it to change power
/// settings" (`AgentAccess.allowsPowerControl`), read per call.
enum PowerTools {
    static let names: Set<String> = ["ewiz_set_low_power_mode", "ewiz_set_mode",
                                     "ewiz_set_charge_limit", "ewiz_pause_charging",
                                     "ewiz_resume_charging", "ewiz_set_sleep_setting"]

    static let denied = """
        The user hasn't allowed agents to change power settings on this Mac (eWiz › Settings › \
        Automation › AI Agents › Allow it to change power settings). Ask them to switch it on.
        """

    /// Agent-facing names for the eWiz modes. `SaveMode`'s raw values are internal.
    static let modes: [(name: String, mode: SaveMode)] = [
        ("extreme", .extremePerformance), ("normal", .normal),
        ("super_saver", .superSaver), ("off", .off),
    ]

    /// Agent-facing names for the pmset features eWiz manages.
    static let sleepSettings: [(name: String, toggle: PowerToggle)] = [
        ("power_nap", .powerNap), ("wake_on_network", .wakeOnNetwork),
        ("tcp_keep_alive", .tcpKeepAlive), ("dim_on_battery", .dimOnBattery),
        ("proximity_wake", .proximityWake), ("terminal_keeps_awake", .ttysKeepAwake),
    ]

    private static var writeHints: [String: Any] { [
        "readOnlyHint": false, "destructiveHint": false, "idempotentHint": true, "openWorldHint": false,
    ] }

    static var tools: [[String: Any]] { [
        [
            "name": "ewiz_set_low_power_mode",
            "title": "Low Power Mode",
            "description": "Turn macOS Low Power Mode on or off. It stays as set until changed again.",
            "inputSchema": object(["enabled": ["type": "boolean"]], required: ["enabled"]),
            "annotations": writeHints,
        ],
        [
            "name": "ewiz_set_mode",
            "title": "eWiz power mode",
            "description": """
                Apply an eWiz preset. extreme: High Power Mode where the Mac has it and every \
                saving off, for maximum speed. normal: balanced. super_saver: Low Power Mode and \
                every battery saving on. off: eWiz stops managing modes. Use it when the user \
                asks for a heavy job to run as fast as possible, or for the battery to last.
                """,
            "inputSchema": object(["mode": ["type": "string", "enum": modes.map(\.name)]],
                                  required: ["mode"]),
            "annotations": writeHints,
        ],
        [
            "name": "ewiz_set_charge_limit",
            "title": "Charge limit",
            "description": """
                Set the battery charge limit (20–100%) and/or turn limiting on or off. Pass at \
                least one of percent and enabled. Macs that limit through macOS's own setting \
                only offer certain steps (often 80, 85, 90, 95, 100); the answer says what was \
                actually applied. Only change it when the user asks, e.g. "charge to 100% for \
                travel".
                """,
            "inputSchema": object([
                "percent": ["type": "integer", "minimum": 20, "maximum": 100],
                "enabled": ["type": "boolean", "description": "Whether the limit is enforced."],
            ], required: []),
            "annotations": writeHints,
        ],
        [
            "name": "ewiz_pause_charging",
            "title": "Pause charging",
            "description": """
                Stop charging the battery while plugged in, for `minutes` or, if omitted, until \
                ewiz_resume_charging. Useful to keep heat down during a long heavy job.
                """,
            "inputSchema": object(["minutes": ["type": "integer", "minimum": 1, "maximum": 1440]],
                                  required: []),
            "annotations": writeHints,
        ],
        [
            "name": "ewiz_resume_charging",
            "title": "Resume charging",
            "description": "End a charging pause now. The charge limit still applies.",
            "inputSchema": object([:], required: []),
            "annotations": writeHints,
        ],
        [
            "name": "ewiz_set_sleep_setting",
            "title": "Sleep setting",
            "description": """
                Turn one of macOS's sleep and battery features on or off. power_nap: wakes in \
                sleep to sync. wake_on_network: other devices can wake the Mac. tcp_keep_alive: \
                network stays up in sleep (Find My, push). dim_on_battery: slightly dimmer \
                display unplugged. proximity_wake: a nearby iPhone or Watch wakes the Mac. \
                terminal_keeps_awake: open terminal/SSH sessions block sleep.
                """,
            "inputSchema": object([
                "setting": ["type": "string", "enum": sleepSettings.map(\.name)],
                "enabled": ["type": "boolean"],
            ], required: ["setting", "enabled"]),
            "annotations": writeHints,
        ],
    ] }

    private static func object(_ properties: [String: Any], required: [String]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": required, "additionalProperties": false]
    }

    // MARK: - Calls

    static func call(_ name: String, _ args: [String: Any],
                     send: (ControlRequest) throws -> ControlResponse = { try ControlClient.send($0) }) -> ToolResult {
        guard AgentAccess.allowsPowerControl else { return ToolResult(text: denied, isError: true) }
        switch name {
        case "ewiz_set_low_power_mode":
            guard let on = args["enabled"] as? Bool else { return invalid("enabled must be true or false.") }
            return run(.setLowPowerMode(on), send) { r in
                r.lowPowerModeEnabled == on
                    ? "Low Power Mode is \(on ? "on" : "off")."
                    : "Asked for Low Power Mode \(on ? "on" : "off"), but macOS reports it \(r.lowPowerModeEnabled ? "on" : "off")."
            }
        case "ewiz_set_mode":
            guard let raw = args["mode"] as? String, let mode = modes.first(where: { $0.name == raw })?.mode else {
                return invalid("mode must be one of \(modes.map(\.name).joined(separator: ", ")).")
            }
            return run(.applyMode(mode), send) { r in
                "Mode set to \(mode.title). Low Power Mode \(onOff(r.lowPowerModeEnabled))"
                    + (r.highPowerModeSupported ? ", High Power Mode \(onOff(r.highPowerModeEnabled))." : ".")
            }
        case "ewiz_set_charge_limit":
            return setChargeLimit(args, send)
        case "ewiz_pause_charging":
            var minutes = -1
            if args["minutes"] != nil {
                guard let m = wholeNumber(args["minutes"], in: 1...1440) else {
                    return invalid("minutes must be a whole number from 1 to 1440, or omitted.")
                }
                minutes = m
            }
            return run(.pauseCharging(minutes), send) { _ in
                minutes > 0 ? "Charging paused for \(minutes) min." : "Charging paused until resumed."
            }
        case "ewiz_resume_charging":
            return run(.pauseCharging(0), send) { _ in "Charging resumed; the charge limit still applies." }
        case "ewiz_set_sleep_setting":
            guard let raw = args["setting"] as? String,
                  let toggle = sleepSettings.first(where: { $0.name == raw })?.toggle else {
                return invalid("setting must be one of \(sleepSettings.map(\.name).joined(separator: ", ")).")
            }
            guard let on = args["enabled"] as? Bool else { return invalid("enabled must be true or false.") }
            return run(.setPowerToggle(toggle, on), send) { r in
                let now = r.powerToggles[toggle.rawValue]
                return now == nil || now == on
                    ? "\(toggle.title): \(onOff(on))."
                    : "Asked for \(toggle.title) \(onOff(on)), but macOS reports it \(onOff(now!))."
            }
        default:
            return invalid("Unknown tool \(name).")
        }
    }

    private static func setChargeLimit(_ args: [String: Any],
                                       _ send: (ControlRequest) throws -> ControlResponse) -> ToolResult {
        let enabled = args["enabled"] as? Bool
        if args["enabled"] != nil, enabled == nil { return invalid("enabled must be true or false.") }
        var percent: Int?
        if args["percent"] != nil {
            guard let p = wholeNumber(args["percent"], in: 20...100) else {
                return invalid("percent must be a whole number from 20 to 100.")
            }
            percent = p
        }
        guard percent != nil || enabled != nil else { return invalid("Pass percent, enabled, or both.") }

        // Read, change two fields, write back: the same merge the app does, so nothing else
        // in the config is touched.
        let current: ControlResponse
        do { current = try send(.getStatus) } catch { return unreachable(error) }
        var cfg = current.config
        if let percent { cfg.chargeLimit = percent }
        if let enabled { cfg.chargeLimitEnabled = enabled }
        return run(.setConfig(cfg), send) { r in
            guard r.config.chargeLimitEnabled else { return "Charge limit is off; the battery charges to 100%." }
            var line = "Charge limit on at \(r.config.chargeLimit)%."
            if let applied = r.nativeLimitApplied, applied != r.config.chargeLimit {
                line += " This Mac limits through macOS, which applies \(applied)%"
                    + (r.nativeLimitSteps.isEmpty ? "." : " (steps: \(r.nativeLimitSteps.map(String.init).joined(separator: ", "))).")
            }
            return line
        }
    }

    // MARK: - Status

    /// Power state for ewiz_status, from the getStatus answer it already fetched.
    static func status(_ r: ControlResponse) -> (lines: [String], data: [String: Any]) {
        let cfg = r.config
        var lines = [
            "Charge limit: " + (cfg.chargeLimitEnabled ? "\(r.nativeLimitApplied ?? cfg.chargeLimit)%." : "off."),
            "Charging: " + (r.chargingEnabled && !r.discharging && r.pauseReason == nil
                            ? "allowed." : "held" + (r.pauseReason.map { " (\($0))" } ?? "") + "."),
            "Mode: \(cfg.mode.title). Low Power Mode \(onOff(r.lowPowerModeEnabled))"
                + (r.highPowerModeSupported ? ", High Power Mode \(onOff(r.highPowerModeEnabled))." : "."),
        ]
        let settings = sleepSettings.compactMap { s in r.powerToggles[s.toggle.rawValue].map { (s.name, $0) } }
        if !settings.isEmpty {
            lines.append("Sleep settings: " + settings.map { "\($0.0) \(onOff($0.1))" }.joined(separator: ", ") + ".")
        }
        let hottest = r.sensors.max { $0.celsius < $1.celsius }
        if let hottest { lines.append("Hottest sensor: \(hottest.name) \(Int(hottest.celsius.rounded()))°C.") }

        var data: [String: Any] = [
            "charge_limit": ["enabled": cfg.chargeLimitEnabled, "percent": cfg.chargeLimit,
                             "applied_percent": r.nativeLimitApplied as Any? ?? NSNull()],
            "charging_allowed": r.chargingEnabled && !r.discharging && r.pauseReason == nil,
            "pause_reason": r.pauseReason as Any? ?? NSNull(),
            "mode": modes.first { $0.mode == cfg.mode }?.name ?? "off",
            "low_power_mode": r.lowPowerModeEnabled,
            "sleep_settings": Dictionary(uniqueKeysWithValues: settings),
        ]
        if r.highPowerModeSupported { data["high_power_mode"] = r.highPowerModeEnabled }
        if let hottest { data["hottest_sensor"] = ["name": hottest.name, "celsius": hottest.celsius] }
        if !AgentAccess.allowsPowerControl {
            lines.append("Changing power settings: not allowed by the user.")
        }
        return (lines, data)
    }

    // MARK: - Helpers

    private static func run(_ request: ControlRequest,
                            _ send: (ControlRequest) throws -> ControlResponse,
                            describe: (ControlResponse) -> String) -> ToolResult {
        do {
            let r = try send(request)
            guard r.ok else {
                return ToolResult(text: "The eWiz helper refused: \(r.message ?? "no reason given").", isError: true)
            }
            return ToolResult(text: describe(r))
        } catch {
            return unreachable(error)
        }
    }

    private static func unreachable(_ error: Error) -> ToolResult {
        ToolResult(text: "The eWiz helper isn't answering (\(error)). Is eWiz installed with its helper?",
                   isError: true)
    }

    private static func invalid(_ text: String) -> ToolResult { ToolResult(text: text, isError: true) }

    static func onOff(_ on: Bool) -> String { on ? "on" : "off" }

    /// A JSON integer within `range`. JSON numbers arrive as NSNumber, and Swift bridges
    /// NSNumber 1 to Bool, so booleans are ruled out by CF type; 30.0 passes, 30.5 doesn't.
    static func wholeNumber(_ value: Any?, in range: ClosedRange<Int>) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue == number.doubleValue.rounded(),
              range.contains(number.intValue) else { return nil }
        return number.intValue
    }
}
