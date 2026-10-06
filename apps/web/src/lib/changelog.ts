/** eWiz release history, newest first. Shared by /changelog and /llms-full.txt. */
export type Group = { heading: "New" | "Fixes" | "Changes" | "Removals"; items: string[] };
export type Release = { v: string; date: string; title: string; groups: Group[]; quote?: string };

/**
 * Release timeline, newest first. Mirrors the GitHub releases; each version
 * links to its full notes there (see releaseUrl).
 */
export const RELEASES: Release[] = [
  {
    v: "0.18.1",
    date: "Oct 6, 2026",
    title: "A new icon",
    groups: [
      {
        heading: "New",
        items: [
          "A new icon: a lightning bolt that doubles as a wizard's hat, in the Dock, Finder, Settings › About and the license window",
          "About and the license window read the icon from the app itself, so they always match the Dock",
        ],
      },
      { heading: "Changes", items: ["The disk image now contains just eWiz"] },
    ],
  },
  {
    v: "0.18.0",
    date: "Oct 6, 2026",
    title: "Battlify is now eWiz",
    groups: [
      {
        heading: "New",
        items: [
          "A new name and icon. Existing Battlify installs move over to eWiz on their next update",
          "An MCP server, so AI agents can check battery status and keep the Mac awake during long tasks",
        ],
      },
      {
        heading: "Fixes",
        items: [
          "Steadier charge limit: the hold rounds up to the macOS charging step instead of down",
          "The menu bar icon, MagSafe light and panel now show the real charge state",
        ],
      },
    ],
  },
  {
    v: "0.17.0",
    date: "Aug 3, 2026",
    title: "Global keyboard shortcuts",
    groups: [
      { heading: "New", items: ["Global keyboard shortcuts for the most-used controls"] },
      { heading: "Fixes", items: ["Reduced battery drain while the lid is closed"] },
    ],
  },
  {
    v: "0.16.0",
    date: "Jul 30, 2026",
    title: "Deep sleep",
    groups: [
      {
        heading: "New",
        items: ["Deep sleep", "Sleep idle back-off", "Menu bar animation is now opt-in"],
      },
      { heading: "Removals", items: ["Fan boost"] },
    ],
  },
  {
    v: "0.15.0",
    date: "Jul 27, 2026",
    title: "Automation rules",
    groups: [
      {
        heading: "New",
        items: [
          "Automation rules: apply a charging or power setting while a condition holds",
          "Keep-awake picker with automatic sleep",
        ],
      },
      { heading: "Fixes", items: ["Charge limit fixes"] },
    ],
  },
  {
    v: "0.13.0",
    date: "Jul 22, 2026",
    title: "Endurance battery-saver",
    groups: [
      {
        heading: "New",
        items: [
          "Endurance mode: dims the screen, turns on Low Power Mode, and trims background wake and Bluetooth, with a live drain meter",
          "Keep-awake process picker",
          "Sleep the Mac automatically once a monitored task finishes",
        ],
      },
      {
        heading: "Fixes",
        items: [
          "Charge limit now survives shutdown and restart",
          "Charge power below 100% no longer stalls below the limit",
          "Heat cap no longer turns off silently after a failed temperature read",
          "Endurance stays off after you turn it off on battery",
        ],
      },
    ],
  },
  {
    v: "0.12.0",
    date: "Jul 18, 2026",
    title: "New icons and rest reminders",
    groups: [
      { heading: "New", items: ["Refreshed icon set", "A “Give your Mac a rest” reminder"] },
    ],
  },
  {
    v: "0.11.0",
    date: "Jul 18, 2026",
    title: "Caffeine mode",
    groups: [
      { heading: "New", items: ["Caffeine mode", "Pixel-style menu bar icon"] },
      { heading: "Fixes", items: ["Install, update, and clamshell fixes", "Performance work"] },
    ],
  },
  {
    v: "0.10.1",
    date: "Jul 14, 2026",
    title: "Notification icon fix",
    groups: [{ heading: "Fixes", items: ["App icon missing from notifications"] }],
  },
  {
    v: "0.10.0",
    date: "Jul 14, 2026",
    title: "New app icon",
    groups: [
      { heading: "New", items: ["Refreshed app icon"] },
      { heading: "Fixes", items: ["Save-mode settings now persist across restarts"] },
    ],
  },
  {
    v: "0.9.3",
    date: "Jul 5, 2026",
    title: "Keep-awake on battery",
    groups: [
      {
        heading: "Changes",
        items: ["Always Active can now be turned on while on battery, not only on AC"],
      },
    ],
  },
  {
    v: "0.9.2",
    date: "Jul 5, 2026",
    title: "Themes and a force-discharge fix",
    groups: [
      {
        heading: "New",
        items: ["Display turns off when the lid closes", "Light and dark themes", "New animations"],
      },
      {
        heading: "Fixes",
        items: [
          "Discharge now waits for a connected adapter, ending charge/discharge flip-flopping",
          "Notification and battery-accuracy fixes",
        ],
      },
    ],
  },
  {
    v: "0.9.0",
    date: "Jul 4, 2026",
    title: "Charge history",
    groups: [
      {
        heading: "New",
        items: [
          "History view with charging and battery sessions",
          "Daily summary and high-charge time tracking",
        ],
      },
    ],
  },
  {
    v: "0.8.1",
    date: "Jul 1, 2026",
    title: "First public release",
    groups: [],
    quote: "0.8.2 through 0.8.4 followed the same day with fixes and refinements.",
  },
];

/** Forward-looking, not commitments. Edit freely as the real roadmap firms up. */
export const ROADMAP = [
  "Scheduled charge limits by time of day",
  "Deeper health insights: cycle counts and capacity over time",
  "Localization, starting with the most-requested languages",
];
