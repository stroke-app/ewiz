import { createServerFn } from "@tanstack/react-start";

import { formatReleaseDate, getReleases } from "./service";

export interface ReleaseDTO {
  version: string;
  /** "Oct 6, 2026" */
  date: string;
  title: string;
  notesHtml: string;
  url: string;
}

export interface LatestReleaseDTO {
  version: string;
  dmg: string;
}

/** Every release for the changelog, or [] when GitHub can't be reached. */
export const $getReleases = createServerFn({ method: "GET" }).handler(
  async (): Promise<ReleaseDTO[]> => {
    try {
      const releases = await getReleases();
      return releases.map((r) => ({
        version: r.version,
        date: formatReleaseDate(r.publishedAt),
        title: r.title,
        notesHtml: r.notesHtml,
        url: r.url,
      }));
    } catch (err) {
      console.error("releases: could not load from GitHub", err);
      return [];
    }
  },
);

/** The newest release with a DMG, or null when GitHub can't be reached. */
export const $getLatestRelease = createServerFn({ method: "GET" }).handler(
  async (): Promise<LatestReleaseDTO | null> => {
    try {
      const latest = (await getReleases()).find((r) => r.dmg);
      return latest?.dmg ? { version: latest.version, dmg: latest.dmg } : null;
    } catch (err) {
      console.error("releases: could not load from GitHub", err);
      return null;
    }
  },
);
