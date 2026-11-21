/**
 * Faithful HTML replicas of the eWiz macOS app (dark appearance), built from
 * the SwiftUI sources: the menu bar panel, the Settings window and its tabs,
 * Battery History and Battery Details. Everything is laid out in macOS points
 * at 1x and scaled to fit by <Stage>.
 */
import { SiApple } from "@icons-pack/react-simple-icons";
import { useQuery } from "@tanstack/react-query";
import {
  ActivityIcon,
  BatteryChargingIcon,
  BatteryIcon,
  CheckIcon,
  ChevronRightIcon,
  ClockIcon,
  CoffeeIcon,
  CpuIcon,
  EllipsisIcon,
  EyeIcon,
  InfoIcon,
  KeyRoundIcon,
  LaptopIcon,
  LogOutIcon,
  MonitorIcon,
  MoonIcon,
  MoonStarIcon,
  PauseIcon,
  PlugIcon,
  PlusIcon,
  RotateCwIcon,
  SearchIcon,
  SettingsIcon,
  SlidersHorizontalIcon,
  SunDimIcon,
  SunIcon,
  WandSparklesIcon,
  WifiIcon,
  ZapIcon,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useEffect, useLayoutEffect, useRef, useState } from "react";

import { AppIcon } from "#/components/logo";
import { latestReleaseQueryOptions } from "#/lib/releases/queries";
import { cn } from "#/lib/utils";

const useIsoLayoutEffect = typeof window === "undefined" ? useEffect : useLayoutEffect;

/* ==========================================================================
   Stage: renders a fixed-size design and scales it to the container width,
   like a screenshot, so the replicas keep their exact macOS proportions.
   ========================================================================== */
export function Stage({
  width,
  height,
  className,
  children,
}: {
  width: number;
  height: number;
  className?: string;
  children: React.ReactNode;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState<number | null>(null);
  useIsoLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = () => setScale(el.clientWidth / width);
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [width]);
  return (
    <div
      ref={ref}
      className={cn("relative w-full overflow-hidden", className)}
      style={{ aspectRatio: `${width} / ${height}` }}
    >
      <div
        className="mac-ui absolute top-0 left-0 origin-top-left transition-opacity duration-300"
        style={{
          width,
          height,
          transform: `scale(${scale ?? 1})`,
          opacity: scale === null ? 0 : 1,
        }}
      >
        {children}
      </div>
    </div>
  );
}

/* ==========================================================================
   Controls
   ========================================================================== */
export function Toggle({
  on,
  onClick,
  label = "Toggle",
}: {
  on: boolean;
  onClick?: () => void;
  label?: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      tabIndex={-1}
      onClick={onClick}
      className={cn(
        "relative h-[18px] w-[32px] shrink-0 rounded-full transition-colors duration-200",
        on ? "bg-(--m-blue)" : "bg-[#4a4a4c]",
      )}
    >
      <span
        className={cn(
          "absolute top-[1px] left-[1px] size-[16px] rounded-full bg-[#dcdcdc] shadow-[0_1px_2px_rgb(0_0_0/0.35)] transition-transform duration-200",
          on && "translate-x-[14px]",
        )}
      />
    </button>
  );
}

function TickSlider({
  value,
  min,
  max,
  step,
  onChange,
}: {
  value: number;
  min: number;
  max: number;
  step: number;
  onChange?: (v: number) => void;
}) {
  const ticks = Math.round((max - min) / step) + 1;
  const pos = ((value - min) / (max - min)) * 100;
  return (
    <div className="relative h-[20px]">
      <div className="absolute inset-x-0 top-[9px] h-[3px] rounded-full bg-(--m-track)" />
      <div className="absolute inset-x-0 top-[13px] flex justify-between">
        {Array.from({ length: ticks }, (_, i) => (
          <span key={i} className="h-[5px] w-px bg-white/25" />
        ))}
      </div>
      <span
        className="absolute top-[1px] h-[18px] w-[9px] -translate-x-1/2 rounded-full bg-[#b9b9bb] shadow-[0_1px_2px_rgb(0_0_0/0.4)] transition-[left] duration-150"
        style={{ left: `${pos}%` }}
      />
      {onChange ? (
        <input
          type="range"
          min={min}
          max={max}
          step={step}
          value={value}
          onChange={(e) => onChange(Number(e.target.value))}
          aria-label="Stop at"
          tabIndex={-1}
          className="absolute inset-0 w-full cursor-pointer opacity-0"
        />
      ) : null}
    </div>
  );
}

function Segmented<T extends string>({
  options,
  value,
  onChange,
  className,
}: {
  options: readonly T[];
  value: T;
  onChange?: (v: T) => void;
  className?: string;
}) {
  return (
    <div className={cn("flex rounded-[8px] bg-white/[0.06] p-[2px]", className)}>
      {options.map((o) => (
        <button
          key={o}
          type="button"
          tabIndex={-1}
          onClick={() => onChange?.(o)}
          className={cn(
            "flex-1 rounded-[6px] py-[5px] text-[12px] transition-colors",
            o === value ? "bg-white/[0.14] font-semibold text-(--m-text)" : "text-(--m-text-2)",
          )}
        >
          {o}
        </button>
      ))}
    </div>
  );
}

function TrafficLights() {
  return (
    <span className="flex gap-[8px]">
      <span className="size-[12px] rounded-full bg-[#ff5f57] shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.25)]" />
      <span className="size-[12px] rounded-full bg-[#febc2e] shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.25)]" />
      <span className="size-[12px] rounded-full bg-[#28c840] shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.25)]" />
    </span>
  );
}

const WINDOW_SHADOW =
  "shadow-[0_0_0_0.5px_rgb(0_0_0/0.9),inset_0_0.5px_0_rgb(255_255_255/0.14),0_24px_70px_-12px_rgb(0_0_0/0.65),0_8px_20px_-6px_rgb(0_0_0/0.4)]";

