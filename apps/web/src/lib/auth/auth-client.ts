import { dodopaymentsClient } from "@dodopayments/better-auth/client";
import { createAuthClient } from "better-auth/react";

import { env } from "#/env/client";

/**
 * https://better-auth.com/docs/concepts/client
 *
 * Our better-auth server instance lives in the TanStack Start server,
 * so authClient should only be used on the client (event handlers, effects, etc).
 *
 * For server/SSR operations, prefer `auth.api` instead, and wrap in a serverFn if needed.
 */
export const authClient = createAuthClient({
  baseURL: env.VITE_BASE_URL,
  plugins: [dodopaymentsClient()],
});

/**
 * Opens the Dodo Payments hosted checkout for the Battlify license.
 * Requires a signed-in user (checkout is `authenticatedUsersOnly`).
 * Redirects the browser to the checkout URL, or throws on failure.
 */
export async function startCheckout(referenceId: string) {
  const { data, error } = await authClient.dodopayments.checkoutSession({
    slug: "battlify",
    referenceId,
  });

  if (error) throw new Error(error.message ?? "Could not start checkout.");
  if (data?.url) window.location.href = data.url;
}
