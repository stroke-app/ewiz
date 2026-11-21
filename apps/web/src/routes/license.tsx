import { createFileRoute, redirect } from "@tanstack/react-router";

/**
 * The app's license window and its "isn't linked to a Mac" error open
 * ewiz.app/license. Finding, linking and re-issuing a key all live on the
 * dashboard, which asks the visitor to sign in first.
 */
export const Route = createFileRoute("/license")({
  beforeLoad: () => {
    throw redirect({ to: "/app" });
  },
});
