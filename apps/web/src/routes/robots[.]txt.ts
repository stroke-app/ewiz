import { createFileRoute } from "@tanstack/react-router";

import { absoluteUrl } from "#/lib/seo";

/**
 * Dynamic robots.txt. Crawlers are welcome on the public marketing pages; the
 * app, auth, checkout, and API routes are kept out of the index. The sitemap
 * URL is built from VITE_BASE_URL so it is correct in every environment.
 */
export const Route = createFileRoute("/robots.txt")({
  server: {
    handlers: {
      GET: () => {
        const body = [
          "User-agent: *",
          "Allow: /",
          "Disallow: /app",
          "Disallow: /login",
          "Disallow: /signup",
          "Disallow: /buy",
          "Disallow: /api/",
          "",
          `Sitemap: ${absoluteUrl("/sitemap.xml")}`,
          "",
        ].join("\n");

        return new Response(body, {
          headers: {
            "content-type": "text/plain; charset=utf-8",
            "cache-control": "public, max-age=3600",
          },
        });
      },
    },
  },
});
