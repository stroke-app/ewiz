import { ArrowRight02Icon } from "@hugeicons/core-free-icons";
import { createFileRoute, Link } from "@tanstack/react-router";

import { Icon } from "#/components/icon";
import { breadcrumbSchema } from "#/components/seo/json-ld";
import { POSTS } from "#/lib/blog/posts";
import { seo } from "#/lib/seo";

const BLOG_DESCRIPTION =
  "Field notes on how lithium-ion batteries work, why they fade, and how to make yours last for years.";

export const Route = createFileRoute("/blog/")({
  component: BlogIndex,
  head: () => ({
    ...seo({
      title: "Battery science blog",
      description: BLOG_DESCRIPTION,
      path: "/blog",
      jsonLd: [breadcrumbSchema([{ name: "Blog", path: "/blog" }])],
    }),
  }),
});

function BlogIndex() {
  return (
    <div>
      <h1 className="text-xl font-semibold">Blog</h1>
      <p className="text-muted-foreground">
        How lithium-ion batteries work, what wears them out, and how to keep yours healthy.
      </p>

      <div className="mt-8 flex flex-col gap-4 border-t border-border pt-8">
        {POSTS.map((post) => (
          <Link
            key={post.slug}
            to="/blog/$slug"
            params={{ slug: post.slug }}
            className="group rounded-lg border border-border bg-surface-1 px-4 py-3 transition-colors hover:bg-surface-2"
          >
            <div className="flex items-start justify-between gap-4">
              <h2 className="text-lg font-medium">{post.title}</h2>
              <span className="mt-1 shrink-0 rounded bg-primary/15 px-1.5 text-xs text-primary">
                {post.tag}
              </span>
            </div>
            <p className="mt-0.5 line-clamp-2 text-muted-foreground">{post.description}</p>
            <p className="mt-2 flex items-center gap-1.5 text-sm text-muted-foreground">
              <span className="text-foreground">{post.displayDate}</span>
              <span aria-hidden>·</span>
              {post.readingMinutes} min read
              <Icon
                icon={ArrowRight02Icon}
                className="ml-auto size-4 transition-transform group-hover:translate-x-0.5"
              />
            </p>
          </Link>
        ))}
      </div>
    </div>
  );
}
