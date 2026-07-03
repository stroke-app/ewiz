import { SiGithub, SiX } from "@icons-pack/react-simple-icons";
import { Link } from "@tanstack/react-router";
import {
  BatteryChargingIcon,
  CheckIcon,
  CpuIcon,
  DownloadIcon,
  HeartIcon,
  LightbulbIcon,
  MonitorIcon,
  MoonIcon,
  ThermometerIcon,
  XIcon,
} from "lucide-react";

import { useCheckout } from "#/components/buy-button";
import { BatteryMark, Logo } from "#/components/logo";
import { Button } from "#/components/ui/button";

import { LINKS, MOMENTS } from "./landing-data";

const PRICE = "$2.99";

function Container({ className, children }: { className?: string; children: React.ReactNode }) {
  return <div className={"mx-auto max-w-3xl px-6 " + (className ?? "")}>{children}</div>;
}

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
      <DownloadIcon />
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
  tone?: "blue" | "rose" | "green";
}) {
  const color =
    tone === "rose" ? "text-rose-500" : tone === "green" ? "text-battlify-green" : "text-primary";
  return (
    <p className={"text-[11px] font-semibold tracking-[0.16em] uppercase " + color}>{children}</p>
  );
}

/* ========================================================================== */

function Nav() {
  return (
    <header className="sticky top-0 z-50 bg-background/80 backdrop-blur-xl">
      <div className="mx-auto grid h-16 max-w-3xl grid-cols-[1fr_auto_1fr] items-center px-6">
        <Link to="/" className="justify-self-start">
          <Logo />
        </Link>
        <nav className="hidden items-center gap-8 justify-self-center text-sm text-muted-foreground sm:flex">
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
        <div className="flex items-center gap-1.5 justify-self-end">
          <Button
            render={<a href={LINKS.github} target="_blank" rel="noreferrer" aria-label="GitHub" />}
            nativeButton={false}
            variant="ghost"
            size="icon-sm"
          >
            <SiGithub className="size-4" />
          </Button>
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
        className="pointer-events-none absolute top-[-6rem] left-1/2 h-[34rem] w-[46rem] -translate-x-1/2 rounded-full opacity-40 blur-[120px]"
        style={{ background: "radial-gradient(closest-side, var(--color-primary), transparent)" }}
      />
      <Container className="relative pt-20 pb-10 text-center">
        <Eyebrow>Introducing Battlify</Eyebrow>
        <h1 className="font-display mx-auto mt-5 max-w-xl text-4xl font-bold tracking-tight text-balance sm:text-5xl">
          A new era of battery care begins here.
        </h1>
        <p className="mx-auto mt-5 max-w-md text-base leading-relaxed text-muted-foreground text-pretty">
          Fast, native, and designed for people who care about their Macs. Rethink how you charge,
          sleep, and look after your battery.
        </p>
        <div className="mt-8 flex justify-center">
          <DownloadButton size="default">Download</DownloadButton>
        </div>
        <p className="mt-4 text-[13px] text-muted-foreground">
          No account required. Free for 30 days.
        </p>
      </Container>

      <Container className="relative pb-20">
        <ScreenshotFrame>
          <WindowMockup variant="charging" />
        </ScreenshotFrame>
      </Container>
    </section>
  );
}

/** Blue-glow panel the app screenshots sit on, à la sql.studio. */
function ScreenshotFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="relative">
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-8 -top-6 bottom-0 rounded-[2rem] opacity-50 blur-2xl"
        style={{ background: "radial-gradient(60% 60% at 50% 0%, var(--color-primary), transparent)" }}
      />
      <div className="relative rounded-[20px] bg-gradient-to-b from-primary/30 via-primary/5 to-transparent p-2 sm:p-2.5">
        {children}
      </div>
    </div>
  );
}

function WindowMockup({ variant }: { variant: "charging" | "sleep" }) {
  const sidebar = [
    { icon: BatteryChargingIcon, label: "Charging", key: "charging" },
    { icon: MoonIcon, label: "Sleep", key: "sleep" },
    { icon: ThermometerIcon, label: "Health", key: "health" },
    { icon: LightbulbIcon, label: "MagSafe", key: "magsafe" },
  ] as const;

  return (
    <div className="overflow-hidden rounded-2xl border border-border bg-card">
      <div className="flex items-center gap-2 border-b border-border/60 bg-background/40 px-4 py-3">
        <span className="size-3 rounded-full bg-[#ff5f57]" />
        <span className="size-3 rounded-full bg-[#febc2e]" />
        <span className="size-3 rounded-full bg-[#28c840]" />
        <span className="mx-auto flex items-center gap-1.5 text-xs text-muted-foreground">
          <BatteryMark className="size-3.5 text-muted-foreground" />
          Battlify — Settings
        </span>
      </div>
      <div className="grid sm:grid-cols-[180px_1fr]">
        <aside className="hidden flex-col gap-1 border-r border-border/60 bg-background/30 p-3 sm:flex">
          {sidebar.map(({ icon: Icon, label, key }) => (
            <div
              key={key}
              className={
                "flex items-center gap-2.5 rounded-lg px-3 py-2 text-sm " +
                (key === variant ? "bg-primary/15 text-primary" : "text-muted-foreground")
              }
            >
              <Icon className="size-4" />
              {label}
            </div>
          ))}
        </aside>
        {variant === "charging" ? <ChargingPane /> : <SleepPane />}
      </div>
    </div>
  );
}

