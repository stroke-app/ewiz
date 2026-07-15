export const LINKS = {
  github: "https://github.com/broisnischal/battlify",
  releases: "https://github.com/broisnischal/battlify/releases",
  feedback: "https://github.com/broisnischal/battlify/issues",
} as const;

export type MomentArt = "bar" | "thermo" | "moon" | "led";

// The four narrative beats of "the fix", each a scene with its own micro-visual.
// Rendered as a sequenced, alternating scroll story, not a flat card grid.
export const MOMENTS = [
  {
    eye: "Hold the line",
    title: "Stops at a number you love.",
    body: "Pick any ceiling from 50 to 100 percent and Battlify keeps it right there, with a small buffer so the charger is not clicking on and off all day. A battery that lives around 80 percent simply lasts longer. Heading out? One tap tops it up to 100, then it drops back on its own.",
    note: 'Works with both of Apple\'s charging schemes: the older CH0B/CH0C keys and the newer CHTE on macOS 26 "Tahoe".',
    art: "bar",
  },
  {
    eye: "Even asleep",
    title: "Holds through the night.",
    body: "Most limiters clock out the second your Mac falls asleep, and macOS quietly creeps you back to 100 percent by morning. Battlify does not. It stops charging just before sleep, or keeps the Mac awake on wall power, so your limit never slips overnight.",
    art: "moon",
  },
  {
    eye: "Keeps its cool",
    title: "Backs off when it runs hot.",
    body: "Heat ages a battery faster than cycles ever will, and every 10 degrees roughly doubles the damage. Set a temperature you are happy with and charging pauses the moment things warm up, then resumes once they cool. The menu always tells you why, so it never feels broken.",
    art: "thermo",
  },
  {
    eye: "One glance",
    title: "Your cable tells the truth.",
    body: "Battlify drives the MagSafe light straight from the real charge state. Amber while it fills, green the instant it is holding at your limit. One look at the cable and you know exactly what is happening, without opening a thing.",
    art: "led",
  },
] as const satisfies ReadonlyArray<{
  eye: string;
  title: string;
  body: string;
  note?: string;
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

// Plain-language answers to the questions people actually ask before buying.
// Also serialized into FAQPage JSON-LD, so keep the answers self-contained.
export const FAQS = [
  {
    q: "Which Macs does Battlify support?",
    a: "Battlify runs on Apple Silicon Macs (M1 and later) on macOS 14 Sonoma or newer, including macOS 26 Tahoe. It is a native menu bar app, so there is no Dock icon and almost no energy cost.",
  },
  {
    q: "Does a charge limit really make my battery last longer?",
    a: "Yes. Lithium-ion batteries wear out fastest when they sit full and warm. Holding the charge around 80 percent keeps the battery in its low-stress range, which slows the loss of capacity over time.",
  },
  {
    q: "Does the limit hold while my Mac is asleep?",
    a: "It can. Battlify either stops charging just before sleep or keeps the Mac awake on wall power, so macOS cannot quietly push you back to 100 percent overnight.",
  },
  {
    q: "How much does Battlify cost?",
    a: "Battlify is a one-time purchase of $2.99. There is no subscription, updates are free for life, and you can try every feature free for 30 days before you decide.",
  },
  {
    q: "Can I move my license to another Mac?",
    a: "Yes. A license is locked to one Mac at a time, and you can move it to a new machine once every 30 days.",
  },
  {
    q: "Is my data private?",
    a: "Battlify does the battery work locally on your Mac and does not route your usage through our servers. The website stores only the account and license details needed to sell and support the app.",
  },
] as const;
