# Battlify SEO Audit

Snapshot after the SEO pass. URLs are environment-driven via `VITE_BASE_URL`
(localhost in dev, `battlify.discerns.app` in prod), so nothing is hardcoded.

## 1. Title & meta optimization

| Area | Status | Notes |
|---|---|---|
| Titles | ✅ | Central `seo()` helper. Home: brand title; inner pages: `Page \| Battlify`. |
| Descriptions | ✅ | Unique, human, ~150 chars per page. |
| Open Graph | ✅ | `og:type/site_name/title/description/url/image(+w/h)/locale` on every page. |
| Twitter card | ✅ | `summary_large_image` with title/description/image + `@broisnischal`. |
| Canonical | ✅ | One per page from `seo()`; root emits none (avoids duplicates). |
| Keywords | ✅ | Targeted keywords on home + blog posts. |

## 2. Heading structure

- Exactly one `<h1>` per page; `<h2>`/`<h3>` nest correctly in the blog article and legal pages. No skipped levels found.

## 3. Internal linking

- Nav links Pricing, Blog, **Changelog (now internal `/changelog`, was pointing at the external GitHub URL)**, Community.
- Footer links Product/Connect + legal. Blog posts cross-link to home CTA. Breadcrumb JSON-LD on blog.

## 4. Canonicalization

- `/privacy` and `/terms` (the older `.blf` duplicates) now carry `robots: noindex, follow` and `canonical → /legal/privacy` and `/legal/terms`. Only one legal set is indexed. **Action for you: eventually delete one legal set to remove the duplication entirely.**

## 5. Image alt text

- No `<img>` tags on the marketing site (all icons/mockups are inline SVG), so no alt gaps. Decorative SVGs carry `aria-hidden`.
- Social share image added: `public/og.png` (1200×630).

## 6. Page speed signals

- SSR on Cloudflare Workers, hashed assets with 1-year immutable cache (`_headers`).
- Fonts and CSS inlined via the app bundle. No render-blocking third-party scripts (PostHog loads client-side, no-ops without a key).
- LCP element is text/SVG hero (no large image). CLS low (fixed layouts). Recommend a Lighthouse run post-deploy to confirm INP.

## 7. Structured data (JSON-LD)

| Schema | Where | Rich result |
|---|---|---|
| Organization | Home | Brand/knowledge panel |
| WebSite | Home | Site name |
| SoftwareApplication | Home | App result (price $2.99, macOS 14+, download) |
| FAQPage | Home (visible FAQ section) | FAQ rich result |
| Article | Blog post | Article result |
| BreadcrumbList | Blog index + post | Breadcrumb trail |

- All validated structurally against schema.org types; entities linked by `@id`. Validate live post-deploy with Google Rich Results Test.
- **Missing/optional to consider:** `aggregateRating` on SoftwareApplication (needs real review data), `VideoObject` if a demo video is added.

## 8. Content quality

- Removed every user-facing em dash (the "AI tell") across blog, landing, legal, changelog, and the app dashboard; replaced with natural punctuation. Voice preserved.
- Blog article is deep, interactive, and cites primary sources (Battery University). Search intent for "macbook charge limit / battery health" is well covered.
- Added a 6-question FAQ answering real pre-purchase questions.
- **Gaps to fill:** thin content on older changelog entries (fine); consider 1–2 more articles ("How Battlify's charge limit works", "macOS 26 Tahoe battery changes") to build topical depth.

## 9. Crawlability

- Dynamic `robots.txt`: allows all public pages, disallows `/app`, `/login`, `/signup`, `/buy`, `/api/`, links the sitemap.
- Dynamic `sitemap.xml`: indexable pages + all blog posts with `lastmod`, `changefreq`, `priority`. Excludes the noindex duplicates.

## Open items for you
1. Delete one legal set (`/legal/*` vs `/privacy`+`/terms`) to fully remove duplication.
2. Fill the `[JURISDICTION]` placeholder in `/legal/terms`.
3. Replace the placeholder roadmap items in the changelog with real plans.
4. Run Lighthouse + Google Rich Results Test against the deployed domain.
