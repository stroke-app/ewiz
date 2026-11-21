#!/bin/bash
# Regenerate the app icon assets from the vector master (branding/ewiz-icon.svg):
#   - branding/AppIcon.icns                         (loose icon, Finder/Dock fallback)
#   - branding/Assets.xcassets/AppIcon.appiconset/  (source for actool → Assets.car)
# The asset catalog is what macOS Notification Center uses to resolve the app icon,
# so it must exist for notifications to show the icon (a loose .icns alone doesn't
# populate the notification banner on modern macOS).
#
# Requires: rsvg-convert (brew install librsvg) + macOS iconutil.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$REPO_DIR/branding/ewiz-icon.svg"
ICNS="$REPO_DIR/branding/AppIcon.icns"
XCASSETS="$REPO_DIR/branding/Assets.xcassets"
APPICONSET="$XCASSETS/AppIcon.appiconset"

command -v rsvg-convert >/dev/null || { echo "error: rsvg-convert not found (brew install librsvg)"; exit 1; }

mkdir -p "$APPICONSET"

# Render each macOS icon slot straight from the SVG for maximum crispness.
render() { rsvg-convert -w "$1" -h "$1" "$SVG" -o "$APPICONSET/$2"; }
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

# Asset-catalog manifests.
cat > "$XCASSETS/Contents.json" <<'JSON'
{
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

cat > "$APPICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16",   "filename" : "icon_16x16.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16",   "filename" : "icon_16x16@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32",   "filename" : "icon_32x32.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32",   "filename" : "icon_32x32@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128", "filename" : "icon_128x128.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128", "filename" : "icon_128x128@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256", "filename" : "icon_256x256.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256", "filename" : "icon_256x256@2x.png" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512", "filename" : "icon_512x512.png" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512", "filename" : "icon_512x512@2x.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

# Build the loose .icns from the same PNGs (iconutil wants a .iconset directory).
WORK="$(mktemp -d)"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
cp "$APPICONSET"/icon_*.png "$ICONSET"/
iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$WORK"

echo "==> Wrote $ICNS"
echo "==> Wrote $APPICONSET (asset-catalog source for actool)"
