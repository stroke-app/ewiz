import handler, { createServerEntry } from "@tanstack/react-start/server-entry";

/**
 * The pre-rename host stays attached so links baked into older installs keep
 * working, but it permanently redirects to ewiz.app so search engines index a
 * single site. 308 keeps the method and body for non-GET requests.
 */
const LEGACY_HOSTS = new Set(["battlify.discerns.app"]);

export default createServerEntry({
  fetch(request) {
    const url = new URL(request.url);
    if (LEGACY_HOSTS.has(url.hostname)) {
      url.protocol = "https:";
      url.hostname = "ewiz.app";
      url.port = "";
      const status = request.method === "GET" || request.method === "HEAD" ? 301 : 308;
      return Response.redirect(url.toString(), status);
    }
    return handler.fetch(request);
  },
});
