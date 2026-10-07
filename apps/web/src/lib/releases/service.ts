import { env } from "#/env/server";

/**
 * eWiz releases, read from GitHub instead of being copied into the site. Each
 * release's notes are its CHANGELOG.md section (the app's release workflow
 * writes them), so a new release shows up here without a site edit.
 */
const RELEASES_API = "https://api.github.com/repos/stroke-app/ewiz/releases?per_page=100";

/** How long a fetched list is served before GitHub is asked again. */
const FRESH_MS = 10 * 60 * 1000;
/** Synthetic Cache API key; never requested over the network. Bump it when
 * the cached shape or notes processing changes, to drop the old lists. */
const CACHE_KEY = "https://ewiz.app/__cache/github-releases/3";

export interface Release {
  version: string;
  /** ISO timestamp the release was published. */
  publishedAt: string;
  title: string;
  /** Notes as written (markdown). */
  notes: string;
  /** Notes rendered and sanitized by GitHub. */
  notesHtml: string;
  /** The release page on GitHub. */
  url: string;
  /** The DMG download, if the release has one. */
  dmg: string | null;
}

interface GitHubRelease {
  tag_name: string;
  name: string | null;
  draft: boolean;
  prerelease: boolean;
  published_at: string | null;
  html_url: string;
  body: string | null;
  body_html?: string;
  assets: { name: string; browser_download_url: string }[];
}

/** "eWiz 0.18.2 — AI Agents" → "AI Agents". A bare "eWiz 0.18.3" has none. */
function titleFromName(name: string) {
  return name.replace(/^\S+\s+v?\d+(?:\.\d+)*\s*(?:[—–:-]\s*)?/, "").trim();
}

/** The notes' first heading; else its first point's bold lead-in or first sentence. */
function titleFromNotes(markdown: string) {
  const heading = /^### (.+)$/m.exec(markdown)?.[1];
  if (heading) return plainTitle(heading);
  const lines = markdown.split("\n");
  const start = lines.findIndex((l) => l.trim() && !l.startsWith("#"));
  if (start < 0) return "";
  let text = lines[start].replace(/^\s*[-*]\s+/, "");
  for (const l of lines.slice(start + 1)) {
    if (!l.trim() || /^\s*[-*#]/.test(l)) break;
    text += ` ${l.trim()}`;
  }
  const bold = /^\*\*(.+?)\*\*/.exec(text);
  return plainTitle(bold ? bold[1] : (/^(.+?[.!?])(?:\s|$)/.exec(text)?.[1] ?? text));
}

function plainTitle(markdown: string) {
  const plain = markdown
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/[*_`]/g, "")
    .replace(/[\s.:—–-]+$/, "");
  return plain.length > 90 ? `${plain.slice(0, plain.lastIndexOf(" ", 88))}…` : plain;
}

const ENTITIES: Record<string, string> = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&quot;": '"',
  "&#39;": "'",
};

/**
 * When the notes open with a heading that says the title, or the title and
 * more ("AI Agents" → "AI Agents, in Settings"), that heading becomes the
 * title, so it isn't shown twice.
 */
function promoteHeading(html: string, title: string) {
  const first = /^\s*<h3>(.*?)<\/h3>\s*/.exec(html);
  if (!first) return { title, notesHtml: html };
  const heading = first[1]
    .replace(/<[^>]+>/g, "")
    .replace(/&(?:amp|lt|gt|quot|#39);/g, (e) => ENTITIES[e]);
  return heading.toLowerCase().startsWith(title.toLowerCase())
    ? { title: heading, notesHtml: html.slice(first[0].length) }
    : { title, notesHtml: html };
}

function toRelease(r: GitHubRelease): Release {
  const notes = (r.body ?? "").trim();
  const { title, notesHtml } = promoteHeading(
    r.body_html ?? "",
    titleFromName(r.name ?? "") || titleFromNotes(notes),
  );
  return {
    version: r.tag_name.replace(/^v/, ""),
    publishedAt: r.published_at ?? "",
    title,
    notes,
    notesHtml,
    url: r.html_url,
    dmg: r.assets.find((a) => a.name.endsWith(".dmg"))?.browser_download_url ?? null,
  };
}

async function fetchReleases(): Promise<Release[]> {
  const res = await fetch(RELEASES_API, {
    headers: {
      // `full` returns the markdown body plus GitHub's sanitized HTML of it.
      accept: "application/vnd.github.full+json",
      "user-agent": "ewiz.app",
      "x-github-api-version": "2022-11-28",
      ...(env.GITHUB_RELEASES_TOKEN
        ? { authorization: `Bearer ${env.GITHUB_RELEASES_TOKEN}` }
        : {}),
    },
  });
  if (!res.ok) throw new Error(`GitHub releases: ${res.status} ${await res.text()}`);
  const list = (await res.json()) as GitHubRelease[];
  return list
    .filter((r) => !r.draft && !r.prerelease && r.published_at)
    .map(toRelease)
    .sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));
}

/**
 * Published releases, newest first. Cached at the edge for FRESH_MS; when
 * GitHub can't be reached the last good list is served instead.
 */
export async function getReleases(): Promise<Release[]> {
  const cache = typeof caches === "undefined" ? undefined : await caches.open("github-releases");
  const hit = await cache?.match(CACHE_KEY);
  if (hit && Date.now() - Number(hit.headers.get("x-fetched-at")) < FRESH_MS) {
    return hit.json();
  }
  try {
    const releases = await fetchReleases();
    await cache?.put(
      CACHE_KEY,
      new Response(JSON.stringify(releases), {
        headers: {
          "content-type": "application/json",
          // Kept a week so a GitHub outage serves the last list, not nothing.
          "cache-control": "max-age=604800",
          "x-fetched-at": String(Date.now()),
        },
      }),
    );
    return releases;
  } catch (err) {
    if (hit) return hit.json();
    throw err;
  }
}

/** "Oct 6, 2026", fixed to UTC so server and client render the same day. */
export function formatReleaseDate(iso: string) {
  return new Date(iso).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}
