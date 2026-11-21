import { useRouterState } from "@tanstack/react-router";
import posthog from "posthog-js";
import { PostHogProvider, usePostHog } from "posthog-js/react";
import { type ReactNode, useEffect, useRef } from "react";

import { env } from "#/env/client";
import { useAuth } from "#/lib/auth/hooks";

const POSTHOG_KEY = env.VITE_PUBLIC_POSTHOG_KEY;

// Initialise as soon as this module loads in the browser, before any component's
// effects run. React runs a child's effects before its parent's, so initialising in
// <Analytics>'s own effect let <PageViewTracker> capture the landing page's $pageview
// first, and posthog-js drops anything captured before init: every visitor's first
// page, and so every one-page visit, went uncounted. (Never runs during SSR.)
if (typeof window !== "undefined" && POSTHOG_KEY && !posthog.__loaded) {
  posthog.init(POSTHOG_KEY, {
    // Through our own domain (routes/ingest.$.ts) so ad blockers don't drop events.
    api_host: "/ingest",
    ui_host: "https://us.posthog.com",
    // We fire pageviews ourselves off the router (see PageViewTracker), since
    // a client-side router doesn't do full page loads for PostHog to catch.
    capture_pageview: false,
    capture_pageleave: true,
    person_profiles: "identified_only",
  });
}

/** Wraps the app in PostHog; renders children untouched when no key is configured. */
export function Analytics({ children }: { children: ReactNode }) {
  if (!POSTHOG_KEY) return <>{children}</>;

  return (
    <PostHogProvider client={posthog}>
      <PageViewTracker />
      {children}
    </PostHogProvider>
  );
}

/** Sends a $pageview whenever the router lands on a new URL. */
function PageViewTracker() {
  const ph = usePostHog();
  const href = useRouterState({ select: (s) => s.location.href });

  useEffect(() => {
    if (!ph) return;
    ph.capture("$pageview", { $current_url: window.location.origin + href });
  }, [ph, href]);

  return null;
}

/**
 * Ties the signed-in user to their PostHog profile, and resets it when they
 * sign out so the next person on the machine starts fresh. Call this from the
 * authenticated layout, where the user is already loaded.
 */
export function usePostHogIdentify() {
  const ph = usePostHog();
  const { user } = useAuth();
  const wasIdentified = useRef(false);

  useEffect(() => {
    if (!ph) return;

    if (user) {
      ph.identify(user.id, { email: user.email, name: user.name });
      wasIdentified.current = true;
    } else if (wasIdentified.current) {
      ph.reset();
      wasIdentified.current = false;
    }
  }, [ph, user]);
}
