#!/bin/bash
# One place for every eWiz secret, so none of them is ever lost.
#
# GitHub Actions secrets and Cloudflare Worker secrets can be written but never read
# back. The only readable copies are two gitignored files:
#
#   apps/web/.env     the website (Better Auth, Google/Apple, Dodo, license signing, PostHog)
#   apps/macos/.env   the release pipeline (update signing key, code-signing identity, tokens)
#
# This script keeps an encrypted backup of both in iCloud Drive and is the way to
# change a secret: edit the .env file, then `push`, which uploads it AND re-backs up.
#
#   ./scripts/secrets.sh backup              encrypt both files → iCloud Drive/eWiz Secrets/
#   ./scripts/secrets.sh restore [file]      decrypt the latest (or given) backup into place
#   ./scripts/secrets.sh push web|release    upload to Cloudflare / GitHub, then back up
#   ./scripts/secrets.sh check               secrets set remotely but missing locally
#
# The backup is AES-256 (gpg, symmetric). Its passphrase is read from the login Keychain
# item "eWiz secrets backup passphrase", or EWIZ_BACKUP_PASSPHRASE_FILE, or asked for.
# Keep your own copy of that passphrase in a password manager: the Keychain item lives
# only on this Mac.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_ENV="$ROOT/apps/web/.env"
MAC_ENV="$ROOT/apps/macos/.env"
BACKUP_DIR="${EWIZ_BACKUP_DIR:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/eWiz Secrets}"
GH_REPO="${GH_REPO:-stroke-app/ewiz}"
KEYCHAIN_ITEM="eWiz secrets backup passphrase"

# Website keys that live as Worker secrets (VITE_* are public and built into the bundle;
# DODO_PAYMENTS_ENVIRONMENT is a [vars] entry in wrangler.toml).
WEB_SECRETS=(BETTER_AUTH_SECRET GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET
    APPLE_CLIENT_ID APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY APPLE_APP_BUNDLE_IDENTIFIER
    DODO_PAYMENTS_API_KEY DODO_PAYMENTS_WEBHOOK_SECRET DODO_BATTLIFY_PRODUCT_ID
    LICENSE_SIGNING_PRIVATE_KEY GITHUB_RELEASES_TOKEN)
RELEASE_SECRETS=(UPDATE_SIGNING_PRIVATE_KEY SELF_SIGNED_CERT_P12_BASE64 SELF_SIGNED_CERT_PASSWORD
    KEYCHAIN_PASSWORD RELEASES_TOKEN
    DEVELOPER_ID_CERT_P12_BASE64 DEVELOPER_ID_CERT_PASSWORD
    NOTARY_KEY_ID NOTARY_ISSUER_ID NOTARY_KEY_P8_BASE64)

# Can be re-created at any time (a new token, a new random value), so a missing local
# copy is a chore, not a loss. Everything else is irreplaceable.
REPLACEABLE=" KEYCHAIN_PASSWORD RELEASES_TOKEN GITHUB_RELEASES_TOKEN "

die() { echo "error: $*" >&2; exit 1; }

flag_missing() {
    if [[ "$REPLACEABLE" == *" $1 "* ]]; then
        echo "  - $1 (replaceable: create a new one when you next need it)"
    else
        echo "  ! $1 (IRREPLACEABLE: put its value in the .env file, then push)"; missing=1
    fi
}

# Writes the passphrase to a private temp file and prints its path (never on a command line).
passphrase_file() {
    local f; f="$(mktemp)"; chmod 600 "$f"
    if [[ -n "${EWIZ_BACKUP_PASSPHRASE_FILE:-}" ]]; then
        cat "$EWIZ_BACKUP_PASSPHRASE_FILE" > "$f"
    elif security find-generic-password -s "$KEYCHAIN_ITEM" -a ewiz -w > "$f" 2>/dev/null; then
        :
    else
        read -r -s -p "Backup passphrase: " pw; echo >&2
        printf '%s' "$pw" > "$f"
    fi
    [[ -s "$f" ]] || die "empty passphrase"
    echo "$f"
}

# Reads KEY's value from an env file without sourcing it (values may hold $ or quotes).
env_value() {
    local file="$1" key="$2" line
    line="$(grep -E "^${key}=" "$file" | tail -1 || true)"
    line="${line#*=}"
    line="${line%\"}"; line="${line#\"}"
    printf '%s' "$line"
}

