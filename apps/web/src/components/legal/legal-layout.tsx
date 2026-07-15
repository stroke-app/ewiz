import { Link } from "@tanstack/react-router";
import { ArrowLeftIcon } from "lucide-react";
import type { ReactNode } from "react";

import { LINKS } from "#/components/landing/landing-data";

/* The battery mark, matched to the landing page's logo. */
function BatteryLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" aria-hidden>
      <rect x="2" y="7" width="17" height="10" rx="2.5" stroke="var(--hold)" strokeWidth="1.8" />
      <rect x="4" y="9" width="9" height="6" rx="1" fill="var(--hold)" />
      <rect x="20" y="10" width="2" height="4" rx="1" fill="var(--hold)" />
      <path d="M9.6 8.4L7.6 12h2.1l-.4 3L12 11h-1.9z" fill="#fff" />
    </svg>
  );
}

const LEGAL_NAV = [
  { to: "/terms", label: "Terms" },
  { to: "/privacy", label: "Privacy" },
  { to: "/changelog", label: "Changelog" },
] as const;

/**
 * Shared chrome for the static legal / info pages (terms, privacy, changelog).
 * Reuses the landing page's `.blf` design scope, with a permanently-solid
 * header instead of the scroll-driven one on the home page.
 */
export function LegalLayout({
  eyebrow,
  title,
  updated,
  intro,
  children,
}: {
  eyebrow: string;
  title: string;
  updated?: string;
  intro?: ReactNode;
  children: ReactNode;
}) {
  return (
    <div className="blf">
      <header className="blf-header solid legal-header">
        <div className="wrap nav">
          <Link to="/" className="brand">
            <BatteryLogo />
            Battlify
          </Link>
          <nav className="nl">
            {LEGAL_NAV.map((item) => (
              <Link key={item.to} to={item.to}>
                {item.label}
              </Link>
            ))}
          </nav>
          <Link to="/" className="buy legal-back">
            <ArrowLeftIcon />
            Home
          </Link>
        </div>
      </header>

      <main className="legal">
        <div className="wrap">
          <div className="legal-head">
            <span className="tag">
              <span className="dot" />
              {eyebrow}
            </span>
            <h1>{title}</h1>
            {updated ? <p className="legal-updated">Last updated {updated}</p> : null}
            {intro ? <div className="legal-intro">{intro}</div> : null}
          </div>

          <article className="legal-body">{children}</article>
        </div>
      </main>

      <footer className="blf-footer legal-footer">
        <div className="wrap">
          <div className="fbot">
            <span>© 2026 Battlify · built by broisnischal</span>
            <span className="legal-foot-links">
              <Link to="/terms">Terms</Link>
              <Link to="/privacy">Privacy</Link>
              <Link to="/changelog">Changelog</Link>
              <a href={LINKS.github} target="_blank" rel="noopener noreferrer">
                GitHub
              </a>
            </span>
          </div>
        </div>
      </footer>
    </div>
  );
}

/** A numbered section within a legal document. */
export function Section({ n, title, children }: { n: string; title: string; children: ReactNode }) {
  return (
    <section className="legal-section">
      <h2>
        <span className="legal-num">{n}</span>
        {title}
      </h2>
      <div className="legal-prose">{children}</div>
    </section>
  );
}
