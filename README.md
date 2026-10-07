<div align="center">

# eWiz

**Make macOS stop wrecking your battery.**

Charge limiting, heat-aware charging, sleep-safe enforcement, and one-tap save
modes — all from your menu bar, built for Apple Silicon.

<a href="https://ewiz.app"><b>Website</b></a> ·
<a href="https://ewiz.app/buy"><b>Buy</b></a> ·
<a href="https://github.com/stroke-app/ewiz/releases"><b>Releases</b></a> ·
<a href="https://github.com/stroke-app/ewiz/issues"><b>Feedback</b></a>

![Platform](https://img.shields.io/badge/macOS-14%2B-blue)
![Arch](https://img.shields.io/badge/Apple%20Silicon-arm64-black)
![Price](https://img.shields.io/badge/price-%242.99-green)
![License](https://img.shields.io/badge/license-eWiz%20License-lightgrey)

</div>

## Why eWiz exists

Lithium batteries wear out fastest when they sit at a high charge and when they
run hot. macOS does both by default: it keeps you topped up at 100% and lets the
machine cook while it's docked and closed. Apple's own "Optimized Charging" tries
to help, but it's a black box — it decides when to hold at 80%, and you can't.

eWiz hands you the controls directly. Pick a charge ceiling and it holds
there. Tell it to stop charging when the battery gets warm and it will. It's a
small menu-bar app that does one thing well, and it stays out of your way the rest
of the time.

## What it does

**Charging & longevity**

- **Charge limit** — cap charging anywhere from 50–100%. eWiz holds the level
  with a hysteresis band so it isn't flicking the charger on and off at the
  threshold. It speaks both Apple Silicon SMC schemes (legacy `CH0B`/`CH0C` and
  the newer `CHTE` on macOS 26 "Tahoe").
- **Heat-aware charging** — pause charging when the battery climbs past a
  temperature you set, then resume once it cools. The menu tells you *why* charging
  is paused, so it never looks broken.
- **Discharge to the limit** — on Macs that support adapter control, if you plug in
  above your limit eWiz can run off the battery until it drifts back down,
  instead of just waiting.
- **Charge to 100% once** — one tap temporarily lifts the limit for a full charge
  (handy before a trip), then reverts itself the moment the battery is full. Good
  for the occasional full cycle a battery actually likes.

**Sleep-safe enforcement**

The catch with any charge limiter: the enforcer can't run while the Mac is asleep,
so a naive limiter lets macOS quietly charge to 100% overnight. eWiz closes
that gap two ways, and you choose which:

- **Stop charging before sleep** — cuts charging as the machine goes to sleep, so
  it can't top up past your limit while nothing's watching.
- **Prevent idle sleep while plugged in** — holds a power assertion (only on wall
  power, never on battery) so the limit stays continuously enforced.

**MagSafe LED**

- Drive the MagSafe LED from the actual charge state: **orange** while charging,
  **green** when it's holding at your limit, and **off** briefly right after wake
  while charging settles. Or force it **off**, or hand it back to macOS — three
  modes, your call. Only shows up on Macs that have a controllable LED.

**Sealed Sleep — a closed lid that costs nothing**

A closed Mac isn't off. Memory stays powered for as long as the lid is shut, and
macOS wakes the machine on a timer to run maintenance, check the network, and answer
Find My. Each wake is seconds; over a weekend they're the difference between the
number you closed on and a number you didn't expect.

- **One switch** powers memory down to disk (`hibernatemode 25`) and turns off every
  wake source behind it — Power Nap, wake-for-network, TCP keep-alive, terminal
  sessions — plus Wi-Fi and Bluetooth as the lid actually closes.
- **A checklist, not a claim.** Nine named causes of closed-lid drain, each shown as
  sealed or still costing you something. Two of them eWiz won't decide for you:
  Find My can't reach a sealed Mac, and a keep-awake you deliberately turned on stays
  turned on until you say otherwise.
- **Measured, not estimated.** The charge is read when the lid shuts and again when it
  opens, so the panel reports what the last close actually cost, per hour and per night.
- **Reversible.** Every setting it displaces is snapshotted going in and written back
  when you switch it off.

The cost is honest and it's the reason this is a switch rather than a default: opening
the lid takes fifteen to thirty seconds while memory is read back from disk.

**Save modes**

- **One-tap Save Modes** — *Off / Normal / Super Saver* flip a whole bundle of
  settings at once instead of hunting through toggles.
- **Sleep & Idle controls** — Power Nap, wake-for-network, and TCP keep-alive are
  the settings that silently wake your Mac in a bag. Turn them off from one place.

**Automation rules**

Rules that read "while *this* is true, do *that*" — and undo it the moment it stops
being true. Build one from any mix of twelve conditions:

- an **external display** is connected (or two, or three)
- a **USB device** or a connected **Bluetooth device** — by name, or any at all
- an **app is running**, or running *and frontmost*
- the battery is **charging**, or **above a level** you set
- the **power adapter** is connected
- your Mac has a given **IP address** (a trailing dot matches a whole subnet)
- you're on a specific **Wi-Fi network**, or connected to a **VPN**
- **headphones or another audio output** is in use
- a **drive or volume** is mounted
- **CPU usage** is above a threshold

Match all of them or any of them, and invert any single condition. While a rule
holds it can switch save mode, set (or lift) the charge limit, hold charging, keep
the Mac awake, turn on Low Power Mode, or dial charge power down.

Rules put your setting back when they stop matching — and if you changed that
setting yourself in the meantime, the rule leaves it alone rather than overruling
you. The Automation tab shows a live readout of everything it can see, so you can
fill a condition in with the exact name of the drive, dock, or network in front of
you, and any rule that's currently holding is listed in the menu, so an automatic
change is never a mystery.

**Insight & convenience**

- **Battery Health** card with the numbers that matter (cycle count, capacity,
  temperature) and plain-language tips.
- **Usage history** charts, plus a per-close readout of how much charge a closed-lid
  session actually cost you — exportable as CSV (samples, daily summary, lid sessions).
- **Power adapter card** showing what's actually feeding the Mac: negotiated wattage,
  voltage and current, and the adapter's own maximum. If your adapter can give more
  than the Mac negotiated, it tells you — that gap is nearly always the cable.
- **Menu bar, your way** — icon only, percentage, time remaining, or both.
- **Lid / clamshell sensor** that warns you when you're docked-and-closed at a high
  charge — the worst-case aging scenario.
- **Quick Actions** — dim or brighten the display, blank it, or sleep the Mac.
- **Keep Awake (Caffeine)** — one tap stops the display from turning off and the Mac
  from idle-sleeping, on battery or plugged in, until you turn it back off (or a timer
  you set runs out). Closing the lid still sleeps, and it releases the moment you quit
  eWiz — so it can never strand your Mac awake.
- **Global keyboard shortcuts** for the things you reach for most — Caffeine, Low Power
  Mode, the charge limit (on/off, or up and down in 5% steps), pause/resume charging,
  cycle save mode, dim the display, and more. Every one is remappable in
  *Settings → Shortcuts*, defaults sit on ⌃⌥⌘, and anything disruptive (sleep, force
  discharge) ships unbound. No Accessibility permission needed: eWiz claims only
  the combinations you assign and never sees anything else you type.
- **Launch at login** and **in-app auto-update**, and it'll tell you if the helper
  ever falls out of date so features don't silently stop working.

## How it works

Writing SMC keys needs root, but you don't want a GUI running as root. So eWiz
splits in two:

- A **menu-bar app** that runs as you and never touches the SMC directly.
- A tiny **root helper** (`ewiz-helper`), installed once as a LaunchDaemon. It
  owns the enforcement loop, auto-starts at every boot, and talks to the app over a
  local socket.

If the helper is ever stopped or killed, it re-enables charging on the way out — so
eWiz can never leave your Mac unable to charge.

## Performance

eWiz is a native Swift app, and it's built to be a quiet background citizen:

- **Event-driven, not busy.** Charge and power-source changes arrive as IOKit
  notifications; the fallback timers are slow and declare scheduling *tolerance*, so
  macOS batches their wake-ups with other work instead of spinning up the CPU on a
  fixed beat. Expensive things (like listing energy-hungry processes) only run while
  you're actually looking at them.
- **Menu-bar only.** No Dock icon, no window kept alive in the background — the UI
  is built on demand when you open the menu.
- **Small, lean builds.** Release binaries are size-optimized and symbol-stripped,
  and the root helper is a minimal daemon with no UI at all.

A note on memory, since people ask: a native Cocoa/SwiftUI app's "Memory" figure in
Activity Monitor is dominated by *shared* system framework pages that every app
counts — it isn't private cost. The honest metric for a battery tool is **energy
impact and wake-ups**, and eWiz is tuned to keep both low. It won't fit in a few
megabytes (no framework-linked app does), but it also won't sit there draining you.

## Install

### Homebrew (recommended)

```bash
brew tap stroke-app/ewiz
brew install --cask ewiz
```

Homebrew asks you to **trust** the tap the first time (its gate for any
third-party tap) — accept, or run `brew trust stroke-app/ewiz`. The cask
clears the download quarantine on install, so the app launches straight away even
though it isn't notarized yet.

Update later with `brew upgrade --cask ewiz`.

### Manual (DMG)

1. Download the latest `eWiz-x.y.z.dmg` from
   [Releases](https://github.com/stroke-app/ewiz/releases) and drag
   **eWiz** into Applications.
2. Because the build isn't notarized yet, macOS may say it's "damaged" — it isn't.
   Clear the quarantine flag once:
   ```bash
   sudo xattr -r -d com.apple.quarantine /Applications/eWiz.app
   ```
   (Homebrew does this for you; only needed for the manual DMG.)

Then, either way:

3. Launch it — it lives in the menu bar, not the Dock. (It's a background app, so
   opening it again just brings the menu-bar item to attention — it won't open a
   window.)
4. Click **Install Helper** in the menu (one password prompt). The helper is a
   LaunchDaemon, so it starts at boot and keeps running on its own.
5. Updates install themselves: **Update** in the menu downloads the new version,
   replaces the app in place, and relaunches it.

### Recommended: turn off macOS's own charge management

For eWiz's limit to behave predictably, disable Apple's competing feature:

- **System Settings → Battery → Battery Health → ⓘ → turn off "Optimized Battery
  Charging."**
- On **macOS 26.4+**, also turn off the built-in **Charge Limit** there.

## Pricing

**Free for 30 days.** Your free days are only spent on days you *actually use*
eWiz, so you get the full month of real use without a countdown breathing down
your neck.

**$2.99 to own.** One-time payment (plus tax) — no subscription, no add-ons. Pay
with **Apple Pay** in a couple of taps, in-app or
[on ewiz.app](https://ewiz.app/buy).

## Build from source

Requires the Swift toolchain (Xcode or the Command Line Tools), macOS 14+, and an
Apple Silicon Mac.

```bash
swift build
swift run eWiz                 # run the menu-bar app
sudo ./scripts/install-helper.sh   # install the root helper daemon

./scripts/package-app.sh 0.8.1     # build eWiz.app
./scripts/make-dmg.sh 0.8.1        # build the DMG

./scripts/test.sh                  # run unit tests + benchmarks (swift-testing)
```

`scripts/test.sh` wraps `swift test`; on machines with only the Command Line Tools
it adds the swift-testing framework search paths automatically. CI runs it on every
push and pull request.

See [`DISTRIBUTION.md`](DISTRIBUTION.md) for signing, notarization, the GitHub
Actions release pipeline, licensing on ewiz.app, and the auto-update feed.

## Contributing & releases

This repo uses [Changesets](https://github.com/changesets/changesets):

```bash
npm install
npm run changeset      # describe your change (patch / minor / major)
```

Commit the generated `.changeset/*.md`. Merging the auto-opened "Version Packages"
PR bumps the version and `CHANGELOG.md`; pushing that version tag triggers the
release build.

The app and helper speak a small versioned protocol over their socket. When you
change what the daemon does, bump `ControlProtocol.version` — the app compares it to
the running helper and warns when the installed helper is out of date, and you'll
need to reinstall it (`sudo ./scripts/install-helper.sh`) for the change to take
effect.

## License

eWiz is **source-available** under the [eWiz License](LICENSE), modelled on the
[MMF License](https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
Mac Mouse Fix uses. In short: do whatever you like with the source. If you publish an
app built from it, it must say it's derived from eWiz, carry no malware, and keep
eWiz's licensing, trial and payment systems intact and paying the author — unless
yours is a substantially new work. Buying eWiz buys a license key for the app; the
source terms are the same for everyone.

## Credits

Charge-control SMC keys and MagSafe LED behavior were learned from
[batt](https://github.com/charlie0129/batt) and
[battery](https://github.com/actuallymentor/battery). Thanks to those projects.