function ChargingPane() {
  const toggles = ["Hold at limit while asleep", "Pause charging when hot", "Drive MagSafe LED"];
  return (
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
          <ToggleRow key={t} label={t} />
        ))}
      </div>
    </div>
  );
}

function SleepPane() {
  const toggles = [
    "Stop charging before sleep",
    "Keep awake on wall power",
    "Disable Power Nap",
    "Silence Bluetooth on sleep",
  ];
  return (
    <div className="p-6">
      <div className="flex items-center justify-between">
        <span className="text-sm text-muted-foreground">When the lid closes</span>
        <span className="rounded-full bg-primary/15 px-2 py-0.5 text-[11px] font-medium text-primary">
          Enforced
        </span>
      </div>
      <div className="mt-4 flex items-center gap-3">
        <div className="flex size-12 items-center justify-center rounded-xl bg-muted text-foreground">
          <MoonIcon className="size-6" />
        </div>
        <p className="text-sm text-muted-foreground">
          Closed means closed — no overnight creep back to 100%, no silent drain.
        </p>
      </div>
      <div className="mt-6 space-y-2">
        {toggles.map((t) => (
          <ToggleRow key={t} label={t} />
        ))}
      </div>
    </div>
  );
}

function ToggleRow({ label }: { label: string }) {
  return (
    <div className="flex items-center justify-between rounded-lg border border-border/60 bg-background/40 px-3 py-2.5">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="flex h-4 w-7 items-center justify-end rounded-full bg-primary p-0.5">
        <span className="size-3 rounded-full bg-white" />
      </span>
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
    <Container className="py-20">
      <div id="features" className="scroll-mt-20">
        <Eyebrow tone="rose">
          <span className="inline-flex items-center gap-1.5">
            <HeartIcon className="size-3 fill-rose-500" /> Made with love
          </span>
        </Eyebrow>
        <h2 className="font-display mt-3 text-3xl font-bold tracking-tight text-balance">
          What sets Battlify apart?
        </h2>

        <div className="mt-8 flex flex-col gap-1">
          {MOMENTS.map((m, i) => {
            const Icon = FEATURE_ICONS[m.eye as keyof typeof FEATURE_ICONS] ?? BatteryChargingIcon;
            return (
              <div
                key={m.eye}
                className={
                  "rounded-lg px-4 py-3.5 transition-colors " +
                  (i === 0 ? "bg-card" : "hover:bg-card/60")
                }
              >
                <div className="flex items-center gap-2.5">
                  <Icon className="size-4 text-muted-foreground" />
                  <h3 className="font-medium">{m.title}</h3>
                </div>
                <p className="mt-1 pl-[26px] text-sm leading-relaxed text-muted-foreground">
                  {m.body}
                </p>
              </div>
            );
          })}
        </div>
      </div>
    </Container>
  );
}

/* ========================================================================== */

function Showcase() {
  return (
    <Container className="py-8">
      <ScreenshotFrame>
        <WindowMockup variant="sleep" />
      </ScreenshotFrame>
    </Container>
  );
}

function Developer() {
  return (
    <Container className="py-16">
      <div className="rounded-xl border border-border bg-card px-5 py-4">
        <div className="flex items-center gap-2.5">
          <HeartIcon className="size-4 fill-rose-500 text-rose-500" />
          <h3 className="font-medium">Made by a single developer</h3>
        </div>
        <p className="mt-1 pl-[26px] text-sm leading-relaxed text-muted-foreground">
          Battlify is crafted by a solo developer, Nischal, in spare time — with a passion for small,
          native Mac software that just works, stays out of your way, and anyone can afford.
        </p>
      </div>
    </Container>
  );
}

/* ========================================================================== */

