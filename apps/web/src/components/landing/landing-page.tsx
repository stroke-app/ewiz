import { Link } from "@tanstack/react-router";
import {
  ActivityIcon,
  ArrowUpRightIcon,
  BatteryChargingIcon,
  CheckIcon,
  ClockIcon,
  CoffeeIcon,
  CpuIcon,
  DownloadIcon,
  HeartIcon,
  HistoryIcon,
  LaptopIcon,
  LayoutGridIcon,
  MousePointerClickIcon,
  MoonStarIcon,
  PlugIcon,
  ThermometerIcon,
  WandSparklesIcon,
  XIcon,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useEffect, useState } from "react";

import { useCheckout } from "#/components/buy-button";
import { AppIcon } from "#/components/logo";
import { Container, Eyebrow, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";
import { cn } from "#/lib/utils";

import { FAQS, LINKS, PRICE } from "./landing-data";
import { LightningField } from "./lightning-field";
import {
  DetailsWindow,
  HistoryWindow,
  MenuBarStrip,
  MenuPopover,
  SettingsWindow,
  Stage,
  Toggle,
} from "./mac-ui";
import type { IconStyle, SettingsTab } from "./mac-ui";

const H2 = "text-3xl font-semibold tracking-tight text-balance sm:text-[2.25rem] sm:leading-[1.15]";
const WIDE = "mx-auto w-full max-w-[68rem] px-4";

function DownloadButton({
  variant = "default",
  className,
}: {
  variant?: "default" | "outline";
  className?: string;
}) {
  return (
    <Button
      render={<Link to="/download" />}
      nativeButton={false}
      variant={variant}
      className={cn("text-[15px]", className)}
    >
      Download
      <DownloadIcon />
    </Button>
  );
}

function BuyButton({ className, children }: { className?: string; children: React.ReactNode }) {
  const { buy, loading } = useCheckout();
  return (
    <Button
      type="button"
      variant="outline"
      onClick={buy}
      disabled={loading}
      className={cn("text-[15px]", className)}
    >
      {children}
    </Button>
  );
}

/* ==========================================================================
   Hero: the real eWiz panel dropping from the menu bar over a live desktop.
   ========================================================================== */
type DesktopView = "settings" | "details" | "history";

function Hero({
  iconStyle,
  onIconStyle,
}: {
  iconStyle: IconStyle;
  onIconStyle: (s: IconStyle) => void;
}) {
  const [view, setView] = useState<DesktopView>("settings");
  const [tab, setTab] = useState<SettingsTab>("Charging");
  return (
    <section>
      <Container className="pt-8 text-center">
        <AppIcon className="animate-enter mx-auto size-[72px]" />
        <Eyebrow
          className="animate-enter mt-7"
          style={{ "--enter-delay": "60ms" } as React.CSSProperties}
        >
          Introducing eWiz
        </Eyebrow>
        <h1
          className="animate-enter mx-auto mt-3 max-w-[40rem] text-[2.1rem] leading-[1.1] font-semibold tracking-tight text-balance sm:text-[3rem]"
          style={{ "--enter-delay": "100ms" } as React.CSSProperties}
        >
          Make macOS stop wrecking your battery.
        </h1>
        <p
          className="animate-enter mx-auto mt-5 max-w-[36rem] text-lg leading-relaxed text-pretty text-muted-foreground"
          style={{ "--enter-delay": "150ms" } as React.CSSProperties}
        >
          Charge limiting, heat-aware charging, sleep-safe enforcement and one-tap save modes, all
          from your menu bar. Built for Apple Silicon.
        </p>
        <div
          className="animate-enter mt-9 flex justify-center gap-2"
          style={{ "--enter-delay": "200ms" } as React.CSSProperties}
        >
          <DownloadButton />
          <BuyButton>Buy · {PRICE}</BuyButton>
        </div>
        <p className="mt-3 text-sm text-muted-foreground">
          Free for 30 days · macOS 14+ · Apple Silicon
        </p>
      </Container>

      <div
        className={cn(WIDE, "animate-enter mt-14")}
        style={{ "--enter-delay": "280ms" } as React.CSSProperties}
      >
        <div className="overflow-hidden rounded-2xl shadow-[0_30px_80px_-30px_rgb(0_40_120/0.55)] ring-1 ring-black/10 dark:ring-white/10">
          {/* Desktop: the whole menu bar scene. */}
          <Stage width={1100} height={700} className="hidden sm:block">
            <div className="wallpaper absolute inset-0" />
            <div className="absolute inset-x-0 top-0">
              <MenuBarStrip iconStyle={iconStyle} />
            </div>
            <div key={view} className="animate-fade absolute top-[66px] left-[64px]">
              {view === "settings" ? (
                <SettingsWindow
                  tab={tab}
                  onTab={setTab}
                  iconStyle={iconStyle}
                  onIconStyle={onIconStyle}
                />
              ) : null}
              {view === "details" ? <DetailsWindow className="ml-[100px]" /> : null}
              {view === "history" ? <HistoryWindow /> : null}
            </div>
            <MenuPopover
              onOpen={setView}
              className="mac-drop absolute top-[32px] right-[14px]"
              style={{ "--drop-delay": "650ms" } as React.CSSProperties}
            />
          </Stage>
          {/* Phone: just the panel, at a readable size. */}
          <Stage width={360} height={580} className="sm:hidden">
            <div className="wallpaper absolute inset-0" />
            <div className="absolute inset-x-0 top-0">
              <MenuBarStrip iconStyle={iconStyle} compact />
            </div>
            <MenuPopover className="mac-drop absolute top-[34px] left-[20px]" />
          </Stage>
        </div>
        <p className="mt-4 flex items-center justify-center gap-2 text-sm text-muted-foreground">
          <MousePointerClickIcon className="size-4" />
          That&apos;s the real eWiz panel. Drag the limit, flip a mode, open Settings.
        </p>
      </div>
    </section>
  );
}

/* ==========================================================================
   Feature switcher: pick a feature, see the real screen. Auto-advances until
   the visitor takes over.
   ========================================================================== */
type FeatureView =
  | { kind: "settings"; tab: SettingsTab }
  | { kind: "history" }
  | { kind: "details" };

const FEATURES: Array<{
  id: string;
  icon: LucideIcon;
  title: string;
  body: string;
  view: FeatureView;
}> = [
  {
    id: "limit",
    icon: BatteryChargingIcon,
    title: "A charge limit that holds",
    body: "Cap charging anywhere from 50 to 100%. eWiz holds the level with a buffer so the charger isn't flicking on and off, and speaks both Apple Silicon charging schemes, including macOS 26 Tahoe.",
    view: { kind: "settings", tab: "Charging" },
  },
  {
    id: "sealed",
    icon: MoonStarIcon,
    title: "Sealed Sleep",
    body: "A closed Mac isn't off. One switch turns off every wake source behind it, shows you each one as sealed, and measures what the last close actually cost.",
    view: { kind: "settings", tab: "Sleep & Power" },
  },
  {
    id: "rules",
    icon: WandSparklesIcon,
    title: "Automation rules",
    body: "While this is true, do that. Build rules from a dozen conditions, from a connected display to a Wi-Fi network. Each one undoes itself when it stops matching.",
    view: { kind: "settings", tab: "Automation" },
  },
  {
    id: "schedule",
    icon: ClockIcon,
    title: "Schedules and Ready By",
    body: "Hold overnight, then top up in time for the morning. Charge on a weekly timetable, or turn charge power down to keep things cool.",
    view: { kind: "settings", tab: "Schedule" },
  },
  {
    id: "history",
    icon: HistoryIcon,
    title: "Every close, measured",
    body: "History lists each charge and every lid-closed session with its exact drop per hour. Export the lot as CSV.",
    view: { kind: "history" },
  },
  {
    id: "details",
    icon: ActivityIcon,
    title: "The numbers that matter",
    body: "Health, cycle count, temperature and capacity, plus live power flow and what your adapter actually negotiated.",
    view: { kind: "details" },
  },
  {
    id: "menubar",
    icon: LayoutGridIcon,
    title: "Your menu bar, your way",
    body: "Twelve battery styles, from Bars to Dial. Pick one and watch the menu bar at the top of the page change with it.",
    view: { kind: "settings", tab: "General" },
  },
];

const FEATURE_MS = 7000;

function Features({
  iconStyle,
  onIconStyle,
}: {
  iconStyle: IconStyle;
  onIconStyle: (s: IconStyle) => void;
}) {
  const [index, setIndex] = useState(0);
  const [auto, setAuto] = useState(true);
  const [paused, setPaused] = useState(false);
  const [tabOverride, setTabOverride] = useState<SettingsTab | null>(null);

  useEffect(() => {
    if (!auto || paused || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const id = window.setTimeout(() => setIndex((i) => (i + 1) % FEATURES.length), FEATURE_MS);
    return () => window.clearTimeout(id);
  }, [auto, paused, index]);

  const feature = FEATURES[index];
  const view = feature.view;
  const tab = tabOverride ?? (view.kind === "settings" ? view.tab : "Charging");
  const select = (i: number) => {
    setAuto(false);
    setTabOverride(null);
    setIndex(i);
  };

  return (
    <section id="features" className="mt-32 scroll-mt-8">
      <div className={WIDE}>
        <Eyebrow tone="rose">Made with care</Eyebrow>
        <h2 className={cn(H2, "mt-1 max-w-xl")}>What sets eWiz apart?</h2>

        <div className="mt-8 grid gap-6 lg:grid-cols-[minmax(0,22rem)_minmax(0,1fr)] lg:gap-10">
          <ul className="flex flex-col gap-1">
            {FEATURES.map((f, i) => {
              const on = i === index;
              return (
                <li key={f.id}>
                  <button
                    type="button"
                    aria-pressed={on}
                    onClick={() => select(i)}
                    onMouseEnter={() => setPaused(true)}
                    onMouseLeave={() => setPaused(false)}
                    className={cn(
                      "relative w-full overflow-hidden rounded-lg px-4 py-3 text-left transition-colors",
                      on ? "bg-surface-2" : "hover:bg-surface-2/50",
                    )}
                  >
                    <span
                      className={cn(
                        "flex items-center gap-2.5 font-medium transition-colors",
                        on ? "text-foreground" : "text-muted-foreground",
                      )}
                    >
                      <f.icon className={cn("size-4", on && "text-primary")} />
                      {f.title}
                    </span>
                    {on ? (
                      <span className="animate-fade mt-1.5 block text-[15px] leading-relaxed text-pretty text-muted-foreground">
                        {f.body}
                      </span>
                    ) : null}
                    {on && auto ? (
                      <span
                        key={index}
                        className="feature-progress absolute inset-x-0 bottom-0 h-0.5 bg-primary/70 motion-reduce:hidden"
                        style={
                          {
                            "--feature-ms": `${FEATURE_MS}ms`,
                            animationPlayState: paused ? "paused" : "running",
                          } as React.CSSProperties
                        }
                      />
                    ) : null}
                  </button>
                </li>
              );
            })}
          </ul>

          <div className="overflow-hidden rounded-xl ring-1 ring-black/10 lg:sticky lg:top-6 lg:self-start dark:ring-white/10">
            <Stage width={760} height={620}>
              <div className="wallpaper absolute inset-0" />
              <div
                key={feature.id}
                className="animate-fade absolute inset-0 flex justify-center pt-[44px]"
              >
                {view.kind === "settings" ? (
                  <SettingsWindow
                    tab={tab}
                    onTab={(t) => {
                      setAuto(false);
                      setTabOverride(t);
                    }}
                    iconStyle={iconStyle}
                    onIconStyle={(s) => {
                      setAuto(false);
                      onIconStyle(s);
                    }}
                  />
                ) : null}
                {view.kind === "history" ? <HistoryWindow height={600} /> : null}
                {view.kind === "details" ? <DetailsWindow /> : null}
              </div>
            </Stage>
          </div>
        </div>
      </div>
    </section>
  );
}

/* ==========================================================================
   Bento: the smaller things, each with a sliver of the real UI.
   ========================================================================== */
const SAVE_MODES = {
  Off: "No battery saving, standard macOS behavior.",
  Normal: "Charge limit 80%, pause when warm, Power Nap off. Find My stays active.",
  "Super Saver":
    "Low Power Mode, charge limit 80%, pause when warm, all sleep wake-ups off, Wi-Fi & Bluetooth off when closed.",
} as const;

function MiniPanel({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div className="mac-ui flex h-40 items-center justify-center bg-[#1c1c1f] px-5">
      <div className={cn("w-full max-w-[17rem]", className)}>{children}</div>
    </div>
  );
}

function BentoCard({
  icon: Icon,
  title,
  body,
  visual,
}: {
  icon: LucideIcon;
  title: string;
  body: string;
  visual: React.ReactNode;
}) {
  return (
    <div className="overflow-hidden rounded-xl border border-border bg-surface-1">
      <div className="border-b border-border">{visual}</div>
      <div className="p-4">
        <h3 className="flex items-center gap-2 font-medium">
          <Icon className="size-4 text-muted-foreground" />
          {title}
        </h3>
        <p className="mt-1 text-[15px] leading-relaxed text-pretty text-muted-foreground">{body}</p>
      </div>
    </div>
  );
}

const QUICK_TILES: Array<{ icon: LucideIcon; label: string; on: boolean }> = [
  { icon: LaptopIcon, label: "Lid", on: false },
  { icon: CoffeeIcon, label: "Awake", on: true },
  { icon: MoonStarIcon, label: "Rest", on: false },
];

const TOP_UP_MENU = [
  "Pause 1 hour",
  "Pause until I resume",
  "Charge to 100% once",
  "Park near 60% (long-term care)",
];

function Bento() {
  const [mode, setMode] = useState<keyof typeof SAVE_MODES>("Normal");
  const [heat, setHeat] = useState(true);
  return (
    <section className="mt-32">
      <div className={WIDE}>
        <Eyebrow>Everything else</Eyebrow>
        <h2 className={cn(H2, "mt-1 max-w-xl")}>Small app. A lot of quiet work.</h2>
        <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <BentoCard
            icon={LayoutGridIcon}
            title="One-tap save modes"
            body="Flip a whole bundle of settings at once instead of hunting through toggles."
            visual={
              <MiniPanel>
                <div className="flex rounded-[8px] bg-white/[0.06] p-[2px]">
                  {(Object.keys(SAVE_MODES) as Array<keyof typeof SAVE_MODES>).map((m) => (
                    <button
                      key={m}
                      type="button"
                      onClick={() => setMode(m)}
                      className={cn(
                        "flex-1 rounded-[6px] py-[5px] text-[12px] transition-colors",
                        m === mode ? "bg-white/[0.14] font-semibold" : "text-(--m-text-2)",
                      )}
                    >
                      {m}
                    </button>
                  ))}
                </div>
                <p
                  key={mode}
                  className="animate-fade mt-2.5 min-h-[3.2em] text-[11px] leading-snug text-(--m-text-2)"
                >
                  {SAVE_MODES[mode]}
                </p>
              </MiniPanel>
            }
          />
          <BentoCard
            icon={ThermometerIcon}
            title="Backs off when it runs hot"
            body="Heat ages a battery faster than cycles do. Past your temperature, charging pauses and the menu tells you why."
            visual={
              <MiniPanel>
                <div className="flex items-center justify-between">
                  <span className="text-[13px]">Pause charging when hot</span>
                  <Toggle on={heat} onClick={() => setHeat((v) => !v)} />
                </div>
                <div
                  className={cn(
                    "mt-3 flex items-center justify-between transition-opacity",
                    !heat && "opacity-40",
                  )}
                >
                  <span className="text-[13px] text-(--m-text-2)">Max temperature</span>
                  <span className="num text-[13px]">40 °C</span>
                </div>
                <p className="mt-3 flex items-center gap-1.5 text-[11px] text-(--m-amber)">
                  <ThermometerIcon className="size-3" />
                  {heat ? "Charging paused, battery is warm" : "Heat cap off"}
                </p>
              </MiniPanel>
            }
          />
          <BentoCard
            icon={PlugIcon}
            title="Your cable tells the truth"
            body="eWiz drives the MagSafe LED from the real charge state: orange while charging, green when it's holding at your limit."
            visual={
              <MiniPanel className="flex justify-center gap-6">
                {[
                  ["#f5a524", "Charging"],
                  ["#3fc24b", "Holding"],
                ].map(([c, l]) => (
                  <div key={l} className="flex flex-col items-center">
                    <div className="flex h-7 w-14 items-center justify-center rounded-md bg-gradient-to-b from-[#4a4a4e] to-[#2a2a2d] shadow-[inset_0_1px_0_rgb(255_255_255/0.15)]">
                      <span
                        className="size-2.5 rounded-full"
                        style={{ backgroundColor: c, boxShadow: `0 0 12px 3px ${c}` }}
                      />
                    </div>
                    <span className="mt-3 text-[11px] text-(--m-text-2)">{l}</span>
                  </div>
                ))}
              </MiniPanel>
            }
          />
          <BentoCard
            icon={CoffeeIcon}
            title="Keep Awake, one tap"
            body="Stop the display sleeping for a long download or a talk. It lets go when the timer runs out, or when you unplug if you ask it to."
            visual={
              <MiniPanel>
                <div className="grid grid-cols-3 gap-1.5">
                  {QUICK_TILES.map((t) => (
                    <span
                      key={t.label}
                      className={cn(
                        "flex flex-col items-center gap-1 rounded-[8px] border py-2",
                        t.on
                          ? "border-[#f5c542]/30 bg-[#f5c542]/15 text-[#f5c542]"
                          : "border-white/5 bg-white/[0.06] text-(--m-text)/80",
                      )}
                    >
                      <t.icon className="size-4" />
                      <span className="text-[10px]">{t.label}</span>
                    </span>
                  ))}
                </div>
                <p className="mt-2.5 text-[11px] text-(--m-text-2)">
                  Keeping awake · screen stays on · 45m left
                </p>
              </MiniPanel>
            }
          />
          <BentoCard
            icon={CpuIcon}
            title="Know your charger"
            body="See the wattage, voltage and current your adapter negotiated. If it could give more, eWiz says so. That gap is nearly always the cable."
            visual={
              <MiniPanel>
                <div className="overflow-hidden rounded-[10px] bg-(--m-card) text-[12px]">
                  {[
                    ["Adapter", "70W USB-C"],
                    ["Negotiated", "20.0 V · 3.4 A"],
                    ["Adapter maximum", "68 W"],
                  ].map(([k, v]) => (
                    <div
                      key={k}
                      className="flex justify-between border-b border-(--m-sep) px-3 py-1.5 last:border-0"
                    >
                      <span className="text-(--m-text)/80">{k}</span>
                      <span className="num font-semibold">{v}</span>
                    </div>
                  ))}
                </div>
              </MiniPanel>
            }
          />
          <BentoCard
            icon={BatteryChargingIcon}
            title="Top up before a trip"
            body="Lift the limit for one full charge, pause it for a few hours, or park the battery near 60% for long-term storage."
            visual={
              <MiniPanel>
                <div className="rounded-[8px] border border-white/10 bg-[#2a2a2d] py-1 text-[12px] shadow-xl">
                  {TOP_UP_MENU.map((item, i) => (
                    <p
                      key={item}
                      className={cn(
                        "mx-1 rounded-[4px] px-2.5 py-[3px]",
                        i === 2 ? "bg-(--m-blue) text-white" : "text-(--m-text)/90",
                      )}
                    >
                      {item}
                    </p>
                  ))}
                </div>
              </MiniPanel>
            }
          />
        </div>

        <div className="mt-4 rounded-xl border border-border bg-surface-1 px-4 py-3">
          <p className="flex items-center gap-2.5 font-medium">
            <HeartIcon className="size-4 fill-rose text-rose" />
            Made by a single developer
          </p>
          <p className="mt-1 text-[15px] leading-relaxed text-pretty text-muted-foreground">
            eWiz is built by{" "}
            <a
              href={LINKS.site}
              target="_blank"
              rel="noreferrer"
              className="text-foreground underline decoration-border underline-offset-4 transition-colors hover:decoration-foreground"
            >
              Nischal
            </a>
            , an independent developer who loves small, native Mac software that just works.
            Questions and ideas go straight to the person who writes the code.
          </p>
        </div>
      </div>
    </section>
  );
}

/* ========================================================================== */

function Supported() {
  const items: Array<{ icon: LucideIcon; title: string; status: string; ok: boolean }> = [
    { icon: CpuIcon, title: "Apple Silicon", status: "Supported", ok: true },
    { icon: LaptopIcon, title: "macOS 14 to 26", status: "Supported", ok: true },
    { icon: XIcon, title: "Intel Macs", status: "Not supported", ok: false },
  ];
  return (
    <section className="mt-32">
      <div className={WIDE}>
        <h2 className={H2}>Will it run on your Mac?</h2>
        <p className="mt-2 max-w-2xl text-lg leading-relaxed text-pretty text-muted-foreground">
          eWiz is built for Apple Silicon MacBooks on macOS 14 Sonoma or newer, and speaks both of
          Apple&apos;s charging schemes, including the new one in macOS 26 Tahoe.
        </p>
        <div className="mt-6 grid gap-4 sm:grid-cols-3">
          {items.map((it) => (
            <div
              key={it.title}
              className="flex flex-col items-center rounded-lg border border-border bg-surface-1 px-4 py-4 text-center"
            >
              <it.icon
                className={cn("size-8", it.ok ? "text-primary" : "text-muted-foreground")}
                strokeWidth={1.5}
              />
              <h3 className="mt-3 text-lg font-medium">{it.title}</h3>
              <span
                className={cn(
                  "mt-1 rounded px-1.5 text-sm",
                  it.ok ? "bg-success/15 text-success" : "bg-surface-3 text-muted-foreground",
                )}
              >
                {it.status}
              </span>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Included({ items }: { items: string[] }) {
  return (
    <div className="mt-4 px-1">
      <p className="text-[15px] font-medium">What&apos;s included</p>
      <ul className="mt-1.5 space-y-1">
        {items.map((f) => (
          <li key={f} className="flex items-center gap-2.5 text-[15px]">
            <CheckIcon className="size-3.5 text-success" />
            {f}
          </li>
        ))}
      </ul>
    </div>
  );
}

function Pricing() {
  const { buy, loading } = useCheckout();
  return (
    <section id="pricing" className="mt-32 scroll-mt-8">
      <div className={WIDE}>
        <div className="text-center">
          <Eyebrow tone="success">Pricing</Eyebrow>
          <h2 className={cn(H2, "mx-auto mt-1 max-w-lg")}>
            Try it free for 30 days, then keep it for good
          </h2>
        </div>
        <div className="mx-auto mt-6 grid max-w-3xl gap-6 sm:grid-cols-2">
          <div className="flex flex-col rounded-lg border border-border bg-surface-1 p-4">
            <h3 className="text-xl font-medium">Free trial</h3>
            <p className="mt-3 flex items-baseline gap-1">
              <span className="text-sm text-muted-foreground">$</span>
              <span className="text-2xl font-medium tabular-nums">0</span>
              <span className="ml-1 text-muted-foreground">for 30 days</span>
            </p>
            <Included items={["Every feature unlocked", "No account needed", "No card required"]} />
            <DownloadButton variant="outline" className="mt-8 w-full sm:mt-auto" />
          </div>

          <div className="flex flex-col rounded-lg border border-border bg-surface-1 p-4">
            <h3 className="text-xl font-medium">License - Single Mac</h3>
            <p className="mt-3 flex items-baseline gap-1">
              <span className="text-sm text-muted-foreground">$</span>
              <span className="text-2xl font-medium tabular-nums">{PRICE.slice(1)}</span>
              <span className="ml-1 text-muted-foreground">one-time</span>
            </p>
            <p className="mt-1 leading-relaxed text-pretty text-muted-foreground">
              Pay once and keep it forever. A replacement MacBook battery runs about $199.
            </p>
            <Included
              items={["Free updates for life", "No subscription", "Move it to a new Mac"]}
            />
            <Button
              type="button"
              onClick={buy}
              disabled={loading}
              className="mt-8 w-full text-[15px]"
            >
              Purchase
              <ArrowUpRightIcon />
            </Button>
          </div>
        </div>
        <p className="mt-4 text-center text-sm text-muted-foreground">
          Secure checkout via Dodo Payments. Taxes are handled at checkout.
        </p>
      </div>
    </section>
  );
}

function Faq() {
  return (
    <section className="mt-32">
      <div className={WIDE}>
        <Eyebrow tone="warning">FAQ</Eyebrow>
        <h2 className={cn(H2, "mt-1")}>Questions, answered</h2>
        <dl className="mt-6 grid gap-3 lg:grid-cols-2">
          {FAQS.map((item) => (
            <div key={item.q} className="rounded-lg border border-border bg-surface-1 px-4 py-3">
              <dt className="text-lg font-medium">{item.q}</dt>
              <dd className="mt-1 leading-relaxed text-pretty text-muted-foreground">{item.a}</dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}

function ClosingCta() {
  return (
    <section className="mt-32">
      <Container className="text-center">
        <AppIcon className="mx-auto size-20" />
        <h2 className={cn(H2, "mx-auto mt-6 max-w-md")}>Give your battery its years back.</h2>
        <p className="mx-auto mt-3 max-w-md text-lg leading-relaxed text-pretty text-muted-foreground">
          Set it once and forget it. eWiz keeps the promise in the background, awake or asleep.
        </p>
        <div className="mt-8 flex justify-center gap-2">
          <DownloadButton />
          <BuyButton>Buy · {PRICE}</BuyButton>
        </div>
      </Container>
    </section>
  );
}

export function LandingPage() {
  const [iconStyle, setIconStyle] = useState<IconStyle>("Bars");
  return (
    <SitePage
      backdrop={
        <LightningField className="pointer-events-none absolute inset-x-0 top-0 -z-10 h-[720px] w-full [mask-image:linear-gradient(to_bottom,black_55%,transparent)]" />
      }
    >
      <Hero iconStyle={iconStyle} onIconStyle={setIconStyle} />
      <Features iconStyle={iconStyle} onIconStyle={setIconStyle} />
      <Bento />
      <Supported />
      <Pricing />
      <Faq />
      <ClosingCta />
    </SitePage>
  );
}
