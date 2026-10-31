---
"ewiz": patch
---

**The menu-bar battery now follows the cable straight away.** Plugging in or unplugging
could leave the icon showing the old state for up to 45 seconds, because what the helper
was doing (holding or draining) was only re-checked every 30 seconds. The app now asks the
helper the moment the cable changes, and once you unplug, the icon stops treating the
battery as still on the charger. The unplug sound and haptic, which that stale state could
silence, now play again.
