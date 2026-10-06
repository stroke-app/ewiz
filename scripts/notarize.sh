#!/bin/bash
# Notarizes and staples a DMG using an App Store Connect API key.
# Usage: ./scripts/notarize.sh dist/eWiz-0.1.0.dmg
#
# Requires these env vars (an App Store Connect API key with "Developer" role):
#   NOTARY_KEY_ID      - the key ID (e.g. ABC123XYZ)
#   NOTARY_ISSUER_ID   - the issuer UUID
#   NOTARY_KEY_PATH    - path to the AuthKey_XXXX.p8 file
set -euo pipefail

DMG="${1:?usage: notarize.sh <path-to-dmg>}"
: "${NOTARY_KEY_ID:?set NOTARY_KEY_ID}"
: "${NOTARY_ISSUER_ID:?set NOTARY_ISSUER_ID}"
: "${NOTARY_KEY_PATH:?set NOTARY_KEY_PATH}"

echo "==> Submitting $DMG to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG" \
    --key "$NOTARY_KEY_PATH" \
    --key-id "$NOTARY_KEY_ID" \
    --issuer "$NOTARY_ISSUER_ID" \
    --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
echo "==> Notarized & stapled: $DMG"
