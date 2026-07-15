import { Link } from "@tanstack/react-router";
import {
  BatteryCharging02Icon,
  Cancel02Icon,
  CpuIcon,
  Download04Icon,
  GithubIcon,
  Idea01Icon,
  LaptopIcon,
  Moon02Icon,
  NewTwitterRectangleIcon,
  ThermometerIcon,
  Tick02Icon,
} from "@hugeicons/core-free-icons";
import type { IconSvgElement } from "@hugeicons/react";

import { useCheckout } from "#/components/buy-button";
import { Icon } from "#/components/icon";
import { BatteryMark, Logo } from "#/components/logo";
import { ThemeToggle } from "#/components/theme-toggle";
import { Button } from "#/components/ui/button";

import { FAQS, LINKS, MOMENTS, SPECS, TESTIMONIALS } from "./landing-data";
import type { MomentArt } from "./landing-data";

const PRICE = "$2.99";

function DownloadButton({
  size = "default",
  className,
  variant = "default",
  children,
}: {
  size?: "default" | "sm" | "lg";
  className?: string;
  variant?: "default" | "outline";
  children?: React.ReactNode;
}) {
  return (
    <Button
      render={
        <a href={LINKS.releases} target="_blank" rel="noreferrer" aria-label="Download Battlify" />
      }
      nativeButton={false}
      size={size}
      variant={variant}
      className={className}
    >
      {children ?? "Download"}
      <Icon icon={Download04Icon} className="size-4" />
    </Button>
  );
}

function BuyButton({
  size = "default",
  className,
  variant = "default",
  children,
}: {
  size?: "default" | "sm" | "lg";
  className?: string;
  variant?: "default" | "outline";
  children?: React.ReactNode;
}) {
  const { buy, loading } = useCheckout();
  return (
    <Button
      size={size}
      variant={variant}
      className={className}
      onClick={buy}
      disabled={loading}
      type="button"
    >
      {children ?? `Buy · ${PRICE}`}
    </Button>
  );
}

function Eyebrow({
  children,
  tone = "blue",
}: {
  children: React.ReactNode;
  tone?: "blue" | "muted";
}) {
  const color = tone === "muted" ? "text-muted-foreground" : "text-primary";
  return (
    <p className={"text-[11px] font-semibold tracking-[0.16em] uppercase " + color}>{children}</p>
  );
}

/* ========================================================================== */

function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/70 backdrop-blur-xl backdrop-saturate-150">
      <div className="mx-auto grid h-16 max-w-3xl grid-cols-[1fr_auto_1fr] items-center px-6">
        <Link to="/" className="justify-self-start transition-opacity hover:opacity-80">
          <Logo />
        </Link>
        <nav className="hidden items-center gap-8 justify-self-center text-sm text-muted-foreground sm:flex">
          <a href="#pricing" className="transition-colors hover:text-foreground">
            Pricing
          </a>
          <Link to="/blog" className="transition-colors hover:text-foreground">
            Blog
          </Link>
          <Link to="/changelog" className="transition-colors hover:text-foreground">
            Changelog
          </Link>
          <a
            href={LINKS.github}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-foreground"
          >
            Community
          </a>
        </nav>
        <div className="flex items-center gap-1.5 justify-self-end">
          <ThemeToggle />
          <Button render={<Link to="/login" />} variant="outline" size="sm" nativeButton={false}>
            Sign in
          </Button>
        </div>
      </div>
    </header>
  );
}

/* ==========================================================================
   1. HERO: lead with the tension, keep the app-window mockup as proof.
   ========================================================================== */

function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div
        aria-hidden
        className="pointer-events-none absolute top-[-8rem] left-1/2 h-[36rem] w-[48rem] -translate-x-1/2 rounded-full opacity-20 blur-[130px] dark:opacity-40"
        style={{ background: "radial-gradient(closest-side, var(--color-primary), transparent)" }}
      />
      <div className="relative mx-auto max-w-3xl px-6 pt-20 pb-12 text-center">
        <div className="animate-enter">
          <Eyebrow>Battery care for Mac</Eyebrow>
        </div>
        <h1
          className="font-display animate-enter mx-auto mt-5 max-w-2xl text-[2.5rem] leading-[1.03] font-bold tracking-[-0.03em] text-balance sm:text-[3.5rem]"
          style={{ "--enter-delay": "80ms" } as React.CSSProperties}
        >
          Your Mac is quietly cooking its own battery.
        </h1>
        <p
          className="animate-enter mx-auto mt-6 max-w-lg text-[15px] leading-relaxed text-muted-foreground text-pretty sm:text-base"
          style={{ "--enter-delay": "160ms" } as React.CSSProperties}
        >
          Left plugged in, it sits at 100 percent, warm, all day. That is the exact condition that
          wears a lithium battery out fastest. Battlify holds it at a healthier level, keeps that
          limit even while your Mac sleeps, and eases off the moment things get hot.
        </p>
        <div
          className="animate-enter mt-8 flex justify-center"
          style={{ "--enter-delay": "240ms" } as React.CSSProperties}
        >
          <DownloadButton size="lg" className="h-11 rounded-2xl px-6 text-[15px]">
            Download
          </DownloadButton>
        </div>
        <p
          className="animate-enter mt-4 text-[13px] text-muted-foreground"
          style={{ "--enter-delay": "320ms" } as React.CSSProperties}
        >
          No account required. Free for 30 days.
        </p>
      </div>

      <div
        className="animate-enter relative mx-auto max-w-3xl px-6 pb-20"
        style={{ "--enter-delay": "420ms" } as React.CSSProperties}
      >
        <ScreenshotFrame>
          <WindowMockup variant="charging" />
        </ScreenshotFrame>
      </div>
    </section>
  );
}

