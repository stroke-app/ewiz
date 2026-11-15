#!/usr/bin/env python3
"""Trace a plug / unplug through every layer, to see which one lags.

Every ~250 ms it reads:
  hw     the battery itself (IORegistry AppleSmartBattery): cable, charging, %, current
  macos  the power source macOS reports (pmset -g batt)
  helper what ewiz-helper's status says (control socket)
  app    what the eWiz menu-bar item says (its accessibility label)
and prints a line only when something changed, with the time since the last cable
change. On each change it also grabs the menu-bar item, so the icon's colour is on
record. Ctrl-C to stop. Output: stdout and plug-trace-<time>/trace.log.

  python3 scripts/plug-trace.py
"""
import json, os, re, socket, subprocess, sys, time

OUT = os.path.join(os.getcwd(), time.strftime("plug-trace-%H%M%S"))
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, "trace.log"), "w")


def sh(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=2).stdout
    except subprocess.TimeoutExpired:
        return ""


def hw():
    out = sh("ioreg", "-rn", "AppleSmartBattery")
    def val(key):
        m = re.search(rf'^\s*"{key}" = (\S+)', out, re.M)
        return m.group(1) if m else "?"
    amps = val("Amperage")
    try:
        amps = int(amps)
        amps = amps - (1 << 64) if amps > (1 << 63) else amps
    except ValueError:
        pass
    return {"cable": val("ExternalConnected") == "Yes", "charging": val("IsCharging") == "Yes",
            "pct": val("CurrentCapacity"), "mA": amps}


def macos():
    out = sh("pmset", "-g", "batt")
    src = "AC" if "AC Power" in out else "batt" if "Battery Power" in out else "?"
    m = re.search(r"\d+%; ([^;]+);", out)
    return {"source": src, "state": m.group(1) if m else "?"}


def helper():
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.5)
        s.connect("/var/run/ewiz.sock")
        s.sendall(b'{"getStatus":{}}\n')
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
        s.close()
        d = json.loads(buf)
        return {"enabled": d.get("chargingEnabled"), "reason": d.get("pauseReason"),
                "cut": d.get("discharging"), "native": d.get("nativeLimitApplied")}
    except Exception as e:  # a busy or missing helper is itself worth seeing
        return {"error": type(e).__name__}


AX = '''tell application "System Events" to tell process "eWiz"
  set i to menu bar item 1 of menu bar 2
  set {x, y} to position of i
  set {w, h} to size of i
  return (description of i) & "|" & x & "," & y & "," & w & "," & h
end tell'''


def app():
    out = sh("osascript", "-e", AX).strip()
    label, _, rect = out.partition("|")
    return {"label": label.removeprefix("eWiz, ")}, rect


def emit(line):
    print(line, flush=True)
    LOG.write(line + "\n"); LOG.flush()


emit(f"tracing → {OUT}   (unplug / plug in; Ctrl-C to stop)")
start = time.monotonic()
last_cable_at = None
prev = {}
shot = 0
try:
    while True:
        t = time.monotonic()
        a, rect = app()
        now = {"hw": hw(), "macos": macos(), "helper": helper(), "app": a}
        if now["hw"]["cable"] != prev.get("hw", {}).get("cable"):
            last_cable_at = t
        # Current wanders by tens of mA every second; only its sign is a state.
        def key(k, d):
            return {kk: (vv > 0 if kk == "mA" and isinstance(vv, int) else vv)
                    for kk, vv in d.items()} if k == "hw" else d
        changed = [k for k in now if key(k, now[k]) != key(k, prev.get(k, {}))]
        if changed:
            since = f"+{t - last_cable_at:5.2f}s" if last_cable_at else "   -   "
            stamp = time.strftime("%H:%M:%S") + f".{int((time.time() % 1) * 1000):03d}"
            parts = []
            for k in ("hw", "macos", "helper", "app"):
                body = " ".join(f"{kk}={vv}" for kk, vv in now[k].items())
                parts.append(("*" if k in changed else " ") + f"{k}[{body}]")
            emit(f"{stamp} {since}  " + "  ".join(parts))
            if rect.count(",") == 3:
                shot += 1
                x, y, w, h = rect.split(",")
                subprocess.run(["screencapture", "-x", "-R", f"{x},{y},{w},{h}",
                                os.path.join(OUT, f"icon-{shot:03d}-{since.strip()}.png")])
        prev = now
        time.sleep(max(0, 0.25 - (time.monotonic() - t)))
except KeyboardInterrupt:
    emit("stopped")