export function MacWindow({
  title,
  width,
  height,
  className,
  style,
  children,
}: {
  title: string;
  width: number;
  height: number;
  className?: string;
  style?: React.CSSProperties;
  children: React.ReactNode;
}) {
  return (
    <div
      className={cn(
        "flex flex-col overflow-hidden rounded-[12px] bg-(--m-window)",
        WINDOW_SHADOW,
        className,
      )}
      style={{ width, height, ...style }}
    >
      <div className="relative flex h-[28px] shrink-0 items-center px-[13px]">
        <TrafficLights />
        <span className="absolute inset-x-0 text-center text-[13px] font-semibold text-(--m-text)/85">
          {title}
        </span>
      </div>
      {children}
    </div>
  );
}

/* ==========================================================================
   Menu bar icon styles (BatteryIconStyle.swift), drawn at 24pt.
   ========================================================================== */
export const ICON_STYLES = [
  "Rounded",
  "Bars",
  "Classic",
  "Minimal",
  "Pixel",
  "Upright",
  "Ring",
  "Meter",
  "Dot",
  "Wave",
  "Bolt",
  "Dial",
] as const;
export type IconStyle = (typeof ICON_STYLES)[number];

const BODY =
  "M2 12C2 9.17 2 7.76 2.88 6.88C3.76 6 5.17 6 8 6H13C15.83 6 17.24 6 18.12 6.88C19 7.76 19 9.17 19 12C19 14.83 19 16.24 18.12 17.12C17.24 18 15.83 18 13 18H8C5.17 18 3.76 18 2.88 17.12C2 16.24 2 14.83 2 12Z";
const NUB = "M19.6 9.6 20.6 9.8C21.6 10 22 10.6 22 12C22 13.4 21.6 14 20.6 14.2L19.6 14.4";

export function BatteryGlyph({
  style,
  level = 0.8,
  className,
}: {
  style: IconStyle;
  level?: number;
  className?: string;
}) {
  const s = { stroke: "currentColor", strokeWidth: 1.6, fill: "none" } as const;
  const f = { fill: "currentColor" } as const;
  const inner = (x: number, w: number, y = 8.6, h = 6.8, r = 1.6) => (
    <rect x={x} y={y} width={Math.max(0.01, w * level)} height={h} rx={r} {...f} />
  );
  let body: React.ReactNode;
  switch (style) {
    case "Rounded":
      body = (
        <>
          <path d={BODY} {...s} />
          <path d={NUB} {...s} strokeLinecap="round" />
          {inner(4.6, 11.8)}
        </>
      );
      break;
    case "Bars":
      body = (
        <>
          <path d={BODY} {...s} />
          <path d={NUB} {...s} strokeLinecap="round" />
          {[5, 9, 13].map((x, i) => (
            <rect
              key={x}
              x={x}
              y={9}
              width={2.6}
              height={6}
              rx={1.3}
              {...f}
              opacity={level * 3 > i ? 1 : 0.25}
            />
          ))}
        </>
      );
      break;
    case "Classic":
      body = (
        <>
          <rect x={2} y={6.5} width={17} height={11} rx={2.2} {...s} />
          <rect x={19.8} y={10} width={2} height={4} rx={0.8} {...f} />
          {inner(4, 13, 8.5, 7, 0.8)}
        </>
      );
      break;
    case "Minimal":
      body = (
        <>
          <rect x={2} y={7} width={20} height={10} rx={5} {...s} />
          {inner(4, 16, 9, 6, 3)}
        </>
      );
      break;
    case "Pixel":
      body = (
        <>
          <path d="M3 6h15v2h1v3h2v2h-2v3h-1v2H3v-2H2V8h1z" {...s} strokeWidth={1.8} />
          {[4.5, 7.5, 10.5, 13.5].map((x, i) => (
            <rect
              key={x}
              x={x}
              y={9}
              width={2.4}
              height={6}
              {...f}
              opacity={level * 4 > i ? 1 : 0.2}
            />
          ))}
        </>
      );
      break;
    case "Upright":
      body = (
        <>
          <rect x={6.5} y={4.5} width={11} height={17} rx={3} {...s} />
          <rect x={10} y={2.3} width={4} height={1.6} rx={0.8} {...f} />
          <rect x={8.5} y={6.5 + 13 * (1 - level)} width={7} height={13 * level} rx={1.4} {...f} />
        </>
      );
      break;
    case "Ring": {
      const c = 2 * Math.PI * 8;
      body = (
        <>
          <circle cx={12} cy={12} r={8} {...s} strokeWidth={2.6} opacity={0.25} />
          <circle
            cx={12}
            cy={12}
            r={8}
            {...s}
            strokeWidth={2.6}
            strokeDasharray={`${c * level} ${c}`}
            strokeLinecap="round"
            transform="rotate(-90 12 12)"
          />
        </>
      );
      break;
    }
    case "Meter":
      body = (
        <>
          {[0, 1, 2, 3].map((i) => (
            <rect
              key={i}
              x={3 + i * 5}
              y={16 - (i + 1) * 2.6}
              width={3.4}
              height={(i + 1) * 2.6 + 2}
              rx={1}
              {...f}
              opacity={level * 4 > i ? 1 : 0.25}
            />
          ))}
        </>
      );
      break;
    case "Dot":
      body = (
        <>
          <defs>
            <clipPath id="dotclip">
              <circle cx={12} cy={12} r={7} />
            </clipPath>
          </defs>
          <circle cx={12} cy={12} r={8.6} {...s} />
          <rect
            x={5}
            y={5 + 14 * (1 - level)}
            width={14}
            height={14}
            {...f}
            clipPath="url(#dotclip)"
          />
        </>
      );
      break;
    case "Wave":
      body = (
        <>
          <path d={BODY} {...s} />
          <path d={NUB} {...s} strokeLinecap="round" />
          <path
            d={`M4.6 11.2q2-1.6 4 0t4 0 3.8 0V15.4H4.6z`}
            {...f}
            transform={`translate(${-(1 - level) * 6} 0)`}
          />
        </>
      );
      break;
    case "Bolt":
      body = (
        <>
          <path d="M13.5 2.5 5.5 13.2h5.8L10 21.5l8.5-11h-5.9z" {...s} strokeLinejoin="round" />
          <path
            d="M13.5 2.5 5.5 13.2h5.8L10 21.5l8.5-11h-5.9z"
            {...f}
            opacity={0.95}
            style={{ clipPath: `inset(${(1 - level) * 100}% 0 0 0)` }}
          />
        </>
      );
      break;
    case "Dial": {
      const r = 8.5;
      const a = Math.PI * (1 - level);
      const hx = 12 + r * Math.cos(a);
      const hy = 16 - r * Math.sin(a);
      body = (
        <>
          <path
            d={`M3.5 16a${r} ${r} 0 0 1 17 0`}
            {...s}
            strokeWidth={2.4}
            opacity={0.25}
            strokeLinecap="round"
          />
          <path
            d={`M3.5 16A${r} ${r} 0 0 1 ${hx.toFixed(2)} ${hy.toFixed(2)}`}
            {...s}
            strokeWidth={2.4}
            strokeLinecap="round"
          />
          <circle cx={hx} cy={hy} r={2} {...f} />
        </>
      );
      break;
    }
  }
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden="true">
      {body}
    </svg>
  );
}

