import { createFileRoute } from "@tanstack/react-router";

import { FAQS, HEADLINES } from "#/components/landing/landing-data";
import { LandingPage } from "#/components/landing/landing-page";
import {
  faqSchema,
  organizationSchema,
  siteNavigationSchema,
  softwareApplicationSchema,
  websiteSchema,
} from "#/components/seo/json-ld";
import { latestReleaseQueryOptions } from "#/lib/releases/queries";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/")({
  loader: async ({ context }) => ({
    latest: await context.queryClient.ensureQueryData(latestReleaseQueryOptions()),
    // A different headline leads each visit. Picked here, not in the component,
    // so the server render and the hydrated page show the same one.
    headline: Math.floor(Math.random() * HEADLINES.length),
  }),
  head: ({ loaderData }) => ({
    ...seo({
      path: "/",
      keywords: [
        "mac battery",
        "macbook charge limit",
        "battery care macos",
        "apple silicon battery",
        "menu bar battery app",
        "eWiz",
      ],
      jsonLd: [
        organizationSchema(),
        websiteSchema(),
        siteNavigationSchema(),
        softwareApplicationSchema(loaderData?.latest),
        faqSchema(FAQS.map((f) => ({ question: f.q, answer: f.a }))),
      ],
    }),
  }),
  component: HomePage,
});

function HomePage() {
  const { headline } = Route.useLoaderData();
  return <LandingPage headline={headline} />;
}
