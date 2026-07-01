import {
  ArrowRightIcon,
  BluetoothIcon,
  CheckIcon,
  ChevronDownIcon,
  GaugeIcon,
  HeartIcon,
  LoaderCircleIcon,
  MoonStarIcon,
  ThermometerIcon,
  ZapIcon,
} from "lucide-react";
import { type ReactNode, useEffect, useRef } from "react";

import { useCheckout } from "#/components/buy-button";
import { ClosedLidCard, MenuPopover, SettingsWindow } from "#/components/landing/app-mockups";
import {
  LINKS,
  MOMENTS,
  type MomentArt,
  SPECS,
  TESTIMONIALS,
} from "#/components/landing/landing-data";
import { cn } from "#/lib/utils";

/* The battery logo, drawn to match the product's own mark. */
function BatteryLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden>
      <rect x="2" y="7" width="17" height="10" rx="2.5" stroke="var(--hold)" strokeWidth="1.8" />
      <rect x="4" y="9" width="9" height="6" rx="1" fill="var(--hold)" />
      <rect x="20" y="10" width="2" height="4" rx="1" fill="var(--hold)" />
      <path d="M9.6 8.4L7.6 12h2.1l-.4 3L12 11h-1.9z" fill="#fff" />
    </svg>
  );
}

function Tag({ children, dot }: { children: ReactNode; dot?: boolean }) {
  return (
    <span className="tag">
      {dot ? <span className="dot" /> : null}
      {children}
    </span>
  );
}

export function LandingPage() {
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            e.target.classList.add("in");
            io.unobserve(e.target);
          }
        }
      },
      { threshold: 0.12 },
    );
    root.querySelectorAll(".rv").forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  return (
    <div className="blf" ref={rootRef}>
      <Header />
      <main id="top">
        <Hero />
        <Testimonials />
        <Problem />
        <ClosedMeansClosed />
        <div id="features">
          {MOMENTS.map((m) => (
            <Moment key={m.title} {...m} />
          ))}
        </div>
        <EveryControl />
        <HowItWorks />
        <Specs />
        <Pricing />
        <Mission />
      </main>
      <Footer />
    </div>
  );
}

