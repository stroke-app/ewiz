import { BREW_INSTALL, FAQS, LATEST, LINKS, PRICE } from "#/components/landing/landing-data";
import { POSTS } from "#/lib/blog/posts";
import { RELEASES } from "#/lib/changelog";
import { absoluteUrl, SITE } from "#/lib/seo";

const FEATURES = [
  "Charge limit: cap charging anywhere from 50 to 100 percent. It holds with a buffer so the charger isn't toggling all day, and works with both Apple Silicon charging schemes, including macOS 26 Tahoe.",
  "Sleep-safe: stops charging before sleep (or keeps the Mac awake on wall power) so macOS can't creep back to 100 percent overnight.",
  "Heat-aware charging: pauses charging when the battery runs warm and resumes once it cools.",
  "Sealed Sleep: one switch turns off every wake source behind a closed lid, shows each one as sealed, and measures what the last close cost.",
  "Automation rules: 'while this is true, do that', from a dozen conditions such as a connected display or a Wi-Fi network. Rules undo themselves when they stop matching.",
  "Schedules and Ready By: hold overnight, then top up in time; charge on a weekly timetable or turn charge power down.",
  "AI Agents: Claude, Cursor and other MCP apps can keep the Mac awake through a long build, test run or download, on a timer that ends by itself. One-click connect for Claude Desktop and Cursor; a copyable command for Claude Code.",
  "One-tap save modes: Off, Normal and Super Saver flip a bundle of settings at once.",
  "MagSafe LED: orange while charging, green when holding at the limit.",
  "Insight: battery health, cycle count, temperature, capacity, live power flow, adapter details and a history of every charge and lid-closed session (CSV export).",
];

const header = () => `# ${SITE.name}

> ${SITE.description}

eWiz is a native macOS menu bar app by Nischal Dahal, an independent developer. It runs on Apple Silicon Macs (M1 or newer) with macOS 14 Sonoma or later. It is a one-time ${PRICE} purchase with a free 30-day trial of every feature; there is no subscription.`;

/** llms.txt (https://llmstxt.org): a short, curated map of the site for AI assistants. */
export function llmsTxt() {
  return `${header()}

## Product

- [Home](${absoluteUrl("/")}): what eWiz does, with the real app UI
- [Download](${absoluteUrl("/download")}): latest version ${LATEST.version}, DMG and Homebrew (\`${BREW_INSTALL}\`)
- [Pricing](${absoluteUrl("/#pricing")}): free 30-day trial, then ${PRICE} once
- [Changelog](${absoluteUrl("/changelog")}): every release
- [Full details for LLMs](${absoluteUrl("/llms-full.txt")}): features, FAQ and release notes in one file

## Learn

${POSTS.map((p) => `- [${p.title}](${absoluteUrl(`/blog/${p.slug}`)}): ${p.description}`).join("\n")}

## Optional

- [Source and issues](${LINKS.github})
- [Privacy policy](${absoluteUrl("/legal/privacy")})
- [Terms of service](${absoluteUrl("/legal/terms")})
`;
}

/** llms-full.txt: the same, expanded into self-contained text. */
export function llmsFullTxt() {
  return `${header()}

## Features

${FEATURES.map((f) => `- ${f}`).join("\n")}

## Install

- Download the DMG: ${LATEST.dmg}
- Or with Homebrew: \`${BREW_INSTALL}\`
- Builds are not notarized yet; on first launch, right-click the app and choose Open.

## Pricing

- Free for 30 days with every feature.
- License: ${PRICE} one-time, single Mac, free updates for life. Moving to a new Mac is allowed once every 30 days.
- Checkout is handled by Dodo Payments (merchant of record).

## FAQ

${FAQS.map((f) => `### ${f.q}\n\n${f.a}`).join("\n\n")}

## Recent releases

${RELEASES.slice(0, 6)
  .map(
    (r) =>
      `### ${r.v} (${r.date}): ${r.title}\n\n${r.groups
        .map((g) => g.items.map((i) => `- ${g.heading}: ${i}`).join("\n"))
        .join("\n")}`,
  )
  .join("\n\n")}

## Links

- Website: ${absoluteUrl("/")}
- Source: ${LINKS.github}
- Issues: ${LINKS.feedback}
- Developer: ${LINKS.site}
`;
}
