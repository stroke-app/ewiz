---
"ewiz": patch
---

**Your charge limit holds even when macOS switches its own limit off.** On Macs where eWiz limits charging through macOS's charge limit, macOS sometimes ignores that limit, usually while it recalibrates the battery, and charges to full. eWiz used to only tell you about it. Now it stops the charge itself: the Mac runs on the battery down to 2% under your limit, then takes power again. The "charging past your limit" notification is gone, since the limit no longer gets crossed.
