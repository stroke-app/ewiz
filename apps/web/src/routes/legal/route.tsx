import { createFileRoute, Outlet } from "@tanstack/react-router";

import { Container, SitePage } from "#/components/site/site-shell";

export const Route = createFileRoute("/legal")({
  component: LegalRoute,
});

function LegalRoute() {
  return (
    <SitePage>
      <Container className="pt-6">
        <Outlet />
      </Container>
    </SitePage>
  );
}
