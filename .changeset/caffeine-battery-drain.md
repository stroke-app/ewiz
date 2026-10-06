---
"ewiz": minor
---

**Caffeine no longer holds the screen awake on battery.**

Caffeine held a `PreventUserIdleDisplaySleep` assertion — the same one `caffeinate -d`
takes — for as long as it was on, whatever the power source. Left on and unplugged, that
kept the display lit on an idle Mac (and, because macOS won't system-sleep while the
display is on, kept the whole machine up): several watts, or percents of charge per hour,
from a feature meant to keep work running.

On battery Caffeine now downgrades the hold to system-only — the same work keeps running,
but the screen is allowed to sleep — and restores the full hold when you plug back in. The
session itself never ends, and any timer keeps running; only the reach of the hold changes.
The replacement assertion is taken before the old one is released, so there's no window
for the display to sleep during the swap.

Two new options in **Settings → Sleep & Power → Caffeine**:

- **End it when I unplug** — stop the session outright on battery, for a Mac that should
  lose no charge at all while left alone.
- **Keep the screen on when on battery** — the old behaviour, for when the screen genuinely
  has to stay lit.

The card also shows what Caffeine is holding right now, and until when.
