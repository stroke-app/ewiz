import { absoluteUrl, SITE } from "#/lib/seo";

/**
 * Renders a JSON-LD structured-data block. Crawlers read application/ld+json
 * from anywhere in the document, so we render it inline in the route body.
 * Content is serialized and injected as raw text (JSON-LD is not HTML).
 */
export function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      // eslint-disable-next-line react/no-danger
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}

/** The publisher/brand. Referenced by other schemas via @id. */
export function organizationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "Organization",
    "@id": `${absoluteUrl("/")}#organization`,
    name: SITE.name,
    alternateName: ["Battlify app", "Battlify for Mac"],
    url: absoluteUrl("/"),
    logo: absoluteUrl("/og.png"),
    sameAs: ["https://github.com/broisnischal/battlify", "https://x.com/broisnischal"],
  };
}

/** The site itself, so search engines can show a sitelinks/name box. */
export function websiteSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "WebSite",
    "@id": `${absoluteUrl("/")}#website`,
    name: SITE.name,
    alternateName: "Battlify app",
    url: absoluteUrl("/"),
    description: SITE.description,
    publisher: { "@id": `${absoluteUrl("/")}#organization` },
    inLanguage: "en",
  };
}

/** The product. Powers the app rich result (price, platform, rating). */
export function softwareApplicationSchema() {
  return {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: SITE.name,
    alternateName: ["Battlify app", "Battlify for Mac", "Download Battlify"],
    applicationCategory: "UtilitiesApplication",
    operatingSystem: "macOS 14+",
    description: SITE.description,
    url: absoluteUrl("/"),
    image: absoluteUrl("/og.png"),
    downloadUrl: "https://github.com/broisnischal/battlify/releases",
    softwareVersion: "0.10.1",
    offers: {
      "@type": "Offer",
      price: "2.99",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
    },
    publisher: { "@id": `${absoluteUrl("/")}#organization` },
  };
}

export interface ArticleSchemaInput {
  title: string;
  description: string;
  slug: string;
  /** ISO publish date. */
  datePublished: string;
  /** ISO modified date; falls back to datePublished. */
  dateModified?: string;
}

/** A blog article, for the Article rich result. */
export function articleSchema(post: ArticleSchemaInput) {
  const url = absoluteUrl(`/blog/${post.slug}`);
  return {
    "@context": "https://schema.org",
    "@type": "Article",
    "@id": `${url}#article`,
    headline: post.title,
    description: post.description,
    image: absoluteUrl("/og.png"),
    datePublished: post.datePublished,
    dateModified: post.dateModified ?? post.datePublished,
    author: {
      "@type": "Person",
      name: "Nischal Dahal",
      url: "https://github.com/broisnischal",
    },
    publisher: { "@id": `${absoluteUrl("/")}#organization` },
    mainEntityOfPage: { "@type": "WebPage", "@id": url },
    inLanguage: "en",
  };
}

/** A breadcrumb trail, for the breadcrumb rich result. */
export function breadcrumbSchema(crumbs: Array<{ name: string; path: string }>) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: crumbs.map((c, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: c.name,
      item: absoluteUrl(c.path),
    })),
  };
}

/**
 * Hints the primary navigation to search engines. Does not force sitelinks
 * (those are automatic), but names the pages Google is most likely to surface
 * under the main result and gives it their preferred labels.
 */
export function siteNavigationSchema() {
  const items = [
    { name: "Blog", path: "/blog" },
    { name: "Changelog", path: "/changelog" },
    { name: "Privacy Policy", path: "/legal/privacy" },
    { name: "Terms of Service", path: "/legal/terms" },
  ];
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "@id": `${absoluteUrl("/")}#nav`,
    itemListElement: items.map((it, i) => ({
      "@type": "SiteNavigationElement",
      position: i + 1,
      name: it.name,
      url: absoluteUrl(it.path),
    })),
  };
}

export interface FaqItem {
  question: string;
  answer: string;
}

/** A FAQ list, for the FAQ rich result. */
export function faqSchema(items: FaqItem[]) {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: items.map((it) => ({
      "@type": "Question",
      name: it.question,
      acceptedAnswer: { "@type": "Answer", text: it.answer },
    })),
  };
}
