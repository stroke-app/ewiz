---
"ewiz": patch
---

**No more Bluetooth permission prompt from the Automation tab.** The tab's live state read
your connected Bluetooth devices every few seconds, which made macOS ask for Bluetooth
access on every update and relaunch eWiz when you allowed it. Bluetooth is now read only
when a rule actually depends on it.

**The AI-agent server no longer crashes when a session ends.** Ending an agent session
sent a signal that crashed `ewiz-mcp` instead of releasing its keep-awake.
