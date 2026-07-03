import { createFileRoute, Link, Outlet } from "@tanstack/react-router";

import { Logo } from "#/components/logo";
import { SignOutButton } from "#/components/sign-out-button";
import { ThemeToggle } from "#/components/theme-toggle";

export const Route = createFileRoute("/_auth/app")({
  component: AppLayout,
});

function AppLayout() {
  return (
    <div className="flex min-h-svh flex-col items-center px-4 py-10">
      <header className="flex w-full max-w-xl items-center justify-between">
        <Link to="/" aria-label="Battlify home">
          <Logo />
        </Link>
        <div className="flex items-center gap-1.5">
          <ThemeToggle />
          <SignOutButton />
        </div>
      </header>

      <main className="mt-12 w-full max-w-xl">
        <Outlet />
      </main>
    </div>
  );
}
