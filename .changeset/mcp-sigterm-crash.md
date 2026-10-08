---
"ewiz": patch
---

**The AI-agent server really no longer crashes when a session ends.** The 0.18.5 fix only
held on newer build tools, so the released `ewiz-mcp` still crashed every time Claude Code
or another agent closed a session, which showed a "quit unexpectedly" report and skipped
handing back any hold it had taken. It now exits cleanly whatever it's built with.
