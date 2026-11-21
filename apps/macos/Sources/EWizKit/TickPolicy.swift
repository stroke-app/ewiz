import Foundation

/// How often the helper's enforcement loop should run.
///
/// The loop exists to make charging decisions, and those only mean anything while
/// current is flowing in. Once the lid is shut on battery there is nothing to decide:
/// the charge limit and the heat cap have nothing to act on, and the MagSafe LED has
/// no adapter to report. The machine is asleep, so the only moment a tick can run at
/// all is inside one of macOS's hourly maintenance dark wakes — and there, the config
/// read, the IOKit walk and the SMC probes are pure cost. They keep the SoC busy in
/// precisely the window that should end as fast as possible.
///
/// So the loop backs off to a minute in that state. A typical 35-second dark wake then
/// sees at most one pass instead of three or four.
public enum TickPolicy {
    /// Cadence while something needs managing — charging has to react within seconds.
    public static let active = 10.0
    /// Cadence while the Mac is closed and on battery.
    public static let idle = 60.0

    /// Anything that still has to react with the lid shut keeps the fast tick: keep-awake's
    /// task gating, a discharge run, a schedule boundary, a ready-by top-up, a calibration,
    /// or a pause that has to expire on time.
    public static func hasNothingToManage(_ cfg: EWizConfig, onExternalPower: Bool) -> Bool {
        if onExternalPower { return false }
        return !cfg.keepAwake
            && !cfg.dischargeEnabled
            && !cfg.calibrateToFull
            && !cfg.readyBy.enabled
            && cfg.pauseUntil == nil
            && cfg.schedules.isEmpty
    }

    public static func interval(_ cfg: EWizConfig,
                                onExternalPower: Bool,
                                lidClosed: Bool) -> Double {
        lidClosed && hasNothingToManage(cfg, onExternalPower: onExternalPower) ? idle : active
    }
}
