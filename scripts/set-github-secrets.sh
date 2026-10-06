#!/bin/bash
# Reads .env and uploads each non-empty value as a GitHub Actions secret via gh.
# Empty values are skipped (so you can run it now and again after filling Apple keys).
#   ./scripts/set-github-secrets.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"
REPO="${GH_REPO:-broisnischal/ewiz}"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "error: $ENV_FILE not found. Copy .env.example to .env and fill it." >&2
    exit 1
fi

# Load .env without exporting comments/blank lines.
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

SECRETS=(
    KEYCHAIN_PASSWORD
    DEVELOPER_ID_CERT_P12_BASE64
    DEVELOPER_ID_CERT_PASSWORD
    NOTARY_KEY_ID
    NOTARY_ISSUER_ID
    NOTARY_KEY_P8_BASE64
    RELEASES_TOKEN
)

echo "Setting secrets on $REPO …"
set_count=0
for name in "${SECRETS[@]}"; do
    value="${!name:-}"
    if [[ -z "$value" ]]; then
        echo "  - $name: empty, skipped"
        continue
    fi
    gh secret set "$name" --repo "$REPO" --body "$value"
    echo "  ✓ $name set"
    set_count=$((set_count + 1))
done

echo "Done. $set_count secret(s) set."
[[ $set_count -lt ${#SECRETS[@]} ]] && \
    echo "Fill the remaining Apple values in .env and re-run to enable signed releases."
exit 0
