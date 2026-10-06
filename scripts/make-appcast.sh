#!/bin/bash
# Generates the update feed (appcast.json) the in-app updater reads.
# Usage: ./scripts/make-appcast.sh <version> <dmg-url> [notes]
set -euo pipefail

VERSION="${1:?usage: make-appcast.sh <version> <dmg-url> [notes]}"
DMG_URL="${2:?usage: make-appcast.sh <version> <dmg-url> [notes]}"
NOTES="${3:-eWiz $VERSION}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$REPO_DIR/dist"
OUT="$REPO_DIR/dist/appcast.json"

# Escape double quotes/newlines in notes for JSON.
ESCAPED_NOTES=$(printf '%s' "$NOTES" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# The DMG's digest and the release key's signature over it, when the release was signed
# (UPDATE_SHA256 / UPDATE_SIGNATURE). They let an ad-hoc build install the update itself.
SIGNED=""
if [[ -n "${UPDATE_SHA256:-}" && -n "${UPDATE_SIGNATURE:-}" ]]; then
  SIGNED=$(printf ',\n  "sha256": "%s",\n  "signature": "%s"' "$UPDATE_SHA256" "$UPDATE_SIGNATURE")
fi
cat > "$OUT" <<EOF
{
  "version": "$VERSION",
  "url": "$DMG_URL",
  "notes": $ESCAPED_NOTES$SIGNED
}
EOF

echo "wrote $OUT:"
cat "$OUT"
