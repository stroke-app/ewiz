---
"ewiz": patch
---

**Plugging in shows "Charging" at once, and the MagSafe light stops flickering.** macOS's charging flag can lag a plug-in by over 20 seconds while current is already flowing into the battery. eWiz waited on that flag, so the panel said "Plugged in, not charging", the icon had no bolt, and the MagSafe light went amber, then green, then amber again. eWiz now treats current flowing into the battery as charging. Also adds `scripts/plug-trace.py`, which logs the battery, macOS, the helper and the menu bar side by side across a plug or unplug.