/* ==========================================================================
   macOS menu bar strip
   ========================================================================== */
export function MenuBarStrip({
  iconStyle,
  compact = false,
}: {
  iconStyle: IconStyle;
  compact?: boolean;
}) {
  return (
    <div className="flex h-[26px] items-center justify-between bg-black/30 px-[14px] text-[13px] text-white">
      <div className="flex items-center gap-[18px]">
        <SiApple className="size-[14px]" />
        {compact ? null : (
          <>
            <span className="font-bold">Finder</span>
            <span>File</span>
            <span>Edit</span>
            <span>View</span>
            <span>Go</span>
            <span>Window</span>
            <span>Help</span>
          </>
        )}
      </div>
      <div className="flex items-center gap-[14px]">
        {compact ? null : <WifiIcon className="size-[15px]" />}
        {compact ? null : <SearchIcon className="size-[14px]" />}
        <SlidersHorizontalIcon className="size-[14px]" />
        <span className="-mx-[5px] rounded-[5px] bg-white/25 px-[5px] py-[2px]">
          <BatteryGlyph style={iconStyle} className="size-[19px]" />
        </span>
        <span className="tabular-nums">{compact ? "9:41" : "Mon Oct 6  9:41 PM"}</span>
      </div>
    </div>
  );
}

/* ==========================================================================
   Menu bar panel (MenuContentView.swift), 320pt wide.
   ========================================================================== */
const MODES = ["Extreme", "Off", "Normal", "Super Saver"] as const;
type Mode = (typeof MODES)[number];

type Quick = "dim" | "off" | "rest" | "lid" | "awake";

