import { createFileRoute } from "@tanstack/react-router";
import { ArrowUpRightIcon, DownloadIcon } from "lucide-react";

import { LINKS } from "#/components/landing/landing-data";
import { LegalLayout } from "#/components/legal/legal-layout";

export const Route = createFileRoute("/changelog")({
  head: () => ({
    meta: [
      { title: "Changelog — Battlify" },
      {
        name: "description",
        content:
          "What's new in Battlify. Every release is included with your license — update whenever you like.",
      },
    ],
  }),
  component: ChangelogPage,
});

/** The current shipping version, kept in sync with appcast.json. */
const CURRENT = "0.8.4";

/** Headline capabilities Battlify ships today. */
const HIGHLIGHTS = [
  {
    title: "Charge limit that holds",
    body: "Pick any ceiling from 50% to 100% and Battlify keeps it there, with a small buffer so the charger isn't clicking on and off all day. Works with both CH0B/CH0C and the newer CHTE keys on macOS 26 Tahoe.",
  },
  {
    title: "Sleep-safe enforcement",
    body: "Your limit holds even while the Mac is asleep — stop charging before sleep, or keep the Mac awake on wall power so macOS can't sneak you back to 100% overnight.",
  },
  {
    title: "Heat-aware charging",
    body: "Set a temperature you're happy with and charging pauses when things get warm, then resumes once they cool. The menu always tells you why it paused.",
  },
  {
    title: "MagSafe LED, driven by real state",
    body: "The cable glows amber while charging and turns green the instant it's holding at your limit — one look tells you what's going on.",
  },
] as const;

/**
 * Known releases, newest first. Each links to its GitHub release for the full,
 * authoritative notes. Kept intentionally light — GitHub is the source of truth.
 */
const RELEASES = [
  { v: "0.8.4", note: "Latest stable release." },
  { v: "0.8.3", note: "Charging reliability and menu polish." },
  { v: "0.8.2", note: "Fixes and refinements." },
  { v: "0.8.1", note: "Fixes and refinements." },
  { v: "0.8.0", note: "Sleep-safe enforcement improvements." },
  { v: "0.7.3", note: "Heat-aware charging refinements." },
  { v: "0.7.2", note: "Fixes and refinements." },
  { v: "0.7.1", note: "Fixes and refinements." },
  { v: "0.6.1", note: "Early public release." },
] as const;

function releaseUrl(v: string) {
  return `https://github.com/broisnischal/battlify/releases/tag/v${v}`;
}

function ChangelogPage() {
  return (
    <LegalLayout
      eyebrow="Changelog"
      title="What's new in Battlify."
      intro={
        <p>
          Every release, straight from the source. Update whenever you like — every version is
          included with your license, forever.
        </p>
      }
    >
      <div className="cl-current">
        <div>
          <span className="cl-badge">Current release</span>
          <h2 className="cl-version">v{CURRENT}</h2>
          <p>The latest stable build, with everything below included.</p>
        </div>
        <a
          href={LINKS.releases}
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-primary"
        >
          <DownloadIcon />
          Get the latest version
        </a>
      </div>

      <section className="legal-section">
        <h2>What Battlify does today</h2>
        <div className="cl-highlights">
          {HIGHLIGHTS.map((h) => (
            <div key={h.title} className="cl-card">
              <h3>{h.title}</h3>
              <p>{h.body}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="legal-section">
        <h2>Release history</h2>
        <div className="legal-prose">
          <p>
            Full, detailed notes for each release live on GitHub. Click any version for exactly what
            changed.
          </p>
        </div>
        <ul className="cl-releases">
          {RELEASES.map((r) => (
            <li key={r.v}>
              <a href={releaseUrl(r.v)} target="_blank" rel="noopener noreferrer">
                <span className="cl-rv">v{r.v}</span>
                <span className="cl-rnote">{r.note}</span>
                <ArrowUpRightIcon />
              </a>
            </li>
          ))}
        </ul>
      </section>
    </LegalLayout>
  );
}
