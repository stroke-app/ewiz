import { createFileRoute } from "@tanstack/react-router";

import { LegalLayout, Section } from "#/components/legal/legal-layout";
import { seo } from "#/lib/seo";

const termsSeo = seo({
  title: "Terms of Service",
  description:
    "The terms that govern your use of Battlify, the menu bar battery care app for Apple Silicon Macs.",
  // Canonical points at /legal/terms, and this URL is noindex, so search
  // engines index a single terms page even though both remain reachable.
  path: "/legal/terms",
});

export const Route = createFileRoute("/terms")({
  head: () => ({
    links: termsSeo.links,
    meta: [...termsSeo.meta, { name: "robots", content: "noindex, follow" }],
  }),
  component: TermsPage,
});

function TermsPage() {
  return (
    <LegalLayout
      eyebrow="Terms of Service"
      title="The fine print, kept short."
      updated="July 14, 2026"
      intro={
        <p>
          Battlify is a small menu-bar app that helps look after your Mac&apos;s battery. These
          terms cover the app, this website, and your license. By installing Battlify or buying a
          license, you agree to them.
        </p>
      }
    >
      <Section n="01" title="Who we are">
        <p>
          Battlify is an independent macOS app built and distributed by Nischal from{" "}
          <b>battlify.app</b>. It runs entirely on your own Mac. Creating an account or purchasing a
          license means you accept these terms.
        </p>
      </Section>

      <Section n="02" title="The software">
        <p>
          Battlify is proprietary software, protected by copyright. When you buy a license, you get
          a personal, non-transferable right to install and run Battlify on Macs you own or control.
          You may not resell, sublicense, or redistribute the app or your license key.
        </p>
        <p>
          The app is provided <b>as is</b>. It talks to low-level battery and charging controls on
          your Mac, and while it&apos;s built carefully and conservatively, you use it at your own
          discretion. See the warranty and liability sections below.
        </p>
      </Section>

      <Section n="03" title="Accounts">
        <p>
          You don&apos;t need an account to try Battlify. It&apos;s free to use for 30 days with no
          sign-up. You only create an account when you buy a license, so we can attach it to you and
          let you manage it. Sign-in is handled through <b>GitHub</b> or <b>Google</b>; we never see
          or store a password.
        </p>
      </Section>

      <Section n="04" title="Licenses">
        <p>
          A license is a <b>one-time $2.99 purchase</b> (plus any applicable tax). There is no
          subscription. It&apos;s yours forever and includes every future update.
        </p>
        <p>
          A license activates on <b>one Mac at a time</b>. If you switch to a different Mac, you can
          move your license to it once every <b>30 days</b> from your dashboard. This keeps things
          simple for genuine upgrades while discouraging casual sharing.
        </p>
      </Section>

      <Section n="05" title="Trial, payments, and refunds">
        <p>
          Battlify is free for 30 days of actual use. The countdown only advances on days you open
          the app, so you can decide before paying anything. Checkout is handled securely by{" "}
          <b>Dodo Payments</b>, our merchant of record; we never see your card details.
        </p>
        <p>
          Because you can try the full app free before buying, sales are generally final. That said,
          if you were double-charged, or your license genuinely won&apos;t activate and we
          can&apos;t fix it, reach out within <b>14 days</b> and we&apos;ll make it right.
        </p>
      </Section>

      <Section n="06" title="Acceptable use">
        <p>You agree not to:</p>
        <ul>
          <li>Circumvent, disable, or tamper with license verification.</li>
          <li>
            Reverse-engineer, decompile, or redistribute the app except where the law allows it.
          </li>
          <li>Use Battlify in any way that breaks applicable laws or harms others.</li>
        </ul>
      </Section>

      <Section n="07" title="Your data">
        <p>
          Battlify reads your Mac&apos;s battery and charging state locally to do its job. Your
          usage, battery readings, and settings <b>stay on your machine</b> and are never
          transmitted to us. Our servers only ever handle your account and license. See the{" "}
          <a href="/privacy">Privacy Policy</a> for the full picture.
        </p>
      </Section>

      <Section n="08" title="Warranty disclaimer">
        <p>
          Battlify is provided <b>&ldquo;as is&rdquo;</b> and <b>&ldquo;as available&rdquo;</b>,
          without warranties of any kind, express or implied. Battery hardware, macOS behavior, and
          charging controllers vary between machines and OS versions. We don&apos;t warrant that
          Battlify will be uninterrupted, error-free, or suitable for any particular purpose.
        </p>
      </Section>

      <Section n="09" title="Limitation of liability">
        <p>
          To the fullest extent permitted by law, Battlify and its author won&apos;t be liable for
          any indirect, incidental, or consequential damages. Total liability for any claim is
          capped at the amount you paid for your license in the 12 months before the claim.
        </p>
      </Section>

      <Section n="10" title="Changes to these terms">
        <p>
          We may update these terms from time to time. When we make a material change, we&apos;ll
          update the date at the top of this page. Continuing to use Battlify after a change means
          you accept the updated terms.
        </p>
      </Section>

      <Section n="11" title="Contact">
        <p>
          Questions, problems, or feedback? Open an issue on{" "}
          <a
            href="https://github.com/broisnischal/battlify/issues"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHub
          </a>{" "}
          or reach out from your dashboard. We read everything.
        </p>
      </Section>
    </LegalLayout>
  );
}
