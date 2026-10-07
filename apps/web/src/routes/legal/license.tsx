import { createFileRoute } from "@tanstack/react-router";

import { LINKS } from "#/components/landing/landing-data";
import { breadcrumbSchema } from "#/components/seo/json-ld";
import { LICENSE_BLOCKS, type LicenseBlock } from "#/lib/license-text";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/legal/license")({
  head: () => ({
    ...seo({
      title: "eWiz License",
      description:
        "eWiz is source-available under the eWiz License: use the code however you like, but a published copy must credit eWiz, carry no malware and keep paying the author.",
      path: "/legal/license",
      jsonLd: [breadcrumbSchema([{ name: "eWiz License", path: "/legal/license" }])],
    }),
  }),
  component: LicensePage,
});

const LINK = "text-primary underline underline-offset-4";

function Block({ block }: { block: LicenseBlock }) {
  switch (block.kind) {
    case "heading":
      return <h2 className="mt-8 text-xl font-semibold tracking-tight">{block.text}</h2>;
    case "rule":
      return <hr className="mt-8 border-border" />;
    case "paragraph":
      return <p className="mt-4">{block.text}</p>;
    case "list": {
      const List = block.ordered ? "ol" : "ul";
      return (
        <List
          className={`mt-4 space-y-3 pl-6 marker:text-muted-foreground ${block.ordered ? "list-decimal" : "list-disc"}`}
        >
          {block.items.map((item) => (
            <li key={item.text} className="pl-1">
              {item.text}
              {item.children.length > 0 ? (
                <ul className="mt-3 list-[circle] space-y-3 pl-6 marker:text-muted-foreground">
                  {item.children.map((child) => (
                    <li key={child} className="pl-1">
                      {child}
                    </li>
                  ))}
                </ul>
              ) : null}
            </li>
          ))}
        </List>
      );
    }
  }
}

function LicensePage() {
  // The file opens with its own title, which the page heading already shows.
  const [title, ...body] = LICENSE_BLOCKS;
  return (
    <article>
      <p className="text-sm font-medium text-primary uppercase">Legal</p>
      <h1 className="mt-1 text-4xl font-bold tracking-tight">
        {title?.kind === "heading" ? title.text : "eWiz License"}
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-pretty text-muted-foreground">
        eWiz is source-available. Use the code however you like; publishing a copy of the app or
        this site comes with a few conditions, set out below. The source is on GitHub for{" "}
        <a href={LINKS.github} target="_blank" rel="noreferrer" className={LINK}>
          the app
        </a>{" "}
        and{" "}
        <a href={LINKS.siteSource} target="_blank" rel="noreferrer" className={LINK}>
          this website
        </a>
        .
      </p>

      <div className="mt-10 rounded-lg border border-border bg-surface-1 px-5 py-2 pb-6 leading-7 text-foreground/85 sm:px-8">
        {body.map((block, i) => (
          <Block key={i} block={block} />
        ))}
      </div>
    </article>
  );
}
