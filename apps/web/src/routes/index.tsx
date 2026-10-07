import { createFileRoute } from "@tanstack/react-router";

import { FAQS } from "#/components/landing/landing-data";
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
  loader: ({ context }) => context.queryClient.ensureQueryData(latestReleaseQueryOptions()),
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
        softwareApplicationSchema(loaderData),
        faqSchema(FAQS.map((f) => ({ question: f.q, answer: f.a }))),
      ],
    }),
  }),
  component: HomePage,
});

function HomePage() {
  return <LandingPage />;
}
