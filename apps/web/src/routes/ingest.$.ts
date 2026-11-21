import { createFileRoute } from "@tanstack/react-router";

/**
 * PostHog reverse proxy: the browser sends analytics to ewiz.app/ingest/* instead of
 * us.i.posthog.com, so ad blockers (common among Mac users) don't drop the events.
 * https://posthog.com/docs/advanced/proxy/cloudflare
 */
const API_HOST = "us.i.posthog.com";
const ASSET_HOST = "us-assets.i.posthog.com";

async function proxy({ request }: { request: Request }): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/ingest/, "") || "/";
  const host = path.startsWith("/static/") || path.startsWith("/array/") ? ASSET_HOST : API_HOST;
  const target = new URL(path + url.search, `https://${host}`);

  const headers = new Headers(request.headers);
  headers.set("host", host);
  headers.delete("cookie");
  // Keep the visitor's IP so PostHog's geolocation reflects them, not the edge.
  const ip = request.headers.get("cf-connecting-ip");
  if (ip) headers.set("x-forwarded-for", ip);

  const upstream = await fetch(target, {
    method: request.method,
    headers,
    body: request.method === "GET" || request.method === "HEAD" ? undefined : request.body,
    redirect: "manual",
  });
  const out = new Headers(upstream.headers);
  out.delete("set-cookie");
  return new Response(upstream.body, { status: upstream.status, headers: out });
}

export const Route = createFileRoute("/ingest/$")({
  server: {
    handlers: { GET: proxy, POST: proxy, OPTIONS: proxy },
  },
});
