---
"ewiz": patch
---

**eWiz's controls no longer stop working after a plug or unplug sound fails.** If the audio
output changed at the wrong moment (headphones, a display's speakers), the plug or unplug
sound could fail inside macOS's audio framework. eWiz didn't crash, but from then on every
button, toggle and mode in the menu-bar panel did nothing until eWiz was restarted. A
sound that fails is now skipped and eWiz carries on. This is the real fix for the
unresponsive panel that 0.19.1 set out to fix by rebuilding the panel on each open.
