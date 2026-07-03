import {
  GithubIcon,
  GoogleIcon,
  Loading03Icon,
  LockPasswordIcon,
  Mail02Icon,
} from "@hugeicons/core-free-icons";
import { useMutation } from "@tanstack/react-query";
import { createFileRoute, Link } from "@tanstack/react-router";
import { toast } from "sonner";

import { AuthField } from "#/components/auth/auth-field";
import { Icon } from "#/components/icon";
import { BatteryMark } from "#/components/logo";
import { SignInSocialButton } from "#/components/sign-in-social-button";
import { Button } from "#/components/ui/button";
import { authClient } from "#/lib/auth/auth-client";

export const Route = createFileRoute("/_guest/login")({
  component: LoginForm,
});

function LoginForm() {
  const { redirectUrl } = Route.useRouteContext();

  const { mutate: emailLoginMutate, isPending } = useMutation({
    mutationFn: async (data: { email: string; password: string }) =>
      await authClient.signIn.email(
        {
          ...data,
          callbackURL: redirectUrl,
        },
        {
          onError: ({ error }) => {
            toast.error(error.message || "An error occurred while signing in.");
          },
        },
      ),
  });

  const handleSubmit = (e: React.SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (isPending) return;

    const formData = new FormData(e.currentTarget);
    const email = formData.get("email") as string;
    const password = formData.get("password") as string;

    if (!email || !password) return;

    emailLoginMutate({ email, password });
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1.5">
        <Link to="/" aria-label="Battlify" className="mb-2 w-fit">
          <BatteryMark className="size-8 text-foreground" accent />
        </Link>
        <h1 className="font-display text-2xl font-bold tracking-tight">Sign in to your account</h1>
        <p className="text-sm text-muted-foreground">
          No account?{" "}
          <Link to="/signup" className="text-primary hover:underline">
            Create one
          </Link>
        </p>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-5">
        <AuthField
          id="email"
          name="email"
          type="email"
          label="Email"
          icon={<Icon icon={Mail02Icon} />}
          placeholder="Enter your email..."
          readOnly={isPending}
          required
        />
        <AuthField
          id="password"
          name="password"
          type="password"
          label="Password"
          icon={<Icon icon={LockPasswordIcon} />}
          placeholder="Enter your password..."
          readOnly={isPending}
          required
          rightSlot={
            <Link to="/login" className="text-xs text-muted-foreground hover:text-foreground">
              Forgot password?
            </Link>
          }
        />
        <Button type="submit" className="mt-1 h-10 w-full" disabled={isPending}>
          {isPending && <Icon icon={Loading03Icon} className="animate-spin" />}
          {isPending ? "Signing in..." : "Sign in"}
        </Button>
      </form>

      <div className="relative text-center text-xs tracking-wide text-muted-foreground uppercase after:absolute after:inset-0 after:top-1/2 after:z-0 after:flex after:items-center after:border-t after:border-border">
        <span className="relative z-10 bg-background px-3">Or continue with</span>
      </div>

      <div className="grid gap-3">
        <SignInSocialButton
          provider="google"
          callbackURL={redirectUrl}
          disabled={isPending}
          icon={<Icon icon={GoogleIcon} className="size-4" />}
        />
        <SignInSocialButton
          provider="github"
          callbackURL={redirectUrl}
          disabled={isPending}
          icon={<Icon icon={GithubIcon} className="size-4" />}
        />
      </div>
    </div>
  );
}
