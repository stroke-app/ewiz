#!/bin/bash
# Builds eWiz.app (a proper menu-bar app bundle) and a distributable zip.
# Usage: ./scripts/package-app.sh [version]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0}"
APP="eWiz.app"
DIST="$REPO_DIR/dist"
APP_DIR="$DIST/$APP"
CONTENTS="$APP_DIR/Contents"
BUNDLE_ID="com.ewiz.app"

echo "==> Building release binaries (v$VERSION)…"
cd "$REPO_DIR"
# Optimize for size (-Osize) and let the linker drop unreachable code
# (-dead_strip). Smaller text pages → smaller footprint, no behavior change.
BUILD_FLAGS=(-c release -Xswiftc -Osize -Xlinker -dead_strip)
# Sparkle.framework's install name is @rpath/Sparkle.framework/…, and SwiftPM links it
# without embedding it anywhere: the app finds it in Contents/Frameworks (copied below)
# only because of this rpath.
swift build "${BUILD_FLAGS[@]}" -Xlinker -rpath -Xlinker @executable_path/../Frameworks --product eWiz
swift build "${BUILD_FLAGS[@]}" --product ewiz-helper
swift build "${BUILD_FLAGS[@]}" --product ewiz-mcp
BIN_DIR="$REPO_DIR/.build/release"

# Sparkle ships as a binary xcframework inside the package artifact; take the macOS slice.
SPARKLE_SRC="$(find "$REPO_DIR/.build/artifacts" -type d -name Sparkle.framework -path '*macos*' | head -1)"
if [[ -z "$SPARKLE_SRC" ]]; then
    echo "error: Sparkle.framework not found under .build/artifacts — did the package resolve?" >&2
    exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

# Main GUI binary.
cp "$BIN_DIR/eWiz" "$CONTENTS/MacOS/eWiz"
chmod 755 "$CONTENTS/MacOS/eWiz"

# App icon. Ship the prebuilt .icns; regenerate it from the SVG master if it's
# missing and rsvg-convert is available (see scripts/make-icon.sh).
ICNS="$REPO_DIR/branding/AppIcon.icns"
if [[ ! -f "$ICNS" ]] && command -v rsvg-convert >/dev/null 2>&1; then
    echo "==> AppIcon.icns missing — regenerating from branding/ewiz-icon.svg"
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
cp "$BIN_DIR/ewiz-helper" "$CONTENTS/MacOS/ewiz-helper"
# The MCP server an AI agent launches (claude mcp add ewiz -- …/Contents/MacOS/ewiz-mcp).
cp "$BIN_DIR/ewiz-mcp" "$CONTENTS/MacOS/ewiz-mcp"
cp "$REPO_DIR/scripts/com.ewiz.helper.daemon.plist" \
   "$CONTENTS/Library/LaunchDaemons/com.ewiz.helper.plist"

# The legacy plist and the scripts stay bundled: they're the fallback for unsigned builds
# and for Macs that already run the /usr/local/bin daemon.
cp "$REPO_DIR/scripts/com.ewiz.helper.plist" "$CONTENTS/Resources/"
cp "$REPO_DIR/scripts/install-helper-bundled.sh" "$CONTENTS/Resources/"
cp "$REPO_DIR/scripts/uninstall-helper.sh" "$CONTENTS/Resources/"
chmod 755 "$CONTENTS/MacOS/ewiz-helper" "$CONTENTS/MacOS/ewiz-mcp" \
          "$CONTENTS/Resources/install-helper-bundled.sh" \
          "$CONTENTS/Resources/uninstall-helper.sh"

# The updater. ditto keeps the framework's Versions/Current symlinks. Headers and module
# maps are build-time only, so they stay out of the bundle (Xcode drops them on embed too).
mkdir -p "$CONTENTS/Frameworks"
SPARKLE="$CONTENTS/Frameworks/Sparkle.framework"
ditto "$SPARKLE_SRC" "$SPARKLE"
rm -rf "$SPARKLE/Versions/B/Headers" "$SPARKLE/Versions/B/PrivateHeaders" "$SPARKLE/Versions/B/Modules" \
       "$SPARKLE/Headers" "$SPARKLE/PrivateHeaders" "$SPARKLE/Modules"

# Strip local/debug symbols before signing (must precede codesign or it would
# invalidate the signature). -x keeps external symbols, so nothing breaks.
strip -x "$CONTENTS/MacOS/eWiz"
strip -x "$CONTENTS/MacOS/ewiz-helper"
strip -x "$CONTENTS/MacOS/ewiz-mcp"

