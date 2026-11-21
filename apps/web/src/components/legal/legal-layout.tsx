import type { ReactNode } from "react";

import { Container, Eyebrow, SitePage } from "#/components/site/site-shell";

/** Shared chrome for the short-form legal pages (/terms, /privacy). */
export function LegalLayout({
  eyebrow,
  title,
  updated,
  intro,
  children,
}: {
  eyebrow: string;
  title: string;
  updated?: string;
  intro?: ReactNode;
  children: ReactNode;
}) {
  return (
    <SitePage>
      <Container className="pt-6">
        <Eyebrow>{eyebrow}</Eyebrow>
        <h1 className="mt-1 text-4xl font-bold tracking-tight text-balance">{title}</h1>
        {updated ? (
          <p className="mt-4">
            <span className="font-semibold">Last updated:</span>{" "}
            <span className="text-muted-foreground">{updated}</span>
          </p>
        ) : null}
        {intro ? <div className="mt-4 text-lg leading-relaxed text-pretty">{intro}</div> : null}
        <article className="mt-4">{children}</article>
      </Container>
    </SitePage>
  );
}

/** A numbered section within a legal document. */
export function Section({ n, title, children }: { n: string; title: string; children: ReactNode }) {
  return (
    <section className="mt-10">
      <h2 className="flex items-baseline gap-3 text-2xl font-semibold tracking-tight">
        <span className="text-base font-medium text-muted-foreground tabular-nums">{n}</span>
        {title}
      </h2>
      <div className="mt-3 space-y-4 leading-7 text-foreground/85 [&_a]:text-primary [&_a]:underline [&_a]:underline-offset-4 [&_b]:font-semibold [&_b]:text-foreground [&_ul]:list-disc [&_ul]:space-y-1.5 [&_ul]:pl-6">
        {children}
      </div>
    </section>
  );
}
