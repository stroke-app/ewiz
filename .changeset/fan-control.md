---
"ewiz": minor
---

**Fans: monitoring, temperatures, and control where the hardware allows it.**

Settings › Sleep & Power now lists every fan the way a fan utility should — name (Left side /
Right side, as the hardware's own tools name them), its minimum, current and maximum rpm with
the live figure emphasised, and what is driving it — followed by a Temperatures card. Sensors
are discovered by walking the SMC's own key table rather than a hardcoded list, because the
keys differ per model and a fixed list is wrong on every Mac it wasn't written for.

Fan *control* is offered only where the SMC accepts it. Some Macs read every fan key and
refuse every write — an M3 Pro on macOS 26 refuses all of them — which is not knowable in
advance, so eWiz tries once, remembers the answer, and says plainly that the machine
won't allow it rather than pretending. Where writes are accepted, Custom holds each fan at a
percentage of its own min…max range (a percentage rather than an rpm figure, because two fans
in one machine needn't share a range), 0% is each fan's minimum rather than off, control
returns to macOS above a temperature guard, and the daemon restores auto when it stops.

Fans reading 0 rpm on a cool Apple silicon Mac is normal, and the UI says so: they stop
entirely until there is heat to move.
