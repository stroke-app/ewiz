/**
 * The roadmap: /roadmap shows all of it, /changelog the "now" and "next" items under
 * the releases. The releases themselves come from GitHub (see #/lib/releases).
 *
 * Forward-looking, not commitments. Move items between stages as they firm up, and
 * delete them once they ship (the changelog says that part).
 */
export type RoadmapStage = "now" | "next" | "later";

export interface RoadmapItem {
  title: string;
  body: string;
  stage: RoadmapStage;
}

export const ROADMAP_STAGES: Record<RoadmapStage, { label: string; blurb: string }> = {
  now: { label: "In progress", blurb: "Being built right now." },
  next: { label: "Next up", blurb: "Planned for the coming releases." },
  later: { label: "Later", blurb: "Ideas we want to get to." },
};

export const ROADMAP: RoadmapItem[] = [
  {
    stage: "now",
    title: "Apple-signed, notarized builds",
    body: "eWiz opens with a double-click like any App Store app: no quarantine command, no “damaged app” warning.",
  },
  {
    stage: "now",
    title: "Sign in with Apple",
    body: "Sign in on ewiz.app with your Apple ID, alongside Google.",
  },
  {
    stage: "next",
    title: "Custom charging animations",
    body: "Pick the animation that plays when you plug in from a gallery, or import your own made in Lottie, Rive or any tool that exports image frames.",
  },
  {
    stage: "next",
    title: "Desktop and Notification Center widgets",
    body: "Battery level, your limit and time remaining at a glance, without opening the menu.",
  },
  {
    stage: "next",
    title: "Shortcuts and Siri actions",
    body: "Set the limit, pause charging or keep the Mac awake from the Shortcuts app, Siri and Focus filters.",
  },
  {
    stage: "next",
    title: "Battery health over time",
    body: "Capacity and cycle count charted across months, so you can see the limit paying off.",
  },
  {
    stage: "later",
    title: "Calendar-aware charging",
    body: "Charges to 100% before a trip or long day on your calendar, then goes back to your limit.",
  },
  {
    stage: "later",
    title: "Bluetooth device batteries",
    body: "AirPods, keyboard, mouse and trackpad levels in the menu, with a heads-up before they run out.",
  },
  {
    stage: "later",
    title: "Background energy alerts",
    body: "A nudge when an app keeps your Mac awake or drains the battery while you're not using it.",
  },
  {
    stage: "later",
    title: "More languages",
    body: "eWiz in the most-requested languages first.",
  },
];