export function MenuPopover({
  onOpen,
  className,
  style,
}: {
  onOpen?: (view: "settings" | "details" | "history") => void;
  className?: string;
  style?: React.CSSProperties;
}) {
  const level = 80;
  const [mode, setMode] = useState<Mode>("Normal");
  const [limitOn, setLimitOn] = useState(true);
  const [stopAt, setStopAt] = useState(80);
  const [dontCharge, setDontCharge] = useState(false);
  const [sealed, setSealed] = useState(true);
  const [wakeInstantly, setWakeInstantly] = useState(true);
  const [quick, setQuick] = useState<Quick | null>(null);

  const charging = limitOn ? stopAt > level && !dontCharge : !dontCharge && level < 100;
  const caption = charging ? "Charging · 1h 12m · 32.2 W" : "Plugged in, not charging";
  const note = dontCharge
    ? "Holding the level"
    : !limitOn
      ? "Charging to 100%"
      : charging
        ? `Charging to ${stopAt}%`
        : stopAt < level
          ? `Draining to ${stopAt}%`
          : `Holding at ${stopAt}%`;
  const status =
    quick === "awake"
      ? "Keeping awake · screen stays on · 45m left"
      : quick === "lid"
        ? "Lid mode · runs with the lid shut on power"
        : quick === "rest"
          ? "Resting · screen off, settings held"
          : "Sleeps as usual";

  const tiles: Array<{ id: Quick; label: string; icon: LucideIcon; alt?: [string, LucideIcon] }> = [
    { id: "dim", label: "Dim", icon: SunDimIcon, alt: ["Brighten", SunIcon] },
    { id: "off", label: "Off", icon: MonitorIcon },
    { id: "rest", label: "Rest", icon: MoonIcon, alt: ["Wake", SunIcon] },
    { id: "lid", label: "Lid", icon: LaptopIcon },
    { id: "awake", label: "Awake", icon: CoffeeIcon },
  ];

  const hair = <div className="my-[12px] h-px bg-(--m-line)" />;

  return (
    <div
      className={cn(
        "w-[320px] rounded-[14px] border border-white/[0.08] bg-(--m-popover)/[0.97] px-[16px] pt-[14px] pb-[12px] shadow-[0_24px_60px_-10px_rgb(0_0_0/0.7),0_0_0_0.5px_rgb(0_0_0/0.8)]",
        className,
      )}
      style={style}
    >
      {/* Header */}
      <div className="flex items-start justify-between">
        <span className="num leading-none font-semibold">
          <span className="text-[30px]">{level}</span>
          <span className="text-[15px] text-(--m-text-2)">%</span>
        </span>
        <span className="mt-[6px] text-[11px] text-(--m-text-2)">{caption}</span>
      </div>
      <div className="relative mt-[10px] h-[8px] rounded-full bg-(--m-track)">
        <div className="h-full rounded-full bg-(--m-green)" style={{ width: `${level}%` }} />
        {limitOn ? (
          <span
            className="absolute -top-[2px] h-[12px] w-[2px] rounded-full bg-white/70 transition-[left] duration-150"
            style={{ left: `${stopAt}%` }}
          />
        ) : null}
      </div>
      <p className="mt-[8px] text-[11px] text-(--m-text-2)">{note}</p>

      {hair}
      <Segmented options={MODES} value={mode} onChange={setMode} />
      {mode === "Extreme" ? (
        <p className="mt-[8px] text-[11px] leading-snug text-(--m-text-2)">
          Low Power Mode off, charging to 100%, no idle sleep, High Power Mode.
        </p>
      ) : null}

      {hair}
      <div className="flex items-center justify-between">
        <span className="text-[13px]">Limit charging</span>
        <span className="flex items-center gap-[10px]">
          <EllipsisIcon className="size-[15px] text-(--m-text-2)" />
          <Toggle on={limitOn} onClick={() => setLimitOn((v) => !v)} />
        </span>
      </div>
      <div className={cn("transition-opacity", !limitOn && "opacity-40")}>
        <div className="mt-[10px] flex items-center justify-between">
          <span className="text-[13px] text-(--m-text-2)">Stop at</span>
          <span className="num text-[13px] font-semibold">{stopAt}%</span>
        </div>
        <div className="mt-[6px]">
          <TickSlider
            value={stopAt}
            min={50}
            max={100}
            step={5}
            onChange={limitOn ? setStopAt : undefined}
          />
        </div>
      </div>
      <div className="mt-[10px] flex items-center justify-between">
        <span>
          <span className="block text-[13px]">Don&apos;t charge</span>
          {dontCharge ? (
            <span className="block text-[11px] text-(--m-text-2)">Holding the level</span>
          ) : null}
        </span>
        <Toggle on={dontCharge} onClick={() => setDontCharge((v) => !v)} />
      </div>

      {hair}
      <div className="flex items-center justify-between">
        <span className="text-[13px]">Sealed Sleep</span>
        <Toggle on={sealed} onClick={() => setSealed((v) => !v)} />
      </div>
      <div className="mt-[10px] flex items-center justify-between">
        <span className="text-[13px]">Wake instantly</span>
        <Toggle on={wakeInstantly} onClick={() => setWakeInstantly((v) => !v)} />
      </div>
      <p className="mt-[9px] flex items-center gap-[6px] text-[11px] text-(--m-text-2)">
        <CheckIcon className="size-[12px] text-(--m-good)" strokeWidth={2.5} />
        {sealed
          ? "Last close: 5h shut · 0% lost · hibernated"
          : "Last close: 5h shut · 3% lost · 0.6%/h"}
      </p>

      {hair}
      <div className="grid grid-cols-5 gap-[6px]">
        {tiles.map((t) => {
          const on = quick === t.id;
          const [label, Icon] = on && t.alt ? t.alt : [t.label, t.icon];
          const tint = t.id === "awake" ? "#f5c542" : t.id === "lid" ? "var(--m-blue-text)" : null;
          return (
            <button
              key={t.id}
              type="button"
              tabIndex={-1}
              onClick={() => setQuick(on ? null : t.id)}
              className={cn(
                "flex flex-col items-center gap-[5px] rounded-[8px] border py-[9px] transition-[transform,background-color] active:scale-[0.96]",
                on && tint
                  ? "border-current/30 bg-current/15"
                  : "border-white/[0.05] bg-white/[0.06] hover:bg-white/[0.1]",
              )}
              style={on && tint ? { color: tint } : undefined}
            >
              <Icon className={cn("size-[16px]", !(on && tint) && "text-(--m-text)/85")} />
              <span className={cn("text-[10px]", !(on && tint) && "text-(--m-text)/85")}>
                {label}
              </span>
            </button>
          );
        })}
      </div>
      <p className="mt-[9px] flex items-center gap-[6px] text-[11px] text-(--m-text-2)">
        <MoonIcon className="size-[12px]" />
        {status}
      </p>

      {hair}
      <div className="flex items-center justify-between text-[12px] text-(--m-text)/80">
        <span className="flex gap-[16px]">
          {(["settings", "details", "history"] as const).map((v) => (
            <button
              key={v}
              type="button"
              tabIndex={-1}
              onClick={() => onOpen?.(v)}
              className="capitalize transition-colors hover:text-(--m-text)"
            >
              {v}
            </button>
          ))}
        </span>
        <span className="flex gap-[14px] text-(--m-text-2)">
          <RotateCwIcon className="size-[15px]" />
          <LogOutIcon className="size-[15px]" />
        </span>
      </div>
    </div>
  );
}

/* ==========================================================================
   Settings window (SettingsView.swift), 580pt wide.
   ========================================================================== */
export type SettingsTab =
  | "Charging"
  | "Schedule"
  | "Automation"
  | "Sleep & Power"
  | "Shortcuts"
  | "General"
  | "About";

const TABS: Array<{ id: SettingsTab; icon: LucideIcon }> = [
  { id: "Charging", icon: BatteryChargingIcon },
  { id: "Schedule", icon: ClockIcon },
  { id: "Automation", icon: WandSparklesIcon },
  { id: "Sleep & Power", icon: MoonStarIcon },
  { id: "Shortcuts", icon: KeyRoundIcon },
  { id: "General", icon: SettingsIcon },
  { id: "About", icon: InfoIcon },
];

function SectionHeader({ children }: { children: React.ReactNode }) {
  return (
    <p className="mt-[22px] mb-[6px] px-[12px] text-[10px] font-semibold tracking-[0.07em] text-(--m-text-3) uppercase first:mt-[16px]">
      {children}
    </p>
  );
}

function Row({
  title,
  subtitle,
  right,
  icon,
}: {
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  right?: React.ReactNode;
  icon?: React.ReactNode;
}) {
  return (
    <div className="flex min-h-[34px] items-center gap-[10px] border-b border-(--m-sep) px-[12px] py-[9px] last:border-b-0">
      {icon}
      <div className="min-w-0 flex-1">
        <p className="text-[13px] text-(--m-text)">{title}</p>
        {subtitle ? (
          <p className="mt-[2px] text-[11px] leading-snug text-(--m-text-2)">{subtitle}</p>
        ) : null}
      </div>
      {right}
    </div>
  );
}

function Note({ icon: Icon, children }: { icon: LucideIcon; children: React.ReactNode }) {
  return (
    <div className="flex gap-[8px] border-b border-(--m-sep) px-[12px] py-[9px] text-[11px] leading-snug text-(--m-text)/80 last:border-b-0">
      <Icon className="mt-[1px] size-[12px] shrink-0 text-(--m-text-2)" />
      <span>{children}</span>
    </div>
  );
}

function useToggles(initial: Record<string, boolean>) {
  const [state, setState] = useState(initial);
  const t = (k: string) => (
    <Toggle on={state[k] ?? false} onClick={() => setState((s) => ({ ...s, [k]: !s[k] }))} />
  );
  return [state, t] as const;
}

