---
"ewiz": patch
---

**Updates install themselves.** eWiz no longer stops at "won't replace itself
automatically" and a browser download. Each release's download is now signed, and eWiz
checks that signature before installing the update in place and relaunching. An update
that doesn't match is refused, and falls back to the download as before.

This takes effect from this version on: the update *to* it still goes through the
download once.
