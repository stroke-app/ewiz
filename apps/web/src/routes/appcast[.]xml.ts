import { createFileRoute } from "@tanstack/react-router";

/**
 * The in-app update feed, served from ewiz.app so the app never depends on where
 * releases are hosted. Every release attaches appcast.xml (Sparkle, the app's
 * SUFeedURL) and appcast.json (the old updater) to its GitHub release; this
 * proxies the latest one, cached at the edge for five minutes.
 */
const SOURCE = "https://github.com/stroke-app/ewiz/releases/latest/download/appcast.xml";

export const Route = createFileRoute("/appcast.xml")({
  server: {
    handlers: {
      GET: async () => {
        const upstream = await fetch(SOURCE, {
          redirect: "follow",
          cf: { cacheTtl: 300, cacheEverything: true },
        } as RequestInit);
        if (!upstream.ok) {
          return new Response("Update feed unavailable", { status: 502 });
        }
        return new Response(upstream.body, {
          headers: {
            "content-type": "application/xml; charset=utf-8",
            "cache-control": "public, max-age=300",
          },
        });
      },
    },
  },
});
