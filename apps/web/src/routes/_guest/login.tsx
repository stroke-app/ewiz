import { AppleIcon, GoogleIcon } from "@hugeicons/core-free-icons";
import { createFileRoute, Link } from "@tanstack/react-router";

import { Icon } from "#/components/icon";
import { AppIcon } from "#/components/logo";
import { SignInSocialButton } from "#/components/sign-in-social-button";
import { seo } from "#/lib/seo";

export const Route = createFileRoute("/_guest/login")({
  head: () => ({ ...seo({ title: "Sign in", path: "/login", noindex: true }) }),
  component: LoginForm,
});

function LoginForm() {
  const { redirectUrl, providers } = Route.useRouteContext();

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1.5">
        <Link to="/" aria-label="eWiz" className="mb-2 w-fit">
          <AppIcon className="size-11" />
        </Link>
        <h1 className="text-xl font-semibold">Sign in to eWiz</h1>
        <p className="text-sm text-muted-foreground">New here? Signing in creates your account.</p>
      </div>

      <div className="grid gap-3">
        {providers.apple ? (
          <SignInSocialButton
            provider="apple"
            callbackURL={redirectUrl}
            icon={<Icon icon={AppleIcon} className="size-4" />}
          />
        ) : null}
        {providers.google ? (
          <SignInSocialButton
            provider="google"
            callbackURL={redirectUrl}
            icon={<Icon icon={GoogleIcon} className="size-4" />}
          />
        ) : null}
        {!providers.apple && !providers.google ? (
          <p className="text-sm text-muted-foreground">Sign-in isn't available right now.</p>
        ) : null}
      </div>
    </div>
  );
}
