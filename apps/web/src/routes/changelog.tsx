import { SiX } from "@icons-pack/react-simple-icons";
import { useSuspenseQuery } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { ChevronDownIcon, DownloadIcon } from "lucide-react";
import { useState } from "react";

import { LINKS } from "#/components/landing/landing-data";
import { breadcrumbSchema } from "#/components/seo/json-ld";
import { Container, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";
import { ROADMAP } from "#/lib/changelog";
import { releasesQueryOptions } from "#/lib/releases/queries";
import { seo } from "#/lib/seo";
import { cn } from "#/lib/utils";

export const Route = createFileRoute("/changelog")({
  loader: ({ context }) => context.queryClient.ensureQueryData(releasesQueryOptions()),
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
    <li className="grid gap-3 border-t border-border pt-10 first:border-t-0 first:pt-0 sm:grid-cols-[140px_1fr] sm:gap-8">
      <div className="flex items-center gap-2 sm:sticky sm:top-8 sm:flex-col sm:items-start sm:gap-1 sm:self-start">
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
        <h2 className="text-lg/7 font-semibold tracking-tight text-balance">{title}</h2>
        {children}
      </div>
    </li>
  );
}

/** Styles the HTML GitHub renders from a release's markdown notes. */
const NOTES =
  "mt-3 text-[15px] leading-relaxed text-foreground/80 [&_a]:underline [&_a]:underline-offset-4 [&_code]:rounded [&_code]:bg-muted [&_code]:px-1 [&_code]:font-mono [&_code]:text-[13px] [&_h3]:mt-8 [&_h3]:font-semibold [&_h3]:text-foreground [&_h3+ol]:mt-2 [&_h3+p]:mt-1.5 [&_h3+ul]:mt-2 [&_li]:pl-1 [&_li]:marker:text-muted-foreground [&_li>p:first-child]:mt-0 [&_ol]:mt-3 [&_ol]:list-decimal [&_ol]:space-y-1.5 [&_ol]:pl-5 [&_p]:mt-3 [&_strong]:font-semibold [&_strong]:text-foreground [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:space-y-1.5 [&_ul]:pl-5 [&>*:first-child]:mt-0";

/** Notes longer than this start folded, so one big release doesn't bury the rest. */
const FOLD_AT = 3000;

function Notes({ html }: { html: string }) {
  const [open, setOpen] = useState(html.length <= FOLD_AT);
  return (
    <>
      <div
        className={cn(
          NOTES,
          !open &&
            "max-h-80 overflow-hidden mask-[linear-gradient(to_bottom,black_55%,transparent)]",
        )}
        // Sanitized by GitHub when it rendered the release's markdown.
        dangerouslySetInnerHTML={{ __html: html }}
      />
      {open ? null : (
        <Button variant="outline" size="sm" className="mt-2" onClick={() => setOpen(true)}>
          Show all notes
          <ChevronDownIcon />
        </Button>
      )}
    </>
  );
}

function ChangelogPage() {
  const { data: releases } = useSuspenseQuery(releasesQueryOptions());
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

        <ol className="mt-12 flex flex-col gap-10">
          {releases.length === 0 ? (
            <li className="text-[15px] text-muted-foreground">
              The release notes couldn&apos;t be loaded just now. They&apos;re all on{" "}
              <a href={LINKS.releases} target="_blank" rel="noreferrer" className="underline">
                GitHub
              </a>
              .
            </li>
          ) : null}
          {releases.map((r) => (
            <Entry
              key={r.version}
              pill={r.version}
              href={r.url}
              date={r.date}
              title={r.title || `eWiz ${r.version}`}
            >
              <Notes html={r.notesHtml} />
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
