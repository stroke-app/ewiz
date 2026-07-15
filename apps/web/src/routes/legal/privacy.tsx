import { createFileRoute, Link } from "@tanstack/react-router";

import { seo } from "#/lib/seo";

export const Route = createFileRoute("/legal/privacy")({
  head: () => ({
    ...seo({
      title: "Privacy Policy",
      description:
        "How Battlify collects, uses, and protects your information. Essential cookies only, no tracking or advertising profiles.",
      path: "/legal/privacy",
    }),
  }),
  component: PrivacyPage,
});

function PrivacyPage() {
  return (
    <article>
      <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">Legal</p>
      <h1 className="font-display mt-3 text-4xl font-bold tracking-tight">Privacy Policy</h1>
      <p className="mt-3 text-sm text-muted-foreground">Effective January 5, 2026</p>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">
        1. What this Privacy Policy covers
      </h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          This Privacy Policy explains how Nischal Dahal (&ldquo;Battlify,&rdquo;
          &ldquo;we,&rdquo; &ldquo;us&rdquo;) collects, uses, and protects your information when you
          visit the Battlify website, create an account, or purchase a license. It covers the
          marketing and licensing website only. The Battlify desktop app connects to your Mac&apos;s
          power management locally and does not route your data through our servers.
        </p>
        <p>
          By using the website or purchasing a license, you agree to the practices described here.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">2. Information we collect</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          <span className="font-medium text-foreground">Account data.</span> When you create an
          account, we store your name and email address. If you sign in with GitHub or Google, we
          receive your name and email from that provider through our authentication layer (Better
          Auth). We do not receive or store your password when you use a social login.
        </p>
        <p>
          <span className="font-medium text-foreground">Payment information.</span> Purchases are
          processed by Dodo Payments, which acts as the Merchant of Record. Your card details are
          handled entirely by Dodo Payments and are{" "}
          <span className="font-medium text-foreground">
            never stored on, or transmitted through, our servers
          </span>
          . We receive only the records we need to fulfill and support your purchase, such as a
          transaction reference and the fact that a license was issued.
        </p>
        <p>
          <span className="font-medium text-foreground">Device data for licensing.</span> To lock a
          license to a single Mac, the desktop app derives a{" "}
          <span className="font-medium text-foreground">device code</span>, a one-way hash of your
          Mac&apos;s hardware identifier. We store this device code together with your purchase
          record so a license can be tied to one machine. The device code cannot be reversed to
          reveal your hardware identifier.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">3. How we use information</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>We use the information we collect to:</p>
        <ul className="list-disc space-y-2 pl-6">
          <li>Create and manage your account and license.</li>
          <li>Process your purchase and issue your license key.</li>
          <li>Tie a license to a single Mac and enable moving it to a new Mac.</li>
          <li>Provide customer support and respond to your requests.</li>
          <li>Send essential service messages, such as receipts and important notices.</li>
          <li>Detect, prevent, and address fraud, abuse, or security issues.</li>
          <li>Comply with our legal obligations.</li>
        </ul>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">4. Data retention</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          We keep your information only as long as necessary for the purposes described in this
          policy, to support your license, and to meet legal or accounting requirements. If you ask
          us to delete your account, we will delete or anonymize your personal data within 30 days,
          except where we are required to retain certain records (for example, tax and payment
          records held by our payment processor).
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">5. Disclosure of information</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>We do not sell your personal information. We disclose information only:</p>
        <ul className="list-disc space-y-2 pl-6">
          <li>
            To service providers who help us operate the website, process payments, and host our
            data, and only to the extent they need it to perform those services.
          </li>
          <li>
            When required by law, regulation, legal process, or a valid government request.
          </li>
          <li>
            In connection with a merger, acquisition, or sale of assets, in which case we will
            notify you before your information becomes subject to a different privacy policy.
          </li>
        </ul>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">6. Third-party services</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>We rely on a small number of trusted providers to run Battlify:</p>
        <ul className="list-disc space-y-2 pl-6">
          <li>
            <span className="font-medium text-foreground">Dodo Payments</span>, payment processing
            and Merchant of Record. See their{" "}
            <a
              href="https://dodopayments.com/"
              target="_blank"
              rel="noreferrer"
              className="text-primary underline underline-offset-4"
            >
              privacy policy
            </a>
            .
          </li>
          <li>
            <span className="font-medium text-foreground">Cloudflare</span>, website hosting and
            database (Workers and D1). See their{" "}
            <a
              href="https://www.cloudflare.com/privacypolicy/"
              target="_blank"
              rel="noreferrer"
              className="text-primary underline underline-offset-4"
            >
              privacy policy
            </a>
            .
          </li>
        </ul>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">7. Cookies &amp; security</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          We use <span className="font-medium text-foreground">essential cookies only</span>, the
          authentication and session cookies needed to keep you signed in and to secure your
          account. We do{" "}
          <span className="font-medium text-foreground">not use analytics or tracking cookies</span>
          , and we do not build advertising profiles.
        </p>
        <p>
          Your license verifies <span className="font-medium text-foreground">offline</span>: the
          license key is a signed token the app checks on your Mac, so Battlify does not phone home
          to use your license and does not route your data through our servers.
        </p>
        <p>
          We take reasonable technical and organizational measures to protect your information. No
          method of transmission or storage is perfectly secure, but if a data breach affecting your
          personal data occurs, we will notify affected users within 72 hours of becoming aware of
          it, where required by law.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">8. Children</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          Battlify is not directed to children. We do not knowingly collect personal information
          from anyone under the age of 13. If you believe a child has provided us with personal
          information, please contact us and we will delete it.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">9. Changes to this policy</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          We may update this Privacy Policy from time to time. When we make material changes, we
          will update the effective date above and, where appropriate, notify you. Your continued
          use of the website after changes take effect means you accept the updated policy.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">10. Contact</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          Questions about this Privacy Policy or your data? Contact{" "}
          Nischal Dahal at{" "}
          <a
            href="mailto:nischaldahal01395@gmail.com"
            className="text-primary underline underline-offset-4"
          >
            nischaldahal01395@gmail.com
          </a>
          .
        </p>
        <p className="pt-4 text-foreground">
          See also:{" "}
          <Link to="/legal/terms" className="text-primary underline underline-offset-4">
            Terms of Service
          </Link>
          .
        </p>
      </div>
    </article>
  );
}
