---
"battlify": minor
---

**The charge limit stays on.** A request that stalled the helper's control socket used
to block every other one, and the health check then tore the socket down and dropped
whatever the app had queued. Requests are now served in order with a short read bound,
and the check asks a question the daemon answers without its lock. The app no longer
pushes placeholder settings before its first answer from the helper (which could switch
the limit off), and edits are merged with the helper's current config instead of
overwriting it with a copy up to 30 seconds old.

**No more surprise password prompt.** One missed answer from the helper no longer reads
as "not installed"; the app asks again and only reinstalls after two misses.

**A menu-bar icon that tells the truth.** A bold bolt while current flows, a pause mark
while charging is held or paused, nothing on battery or when full, and a check when a
charge finishes, in every icon style (Pixel gets pixel-art marks). The mark springs in
when the state changes and drops away on unplug. The panel says "Draining to 80%" above
the limit rather than "Holding at 80%".

**Low-battery shake.** The icon trembles at 20%, and every 20 seconds under 10%.
Settings → General → Menu Bar, with a Preview button.

**Steadier panel.** Lid mode no longer inserts a row above the tiles, and the line under
them always takes one line, so pressing a tile never moves the layout.

**AI agents can keep the Mac awake.** A bundled MCP server lets an agent hold the Mac
awake for a long task, optionally with the lid closed, on a lease that ends on its own.

**Cleaner sounds.** Every theme now plays at matched loudness, without clicks, and the
off-key cues resolve.

**License and support.** The license window opens centred, asks before removing a
license, and links to support. Settings → About gains Contact Support, Report a Bug and
Copy Diagnostics, each filled in with what support needs.
