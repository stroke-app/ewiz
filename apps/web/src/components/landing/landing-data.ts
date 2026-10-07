export const LINKS = {
  github: "https://github.com/stroke-app/ewiz",
  releases: "https://github.com/stroke-app/ewiz/releases",
  feedback: "https://github.com/stroke-app/ewiz/issues",
  x: "https://x.com/broisnischal",
  stroke: "https://stroke.click",
  site: "https://nischal-dahal.com.np",
} as const;

/** Homebrew cask, published to the stroke-app/homebrew-ewiz tap on every release. */
export const BREW_INSTALL = "brew install --cask stroke-app/ewiz/ewiz";

export const PRICE = "$2.99";

// Plain-language answers to the questions people actually ask before buying.
// Also serialized into FAQPage JSON-LD, so keep the answers self-contained.
export const FAQS = [
  {
    q: "Which Macs does eWiz support?",
    a: "eWiz runs on Apple Silicon Macs (M1 and later) on macOS 14 Sonoma or newer, including macOS 26 Tahoe. It is a native menu bar app, so there is no Dock icon and almost no energy cost.",
  },
  {
    q: "Does a charge limit really make my battery last longer?",
    a: "Yes. Lithium-ion batteries wear out fastest when they sit full and warm. Holding the charge around 80 percent keeps the battery in its low-stress range, which slows the loss of capacity over time.",
  },
  {
    q: "Does the limit hold while my Mac is asleep?",
    a: "It can. eWiz either stops charging just before sleep or keeps the Mac awake on wall power, so macOS cannot quietly push you back to 100 percent overnight.",
  },
  {
    q: "How much does eWiz cost?",
    a: "eWiz is a one-time purchase of $2.99. There is no subscription, updates are free for life, and you can try every feature free for 30 days before you decide.",
  },
  {
    q: "Can I move my license to another Mac?",
    a: "Yes. A license is locked to one Mac at a time, and you can move it to a new machine once every 30 days.",
  },
  {
    q: "Is my data private?",
    a: "eWiz does the battery work locally on your Mac and does not route your usage through our servers. The website stores only the account and license details needed to sell and support the app.",
  },
] as const;
