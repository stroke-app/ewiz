import { createFileRoute, Link } from "@tanstack/react-router";
import { DownloadIcon } from "lucide-react";

import { LINKS } from "#/components/landing/landing-data";
import { Logo } from "#/components/logo";
import { breadcrumbSchema, JsonLd, softwareApplicationSchema } from "#/components/seo/json-ld";
import { seo } from "#/lib/seo";

/** Kept in sync with appcast.json / the latest GitHub release. */
const VERSION = "0.10.1";

const REQUIREMENTS = [
  { label: "macOS 14 Sonoma or newer", detail: "Including macOS 26 Tahoe" },
  { label: "Apple Silicon", detail: "M1 and later, arm64 native" },
  { label: "About 12 MB", detail: "Menu bar only, no Dock icon" },
];

export const Route = createFileRoute("/download")({
  head: () => ({
    ...seo({
      title: "Download Battlify",
      description:
        "Download Battlify for macOS. Native menu bar battery care for Apple Silicon Macs. Free for 30 days, then a one-time $2.99.",
      path: "/download",
      keywords: ["download battlify", "battlify download", "battlify mac", "battlify app"],
    }),
  }),
  component: DownloadPage,
});

function DownloadPage() {
  return (
    <div className="min-h-svh bg-background text-foreground">
      <JsonLd data={softwareApplicationSchema()} />
      <JsonLd data={breadcrumbSchema([{ name: "Download", path: "/download" }])} />

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

      <main className="mx-auto max-w-3xl px-6 py-20">
        <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">Download</p>
        <h1 className="font-display mt-3 text-4xl font-bold tracking-tight">Download Battlify</h1>
        <p className="mt-3 max-w-xl text-base leading-relaxed text-muted-foreground">
          Native menu bar battery care for your Mac. Try every feature free for 30 days, then keep
          it forever for a one-time $2.99.
        </p>

        <div className="mt-8 flex flex-wrap items-center gap-3">
          <a
            href={LINKS.releases}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-3 text-sm font-medium text-primary-foreground transition-opacity hover:opacity-90"
          >
            <DownloadIcon className="size-4" />
            Download for Mac
          </a>
          <a
            href={LINKS.releases}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 rounded-lg border border-border px-5 py-3 text-sm font-medium transition-colors hover:bg-muted"
          >
            All releases
          </a>
        </div>
        <p className="mt-3 text-xs text-muted-foreground">
          Version {VERSION} · No account required to try · Free for 30 days
        </p>

        <section className="mt-14">
          <h2 className="font-display text-xl font-bold tracking-tight">Requirements</h2>
          <ul className="mt-4 divide-y divide-border rounded-2xl border border-border bg-card">
            {REQUIREMENTS.map((r) => (
              <li key={r.label} className="flex items-baseline justify-between gap-4 p-5">
                <span className="font-medium">{r.label}</span>
                <span className="text-sm text-muted-foreground">{r.detail}</span>
              </li>
            ))}
          </ul>
        </section>

        <section className="mt-10 rounded-2xl border border-primary/30 bg-primary/5 p-6">
          <h2 className="font-display text-lg font-bold tracking-tight">Every update, included</h2>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            Your license covers every future version for life. See what shipped recently on the{" "}
            <Link to="/changelog" className="text-primary underline underline-offset-4">
              changelog
            </Link>
            , or read the battery science behind Battlify on the{" "}
            <Link to="/blog" className="text-primary underline underline-offset-4">
              blog
            </Link>
            .
          </p>
        </section>
      </main>

      <footer className="border-t border-border">
        <div className="mx-auto flex max-w-3xl flex-col items-center justify-between gap-4 px-6 py-8 text-sm text-muted-foreground sm:flex-row">
          <p>© 2026 Battlify · built by broisnischal</p>
          <div className="flex items-center gap-5">
            <Link to="/changelog" className="transition-colors hover:text-foreground">
              Changelog
            </Link>
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
