import { createFileRoute, Link } from "@tanstack/react-router";

import { Button } from "#/components/ui/button";
import { getPost } from "#/lib/blog/posts";

export const Route = createFileRoute("/blog/$slug")({
  component: PostPage,
  head: ({ params }) => {
    const post = getPost(params.slug);
    return {
      meta: post
        ? [
            { title: `${post.title} — Battlify` },
            { name: "description", content: post.description },
            { property: "og:title", content: post.title },
            { property: "og:description", content: post.description },
          ]
        : [{ title: "Post not found — Battlify" }],
    };
  },
});

function PostPage() {
  const { slug } = Route.useParams();
  const post = getPost(slug);

  if (!post) {
    return (
      <div className="py-10 text-center">
        <h1 className="font-display text-2xl font-bold tracking-tight">Post not found</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          That article doesn&apos;t exist (or moved).
        </p>
        <Link
          to="/blog"
          className="mt-4 inline-block text-sm font-medium text-primary hover:underline"
        >
          ← All posts
        </Link>
      </div>
    );
  }

  const { Content } = post;

  return (
    <article>
      <Link
        to="/blog"
        className="text-sm text-muted-foreground transition-colors hover:text-foreground"
      >
        ← All posts
      </Link>

      <header className="mt-6">
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <span className="rounded-full bg-primary/10 px-2 py-0.5 font-medium text-primary">
            {post.tag}
          </span>
          <span>{post.displayDate}</span>
          <span aria-hidden>·</span>
          <span>{post.readingMinutes} min read</span>
        </div>
        <h1 className="font-display mt-4 text-4xl font-bold tracking-tight text-balance">
          {post.title}
        </h1>
        <p className="mt-4 text-lg leading-relaxed text-muted-foreground text-pretty">
          {post.description}
        </p>
      </header>

      <hr className="my-10 border-border" />

      <Content />

      <aside className="mt-16 rounded-2xl border border-primary/30 bg-primary/5 p-6 text-center">
        <h2 className="font-display text-xl font-bold tracking-tight">
          Let Battlify handle the hard part.
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm leading-relaxed text-muted-foreground">
          Charge limiting, sleep-safe enforcement, and heat-aware charging — the science above,
          turned into a setting you configure once. $2.99, free for 30 days.
        </p>
        <div className="mt-5 flex justify-center">
          <Button render={<Link to="/" />} size="lg" nativeButton={false}>
            Meet Battlify
          </Button>
        </div>
      </aside>
    </article>
  );
}
