---
"ewiz": minor
---

**Don't charge while plugged in.** A switch that runs the Mac off the adapter and leaves
the battery exactly where it is — no charging, whatever the level and whatever the limit
says. It sits above the limit, schedules and ready-by top-ups deliberately: it's the
switch you reach for when the battery should be left alone, and being second-guessed by
another setting would defeat it. Only an explicit pause overrides it. On Macs with a
MagSafe light, the light holds **amber** while it's on, so the state is visible without
opening anything. Available in the menu, in Settings → Charging, and on ⌃⌥⌘H.

**Plug-in feedback (experimental).** Two opt-in bits of feedback for the moment the
adapter connects:

- **Trackpad taps** — two on connect, one on unplug, three when the charge limit is
  reached. It needs a Force Touch trackpad, and does nothing with the lid shut (the
  trackpad is asleep with it); there's no API to detect the hardware, so Settings says so
  rather than pretending to gate it.
- **A charging animation** over the screen for about a second: **Dot Grid** (a grid of
  dots ripples out from the port, each dot jittering as the wave passes), **Rings** (rings
  push out with the charge level in the middle), or **Glow** (a soft light rising off the
  bottom edge). The window is click-through, sits on the screen the pointer is on, and is
  torn down afterwards rather than kept around. Duration is capped at 2 seconds — it
  covers the screen, so it has to be over before it becomes something to wait out — and
  Reduce Motion replaces the motion with the level fading in place.

**Morphing glyphs.** The charging bolt now breathes between a slim and a fat bolt, and
the charge-complete flash grows that bolt into a checkmark, both via real shape
interpolation (`PathMorph`: outlines resampled by arc length, closed rings rotated into
least-travel alignment) rather than cross-fading two glyphs over each other. Covered by
eight unit tests.
