import { SiGithub, SiX } from "@icons-pack/react-simple-icons";
import { Link } from "@tanstack/react-router";
import {
  BatteryChargingIcon,
  CheckIcon,
  DownloadIcon,
  HeartIcon,
  LightbulbIcon,
  MoonIcon,
  ThermometerIcon,
} from "lucide-react";

import { useCheckout } from "#/components/buy-button";
import { BatteryMark, Logo } from "#/components/logo";
import { Button } from "#/components/ui/button";

import { LINKS, MOMENTS } from "./landing-data";

const PRICE = "$2.99";

function DownloadButton({
  size = "lg",
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
      <DownloadIcon />
      {children ?? "Download"}
    </Button>
  );
}

function BuyButton({
  size = "lg",
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
  tone?: "blue" | "rose";
}) {
  return (
    <p
      className={
        "text-xs font-semibold tracking-[0.16em] uppercase " +
        (tone === "rose" ? "text-rose-400" : "text-primary")
      }
    >
      {children}
    </p>
  );
}

/* ========================================================================== */

function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/70 backdrop-blur-xl">
      <div className="mx-auto grid h-16 max-w-6xl grid-cols-[1fr_auto_1fr] items-center px-6">
        <Link to="/" className="justify-self-start">
          <Logo />
        </Link>
        <nav className="hidden items-center gap-8 justify-self-center text-sm text-muted-foreground md:flex">
          <a href="#pricing" className="transition-colors hover:text-foreground">
            Pricing
          </a>
          <a
            href={LINKS.releases}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-foreground"
          >
            Changelog
          </a>
          <a
            href={LINKS.github}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-foreground"
          >
            Community
          </a>
        </nav>
        <div className="justify-self-end">
          <Button render={<Link to="/login" />} variant="outline" size="sm" nativeButton={false}>
            Sign in
          </Button>
        </div>
      </div>
    </header>
  );
}

/* ========================================================================== */

function Hero() {
  return (
    <section className="relative overflow-hidden">
      <div
        aria-hidden
        className="pointer-events-none absolute top-[-8rem] left-1/2 h-[40rem] w-[52rem] -translate-x-1/2 rounded-full opacity-45 blur-[130px]"
        style={{ background: "radial-gradient(closest-side, var(--color-primary), transparent)" }}
      />
      <div className="relative mx-auto max-w-3xl px-6 pt-24 pb-12 text-center">
        <Eyebrow>Introducing Battlify</Eyebrow>
        <h1 className="font-display mx-auto mt-5 max-w-2xl text-5xl font-bold tracking-tight text-balance sm:text-6xl">
          A new era of battery care begins here.
        </h1>
        <p className="mx-auto mt-6 max-w-lg text-lg leading-relaxed text-muted-foreground text-pretty">
          Fast, native, and designed for people who care about their Macs. Rethink how you charge,
          sleep, and look after your battery.
        </p>
        <div className="mt-9 flex justify-center">
          <DownloadButton size="lg">Download</DownloadButton>
        </div>
        <p className="mt-4 text-sm text-muted-foreground">
          No account required. Free for 30 days.
        </p>
      </div>

      <div className="relative mx-auto max-w-4xl px-6 pb-24">
        <WindowMockup />
      </div>
    </section>
  );
}

