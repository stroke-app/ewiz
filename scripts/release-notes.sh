#!/bin/bash
# Prints one version's release notes: its section of CHANGELOG.md without the
# changesets bookkeeping (the "### Patch Changes" headings and the commit-hash
# prefix on each entry). The GitHub release carries this text, and ewiz.app's
# changelog page reads it from there.
# Usage: ./scripts/release-notes.sh <version>
set -euo pipefail

VERSION="${1:?usage: release-notes.sh <version>}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

awk -v v="$VERSION" '
  /^## / { if (inside) exit; inside = ($2 == v); next }
  !inside || /^### (Major|Minor|Patch) Changes$/ { next }
  {
    # "- 5dadc82: text" -> "- text"
    if (match($0, /^- [0-9a-f]+: /) && RLENGTH >= 11) $0 = "- " substr($0, RLENGTH + 1)
    # Drop leading and trailing blank lines, and squeeze runs of them into one.
    if ($0 ~ /^[ \t]*$/) { if (printed) blank = 1; next }
    if (blank) { print ""; blank = 0 }
    print
    printed = 1
  }
' "$REPO_DIR/CHANGELOG.md" |
# Unwrap hard-wrapped paragraphs: GitHub renders every newline in a release
# body as a line break. List items, headings, quotes and code stay as they are.
awk '
  function flush() { if (have) print buf; have = 0 }
  {
    s = $0; sub(/^[ \t]+/, "", s)
    if (s ~ /^```/) { flush(); print; fence = !fence; next }
    if (fence) { print; next }
    if (s == "") { flush(); print; next }
    if (have && buf !~ /^[ \t]*#/ && s !~ /^([-*+] |[0-9]+\. |#|>|\|)/) { buf = buf " " s; next }
    flush(); buf = $0; have = 1
  }
  END { flush() }
'
