---
"ewiz": minor
---

Removed fan control and Endurance mode.

**Fan control** is gone. Apple silicon refuses SMC fan writes — it returns success and
leaves the key reading what it was, which is why the feature spent three releases
learning to detect its own failure. On the hardware it did work on, it was a fan-speed
utility bolted to a battery app.

The one part that stays is the part that can't safely be deleted: forced fan mode lives
in the SMC and outlives the build that set it, across quit, log-out and restart. The
helper now hands every forced fan back to macOS once, at startup, and never touches them
again. A Mac left pinned by an older build fixes itself the first time this version runs.

**Endurance** is gone too. It dimmed the screen, turned on Low Power Mode, trimmed
background wake and switched Bluetooth off — overlapping Super Saver on three of four
levers, and driven by a drain meter whose reading depended more on what you were doing
than on whether the mode was on.

Existing configs load unchanged; the settings both features wrote are ignored and
dropped on the next save.
