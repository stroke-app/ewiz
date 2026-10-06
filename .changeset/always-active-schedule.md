---
"ewiz": minor
---

**Always Active** can now switch itself on and off instead of only being held by hand.

**Always Active hours** (Settings → Schedule) hold the Mac awake on a weekly
timetable — for example weekdays from 9 AM for 9 hours. While at least one window is
enabled, the switch means "hold during these hours": inside a window the lid-closed
hold applies, outside it the Mac sleeps normally, with no need to remember to turn it
off. Windows may wrap past midnight, so an overnight window belongs to the day it
starts on. With no windows set the switch behaves exactly as before.

**Turn off automatically** (Settings → Charging, under Always Active) sets a deadline —
30 minutes to 8 hours, or "don't turn off". The deadline lives in the root daemon's
config, so it still fires while the Mac is asleep or eWiz isn't running, and it
clears the switch rather than leaving an on toggle that no longer holds anything.

The Always Active section shows which hours are set and whether it is **HOLDING** or
**WAITING** right now, and the clamshell display saver follows the same verdict — it
no longer forces the internal display off outside a scheduled window.
