import { a11yDevtoolsPlugin } from "@tanstack/devtools-a11y/react";
import { TanStackDevtools } from "@tanstack/react-devtools";
import type { QueryClient } from "@tanstack/react-query";
import { ReactQueryDevtoolsPanel } from "@tanstack/react-query-devtools";
import { createRootRouteWithContext, HeadContent, Scripts } from "@tanstack/react-router";
import { TanStackRouterDevtoolsPanel } from "@tanstack/react-router-devtools";

import { Analytics } from "#/components/analytics/posthog";
import { ICON_VERSION } from "#/components/logo";
import { ThemeProvider } from "#/components/theme-provider";
import { Toaster } from "#/components/ui/sonner";
import type { AuthQueryResult } from "#/lib/auth/queries";
import { seo } from "#/lib/seo";

import appCss from "#/styles.css?url";

interface MyRouterContext {
  queryClient: QueryClient;
  user: AuthQueryResult;
}

export const Route = createRootRouteWithContext<MyRouterContext>()({
  // Typically we don't need the user immediately in landing pages.
  // For protected routes with loader data, see /_auth/route.tsx
  // beforeLoad: ({ context }) => {
  //   context.queryClient.prefetchQuery(authQueryOptions());
  // },
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { name: "theme-color", content: "#f7f7f7", media: "(prefers-color-scheme: light)" },
      { name: "theme-color", content: "#161616", media: "(prefers-color-scheme: dark)" },
      // Site-wide defaults. Each route overrides title/description/canonical
      // and adds its own og:url via the seo() helper.
      ...seo().meta,
    ],
    links: [
      // Scalable SVG for modern browsers, PNG fallbacks, and the Apple
      // touch icon for home-screen bookmarks. All derived from the eWiz mark.
      { rel: "icon", href: `/favicon.svg?v=${ICON_VERSION}`, type: "image/svg+xml" },
      { rel: "icon", href: `/favicon-32.png?v=${ICON_VERSION}`, type: "image/png", sizes: "32x32" },
      { rel: "icon", href: `/icon-192.png?v=${ICON_VERSION}`, type: "image/png", sizes: "192x192" },
      {
        rel: "apple-touch-icon",
        href: `/apple-touch-icon.png?v=${ICON_VERSION}`,
        sizes: "180x180",
      },
      { rel: "manifest", href: "/site.webmanifest" },
      { rel: "stylesheet", href: appCss },
    ],
  }),
  shellComponent: RootDocument,
});

function RootDocument({ children }: { readonly children: React.ReactNode }) {
  return (
    // suppress since we're updating the "dark" class in ThemeProvider
    <html lang="en" suppressHydrationWarning>
      <head>
        <HeadContent />
      </head>
      <body>
        <ThemeProvider defaultTheme="system">
          <Analytics>{children}</Analytics>
          <Toaster richColors />
        </ThemeProvider>

        <TanStackDevtools
          plugins={[
            {
              name: "TanStack Query",
              render: <ReactQueryDevtoolsPanel />,
            },
            {
              name: "TanStack Router",
              render: <TanStackRouterDevtoolsPanel />,
            },
            a11yDevtoolsPlugin(),
          ]}
        />

        <Scripts />
      </body>
    </html>
  );
}
