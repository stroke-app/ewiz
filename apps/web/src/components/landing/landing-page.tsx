import { SiGithub } from "@icons-pack/react-simple-icons";
import { Link } from "@tanstack/react-router";
import {
  ArrowRightIcon,
  BatteryChargingIcon,
  CheckIcon,
  CpuIcon,
  HeartIcon,
  LightbulbIcon,
  MoonIcon,
  ShieldCheckIcon,
  ThermometerIcon,
  ZapIcon,
} from "lucide-react";

import { useCheckout } from "#/components/buy-button";
import { BatteryMark, Logo } from "#/components/logo";
import { Button } from "#/components/ui/button";

import { LINKS, MOMENTS, SPECS, TESTIMONIALS } from "./landing-data";

const PRICE = "$2.99";

function BuyButton({
  size = "lg",
  className,
  children,
}: {
  size?: "default" | "sm" | "lg";
  className?: string;
  children?: React.ReactNode;
}) {
  const { buy, loading } = useCheckout();
  return (
    <Button size={size} className={className} onClick={buy} disabled={loading} type="button">
      <ZapIcon />
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
        "text-xs font-semibold tracking-[0.14em] uppercase " +
        (tone === "rose" ? "text-rose-400" : "text-primary")
      }
    >
      {children}
    </p>
  );
}

/* -------------------------------------------------------------------------- */

function Nav() {
  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-background/70 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
        <Link to="/">
          <Logo />
        </Link>
        <nav className="hidden items-center gap-8 text-sm text-muted-foreground md:flex">
          <a href="#features" className="transition-colors hover:text-foreground">
            Features
          </a>
          <a href="#how" className="transition-colors hover:text-foreground">
            How it works
          </a>
          <a href="#pricing" className="transition-colors hover:text-foreground">
            Pricing
          </a>
          <a
            href={LINKS.github}
            target="_blank"
            rel="noreferrer"
            className="transition-colors hover:text-foreground"
          >
            Source
          </a>
        </nav>
        <div className="flex items-center gap-2">
          <Button render={<Link to="/login" />} variant="ghost" size="sm" nativeButton={false}>
            Sign in
          </Button>
          <BuyButton size="sm" />
        </div>
      </div>
    </header>
  );
}

/* -------------------------------------------------------------------------- */

function Hero() {
  return (
    <section className="relative overflow-hidden">
      {/* ambient blue glow */}
      <div
        aria-hidden
        className="pointer-events-none absolute top-[-10rem] left-1/2 h-[36rem] w-[46rem] -translate-x-1/2 rounded-full opacity-40 blur-[120px]"
        style={{ background: "radial-gradient(closest-side, var(--color-primary), transparent)" }}
      />
      <div className="relative mx-auto max-w-3xl px-6 pt-20 pb-10 text-center">
        <Eyebrow>Introducing Battlify</Eyebrow>
        <h1 className="font-display mt-4 text-5xl font-bold tracking-tight text-balance sm:text-6xl">
          A longer life for your Mac&apos;s battery.
        </h1>
        <p className="mx-auto mt-5 max-w-xl text-lg text-muted-foreground text-pretty">
          Battlify holds your charge where it should be, keeps a closed lid actually closed, and
          never lets heat cook your cells — quietly, from the menu bar.
        </p>
        <div className="mt-8 flex items-center justify-center gap-3">
          <BuyButton size="lg">Buy Battlify · {PRICE}</BuyButton>
          <Button
            render={<a href="#how" aria-label="See how it works" />}
            variant="outline"
            size="lg"
            nativeButton={false}
          >
            See how it works
          </Button>
        </div>
        <p className="mt-4 text-sm text-muted-foreground">
          Free for 30 days. {PRICE} to own it forever — no subscription.
        </p>
      </div>

      <div className="relative mx-auto max-w-3xl px-6 pb-20">
        <HeroMockup />
      </div>
    </section>
  );
}

