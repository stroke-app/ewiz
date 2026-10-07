export const LINKS = {
  github: "https://github.com/stroke-app/ewiz",
  /** This website's source. */
  siteSource: "https://github.com/stroke-app/ewiz-releases",
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
    a: "Apple Silicon Macs (M1 and later) on macOS 14 Sonoma or newer, including macOS 26 Tahoe. Intel Macs aren't supported. It lives in the menu bar with no Dock icon, and at idle it uses close to 0% CPU.",
  },
  {
    q: "Does a charge limit really make my battery last longer?",
    a: "It slows the wear. Lithium-ion batteries age fastest when they sit full and when they run hot, and a MacBook on a charger does both. Holding around 80% avoids the worst of it. It won't make an old battery new again.",
  },
  {
    q: "Does the limit hold while my Mac is asleep?",
    a: "Yes, if you let it. A charge limiter can't check anything while the Mac sleeps, which is how macOS sneaks back to 100% overnight. eWiz either stops charging just before sleep or keeps the Mac awake on wall power. You pick which.",
  },
  {
    q: "How much does eWiz cost?",
    a: "$2.99, once. There's no subscription, updates are free, and every feature is unlocked for the first 30 days so you can decide with the real thing.",
  },
  {
    q: "Can I move my license to another Mac?",
    a: "Yes. A license works on one Mac at a time, and you can move it to a new one once every 30 days.",
  },
  {
    q: "Is my data private?",
    a: "eWiz does its work on your Mac and doesn't send your usage anywhere. The website keeps only what it needs to sell you a license and support it: your account and your license.",
  },
  {
    q: "Why does it ask for my password?",
    a: "Charge limiting, Low Power Mode and the sleep controls need a small helper that runs as root, because macOS only lets root change them. You install it once from the menu, and you can uninstall it from Settings › General.",
  },
  {
    q: "Why does macOS warn me the first time I open it?",
    a: "eWiz isn't notarized by Apple yet. The first time, right-click the app in Applications and choose Open, or allow it in System Settings › Privacy & Security. After that it opens like any other app.",
  },
] as const;
