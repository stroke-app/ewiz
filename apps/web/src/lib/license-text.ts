// The repository's LICENSE file, so /legal/license can never drift from it.
import raw from "../../../LICENSE?raw";

export interface LicenseItem {
  text: string;
  children: string[];
}

export type LicenseBlock =
  | { kind: "heading"; text: string }
  | { kind: "rule" }
  | { kind: "paragraph"; text: string }
  | { kind: "list"; ordered: boolean; items: LicenseItem[] };

/**
 * Reads the LICENSE's plain-text layout: blank-line separated blocks, "#"
 * headings, a "---" rule, and "-" / "1." items, where an indented item belongs
 * to the item before it. Hard-wrapped lines are joined back into one.
 */
function parse(text: string): LicenseBlock[] {
  const blocks: LicenseBlock[] = [];
  for (const chunk of text.trim().split(/\n\s*\n/)) {
    const first = chunk.split("\n")[0];
    const joined = chunk
      .split("\n")
      .map((l) => l.trim())
      .join(" ");
    if (/^#+ /.test(first)) {
      blocks.push({ kind: "heading", text: joined.replace(/^#+ /, "") });
      continue;
    }
    if (/^-{3,}$/.test(first.trim())) {
      blocks.push({ kind: "rule" });
      continue;
    }
    const item = /^(\s*)(-|\d+\.) /.exec(first);
    if (!item) {
      blocks.push({ kind: "paragraph", text: joined });
      continue;
    }
    const body = joined.replace(/^(-|\d+\.) /, "");
    const ordered = item[2] !== "-";
    const last = blocks.at(-1);
    if (last?.kind === "list" && item[1]) {
      last.items.at(-1)?.children.push(body);
    } else if (last?.kind === "list" && last.ordered === ordered) {
      last.items.push({ text: body, children: [] });
    } else {
      blocks.push({ kind: "list", ordered, items: [{ text: body, children: [] }] });
    }
  }
  return blocks;
}

export const LICENSE_BLOCKS = parse(raw);
