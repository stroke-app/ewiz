#!/bin/bash
# Builds Battlify.app (a proper menu-bar app bundle) and a distributable zip.
# Usage: ./scripts/package-app.sh [version]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP="Battlify.app"
DIST="$REPO_DIR/dist"
APP_DIR="$DIST/$APP"
CONTENTS="$APP_DIR/Contents"
BUNDLE_ID="com.battlify.app"

echo "==> Building release binaries (v$VERSION)…"
cd "$REPO_DIR"
# Optimize for size (-Osize) and let the linker drop unreachable code
# (-dead_strip). Smaller text pages → smaller footprint, no behavior change.
BUILD_FLAGS=(-c release -Xswiftc -Osize -Xlinker -dead_strip)
swift build "${BUILD_FLAGS[@]}" --product Battlify
swift build "${BUILD_FLAGS[@]}" --product battlify-helper
swift build "${BUILD_FLAGS[@]}" --product battlify-mcp
BIN_DIR="$REPO_DIR/.build/release"

echo "==> Assembling $APP"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# Main GUI binary.
cp "$BIN_DIR/Battlify" "$CONTENTS/MacOS/Battlify"
chmod 755 "$CONTENTS/MacOS/Battlify"

# App icon. Ship the prebuilt .icns; regenerate it from the SVG master if it's
# missing and rsvg-convert is available (see scripts/make-icon.sh).
ICNS="$REPO_DIR/branding/AppIcon.icns"
if [[ ! -f "$ICNS" ]] && command -v rsvg-convert >/dev/null 2>&1; then
    echo "==> AppIcon.icns missing — regenerating from branding/battlify-icon.svg"
    "$REPO_DIR/scripts/make-icon.sh"
fi
if [[ -f "$ICNS" ]]; then
    cp "$ICNS" "$CONTENTS/Resources/AppIcon.icns"
else
    echo "warning: branding/AppIcon.icns not found — app will have no custom icon"
fi

# Compile the asset catalog (Assets.car). This is what macOS Notification Center
# reads to resolve the app icon — a loose .icns alone leaves the notification
# banner icon blank. Needs actool (full Xcode; present on the CI runner). When
# it's unavailable (e.g. Command Line Tools only), fall back to the loose .icns
# and DON'T emit CFBundleIconName, so nothing points at a missing catalog.
XCASSETS="$REPO_DIR/branding/Assets.xcassets"
ICON_NAME_PLIST=""
if [[ -d "$XCASSETS" ]] && xcrun --find actool >/dev/null 2>&1; then
    echo "==> Compiling asset catalog with actool"
    if xcrun actool \
        --compile "$CONTENTS/Resources" \
        --app-icon AppIcon \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --output-partial-info-plist "$DIST/actool-partial.plist" \
        "$XCASSETS" >/dev/null; then
        if [[ -f "$CONTENTS/Resources/Assets.car" ]]; then
            ICON_NAME_PLIST=$'\n    <key>CFBundleIconName</key>         <string>AppIcon</string>'
            echo "==> Assets.car compiled — notifications will resolve the icon"
        fi
    else
        echo "warning: actool failed — shipping loose .icns only (notification icon may be blank)"
    fi
else
    echo "==> actool unavailable — shipping loose .icns only (notification icon needs a CI build)"
fi

# The helper lives in MacOS/, not Resources/, because SMAppService runs it straight out of
# the bundle via the BundleProgram path below — and a bundle-relative daemon is the whole
# reason app updates no longer need to reinstall anything. Contents/MacOS is also where a
# nested executable belongs for signing.
mkdir -p "$CONTENTS/Library/LaunchDaemons"
cp "$BIN_DIR/battlify-helper" "$CONTENTS/MacOS/battlify-helper"
# The MCP server an AI agent launches (claude mcp add battlify -- …/Contents/MacOS/battlify-mcp).
cp "$BIN_DIR/battlify-mcp" "$CONTENTS/MacOS/battlify-mcp"
cp "$REPO_DIR/scripts/com.battlify.helper.daemon.plist" \
   "$CONTENTS/Library/LaunchDaemons/com.battlify.helper.plist"

# The legacy plist and the scripts stay bundled: they're the fallback for unsigned builds
# and for Macs that already run the /usr/local/bin daemon.
cp "$REPO_DIR/scripts/com.battlify.helper.plist" "$CONTENTS/Resources/"
cp "$REPO_DIR/scripts/install-helper-bundled.sh" "$CONTENTS/Resources/"
cp "$REPO_DIR/scripts/uninstall-helper.sh" "$CONTENTS/Resources/"
chmod 755 "$CONTENTS/MacOS/battlify-helper" "$CONTENTS/MacOS/battlify-mcp" \
          "$CONTENTS/Resources/install-helper-bundled.sh" \
          "$CONTENTS/Resources/uninstall-helper.sh"

# Strip local/debug symbols before signing (must precede codesign or it would
# invalidate the signature). -x keeps external symbols, so nothing breaks.
strip -x "$CONTENTS/MacOS/Battlify"
strip -x "$CONTENTS/MacOS/battlify-helper"
strip -x "$CONTENTS/MacOS/battlify-mcp"

# Info.plist — LSUIElement makes it a menu-bar-only (agent) app.
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>Battlify</string>
    <key>CFBundleDisplayName</key>      <string>Battlify</string>
    <key>CFBundleIdentifier</key>       <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>       <string>Battlify</string>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>$ICON_NAME_PLIST
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>          <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>   <string>14.0</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHumanReadableCopyright</key> <string>Battlify</string>
    <!-- Required: Battlify toggles Bluetooth power on lid close. Without this
         usage string macOS kills the app (TCC) when it touches Bluetooth. -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Battlify turns Bluetooth off when you close the lid and back on when you reopen it, to save battery.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>Battlify turns Bluetooth off when you close the lid and back on when you reopen it, to save battery.</string>
</dict>
</plist>
PLIST

# Signing. Set CODESIGN_IDENTITY to a "Developer ID Application: …" identity for
# a distributable, notarizable build; otherwise we ad-hoc sign for local use.
IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
    echo "==> Ad-hoc code signing (local use only — not notarizable)"
    SIGN_FLAGS=(--force --sign -)
else
    echo "==> Developer ID signing with hardened runtime: $IDENTITY"
    SIGN_FLAGS=(--force --options runtime --timestamp --sign "$IDENTITY")
fi

# `strip` rewrites each binary rather than editing it, so the result carries the shell's
# umask and not the modes set when they were copied in — 0700 by default, which ships an
# app only its builder can run and a daemon binary root has to be lucky to execute. Fix
# the whole bundle here, after stripping and before signing.
chmod 755 "$CONTENTS/MacOS/Battlify" "$CONTENTS/MacOS/battlify-helper" "$CONTENTS/MacOS/battlify-mcp"
chmod -R go+rX "$APP_DIR"

# Sign nested executables first, then the app bundle (no deprecated --deep).
codesign "${SIGN_FLAGS[@]}" "$CONTENTS/MacOS/battlify-helper"
codesign "${SIGN_FLAGS[@]}" "$CONTENTS/MacOS/battlify-mcp"
codesign "${SIGN_FLAGS[@]}" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR" || echo "warning: verify failed"

echo "==> Creating zip"
cd "$DIST"
rm -f "Battlify-$VERSION.zip"
ditto -c -k --keepParent "$APP" "Battlify-$VERSION.zip"
shasum -a 256 "Battlify-$VERSION.zip"

echo "==> Done: $APP_DIR"
echo "    Run: open '$APP_DIR'"
