#!/bin/bash
# Installs the prebuilt helper from eWiz.app/Contents/Resources. Run as root
# by the app; does not rebuild.
set -euo pipefail

RES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The helper sits in Contents/MacOS alongside the app binary — SMAppService needs it there,
# and this script runs from Contents/Resources.
BIN_SRC="$RES_DIR/../MacOS/ewiz-helper"
PLIST_SRC="$RES_DIR/com.ewiz.helper.plist"
BIN_DST="/usr/local/bin/ewiz-helper"
PLIST_DST="/Library/LaunchDaemons/com.ewiz.helper.plist"
LABEL="com.ewiz.helper"

if [[ "$EUID" -ne 0 ]]; then
    echo "error: must run as root." >&2
    exit 1
fi
if [[ ! -x "$BIN_SRC" ]]; then
    echo "error: bundled helper not found at $BIN_SRC" >&2
    exit 1
fi

# `launchctl bootout` is async: bootstrapping right after it races the old job's
# teardown and fails with "Bootstrap failed: 5". Enable first (a disabled service
# won't bootstrap), wait for the old instance to unload, then bootstrap with retry.
reload_daemon() {
    local plist="$1" label="$2"
    local errfile; errfile="$(mktemp)"

    launchctl enable "system/$label" 2>/dev/null || true

    if launchctl print "system/$label" >/dev/null 2>&1; then
        launchctl bootout "system/$label" 2>/dev/null || true
        for _ in $(seq 1 50); do   # wait up to ~5s for unload
            launchctl print "system/$label" >/dev/null 2>&1 || break
            sleep 0.1
        done
    fi

    for _ in $(seq 1 10); do
        if launchctl bootstrap system "$plist" 2>"$errfile"; then
            rm -f "$errfile"
            return 0
        fi
        # already loaded (we lost the race) — restart onto the new binary and stop
        if launchctl print "system/$label" >/dev/null 2>&1; then
            launchctl kickstart -k "system/$label" 2>/dev/null || true
            rm -f "$errfile"
            return 0
        fi
        sleep 0.3
    done

    echo "error: failed to load daemon after several attempts:" >&2
    cat "$errfile" >&2 2>/dev/null || true
    rm -f "$errfile"
    return 1
}

# eWiz was called BattPie, then Battlify, and shipped its helper under other labels,
# binary and socket. Installing on top of that left BOTH daemons loaded, each with
# KeepAlive, each driving the same SMC charge keys on its own timer — so they fought,
# and whichever wrote last won the tick. When the old one won while holding the charge
# inhibit, the Mac sat on the charger and drained to empty, because the daemon that
# knew the limit was no longer the one talking to the hardware.
#
# Nothing we install depends on the old app, so evict it unconditionally.
evict_legacy_daemon() {
    local label="$1" bin="$2" plist="$3" sock="$4"

    if launchctl print "system/$label" >/dev/null 2>&1; then
        echo "==> Removing the superseded $label daemon"
        launchctl bootout "system/$label" 2>/dev/null || true
        for _ in $(seq 1 50); do   # wait up to ~5s for unload
            launchctl print "system/$label" >/dev/null 2>&1 || break
            sleep 0.1
        done
    fi

    # Its job is unloaded, so a survivor of the SIGTERM won't be revived by KeepAlive.
    pkill -f "^$bin" 2>/dev/null || true

    # Clear the inhibit before the binary goes. The old daemon deliberately leaves
    # charging cut on exit so a limit survives reboot, and once its binary is deleted
    # nothing on the system still knows how to undo that. Our daemon re-applies the
    # real limit seconds later, so this is a handover and not a policy change.
    if [[ -x "$bin" ]]; then
        "$bin" enable 2>/dev/null || true
    fi

    rm -f "$bin" "$plist" "$sock"
}

evict_legacy_daemon "com.battpie.helper" \
    "/usr/local/bin/battpie-helper" \
    "/Library/LaunchDaemons/com.battpie.helper.plist" \
    "/var/run/battpie.sock"
evict_legacy_daemon "com.battlify.helper" \
    "/usr/local/bin/battlify-helper" \
    "/Library/LaunchDaemons/com.battlify.helper.plist" \
    "/var/run/battlify.sock"

install -d /usr/local/bin
install -m 755 "$BIN_SRC" "$BIN_DST"
# strip quarantine, or Gatekeeper kills the LaunchDaemon (build isn't notarized)
xattr -c "$BIN_DST" 2>/dev/null || true

install -m 644 "$PLIST_SRC" "$PLIST_DST"
chown root:wheel "$PLIST_DST"
install -d -m 755 "/Library/Application Support/eWiz"

if ! reload_daemon "$PLIST_DST" "$LABEL"; then
    exit 1
fi

echo "eWiz helper installed and loaded."
