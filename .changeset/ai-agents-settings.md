---
"ewiz": patch
---

**AI Agents, in Settings.** eWiz ships an MCP server that lets AI agents (Claude, Cursor
and other MCP apps) keep the Mac awake through a long build, test run or download, on a
timer that ends by itself. It now has a home in **Settings › Automation › AI Agents**:

- **One switch** to let agents use it at all, and a second for keeping the Mac running
  with the lid closed. Agents asking while it's off are told so, and where to turn it on.
- **Connect** adds eWiz to Claude Desktop or Cursor in one click, keeping everything else
  in their settings. Claude Code gets a ready-to-paste command, and any other MCP app a
  config block.
- **Live status** shows which agent is keeping the Mac awake, for what, and for how long.
