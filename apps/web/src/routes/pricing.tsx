import { createFileRoute, Link } from "@tanstack/react-router";
import {
  CodeIcon,
  CreditCardIcon,
  HourglassIcon,
  KeyRoundIcon,
  LaptopIcon,
  Undo2Icon,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

import { PRICE } from "#/components/landing/landing-data";
import { PricingPlans } from "#/components/pricing-plans";
import { breadcrumbSchema, softwareApplicationSchema } from "#/components/seo/json-ld";
import { Container, Eyebrow, SitePage } from "#/components/site/site-shell";
import { latestReleaseQueryOptions } from "#/lib/releases/queries";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/pricing")({
  loader: ({ context }) => context.queryClient.ensureQueryData(latestReleaseQueryOptions()),
  head: ({ loaderData }) => ({
    ...seo({
      title: "Pricing",
      description: `eWiz is free for 30 days with every feature, then a one-time ${PRICE} license for one Mac. No subscription, and updates are free for life.`,
      path: "/pricing",
      keywords: ["eWiz price", "eWiz license", "eWiz free trial", "mac battery app price"],
      jsonLd: [
        softwareApplicationSchema(loaderData),
        breadcrumbSchema([{ name: "Pricing", path: "/pricing" }]),
      ],
    }),
  }),
  component: PricingPage,
});

const LINK = "text-foreground underline underline-offset-4";

const DETAILS: Array<{ icon: LucideIcon; title: string; body: React.ReactNode }> = [
  {
    icon: HourglassIcon,
    title: "30 days, every feature",
    body: "The trial unlocks everything from the first launch. No account and no card: download it and go.",
  },
  {
    icon: LaptopIcon,
    title: "One Mac at a time",
    body: "A license is locked to one Mac. You can move it to a new Mac once every 30 days.",
  },
  {
    icon: KeyRoundIcon,
    title: "Your key, on your dashboard",
    body: "Buying needs a free eWiz account. Your license key then lives on your dashboard, where you link it to your Mac.",
  },
  {
    icon: CreditCardIcon,
    title: "Checkout by Dodo Payments",
    body: "Dodo Payments is the merchant of record: it processes the card and handles the applicable taxes. We never see your card details.",
  },
  {
    icon: Undo2Icon,
    title: "Refunds",
    body: (
      <>
        Because the trial lets you try everything first, purchases are generally non-refundable. If
        you think yours warrants one, email{" "}
        <a href="mailto:nischaldahal01395@gmail.com" className={LINK}>
          nischaldahal01395@gmail.com
        </a>
        . The{" "}
        <Link to="/legal/terms" className={LINK}>
          terms
        </Link>{" "}
        have the details.
      </>
    ),
  },
  {
    icon: CodeIcon,
    title: "Source-available",
    body: (
      <>
        The source is on GitHub under the{" "}
        <Link to="/legal/license" className={LINK}>
          eWiz License
        </Link>
        . A license buys a key for the app; the source terms are the same for everyone.
      </>
    ),
  },
];

function PricingPage() {
  return (
    <SitePage>
      <Container className="pt-10">
        <div className="text-center">
          <Eyebrow tone="success">Pricing</Eyebrow>
          <h1 className="mx-auto mt-1 max-w-lg text-3xl font-semibold tracking-tight text-balance sm:text-[2.25rem] sm:leading-[1.15]">
            Try it free for 30 days, then keep it for good
          </h1>
          <p className="mx-auto mt-3 max-w-md text-lg leading-relaxed text-pretty text-muted-foreground">
            One price, paid once. No subscription, and every update is included.
          </p>
        </div>
        <div className="mt-10">
          <PricingPlans />
        </div>

        <section className="mt-24">
          <Eyebrow>Details</Eyebrow>
          <h2 className="mt-1 text-2xl font-semibold tracking-tight">How the license works</h2>
          <dl className="mt-6 grid gap-3 sm:grid-cols-2">
            {DETAILS.map(({ icon: Icon, title, body }) => (
              <div key={title} className="rounded-lg border border-border bg-surface-1 px-4 py-3">
                <dt className="flex items-center gap-2 text-[15px] font-medium">
                  <Icon className="size-4 text-muted-foreground" aria-hidden />
                  {title}
                </dt>
                <dd className="mt-1 text-[15px] leading-relaxed text-pretty text-muted-foreground">
                  {body}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      </Container>
    </SitePage>
  );
}