function ChargingTab() {
  const [s, t] = useToggles({
    park: false,
    hold: true,
    beforeSleep: false,
    idle: true,
    active: false,
    heat: true,
    discharge: false,
  });
  return (
    <>
      <SectionHeader>Long-term care</SectionHeader>
      <Row
        title="Park the battery near 60%"
        subtitle="Charges up to it, runs down to it, then holds there on the adapter."
        right={t("park")}
      />
      {s.park ? (
        <Note icon={ActivityIcon}>
          On. You give up the top 40% day to day, so turn it off before a trip.
        </Note>
      ) : null}
      <SectionHeader>Hold</SectionHeader>
      <Row
        title="Don't charge while plugged in"
        subtitle="Stops charging and runs on wall power. macOS can only hold this Mac at 80, 85, 90, 95%, so it charges up to the next of those first, from 80% at the lowest."
        right={t("hold")}
      />
      {s.hold ? (
        <Note icon={PauseIcon}>
          Held. The battery stays around the level it was at when you switched this on, instead of
          climbing to full.
        </Note>
      ) : null}
      <SectionHeader>Enforcement</SectionHeader>
      <Row
        title="Stop charging before sleep"
        subtitle="Cuts charging at sleep even when no limit is set."
        right={t("beforeSleep")}
      />
      <Row
        title="Prevent idle sleep while plugged in"
        subtitle="Keeps the Mac awake on power so the limit holds."
        right={t("idle")}
      />
      <Row
        title="Always Active (keep awake with lid closed)"
        subtitle="Work keeps running with the lid shut. AC power only by default."
        right={t("active")}
      />
      <SectionHeader>Heat</SectionHeader>
      <Row
        title="Pause charging when hot"
        subtitle="Stops charging while the battery is warm."
        right={t("heat")}
      />
      {s.heat ? (
        <Row
          title="Max temperature"
          right={
            <span className="flex items-center gap-[8px]">
              <span className="num text-[13px]">40 °C</span>
              <span className="flex flex-col overflow-hidden rounded-[5px] bg-white/[0.1] text-[8px] leading-[9px] text-(--m-text-2)">
                <span className="px-[4px]">▲</span>
                <span className="px-[4px]">▼</span>
              </span>
            </span>
          }
        />
      ) : null}
      <SectionHeader>Discharge</SectionHeader>
      <Row
        title="Discharge to limit"
        subtitle="Runs off battery until it drops back to the limit."
        right={t("discharge")}
      />
    </>
  );
}

function ScheduleTab() {
  const [s, t] = useToggles({ overnight: true, commute: false, ready: true });
  const days = ["S", "M", "T", "W", "T", "F", "S"];
  return (
    <>
      <SectionHeader>Charging schedules</SectionHeader>
      <Row
        icon={<PauseIcon className="size-[15px] text-(--m-blue-text)" />}
        title="Overnight hold"
        subtitle="22:00–06:00 · Weekdays"
        right={
          <span className="flex items-center gap-[8px]">
            {t("overnight")}
            <ChevronRightIcon className="size-[13px] text-(--m-text-3)" />
          </span>
        }
      />
      <Row
        icon={<ZapIcon className="size-[15px] text-(--m-blue-text)" />}
        title="Top up before work"
        subtitle="07:00–08:30 · Weekdays"
        right={
          <span className="flex items-center gap-[8px]">
            {t("commute")}
            <ChevronRightIcon className="size-[13px] text-(--m-text-3)" />
          </span>
        }
      />
      <div className="px-[12px] pt-[8px]">
        <SmallButton>
          <PlusIcon className="size-[11px]" />
          Add Schedule
        </SmallButton>
      </div>
      <SectionHeader>Ready by</SectionHeader>
      <Row
        title="Charge to a target by a set time"
        subtitle="Holds overnight, then tops up to be ready on time."
        right={t("ready")}
      />
      {s.ready ? (
        <>
          <Row
            title="Ready by"
            right={
              <span className="rounded-[5px] bg-white/[0.1] px-[7px] py-[2px] text-[12px]">
                8:00 AM
              </span>
            }
          />
          <Row title="Charge to" right={<span className="num text-[13px]">90%</span>} />
          <Row
            title="On these days"
            right={
              <span className="flex gap-[4px]">
                {days.map((d, i) => (
                  <span
                    key={i}
                    className={cn(
                      "flex size-[22px] items-center justify-center rounded-full text-[10px] font-semibold",
                      i > 0 && i < 6
                        ? "bg-(--m-blue) text-white"
                        : "bg-white/[0.08] text-(--m-text-2)",
                    )}
                  >
                    {d}
                  </span>
                ))}
              </span>
            }
          />
        </>
      ) : null}
      <SectionHeader>Charge power</SectionHeader>
      <div className="px-[12px] py-[6px]">
        <div className="flex items-center justify-between">
          <span className="text-[13px]">Power to the battery</span>
          <span className="num text-[13px] font-semibold">60%</span>
        </div>
        <div className="mt-[8px]">
          <TickSlider value={60} min={0} max={100} step={10} />
        </div>
        <p className="mt-[6px] text-[11px] leading-snug text-(--m-text-2)">
          How much of the charger goes to the battery rather than to your Mac. Lower is cooler and
          slower; 0% holds the battery entirely.
        </p>
      </div>
    </>
  );
}

function SmallButton({ children }: { children: React.ReactNode }) {
  return (
    <span className="inline-flex items-center gap-[4px] rounded-[5px] bg-white/[0.12] px-[8px] py-[2px] text-[12px] shadow-[inset_0_0.5px_0_rgb(255_255_255/0.15)]">
      {children}
    </span>
  );
}

