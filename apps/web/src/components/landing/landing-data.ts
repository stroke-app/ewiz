export const LINKS = {
  github: "https://github.com/broisnischal/battlify",
  releases: "https://github.com/broisnischal/battlify/releases",
  feedback: "https://github.com/broisnischal/battlify/issues",
} as const;

export type MomentArt = "bar" | "thermo" | "moon" | "led";

// Full-bleed feature "moments", alternating light and dark, each with its own art.
export const MOMENTS = [
  {
    eye: "Charge limit",
    title: "Stops at a number you love.",
    body: "Pick any ceiling from 50% up to 100%, and Battlify keeps it right there. It holds the level with a small buffer so the charger isn't clicking on and off all day. A battery that lives around 80% simply lasts a lot longer. And when you're about to head out, one tap tops it up to 100%, then it drops back on its own.",
    note: 'It works with both of Apple\'s charging schemes: the older CH0B/CH0C keys and the newer CHTE on macOS 26 "Tahoe".',
    tone: "light",
    flip: false,
    art: "bar",
  },
  {
    eye: "Sleep-safe",
    title: "Holds the line, even asleep.",
    body: "Most limiters clock out the second your Mac falls asleep, so macOS quietly sneaks you back up to 100% overnight. Battlify doesn't. It can stop charging right before sleep, or keep the Mac awake on wall power so your limit never slips.",
    tone: "dark",
    flip: true,
    art: "moon",
  },
  {
    eye: "Heat-aware",
    title: "Never breaks a sweat.",
    body: "Heat ages a battery faster than charge cycles ever do. Set a temperature you're happy with, and charging pauses the moment things get warm, then picks back up once they cool off. The menu always tells you why it paused, so it never feels broken.",
    tone: "light",
    flip: false,
    art: "thermo",
  },
  {
    eye: "MagSafe LED",
    title: "Your cable, in the know.",
    body: "Battlify drives the MagSafe light straight from the real charge state. It glows amber while charging, and turns green the instant it's holding at your limit. One look at the cable and you know what's going on, without opening a thing.",
    tone: "dark",
    flip: true,
    art: "led",
  },
] as const satisfies ReadonlyArray<{
  eye: string;
  title: string;
  body: string;
  note?: string;
  tone: "light" | "dark";
  flip: boolean;
  art: MomentArt;
}>;

export const SPECS = [
  { n: "macOS 14+", l: "Sonoma and later" },
  { n: "Apple Silicon", l: "arm64 native" },
  { n: "Native Swift", l: "event-driven, low energy" },
  { n: "Menu-bar only", l: "no Dock icon, no clutter" },
] as const;

export const TESTIMONIALS = [
  {
    quote: "Pulled my MacBook out of my bag and it was at the exact same charge. First time ever.",
    who: "MacBook Pro user",
    src: "GitHub",
  },
  {
    quote: "Set it to 80% once and forgot about it. The menu-bar UI is genuinely lovely.",
    who: "Apple Silicon dev",
    src: "Reddit",
  },
  {
    quote: "My AirPods used to connect to my closed laptop constantly. Not anymore. Bliss.",
    who: "Designer",
    src: "Email",
  },
  {
    quote: "Heat-aware charging got me through a whole summer of hot dock sessions.",
    who: "Remote worker",
    src: "GitHub",
  },
  {
    quote: "Amber to green on the MagSafe cable is such a tiny, perfect detail.",
    who: "M3 MacBook Air owner",
    src: "Feedback",
  },
  {
    quote: "$2.99 for something this polished feels almost unfair. Instant buy.",
    who: "Power user",
    src: "Email",
  },
] as const;
