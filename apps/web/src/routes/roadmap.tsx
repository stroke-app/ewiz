import { createFileRoute, Link } from "@tanstack/react-router";
import { CircleDotIcon, CompassIcon, HammerIcon, LightbulbIcon } from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { LINKS } from "#/components/landing/landing-data";
import { breadcrumbSchema } from "#/components/seo/json-ld";
import { Container, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";
import { ROADMAP, ROADMAP_STAGES, type RoadmapStage } from "#/lib/changelog";
import { seo } from "#/lib/seo";
import { cn } from "#/lib/utils";

export const Route = createFileRoute("/roadmap")({
  head: () => ({
    ...seo({
      title: "Roadmap",
      description:
        "What's coming to eWiz: notarized builds, custom charging animations, widgets, Shortcuts actions, battery health over time and more.",
      path: "/roadmap",
      jsonLd: [breadcrumbSchema([{ name: "Roadmap", path: "/roadmap" }])],
    }),
  }),
  component: RoadmapPage,
});

const STAGE_ICON: Record<RoadmapStage, LucideIcon> = {
  now: HammerIcon,
  next: CompassIcon,
  later: LightbulbIcon,
};

const STAGE_DOT: Record<RoadmapStage, string> = {
  now: "text-primary",
  next: "text-foreground",
  later: "text-muted-foreground",
};

function RoadmapPage() {
  const stages = Object.keys(ROADMAP_STAGES) as RoadmapStage[];
  return (
    <SitePage>
      <Container className="max-w-[44rem] pt-10">
        <h1 className="text-3xl font-semibold tracking-tight text-balance sm:text-[2.25rem] sm:leading-[1.15]">
          Roadmap
        </h1>
        <p className="mt-3 text-lg leading-relaxed text-pretty text-muted-foreground">
          eWiz is in public beta and updates often. This is what&apos;s being built and what&apos;s
          next. Plans, not promises: they move as we learn what people need.
        </p>

        {stages.map((stage) => {
          const Icon = STAGE_ICON[stage];
          const items = ROADMAP.filter((i) => i.stage === stage);
          if (items.length === 0) return null;
          return (
            <section key={stage} aria-labelledby={`${stage}-title`} className="mt-12">
              <div className="flex items-center gap-2.5">
                <Icon className="size-5 text-muted-foreground" aria-hidden />
                <h2 id={`${stage}-title`} className="text-xl font-semibold tracking-tight">
                  {ROADMAP_STAGES[stage].label}
                </h2>
              </div>
              <p className="mt-1 text-[15px] text-muted-foreground">
                {ROADMAP_STAGES[stage].blurb}
              </p>
              <ul className="mt-4 flex flex-col gap-3">
                {items.map((item) => (
                  <li
                    key={item.title}
                    className="flex gap-3 rounded-lg border border-border bg-surface-1 px-4 py-3"
                  >
                    <CircleDotIcon
                      className={cn("mt-1 size-4 shrink-0", STAGE_DOT[stage])}
                      aria-hidden
                    />
                    <div>
                      <h3 className="font-medium">{item.title}</h3>
                      <p className="mt-0.5 text-[15px] leading-relaxed text-pretty text-muted-foreground">
                        {item.body}
                      </p>
                    </div>
                  </li>
                ))}
              </ul>
            </section>
          );
        })}

        <section className="mt-14 rounded-lg border border-border bg-surface-1 px-5 py-5">
          <h2 className="font-semibold">Missing something?</h2>
          <p className="mt-1 text-[15px] leading-relaxed text-muted-foreground">
            Requests decide what gets built next. Tell us what would make eWiz better for you.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button
              render={
                <a
                  href={`${LINKS.feedback}/new?labels=enhancement&title=Feature%20request%3A%20`}
                  target="_blank"
                  rel="noreferrer"
                  aria-label="Suggest a feature on GitHub"
                />
              }
              nativeButton={false}
            >
              Suggest a feature
            </Button>
            <Button render={<Link to="/changelog" />} nativeButton={false} variant="outline">
              What&apos;s already shipped
            </Button>
          </div>
        </section>
      </Container>
    </SitePage>
  );
}
