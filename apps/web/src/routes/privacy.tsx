import { createFileRoute } from "@tanstack/react-router";

import { LegalLayout, Section } from "#/components/legal/legal-layout";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy Policy — Battlify" },
      {
        name: "description",
        content:
          "How Battlify handles your data: the app runs on your Mac, and our servers only touch your account and license.",
      },
    ],
  }),
  component: PrivacyPage,
});

function PrivacyPage() {
  return (
    <LegalLayout
      eyebrow="Privacy Policy"
      title="Your battery is your business."
      updated="July 14, 2026"
      intro={
        <p>
          The short version: the Battlify app works entirely on your Mac, and our servers only ever
          handle accounts and licenses. There&apos;s no telemetry, no analytics in the app, and no
          ad tracking anywhere.
        </p>
      }
    >
      <Section n="01" title="What stays on your Mac">
        <p>
          Everything Battlify does to look after your battery happens locally. Your charge limit,
          temperature threshold, sleep behavior, MagSafe LED preference, and every battery and
          charging reading it uses <b>never leave your device</b>. The desktop app sends us no usage
          analytics and no telemetry, full stop.
        </p>
      </Section>

      <Section n="02" title="What we collect for accounts">
        <p>
          You only create an account when you buy a license. At that point we store the minimum
          needed to attach a license to you and keep it working:
        </p>
        <ul>
          <li>
            Basic identity from your <b>GitHub</b> or <b>Google</b> sign-in (name, email, avatar).
          </li>
          <li>Session data — cookies and security metadata — so you stay signed in.</li>
          <li>
            License details, including a device code so a license can be bound to one Mac at a time.
          </li>
          <li>Payment status (paid / refunded) as reported by our payment processor.</li>
        </ul>
      </Section>

      <Section n="03" title="What we don't collect">
        <p>
          We don&apos;t collect your battery history, charge patterns, hardware serials, app usage
          analytics, or any advertising identifiers. There are no third-party analytics or
          advertising trackers on this website.
        </p>
      </Section>

      <Section n="04" title="Cookies on this website">
        <p>Only two functional cookies are used, and neither is for tracking:</p>
        <ul>
          <li>A session cookie, so you stay signed in to your dashboard.</li>
          <li>A theme cookie, to remember light or dark mode.</li>
        </ul>
      </Section>

      <Section n="05" title="Third parties we rely on">
        <ul>
          <li>
            <b>Dodo Payments</b> — our merchant of record, processes checkout and billing. We never
            see your card details.
          </li>
          <li>
            <b>GitHub</b> and <b>Google</b> — for sign-in, when you choose to create an account.
          </li>
          <li>Our hosting provider — serves this website and the account/license API.</li>
        </ul>
        <p>Each operates under its own privacy policy.</p>
      </Section>

      <Section n="06" title="Your rights">
        <p>
          You can view your account and license from your dashboard at any time, and you can request
          a copy of your data, a correction, or deletion. We honor these requests for everyone,
          wherever you are. Deleting your account removes the personal data we hold; local app data
          on your Mac is yours to keep or remove.
        </p>
      </Section>

      <Section n="07" title="Contact">
        <p>
          For any privacy question, open an issue on{" "}
          <a
            href="https://github.com/broisnischal/battlify/issues"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHub
          </a>{" "}
          or reach out from your dashboard.
        </p>
      </Section>
    </LegalLayout>
  );
}
