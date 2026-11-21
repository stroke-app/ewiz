import { createFileRoute, Link } from "@tanstack/react-router";
import {
  BatteryChargingIcon,
  CalendarClockIcon,
  CircleCheckIcon,
  InfoIcon,
  KeyboardIcon,
  LightbulbIcon,
  MoonIcon,
  SettingsIcon,
  WandSparklesIcon,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { breadcrumbSchema } from "#/components/seo/json-ld";
import { Container, SitePage } from "#/components/site/site-shell";
import { seo } from "#/lib/seo";
import { cn } from "#/lib/utils";

export const Route = createFileRoute("/features")({
  head: () => ({
    ...seo({
      title: "Features",
      description:
        "Every eWiz setting explained in plain language: charge limits, schedules, automation rules, Sealed Sleep, keyboard shortcuts and the menu bar.",
      path: "/features",
      keywords: [
        "eWiz features",
        "eWiz settings",
        "mac charge limit",
        "mac battery settings explained",
      ],
      jsonLd: [breadcrumbSchema([{ name: "Features", path: "/features" }])],
    }),
  }),
  component: FeaturesPage,
});

type Note = { kind: "default" | "tip"; text: string };

interface Feature {
  /** The label as it reads in the app. */
  name: string;
  body: string;
  note?: Note;
}

interface Group {
  /** The small uppercase heading above the rows in the Settings window. */
  title: string;
  features: Feature[];
}

interface Section {
  /** The app deep-links to /features#<id>, so these must not change. */
  id: string;
  title: string;
  icon: LucideIcon;
  intro: string;
  groups: Group[];
}

const SECTIONS: Section[] = [
  {
    id: "charging",
    title: "Charging",
    icon: BatteryChargingIcon,
    intro:
      "How and when your battery charges, so it spends less time full and hot, the two things that wear it out fastest.",
    groups: [
      {
        title: "Long-term care",
        features: [
          {
            name: "Park the battery near 60%",
            body: "eWiz charges up to 60% or runs down to it, then keeps it there while your Mac runs on the charger. A battery stored around the middle ages much more slowly than one kept full.",
            note: {
              kind: "tip",
              text: "You give up the top 40% day to day, so turn it off the day before a trip. Only shown on Macs where eWiz can run the Mac from the battery while plugged in.",
            },
          },
        ],
      },
      {
        title: "Hold",
        features: [
          {
            name: "Don't charge while plugged in",
            body: "Stops charging and runs your Mac straight from the wall, leaving the battery at whatever level it is now, whatever your limit says.",
            note: {
              kind: "tip",
              text: "Handy for a long day at a desk. On some Macs, macOS can only hold at certain levels, so the app says which and may charge up to the next one first.",
            },
          },
        ],
      },
      {
        title: "Enforcement",
        features: [
          {
            name: "Stop charging before sleep",
            body: "eWiz can't watch the battery while the Mac is asleep, so this switches charging off as it goes to sleep. That way it can't quietly fill up to 100% overnight.",
            note: {
              kind: "tip",
              text: "With a charge limit set this already happens, so you only need the switch if you want it without a limit too.",
            },
          },
          {
            name: "Prevent idle sleep while plugged in",
            body: "Keeps the Mac awake while it's on the charger, so eWiz is always there to hold your limit. It never applies on battery.",
          },
          {
            name: "Always Active (keep awake with lid closed)",
            body: "Lets work carry on with the lid shut: a download, a backup, a long export. By default it only does this while the charger is connected.",
          },
          {
            name: "Turn off automatically",
            body: "Ends Always Active after 30 minutes up to 8 hours, or never. The timer still runs out on time even if the Mac is asleep or eWiz isn't open.",
          },
          {
            name: "Scheduled hours",
            body: "Appears once you've set Always Active hours on the Schedule tab. Outside those hours the Mac sleeps as usual.",
          },
          {
            name: "Also keep awake on battery",
            body: "Keeps the Mac running with the lid shut even when unplugged. It drains the battery quickly and can run warm in a bag.",
            note: {
              kind: "tip",
              text: "If you turn this on, also turn on Sleep if it gets too hot.",
            },
          },
          {
            name: "Only while a task is running",
            body: "Stays awake only while an app or process you name is running, then lets the Mac sleep. Type names like ffmpeg or rsync, or use Choose… to pick from what's running now.",
          },
          {
            name: "Or any process above",
            body: "Also stays awake while anything is busy using more than the share of the processor you set. Set it to Off to rely on names alone.",
          },
          {
            name: "Sleep when the task finishes",
            body: "Puts the Mac to sleep as soon as the task stops, instead of waiting for it to sit idle.",
          },
          {
            name: "Sleep if it gets too hot",
            body: "Lets go of keep-awake and puts the Mac to sleep if it passes a temperature you choose, between 35 and 55 °C.",
            note: { kind: "default", text: "40 °C, which is where it starts when you turn it on." },
          },
        ],
      },
      {
        title: "Heat",
        features: [
          {
            name: "Pause charging when hot",
            body: "Charging a warm battery wears it faster. This pauses charging while the battery is above the temperature you set (30 to 45 °C) and resumes once it cools. The menu tells you when this is why charging stopped.",
            note: { kind: "default", text: "On, at around 35 °C (where the setting starts)." },
          },
        ],
      },
      {
        title: "Discharge",
        features: [
          {
            name: "Discharge to limit",
            body: "If you plug in while the battery is above your limit, eWiz runs the Mac from the battery until it drops back down, instead of waiting for you to use it up. Only shown on Macs that support it.",
          },
        ],
      },
      {
        title: "MagSafe LED",
        features: [
          {
            name: "MagSafe LED behaviour",
            body: "MagSafe is the magnetic charging plug on newer MacBooks, with a small light on it. Auto leaves the light to macOS. Status shows orange while charging, green while holding at your limit, and goes dark briefly after waking. Off keeps it dark.",
            note: {
              kind: "tip",
              text: "Status is the most useful: green means eWiz is holding your limit. Only shown on Macs with a MagSafe light eWiz can control.",
            },
          },
        ],
      },
    ],
  },
  {
    id: "schedule",
    title: "Schedule",
    icon: CalendarClockIcon,
    intro: "Timetables, for when you want charging or keep-awake to follow your week on its own.",
    groups: [
      {
        title: "Charging schedules",
        features: [
          {
            name: "Add Schedule",
            body: "Each schedule picks a time window and the days of the week, and does one thing during it: Charge, Hold (don't charge), or Run on battery. Switch any schedule off without deleting it.",
            note: {
              kind: "tip",
              text: "A Hold schedule during working hours keeps the battery steady while you're docked.",
            },
          },
        ],
      },
      {
        title: "Always Active hours",
        features: [
          {
            name: "Add Hours",
            body: "Set hours when Always Active keeps the Mac awake with the lid closed, for example overnight backups. Outside them the Mac sleeps normally. They only take effect while Always Active is switched on.",
          },
        ],
      },
      {
        title: "Ready by",
        features: [
          {
            name: "Charge to a target by a set time",
            body: "Holds the battery overnight instead of filling it, then tops it up so it reaches your target (50 to 100%) by the time you choose, on the days you pick.",
            note: {
              kind: "tip",
              text: "Set it to when you usually leave, so you get a full battery without it sitting full all night.",
            },
          },
        ],
      },
      {
        title: "Charge power",
        features: [
          {
            name: "Power to the battery",
            body: "Chooses how much of the charger's power goes into the battery rather than running your Mac. Lower charges slower and cooler, and 0% holds the battery where it is. A live readout shows where the watts are going.",
            note: {
              kind: "tip",
              text: "Some Macs and macOS versions don't let apps control charging speed. The app says so when that's the case, and your charge limit still works.",
            },
          },
        ],
      },
    ],
  },
  {
    id: "automation",
    title: "Automation",
    icon: WandSparklesIcon,
    intro:
      "Rules that change a setting while something is true, and put it back when it stops being true.",
    groups: [
      {
        title: "Rules",
        features: [
          {
            name: "Add Rule",
            body: "A rule reads “while this is true, do that”. It can watch for a connected display, a USB or Bluetooth device, an app running (or in front), the battery charging or above a level, the charger, an IP address, a Wi-Fi network, a VPN, headphones or another audio output, a mounted drive, or a busy processor.",
          },
          {
            name: "What a rule can do",
            body: "While it matches, a rule can switch save mode, set the charge limit, hold charging, keep the Mac awake, turn on Low Power Mode or lower charge power. Match all conditions or any of them, and flip any single one to mean “not”.",
            note: {
              kind: "tip",
              text: "If you change that setting yourself while a rule holds, the rule leaves your choice alone when it ends.",
            },
          },
          {
            name: "Start from an example",
            body: "Ready-made rules to adjust: Docked at a display (limit 80%), Heavy app: charge to full, Long build: stay awake, and On a specific Wi-Fi network.",
          },
        ],
      },
      {
        title: "Permission needed",
        features: [
          {
            name: "Grant Location Access…",
            body: "macOS treats the name of your Wi-Fi network as location data. This only appears if a rule matches on Wi-Fi, and asks macOS to let eWiz read the network name.",
          },
        ],
      },
      {
        title: "Right now",
        features: [
          {
            name: "Live readout",
            body: "Shows what eWiz can see at this moment: displays, devices, network, drives and so on. Use it to copy the exact name of your dock or network into a rule.",
          },
        ],
      },
      {
        title: "AI Agents",
        features: [
          {
            name: "Let AI agents use eWiz",
            body: "AI apps such as Claude and Cursor can connect to eWiz to keep your Mac awake during a long build, test run or download, on a timer that ends by itself, and to read battery and power status. They connect through MCP, a standard way for AI apps to use tools on your Mac.",
            note: {
              kind: "tip",
              text: "If you don't use AI coding tools, you can ignore this whole group.",
            },
          },
          {
            name: "Allow it with the lid closed",
            body: "Lets an agent turn on Always Active, so work continues with the lid shut until the agent's timer runs out.",
          },
          {
            name: "Allow it to change power settings",
            body: "Lets an agent change Low Power Mode, the charge limit, charging pause, the save mode and the sleep features.",
          },
          {
            name: "Tell agents when the battery runs low",
            body: "Claude Code is told when the Mac is unplugged and running low, so it can save and wrap up. Pick the level under Warn at; a final warning follows at a lower level.",
          },
          {
            name: "Connect",
            body: "Adds eWiz to supported AI apps in one click, or copies the command or settings to paste into other apps. The group also lists any agent currently keeping the Mac awake.",
          },
        ],
      },
    ],
  },
  {
    id: "sleep-power",
    title: "Sleep & Power",
    icon: MoonIcon,
    intro:
      "What your Mac does when the lid closes or you step away, and the switches that quietly drain the battery while it sleeps.",
    groups: [
      {
        title: "Sealed Sleep",
        features: [
          {
            name: "Sealed Sleep",
            body: "A closed Mac isn't really off: macOS keeps waking it for maintenance, the network and Find My, and each wake costs a little battery. Sealed Sleep turns all of that off in one switch, so nothing wakes the Mac until you open the lid. A checklist shows each cause of drain and whether it's sealed.",
            note: {
              kind: "tip",
              text: "Find My can't reach the Mac while the lid is shut. Turning Sealed Sleep off puts every setting back how it was.",
            },
          },
          {
            name: "Wake instantly",
            body: "Keeps memory powered so the Mac wakes right away when you open the lid. Turned off, memory is saved to disk instead, which costs nothing while closed but takes 15 to 30 seconds to wake.",
            note: { kind: "default", text: "On." },
          },
          {
            name: "Then hibernate after",
            body: "With instant wake on, saves memory to disk and powers it down once the lid has been shut this long (5 minutes to 3 hours). Short closes still wake instantly, and long ones cost nothing.",
            note: {
              kind: "tip",
              text: "Never keeps memory powered the whole time, which costs about 3% a day.",
            },
          },
        ],
      },
      {
        title: "Work with the lid closed",
        features: [
          {
            name: "Clamshell mode",
            body: "Clamshell means using a MacBook with its lid shut, usually with an external display. Turn this on and the Mac keeps running when you close the lid; only the built-in screen goes dark.",
          },
          {
            name: "Keep going on battery",
            body: "Keeps clamshell mode running after you unplug. Turn it off to let the Mac sleep as soon as the charger comes out.",
            note: {
              kind: "default",
              text: "On. A shut Mac on battery drains fast, so set a temperature cutoff under Charging.",
            },
          },
        ],
      },
      {
        title: "When the lid closes",
        features: [
          {
            name: "Turn off Wi-Fi / Turn off Bluetooth",
            body: "Switches Wi-Fi or Bluetooth off when you close the lid, so they can't keep the Mac busy in your bag.",
          },
          {
            name: "Switch off",
            body: "How long to wait after the lid closes before switching them off. Open the lid again within that time and nothing changes.",
          },
          {
            name: "Restore Wi-Fi & Bluetooth on wake",
            body: "Turns them back on when you open the lid. While Sealed Sleep is on, it looks after these for you.",
          },
        ],
      },
      {
        title: "Rest without closing the lid",
        features: [
          {
            name: "Rest Now",
            body: "Turns off the screen and keyboard light and applies the settings below, without shutting the lid. Touch anything to come back.",
          },
          {
            name: "Rest automatically when I'm away",
            body: "Rests on its own after no input for a while (5 to 120 minutes). It holds off during calls, films and games.",
          },
          {
            name: "Then sleep after",
            body: "Puts the Mac fully to sleep once it has rested this much longer, or Never.",
          },
          {
            name: "Low Power Mode while resting",
            body: "Turns on Low Power Mode while resting and puts it back when you return.",
          },
          {
            name: "Wi-Fi and Bluetooth off while resting",
            body: "Switches both off while resting.",
            note: {
              kind: "default",
              text: "Off, because losing the network mid-call costs more than it saves.",
            },
          },
        ],
      },
      {
        title: "Caffeine (keep awake now)",
        features: [
          {
            name: "Caffeine",
            body: "Stops the screen and the Mac from going to sleep until you turn it off, or until a timer runs out. You switch it on from the menu bar; this group sets how it behaves. Closing the lid still sleeps the Mac.",
          },
          {
            name: "End it when I unplug",
            body: "Turns Caffeine off the moment you switch to battery.",
          },
          {
            name: "Keep the screen on when on battery",
            body: "When off, the screen can sleep and lock on battery while your tasks keep running, which saves a fair bit of power.",
            note: { kind: "default", text: "On." },
          },
        ],
      },
      {
        title: "On Battery",
        features: [
          {
            name: "Slightly dim the display on battery",
            body: "Lowers brightness a little when you unplug, to stretch battery life.",
          },
        ],
      },
      {
        title: "Wake while closed",
        features: [
          {
            name: "Power Nap",
            body: "Wakes the Mac now and then while closed to sync Mail and iCloud.",
          },
          {
            name: "Wake for network access",
            body: "Lets other devices on your network wake this Mac, for example to reach a shared folder.",
          },
          {
            name: "Keep network alive in sleep",
            body: "Keeps Find My and notifications working while the Mac sleeps.",
          },
          {
            name: "Wake when a nearby device is close",
            body: "Lets a nearby iPhone or Apple Watch wake the Mac, which can happen over and over in a bag.",
          },
          {
            name: "Stay awake for terminal sessions",
            body: "Keeps the Mac fully awake while any Terminal or remote login session is open.",
          },
        ],
      },
      {
        title: "Power",
        features: [
          {
            name: "Low Power Mode",
            body: "The macOS Low Power Mode: the Mac runs a little slower and uses less energy. On Macs with a ProMotion (120 Hz) screen it also lowers how often the screen refreshes.",
          },
        ],
      },
      {
        title: "Network profiles",
        features: [
          {
            name: "Switch mode by Wi-Fi network",
            body: "Picks a save mode automatically based on the Wi-Fi network you join. Use Add current network, then choose a mode for it, such as Super Saver at a café and Normal at home. Needs Location access, like the Wi-Fi rules.",
          },
        ],
      },
    ],
  },
  {
    id: "shortcuts",
    title: "Shortcuts",
    icon: KeyboardIcon,
    intro: "Keyboard shortcuts that work from any app, for the things you reach for most.",
    groups: [
      {
        title: "Global Shortcuts",
        features: [
          {
            name: "Enable keyboard shortcuts",
            body: "Turns the shortcuts on. eWiz only listens for the key combinations listed here, never anything else you type, so it doesn't need Accessibility permission.",
          },
          {
            name: "Recording a shortcut",
            body: "Click the box next to an action and press the keys you want. Delete (⌫) removes a shortcut and Escape (⎋) cancels. If you reuse a combination, the app tells you which action lost it.",
            note: {
              kind: "tip",
              text: "Include Control (⌃) or Option (⌥). A combination of only ⌘ and ⇧ takes that shortcut away from every other app, and the app warns you when that happens.",
            },
          },
          {
            name: "Reset to Defaults",
            body: "Puts every shortcut back. Defaults use ⌃⌥⌘, and disruptive actions like Sleep now start without a shortcut.",
          },
        ],
      },
      {
        title: "Charging",
        features: [
          {
            name: "Charging shortcuts",
            body: "Toggle the charge limit, raise or lower it in 5% steps, pause or resume charging, cycle save mode (Off, Normal, Super Saver), toggle Low Power Mode, force discharge, or don't-charge.",
          },
        ],
      },
      {
        title: "Sleep & Display",
        features: [
          {
            name: "Sleep and display shortcuts",
            body: "Toggle Caffeine or Always Active, dim or restore the display, nudge brightness up or down by 10%, turn the display off, rest or wake the Mac, or put it to sleep now.",
          },
        ],
      },
      {
        title: "Wi-Fi & Bluetooth",
        features: [
          {
            name: "Toggle Wi-Fi / Toggle Bluetooth",
            body: "Turn either one on or off.",
          },
        ],
      },
      {
        title: "Windows",
        features: [
          {
            name: "Window shortcuts",
            body: "Open Settings, Battery Details or Battery History, or switch to the next menu bar icon style.",
          },
        ],
      },
    ],
  },
  {
    id: "general",
    title: "General",
    icon: SettingsIcon,
    intro: "The helper that makes it all work, plus how eWiz looks, sounds and starts up.",
    groups: [
      {
        title: "Helper",
        features: [
          {
            name: "Install Helper…",
            body: "The helper is a small background part of eWiz that has permission to change charging and sleep settings, which a normal app can't. You install it once with your Mac password; after that it starts with the Mac and keeps itself up to date.",
            note: {
              kind: "tip",
              text: "If charging settings look greyed out or stop working, check here. If it says “Update required”, click Reinstall Helper…, and use Uninstall… to remove it.",
            },
          },
        ],
      },
      {
        title: "Menu Bar",
        features: [
          {
            name: "Battery style",
            body: "Choose how the battery looks in the menu bar from twelve styles, from Classic to Ring and Dial. The fill always matches your exact charge.",
          },
          {
            name: "Show",
            body: "Show the icon only, the percentage, the time remaining, or both. Time remaining means time to full while charging and time to empty on battery.",
          },
          {
            name: "Color icon by charge state",
            body: "Turns the icon green while charging and red when the battery is low or warm.",
            note: { kind: "default", text: "On." },
          },
          {
            name: "Animate the icon while charging",
            body: "Adds a charging animation to the icon. It uses a little extra processing power while plugged in.",
          },
          {
            name: "Shake when the battery runs low",
            body: "The icon gives a short shake at 20%, then every 20 seconds below 10%, so you notice before it's too late. Preview shows you what it looks like.",
            note: { kind: "default", text: "On." },
          },
        ],
      },
      {
        title: "Notifications",
        features: [
          {
            name: "Notify me about charge events",
            body: "Sends a notification when the limit is reached, charging pauses for heat, the battery is low, or it's fully charged. Send Test Notification checks they arrive.",
          },
          {
            name: "Suggest an occasional restart",
            body: "Reminds you to restart your Mac once it has been running for a week without one.",
          },
        ],
      },
      {
        title: "Plug-in feedback (experimental)",
        features: [
          {
            name: "Tap the trackpad when you plug in",
            body: "A gentle tap you can feel: two when you plug in, one when you unplug, three when the battery reaches your limit.",
          },
          {
            name: "Play a sound when you plug in",
            body: "A short sound when you plug in and a smaller one when you unplug. Choose from Warm, Glass, Pluck, Blip and Tick, set the volume, and test each one.",
          },
          {
            name: "Animate anyway",
            body: "Only appears if Reduce Motion is on in macOS. eWiz keeps its animations off in that case unless you allow them here.",
          },
        ],
      },
      {
        title: "Startup",
        features: [
          {
            name: "Launch at login",
            body: "Opens eWiz when you log in, so it's always in the menu bar. If macOS asks, approve it in System Settings › General › Login Items.",
            note: { kind: "tip", text: "Keep this on so your settings are always applied." },
          },
        ],
      },
      {
        title: "System",
        features: [
          {
            name: "Lid / Last closed",
            body: "Shows whether the lid is open or closed, and how long ago it was last closed and how much charge that cost.",
          },
        ],
      },
      {
        title: "Updates",
        features: [
          {
            name: "Check for Updates…",
            body: "Looks for a newer version and installs it for you. When one is ready you'll see Update Now and the new version number.",
          },
        ],
      },
    ],
  },
  {
    id: "about",
    title: "About",
    icon: InfoIcon,
    intro: "Your license, and the quickest ways to get help.",
    groups: [
      {
        title: "About",
        features: [
          {
            name: "Activate License / Manage License",
            body: "Enter a license key after the 30-day trial, or manage the one you have.",
          },
          {
            name: "Contact Support / Report a Bug",
            body: "Starts an email or a bug report with your Mac and eWiz details already filled in, so you don't have to look them up.",
          },
          {
            name: "Copy Diagnostics",
            body: "Copies those details to paste wherever you're asking for help.",
          },
        ],
      },
    ],
  },
];

const NOTE_STYLE = {
  default: { icon: CircleCheckIcon, label: "Good default", tone: "text-success" },
  tip: { icon: LightbulbIcon, label: "Tip", tone: "text-warning" },
} as const;

/** The section currently nearest the top of the viewport, for the nav highlight. */
function useActiveSection(ids: string[]) {
  const [active, setActive] = useState(ids[0]);
  useEffect(() => {
    const visible = new Map<string, boolean>();
    const observer = new IntersectionObserver(
      (entries) => {
        for (const e of entries) visible.set(e.target.id, e.isIntersecting);
        const first = ids.find((id) => visible.get(id));
        if (first) setActive(first);
      },
      { rootMargin: "-20% 0px -70% 0px" },
    );
    for (const id of ids) {
      const el = document.getElementById(id);
      if (el) observer.observe(el);
    }
    return () => observer.disconnect();
  }, [ids]);
  return active;
}

const IDS = SECTIONS.map((s) => s.id);

function FeaturesPage() {
  const active = useActiveSection(IDS);
  return (
    <SitePage>
      <Container className="max-w-[68rem] pt-10">
        <div className="max-w-2xl">
          <h1 className="text-3xl font-semibold tracking-tight text-balance sm:text-[2.25rem] sm:leading-[1.15]">
            Every setting, in plain words
          </h1>
          <p className="mt-3 text-lg leading-relaxed text-pretty text-muted-foreground">
            The everyday controls, like the charge limit, save modes and Caffeine, live in the menu
            bar. This page walks through the Settings window tab by tab, so you know what each
            switch does and which ones are worth turning on.
          </p>
        </div>

        <div className="mt-10 lg:grid lg:grid-cols-[11rem_minmax(0,1fr)] lg:gap-14">
          <SectionNav active={active} />
          <div className="max-w-[44rem] min-w-0">
            {SECTIONS.map((s) => (
              <FeatureSection key={s.id} section={s} />
            ))}
            <p className="mt-16 text-[15px] text-muted-foreground">
              Still stuck?{" "}
              <Link
                to="/download"
                className="text-foreground underline underline-offset-4 transition-colors hover:text-primary"
              >
                Get the latest version
              </Link>{" "}
              or use Contact Support in Settings › About.
            </p>
          </div>
        </div>
      </Container>
    </SitePage>
  );
}

function SectionNav({ active }: { active: string }) {
  const listRef = useRef<HTMLUListElement>(null);
  // On phones the chips scroll sideways; keep the current one in view.
  useEffect(() => {
    const list = listRef.current;
    const chip = list?.querySelector('[aria-current="location"]');
    if (!list || !(chip instanceof HTMLElement) || list.scrollWidth <= list.clientWidth) return;
    list.scrollTo({ left: chip.offsetLeft - list.offsetLeft - 16, behavior: "smooth" });
  }, [active]);
  return (
    <nav
      aria-label="Settings tabs"
      className="sticky top-0 z-10 -mx-4 border-b border-border bg-background/90 px-4 py-2 backdrop-blur lg:top-8 lg:mx-0 lg:self-start lg:border-0 lg:bg-transparent lg:p-0 lg:backdrop-blur-none"
    >
      <ul
        ref={listRef}
        className="flex [scrollbar-width:none] gap-2 overflow-x-auto lg:flex-col lg:gap-0.5 lg:overflow-visible"
      >
        {SECTIONS.map(({ id, title, icon: Icon }) => {
          const on = id === active;
          return (
            <li key={id} className="shrink-0">
              <a
                href={`#${id}`}
                aria-current={on ? "location" : undefined}
                className={cn(
                  "flex items-center gap-2 rounded-lg border px-3 py-1 text-sm whitespace-nowrap transition-colors lg:border-transparent lg:px-2.5 lg:py-1.5 lg:text-[15px]",
                  on
                    ? "border-border bg-surface-2 text-foreground"
                    : "border-border text-muted-foreground hover:bg-surface-1 hover:text-foreground",
                )}
              >
                <Icon className="hidden size-4 lg:block" aria-hidden />
                {title}
              </a>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}

function FeatureSection({ section }: { section: Section }) {
  const { id, title, icon: Icon, intro, groups } = section;
  return (
    <section id={id} aria-labelledby={`${id}-title`} className="scroll-mt-20 pt-12 lg:scroll-mt-8">
      <div className="flex items-center gap-2.5">
        <Icon className="size-5 text-muted-foreground" aria-hidden />
        <h2 id={`${id}-title`} className="text-2xl font-semibold tracking-tight">
          {title}
        </h2>
      </div>
      <p className="mt-2 text-lg leading-relaxed text-pretty text-muted-foreground">{intro}</p>

      {groups.map((g) => (
        <div key={g.title} className="mt-8">
          <h3 className="text-sm font-medium text-muted-foreground uppercase">{g.title}</h3>
          <dl className="mt-2 divide-y divide-border border-y border-border">
            {g.features.map((f) => (
              <div key={f.name} className="py-3">
                <dt className="text-[15px] font-medium">{f.name}</dt>
                <dd className="mt-1 text-[15px] leading-relaxed text-pretty text-muted-foreground">
                  {f.body}
                </dd>
                {f.note ? <FeatureNote note={f.note} /> : null}
              </div>
            ))}
          </dl>
        </div>
      ))}
    </section>
  );
}

function FeatureNote({ note }: { note: Note }) {
  const { icon: Icon, label, tone } = NOTE_STYLE[note.kind];
  return (
    <dd className="mt-2 flex gap-2 rounded-lg border border-border bg-surface-1 px-3 py-2 text-sm leading-relaxed text-pretty">
      <Icon className={cn("mt-0.5 size-4 shrink-0", tone)} aria-hidden />
      <span>
        <span className="font-medium">{label}:</span>{" "}
        <span className="text-muted-foreground">{note.text}</span>
      </span>
    </dd>
  );
}
