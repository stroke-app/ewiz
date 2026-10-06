---
"ewiz": patch
---

**Fixed: the app could hang on a helper that looked perfectly healthy.** launchd reported the
job running, the binary and plist were in place, the process was alive — and every request the
app made got "connection refused", so the app blocked forever with nothing to show for it.

The cause was an install race one step further along than the installer guards for: two
daemons overlap briefly, the second removes the first's socket and binds its own, then the
second goes away. The survivor is still listening on a socket that no longer has a name.
Every health signal says fine; nothing can reach it.

Socket, bind and listen failures are now fatal — a helper with no control channel is worse
than none, because launchd keeps it and stops trying, whereas exiting gets it restarted with a
clean bind. The enforcement loop also checks that the socket path still refers to the socket it
bound, and exits if it doesn't, which is the only way that state is visible from inside the
process. Startup logs the path it's serving, so diagnosing this is now one line of log.