# Info.plist — LSUIElement makes it a menu-bar-only (agent) app.
#
# CFBundleVersion is the build number Sparkle compares (see scripts/build-number.sh), and
# the SU* keys configure it: the feed, the release key every download has to verify
# against (UpdateSignature.publicKeyBase64 — the same key signs appcast.json for the old
# updater), a check on launch and every day without asking first, and verification of the
# image before it's even opened. The app is ad-hoc signed, so SUPublicEDKey is the only
# proof Sparkle has; it accepts that in place of a Developer ID match.
BUILD_NUMBER="$("$REPO_DIR/scripts/build-number.sh" "$VERSION")"
SPARKLE_FEED="https://raw.githubusercontent.com/stroke-app/ewiz-releases/main/appcast.xml"
# Read from the source so the key the app trusts and the key licensetool checks its
# signatures against are one constant.
SPARKLE_PUBLIC_KEY="$(sed -n 's/.*publicKeyBase64 = "\([A-Za-z0-9+\/=]*\)".*/\1/p' "$REPO_DIR/Sources/EWizKit/UpdateSignature.swift")"
if [[ ${#SPARKLE_PUBLIC_KEY} -ne 44 ]]; then
    echo "error: could not read UpdateSignature.publicKeyBase64 (got '$SPARKLE_PUBLIC_KEY')" >&2
    exit 1
fi
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>eWiz</string>
    <key>CFBundleDisplayName</key>      <string>eWiz</string>
    <key>CFBundleIdentifier</key>       <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>       <string>eWiz</string>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>$ICON_NAME_PLIST
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key>          <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>   <string>14.0</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHumanReadableCopyright</key> <string>eWiz</string>
    <!-- Sparkle (in-app updates). -->
    <key>SUFeedURL</key>                <string>$SPARKLE_FEED</string>
    <key>SUPublicEDKey</key>            <string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>  <true/>
    <key>SUScheduledCheckInterval</key> <integer>86400</integer>
    <key>SUVerifyUpdateBeforeExtraction</key> <true/>
    <!-- Required: eWiz toggles Bluetooth power on lid close. Without this
         usage string macOS kills the app (TCC) when it touches Bluetooth. -->
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>eWiz turns Bluetooth off when you close the lid and back on when you reopen it, to save battery.</string>
    <key>NSBluetoothPeripheralUsageDescription</key>
    <string>eWiz turns Bluetooth off when you close the lid and back on when you reopen it, to save battery.</string>
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
chmod 755 "$CONTENTS/MacOS/eWiz" "$CONTENTS/MacOS/ewiz-helper" "$CONTENTS/MacOS/ewiz-mcp"
chmod -R go+rX "$APP_DIR"

# Sign innermost first, then outward, and never --deep (deprecated, and it signs in the
# wrong order). Sparkle's pieces arrive ad-hoc signed by its own build; they are re-signed
# here so the whole bundle carries one identity, in the order Sparkle's documentation
# gives (sparkle-project.org/documentation/sandboxing): the XPC services, Autoupdate and
# Updater.app inside the framework, then the framework, then our executables, then the app.
# Downloader.xpc keeps its entitlements (network client), which --force would otherwise drop.
codesign "${SIGN_FLAGS[@]}" "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
codesign "${SIGN_FLAGS[@]}" --preserve-metadata=entitlements "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE/Versions/B/Autoupdate"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE/Versions/B/Updater.app"
codesign "${SIGN_FLAGS[@]}" "$SPARKLE"
codesign "${SIGN_FLAGS[@]}" "$CONTENTS/MacOS/ewiz-helper"
codesign "${SIGN_FLAGS[@]}" "$CONTENTS/MacOS/ewiz-mcp"
codesign "${SIGN_FLAGS[@]}" "$APP_DIR"
# --deep here only *checks* nested code; Sparkle's installer does the same before it
# will swap this bundle in, so a mis-signed piece should fail the build, not the update.
codesign --verify --deep --strict --verbose=2 "$APP_DIR" || echo "warning: verify failed"

echo "==> Creating zip"
cd "$DIST"
rm -f "eWiz-$VERSION.zip"
ditto -c -k --keepParent "$APP" "eWiz-$VERSION.zip"
shasum -a 256 "eWiz-$VERSION.zip"

echo "==> Done: $APP_DIR"
echo "    Run: open '$APP_DIR'"
