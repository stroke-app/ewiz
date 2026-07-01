import { createFileRoute, Link, Outlet } from "@tanstack/react-router";

import { SignOutButton } from "#/components/sign-out-button";
import { ThemeToggle } from "#/components/theme-toggle";
import { Button } from "#/components/ui/button";

export const Route = createFileRoute("/_auth/app")({
  component: AppLayout,
});

function AppLayout() {
  return (
    <div className="flex min-h-svh flex-col items-center px-4 py-10">
      <header className="flex w-full max-w-xl items-center justify-between">
        <Button render={<Link to="/" />} size="sm" variant="ghost" nativeButton={false}>
          ← Battlify
        </Button>
        <div className="flex items-center gap-1">
          <ThemeToggle />
          <SignOutButton />
        </div>
      </header>

      <main className="mt-10 w-full max-w-xl">
        <Outlet />
      </main>
    </div>
  );
}
