---
"ewiz": patch
---

**The menu-bar panel no longer stops responding after eWiz has been running a while.**
After hours of running, the panel could open looking normal while every button, toggle
and mode in it did nothing until eWiz was restarted. The panel is now built fresh each
time it opens, so it can't go stale. It also opens fully on screen at the right edge, no
longer flickers when switching modes, and keeps a failed helper install's error visible
after the password prompt closes it.