/** Blue-glow panel the app screenshots sit on, à la sql.studio. */
function ScreenshotFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-8 -top-8 bottom-0 rounded-[2rem] opacity-30 blur-2xl dark:opacity-50"
        style={{
          background: "radial-gradient(60% 60% at 50% 0%, var(--color-primary), transparent)",
        }}
      />
      <div className="relative rounded-[22px] bg-gradient-to-b from-primary/20 via-primary/5 to-transparent p-2 sm:p-2.5 dark:from-primary/30">
        {children}
      </div>
    </div>
  );
}

function WindowMockup({ variant }: { variant: "charging" | "sleep" }) {
  const sidebar: Array<{ icon: IconSvgElement; label: string; key: string }> = [
    { icon: BatteryCharging02Icon, label: "Charging", key: "charging" },
    { icon: Moon02Icon, label: "Sleep", key: "sleep" },
    { icon: ThermometerIcon, label: "Health", key: "health" },
    { icon: Idea01Icon, label: "MagSafe", key: "magsafe" },
  ];

  return (
    <div className="overflow-hidden rounded-[18px] bg-card shadow-window ring-1 ring-black/5 dark:ring-white/10">
      {/* Toolbar */}
      <div className="relative flex items-center gap-2 border-b border-border/60 bg-gradient-to-b from-muted/40 to-transparent px-4 py-3">
        <span className="flex gap-2">
          <span className="size-3 rounded-full bg-[#ff5f57] ring-1 ring-black/10 ring-inset" />
          <span className="size-3 rounded-full bg-[#febc2e] ring-1 ring-black/10 ring-inset" />
          <span className="size-3 rounded-full bg-[#28c840] ring-1 ring-black/10 ring-inset" />
        </span>
        <span className="absolute inset-x-0 flex items-center justify-center gap-1.5 text-xs font-medium text-muted-foreground">
          <BatteryMark className="size-3.5 text-muted-foreground" />
          Battlify: Settings
        </span>
      </div>
      <div className="grid sm:grid-cols-[176px_1fr]">
        <aside className="hidden flex-col gap-0.5 border-r border-border/60 bg-muted/20 p-2.5 sm:flex">
          {sidebar.map((item) => {
            const active = item.key === variant;
            return (
              <div
                key={item.key}
                className={
                  "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm transition-colors " +
                  (active
                    ? "bg-primary/10 font-medium text-primary"
                    : "text-muted-foreground hover:bg-muted/50")
                }
              >
                <Icon icon={item.icon} className="size-4" />
                {item.label}
              </div>
            );
          })}
        </aside>
        {variant === "charging" ? <ChargingPane /> : <SleepPane />}
      </div>
    </div>
  );
}

function ChargingPane() {
  const toggles: Array<{ label: string; on: boolean }> = [
    { label: "Hold at limit while asleep", on: true },
    { label: "Pause charging when hot", on: true },
    { label: "Drive MagSafe LED", on: false },
  ];
  return (
    <div className="p-6">
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground">Charge limit</span>
        <span className="rounded-full bg-battlify-green/15 px-2.5 py-0.5 text-[11px] font-medium text-battlify-green">
          Holding
        </span>
      </div>
      <div className="mt-3 flex items-end gap-3">
        <span className="font-display text-6xl font-semibold tracking-[-0.03em] tabular-nums">
          80%
        </span>
        <span className="mb-2 text-sm text-muted-foreground">buffered · plugged in</span>
      </div>
      {/* Charge track with a limit thumb, like a real slider */}
      <div className="relative mt-5 h-2.5 w-full rounded-full bg-muted shadow-[inset_0_1px_2px_rgba(0,0,0,0.06)] dark:shadow-[inset_0_1px_2px_rgba(0,0,0,0.4)]">
        <div className="relative h-full w-4/5 rounded-full bg-gradient-to-r from-battlify-green/85 to-battlify-green">
          <span className="absolute top-1/2 -right-1 size-4 -translate-y-1/2 rounded-full border border-black/10 bg-white shadow-md dark:border-white/20" />
        </div>
      </div>
      <div className="mt-6 space-y-2">
        {toggles.map((t) => (
          <ToggleRow key={t.label} label={t.label} on={t.on} />
        ))}
      </div>
    </div>
  );
}