function Header() {
  const headerRef = useRef<HTMLElement>(null);
  const { buy, loading } = useCheckout();

  // Solid on scroll + invert to dark chrome while over dark sections.
  useEffect(() => {
    const hdr = headerRef.current;
    if (!hdr) return;
    const darks = Array.from(
      document.querySelectorAll(".problem, .moment.dark, .showcase.dark, .how"),
    );
    const onScroll = () => {
      hdr.classList.toggle("solid", window.scrollY > 40);
      const navH = 62;
      let onDark = false;
      for (const el of darks) {
        const r = el.getBoundingClientRect();
        if (r.top <= navH && r.bottom >= navH) {
          onDark = true;
          break;
        }
      }
      hdr.classList.toggle("on-dark", onDark);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header className="blf-header" ref={headerRef}>
      <div className="wrap nav">
        <a href="#top" className="brand">
          <BatteryLogo />
          Battlify
        </a>
        <nav className="nl">
          <a href="#problem">The problem</a>
          <a href="#features">Features</a>
          <a href="#how">How it works</a>
          <a href="#pricing">Pricing</a>
        </nav>
        <button type="button" className="buy" onClick={buy} disabled={loading}>
          {loading ? "Opening…" : "Buy · $2.99"}
        </button>
      </div>
    </header>
  );
}

function Hero() {
  return (
    <section className="hero">
      <div className="hero-grid">
        <div className="hero-copy">
          <Tag dot>macOS menu-bar app · Apple Silicon</Tag>
          <h1>
            Your Mac shouldn&apos;t <span className="g">drain in your bag.</span>
          </h1>
          <p className="sub">
            Battlify is a tiny menu-bar app that makes a closed lid actually closed, caps charging
            at a healthy level, and keeps things cool, so your battery stays healthy for years. It
            just sits quietly in the background and does its job.
          </p>
          <div className="cta">
            <BuyButton>Buy Battlify for $2.99</BuyButton>
            <a className="btn btn-ghost" href="#problem">
              See what it fixes
            </a>
          </div>
          <p className="price-note">
            <b>$2.99.</b> Once. No subscription. Free for 30 days of use.
          </p>
          <div className="chips">
            <span className="chip-stat">
              <span className="cd" />
              <b>0.0%/hr</b> while closed
            </span>
            <span className="chip-stat">
              <b>80%</b> charge cap
            </span>
            <span className="chip-stat">Native · Apple Silicon</span>
          </div>
        </div>

        <div className="hero-visual">
          <MenuPopover />
        </div>
      </div>

      <a className="scrolldown" href="#problem">
        scroll
        <ChevronDownIcon />
      </a>
    </section>
  );
}

function Testimonials() {
  return (
    <section className="quotes">
      <p className="qhead">Loved by people who love their Macs</p>
      <div className="marquee">
        <div className="track">
          {[...TESTIMONIALS, ...TESTIMONIALS].map((t, i) => (
            <figure className="qcard" key={i}>
              <p>&ldquo;{t.quote}&rdquo;</p>
              <figcaption className="who">
                <b>{t.who}</b> · {t.src}
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}

function Problem() {
  return (
    <section className="problem" id="problem">
      <div className="wrap problem-grid">
        <div className="rv">
          <Tag>The problem</Tag>
          <h2 style={{ marginTop: 16 }}>
            Closed should <span className="lg">mean closed.</span>
          </h2>
          <p className="lede-strong">
            You shut the lid, but macOS keeps working in the dark. Power Nap syncs, Bluetooth keeps
            hunting for your earbuds, and the network wakes it over and over. You open it later to a{" "}
            <em>warm, half-empty</em> Mac.
          </p>
          <p>
            Battlify shuts all of that down the moment the lid closes, then puts it back when you
            open up. Here&apos;s a real history log from my own Mac running Battlify. Hours closed,
            and zero drop:
          </p>
        </div>
        <div className="rv">
          <ClosedLidCard />
        </div>
      </div>
    </section>
  );
}

function ClosedMeansClosed() {
  return (
    <section className="showcase light">
      <div className="wrap showcase-grid">
        <div className="rv">
          <Tag>Lid-closed automation</Tag>
          <h2 style={{ marginTop: 16 }}>One switch for the whole shutdown.</h2>
          <p>
            Super Save flips everything that drains a closed Mac, all at once, then puts it all back
            the moment you lift the lid.
          </p>
          <ul className="checklist">
            <li>
              <BluetoothIcon />
              <span>
                <b>No earbud hijacking.</b> Bluetooth goes off while closed, so your AirPods stay
                with your phone.
              </span>
            </li>
            <li>
              <MoonStarIcon />
              <span>
                <b>No secret wakeups.</b> Power Nap and network wake are held down, not just asked
                nicely.
              </span>
            </li>
            <li>
              <CheckIcon />
              <span>
                <b>Restored on wake.</b> Wi-Fi and Bluetooth come back exactly as you left them.
              </span>
            </li>
          </ul>
        </div>
        <div className="win-hold rv">
          <SettingsWindow tab="sleep" />
        </div>
      </div>
    </section>
  );
}

function EveryControl() {
  return (
    <section className="showcase deep flip">
      <div className="wrap showcase-grid">
        <div className="rv">
          <Tag>Full control</Tag>
          <h2 style={{ marginTop: 16 }}>Tune every last detail.</h2>
          <p>
            Battlify isn&apos;t a black box like Apple&apos;s Optimized Charging. Every behavior is
            a switch you own.
          </p>
          <ul className="checklist">
            <li>
              <ZapIcon />
              <span>
                <b>Enforcement.</b> Stop charging before sleep, or keep the Mac awake so the limit
                never lapses.
              </span>
            </li>
            <li>
              <ThermometerIcon />
              <span>
                <b>Heat.</b> Pause charging past a maximum temperature you choose.
              </span>
            </li>
            <li>
              <GaugeIcon />
              <span>
                <b>Discharge.</b> Plugged in above your limit? Run off the battery until it drifts
                back down.
              </span>
            </li>
          </ul>
        </div>
        <div className="win-hold rv">
          <SettingsWindow tab="charging" />
        </div>
      </div>
    </section>
  );
}

function Moment({
  eye,
  title,
  body,
  note,
  tone,
  flip,
  art,
}: {
  eye: string;
  title: string;
  body: string;
  note?: string;
  tone: "light" | "dark";
  flip: boolean;
  art: MomentArt;
}) {
  return (
    <section className={cn("moment", tone, flip && "flip")}>
      <div className="wrap m-in">
        <div className="rv">
          <Tag>{eye}</Tag>
          <h2 style={{ marginTop: 16 }}>{title}</h2>
          <p>{body}</p>
          {note ? <div className="m-note">{note}</div> : null}
        </div>
        <div className="m-art rv">
          <MomentArt art={art} />
        </div>
      </div>
    </section>
  );
}

function MomentArt({ art }: { art: MomentArt }) {
  switch (art) {
    case "bar":
      return (
        <div className="art-bar">
          <i />
          <u />
        </div>
      );
    case "thermo":
      return (
        <div className="thermo">
          <i />
        </div>
      );
    case "moon":
      return <div className="moon" style={{ color: "#C9CFD8" }} />;
    case "led":
      return (
        <div className="art-led">
          <span className="b amber" />
          <span className="arrow">→</span>
          <span className="b green" />
        </div>
      );
  }
}

function HowItWorks() {
  return (
    <section className="how" id="how">
      <div className="wrap">
        <div className="head rv">
          <Tag>How it works</Tag>
          <h2 style={{ marginTop: 16 }}>Two pieces, so nothing you use runs as root.</h2>
          <p className="lede">
            Writing the charge-control keys needs root, but a GUI never should. So I split Battlify
            into two pieces that talk to each other over a local socket.
          </p>
        </div>

        <div className="arch rv">
          <div className="node">
            <div className="t">runs as you</div>
            <h4>
              Menu-bar app <span className="chip">SwiftUI</span>
            </h4>
            <p>
              The part you touch. It never writes to the SMC directly. It just asks the helper, and
              shows you exactly what&apos;s going on. No Dock icon, no window left running.
            </p>
          </div>

          <div className="conn">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
              <path d="M8 8L16 8M8 8l3-3M8 8l3 3M16 16L8 16M16 16l-3-3M16 16l-3 3" />
            </svg>
            local socket
          </div>

          <div className="node">
            <div className="t">runs as root, once installed</div>
            <h4>
              battlify-helper <span className="chip">LaunchDaemon</span>
            </h4>
            <p>
              A tiny daemon that owns the enforcement loop, starts at every boot, and does the
              privileged work with no interface of its own. One password prompt to install it, and
              after that it runs on its own.
            </p>
          </div>
        </div>

        <div className="safety rv">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            <path d="M9 12l2 2 4-4" />
          </svg>
          <div>
            <b>It can never leave your Mac unable to charge.</b>
            <p>
              If the helper is ever stopped or killed, it re-enables charging on the way out.
              Fail-safe by design.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

function Specs() {
  return (
    <section className="specs">
      <div className="wrap specs-grid">
        {SPECS.map((s) => (
          <div className="spec rv" key={s.n}>
            <div className="n">{s.n}</div>
            <div className="l">{s.l}</div>
          </div>
        ))}
      </div>
    </section>
  );
}

function Pricing() {
  return (
    <section className="pricing" id="pricing">
      <div className="pricing-grid">
        <div className="phil rv">
          <Tag>Pricing</Tag>
          <h2 style={{ marginTop: 16 }}>Great software. Great price.</h2>
          <p>
            A worn-out MacBook battery costs around $150 to replace. Battlify helps you put that day
            off for years, for less than you&apos;d spend on a coffee, and you only pay once.
          </p>
          <ul>
            <li>
              <CheckIcon />
              Every feature included, nothing locked away
            </li>
            <li>
              <CheckIcon />
              Free for 30 days, counted only on days you use it
            </li>
            <li>
              <CheckIcon />
              Yours forever, with every future update
            </li>
          </ul>
        </div>

        <div className="pricecard rv">
          <span className="k">Own it forever</span>
          <div className="amt">
            $2.99<small>one-time</small>
          </div>
          <p className="free">Free for 30 days. No account needed to start.</p>
          <BuyButton className="btn">Buy Battlify</BuyButton>
          <p className="note">
            Plus tax. Checkout is handled securely by Dodo Payments, and your license arrives the
            moment you pay.
          </p>
        </div>
      </div>
    </section>
  );
}

function Mission() {
  return (
    <section className="mission">
      <div className="inner rv">
        <div className="av">N</div>
        <blockquote>
          &ldquo;I want Battlify to be something you feel genuinely good about installing. So I keep
          it as cheap as I possibly can, so it feels like a great deal and just about anyone can
          afford it. Honestly, I just hope it makes this tiny corner of your day a little nicer. If
          it buys your battery a few extra years, I&apos;ve done my job.&rdquo;
        </blockquote>
        <p className="sig">
          Thanks for reading this far, and for every note and bug report you&apos;ve sent my way. It
          really does keep me going.{" "}
          <HeartIcon
            style={{ width: 14, height: 14, display: "inline", verticalAlign: "-2px" }}
            fill="currentColor"
          />
        </p>
        <p className="signame">Nischal</p>
      </div>
    </section>
  );
}

/** Primary buy button in the bespoke `.btn` style, wired to Dodo checkout. */
function BuyButton({ children, className }: { children: ReactNode; className?: string }) {
  const { buy, loading } = useCheckout();
  return (
    <button
      type="button"
      className={cn("btn btn-primary", className)}
      onClick={buy}
      disabled={loading}
    >
      {loading ? (
        <>
          <LoaderCircleIcon className="animate-spin" />
          Opening checkout…
        </>
      ) : (
        <>
          {children}
          <ArrowRightIcon />
        </>
      )}
    </button>
  );
}

function Footer() {
  return (
    <footer className="blf-footer">
      <div className="wrap">
        <div className="foot">
          <div>
            <a href="#top" className="brand">
              <BatteryLogo />
              Battlify
            </a>
            <p>
              A tiny menu-bar app that keeps macOS from wrecking your battery. Built for Apple
              Silicon.
            </p>
          </div>
          <div className="fcols">
            <div className="fcol">
              <h5>Product</h5>
              <a href="#features">Features</a>
              <a href="#how">How it works</a>
              <a href="#pricing">Pricing</a>
            </div>
            <div className="fcol">
              <h5>Get it</h5>
              <a href={LINKS.releases} target="_blank" rel="noopener noreferrer">
                Releases
              </a>
              <a href="#pricing">Buy Battlify</a>
            </div>
            <div className="fcol">
              <h5>Source</h5>
              <a href={LINKS.github} target="_blank" rel="noopener noreferrer">
                GitHub
              </a>
              <a href={LINKS.feedback} target="_blank" rel="noopener noreferrer">
                Feedback
              </a>
            </div>
          </div>
        </div>
        <div className="fbot">
          <span>© 2026 Battlify · built by broisnischal</span>
          <span>Made for the menu bar 🔋</span>
        </div>
      </div>
    </footer>
  );
}
