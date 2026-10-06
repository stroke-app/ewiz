---
"ewiz": minor
---

**Animations were silently doing nothing if Reduce Motion was on.** Every animation in
the app — the charging icon, the charge-complete flash, the plug-in overlay — was gated
behind macOS's Reduce Motion, so on a Mac with it enabled, turning "animate the charging
icon" on had no visible effect whatsoever. Reduce Motion is still respected by default,
but Settings → Sleep & Power now offers **Animate anyway**, shown only when Reduce Motion
is actually on, and every animation reads the same resolved answer instead of each one
checking for itself.

**The animations were also linear, and linear reads as mechanical.** Nothing physical
moves at constant velocity. Progress now runs through real easing curves
(`cubic-bezier(0.23, 1, 0.32, 1)` and friends, solved the same way a browser solves
`cubic-bezier()`), and the timings came down to where a state change belongs:

- The charging fill sweeps in 6 steps rather than 8, front-loaded by the ease-out, so it
  surges and settles instead of crawling. The menu-bar tick can't safely go faster — each
  one relayouts the status item — so a shorter cycle is what buys the speed.
- Connect and disconnect morph in ~220ms (was 630ms and linear), which puts them in the
  same band as a dropdown. Ease-out, never ease-in: withholding motion at the start is
  what makes a short animation still feel slow.
- The overlay's dot wave has a narrow front (0.3 of the cycle, was 0.6) — at the old
  width most of the screen lit at once and it read as "dots everywhere" rather than a
  ripple crossing it.

**The menu-bar glyph now reacts to power changes.** Plug in and the bolt grows out of a
flat spark; unplug and it collapses back into one, both by real shape interpolation.

**Six more shortcuts:** brightness up and down (⌃⌥⌘] and ⌃⌥⌘[), battery saver (⌃⌥⌘E),
don't-charge (⌃⌥⌘H), and Wi-Fi and Bluetooth toggles — the last two ship deliberately
unbound, since cutting Wi-Fi by a mistyped chord is not a surprise worth shipping.