function SleepPane() {
  const toggles: Array<{ label: string; on: boolean }> = [
    { label: "Stop charging before sleep", on: true },
    { label: "Keep awake on wall power", on: true },
    { label: "Disable Power Nap", on: false },
    { label: "Silence Bluetooth on sleep", on: true },
  ];
  return (
    <div className="p-6">
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground">When the lid closes</span>
        <span className="rounded-full bg-primary/15 px-2.5 py-0.5 text-[11px] font-medium text-primary">
          Enforced
        </span>
      </div>
      <div className="mt-4 flex items-center gap-3">
        <div className="flex size-12 shrink-0 items-center justify-center rounded-xl bg-muted text-foreground">
          <Icon icon={Moon02Icon} className="size-6" />
        </div>
        <p className="text-sm leading-relaxed text-muted-foreground">
          Closed means closed: no overnight creep back to 100%, no silent drain.
        </p>
      </div>
      <div className="mt-6 space-y-2">
        {toggles.map((t) => (
          <ToggleRow key={t.label} label={t.label} on={t.on} />
        ))}
      </div>
    </div>
  );
}

function ToggleRow({ label, on }: { label: string; on: boolean }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-border/60 bg-muted/30 px-3.5 py-2.5">
      <span className={"text-sm " + (on ? "text-foreground" : "text-muted-foreground")}>
        {label}
      </span>
      <span
        aria-hidden
        className={
          "relative h-[18px] w-[30px] shrink-0 rounded-full transition-colors " +
          (on ? "bg-primary" : "bg-muted-foreground/25")
        }
      >
        <span
          className={
            "absolute top-0.5 left-0.5 size-[14px] rounded-full bg-white shadow-sm transition-transform " +
            (on ? "translate-x-3" : "translate-x-0")
          }
        />
      </span>
    </div>
  );
}

/* ==========================================================================
   2. THE PROBLEM: the emotional turn. A full, warm battery ages fastest,
   and heat and high charge multiply each other. Inline aging grid (SVG/CSS).
   ========================================================================== */

function Problem() {
  return (
    <section className="mx-auto max-w-3xl px-6 py-24">
      <div className="reveal grid items-center gap-12 sm:grid-cols-[1fr_auto]">
        <div className="max-w-md">
          <Eyebrow tone="muted">The problem</Eyebrow>
          <h2 className="font-display mt-3 text-3xl font-bold tracking-[-0.025em] text-balance sm:text-[2.5rem] sm:leading-[1.05]">
            A full, warm battery ages fastest.
          </h2>
          <p className="mt-5 leading-relaxed text-muted-foreground text-pretty">
            A lithium battery runs on two clocks at once. A cycle clock, worn by charging and
            discharging. And a calendar clock, chemistry that decays with time alone. A Mac left
            full and warm loses health without finishing a single cycle.
          </p>
          <p className="mt-4 leading-relaxed text-muted-foreground text-pretty">
            Two things do the real damage: a high charge level and heat. Alone, each is corrosive.
            Together they do not add up, they{" "}
            <span className="font-medium text-foreground">multiply</span>. Pinned at 100 percent
            while it runs warm is the worst place a battery can sit, and it is exactly where a
            laptop on a charger all day ends up.
          </p>
        </div>
        <AgingGrid />
      </div>
    </section>
  );
}

/** Monochrome heatmap: aging intensity across charge level (rows) and heat (cols). */
function AgingGrid() {
  const charges = [100, 90, 80, 60]; // top to bottom
  const temps = [20, 30, 40, 50]; // left to right
  const maxProduct = 100 * 50;
  return (
    <figure className="mx-auto w-full max-w-[260px]">
      <div className="rounded-2xl border border-border bg-card p-4 shadow-soft">
        <div className="grid grid-cols-[auto_1fr] gap-x-2">
          {/* Y label */}
          <div className="flex items-center">
            <span className="text-[10px] font-medium tracking-[0.14em] text-muted-foreground uppercase [writing-mode:vertical-rl] [transform:rotate(180deg)]">
              Charge
            </span>
          </div>
          <div className="grid grid-cols-4 gap-1">
            {charges.map((c) =>
              temps.map((t) => {
                const intensity = (c * t) / maxProduct; // 0..1
                const worst = c === 100 && t === 50;
                return (
                  <div
                    key={`${c}-${t}`}
                    className={
                      "relative aspect-square rounded-md " +
                      (worst ? "ring-2 ring-foreground/50" : "")
                    }
                    style={{
                      backgroundColor: "var(--foreground)",
                      opacity: 0.06 + intensity * 0.82,
                    }}
                  />
                );
              }),
            )}
          </div>
        </div>
        {/* X label */}
        <div className="mt-2 flex items-center justify-end">
          <span className="text-[10px] font-medium tracking-[0.14em] text-muted-foreground uppercase">
            Heat
          </span>
        </div>
      </div>
      <figcaption className="mt-3 text-center text-[12px] leading-relaxed text-muted-foreground">
        Aging roughly <span className="font-medium text-foreground tabular-nums">doubles</span> for
        every 10&nbsp;°C. Darkest corner is 100 percent and hot.
      </figcaption>
    </figure>
  );
}

