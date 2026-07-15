import { env } from "#/env/client";

/**
 * Single source of truth for site-wide SEO. Everything that needs an absolute
 * URL (canonical, Open Graph, Twitter, sitemap, JSON-LD) is built from
 * VITE_BASE_URL, so it stays correct in local dev (localhost:3000) and in
 * production without hardcoding a domain.
 */
export const SITE = {
  name: "Battlify",
  /** Used as the default and as the " | Battlify" suffix on inner pages. */
  titleDefault: "Battlify: Menu bar battery care for your Mac",
  description:
    "Battlify is a native menu bar app for Apple Silicon Macs. Set a charge limit that holds, pause charging when the battery runs warm, and keep your limit even while the Mac sleeps.",
  locale: "en_US",
  twitter: "@broisnischal",
  /** 1200x630 share image lives in /public. */
  ogImage: "/og.png",
} as const;

/** Trim a trailing slash so we never emit a double slash when joining paths. */
function baseUrl(): string {
  return env.VITE_BASE_URL.replace(/\/$/, "");
}

/** Turn a root-relative path ("/blog") into an absolute URL for this env. */
export function absoluteUrl(path = "/"): string {
  const clean = path.startsWith("/") ? path : `/${path}`;
  return `${baseUrl()}${clean}`;
}

type MetaTag =
  | { title: string }
  | { name: string; content: string }
  | { property: string; content: string };

type LinkTag = { rel: string; href: string };

export interface SeoOptions {
  /** Page title without the brand suffix. Omit on the home page. */
  title?: string;
  description?: string;
  /** Root-relative path of the page, used for canonical + og:url. */
  path?: string;
  /** Root-relative or absolute image URL. Defaults to the site OG image. */
  image?: string;
  /** Open Graph type. "website" for pages, "article" for blog posts. */
  type?: "website" | "article";
  /** Extra keywords, comma-joined into the keywords meta. */
  keywords?: string[];
}

/**
 * Build the meta + link tags for a route's `head()`. Spread the result:
 *
 *   head: () => ({ ...seo({ title: "Blog", path: "/blog" }) })
 */
export function seo(options: SeoOptions = {}): { meta: MetaTag[]; links: LinkTag[] } {
  const { title, description = SITE.description, path = "/", type = "website", keywords } = options;

  const fullTitle = title ? `${title} | ${SITE.name}` : SITE.titleDefault;
  const url = absoluteUrl(path);
  const image = options.image
    ? options.image.startsWith("http")
      ? options.image
      : absoluteUrl(options.image)
    : absoluteUrl(SITE.ogImage);

  const meta: MetaTag[] = [
    { title: fullTitle },
    { name: "description", content: description },

    { property: "og:type", content: type },
    { property: "og:site_name", content: SITE.name },
    { property: "og:title", content: fullTitle },
    { property: "og:description", content: description },
    { property: "og:url", content: url },
    { property: "og:image", content: image },
    { property: "og:image:width", content: "1200" },
    { property: "og:image:height", content: "630" },
    { property: "og:locale", content: SITE.locale },

    { name: "twitter:card", content: "summary_large_image" },
    { name: "twitter:site", content: SITE.twitter },
    { name: "twitter:creator", content: SITE.twitter },
    { name: "twitter:url", content: url },
    { name: "twitter:title", content: fullTitle },
    { name: "twitter:description", content: description },
    { name: "twitter:image", content: image },
  ];

  if (keywords?.length) {
    meta.push({ name: "keywords", content: keywords.join(", ") });
  }

  return { meta, links: [{ rel: "canonical", href: url }] };
}
