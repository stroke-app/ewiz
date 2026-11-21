#!/bin/bash
# Installs the eWiz privileged helper as a LaunchDaemon (runs as root).
# Run with sudo:  sudo ./scripts/install-helper.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DST="/usr/local/bin/ewiz-helper"
PLIST_SRC="$REPO_DIR/scripts/com.ewiz.helper.plist"
PLIST_DST="/Library/LaunchDaemons/com.ewiz.helper.plist"
LABEL="com.ewiz.helper"

if [[ "$EUID" -ne 0 ]]; then
    echo "error: must run as root (use sudo)." >&2
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

echo "==> Building release binary…"
BUILD_FLAGS="-c release -Xswiftc -Osize -Xlinker -dead_strip"
# build as the invoking user so SwiftPM caches land in their home, not root's
if [[ -n "${SUDO_USER:-}" ]]; then
    sudo -u "$SUDO_USER" bash -lc "cd '$REPO_DIR' && swift build $BUILD_FLAGS --product ewiz-helper"
else
    (cd "$REPO_DIR" && swift build $BUILD_FLAGS --product ewiz-helper)
fi
BIN_SRC="$REPO_DIR/.build/release/ewiz-helper"

evict_legacy_daemon "com.battpie.helper" \
    "/usr/local/bin/battpie-helper" \
    "/Library/LaunchDaemons/com.battpie.helper.plist" \
    "/var/run/battpie.sock"
evict_legacy_daemon "com.battlify.helper" \
    "/usr/local/bin/battlify-helper" \
    "/Library/LaunchDaemons/com.battlify.helper.plist" \
    "/var/run/battlify.sock"

echo "==> Installing binary to $BIN_DST"
install -d /usr/local/bin
install -m 755 "$BIN_SRC" "$BIN_DST"
strip -x "$BIN_DST" || true   # shrink on-disk + resident size
# strip rewrites the file rather than editing it, so the result carries root's umask
# and not the mode above — 0700 under the default umask, which leaves the daemon fine
# (launchd runs it as root) but makes `ewiz-helper status` permission-denied for
# the person who installed it. Restore the mode we asked for.
chmod 755 "$BIN_DST"

echo "==> Installing LaunchDaemon to $PLIST_DST"
install -m 644 "$PLIST_SRC" "$PLIST_DST"
chown root:wheel "$PLIST_DST"

echo "==> Creating config directory"
install -d -m 755 "/Library/Application Support/eWiz"

echo "==> Loading daemon"
if ! reload_daemon "$PLIST_DST" "$LABEL"; then
    exit 1
fi

echo "==> Done. Status:"
sleep 1
"$BIN_DST" status || true
echo
echo "Logs: /var/log/ewiz-helper.log"
echo "To uninstall: sudo ./scripts/uninstall-helper.sh"
