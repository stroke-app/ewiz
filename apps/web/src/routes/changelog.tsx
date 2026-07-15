import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowUpRightIcon, DownloadIcon } from "lucide-react";

import { LINKS } from "#/components/landing/landing-data";
import { Logo } from "#/components/logo";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/changelog")({
  head: () => ({
    ...seo({
      title: "Changelog",
      description:
        "What's new in Battlify. Every release is included with your license, so you can update whenever you like.",
      path: "/changelog",
    }),
  }),
  component: ChangelogPage,
});

type Change = { label: string; body: string };
type Release = { v: string; date: string; note?: string; latest?: boolean; changes?: Change[] };

/**
 * Release timeline, newest first. Mirrors the GitHub releases (versions, dates,
 * and notes). Full, authoritative notes for every version live on GitHub, which
 * each version links to (see releaseUrl).
 */
const RELEASES: Release[] = [
  {
    v: "0.10.1",
    date: "July 14, 2026",
    latest: true,
    changes: [
      {
        label: "App icon in notifications",
        body: "Fixed the missing app icon that could show up on Battlify notifications.",
      },
    ],
  },
  {
    v: "0.10.0",
    date: "July 14, 2026",
    changes: [
      {
        label: "New app icon",
        body: "Refreshed the app icon, and fixed save-mode persistence so your settings stick across restarts.",
      },
    ],
  },
  {
    v: "0.9.3",
    date: "July 5, 2026",
    changes: [
      {
        label: "Keep-awake on battery",
        body: "Always Active is now opt-in on battery power, no longer limited to AC, so you can keep your Mac awake on the go when you choose to.",
      },
    ],
  },
  {
    v: "0.9.2",
    date: "July 5, 2026",
    changes: [
      {
        label: "Force-discharge fix",
        body: "Discharge is now gated on physical adapter presence, ending an oscillation where the battery would flip between charging and discharging.",
      },
      {
        label: "Lid display-off, icons, and themes",
        body: "Folds in v0.9.1: display-off on lid close, HugeIcons battery glyphs, light and dark themes, new animations, plus notification and battery-accuracy fixes.",
      },
    ],
  },
  {
    v: "0.9.0",
    date: "July 4, 2026",
    changes: [
      {
        label: "Charge history",
        body: "New History view with clear controls, charging and battery sessions, a daily summary, and high-charge time tracking.",
      },
    ],
  },
  { v: "0.8.4", date: "July 1, 2026", note: "Fixes and refinements." },
  { v: "0.8.3", date: "July 1, 2026", note: "Fixes and refinements." },
  { v: "0.8.2", date: "July 1, 2026", note: "Fixes and refinements." },
  { v: "0.8.1", date: "July 1, 2026", note: "First public release." },
];

/** Forward-looking, not commitments. Edit freely as the real roadmap firms up. */
const ROADMAP: Change[] = [
  {
    label: "Scheduled charge limits",
    body: "Automate your ceiling by time of day, so it can ease up overnight and tighten during the workday without you touching it.",
  },
  {
    label: "Deeper health insights",
    body: "Richer trends in History: cycle counts, capacity over time, and how much high-charge time you've avoided.",
  },
  {
    label: "Localization",
    body: "Battlify in more languages, starting with the most-requested from the community.",
  },
];

function releaseUrl(v: string) {
  return `https://github.com/broisnischal/battlify/releases/tag/v${v}`;
}

function ChangelogPage() {
  return (
    <div className="min-h-svh bg-background text-foreground">
      <header className="sticky top-0 z-50 border-b border-border/60 bg-background/70 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-between px-6">
          <Link to="/">
            <Logo />
          </Link>
          <Link
            to="/"
            className="text-sm text-muted-foreground transition-colors hover:text-foreground"
          >
            ← Back to Battlify
          </Link>
        </div>
      </header>

      <main className="mx-auto max-w-3xl px-6 py-16">
        <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">Changelog</p>
        <h1 className="font-display mt-3 text-4xl font-bold tracking-tight">
          What&apos;s new in Battlify
        </h1>
        <p className="mt-3 max-w-xl text-sm leading-relaxed text-muted-foreground">
          Every release, straight from the source. Update whenever you like, every version is
          included with your license, forever.
        </p>

        <a
          href={LINKS.releases}
          target="_blank"
          rel="noopener noreferrer"
          className="mt-6 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-2.5 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
        >
          <DownloadIcon className="size-4" />
          Get the latest version
        </a>

        <ol className="relative mt-14 ml-2 border-l border-border">
          {RELEASES.map((r) => (
            <li key={r.v} className="relative pb-12 pl-8 last:pb-0">
              <span
                className={
                  r.latest
                    ? "absolute top-1 -left-[7px] size-3.5 rounded-full bg-primary ring-4 ring-primary/20"
                    : "absolute top-1.5 -left-[5px] size-2.5 rounded-full bg-muted-foreground/40"
                }
                aria-hidden
              />

              <div className="flex items-center gap-2.5">
                <a
                  href={releaseUrl(r.v)}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="group inline-flex items-center gap-1 font-display text-xl font-bold tracking-tight transition-colors hover:text-primary"
                >
                  v{r.v}
                  <ArrowUpRightIcon className="size-4 text-muted-foreground transition-colors group-hover:text-primary" />
                </a>
                {r.latest ? (
                  <span className="rounded-full bg-primary/15 px-2 py-0.5 text-[10px] font-semibold tracking-wider text-primary uppercase">
                    Latest
                  </span>
                ) : null}
              </div>

              <p className="mt-1 text-xs text-muted-foreground">{r.date}</p>

              {r.changes ? (
                <ul className="mt-4 space-y-3">
                  {r.changes.map((c) => (
                    <li key={c.label} className="flex gap-3 text-sm leading-relaxed">
                      <span className="mt-2 size-1.5 shrink-0 rounded-full bg-primary/60" aria-hidden />
                      <span>
                        <span className="font-semibold text-foreground">{c.label}</span>{" "}
                        <span className="text-muted-foreground">{c.body}</span>
                      </span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{r.note}</p>
              )}
            </li>
          ))}

          <li className="relative pl-8">
            <span
              className="absolute top-1.5 -left-[5px] size-2.5 rounded-full border-2 border-muted-foreground/50 bg-background"
              aria-hidden
            />
            <h2 className="font-display text-xl font-bold tracking-tight text-muted-foreground">
              Planned next
            </h2>
            <p className="mt-1 text-xs text-muted-foreground">Roadmap, subject to change</p>
            <ul className="mt-4 space-y-3">
              {ROADMAP.map((c) => (
                <li key={c.label} className="flex gap-3 text-sm leading-relaxed">
                  <span
                    className="mt-2 size-1.5 shrink-0 rounded-full border border-muted-foreground/50"
                    aria-hidden
                  />
                  <span>
                    <span className="font-semibold text-foreground">{c.label}</span>{" "}
                    <span className="text-muted-foreground">{c.body}</span>
                  </span>
                </li>
              ))}
            </ul>
          </li>
        </ol>
      </main>

      <footer className="border-t border-border">
        <div className="mx-auto flex max-w-3xl flex-col items-center justify-between gap-4 px-6 py-8 text-sm text-muted-foreground sm:flex-row">
          <p>© 2026 Battlify · built by broisnischal</p>
          <div className="flex items-center gap-5">
            <Link to="/legal/privacy" className="transition-colors hover:text-foreground">
              Privacy
            </Link>
            <Link to="/legal/terms" className="transition-colors hover:text-foreground">
              Terms
            </Link>
          </div>
        </div>
      </footer>
    </div>
  );
}
