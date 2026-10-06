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

cat > "$OUT" <<EOF
{
  "version": "$VERSION",
  "url": "$DMG_URL",
  "notes": $ESCAPED_NOTES
}
EOF

echo "wrote $OUT:"
cat "$OUT"
