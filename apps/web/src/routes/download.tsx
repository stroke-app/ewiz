import { SiApple, SiGithub, SiHomebrew } from "@icons-pack/react-simple-icons";
import { createFileRoute, Link } from "@tanstack/react-router";
import {
  ArrowUpRightIcon,
  CheckIcon,
  CopyIcon,
  DownloadIcon,
  TriangleAlertIcon,
} from "lucide-react";
import { useState } from "react";

import { BREW_INSTALL, LATEST, LINKS } from "#/components/landing/landing-data";
import { breadcrumbSchema, softwareApplicationSchema } from "#/components/seo/json-ld";
import { Container, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/download")({
  head: () => ({
    ...seo({
      title: "Download for Mac",
      description:
        "Download eWiz for macOS. Native menu bar battery care for Apple Silicon Macs. Free for 30 days, then a one-time $2.99.",
      path: "/download",
      keywords: ["download eWiz", "eWiz download", "eWiz mac", "eWiz app"],
      jsonLd: [
        softwareApplicationSchema(),
        breadcrumbSchema([{ name: "Download", path: "/download" }]),
      ],
    }),
  }),
  component: DownloadPage,
});

const PILL =
  "inline-flex h-8 items-center gap-1.5 rounded-lg border border-border bg-surface-1 px-3 text-[15px] transition-colors hover:bg-surface-2";

function DownloadPage() {
  return (
    <SitePage>
      <Container className="max-w-[38rem] pt-10">
        <DownloadIcon className="mx-auto size-24 text-surface-4" strokeWidth={1.75} aria-hidden />

        <h1 className="mt-14 text-xl font-medium">Download eWiz</h1>
        <p className="mt-1 text-lg text-muted-foreground">
          Currently available for macOS on Apple Silicon.
        </p>

        <div className="mt-6 flex items-end justify-between gap-4 border-b border-border pb-2">
          <p className="text-lg text-muted-foreground">
            Version - <span className="text-foreground tabular-nums">{LATEST.version}</span>
          </p>
          <Button render={<Link to="/changelog" />} nativeButton={false} className="text-[15px]">
            View Changelog
            <ArrowUpRightIcon />
          </Button>
        </div>

        <div className="flex items-center justify-between gap-4 border-b border-border py-4">
          <span className="flex items-center gap-3 text-lg">
            <SiApple className="size-5" aria-hidden />
            macOS
          </span>
          <a href={LATEST.dmg} className={PILL}>
            Apple Silicon
          </a>
        </div>

        <div className="flex items-center justify-between gap-4 border-b border-border py-4">
          <span className="flex items-center gap-3 text-lg">
            <SiGithub className="size-5" aria-hidden />
            Earlier versions
          </span>
          <a href={LINKS.releases} target="_blank" rel="noreferrer" className={PILL}>
            All releases
          </a>
        </div>

        <div className="border-b border-border py-4">
          <span className="flex items-center gap-3 text-lg">
            <SiHomebrew className="size-5" aria-hidden />
            Homebrew
          </span>
          <BrewCommand />
        </div>

        <div className="mt-10 flex gap-3 rounded-lg border border-border bg-surface-1 p-4">
          <TriangleAlertIcon className="mt-1 size-5 shrink-0 text-warning" aria-hidden />
          <div>
            <h2 className="text-lg font-medium">Unsigned application</h2>
            <p className="mt-0.5 leading-relaxed text-muted-foreground">
              These builds are not signed by Apple yet, so macOS may block the first launch:
            </p>
            <ul className="mt-2 space-y-1 text-muted-foreground">
              <li>
                · <span className="text-foreground">Right-click</span> the app in Applications and
                choose <span className="text-foreground">Open</span>, or
              </li>
              <li>
                · allow it in{" "}
                <span className="text-foreground">System Settings → Privacy &amp; Security</span>.
              </li>
            </ul>
          </div>
        </div>

        <dl className="mt-6 grid gap-3 text-[15px] sm:grid-cols-3">
          {[
            { k: "macOS", v: "14 Sonoma or newer" },
            { k: "Chip", v: "Apple Silicon (M1+)" },
            { k: "Trial", v: "30 days, every feature" },
          ].map((r) => (
            <div key={r.k} className="rounded-lg border border-border px-3 py-2">
              <dt className="text-sm text-muted-foreground">{r.k}</dt>
              <dd>{r.v}</dd>
            </div>
          ))}
        </dl>
      </Container>
    </SitePage>
  );
}

/** The cask install line with a one-click copy. */
function BrewCommand() {
  const [copied, setCopied] = useState(false);
  return (
    <div className="mt-3 flex items-center gap-2 rounded-lg border border-border bg-surface-1 py-1.5 pr-1.5 pl-3">
      <code className="min-w-0 flex-1 overflow-x-auto font-mono text-sm whitespace-nowrap [font-variant-ligatures:none]">
        <span className="text-muted-foreground select-none">$ </span>
        {BREW_INSTALL}
      </code>
      <button
        type="button"
        onClick={async () => {
          await navigator.clipboard.writeText(BREW_INSTALL);
          setCopied(true);
          window.setTimeout(() => setCopied(false), 1600);
        }}
        aria-label={copied ? "Copied" : "Copy install command"}
        className="flex size-8 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-surface-2 hover:text-foreground"
      >
        {copied ? <CheckIcon className="size-4 text-success" /> : <CopyIcon className="size-4" />}
      </button>
    </div>
  );
}