function AutomationTab() {
  const [, t] = useToggles({ dock: true, build: true, heavy: false });
  const rule = (key: string, icon: LucideIcon, title: string, caption: string, active: boolean) => {
    const Icon = icon;
    return (
      <Row
        icon={<Icon className="size-[17px] text-(--m-blue-text)" />}
        title={
          <span className="flex items-center gap-[6px]">
            {title}
            {active ? (
              <span className="rounded-full bg-(--m-green)/25 px-[6px] text-[9px] leading-[15px] font-bold text-(--m-green)">
                ACTIVE
              </span>
            ) : null}
          </span>
        }
        subtitle={caption}
        right={
          <span className="flex items-center gap-[8px]">
            {t(key)}
            <ChevronRightIcon className="size-[13px] text-(--m-text-3)" />
          </span>
        }
      />
    );
  };
  return (
    <>
      <SectionHeader>Rules</SectionHeader>
      {rule(
        "dock",
        BatteryIcon,
        "Docked at a display",
        "While external display connected 1 → Charge limit 80%",
        true,
      )}
      {rule(
        "build",
        EyeIcon,
        "Long build: stay awake",
        "While Xcode is running → Keep the Mac awake",
        true,
      )}
      {rule(
        "heavy",
        ZapIcon,
        "Heavy app: charge to full",
        "While Final Cut Pro is running → Charge limit 100%",
        false,
      )}
      <div className="flex items-center gap-[8px] px-[12px] pt-[8px]">
        <SmallButton>
          <PlusIcon className="size-[11px]" />
          Add Rule
        </SmallButton>
        <SmallButton>Start from an example ⌄</SmallButton>
      </div>
      <SectionHeader>Right now</SectionHeader>
      {[
        ["Power", "Charging · 82%"],
        ["External displays", "Studio Display"],
        ["Wi-Fi", "Home"],
        ["IP address", "192.168.1.24"],
        ["VPN", "Not connected"],
        ["Bluetooth", "AirPods Pro"],
        ["CPU", "12%"],
      ].map(([k, v]) => (
        <Row key={k} title={k} right={<span className="text-[12px] text-(--m-text-2)">{v}</span>} />
      ))}
      <AgentsSection />
    </>
  );
}

function AgentsSection() {
  const [s, t] = useToggles({ agents: true, lid: false });
  const [copied, setCopied] = useState(false);
  return (
    <>
      <SectionHeader>AI Agents</SectionHeader>
      <Row
        title="Let AI agents keep this Mac awake"
        subtitle="Claude, Cursor and other MCP apps can hold it awake through a long build, test run or download, on a timer that ends by itself."
        right={t("agents")}
      />
      {s.agents ? (
        <>
          <Row
            title="Allow it with the lid closed"
            subtitle="Turns on Always Active until the agent's timer runs out."
            right={t("lid")}
          />
          <Note icon={CoffeeIcon}>Keeping awake: Running the test suite · 42m left</Note>
          <Row
            title="Claude Desktop"
            subtitle="Connected."
            right={<CheckIcon className="size-[14px] text-(--m-good)" strokeWidth={2.6} />}
          />
          <Row
            title="Cursor"
            subtitle="Adds eWiz to its MCP servers."
            right={<SmallButton>Connect</SmallButton>}
          />
          <Row
            title="Claude Code"
            subtitle="Run this once in Terminal to add eWiz."
            right={
              <button type="button" tabIndex={-1} onClick={() => setCopied(true)}>
                <SmallButton>{copied ? "Copied" : "Copy Command"}</SmallButton>
              </button>
            }
          />
        </>
      ) : null}
    </>
  );
}

const LEAKS = [
  "Memory stays powered",
  "Deep sleep is switched off",
  "Terminal sessions block sleep",
  "Always Active holds on battery",
  "Network kept alive in sleep",
  "Power Nap",
  "Wake for network access",
  "Bluetooth stays on",
  "Wi-Fi stays on",
];

function SleepTab() {
  const [s, t] = useToggles({ sealed: true, instant: true, wifi: true, bt: true });
  return (
    <>
      <div className="mt-[14px] rounded-[10px] bg-white/[0.04] px-[12px] py-[10px]">
        <div className="flex items-center justify-between">
          <span>
            <span className="block text-[13px]">Sealed Sleep</span>
            <span
              className={cn(
                "block text-[11px]",
                s.sealed ? "text-(--m-good)" : "text-(--m-text-2)",
              )}
            >
              {s.sealed ? "Nothing can wake it" : "Ordinary macOS sleep"}
            </span>
          </span>
          {t("sealed")}
        </div>
        <p className="mt-[6px] text-[11px] leading-snug text-(--m-text-2)">
          A closed Mac isn&apos;t off. macOS keeps waking it on a timer for maintenance, the network
          and Find My. Sealed Sleep switches all of that off, so nothing brings it up until you open
          the lid.
        </p>
        <div className="mt-[8px] flex items-center justify-between">
          <span className="text-[13px]">Wake instantly</span>
          {t("instant")}
        </div>
        <ul className="mt-[10px] grid grid-cols-2 gap-x-[12px] gap-y-[5px]">
          {LEAKS.map((l) => (
            <li key={l} className="flex items-center gap-[6px] text-[11px]">
              {s.sealed ? (
                <>
                  <CheckIcon className="size-[11px] shrink-0 text-(--m-good)" strokeWidth={2.6} />
                  <span className="text-(--m-text-2) line-through decoration-white/30">{l}</span>
                </>
              ) : (
                <>
                  <span className="size-[6px] shrink-0 rounded-full bg-(--m-amber)" />
                  <span>{l}</span>
                </>
              )}
            </li>
          ))}
        </ul>
        <p className="mt-[10px] flex items-center gap-[6px] text-[11px] text-(--m-good)">
          <CheckIcon className="size-[12px]" strokeWidth={2.6} />
          Last close: 34h shut · 0% lost
        </p>
      </div>
      <SectionHeader>When the lid closes</SectionHeader>
      <div className={cn("transition-opacity", s.sealed && "opacity-55")}>
        <Row title="Turn off Wi-Fi" right={t("wifi")} />
        <Row title="Turn off Bluetooth" right={t("bt")} />
      </div>
      <SectionHeader>Wake while closed</SectionHeader>
      <Row
        title="Power Nap"
        subtitle="Wakes periodically while closed to sync Mail/iCloud"
        right={<Toggle on={false} />}
      />
      <Row
        title="Wake for network access"
        subtitle="Lets other devices wake this Mac over the network"
        right={<Toggle on={false} />}
      />
    </>
  );
}

