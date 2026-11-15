---
"ewiz": patch
---

**The helper update from 0.19.6 now actually installs, and plugging in no longer looks like a full battery.** 0.19.6 changed the helper so it notices charging starting, but didn't bump the helper's build number, so the app never replaced the running helper and kept the old one. That is now build 30 and installs on launch. In the seconds between plugging in and current flowing (and while the helper settles after wake), the menu-bar icon drew the pause mark, which on the bars style reads as a full battery over a 32% level. It now shows just the level until the bolt appears, and the panel says "Charging starts in a moment" while settling.
