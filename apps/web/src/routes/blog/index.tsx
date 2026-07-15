import { ArrowRight02Icon } from "@hugeicons/core-free-icons";
import { createFileRoute, Link } from "@tanstack/react-router";

import { Icon } from "#/components/icon";
import { breadcrumbSchema, JsonLd } from "#/components/seo/json-ld";
import { POSTS } from "#/lib/blog/posts";
import { seo } from "#/lib/seo";

const BLOG_DESCRIPTION =
  "Field notes on how lithium-ion batteries work, why they fade, and how to make yours last for years.";

export const Route = createFileRoute("/blog/")({
  component: BlogIndex,
  head: () => ({
    ...seo({ title: "Blog", description: BLOG_DESCRIPTION, path: "/blog" }),
  }),
});

function BlogIndex() {
  return (
    <div>
      <JsonLd data={breadcrumbSchema([{ name: "Blog", path: "/blog" }])} />
      <p className="text-[11px] font-semibold tracking-[0.16em] text-primary uppercase">Blog</p>
      <h1 className="font-display mt-3 text-4xl font-bold tracking-tight text-balance">
        Battery science, without the hand-waving.
      </h1>
      <p className="mt-3 max-w-xl text-muted-foreground">
        How lithium-ion batteries actually work, what really wears them out, and the habits that
        keep yours healthy for years.
      </p>

      <div className="mt-10 flex flex-col gap-4">
        {POSTS.map((post) => (
          <Link
            key={post.slug}
            to="/blog/$slug"
            params={{ slug: post.slug }}
            className="group rounded-2xl border border-border bg-card p-6 transition-colors hover:border-primary/40"
          >
            <div className="flex items-center gap-2 text-xs text-muted-foreground">
              <span className="rounded-full bg-primary/10 px-2 py-0.5 font-medium text-primary">
                {post.tag}
              </span>
              <span>{post.displayDate}</span>
              <span aria-hidden>·</span>
              <span>{post.readingMinutes} min read</span>
            </div>
            <h2 className="mt-3 text-xl font-semibold tracking-tight">{post.title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{post.description}</p>
            <span className="mt-4 inline-flex items-center gap-1.5 text-sm font-medium text-primary">
              Read the post
              <Icon
                icon={ArrowRight02Icon}
                className="size-4 transition-transform group-hover:translate-x-0.5"
              />
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
