---
"ewiz": patch
---

**Fixed: the charge limit could be crossed while the Mac slept, charging to full.**

Enforcement is a tick loop in the root daemon, and that loop is frozen for the whole
time the Mac is asleep — so whatever the SMC was last told is what stands. Sleep while
charging below the limit and macOS carries on charging, unsupervised, to 100%.

Cutting charging on the way into sleep was the protection, but it had two holes. It was
gated behind the "Stop charging before sleep" option, which is off by default, so a
limit set by itself wasn't protected at all. And the request came from the app, over the
control socket, which means it only happened while the app was running — quit eWiz,
log out, or have it crash, and the protection vanished with no sign that it had.

The daemon now registers for sleep and wake notifications itself, on its own thread and
run loop, so the cut happens whether or not anything is running in user space. It
applies whenever a charge limit is enforced, not only when the option is ticked: the
limit exists to keep the battery off full, and there is no way to stop at it while
frozen. Charge still creeps towards the limit across the maintenance wakes macOS takes
anyway — the tick runs during those and re-enables charging while below the resume
threshold — and enforcement is re-evaluated the moment the Mac powers back on instead of
waiting out the tick interval. The app's own pre-sleep request stays, so older app builds
keep working; both paths are idempotent.