cmd_backup() (
    [[ -f "$WEB_ENV" || -f "$MAC_ENV" ]] || die "no .env files to back up"
    mkdir -p "$BACKUP_DIR"
    local stage pass stamp out
    stage="$(mktemp -d)"; pass="$(passphrase_file)"
    trap 'rm -rf "$stage" "$pass"' EXIT
    mkdir -p "$stage/apps/web" "$stage/apps/macos"
    [[ -f "$WEB_ENV" ]] && cp "$WEB_ENV" "$stage/apps/web/.env"
    [[ -f "$MAC_ENV" ]] && cp "$MAC_ENV" "$stage/apps/macos/.env"
    {
        echo "eWiz secrets backup, $(date -u +%Y-%m-%dT%H:%M:%SZ), from $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo '?')"
        echo "Restore: ./scripts/secrets.sh restore <this file>"
        echo
        for f in apps/web/.env apps/macos/.env; do
            [[ -f "$stage/$f" ]] || continue
            echo "$f:"
            grep -E '^[A-Z0-9_]+=.+' "$stage/$f" | cut -d= -f1 | sed 's/^/  /'
        done
    } > "$stage/MANIFEST.txt"
    stamp="$(date +%Y-%m-%d-%H%M%S)"
    out="$BACKUP_DIR/ewiz-secrets-$stamp.tar.gpg"
    tar -C "$stage" -cf - MANIFEST.txt apps \
        | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-file "$pass" \
              --symmetric --cipher-algo AES256 -o "$out"
    # Prove it opens before calling it a backup.
    gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$pass" -d "$out" \
        | tar -tf - | grep -q MANIFEST.txt || die "backup did not verify: $out"
    cp "$out" "$BACKUP_DIR/ewiz-secrets-latest.tar.gpg"
    echo "Backed up and verified → $out"
)

cmd_restore() (
    local in="${1:-$BACKUP_DIR/ewiz-secrets-latest.tar.gpg}" pass stage f
    [[ -f "$in" ]] || die "no backup at $in"
    pass="$(passphrase_file)"; stage="$(mktemp -d)"
    trap 'rm -rf "$stage" "$pass"' EXIT
    gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$pass" -d "$in" | tar -C "$stage" -xf -
    cat "$stage/MANIFEST.txt"; echo
    for f in apps/web/.env apps/macos/.env; do
        [[ -f "$stage/$f" ]] || continue
        if [[ -f "$ROOT/$f" ]] && ! cmp -s "$stage/$f" "$ROOT/$f"; then
            cp "$ROOT/$f" "$ROOT/$f.before-restore"
            echo "kept your current $f as $f.before-restore"
        fi
        install -m 600 "$stage/$f" "$ROOT/$f"
        echo "restored $f"
    done
)

cmd_push() (
    case "${1:-}" in
        web)
            [[ -f "$WEB_ENV" ]] || die "$WEB_ENV not found"
            local json; json="$(mktemp)"; chmod 600 "$json"
            trap 'rm -f "$json"' EXIT
            python3 - "$WEB_ENV" "$json" "${WEB_SECRETS[@]}" <<'PY'
import json, sys
env, out, keys = sys.argv[1], sys.argv[2], sys.argv[3:]
vals = {}
for line in open(env):
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line: continue
    k, v = line.split("=", 1)
    vals[k] = v.strip().strip('"')
json.dump({k: vals[k] for k in keys if vals.get(k)}, open(out, "w"))
print("uploading:", ", ".join(k for k in keys if vals.get(k)))
PY
            (cd "$ROOT/apps/web" && CI=true bunx wrangler secret bulk "$json")
            ;;
        release)
            [[ -f "$MAC_ENV" ]] || die "$MAC_ENV not found"
            local k v
            for k in "${RELEASE_SECRETS[@]}"; do
                v="$(env_value "$MAC_ENV" "$k")"
                [[ -n "$v" ]] || { echo "  - $k: empty locally, left as it is on GitHub"; continue; }
                printf '%s' "$v" | gh secret set "$k" --repo "$GH_REPO"
                echo "  ✓ $k"
            done
            ;;
        *) die "usage: secrets.sh push web|release" ;;
    esac
    cmd_backup
)

cmd_check() {
    local missing=0 k
    echo "GitHub ($GH_REPO) secrets with no local copy in apps/macos/.env:"
    for k in $(gh secret list --repo "$GH_REPO" --json name --jq '.[].name'); do
        if [[ ! -f "$MAC_ENV" || -z "$(env_value "$MAC_ENV" "$k")" ]]; then flag_missing "$k"; fi
    done
    echo "Cloudflare Worker secrets with no local copy in apps/web/.env:"
    for k in $(cd "$ROOT/apps/web" && CI=true bunx wrangler secret list 2>/dev/null \
                 | python3 -c 'import json,sys; [print(s["name"]) for s in json.load(sys.stdin)]'); do
        if [[ ! -f "$WEB_ENV" || -z "$(env_value "$WEB_ENV" "$k")" ]]; then flag_missing "$k"; fi
    done
    local latest="$BACKUP_DIR/ewiz-secrets-latest.tar.gpg"
    if [[ -f "$latest" ]]; then
        for f in "$WEB_ENV" "$MAC_ENV"; do
            [[ -f "$f" && "$f" -nt "$latest" ]] && { echo "! $f changed after the last backup — run backup"; missing=1; }
        done
        echo "Last backup: $(stat -f '%Sm' "$latest")"
    else
        echo "! no backup yet — run backup"; missing=1
    fi
    [[ $missing -eq 0 ]] && echo "Every irreplaceable secret has a local copy and a current backup."
    return $missing
}

case "${1:-}" in
    backup)  cmd_backup ;;
    restore) shift; cmd_restore "$@" ;;
    push)    shift; cmd_push "$@" ;;
    check)   cmd_check ;;
    *) sed -n '2,24p' "$0"; exit 1 ;;
esac
