#!/bin/bash
# Generates the Homebrew cask (ewiz.rb) for a release.
# Usage: ./scripts/make-cask.sh <version> <dmg-url> <sha256>
set -euo pipefail

VERSION="${1:?usage: make-cask.sh <version> <dmg-url> <sha256>}"
DMG_URL="${2:?usage: make-cask.sh <version> <dmg-url> <sha256>}"
SHA="${3:?usage: make-cask.sh <version> <dmg-url> <sha256>}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$REPO_DIR/dist"
OUT="$REPO_DIR/dist/ewiz.rb"

cat > "$OUT" <<RUBY
cask "ewiz" do
  version "$VERSION"
  sha256 "$SHA"

  url "$DMG_URL"
  name "eWiz"
  desc "Menu bar battery saver and charge limiter for Apple Silicon Macs"
  homepage "https://github.com/broisnischal/ewiz"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "eWiz.app"

  # The app is signed ad-hoc (not notarized yet). Homebrew quarantines downloads
  # and no longer supports --no-quarantine, so clear the quarantine after install
  # to let the app launch without a Gatekeeper "damaged" warning.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/eWiz.app"]
  end

  caveats <<~EOS
    Charge limiting, Low Power Mode, and sleep controls need a small root helper
    (a LaunchDaemon). After first launch, open the eWiz menu-bar item and
    click "Install Helper" — you will be asked for your password once. The helper
    re-enables charging automatically if it ever stops.
  EOS

  uninstall quit: ["com.ewiz.app", "com.battlify.app"]

  zap trash: [
    "~/Library/Application Support/eWiz",
    "~/Library/Preferences/com.ewiz.app.plist",
    # From before the rename.
    "~/Library/Application Support/Battlify",
    "~/Library/Preferences/com.battlify.app.plist",
  ]
end
RUBY

echo "wrote $OUT:"
cat "$OUT"
