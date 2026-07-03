import { createFileRoute, Link } from "@tanstack/react-router";

export const Route = createFileRoute("/legal/terms")({
  component: TermsPage,
});

function TermsPage() {
  return (
    <article>
      <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">Legal</p>
      <h1 className="font-display mt-3 text-4xl font-bold tracking-tight">Terms of Service</h1>
      <p className="mt-3 text-sm text-muted-foreground">Effective January 5, 2026</p>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">
        1. Introduction &amp; acceptance
      </h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          These Terms of Service (&ldquo;Terms&rdquo;) govern your use of the Battlify website, your
          account, and the Battlify desktop app (together, the &ldquo;Service&rdquo;), provided by{" "}
          <code>[LEGAL_ENTITY]</code> (&ldquo;Battlify,&rdquo; &ldquo;we,&rdquo; &ldquo;us&rdquo;).
          By creating an account, purchasing a license, or using the Service, you agree to these
          Terms. If you do not agree, do not use the Service.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">2. Eligibility</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          You must be at least 13 years old to use the Service. By using it, you represent that you
          meet this requirement and that you are able to form a binding agreement with us.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">3. Accounts</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          You need an account to purchase and manage a license. You can register with an email and
          password or through GitHub or Google. You are responsible for keeping your account
          credentials secure and for all activity under your account. You may not use bots or
          automated means to create accounts or access the Service. Notify us promptly of any
          unauthorized use of your account.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">4. License grant</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          When you purchase Battlify for a one-time price of $2.99, we grant you a{" "}
          <span className="font-medium text-foreground">
            perpetual, non-exclusive, non-transferable
          </span>{" "}
          license to use Battlify. This is a one-time purchase, not a subscription.
        </p>
        <p>
          Your license is{" "}
          <span className="font-medium text-foreground">locked to one Mac</span> via a device code
          (a one-way hash of your Mac&apos;s hardware identifier). You may{" "}
          <span className="font-medium text-foreground">
            move your license to a new Mac once every 30 days
          </span>
          .
        </p>
        <p>
          You may{" "}
          <span className="font-medium text-foreground">not</span> redistribute, resell, sublicense,
          or share your license key, nor attempt to circumvent, disable, or tamper with the
          licensing or device-locking mechanisms.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">
        5. Acceptable use &amp; prohibited conduct
      </h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>You agree not to:</p>
        <ul className="list-disc space-y-2 pl-6">
          <li>Reverse engineer, decompile, or attempt to derive the source of the licensed app, except where the law expressly permits it.</li>
          <li>Circumvent, disable, or interfere with licensing, security, or authentication features.</li>
          <li>Use the Service to violate any law or infringe the rights of others.</li>
          <li>Attempt to gain unauthorized access to the Service, other accounts, or our systems.</li>
          <li>Resell, redistribute, or commercially exploit the Service or license keys.</li>
        </ul>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">6. Payment &amp; refunds</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          Battlify is a one-time purchase of $2.99, processed by Dodo Payments as the Merchant of
          Record. Dodo Payments handles card processing and applicable taxes; we never see your card
          details.
        </p>
        <p>
          Battlify is{" "}
          <span className="font-medium text-foreground">free for 30 days</span> so you can evaluate
          it fully before buying. Because of this trial,{" "}
          <span className="font-medium text-foreground">
            purchases are generally non-refundable
          </span>
          . If you believe your situation warrants a refund, you may send a request to{" "}
          <a href="mailto:[CONTACT_EMAIL]" className="text-primary underline underline-offset-4">
            [CONTACT_EMAIL]
          </a>
          ; approved refunds are handled through Dodo Payments.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">7. Intellectual property</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          Battlify, its name, branding, and code are owned by <code>[LEGAL_ENTITY]</code> and are
          protected by intellectual property laws. Your license grants you a right to use the
          software, not ownership of it. Open-source components included in Battlify remain governed
          by their own respective licenses, as noted in the{" "}
          <a
            href="https://github.com/broisnischal/battlify"
            target="_blank"
            rel="noreferrer"
            className="text-primary underline underline-offset-4"
          >
            project repository
          </a>
          .
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">8. Disclaimer of warranties</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          The Service is provided{" "}
          <span className="font-medium text-foreground">
            &ldquo;as is&rdquo; and &ldquo;as available&rdquo;
          </span>{" "}
          without warranties of any kind, whether express or implied, including but not limited to
          warranties of merchantability, fitness for a particular purpose, and non-infringement. We
          do not warrant that the Service will be uninterrupted, error-free, or that it will extend
          the life of any particular battery.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">9. Limitation of liability</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          To the maximum extent permitted by law, <code>[LEGAL_ENTITY]</code> will not be liable for
          any indirect, incidental, special, consequential, or punitive damages, or for any loss of
          data, hardware, or profits, arising out of or related to your use of the Service. Our
          total liability for any claim relating to the Service will not exceed the amount you paid
          for your license.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">10. Termination</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          We may suspend or terminate your access to the Service and your license if you violate
          these Terms or use the Service in a way that harms us or others. Provisions that by their
          nature should survive termination — including intellectual property, disclaimers, and
          limitation of liability — will survive.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">
        11. Changes to the service &amp; terms
      </h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          We may update the Service and these Terms from time to time. When we make material
          changes, we will update the effective date and, where appropriate, notify you. For any
          change to pricing, we will provide at least 30 days&apos; notice. Your continued use of the
          Service after changes take effect means you accept the updated Terms.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">12. Governing law</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          These Terms are governed by the laws of <code>[JURISDICTION]</code>, without regard to its
          conflict-of-laws rules. You agree to the exclusive jurisdiction of the courts located
          there for any dispute arising out of or relating to these Terms or the Service.
        </p>
      </div>

      <h2 className="font-display mt-10 mb-3 text-xl font-semibold">13. Contact</h2>
      <div className="space-y-4 text-sm leading-relaxed text-muted-foreground">
        <p>
          Questions about these Terms? Contact <code>[LEGAL_ENTITY]</code> at{" "}
          <a href="mailto:[CONTACT_EMAIL]" className="text-primary underline underline-offset-4">
            [CONTACT_EMAIL]
          </a>
          .
        </p>
        <p className="pt-4 text-foreground">
          See also:{" "}
          <Link to="/legal/privacy" className="text-primary underline underline-offset-4">
            Privacy Policy
          </Link>
          .
        </p>
      </div>
    </article>
  );
}
