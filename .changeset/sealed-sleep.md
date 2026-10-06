---
"ewiz": minor
---

**Sealed Sleep** — close the lid and the charge stops moving.

A closed Mac isn't off. Memory stays powered for as long as the lid is shut, and macOS
wakes the machine on a timer for maintenance, for the network, and to answer Find My.
Each wake is seconds. Over a weekend they add up to a number nobody expects.

There is one lever that removes the trickle rather than trimming it: powering memory
down and writing it to disk. Sealed Sleep pulls that lever (`hibernatemode 25`,
`standby 1`) and then switches off everything that would hold the Mac up before it can
get there — Power Nap, wake-for-network, TCP keep-alive, terminal sessions — plus Wi-Fi
and Bluetooth as the lid actually closes.

What's new beyond the settings themselves:

- **A checklist instead of a promise.** Nine named causes of closed-lid drain, each
  shown as sealed or still costing power. Two aren't eWiz's call and say so: Find My
  can't reach a sealed Mac, and a keep-awake you turned on deliberately stays on until
  you release it.
- **Verified writes.** `pmset` exits 0 for keys a Mac silently ignores, so everything is
  read back and anything refused is named rather than quietly counted as success.
- **Measured, not projected.** The charge is read at close and again at open, so the
  panel reports what the last closed-lid stretch actually cost, per hour and per night.
- **Reversible.** Every displaced setting is snapshotted on the way in and written back
  on the way out, including the two radio preferences the app owns.
- **Held against everything that used to undo it.** A save mode switch, or a Mac that
  drifted after a macOS update, no longer silently unseals it.

The cost is stated where the switch is, because it applies to every sleep and not just
the long ones: opening the lid takes fifteen to thirty seconds while memory is read back
from disk.

Replaces the **Deep sleep** picker and **Super Save when lid closed** — three controls
aimed at one outcome, none of them sufficient alone. Anyone who had chosen Deep sleep
keeps it: that setting migrates to Sealed Sleep on first launch.
