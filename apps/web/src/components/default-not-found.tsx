import { Link } from "@tanstack/react-router";

import { Container, SitePage } from "#/components/site/site-shell";
import { Button } from "#/components/ui/button";

export function DefaultNotFound() {
  return (
    <SitePage>
      <Container className="pt-16 text-center">
        <p className="text-sm font-medium text-primary uppercase">404</p>
        <h1 className="mt-1 text-3xl font-semibold tracking-tight">This page doesn&apos;t exist</h1>
        <p className="mt-2 text-lg text-muted-foreground">
          It may have moved, or the link is wrong.
        </p>
        <div className="mt-8 flex justify-center gap-2">
          <Button type="button" variant="outline" onClick={() => window.history.back()}>
            Go back
          </Button>
          <Button render={<Link to="/" />} nativeButton={false}>
            Home
          </Button>
        </div>
      </Container>
    </SitePage>
  );
}
