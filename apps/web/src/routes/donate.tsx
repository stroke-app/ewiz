import { SiGithub } from "@icons-pack/react-simple-icons";
import { createFileRoute, Link } from "@tanstack/react-router";
import { BugIcon, HeartIcon, StarIcon } from "lucide-react";

import { useCheckout } from "#/components/buy-button";
import { LINKS, PRICE } from "#/components/landing/landing-data";
import { Container, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";
import { seo } from "#/lib/seo";

// Copies of the app up to 0.19.10 open this page from Settings › About › Donate;
// newer ones go straight to /donate/checkout.
export const Route = createFileRoute("/donate")({
  head: () => ({
    ...seo({
      title: "Support eWiz",
      description:
        "Donate any amount, buy a license, star the repo or report a bug to keep eWiz going.",
      path: "/donate",
    }),
  }),
  component: DonatePage,
});

function DonatePage() {
  const { buy, loading } = useCheckout();
  const ways = [
    {
      icon: StarIcon,
      title: "Star it on GitHub",
      body: "It helps other Mac owners find eWiz.",
      href: LINKS.github,
      cta: "Open GitHub",
    },
    {
      icon: BugIcon,
      title: "Report a bug or idea",
      body: "Bug reports and ideas decide what gets fixed and built next.",
      href: LINKS.feedback,
      cta: "Open an issue",
    },
  ];
  return (
    <SitePage>
      <Container className="max-w-[38rem] pt-10">
        <HeartIcon className="size-8 fill-rose text-rose" aria-hidden />
        <h1 className="mt-4 text-3xl font-semibold tracking-tight">Support eWiz</h1>
        <p className="mt-2 text-lg leading-relaxed text-pretty text-muted-foreground">
          eWiz is made by one person. Donate whatever it&apos;s worth to you, or buy a license for{" "}
          {PRICE} once. Either keeps updates coming for everyone.
        </p>
        <div className="mt-6 flex flex-wrap gap-2">
          <Button
            render={<a href="/donate/checkout" aria-label="Donate any amount" />}
            nativeButton={false}
            className="text-[15px]"
          >
            <HeartIcon className="size-4" aria-hidden />
            Donate any amount
          </Button>
          <Button
            type="button"
            variant="outline"
            onClick={buy}
            disabled={loading}
            className="text-[15px]"
          >
            Buy a license · {PRICE}
          </Button>
        </div>
        <div className="mt-10 flex flex-col gap-3">
          {ways.map((w) => (
            <a
              key={w.title}
              href={w.href}
              target="_blank"
              rel="noreferrer"
              className="flex items-center gap-4 rounded-lg border border-border bg-surface-1 px-4 py-3 transition-colors hover:bg-surface-2"
            >
              <w.icon className="size-5 shrink-0 text-muted-foreground" aria-hidden />
              <span className="flex-1">
                <span className="block font-medium">{w.title}</span>
                <span className="block text-sm text-muted-foreground">{w.body}</span>
              </span>
              <span className="flex items-center gap-1.5 text-sm text-muted-foreground">
                <SiGithub className="size-3.5" aria-hidden />
                {w.cta}
              </span>
            </a>
          ))}
        </div>
        <p className="mt-8 text-sm text-muted-foreground">
          Already bought it?{" "}
          <Link to="/app" className="text-primary underline-offset-4 hover:underline">
            Manage your license
          </Link>
          .
        </p>
      </Container>
    </SitePage>
  );
}
