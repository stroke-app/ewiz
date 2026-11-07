---
"ewiz": patch
---

**Permissions and the helper now survive updates.** eWiz is now signed with its own certificate instead of a one-off signature, so macOS keeps Bluetooth and other permissions across updates, and the helper updates itself without asking for your password. The first update after this one asks once more; later ones don't.
