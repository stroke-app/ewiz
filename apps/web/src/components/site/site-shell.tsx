import { Link } from "@tanstack/react-router";

import { LINKS } from "#/components/landing/landing-data";
import { AppIcon, Logo } from "#/components/logo";
import { ThemeToggle } from "#/components/theme-toggle";
import { useAuth } from "#/lib/auth/hooks";
import { cn } from "#/lib/utils";

/** The single 736px reading column every marketing page is laid out on. */
export function Container({ className, ...props }: React.ComponentProps<"div">) {
  return <div className={cn("mx-auto w-full max-w-[48rem] px-4", className)} {...props} />;
}

const EYEBROW_TONE = {
  brand: "text-primary",
  rose: "text-rose",
  success: "text-success",
  warning: "text-warning",
} as const;

/** Small uppercase label above a heading. Each section picks its own color. */
export function Eyebrow({
  tone = "brand",
  className,
  ...props
}: React.ComponentProps<"p"> & { tone?: keyof typeof EYEBROW_TONE }) {
  return (
    <p className={cn("text-sm font-medium uppercase", EYEBROW_TONE[tone], className)} {...props} />
  );
}

const NAV_LINK = "transition-colors hover:text-foreground";

export function SiteHeader() {
  const { user } = useAuth();
  return (
    <header>
      <Container className="grid h-[88px] max-w-[68rem] grid-cols-[1fr_auto_1fr] items-center">
        <Link
          to="/"
          aria-label="eWiz home"
          className="justify-self-start transition-opacity hover:opacity-80"
        >
          <AppIcon className="size-8" />
        </Link>
        <nav className="flex items-center gap-3 text-sm text-muted-foreground sm:gap-6 sm:text-[15px]">
          <Link to="/" hash="pricing" className={NAV_LINK}>
            Pricing
          </Link>
          <Link to="/changelog" className={NAV_LINK}>
            Changelog
          </Link>
          <Link to="/blog" className={cn(NAV_LINK, "hidden sm:inline")}>
            Blog
          </Link>
          <a href={LINKS.feedback} target="_blank" rel="noreferrer" className={NAV_LINK}>
            Community
          </a>
        </nav>
        <Link
          to={user ? "/app" : "/login"}
          className="justify-self-end rounded-lg border border-border bg-surface-1 px-2.5 py-0.5 text-sm whitespace-nowrap transition-colors hover:bg-surface-2 sm:text-[15px]"
        >
          {user ? "Dashboard" : "Sign in"}
        </Link>
      </Container>
    </header>
  );
}

type FooterLink = { label: string } & (
  | {
      to: "/" | "/download" | "/changelog" | "/blog" | "/legal/privacy" | "/legal/terms";
      hash?: string;
    }
  | { href: string }
);

const FOOTER_COLUMNS: Array<{ title: string; links: FooterLink[] }> = [
  {
    title: "Product",
    links: [
      { label: "Pricing", to: "/", hash: "pricing" },
      { label: "Download", to: "/download" },
      { label: "Changelog", to: "/changelog" },
      { label: "Blog", to: "/blog" },
    ],
  },
  {
    title: "Connect",
    links: [
      { label: "X / Twitter", href: LINKS.x },
      { label: "GitHub", href: LINKS.github },
      { label: "Report an issue", href: LINKS.feedback },
    ],
  },
  {
    title: "More",
    links: [
      { label: "Stroke", href: LINKS.stroke },
      { label: "nischal-dahal.com.np", href: LINKS.site },
    ],
  },
  {
    title: "Legal",
    links: [
      { label: "Privacy policy", to: "/legal/privacy" },
      { label: "Terms of service", to: "/legal/terms" },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="mt-24">
      <Container className="max-w-[68rem]">
        <div className="grid grid-cols-2 gap-8 border-t border-border pt-10 pb-8 sm:grid-cols-[1fr_auto_auto_auto_auto] sm:gap-12">
          <div className="col-span-2 sm:col-span-1">
            <Logo />
            <p className="mt-3 max-w-56 text-sm text-muted-foreground">
              Battery care for your Mac, built by one developer.
            </p>
          </div>
          {FOOTER_COLUMNS.map((col) => (
            <div key={col.title}>
              <p className="text-sm font-medium">{col.title}</p>
              <ul className="mt-3 space-y-2 text-sm text-muted-foreground">
                {col.links.map((l) => (
                  <li key={l.label}>
                    {"href" in l ? (
                      <a href={l.href} target="_blank" rel="noreferrer" className={NAV_LINK}>
                        {l.label}
                      </a>
                    ) : (
                      <Link to={l.to} hash={l.hash} className={NAV_LINK}>
                        {l.label}
                      </Link>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>
        <div className="flex items-center justify-between border-t border-border py-6 text-sm text-muted-foreground">
          <p>© 2026 eWiz</p>
          <ThemeToggle />
        </div>
      </Container>
    </footer>
  );
}

/** Header + footer around a marketing page. `backdrop` paints behind the header and content. */
export function SitePage({
  children,
  backdrop,
}: {
  children: React.ReactNode;
  backdrop?: React.ReactNode;
}) {
  return (
    <div className="relative isolate flex min-h-svh flex-col bg-background text-foreground">
      {backdrop}
      <SiteHeader />
      <main className="flex-1">{children}</main>
      <SiteFooter />
    </div>
  );
}