/** A dark macOS menu-bar popover mock — Battlify's actual surface. */
function HeroMockup() {
  const toggles = [
    { icon: MoonIcon, label: "Sleep-safe enforcement" },
    { icon: ThermometerIcon, label: "Heat-aware charging" },
    { icon: LightbulbIcon, label: "MagSafe LED status" },
  ];
  return (
    <div className="relative rounded-2xl border border-border bg-card p-2 shadow-2xl shadow-primary/10">
      <div className="rounded-xl border border-border/60 bg-background/60 p-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <BatteryMark className="size-4 text-battlify-green" />
            <span className="text-sm font-medium">Battlify</span>
          </div>
          <span className="rounded-full bg-battlify-green/15 px-2 py-0.5 text-[11px] font-medium text-battlify-green">
            Holding
          </span>
        </div>

        <div className="mt-5 flex items-end gap-3">
          <span className="font-display text-5xl font-semibold tracking-tight">80%</span>
          <span className="mb-1.5 text-sm text-muted-foreground">limit · buffered</span>
        </div>
        <div className="mt-3 h-2.5 w-full overflow-hidden rounded-full bg-muted">
          <div className="h-full w-4/5 rounded-full bg-battlify-green" />
        </div>

        <div className="mt-5 space-y-2">
          {toggles.map(({ icon: Icon, label }) => (
            <div
              key={label}
              className="flex items-center justify-between rounded-lg border border-border/60 bg-card/60 px-3 py-2"
            >
              <span className="flex items-center gap-2 text-sm text-muted-foreground">
                <Icon className="size-4" />
                {label}
              </span>
              <span className="flex h-4 w-7 items-center justify-end rounded-full bg-primary p-0.5">
                <span className="size-3 rounded-full bg-white" />
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

/* -------------------------------------------------------------------------- */

const FEATURE_ICONS = {
  "Charge limit": BatteryChargingIcon,
  "Sleep-safe": MoonIcon,
  "Heat-aware": ThermometerIcon,
  "MagSafe LED": LightbulbIcon,
} as const;

function Features() {
  return (
    <section id="features" className="mx-auto max-w-6xl scroll-mt-20 px-6 py-24">
      <Eyebrow tone="rose">
        <span className="inline-flex items-center gap-1.5">
          <HeartIcon className="size-3.5 fill-rose-400" /> Made with care
        </span>
      </Eyebrow>
      <h2 className="font-display mt-3 max-w-2xl text-4xl font-bold tracking-tight text-balance">
        What sets Battlify apart?
      </h2>
      <p className="mt-3 max-w-2xl text-muted-foreground">
        Four small jobs, done exactly right. No dashboards, no background bloat — just a menu-bar
        icon that keeps your battery healthy while you forget it exists.
      </p>

      <div className="mt-12 grid gap-4 sm:grid-cols-2">
        {MOMENTS.map((m) => {
          const Icon = FEATURE_ICONS[m.eye as keyof typeof FEATURE_ICONS] ?? BatteryChargingIcon;
          return (
            <div
              key={m.eye}
              className="group rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40"
            >
              <div className="flex size-10 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-primary/20">
                <Icon className="size-5" />
              </div>
              <p className="mt-4 text-xs font-semibold tracking-wide text-primary uppercase">
                {m.eye}
              </p>
              <h3 className="mt-1 text-lg font-semibold">{m.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{m.body}</p>
              {"note" in m && m.note ? (
                <p className="mt-3 border-t border-border/60 pt-3 text-xs text-muted-foreground/80">
                  {m.note}
                </p>
              ) : null}
            </div>
          );
        })}
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */

function HowItWorks() {
  const nodes = [
    {
      icon: BatteryChargingIcon,
      title: "Menu-bar app",
      body: "A tiny SwiftUI app that runs as you — no Dock icon, no privileges. It's just the face and the controls.",
    },
    {
      icon: CpuIcon,
      title: "Local helper daemon",
      body: "battlify-helper runs as root and owns the charging loop. One install-time password, then it works on its own.",
    },
    {
      icon: ShieldCheckIcon,
      title: "Fail-safe by design",
      body: "Kill the helper and it re-enables charging on the way out. Battlify can never leave your Mac unable to charge.",
    },
  ];
  return (
    <section id="how" className="scroll-mt-20 border-y border-border bg-card/40">
      <div className="mx-auto max-w-6xl px-6 py-24">
        <Eyebrow>Under the hood</Eyebrow>
        <h2 className="font-display mt-3 max-w-2xl text-4xl font-bold tracking-tight text-balance">
          Native, quiet, and impossible to trap you.
        </h2>
        <p className="mt-3 max-w-2xl text-muted-foreground">
          Battlify never writes to your Mac&apos;s SMC directly. It talks over a local socket to a
          small helper that does the privileged work — and bows out safely if anything goes wrong.
        </p>

        <div className="mt-12 grid gap-4 md:grid-cols-3">
          {nodes.map((n, i) => (
            <div key={n.title} className="relative rounded-2xl border border-border bg-card p-6">
              <div className="flex size-10 items-center justify-center rounded-xl bg-primary/10 text-primary ring-1 ring-primary/20">
                <n.icon className="size-5" />
              </div>
              <h3 className="mt-4 text-base font-semibold">{n.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{n.body}</p>
              {i < nodes.length - 1 ? (
                <ArrowRightIcon className="absolute top-1/2 -right-[13px] hidden size-5 -translate-y-1/2 text-border md:block" />
              ) : null}
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */

function Specs() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-20">
      <div className="grid gap-px overflow-hidden rounded-2xl border border-border bg-border sm:grid-cols-2 lg:grid-cols-4">
        {SPECS.map((s) => (
          <div key={s.n} className="bg-background p-6">
            <p className="font-display text-2xl font-semibold tracking-tight">{s.n}</p>
            <p className="mt-1 text-sm text-muted-foreground">{s.l}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */

function Testimonials() {
  return (
    <section className="mx-auto max-w-6xl px-6 py-16">
      <Eyebrow tone="rose">Loved by people who forget it&apos;s there</Eyebrow>
      <div className="mt-8 columns-1 gap-4 sm:columns-2 lg:columns-3 [&>*]:mb-4">
        {TESTIMONIALS.map((t) => (
          <figure
            key={t.quote}
            className="break-inside-avoid rounded-2xl border border-border bg-card p-5"
          >
            <blockquote className="text-sm leading-relaxed">&ldquo;{t.quote}&rdquo;</blockquote>
            <figcaption className="mt-3 text-xs text-muted-foreground">
              {t.who} · <span className="text-muted-foreground/70">{t.src}</span>
            </figcaption>
          </figure>
        ))}
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */

function Pricing() {
  const included = [
    "Charge limiting with smart buffer",
    "Sleep-safe lid enforcement",
    "Heat-aware charging",
    "MagSafe LED status",
    "One-time top-up to 100%",
    "Free updates, forever",
  ];
  return (
    <section id="pricing" className="mx-auto max-w-6xl scroll-mt-20 px-6 py-24">
      <div className="mx-auto max-w-xl text-center">
        <Eyebrow>Pricing</Eyebrow>
        <h2 className="font-display mt-3 text-4xl font-bold tracking-tight text-balance">
          Great app. Almost-free price.
        </h2>
        <p className="mt-3 text-muted-foreground">
          A replacement battery at the Apple Store runs about $199. Battlify is {PRICE} — once — and
          it helps you avoid ever needing one.
        </p>
      </div>

      <div className="mx-auto mt-10 max-w-md rounded-3xl border border-border bg-card p-8">
        <div className="flex items-baseline gap-2">
          <span className="font-display text-5xl font-bold tracking-tight">{PRICE}</span>
          <span className="text-muted-foreground">one-time</span>
        </div>
        <p className="mt-1 text-sm text-muted-foreground">
          Own it forever. No subscription, no account required to run it.
        </p>
        <BuyButton size="lg" className="mt-6 w-full">
          Buy Battlify · {PRICE}
        </BuyButton>
        <p className="mt-3 text-center text-xs text-muted-foreground">
          Secure checkout via Dodo Payments · free for 30 days
        </p>
        <ul className="mt-6 space-y-2.5 border-t border-border/60 pt-6">
          {included.map((f) => (
            <li key={f} className="flex items-center gap-2.5 text-sm">
              <CheckIcon className="size-4 shrink-0 text-battlify-green" />
              {f}
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */

function Maker() {
  return (
    <section className="border-y border-border bg-card/40">
      <div className="mx-auto max-w-3xl px-6 py-24 text-center">
        <blockquote className="font-display text-2xl leading-relaxed font-medium text-balance sm:text-3xl">
          &ldquo;I kept pulling my MacBook out of my bag warm and half-drained. macOS wouldn&apos;t
          stop doing it, so I wrote something that would. Battlify is that fix — small, native, and
          priced so anyone can just have it.&rdquo;
        </blockquote>
        <figcaption className="mt-6 text-sm text-muted-foreground">
          — Nischal, maker of Battlify
        </figcaption>
      </div>
    </section>
  );
}

/* -------------------------------------------------------------------------- */

function Footer() {
  const cols = [
    {
      title: "Product",
      links: [
        { label: "Features", href: "#features", external: false },
        { label: "How it works", href: "#how", external: false },
        { label: "Pricing", href: "#pricing", external: false },
      ],
    },
    {
      title: "Get it",
      links: [
        { label: "Download", href: LINKS.releases, external: true },
        { label: "Source", href: LINKS.github, external: true },
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
      </div>
      <div className="border-t border-border">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-4 px-6 py-6 text-sm text-muted-foreground sm:flex-row">
          <p>© 2026 Battlify · built by broisnischal</p>
          <div className="flex items-center gap-5">
            <Link to="/legal/privacy" className="transition-colors hover:text-foreground">
              Privacy
            </Link>
            <Link to="/legal/terms" className="transition-colors hover:text-foreground">
              Terms
            </Link>
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

/* -------------------------------------------------------------------------- */

export function LandingPage() {
  return (
    <div className="min-h-svh bg-background text-foreground">
      <Nav />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Specs />
        <Testimonials />
        <Pricing />
        <Maker />
      </main>
      <Footer />
    </div>
  );
}