function Supported() {
  const items = [
    { icon: CpuIcon, title: "Apple Silicon", status: "Supported", ok: true },
    { icon: MonitorIcon, title: "macOS 14 – 26", status: "Supported", ok: true },
    { icon: XIcon, title: "Intel Macs", status: "Not supported", ok: false },
  ];
  return (
    <Container className="py-16">
      <h2 className="font-display text-3xl font-bold tracking-tight text-balance">
        Which Macs are supported?
      </h2>
      <p className="mt-3 max-w-xl text-muted-foreground">
        Battlify is built for modern Apple Silicon MacBooks and supports both of Apple&apos;s
        charging schemes — the older CH0B/CH0C keys and the newer CHTE on macOS 26 &ldquo;Tahoe.&rdquo;
      </p>
      <div className="mt-8 grid gap-4 sm:grid-cols-3">
        {items.map((it) => (
          <div
            key={it.title}
            className="flex flex-col items-center rounded-xl border border-border bg-card p-6 text-center"
          >
            <div className="flex size-11 items-center justify-center rounded-xl bg-muted text-foreground">
              <it.icon className="size-5" />
            </div>
            <h3 className="mt-3 text-sm font-medium">{it.title}</h3>
            <p
              className={
                "mt-1 text-xs font-medium " + (it.ok ? "text-battlify-green" : "text-muted-foreground")
              }
            >
              {it.status}
            </p>
          </div>
        ))}
      </div>
    </Container>
  );
}

/* ========================================================================== */

function Pricing() {
  const trialFeatures = ["Every feature unlocked", "No account needed", "Runs for 30 days"];
  const licenseFeatures = [
    "Everything in the trial",
    "Yours forever — no subscription",
    "Free updates for life",
    "Locked to one Mac (movable)",
  ];
  return (
    <Container className="py-20">
      <div id="pricing" className="scroll-mt-20 text-center">
        <Eyebrow tone="green">Pricing</Eyebrow>
        <h2 className="font-display mx-auto mt-3 max-w-md text-3xl font-bold tracking-tight text-balance">
          Try it free, then own it forever for {PRICE}.
        </h2>
      </div>

      <div className="mt-10 grid gap-4 sm:grid-cols-2">
        {/* Free trial */}
        <div className="flex flex-col rounded-2xl border border-border bg-card p-6">
          <h3 className="font-medium">Free trial</h3>
          <div className="mt-2 flex items-baseline gap-1.5">
            <span className="font-display text-4xl font-bold tracking-tight">$0</span>
            <span className="text-sm text-muted-foreground">for 30 days</span>
          </div>
          <p className="mt-4 text-xs font-medium tracking-wide text-muted-foreground uppercase">
            What&apos;s included
          </p>
          <ul className="mt-3 space-y-2.5">
            {trialFeatures.map((f) => (
              <li key={f} className="flex items-center gap-2.5 text-sm">
                <CheckIcon className="size-4 shrink-0 text-muted-foreground" />
                {f}
              </li>
            ))}
          </ul>
          <DownloadButton size="lg" variant="outline" className="mt-8 w-full">
            Download
          </DownloadButton>
        </div>

        {/* License */}
        <div className="relative flex flex-col rounded-2xl border border-primary/50 bg-card p-6 ring-1 ring-primary/20">
          <h3 className="font-medium">License · Single Mac</h3>
          <div className="mt-2 flex items-baseline gap-1.5">
            <span className="font-display text-4xl font-bold tracking-tight">{PRICE}</span>
            <span className="text-sm text-muted-foreground">one-time</span>
          </div>
          <p className="mt-3 text-sm leading-relaxed text-muted-foreground">
            Pay once, keep it forever. A replacement battery at the Apple Store runs about $199 —
            this is $2.99.
          </p>
          <p className="mt-4 text-xs font-medium tracking-wide text-muted-foreground uppercase">
            What&apos;s included
          </p>
          <ul className="mt-3 space-y-2.5">
            {licenseFeatures.map((f) => (
              <li key={f} className="flex items-center gap-2.5 text-sm">
                <CheckIcon className="size-4 shrink-0 text-battlify-green" />
                {f}
              </li>
            ))}
          </ul>
          <BuyButton size="lg" className="mt-8 w-full">
            Buy Battlify · {PRICE}
          </BuyButton>
        </div>
      </div>
      <p className="mt-5 text-center text-xs text-muted-foreground">
        Secure checkout via Dodo Payments · applicable taxes handled at checkout.
      </p>
    </Container>
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
    <footer className="mt-8 border-t border-border">
      <Container className="grid gap-10 py-14 sm:grid-cols-[1fr_auto_auto_auto]">
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
      </Container>
      <Container className="flex flex-col items-center justify-between gap-4 border-t border-border py-6 text-sm text-muted-foreground sm:flex-row">
        <p>© 2026 Battlify · built by broisnischal</p>
        <div className="flex items-center gap-4">
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
      </Container>
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