/* ==========================================================================
   3. THE FIX: Battlify does the two hard habits for you. The MOMENTS become
   sequenced, alternating scenes, each with its own micro-visual.
   ========================================================================== */

function Fix() {
  return (
    <section id="features" className="scroll-mt-20 border-t border-border">
      <div className="mx-auto max-w-3xl px-6 pt-24 pb-8">
        <div className="reveal max-w-xl">
          <Eyebrow>The fix</Eyebrow>
          <h2 className="font-display mt-3 text-3xl font-bold tracking-[-0.025em] text-balance sm:text-[2.5rem] sm:leading-[1.05]">
            Battlify does the two hard parts for you.
          </h2>
          <p className="mt-5 leading-relaxed text-muted-foreground text-pretty">
            Staying off 100 percent and staying cool are simple ideas, and a real pain to do by
            hand. Battlify makes them automatic, then disappears into your menu bar.
          </p>
        </div>

        <div className="mt-16 space-y-20 sm:space-y-28">
          {MOMENTS.map((m, i) => (
            <Scene key={m.eye} moment={m} index={i} flip={i % 2 === 1} />
          ))}
        </div>
      </div>
    </section>
  );
}

function Scene({
  moment,
  index,
  flip,
}: {
  moment: (typeof MOMENTS)[number];
  index: number;
  flip: boolean;
}) {
  return (
    <div className="reveal grid items-center gap-8 sm:grid-cols-2 sm:gap-14">
      <div className={flip ? "sm:order-2" : ""}>
        <div className="flex items-center gap-3">
          <span className="font-display text-sm font-semibold text-primary tabular-nums">
            {String(index + 1).padStart(2, "0")}
          </span>
          <span className="h-px flex-1 bg-border" />
          <Eyebrow>{moment.eye}</Eyebrow>
        </div>
        <h3 className="font-display mt-4 text-2xl font-bold tracking-[-0.02em] text-balance">
          {moment.title}
        </h3>
        <p className="mt-3 max-w-md leading-relaxed text-muted-foreground text-pretty">
          {moment.body}
        </p>
        {"note" in moment && moment.note ? (
          <p className="mt-4 max-w-md rounded-xl border border-border bg-muted/40 px-3.5 py-2.5 text-[13px] leading-relaxed text-muted-foreground text-pretty">
            {moment.note}
          </p>
        ) : null}
      </div>
      <div className={flip ? "sm:order-1" : ""}>
        <SceneArt art={moment.art} />
      </div>
    </div>
  );
}

function SceneArt({ art }: { art: MomentArt }) {
  return (
    <div className="relative rounded-2xl border border-border bg-card p-6 shadow-soft">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-6 -top-6 bottom-0 rounded-[2rem] opacity-20 blur-2xl dark:opacity-30"
        style={{
          background: "radial-gradient(60% 60% at 50% 0%, var(--color-primary), transparent)",
        }}
      />
      <div className="relative">
        {art === "bar" ? <LimitArt /> : null}
        {art === "moon" ? <SleepArt /> : null}
        {art === "thermo" ? <HeatArt /> : null}
        {art === "led" ? <LedArt /> : null}
      </div>
    </div>
  );
}

function LimitArt() {
  return (
    <div>
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground">Charge limit</span>
        <span className="rounded-full bg-battlify-green/15 px-2.5 py-0.5 text-[11px] font-medium text-battlify-green">
          Holding
        </span>
      </div>
      <div className="mt-2 flex items-end gap-2">
        <span className="font-display text-5xl font-semibold tracking-[-0.03em] tabular-nums">
          80%
        </span>
        <span className="mb-1.5 text-sm text-muted-foreground">plugged in</span>
      </div>
      <div className="relative mt-5 h-2.5 w-full rounded-full bg-muted shadow-[inset_0_1px_2px_rgba(0,0,0,0.06)] dark:shadow-[inset_0_1px_2px_rgba(0,0,0,0.4)]">
        <div className="relative h-full w-4/5 rounded-full bg-gradient-to-r from-battlify-green/85 to-battlify-green">
          <span className="absolute top-1/2 -right-1 size-4 -translate-y-1/2 rounded-full border border-black/10 bg-white shadow-md dark:border-white/20" />
        </div>
      </div>
      <div className="mt-3 flex justify-between text-[11px] tabular-nums text-muted-foreground">
        <span>50%</span>
        <span className="font-medium text-foreground">limit 80%</span>
        <span>100%</span>
      </div>
    </div>
  );
}

