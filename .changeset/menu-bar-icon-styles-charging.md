---
"ewiz": minor
---

Four more menu-bar battery styles, and a charging icon that actually shows charging.

**Upright**, **Ring**, **Meter** and **Dot** join Rounded, Bars, Classic, Minimal and
Pixel. Upright is a standing battery filling from the bottom; Ring is a circular gauge
whose arc tracks the charge; Meter is a five-step signal-style scale; Dot is a circle
filling like liquid, for a menu bar that should stay quiet. The five horizontal styles
still share one drawing box so switching between them can't shift the menu-bar layout;
the upright and round styles are narrower by nature, which is a choice made once rather
than something that moves while you work. The picker is a grid now — nine tiles in one
row would each be too narrow to tell apart.

While charging, the fill rises from your real level towards full and restarts, instead
of the level disappearing behind a lone pulsing bolt. The bolt sits in a transparent
halo knocked out of the fill, so it stays legible from a sliver to full rather than
dissolving into it — and because the halo is alpha, it survives macOS's template
tinting in both light and dark menu bars. With the animation toggle off the icon draws
your true level with a steady bolt, so a static icon is never a lie. Ring gets a
travelling leading segment; Meter sweeps its steps.
