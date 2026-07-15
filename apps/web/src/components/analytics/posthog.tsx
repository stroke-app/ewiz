import { useRouterState } from "@tanstack/react-router";
import posthog from "posthog-js";
import { PostHogProvider, usePostHog } from "posthog-js/react";
import { type ReactNode, useEffect, useRef } from "react";

import { env } from "#/env/client";
import { useAuth } from "#/lib/auth/hooks";

const POSTHOG_KEY = env.VITE_PUBLIC_POSTHOG_KEY;

/**
 * Wraps the app in PostHog. We init inside an effect so it only ever runs in
 * the browser (posthog-js touches window/localStorage and would blow up during
 * SSR). If there's no key configured, we just render children untouched.
 */
export function Analytics({ children }: { children: ReactNode }) {
  useEffect(() => {
    if (!POSTHOG_KEY || posthog.__loaded) return;
    posthog.init(POSTHOG_KEY, {
      api_host: env.VITE_PUBLIC_POSTHOG_HOST,
      // We fire pageviews ourselves off the router (see PageViewTracker), since
      // a client-side router doesn't do full page loads for PostHog to catch.
      capture_pageview: false,
      capture_pageleave: true,
      person_profiles: "identified_only",
    });
  }, []);

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