function SleepArt() {
  // Map percentage to SVG y: 0% -> 96, 100% -> 16.
  const y = (pct: number) => 96 - (pct / 100) * 80;
  return (
    <div>
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-1.5 text-sm text-muted-foreground">
          <Icon icon={Moon02Icon} className="size-4" />
          Overnight
        </span>
        <span className="rounded-full bg-primary/15 px-2.5 py-0.5 text-[11px] font-medium text-primary">
          Enforced
        </span>
      </div>
      <svg
        viewBox="0 0 240 112"
        className="mt-4 w-full"
        role="img"
        aria-label="Battlify holds at 80 percent overnight while macOS alone creeps to 100 percent"
      >
        {/* baseline */}
        <line x1="16" y1="96" x2="224" y2="96" stroke="var(--border)" strokeWidth="1" />
        {/* macOS creep to 100% (the problem) */}
        <path
          d={`M16 ${y(80)} C 90 ${y(84)}, 150 ${y(98)}, 224 ${y(100)}`}
          fill="none"
          stroke="var(--muted-foreground)"
          strokeWidth="2"
          strokeDasharray="4 4"
          opacity="0.6"
        />
        {/* Battlify holds flat at 80% */}
        <path
          d={`M16 ${y(80)} L 224 ${y(80)}`}
          fill="none"
          stroke="var(--battlify-green)"
          strokeWidth="2.5"
          strokeLinecap="round"
        />
        <circle cx="224" cy={y(80)} r="3.5" fill="var(--battlify-green)" />
      </svg>
      <div className="mt-3 flex flex-col gap-1.5 text-[12px]">
        <span className="flex items-center gap-2">
          <span className="h-0.5 w-4 rounded-full bg-battlify-green" />
          <span className="text-foreground">Battlify holds 80%</span>
        </span>
        <span className="flex items-center gap-2">
          <span className="h-px w-4 rounded-full bg-muted-foreground/60" />
          <span className="text-muted-foreground">macOS alone creeps to 100%</span>
        </span>
      </div>
    </div>
  );
}

function HeatArt() {
  // 20°C..50°C scale; threshold 35, current 39 (paused).
  const pos = (t: number) => ((t - 20) / 30) * 100;
  return (
    <div>
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-1.5 text-sm text-muted-foreground">
          <Icon icon={ThermometerIcon} className="size-4" />
          Temperature
        </span>
        <span className="rounded-full bg-muted px-2.5 py-0.5 text-[11px] font-medium text-muted-foreground tabular-nums">
          Paused · 39&nbsp;°C
        </span>
      </div>
      <div className="mt-8 relative h-2.5 w-full rounded-full bg-muted shadow-[inset_0_1px_2px_rgba(0,0,0,0.06)] dark:shadow-[inset_0_1px_2px_rgba(0,0,0,0.4)]">
        {/* fill to current temp, neutral (not a charge-status color) */}
        <div
          className="h-full rounded-full bg-foreground/70"
          style={{ width: `${pos(39)}%` }}
        />
        {/* threshold marker */}
        <span
          className="absolute -top-1.5 h-[22px] w-0.5 -translate-x-1/2 rounded-full bg-foreground"
          style={{ left: `${pos(35)}%` }}
        />
        <span
          className="absolute -top-7 -translate-x-1/2 text-[11px] font-medium text-foreground tabular-nums"
          style={{ left: `${pos(35)}%` }}
        >
          35&nbsp;°C
        </span>
      </div>
      <div className="mt-3 flex justify-between text-[11px] tabular-nums text-muted-foreground">
        <span>20&nbsp;°C</span>
        <span>50&nbsp;°C</span>
      </div>
      <p className="mt-4 text-[13px] leading-relaxed text-muted-foreground text-pretty">
        Past your threshold, charging pauses and picks back up once it cools.
      </p>
    </div>
  );
}

