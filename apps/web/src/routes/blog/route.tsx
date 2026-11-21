import { createFileRoute, Outlet } from "@tanstack/react-router";

import { Container, SitePage } from "#/components/site/site-shell";

export const Route = createFileRoute("/blog")({
  component: BlogLayout,
});

function BlogLayout() {
  return (
    <SitePage>
      <Container className="pt-6">
        <Outlet />
      </Container>
    </SitePage>
  );
}
