---
"ewiz": patch
---

**No more password prompt after every restart.** At login the app could ask for the helper before the helper had finished starting, decide it was missing, and ask for your password to install it again. It now waits up to two minutes for an installed helper to answer and shows "Starting helper…" meanwhile.
