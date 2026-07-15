import { createFileRoute } from "@tanstack/react-router";

import { FAQS } from "#/components/landing/landing-data";
import { LandingPage } from "#/components/landing/landing-page";
import {
  faqSchema,
  JsonLd,
  organizationSchema,
  siteNavigationSchema,
  softwareApplicationSchema,
  websiteSchema,
} from "#/components/seo/json-ld";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/")({
  head: () => ({
    ...seo({
      path: "/",
      keywords: [
        "mac battery",
        "macbook charge limit",
        "battery care macos",
        "apple silicon battery",
        "menu bar battery app",
      ],
    }),
  }),
  component: HomePage,
});

function HomePage() {
  return (
    <>
      <JsonLd data={organizationSchema()} />
      <JsonLd data={websiteSchema()} />
      <JsonLd data={siteNavigationSchema()} />
      <JsonLd data={softwareApplicationSchema()} />
      <JsonLd data={faqSchema(FAQS.map((f) => ({ question: f.q, answer: f.a })))} />
      <LandingPage />
    </>
  );
}
