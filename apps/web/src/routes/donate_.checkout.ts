import { createFileRoute } from "@tanstack/react-router";

import { LINKS } from "#/components/landing/landing-data";

/**
 * Every Donate button (the site, and Settings › About › Donate in the app) points
 * here, and this sends the visitor on to the pay-what-you-want checkout. Keeping
 * the hop on ewiz.app means the checkout link can change without an app release.
 */
export const Route = createFileRoute("/donate_/checkout")({
  server: {
    handlers: {
      GET: () =>
        new Response(null, {
          status: 302,
          headers: { location: LINKS.donateCheckout, "cache-control": "no-store" },
        }),
    },
  },
});
