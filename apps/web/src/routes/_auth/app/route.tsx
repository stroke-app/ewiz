import { createFileRoute, Link, Outlet } from "@tanstack/react-router";

import { Logo } from "#/components/logo";
import { SignOutButton } from "#/components/sign-out-button";

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
        <SignOutButton />
      </header>

      <main className="mt-12 w-full max-w-xl">
        <Outlet />
      </main>
    </div>
  );
}