function GeneralTab({
  iconStyle,
  onIconStyle,
}: {
  iconStyle: IconStyle;
  onIconStyle: (s: IconStyle) => void;
}) {
  const [, t] = useToggles({ color: false });
  return (
    <>
      <SectionHeader>Helper</SectionHeader>
      <div className="px-[12px]">
        <p className="flex items-center gap-[8px] text-[13px]">
          <span className="flex size-[15px] items-center justify-center rounded-full bg-[#d0d0d0]">
            <CheckIcon className="size-[10px] text-[#282828]" strokeWidth={3} />
          </span>
          Installed and running
        </p>
        <p className="mt-[6px] text-[11px] text-(--m-text-2)">
          Enforcing your charge policy in the background. It re-enables charging if ever stopped.
        </p>
        <div className="mt-[8px] flex gap-[8px]">
          <SmallButton>Reinstall Helper…</SmallButton>
          <SmallButton>Uninstall…</SmallButton>
        </div>
      </div>
      <SectionHeader>Menu bar</SectionHeader>
      <div className="grid grid-cols-5 gap-[7px] px-[12px]">
        {ICON_STYLES.map((st) => {
          const on = st === iconStyle;
          return (
            <button
              key={st}
              type="button"
              tabIndex={-1}
              onClick={() => onIconStyle(st)}
              className={cn(
                "flex flex-col items-center gap-[5px] rounded-[8px] border py-[9px] transition-colors",
                on
                  ? "border-(--m-blue) bg-(--m-blue)/20 text-(--m-blue-text)"
                  : "border-transparent bg-white/[0.06] text-(--m-text)/85 hover:bg-white/[0.1]",
              )}
            >
              <BatteryGlyph style={st} className="size-[26px]" />
              <span className="text-[11px] font-medium">{st}</span>
            </button>
          );
        })}
      </div>
      <p className="mt-[8px] px-[12px] text-[11px] text-(--m-text-2)">
        Pick how the battery looks in the menu bar. The fill tracks your exact charge.
      </p>
      <div className="mt-[6px]">
        <Row
          title="Show"
          subtitle="Time remaining is time to full while charging, time to empty on battery."
          right={
            <span className="flex items-center gap-[10px] rounded-[5px] bg-white/[0.12] py-[2px] pr-[3px] pl-[8px] text-[12px]">
              Icon only
              <span className="rounded-[4px] bg-(--m-blue) px-[3px] text-[8px] leading-[14px] text-white">
                ⇕
              </span>
            </span>
          }
        />
        <Row
          title="Color icon by charge state"
          subtitle="Green charging, red when low or warm."
          right={t("color")}
        />
      </div>
    </>
  );
}

function AboutTab() {
  const { data: latest } = useQuery(latestReleaseQueryOptions());
  return (
    <div className="flex flex-col items-center pt-[40px] text-center">
      <AppIcon className="size-[84px]" />
      <p className="mt-[12px] text-[20px] font-semibold">eWiz</p>
      <p className="mt-[2px] min-h-[1lh] text-[11px] text-(--m-text-2)">
        {latest ? `Version ${latest.version}` : null}
      </p>
      <p className="mt-[14px] max-w-[300px] text-[12px] leading-snug text-(--m-text-2)">
        Charge limiting, heat-aware charging, sleep-safe enforcement, and one-tap save modes.
      </p>
      <div className="mt-[16px] flex gap-[8px]">
        <SmallButton>Check for Updates…</SmallButton>
        <SmallButton>Send Feedback</SmallButton>
      </div>
    </div>
  );
}

export function SettingsWindow({
  tab,
  onTab,
  iconStyle,
  onIconStyle,
  height = 600,
  scroll = 0,
  className,
  style,
}: {
  scroll?: number;
  tab: SettingsTab;
  onTab: (t: SettingsTab) => void;
  iconStyle: IconStyle;
  onIconStyle: (s: IconStyle) => void;
  height?: number;
  className?: string;
  style?: React.CSSProperties;
}) {
  const clickable = (id: SettingsTab) => id !== "Shortcuts";
  return (
    <MacWindow
      title="eWiz Settings"
      width={580}
      height={height}
      className={className}
      style={style}
    >
      <div className="flex shrink-0 gap-[2px] border-b border-black/50 px-[10px] pb-[8px] shadow-[0_0.5px_0_rgb(255_255_255/0.05)]">
        {TABS.map(({ id, icon: Icon }) => {
          const on = id === tab;
          return (
            <button
              key={id}
              type="button"
              tabIndex={-1}
              onClick={() => clickable(id) && onTab(id)}
              className={cn(
                "flex flex-1 flex-col items-center gap-[4px] rounded-[9px] py-[6px] transition-colors",
                on ? "bg-white/10 text-(--m-blue-text)" : "text-(--m-text)/75",
                !on && clickable(id) && "hover:bg-white/[0.05]",
              )}
            >
              <Icon className="size-[19px]" strokeWidth={1.6} />
              <span className="text-[10.5px]">{id}</span>
            </button>
          );
        })}
      </div>
      <div className="min-h-0 flex-1 overflow-hidden">
        <div
          key={tab}
          className="animate-fade mx-auto w-[468px] pb-[16px] transition-transform duration-500"
          style={scroll ? { transform: `translateY(-${scroll}px)` } : undefined}
        >
          {tab === "Charging" ? <ChargingTab /> : null}
          {tab === "Schedule" ? <ScheduleTab /> : null}
          {tab === "Automation" ? <AutomationTab /> : null}
          {tab === "Sleep & Power" ? <SleepTab /> : null}
          {tab === "General" ? (
            <GeneralTab iconStyle={iconStyle} onIconStyle={onIconStyle} />
          ) : null}
          {tab === "About" ? <AboutTab /> : null}
        </div>
      </div>
    </MacWindow>
  );
}

/* ==========================================================================
   Battery History and Battery Details
   ========================================================================== */
function GroupCard({ children }: { children: React.ReactNode }) {
  return <div className="overflow-hidden rounded-[10px] bg-(--m-card)">{children}</div>;
}

