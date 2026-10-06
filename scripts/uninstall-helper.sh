#!/bin/bash
# Removes the eWiz privileged helper LaunchDaemon.
# Run with sudo:  sudo ./scripts/uninstall-helper.sh
set -euo pipefail

PLIST_DST="/Library/LaunchDaemons/com.ewiz.helper.plist"
BIN_DST="/usr/local/bin/ewiz-helper"

if [[ "$EUID" -ne 0 ]]; then
    echo "error: must run as root (use sudo)." >&2
    exit 1
fi

echo "==> Unloading daemon"
launchctl bootout system "$PLIST_DST" 2>/dev/null || true

# Re-enable charging AFTER the daemon is unloaded: on exit the daemon now
# preserves the charge inhibit (so the limit survives shutdown/restart), so this
# must be the last word on the SMC — otherwise the daemon's exit cleanup would
# re-inhibit charging right after we cleared it, leaving the Mac unable to charge.
echo "==> Re-enabling charging (safety) after unloading daemon"
"$BIN_DST" enable 2>/dev/null || true

echo "==> Removing files"
rm -f "$PLIST_DST"
rm -f "$BIN_DST"
rm -f /var/run/ewiz.sock

# The pre-rename BattPie daemon, if this Mac ever ran it. Uninstalling only the
# current helper would leave that one loaded and still driving the charge keys,
# so "uninstalled" would still mean a Mac that won't charge.
# And the Battlify one, its name before eWiz.
for legacy in battpie battlify; do
    LEGACY_PLIST="/Library/LaunchDaemons/com.$legacy.helper.plist"
    LEGACY_BIN="/usr/local/bin/$legacy-helper"
    if [[ -e "$LEGACY_PLIST" || -e "$LEGACY_BIN" ]]; then
        echo "==> Removing the superseded $legacy helper"
        launchctl bootout system "$LEGACY_PLIST" 2>/dev/null || true
        pkill -f "^$LEGACY_BIN" 2>/dev/null || true
        "$LEGACY_BIN" enable 2>/dev/null || true
        rm -f "$LEGACY_PLIST" "$LEGACY_BIN" "/var/run/$legacy.sock"
    fi
done

echo "==> Done. (Config left in /Library/Application Support/eWiz)"
