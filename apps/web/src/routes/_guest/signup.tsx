import { SiGithub, SiGoogle } from "@icons-pack/react-simple-icons";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { LoaderCircleIcon, LockIcon, MailIcon, UserIcon } from "lucide-react";
import { toast } from "sonner";

import { AuthField } from "#/components/auth/auth-field";
import { BatteryMark } from "#/components/logo";
import { SignInSocialButton } from "#/components/sign-in-social-button";
import { Button } from "#/components/ui/button";
import { authClient } from "#/lib/auth/auth-client";
import { authQueryOptions } from "#/lib/auth/queries";

export const Route = createFileRoute("/_guest/signup")({
  component: SignupForm,
});

function SignupForm() {
  const { redirectUrl } = Route.useRouteContext();
  const queryClient = useQueryClient();
  const navigate = useNavigate();

  const { mutate: signupMutate, isPending } = useMutation({
    mutationFn: async (data: { name: string; email: string; password: string }) => {
      await authClient.signUp.email(
        {
          ...data,
          callbackURL: redirectUrl,
        },
        {
          onError: ({ error }) => {
            toast.error(error.message || "An error occurred while signing up.");
          },
          onSuccess: () => {
            queryClient.removeQueries({ queryKey: authQueryOptions().queryKey });
            navigate({ to: redirectUrl });
          },
        },
      );
    },
  });

  const handleSubmit = (e: React.SubmitEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (isPending) return;

    const formData = new FormData(e.currentTarget);
    const name = formData.get("name") as string;
    const email = formData.get("email") as string;
    const password = formData.get("password") as string;
    const confirmPassword = formData.get("confirm_password") as string;

    if (!name || !email || !password || !confirmPassword) return;

    if (password !== confirmPassword) {
      toast.error("Passwords do not match.");
      return;
    }

    signupMutate({ name, email, password });
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-1.5">
        <Link to="/" aria-label="Battlify" className="mb-2 w-fit">
          <BatteryMark className="size-8 text-foreground" accent />
        </Link>
        <h1 className="font-display text-2xl font-bold tracking-tight">Create your account</h1>
        <p className="text-sm text-muted-foreground">
          Already have one?{" "}
          <Link to="/login" className="text-primary hover:underline">
            Sign in
          </Link>
        </p>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-5">
        <AuthField
          id="name"
          name="name"
          type="text"
          label="Name"
          icon={<UserIcon />}
          placeholder="Enter your name..."
          readOnly={isPending}
          required
        />
        <AuthField
          id="email"
          name="email"
          type="email"
          label="Email"
          icon={<MailIcon />}
          placeholder="Enter your email..."
          readOnly={isPending}
          required
        />
        <AuthField
          id="password"
          name="password"
          type="password"
          label="Password"
          icon={<LockIcon />}
          placeholder="Create a password..."
          readOnly={isPending}
          required
        />
        <AuthField
          id="confirm_password"
          name="confirm_password"
          type="password"
          label="Confirm password"
          icon={<LockIcon />}
          placeholder="Re-enter your password..."
          readOnly={isPending}
          required
        />
        <Button type="submit" className="mt-1 h-10 w-full" disabled={isPending}>
          {isPending && <LoaderCircleIcon className="animate-spin" />}
          {isPending ? "Creating account..." : "Create account"}
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
          icon={<SiGoogle className="size-4" />}
        />
        <SignInSocialButton
          provider="github"
          callbackURL={redirectUrl}
          disabled={isPending}
          icon={<SiGithub className="size-4" />}
        />
      </div>
    </div>
  );
}
