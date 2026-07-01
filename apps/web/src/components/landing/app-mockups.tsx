import {
  BatteryChargingIcon,
  ChevronDownIcon,
  InfoIcon,
  MonitorIcon,
  MoonIcon,
  MoonStarIcon,
  PauseIcon,
  PowerIcon,
  RotateCwIcon,
  SettingsIcon,
  SparklesIcon,
  SunDimIcon,
  ZapIcon,
} from "lucide-react";

import { cn } from "#/lib/utils";

function Toggle({ on }: { on: boolean }) {
  return <span className={cn("aw-toggle", !on && "off")} aria-hidden />;
}

/* A small filled battery glyph for the popover header. */
function BattGlyph() {
  return (
    <svg viewBox="0 0 30 15" fill="none" aria-hidden>
      <rect
        x="0.6"
        y="0.6"
        width="25"
        height="13.8"
        rx="3"
        stroke="currentColor"
        strokeWidth="1.2"
      />
      <rect x="2.4" y="2.4" width="17" height="10.2" rx="1.6" fill="currentColor" />
      <rect x="27" y="4.6" width="2.4" height="5.8" rx="1.2" fill="currentColor" />
    </svg>
  );
}

/** The menu-bar popover — the app's home screen, recreated for the hero. */
export function MenuPopover() {
  return (
    <div className="appwin" role="img" aria-label="Battlify menu-bar popover">
      <div className="aw-top">
        <span className="aw-batt">
          <BattGlyph />
          <span className="aw-pct">
            67<span>%</span>
          </span>
        </span>
        <span className="aw-meta">
          On battery
          <br />
          3h 15m left
        </span>
      </div>
      <div className="aw-track">
        <i style={{ width: "67%" }} />
        <u style={{ left: "80%" }} />
      </div>
      <div className="aw-cap">Limit 80%</div>

      <div className="divider" />

      <div className="aw-trial">
        <SparklesIcon />
        <span className="tx">
          <b>Trial — 28 free days left</b>
          <p>Activate any time to unlock permanently.</p>
        </span>
        <span className="go">Activate</span>
      </div>

      <div className="divider" />

      <div className="aw-label">Save mode</div>
      <div className="aw-seg">
        <span>Off</span>
        <span className="on">Normal</span>
        <span>Super Saver</span>
      </div>
      <p className="aw-desc">
        Charge limit 80%, pause when warm, Power Nap off. Find My stays active.
      </p>

      <div className="divider" />

      <div className="aw-label">
        <BatteryChargingIcon /> Charge limit
      </div>
      <div className="aw-row">
        <span className="rl">
          <PauseIcon /> Pause charging…
        </span>
        <ChevronDownIcon className="opacity-50" style={{ width: 15, height: 15 }} />
      </div>
      <div className="aw-row">
        <span className="rl">Limit charging</span>
        <Toggle on />
      </div>
      <div className="aw-row">
        <span className="rl">Stop at</span>
        <b>80%</b>
      </div>
      <div className="aw-ticks">
        <div className="bar">
          {Array.from({ length: 11 }).map((_, i) => (
            <span key={i} />
          ))}
        </div>
        <div className="knob" />
      </div>
      <div className="aw-row muted">
        <span className="rl">
          <ZapIcon /> Charge to 100% once
        </span>
      </div>

      <div className="divider" />

      <div className="aw-label">Quick actions</div>
      <div className="aw-actions">
        <span className="aw-act">
          <SunDimIcon />
          Dim
        </span>
        <span className="aw-act">
          <MonitorIcon />
          Display Off
        </span>
        <span className="aw-act">
          <MoonIcon />
          Sleep
        </span>
      </div>

      <div className="divider" />

      <div className="aw-foot">
        <span>Settings…</span>
        <span>Details…</span>
        <span>History…</span>
        <RotateCwIcon className="sp" />
        <PowerIcon />
      </div>
    </div>
  );
}

/* --- Settings window --- */

function Row({
  title,
  desc,
  on,
  sub,
  right,
}: {
  title: string;
  desc?: string;
  on?: boolean;
  sub?: boolean;
  right?: React.ReactNode;
}) {
  return (
    <div className={cn("mw-item", sub && "sub")}>
      <span className="it">
        <h6>{title}</h6>
        {desc ? <p>{desc}</p> : null}
      </span>
      {right ?? <Toggle on={!!on} />}
    </div>
  );
}

