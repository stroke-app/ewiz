---
"ewiz": minor
---

Menu-bar text options, a Power Adapter card, and CSV export for history.

- **Menu bar display** is now a choice of *Icon only / Percentage / Time remaining / Percentage & time* instead of a percentage on-off switch. Time remaining shows time to full while charging and time to empty on battery, and falls back to the percentage whenever macOS has no estimate. Existing preferences migrate (percentage off → Icon only).
- **Power Adapter card** in Battery Details: adapter name, negotiated wattage, supply voltage/current, manufacturer, model, and serial. When the adapter advertises more power than the Mac negotiated, it says so — that gap is almost always the cable.
- **Export history as CSV** from the History window: samples, daily summary, or lid sessions, for the range currently on screen.
