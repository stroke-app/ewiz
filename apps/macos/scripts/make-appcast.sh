#!/bin/bash
# Generates both update feeds for a release:
#   dist/appcast.xml   the Sparkle appcast the app reads (SUFeedURL)
#   dist/appcast.json  the feed copies up to 0.18.5 read with the app's old updater; they
#                      can only reach a Sparkle build through it, so it keeps being published
#
# Usage: ./scripts/make-appcast.sh <version> <dmg-url> [notes]
#   notes: the release notes, Markdown or plain text (the CHANGELOG section, via
#          scripts/release-notes.sh). Default "eWiz <version>".
#
# Environment, from `licensetool sign-update` (all optional; the feeds carry what's set):
#   UPDATE_SHA256        the DMG's digest                  → appcast.json "sha256"
#   UPDATE_SIGNATURE     signature over the digest's hex   → appcast.json "signature"
#   UPDATE_ED_SIGNATURE  Sparkle's signature over the bytes → appcast.xml sparkle:edSignature
#   UPDATE_LENGTH        the DMG's size in bytes           → appcast.xml length
#                        (read from dist/eWiz-<version>.dmg when unset and present)
set -euo pipefail

VERSION="${1:?usage: make-appcast.sh <version> <dmg-url> [notes]}"
DMG_URL="${2:?usage: make-appcast.sh <version> <dmg-url> [notes]}"
NOTES="${3:-eWiz $VERSION}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_DIR/dist"
mkdir -p "$DIST"
BUILD_NUMBER="$("$REPO_DIR/scripts/build-number.sh" "$VERSION")"

LENGTH="${UPDATE_LENGTH:-}"
if [[ -z "$LENGTH" && -f "$DIST/eWiz-$VERSION.dmg" ]]; then
    LENGTH=$(stat -f %z "$DIST/eWiz-$VERSION.dmg")
fi

if [[ -z "${UPDATE_ED_SIGNATURE:-}" ]]; then
    echo "warning: UPDATE_ED_SIGNATURE is unset — the app will refuse this appcast.xml (SUPublicEDKey demands a signature)" >&2
fi

# ---- appcast.json (legacy) -------------------------------------------------------------

ESCAPED_NOTES=$(printf '%s' "$NOTES" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
SIGNED=""
if [[ -n "${UPDATE_SHA256:-}" && -n "${UPDATE_SIGNATURE:-}" ]]; then
    SIGNED=$(printf ',\n  "sha256": "%s",\n  "signature": "%s"' "$UPDATE_SHA256" "$UPDATE_SIGNATURE")
fi
cat > "$DIST/appcast.json" <<EOF
{
  "version": "$VERSION",
  "url": "$DMG_URL",
  "notes": $ESCAPED_NOTES$SIGNED
}
EOF

# ---- appcast.xml (Sparkle) -------------------------------------------------------------

# Python does the escaping: the notes go into an HTML <description>, everything else is
# an XML attribute or text node, and quoting all of that in shell is how feeds break.
VERSION="$VERSION" DMG_URL="$DMG_URL" NOTES="$NOTES" BUILD_NUMBER="$BUILD_NUMBER" \
LENGTH="$LENGTH" ED_SIGNATURE="${UPDATE_ED_SIGNATURE:-}" OUT="$DIST/appcast.xml" \
python3 - <<'PY'
import os, re
from email.utils import formatdate
from html import escape

def notes_html(text):
    """The CHANGELOG section as simple HTML: headings, bullet lists and paragraphs.
    Sparkle renders <description> as HTML, so plain newlines would run together."""
    out, items, para = [], [], []
    def flush_items():
        if items:
            out.append("<ul>" + "".join(f"<li>{i}</li>" for i in items) + "</ul>"); items.clear()
    def flush_para():
        if para:
            out.append("<p>" + " ".join(para) + "</p>"); para.clear()
    def inline(s):
        s = escape(s, quote=False)
        s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", s)
        return s
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            flush_items(); flush_para(); continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            flush_items(); flush_para()
            level = min(len(m.group(1)) + 1, 6)   # "## 0.19.0" → h3, below the item title
            out.append(f"<h{level}>{inline(m.group(2))}</h{level}>"); continue
        m = re.match(r"^[-*+]\s+(.*)$", line)
        if m:
            flush_para(); items.append(inline(m.group(1))); continue
        if items and raw.startswith((" ", "\t")):
            items[-1] += " " + inline(line); continue   # a wrapped bullet
        flush_items(); para.append(inline(line))
    flush_items(); flush_para()
    return "\n".join(out)

e = os.environ
version, build, url = e["VERSION"], e["BUILD_NUMBER"], e["DMG_URL"]
length = f' length="{escape(e["LENGTH"])}"' if e["LENGTH"] else ""
ed = f' sparkle:edSignature="{escape(e["ED_SIGNATURE"])}"' if e["ED_SIGNATURE"] else ""
notes = notes_html(e["NOTES"]).replace("]]>", "]]]]><![CDATA[>")

xml = f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>eWiz</title>
    <link>https://ewiz.app</link>
    <description>eWiz updates</description>
    <language>en</language>
    <item>
      <title>eWiz {escape(version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
{notes}
      ]]></description>
      <enclosure url="{escape(url)}"{length} type="application/octet-stream"{ed}/>
    </item>
  </channel>
</rss>
'''
with open(e["OUT"], "w", encoding="utf-8") as f:
    f.write(xml)
PY

echo "wrote $DIST/appcast.json:"
cat "$DIST/appcast.json"
echo "wrote $DIST/appcast.xml:"
cat "$DIST/appcast.xml"