/** Wide macOS-style app window — Battlify's Settings surface. */
function WindowMockup() {
  const sidebar = [
    { icon: BatteryChargingIcon, label: "Charging", active: true },
    { icon: MoonIcon, label: "Sleep", active: false },
    { icon: ThermometerIcon, label: "Health", active: false },
    { icon: LightbulbIcon, label: "MagSafe", active: false },
  ];
  const toggles = [
    { label: "Hold at limit while asleep", on: true },
    { label: "Pause charging when hot", on: true },
    { label: "Drive MagSafe LED", on: true },
  ];
  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-card shadow-2xl shadow-primary/10">
      {/* titlebar */}
      <div className="flex items-center gap-2 border-b border-border/60 bg-background/40 px-4 py-3">
        <span className="size-3 rounded-full bg-[#ff5f57]" />
        <span className="size-3 rounded-full bg-[#febc2e]" />
        <span className="size-3 rounded-full bg-[#28c840]" />
        <span className="mx-auto flex items-center gap-1.5 text-xs text-muted-foreground">
          <BatteryMark className="size-3.5 text-muted-foreground" />
          Battlify — Settings
        </span>
      </div>
      {/* body */}
      <div className="grid sm:grid-cols-[190px_1fr]">
        <aside className="hidden flex-col gap-1 border-r border-border/60 bg-background/30 p-3 sm:flex">
          {sidebar.map(({ icon: Icon, label, active }) => (
            <div
              key={label}
              className={
                "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm " +
                (active
                  ? "bg-primary/15 text-primary"
                  : "text-muted-foreground")
              }
            >
              <Icon className="size-4" />
              {label}
            </div>
          ))}
        </aside>
        <div className="p-6">
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Charge limit</span>
            <span className="rounded-full bg-battlify-green/15 px-2 py-0.5 text-[11px] font-medium text-battlify-green">
              Holding
            </span>
          </div>
          <div className="mt-3 flex items-end gap-3">
            <span className="font-display text-6xl font-semibold tracking-tight">80%</span>
            <span className="mb-2 text-sm text-muted-foreground">buffered · plugged in</span>
          </div>
          <div className="mt-4 h-2.5 w-full overflow-hidden rounded-full bg-muted">
            <div className="h-full w-4/5 rounded-full bg-battlify-green" />
          </div>
          <div className="mt-6 space-y-2">
            {toggles.map((t) => (
              <div
                key={t.label}
                className="flex items-center justify-between rounded-lg border border-border/60 bg-background/40 px-3 py-2.5"
              >
                <span className="text-sm text-muted-foreground">{t.label}</span>
                <span className="flex h-4 w-7 items-center justify-end rounded-full bg-primary p-0.5">
                  <span className="size-3 rounded-full bg-white" />
                </span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ========================================================================== */

const FEATURE_ICONS = {
  "Charge limit": BatteryChargingIcon,
  "Sleep-safe": MoonIcon,
  "Heat-aware": ThermometerIcon,
  "MagSafe LED": LightbulbIcon,
} as const;

function Features() {
  return (
    <section id="features" className="mx-auto max-w-3xl scroll-mt-20 px-6 py-24">
      <Eyebrow tone="rose">
        <span className="inline-flex items-center gap-1.5">
          <HeartIcon className="size-3.5 fill-rose-400" /> Made with love
        </span>
      </Eyebrow>
      <h2 className="font-display mt-3 text-4xl font-bold tracking-tight text-balance">
        What sets Battlify apart?
      </h2>

      <div className="mt-10 flex flex-col gap-3">
        {MOMENTS.map((m) => {
          const Icon = FEATURE_ICONS[m.eye as keyof typeof FEATURE_ICONS] ?? BatteryChargingIcon;
          return (
            <div
              key={m.eye}
              className="rounded-xl border border-border bg-card px-5 py-4 transition-colors hover:border-primary/40"
            >
              <div className="flex items-center gap-3">
                <Icon className="size-4 text-primary" />
                <h3 className="font-medium">{m.title}</h3>
              </div>
              <p className="mt-1.5 pl-7 text-sm leading-relaxed text-muted-foreground">{m.body}</p>
            </div>
          );
        })}
      </div>
    </section>
  );
}

/* ========================================================================== */

function Showcase() {
  const cards = [
    {
      icon: BatteryChargingIcon,
      title: "Set it and forget it",
      body: "Pick a ceiling once. Battlify holds it with a buffer so the charger isn't clicking all day.",
    },
    {
      icon: MoonIcon,
      title: "Closed means closed",
      body: "Stops the overnight creep back to 100% and the silent drain of a sleeping Mac.",
    },
    {
      icon: LightbulbIcon,
      title: "Status at a glance",
      body: "The MagSafe LED glows amber while charging, green the instant it's holding.",
    },
  ];
  return (
    <section className="mx-auto max-w-6xl px-6 py-12">
      <div className="grid gap-4 md:grid-cols-3">
        {cards.map((c) => (
          <div key={c.title} className="rounded-2xl border border-border bg-card p-6">
            <div className="flex h-28 items-center justify-center rounded-xl bg-gradient-to-br from-primary/15 to-transparent">
              <c.icon className="size-8 text-primary" />
            </div>
            <h3 className="mt-4 font-medium">{c.title}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">{c.body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

/* ========================================================================== */

function Developer() {
  return (
    <section className="mx-auto max-w-2xl px-6 py-24 text-center">
      <div className="mx-auto flex size-11 items-center justify-center rounded-full bg-rose-400/10 text-rose-400 ring-1 ring-rose-400/20">
        <HeartIcon className="size-5 fill-rose-400" />
      </div>
      <h2 className="font-display mt-5 text-3xl font-bold tracking-tight text-balance">
        Made by a single developer
      </h2>
      <p className="mt-4 leading-relaxed text-muted-foreground text-pretty">
        Battlify is crafted by a solo developer, Nischal, in spare time — with a passion for small,
        native Mac software that just works, stays out of your way, and anyone can afford.
      </p>
    </section>
  );
}

/* ========================================================================== */

function Supported() {
  const items = [
    { title: "Apple Silicon", note: "M1 and later", status: "Supported", ok: true },
    { title: "macOS 14 – 26", note: "Sonoma through Tahoe", status: "Supported", ok: true },
    { title: "Intel Macs", note: "no charge-control SMC keys", status: "Not planned", ok: false },
  ];
  return (
    <section className="mx-auto max-w-6xl px-6 py-16">
      <div className="mx-auto max-w-2xl text-center">
        <h2 className="font-display text-4xl font-bold tracking-tight text-balance">
          Which Macs are supported?
        </h2>
        <p className="mt-3 text-muted-foreground">
          Battlify is built for modern Apple Silicon MacBooks and supports both of Apple&apos;s
          charging schemes — the older CH0B/CH0C keys and the newer CHTE on macOS 26 &ldquo;Tahoe.&rdquo;
        </p>
      </div>
      <div className="mx-auto mt-10 grid max-w-4xl gap-4 sm:grid-cols-3">
        {items.map((it) => (
          <div key={it.title} className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center justify-between">
              <h3 className="font-medium">{it.title}</h3>
              <span
                className={
                  "rounded-full px-2 py-0.5 text-[11px] font-medium " +
                  (it.ok
                    ? "bg-battlify-green/15 text-battlify-green"
                    : "bg-muted text-muted-foreground")
                }
              >
                {it.status}
              </span>
            </div>
            <p className="mt-2 text-sm text-muted-foreground">{it.note}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

/* ========================================================================== */

function Pricing() {
  const trialFeatures = ["Every feature unlocked", "No account needed", "Runs for 30 days"];
  const licenseFeatures = [
    "Everything in the free trial",
    "Yours forever — no subscription",
    "Free updates for life",
    "Locked to one Mac (movable)",
  ];
  return (
    <section id="pricing" className="mx-auto max-w-6xl scroll-mt-20 px-6 py-24">
      <div className="mx-auto max-w-2xl text-center">
        <Eyebrow>Pricing</Eyebrow>
        <h2 className="font-display mt-3 text-4xl font-bold tracking-tight text-balance">
          Try it free, then own it forever for {PRICE}.
        </h2>
        <p className="mt-3 text-muted-foreground">
          A replacement battery at the Apple Store runs about $199. Battlify is {PRICE} — once — and
          helps you avoid ever needing one.
        </p>
      </div>

      <div className="mx-auto mt-12 grid max-w-3xl gap-4 sm:grid-cols-2">
        {/* Free trial */}
        <div className="flex flex-col rounded-3xl border border-border bg-card p-8">
          <h3 className="font-medium">Free trial</h3>
          <div className="mt-3 flex items-baseline gap-1.5">
            <span className="font-display text-4xl font-bold tracking-tight">$0</span>
            <span className="text-sm text-muted-foreground">for 30 days</span>
          </div>
          <p className="mt-2 text-sm text-muted-foreground">
            Download and use every feature. No card, no account.
          </p>
          <DownloadButton size="lg" variant="outline" className="mt-6 w-full">
            Download
          </DownloadButton>
          <ul className="mt-6 space-y-2.5 border-t border-border/60 pt-6">
            {trialFeatures.map((f) => (
              <li key={f} className="flex items-center gap-2.5 text-sm">
                <CheckIcon className="size-4 shrink-0 text-muted-foreground" />
                {f}
              </li>
            ))}
          </ul>
        </div>

        {/* License */}
        <div className="relative flex flex-col rounded-3xl border border-primary/50 bg-card p-8 ring-1 ring-primary/20">
          <span className="absolute -top-3 right-6 rounded-full bg-primary px-3 py-0.5 text-xs font-medium text-primary-foreground">
            Own it
          </span>
          <h3 className="font-medium">License</h3>
          <div className="mt-3 flex items-baseline gap-1.5">
            <span className="font-display text-4xl font-bold tracking-tight">{PRICE}</span>
            <span className="text-sm text-muted-foreground">one-time</span>
          </div>
          <p className="mt-2 text-sm text-muted-foreground">
            Perpetual license. Pay once, keep it forever.
          </p>
          <BuyButton size="lg" className="mt-6 w-full">
            Buy Battlify · {PRICE}
          </BuyButton>
          <ul className="mt-6 space-y-2.5 border-t border-border/60 pt-6">
            {licenseFeatures.map((f) => (
              <li key={f} className="flex items-center gap-2.5 text-sm">
                <CheckIcon className="size-4 shrink-0 text-battlify-green" />
                {f}
              </li>
            ))}
          </ul>
        </div>
      </div>
      <p className="mx-auto mt-6 max-w-xl text-center text-xs text-muted-foreground">
        Secure checkout via Dodo Payments · applicable taxes handled at checkout.
      </p>
    </section>
  );
}

/* ========================================================================== */

function Footer() {
  const cols: Array<{
    title: string;
    links: Array<{ label: string; href: string; external?: boolean; to?: string }>;
  }> = [
    {
      title: "Product",
      links: [
        { label: "Features", href: "#features" },
        { label: "Pricing", href: "#pricing" },
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
      <div className="mx-auto grid max-w-6xl gap-10 px-6 py-16 sm:grid-cols-2 lg:grid-cols-4">
        <div className="lg:col-span-2">
          <Logo />
          <p className="mt-3 max-w-xs text-sm text-muted-foreground">
            Menu-bar battery care for Apple Silicon Macs. Charge limiting, sleep-safe, heat-aware.
          </p>
        </div>
        {cols.map((c) => (
          <div key={c.title}>
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
        <div>
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
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-6 text-sm text-muted-foreground sm:flex-row">
          <p>© 2026 Battlify · built by broisnischal</p>
          <div className="flex items-center gap-5">
            <a
              href="https://x.com/broisnischal"
              target="_blank"
              rel="noreferrer"
              aria-label="X"
              className="transition-colors hover:text-foreground"
            >
              <SiX className="size-4" />
            </a>
            <a
              href={LINKS.github}
              target="_blank"
              rel="noreferrer"
              aria-label="GitHub"
              className="transition-colors hover:text-foreground"
            >
              <SiGithub className="size-4" />
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
        <Features />
        <Showcase />
        <Developer />
        <Supported />
        <Pricing />
      </main>
      <Footer />
    </div>
  );
}
