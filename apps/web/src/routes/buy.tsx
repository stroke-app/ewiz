import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * The desktop app's "Buy Battlify" button opens battlify.app/buy. Funnel it to
 * the dashboard, which walks the user through sign-in → checkout → device link.
 */
export const Route = createFileRoute("/buy")({
  beforeLoad: () => {
    throw redirect({ to: "/app" });
  },
});
