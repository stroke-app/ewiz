---
"ewiz": minor
---

**Pick the plug-in animation from the menu**, not three windows deep in Settings. Quick
Actions gains an **Animation** button: switch it on or off, choose the style, and play it
on the spot to see what it looks like without unplugging anything.

**Bring your own animation.** A new **Custom** style plays a numbered image sequence from
`~/Library/Application Support/eWiz/ChargeAnimation` — export frames from Rive, Lottie
or After Effects and drop them in; Settings has a button that creates and reveals the
folder and tells you how many frames it found. Frames are read in filename order, capped
at 120, cached until the folder changes, and scaled to fit while preserving aspect, so a
square export isn't stretched across a 16:10 display. With no frames present it plays the
dot grid rather than flashing an empty screen. No third-party runtime, no binary format to
parse: an image sequence is the one export every motion tool agrees on.

**The charging animation runs at twice the frame rate.** A six-step sweep at two frames a
second reads as a slideshow however well it's eased; the tick is 250ms now, so a sweep
takes about 1.5s instead of 3. It still only runs while plugged in with animation switched
on, and stops the moment nothing needs it.

**Two more shortcuts:** rest / wake the Mac (⌃⌥⌘R) and cycle the menu-bar icon style
(⌃⌥⌘I). The rest shortcut shows its banner *before* the screen goes dark — a confirmation
nobody can see is not a confirmation.
