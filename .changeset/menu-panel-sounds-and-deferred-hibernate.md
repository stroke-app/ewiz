---
"ewiz": minor
---

**The menu panel, rebuilt to look like it belongs in the menu bar.**

320pt wide with 16pt margins, the geometry the system's own panels use. Rules stop at the
text margin rather than cutting the panel into bands, row labels sit at the system size,
and the surface is one flat opaque fill: the `NSVisualEffectView` it used to have sampled
whatever window was behind it, so the same menu read as near-black over the desktop and as
washed grey over an editor, and every fill inside it drifted with the background it was a
percentage of.

Three defects went with it. The save-mode picker is drawn here now instead of being an
`NSSegmentedControl`, which arrived as first responder wearing a focus ring no system panel
draws and sized every segment to its own label. The panel's window is sized to its content,
because `MenuBarExtra(.window)` grows its window with the content and never shrinks it back
— the leftover strip was bare, see-through window above the panel. And the window's opaque
square backing is cleared, so the rounded corners stop having dark right angles tucked
behind them.

**Sounds you can choose.** Five voicings of the same three cues: Warm, Glass (a bell's
inharmonic partials, not an octave stack), Pluck, Blip and Tick, which is transients only
for anyone who wants to be told without being sung to. The picker plays as you change it.

**A long close now costs nothing, and a short one still opens instantly.** Apple silicon
has no `standbydelay`: `hibernatemode` is either 3 (memory powered, instant lid, ~0.1%/h) or
25 (memory down, nothing to lose, 15–30s to come back). So the delay is implemented instead
of configured — on the way into a closed-lid sleep on battery the daemon books its own wake,
and if the Mac is still shut when that wake lands, memory goes off and it re-sleeps into
hibernation. Tunable under Sealed Sleep, 20 minutes by default.

**A Lid tile** in the quick actions, in place of Sleep: one press holds caffeine, Always
Active and the battery permission together, which is the set anyone working with the lid
shut turns on by hand. Sleep is still on its shortcut.

Fixed: "prevent idle sleep" was ANDed with the charge limit being on, so Extreme Performance
— which asks for no idle sleep and deliberately turns the limit off — could never hold the
assertion, and a Mac left on a long render idled out from under it.

The plug-in animation is off in this build and marked as coming in the next one. It plays
over whatever you're doing, so it ships when it's right.