function LedArt() {
  const tips: Array<{ label: string; state: "charging" | "holding" }> = [
    { label: "While filling", state: "charging" },
    { label: "At the limit", state: "holding" },
  ];
  return (
    <div>
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-1.5 text-sm text-muted-foreground">
          <Icon icon={Idea01Icon} className="size-4" />
          MagSafe LED
        </span>
      </div>
      <div className="mt-5 grid grid-cols-2 gap-4">
        {tips.map((tip) => {
          const holding = tip.state === "holding";
          const dot = holding ? "bg-battlify-green" : "bg-battlify-orange";
          const glow = holding ? "var(--battlify-green)" : "var(--battlify-orange)";
          return (
            <div
              key={tip.state}
              className="flex flex-col items-center rounded-xl border border-border bg-muted/30 p-4"
            >
              {/* cable connector */}
              <div className="flex h-6 w-12 items-center justify-center rounded-md bg-foreground/85">
                <span
                  className={"size-2.5 rounded-full " + dot}
                  style={{ boxShadow: `0 0 10px 2px ${glow}` }}
                />
              </div>
              <span
                className={
                  "mt-3 text-[11px] font-medium " +
                  (holding ? "text-battlify-green" : "text-battlify-orange")
                }
              >
                {holding ? "Green" : "Amber"}
              </span>
              <span className="mt-0.5 text-[12px] text-muted-foreground">{tip.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

/* ==========================================================================
   Showcase: a second window as proof, plus a compact spec strip.
   ========================================================================== */

function Showcase() {
  return (
    <section className="border-t border-border">
      <div className="reveal mx-auto max-w-3xl px-6 py-20">
        <div className="mx-auto mb-10 max-w-md text-center">
          <p className="leading-relaxed text-muted-foreground text-pretty">
            Everything lives in one small window and a menu bar icon you can read at a glance. No
            Dock clutter, no account, no fuss.
          </p>
        </div>
        <ScreenshotFrame>
          <WindowMockup variant="sleep" />
        </ScreenshotFrame>
        <dl className="mt-12 grid grid-cols-2 gap-x-6 gap-y-8 sm:grid-cols-4">
          {SPECS.map((s) => (
            <div key={s.n}>
              <dt className="font-display text-lg font-semibold tracking-[-0.01em]">{s.n}</dt>
              <dd className="mt-1 text-[13px] leading-relaxed text-muted-foreground">{s.l}</dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}

/* ==========================================================================
   4. PROOF: testimonials, then compatibility, as reassurance.
   ========================================================================== */

function Proof() {
  return (
    <section className="border-t border-border">
      <div className="mx-auto max-w-3xl px-6 py-24">
        <div className="reveal max-w-xl">
          <Eyebrow>Loved by Mac owners</Eyebrow>
          <h2 className="font-display mt-3 text-3xl font-bold tracking-[-0.025em] text-balance sm:text-[2.5rem] sm:leading-[1.05]">
            People simply stopped worrying about it.
          </h2>
        </div>
        <div className="reveal mt-10 gap-4 [column-fill:_balance] sm:columns-2">
          {TESTIMONIALS.map((t) => (
            <figure
              key={t.quote}
              className="mb-4 break-inside-avoid rounded-2xl border border-border bg-card p-5 shadow-soft"
            >
              <blockquote className="text-[15px] leading-relaxed text-foreground text-pretty">
                “{t.quote}”
              </blockquote>
              <figcaption className="mt-3 flex items-center gap-2 text-[13px] text-muted-foreground">
                <span className="font-medium text-foreground">{t.who}</span>
                <span aria-hidden>·</span>
                <span>{t.src}</span>
              </figcaption>
            </figure>
          ))}
        </div>

        <Supported />
      </div>
    </section>
  );
}

function Supported() {
  const items: Array<{ icon: IconSvgElement; title: string; status: string; ok: boolean }> = [
    { icon: CpuIcon, title: "Apple Silicon", status: "Supported", ok: true },
    { icon: LaptopIcon, title: "macOS 14 to 26", status: "Supported", ok: true },
    { icon: Cancel02Icon, title: "Intel Macs", status: "Not supported", ok: false },
  ];
  return (
    <div className="reveal mt-16">
      <h3 className="font-display text-xl font-bold tracking-[-0.02em]">
        Will it run on your Mac?
      </h3>
      <p className="mt-2 max-w-xl text-sm leading-relaxed text-muted-foreground text-pretty">
        Battlify is built for modern Apple Silicon MacBooks and supports both of Apple&apos;s
        charging schemes: the older CH0B/CH0C keys and the newer CHTE on macOS 26 &ldquo;Tahoe.&rdquo;
      </p>
      <div className="mt-6 grid gap-4 sm:grid-cols-3">
        {items.map((it) => (
          <div
            key={it.title}
            className="flex flex-col items-center rounded-2xl border border-border bg-card p-6 text-center shadow-soft transition-transform duration-200 hover:-translate-y-0.5"
          >
            <div
              className={
                "flex size-11 items-center justify-center rounded-xl " +
                (it.ok ? "bg-primary/10 text-primary" : "bg-muted text-muted-foreground")
              }
            >
              <Icon icon={it.icon} className="size-5" />
            </div>
            <h4 className="mt-3 text-sm font-medium">{it.title}</h4>
            <p
              className={
                "mt-1 inline-flex items-center gap-1 text-xs font-medium " +
                (it.ok ? "text-primary" : "text-muted-foreground")
              }
            >
              {it.ok ? <Icon icon={Tick02Icon} className="size-3.5" /> : null}
              {it.status}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ==========================================================================
   5. THE MATH: pricing reframed around value. $199 battery vs $2.99.
   ========================================================================== */

function Pricing() {
  const trialFeatures = ["Every feature unlocked", "No account needed", "Runs for 30 days"];
  const licenseFeatures = [
    "Everything in the trial",
    "Yours forever, no subscription",
    "Free updates for life",
    "Locked to one Mac (movable)",
  ];
  return (
    <section className="border-t border-border">
      <div className="mx-auto max-w-3xl px-6 py-24">
        <div id="pricing" className="reveal scroll-mt-20 max-w-xl">
          <Eyebrow>The math</Eyebrow>
          <h2 className="font-display mt-3 text-3xl font-bold tracking-[-0.025em] text-balance sm:text-[2.5rem] sm:leading-[1.05]">
            A new battery is about{" "}
            <span className="tabular-nums text-muted-foreground line-through decoration-2">
              $199
            </span>
            . Battlify is <span className="tabular-nums">{PRICE}</span>.
          </h2>
          <p className="mt-5 leading-relaxed text-muted-foreground text-pretty">
            Apple rates a modern MacBook battery for around{" "}
            <span className="font-medium text-foreground tabular-nums">1,000</span> cycles. How you
            treat it in between decides whether it gets there. Battlify is a one-time {PRICE}, free
            to try for 30 days, so the only thing you risk is a worn out battery.
          </p>
        </div>

        <div className="reveal mt-10 grid items-start gap-4 sm:grid-cols-2">
          {/* Free trial */}
          <div className="flex flex-col rounded-2xl border border-border bg-card p-6 shadow-soft">
            <h3 className="font-medium">Free trial</h3>
            <div className="mt-2 flex items-baseline gap-1.5">
              <span className="font-display text-4xl font-bold tracking-[-0.02em] tabular-nums">
                $0
              </span>
              <span className="text-sm text-muted-foreground">for 30 days</span>
            </div>
            <p className="mt-4 text-xs font-medium tracking-wide text-muted-foreground uppercase">
              What&apos;s included
            </p>
            <ul className="mt-3 space-y-2.5">
              {trialFeatures.map((f) => (
                <li key={f} className="flex items-center gap-2.5 text-sm">
                  <Icon icon={Tick02Icon} className="size-4 text-muted-foreground" />
                  {f}
                </li>
              ))}
            </ul>
            <DownloadButton size="lg" variant="outline" className="mt-8 h-11 w-full rounded-2xl">
              Download
            </DownloadButton>
          </div>

          {/* License */}
          <div className="relative flex flex-col rounded-2xl border border-primary/40 bg-card p-6 shadow-elevated ring-1 ring-primary/15">
            <h3 className="font-medium">License · Single Mac</h3>
            <div className="mt-2 flex items-baseline gap-1.5">
              <span className="font-display text-4xl font-bold tracking-[-0.02em] tabular-nums">
                {PRICE}
              </span>
              <span className="text-sm text-muted-foreground">one-time</span>
            </div>
            <p className="mt-3 text-sm leading-relaxed text-muted-foreground text-pretty">
              Pay once, keep it forever. A replacement battery at the Apple Store runs about{" "}
              <span className="tabular-nums">$199</span>. This is <span className="tabular-nums">{PRICE}</span>.
            </p>
            <p className="mt-4 text-xs font-medium tracking-wide text-muted-foreground uppercase">
              What&apos;s included
            </p>
            <ul className="mt-3 space-y-2.5">
              {licenseFeatures.map((f) => (
                <li key={f} className="flex items-center gap-2.5 text-sm">
                  <Icon icon={Tick02Icon} className="size-4 text-primary" />
                  {f}
                </li>
              ))}
            </ul>
            <BuyButton size="lg" className="mt-8 h-11 w-full rounded-2xl">
              Buy Battlify · {PRICE}
            </BuyButton>
          </div>
        </div>
        <p className="mt-5 text-center text-xs text-muted-foreground">
          Secure checkout via Dodo Payments · applicable taxes handled at checkout.
        </p>
      </div>
    </section>
  );
}

/* ==========================================================================
   6. FAQ (feeds JSON-LD, keep the data contract) + closing CTA.
   ========================================================================== */

function Faq() {
  return (
    <section className="border-t border-border">
      <div className="mx-auto max-w-3xl px-6 py-24">
        <div className="reveal text-center">
          <Eyebrow>FAQ</Eyebrow>
          <h2 className="font-display mx-auto mt-3 max-w-md text-3xl font-bold tracking-[-0.025em] text-balance sm:text-[2.5rem] sm:leading-[1.05]">
            Questions, answered.
          </h2>
        </div>
        <dl className="reveal mt-10 divide-y divide-border rounded-2xl border border-border bg-card shadow-soft">
          {FAQS.map((item) => (
            <div key={item.q} className="p-6">
              <dt className="font-medium">{item.q}</dt>
              <dd className="mt-2 text-sm leading-relaxed text-muted-foreground text-pretty">
                {item.a}
              </dd>
            </div>
          ))}
        </dl>
      </div>
    </section>
  );
}

function ClosingCta() {
  return (
    <section className="relative overflow-hidden border-t border-border">
      <div
        aria-hidden
        className="pointer-events-none absolute bottom-[-10rem] left-1/2 h-[30rem] w-[44rem] -translate-x-1/2 rounded-full opacity-20 blur-[130px] dark:opacity-40"
        style={{ background: "radial-gradient(closest-side, var(--color-primary), transparent)" }}
      />
      <div className="reveal relative mx-auto max-w-3xl px-6 py-28 text-center">
        <h2 className="font-display mx-auto max-w-xl text-3xl font-bold tracking-[-0.03em] text-balance sm:text-[2.75rem] sm:leading-[1.05]">
          Give your battery its years back.
        </h2>
        <p className="mx-auto mt-5 max-w-md leading-relaxed text-muted-foreground text-pretty">
          Set your limit once and forget it. Battlify keeps the promise in the background, awake or
          asleep, cool or warm.
        </p>
        <div className="mt-8 flex flex-col items-center justify-center gap-3 sm:flex-row">
          <DownloadButton size="lg" className="h-11 rounded-2xl px-6 text-[15px]">
            Download
          </DownloadButton>
          <BuyButton size="lg" variant="outline" className="h-11 rounded-2xl px-6 text-[15px]">
            Buy · {PRICE}
          </BuyButton>
        </div>
        <p className="mt-6 text-[13px] text-muted-foreground">
          Free for 30 days. Built by Nischal, a solo developer who loves small, native Mac software
          that just works.
        </p>
      </div>
    </section>
  );
}

/* ========================================================================== */

function Footer() {
  const cols: Array<{
    title: string;
    links: Array<{ label: string; href: string; external?: boolean }>;
  }> = [
    {
      title: "Product",
      links: [
        { label: "Pricing", href: "#pricing" },
        { label: "Blog", href: "/blog" },
        { label: "Download", href: LINKS.releases, external: true },
      ],
    },
    {
      title: "Connect",
      links: [
        { label: "GitHub", href: LINKS.github, external: true },
        { label: "Report an issue", href: LINKS.feedback, external: true },
      ],
    },
  ];
  return (
    <footer className="border-t border-border">
      <div className="mx-auto grid max-w-3xl gap-10 px-6 py-14 sm:grid-cols-[1fr_auto_auto_auto]">
        <div>
          <Logo />
        </div>
        {cols.map((c) => (
          <div key={c.title} className="sm:min-w-28">
            <p className="text-sm font-semibold">{c.title}</p>
            <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
              {c.links.map((l) => (
                <li key={l.label}>
                  <a
                    href={l.href}
                    {...(l.external ? { target: "_blank", rel: "noreferrer" } : {})}
                    className="transition-colors hover:text-foreground"
                  >
                    {l.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ))}
        <div className="sm:min-w-28">
          <p className="text-sm font-semibold">Legal</p>
          <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
            <li>
              <Link to="/legal/privacy" className="transition-colors hover:text-foreground">
                Privacy policy
              </Link>
            </li>
            <li>
              <Link to="/legal/terms" className="transition-colors hover:text-foreground">
                Terms of service
              </Link>
            </li>
          </ul>
        </div>
      </div>
      <div className="border-t border-border">
        <div className="mx-auto flex max-w-3xl flex-col items-center justify-between gap-4 px-6 py-6 text-sm text-muted-foreground sm:flex-row">
          <p>© 2026 Battlify · built by broisnischal</p>
          <div className="flex items-center gap-4">
            <a
              href="https://x.com/broisnischal"
              target="_blank"
              rel="noreferrer"
              aria-label="X"
              className="transition-colors hover:text-foreground"
            >
              <Icon icon={NewTwitterRectangleIcon} className="size-4" />
            </a>
            <a
              href={LINKS.github}
              target="_blank"
              rel="noreferrer"
              aria-label="GitHub"
              className="transition-colors hover:text-foreground"
            >
              <Icon icon={GithubIcon} className="size-4" />
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}

/* ========================================================================== */

export function LandingPage() {
  return (
    <div className="min-h-svh bg-background text-foreground">
      <Nav />
      <main>
        <Hero />
        <Problem />
        <Fix />
        <Showcase />
        <Proof />
        <Pricing />
        <Faq />
        <ClosingCta />
      </main>
      <Footer />
    </div>
  );
}