/** The macOS Settings window — proves the depth of control. */
export function SettingsWindow({ tab }: { tab: "charging" | "sleep" }) {
  return (
    <div className="macwin" role="img" aria-label={`Battlify settings — ${tab}`}>
      <div className="mw-bar">
        <span className="mw-lights">
          <i className="r" />
          <i className="y" />
          <i className="g" />
        </span>
        <span className="mw-title">Battlify Settings</span>
      </div>
      <div className="mw-tabs">
        <span className={cn("mw-tab", tab === "charging" && "on")}>
          <BatteryChargingIcon />
          Charging
        </span>
        <span className={cn("mw-tab", tab === "sleep" && "on")}>
          <MoonStarIcon />
          Sleep &amp; Power
        </span>
        <span className="mw-tab">
          <SettingsIcon />
          General
        </span>
        <span className="mw-tab">
          <InfoIcon />
          About
        </span>
      </div>

      {tab === "charging" ? (
        <div className="mw-body">
          <div className="mw-group">Enforcement</div>
          <div className="mw-card">
            <Row
              title="Stop charging before sleep"
              desc="Cuts charging as the Mac sleeps so it can't top up past the limit."
              on={false}
            />
            <Row
              title="Prevent idle sleep while plugged in"
              desc="Keeps the Mac awake on power so the limit is always enforced."
              on={false}
            />
          </div>

          <div className="mw-group">Heat</div>
          <div className="mw-card">
            <Row
              title="Pause charging when hot"
              desc="Stops charging when the battery runs warm to reduce wear."
              on
            />
            <Row title="Max temperature" right={<span className="mw-step">35 °C</span>} />
          </div>

          <div className="mw-group">Discharge</div>
          <div className="mw-card">
            <Row
              title="Discharge to limit"
              desc="If you plug in above the limit, run off battery until it drops back down."
              on={false}
            />
          </div>

          <div className="mw-group">MagSafe LED</div>
          <div className="mw-card">
            <div className="mw-item" style={{ display: "block" }}>
              <div className="mw-seg">
                <span>Auto</span>
                <span className="on">Status</span>
                <span>Off</span>
              </div>
              <p style={{ marginTop: 10 }}>
                Orange charging · green holding limit · off briefly after wake.
              </p>
            </div>
          </div>
        </div>
      ) : (
        <div className="mw-body">
          <div className="mw-group">When the lid closes</div>
          <div className="mw-card">
            <Row
              title="Super Save when lid closed"
              desc="Maximizes battery while closed, restores when you open it."
              on
            />
            <Row title="Turn off Wi-Fi" sub on={false} />
            <Row title="Turn off Bluetooth" sub on={false} />
            <Row title="Restore Wi-Fi & Bluetooth on wake" sub on />
          </div>

          <div className="mw-group">On battery</div>
          <div className="mw-card">
            <Row
              title="Slightly dim the display on battery"
              desc="Lowers brightness a little when unplugged to stretch battery life."
              on={false}
            />
          </div>

          <div className="mw-group">Wake while closed</div>
          <div className="mw-card">
            <Row
              title="Power Nap"
              desc="Wakes periodically while closed to sync Mail/iCloud."
              on={false}
            />
            <Row
              title="Wake for network access"
              desc="Lets other devices wake this Mac over the network."
              on={false}
            />
            <Row
              title="Keep network alive in sleep"
              desc="Keeps Find My & push active during sleep."
              on
            />
          </div>
        </div>
      )}
    </div>
  );
}

/** The "While Lid Was Closed" history card — the proof of 0.0%/hr drain. */
export function ClosedLidCard() {
  return (
    <div className="lidcard" role="img" aria-label="History: while lid was closed">
      <div className="h">While Lid Was Closed</div>
      <div className="lidrow">
        <span>
          <div className="l1">Closed Jul 1, 8:39 AM</div>
          <div className="l2">53% → 53% · 10h 54m</div>
        </span>
        <span>
          <div className="r1">no drop</div>
          <div className="r2">0.0%/hr</div>
        </span>
      </div>
      <div className="lidrow">
        <span>
          <div className="l1">Closed Jul 1, 12:48 AM</div>
          <div className="l2">45% → 45% · 7h 30m</div>
        </span>
        <span>
          <div className="r1">no drop</div>
          <div className="r2">0.0%/hr</div>
        </span>
      </div>
    </div>
  );
}
