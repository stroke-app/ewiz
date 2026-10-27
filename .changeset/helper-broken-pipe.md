---
"ewiz": patch
---

**The helper no longer crashes when the app stops waiting for it, and a held charge stays
held across helper restarts.** When the helper was busy (a sleep transition, a settings
write) the app gave up on its request after a few seconds and closed the connection. The
helper's reply to that closed connection raised a broken-pipe signal that killed it; launchd
started it again, but the restarted helper had forgotten where "don't charge" had parked the
battery and let it charge on to the limit, and the app showed "The helper installed but
isn't responding" beside "Installed and running" until it was relaunched. The helper now
survives a client that hangs up, remembers the hold level on disk, the app waits longer for a
freshly installed helper to come up, and the error clears as soon as the helper answers.
