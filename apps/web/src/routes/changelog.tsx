import { SiX } from "@icons-pack/react-simple-icons";
import { createFileRoute, Link } from "@tanstack/react-router";
import { DownloadIcon } from "lucide-react";

import { LINKS } from "#/components/landing/landing-data";
import { breadcrumbSchema } from "#/components/seo/json-ld";
import { Container, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";
import { RELEASES, ROADMAP } from "#/lib/changelog";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/changelog")({
  head: () => ({
    ...seo({
      title: "Changelog: what's new",
      description:
        "What's new in eWiz. Every release is included with your license, so you can update whenever you like.",
      path: "/changelog",
      jsonLd: [breadcrumbSchema([{ name: "Changelog", path: "/changelog" }])],
    }),
  }),
  component: ChangelogPage,
});

function releaseUrl(v: string) {
  return `https://github.com/stroke-app/ewiz/releases/tag/v${v}`;
}

function Entry({
  pill,
  href,
  date,
  title,
  children,
}: {
  pill: string;
  href?: string;
  date?: string;
  title: string;
  children: React.ReactNode;
}) {
  const pillClass =
    "w-fit rounded-md border border-border bg-surface-1 px-1.5 text-[15px] tabular-nums";
  return (
    <li className="grid gap-3 sm:grid-cols-[140px_1fr] sm:gap-6">
      <div className="flex items-center gap-2 sm:flex-col sm:items-start sm:gap-0.5">
        {href ? (
          <a
            href={href}
            target="_blank"
            rel="noreferrer"
            className={pillClass + " transition-colors hover:bg-surface-2"}
          >
            {pill}
          </a>
        ) : (
          <span className={pillClass}>{pill}</span>
        )}
        {date ? <span className="text-sm text-muted-foreground">{date}</span> : null}
      </div>
      <div>
        <h2 className="rounded-lg border border-border bg-surface-1 px-2 py-0.5 text-lg font-semibold">
          {title}
        </h2>
        {children}
      </div>
    </li>
  );
}

function ChangelogPage() {
  return (
    <SitePage>
      <Container className="pt-6">
        <h1 className="text-xl font-semibold">Changelog</h1>
        <p className="text-muted-foreground">Follow updates made to eWiz.</p>
        <div className="mt-4 flex gap-2">
          <Button render={<Link to="/download" />} nativeButton={false} size="sm">
            <DownloadIcon />
            Get the latest
          </Button>
          <Button
            render={<a href={LINKS.x} target="_blank" rel="noreferrer" aria-label="Follow on X" />}
            nativeButton={false}
            variant="outline"
            size="sm"
          >
            Follow on
            <SiX className="size-3" />
          </Button>
        </div>

        <ol className="mt-12 flex flex-col gap-12">
          {RELEASES.map((r) => (
            <Entry key={r.v} pill={r.v} href={releaseUrl(r.v)} date={r.date} title={r.title}>
              {r.groups.map((g) => (
                <div key={g.heading} className="mt-5">
                  <h3 className="font-semibold">{g.heading}</h3>
                  <ul className="mt-2 list-disc space-y-1.5 pl-6 marker:text-muted-foreground">
                    {g.items.map((item) => (
                      <li key={item} className="pl-1 text-[15px] leading-relaxed">
                        {item}
                      </li>
                    ))}
                  </ul>
                </div>
              ))}
              {r.quote ? (
                <blockquote className="mt-5 border-l-2 border-border pl-3 text-[15px] text-muted-foreground italic">
                  {r.quote}
                </blockquote>
              ) : null}
            </Entry>
          ))}

          <Entry pill="Next" title="On the roadmap">
            <ul className="mt-4 list-disc space-y-1.5 pl-6 marker:text-muted-foreground">
              {ROADMAP.map((item) => (
                <li key={item} className="pl-1 text-[15px] leading-relaxed">
                  {item}
                </li>
              ))}
            </ul>
            <blockquote className="mt-5 border-l-2 border-border pl-3 text-[15px] text-muted-foreground italic">
              Plans, not promises. Ideas are welcome on{" "}
              <a href={LINKS.feedback} target="_blank" rel="noreferrer" className="underline">
                GitHub
              </a>
              .
            </blockquote>
          </Entry>
        </ol>
      </Container>
    </SitePage>
  );
}
