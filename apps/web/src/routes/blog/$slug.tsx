import { createFileRoute, Link } from "@tanstack/react-router";

import { articleSchema, breadcrumbSchema } from "#/components/seo/json-ld";
import { Button } from "#/components/ui/button";
import { getPost } from "#/lib/blog/posts";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/blog/$slug")({
  component: PostPage,
  head: ({ params }) => {
    const post = getPost(params.slug);
    if (!post) {
      return { ...seo({ title: "Post not found", path: `/blog/${params.slug}` }) };
    }
    return {
      ...seo({
        title: post.title,
        description: post.description,
        path: `/blog/${post.slug}`,
        type: "article",
        keywords: [post.tag.toLowerCase(), "battery health", "lithium-ion", "macbook battery"],
        jsonLd: [
          articleSchema({
            title: post.title,
            description: post.description,
            slug: post.slug,
            datePublished: post.date,
          }),
          breadcrumbSchema([
            { name: "Blog", path: "/blog" },
            { name: post.title, path: `/blog/${post.slug}` },
          ]),
        ],
      }),
    };
  },
});

function PostPage() {
  const { slug } = Route.useParams();
  const post = getPost(slug);

  if (!post) {
    return (
      <div className="py-10 text-center">
        <h1 className="text-2xl font-semibold tracking-tight">Post not found</h1>
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
          <span className="rounded bg-primary/15 px-1.5 text-primary">{post.tag}</span>
          <span>{post.displayDate}</span>
          <span aria-hidden>·</span>
          <span>{post.readingMinutes} min read</span>
        </div>
        <h1 className="mt-3 text-4xl font-semibold tracking-tight text-balance">{post.title}</h1>
        <p className="mt-4 text-lg leading-relaxed text-pretty text-muted-foreground">
          {post.description}
        </p>
      </header>

      <hr className="my-10 border-border" />

      <Content />

      <aside className="mt-16 rounded-lg border border-border bg-surface-1 p-6 text-center">
        <h2 className="text-xl font-semibold tracking-tight">Let eWiz handle the hard part.</h2>
        <p className="mx-auto mt-2 max-w-md text-sm leading-relaxed text-muted-foreground">
          Charge limiting, sleep-safe enforcement, and heat-aware charging. The science above,
          turned into a setting you configure once. $2.99, free for 30 days.
        </p>
        <div className="mt-5 flex justify-center">
          <Button render={<Link to="/" />} nativeButton={false} className="text-[15px]">
            Meet eWiz
          </Button>
        </div>
      </aside>
    </article>
  );
}
