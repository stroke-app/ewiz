#!/bin/bash
# Prints the build number (CFBundleVersion, and the appcast's sparkle:version) for a
# release version. Sparkle decides "is this newer?" from that number, so it has to grow
# with every release and read as one integer: major*10000 + minor*100 + patch.
#
#   0.18.5        → 1805
#   0.19.0        → 1900
#   1.2.3         → 10203
#   0.19.0-beta.1 → 1900   (a pre-release suffix is ignored)
#
# Minor and patch therefore have two digits each: a 0.100.0 or 0.18.100 would collide
# with its neighbours, so the script refuses them rather than ship a version Sparkle
# would sort wrongly. scripts/package-app.sh writes it into Info.plist and
# scripts/make-appcast.sh into appcast.xml, from the same version string, so the two
# can't disagree.
#
# Usage: ./scripts/build-number.sh <version>
set -euo pipefail

VERSION="${1:?usage: build-number.sh <version>}"
IFS=. read -r MAJOR MINOR PATCH _ <<<"${VERSION%%-*}"

for part in MAJOR MINOR PATCH; do
    digits="${!part:-0}"
    digits="${digits//[!0-9]/}"
    : "${digits:=0}"
    printf -v "$part" '%d' "$((10#$digits))"
done

if (( MINOR >= 100 || PATCH >= 100 )); then
    echo "error: $VERSION has a minor or patch ≥ 100; the build number would not sort after earlier releases" >&2
    exit 1
fi

echo $(( MAJOR * 10000 + MINOR * 100 + PATCH ))
