import { createFileRoute } from "@tanstack/react-router";

import { POSTS } from "#/lib/blog/posts";
import { absoluteUrl } from "#/lib/seo";

interface UrlEntry {
  path: string;
  changefreq: "daily" | "weekly" | "monthly" | "yearly";
  priority: string;
  lastmod?: string;
}

/** Only indexable, canonical pages. The /privacy + /terms duplicates are
 *  noindex and canonicalized to /legal/*, so they are intentionally omitted. */
function urls(): UrlEntry[] {
  const staticPages: UrlEntry[] = [
    { path: "/", changefreq: "weekly", priority: "1.0" },
    { path: "/download", changefreq: "weekly", priority: "0.9" },
    { path: "/blog", changefreq: "weekly", priority: "0.8" },
    { path: "/changelog", changefreq: "weekly", priority: "0.6" },
    { path: "/legal/privacy", changefreq: "yearly", priority: "0.3" },
    { path: "/legal/terms", changefreq: "yearly", priority: "0.3" },
  ];

  const posts: UrlEntry[] = POSTS.map((p) => ({
    path: `/blog/${p.slug}`,
    changefreq: "monthly",
    priority: "0.7",
    lastmod: p.date,
  }));

  return [...staticPages, ...posts];
}

export const Route = createFileRoute("/sitemap.xml")({
  server: {
    handlers: {
      GET: () => {
        const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls()
  .map(
    (u) =>
      `  <url>\n    <loc>${absoluteUrl(u.path)}</loc>\n${
        u.lastmod ? `    <lastmod>${u.lastmod}</lastmod>\n` : ""
      }    <changefreq>${u.changefreq}</changefreq>\n    <priority>${u.priority}</priority>\n  </url>`,
  )
  .join("\n")}
</urlset>
`;

        return new Response(body, {
          headers: {
            "content-type": "application/xml; charset=utf-8",
            "cache-control": "public, max-age=3600",
          },
        });
      },
    },
  },
});