function H({ children, right }: { children: React.ReactNode; right?: string }) {
  return (
    <div className="mt-[18px] mb-[8px] flex items-baseline justify-between first:mt-[10px]">
      <h3 className="text-[15px] font-semibold">{children}</h3>
      {right ? <span className="text-[11px] text-(--m-text-2)">{right}</span> : null}
    </div>
  );
}

function HistoryRow({
  icon,
  title,
  sub,
  value,
  rate,
  good,
}: {
  icon?: boolean;
  title: string;
  sub: string;
  value: string;
  rate: string;
  good?: boolean;
}) {
  return (
    <div className="flex items-center gap-[12px] border-b border-(--m-sep) px-[12px] py-[8px] last:border-b-0">
      {icon ? <ZapIcon className="size-[15px] fill-(--m-green) text-(--m-green)" /> : null}
      <div className="flex-1">
        <p className="text-[13px]">{title}</p>
        <p className="num text-[11px] text-(--m-text-2)">{sub}</p>
      </div>
      <div className="text-right">
        <p
          className={cn(
            "text-[13px] font-semibold",
            good ? "text-(--m-green)" : "text-(--m-text-2)",
          )}
        >
          {value}
        </p>
        <p className="num text-[11px] text-(--m-text-2)">{rate}</p>
      </div>
    </div>
  );
}

export function HistoryWindow({
  height = 560,
  className,
}: {
  height?: number;
  className?: string;
}) {
  const bars = [38, 52, 45, 70, 64, 80, 76, 80, 80, 72, 66, 80, 84, 80];
  return (
    <MacWindow title="Battery History" width={560} height={height} className={className}>
      <div className="min-h-0 flex-1 overflow-hidden px-[20px]">
        <H right="Last 14 days">Charge level</H>
        <GroupCard>
          <div className="flex h-[92px] items-end gap-[6px] px-[12px] pt-[12px] pb-[10px]">
            {bars.map((b, i) => (
              <span
                key={i}
                className="flex-1 rounded-t-[3px] bg-(--m-green)/80"
                style={{ height: `${b}%`, opacity: 0.45 + (i / bars.length) * 0.55 }}
              />
            ))}
          </div>
        </GroupCard>
        <H>Charging</H>
        <GroupCard>
          <HistoryRow
            icon
            title="Oct 6, 7:20 PM"
            sub="59% → 84% · 21m"
            value="+25%"
            rate="70.7%/h"
            good
          />
          <HistoryRow
            icon
            title="Oct 6, 8:17 AM"
            sub="66% → 72% · 5m"
            value="+6%"
            rate="71.3%/h"
            good
          />
        </GroupCard>
        <H>While Lid Was Closed</H>
        <GroupCard>
          <HistoryRow
            title="Closed Oct 6, 2:05 PM"
            sub="72% → 72% · 4h 43m"
            value="no drop"
            rate="0.0%/h"
          />
          <HistoryRow
            title="Closed Oct 6, 10:35 AM"
            sub="71% → 71% · 3h 15m"
            value="no drop"
            rate="0.0%/h"
          />
          <HistoryRow
            title="Closed Oct 5, 11:59 PM"
            sub="64% → 65% · 7h 55m"
            value="no drop"
            rate="0.0%/h"
          />
          <HistoryRow
            title="Closed Oct 5, 6:12 PM"
            sub="81% → 81% · 2h 40m"
            value="no drop"
            rate="0.0%/h"
          />
        </GroupCard>
      </div>
    </MacWindow>
  );
}

function KV({ k, v, icon }: { k: string; v: string; icon?: React.ReactNode }) {
  return (
    <div className="flex items-center gap-[10px] border-b border-(--m-sep) px-[12px] py-[7px] last:border-b-0">
      {icon}
      <span className="flex-1 text-[12px] text-(--m-text)/85">{k}</span>
      <span className="num text-[12px] font-semibold">{v}</span>
    </div>
  );
}

export function DetailsWindow({
  height = 600,
  className,
}: {
  height?: number;
  className?: string;
}) {
  return (
    <MacWindow title="Battery Details" width={380} height={height} className={className}>
      <div className="min-h-0 flex-1 overflow-hidden px-[18px]">
        <H>Battery</H>
        <GroupCard>
          <KV k="Health" v="86%" />
          <KV k="Cycle count" v="401" />
          <KV k="Temperature" v="30.7 °C" />
          <KV k="Capacity" v="5400 / 6249 mAh" />
          <KV k="Power source" v="AC Power" />
          <KV k="Charge" v="80%" />
        </GroupCard>
        <H right="68W">Power Flow</H>
        <div className="h-[8px] overflow-hidden rounded-full bg-(--m-track)">
          <div className="h-full w-full rounded-full bg-[#8fb0e6]" />
        </div>
        <p className="mt-[6px] mb-[10px] flex gap-[14px] text-[10px] text-(--m-text-2)">
          <span className="flex items-center gap-[5px]">
            <span className="size-[6px] rounded-full bg-[#8fb0e6]" />
            System <b className="font-semibold text-(--m-text)">18.6 W · 100%</b>
          </span>
          <span className="flex items-center gap-[5px]">
            <span className="size-[6px] rounded-full bg-(--m-green)" />
            Into battery <b className="font-semibold text-(--m-text)">0.0 W · 0%</b>
          </span>
        </p>
        <GroupCard>
          <KV
            k="Adapter in"
            v="18.6 W"
            icon={<ZapIcon className="size-[13px] fill-[#f5c542] text-[#f5c542]" />}
          />
          <KV
            k="System draw"
            v="18.6 W"
            icon={<CpuIcon className="size-[13px] text-[#f0a35e]" />}
          />
          <KV
            k="Battery idle"
            v="0.0 W"
            icon={<BatteryIcon className="size-[13px] text-(--m-text-2)" />}
          />
        </GroupCard>
        <H right="68 W">Power Adapter</H>
        <GroupCard>
          <KV
            k="Adapter"
            v="70W USB-C Power Adapter"
            icon={<PlugIcon className="size-[13px] text-(--m-text-2)" />}
          />
          <KV k="Negotiated" v="20.0 V · 3.4 A" />
          <KV k="Adapter maximum" v="68 W" />
        </GroupCard>
      </div>
    </MacWindow>
  );
}
