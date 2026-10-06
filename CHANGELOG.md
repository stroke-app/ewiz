# ewiz

## 0.18.1

### Patch Changes

- c3a7606: **A new icon for eWiz.** A lightning bolt that doubles as a wizard's hat, in the Dock,
  Finder, Settings › About and the license window. About and the license window now show
  the app's real icon instead of a separate battery drawing, so the two can't drift apart.

## 0.18.0

### Minor Changes

- 5bdbb4b: **Always Active** can now switch itself on and off instead of only being held by hand.

  **Always Active hours** (Settings → Schedule) hold the Mac awake on a weekly
  timetable — for example weekdays from 9 AM for 9 hours. While at least one window is
  enabled, the switch means "hold during these hours": inside a window the lid-closed
  hold applies, outside it the Mac sleeps normally, with no need to remember to turn it
  off. Windows may wrap past midnight, so an overnight window belongs to the day it
  starts on. With no windows set the switch behaves exactly as before.

  **Turn off automatically** (Settings → Charging, under Always Active) sets a deadline —
  30 minutes to 8 hours, or "don't turn off". The deadline lives in the root daemon's
  config, so it still fires while the Mac is asleep or eWiz isn't running, and it
  clears the switch rather than leaving an on toggle that no longer holds anything.

  The Always Active section shows which hours are set and whether it is **HOLDING** or
  **WAITING** right now, and the clamshell display saver follows the same verdict — it
  no longer forces the internal display off outside a scheduled window.

- 5bdbb4b: **Caffeine no longer holds the screen awake on battery.**

  Caffeine held a `PreventUserIdleDisplaySleep` assertion — the same one `caffeinate -d`
  takes — for as long as it was on, whatever the power source. Left on and unplugged, that
  kept the display lit on an idle Mac (and, because macOS won't system-sleep while the
  display is on, kept the whole machine up): several watts, or percents of charge per hour,
  from a feature meant to keep work running.

  On battery Caffeine now downgrades the hold to system-only — the same work keeps running,
  but the screen is allowed to sleep — and restores the full hold when you plug back in. The
  session itself never ends, and any timer keeps running; only the reach of the hold changes.
  The replacement assertion is taken before the old one is released, so there's no window
  for the display to sleep during the swap.

  Two new options in **Settings → Sleep & Power → Caffeine**:

  - **End it when I unplug** — stop the session outright on battery, for a Mac that should
    lose no charge at all while left alone.
  - **Keep the screen on when on battery** — the old behaviour, for when the screen genuinely
    has to stay lit.

  The card also shows what Caffeine is holding right now, and until when.

- 5bdbb4b: **The charge limit stays on.** A request that stalled the helper's control socket used
  to block every other one, and the health check then tore the socket down and dropped
  whatever the app had queued. Requests are now served in order with a short read bound,
  and the check asks a question the daemon answers without its lock. The app no longer
  pushes placeholder settings before its first answer from the helper (which could switch
  the limit off), and edits are merged with the helper's current config instead of
  overwriting it with a copy up to 30 seconds old.

  **No more surprise password prompt.** One missed answer from the helper no longer reads
  as "not installed"; the app asks again and only reinstalls after two misses.

  **A menu-bar icon that tells the truth.** A bold bolt while current flows, a pause mark
  while charging is held or paused, nothing on battery or when full, and a check when a
  charge finishes, in every icon style (Pixel gets pixel-art marks). The mark springs in
  when the state changes and drops away on unplug. The panel says "Draining to 80%" above
  the limit rather than "Holding at 80%".

  **Low-battery shake.** The icon trembles at 20%, and every 20 seconds under 10%.
  Settings → General → Menu Bar, with a Preview button.

  **Steadier panel.** Lid mode no longer inserts a row above the tiles, and the line under
  them always takes one line, so pressing a tile never moves the layout.

  **AI agents can keep the Mac awake.** A bundled MCP server lets an agent hold the Mac
  awake for a long task, optionally with the lid closed, on a lease that ends on its own.

  **Cleaner sounds.** Every theme now plays at matched loudness, without clicks, and the
  off-key cues resolve.

  **License and support.** The license window opens centred, asks before removing a
  license, and links to support. Settings → About gains Contact Support, Report a Bug and
  Copy Diagnostics, each filled in with what support needs.

- 5bdbb4b: **Pick the plug-in animation from the menu**, not three windows deep in Settings. Quick
  Actions gains an **Animation** button: switch it on or off, choose the style, and play it
  on the spot to see what it looks like without unplugging anything.

  **Bring your own animation.** A new **Custom** style plays a numbered image sequence from
  `~/Library/Application Support/eWiz/ChargeAnimation` — export frames from Rive, Lottie
  or After Effects and drop them in; Settings has a button that creates and reveals the
  folder and tells you how many frames it found. Frames are read in filename order, capped
  at 120, cached until the folder changes, and scaled to fit while preserving aspect, so a
  square export isn't stretched across a 16:10 display. With no frames present it plays the
  dot grid rather than flashing an empty screen. No third-party runtime, no binary format to
  parse: an image sequence is the one export every motion tool agrees on.

  **The charging animation runs at twice the frame rate.** A six-step sweep at two frames a
  second reads as a slideshow however well it's eased; the tick is 250ms now, so a sweep
  takes about 1.5s instead of 3. It still only runs while plugged in with animation switched
  on, and stops the moment nothing needs it.

  **Two more shortcuts:** rest / wake the Mac (⌃⌥⌘R) and cycle the menu-bar icon style
  (⌃⌥⌘I). The rest shortcut shows its banner _before_ the screen goes dark — a confirmation
  nobody can see is not a confirmation.

- 5bdbb4b: **Fans: monitoring, temperatures, and control where the hardware allows it.**

  Settings › Sleep & Power now lists every fan the way a fan utility should — name (Left side /
  Right side, as the hardware's own tools name them), its minimum, current and maximum rpm with
  the live figure emphasised, and what is driving it — followed by a Temperatures card. Sensors
  are discovered by walking the SMC's own key table rather than a hardcoded list, because the
  keys differ per model and a fixed list is wrong on every Mac it wasn't written for.

  Fan _control_ is offered only where the SMC accepts it. Some Macs read every fan key and
  refuse every write — an M3 Pro on macOS 26 refuses all of them — which is not knowable in
  advance, so eWiz tries once, remembers the answer, and says plainly that the machine
  won't allow it rather than pretending. Where writes are accepted, Custom holds each fan at a
  percentage of its own min…max range (a percentage rather than an rpm figure, because two fans
  in one machine needn't share a range), 0% is each fan's minimum rather than off, control
  returns to macOS above a temperature guard, and the daemon restores auto when it stops.

  Fans reading 0 rpm on a cool Apple silicon Mac is normal, and the UI says so: they stop
  entirely until there is heat to move.

- 5bdbb4b: **Buying, licenses and support move to ewiz.app.** Buy opens ewiz.app/buy, the license
  window links to ewiz.app/license for a lost key or a new Mac, Visit the Website and
  Donate go to ewiz.app, and Contact Support writes to hello@ewiz.app. Every license
  already sold keeps working, and keys issued for eWiz are accepted too.
- 5bdbb4b: Four more menu-bar battery styles, and a charging icon that actually shows charging.

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

- 5bdbb4b: Menu-bar text options, a Power Adapter card, and CSV export for history.

  - **Menu bar display** is now a choice of _Icon only / Percentage / Time remaining / Percentage & time_ instead of a percentage on-off switch. Time remaining shows time to full while charging and time to empty on battery, and falls back to the percentage whenever macOS has no estimate. Existing preferences migrate (percentage off → Icon only).
  - **Power Adapter card** in Battery Details: adapter name, negotiated wattage, supply voltage/current, manufacturer, model, and serial. When the adapter advertises more power than the Mac negotiated, it says so — that gap is almost always the cable.
  - **Export history as CSV** from the History window: samples, daily summary, or lid sessions, for the range currently on screen.

- 5bdbb4b: **The menu panel, rebuilt to look like it belongs in the menu bar.**

  320pt wide with 16pt margins, the geometry the system's own panels use. Rules stop at the
  text margin rather than cutting the panel into bands, row labels sit at the system size,
  and the surface is one flat opaque fill: the `NSVisualEffectView` it used to have sampled
  whatever window was behind it, so the same menu read as near-black over the desktop and as
  washed grey over an editor, and every fill inside it drifted with the background it was a
  percentage of.

  Three defects went with it. The save-mode picker is drawn here now instead of being an
  `NSSegmentedControl`, which arrived as first responder wearing a focus ring no system panel
  draws and sized every segment to its own label. The panel's window is sized to its content,
  because `MenuBarExtra(.window)` grows its window with the content and never shrinks it back
  — the leftover strip was bare, see-through window above the panel. And the window's opaque
  square backing is cleared, so the rounded corners stop having dark right angles tucked
  behind them.

  **Sounds you can choose.** Five voicings of the same three cues: Warm, Glass (a bell's
  inharmonic partials, not an octave stack), Pluck, Blip and Tick, which is transients only
  for anyone who wants to be told without being sung to. The picker plays as you change it.

  **A long close now costs nothing, and a short one still opens instantly.** Apple silicon
  has no `standbydelay`: `hibernatemode` is either 3 (memory powered, instant lid, ~0.1%/h) or
  25 (memory down, nothing to lose, 15–30s to come back). So the delay is implemented instead
  of configured — on the way into a closed-lid sleep on battery the daemon books its own wake,
  and if the Mac is still shut when that wake lands, memory goes off and it re-sleeps into
  hibernation. Tunable under Sealed Sleep, 20 minutes by default.

  **A Lid tile** in the quick actions, in place of Sleep: one press holds caffeine, Always
  Active and the battery permission together, which is the set anyone working with the lid
  shut turns on by hand. Sleep is still on its shortcut.

  Fixed: "prevent idle sleep" was ANDed with the charge limit being on, so Extreme Performance
  — which asks for no idle sleep and deliberately turns the limit off — could never hold the
  assertion, and a Mac left on a long render idled out from under it.

  The plug-in animation is off in this build and marked as coming in the next one. It plays
  over whatever you're doing, so it ships when it's right.

- 5bdbb4b: **Animations were silently doing nothing if Reduce Motion was on.** Every animation in
  the app — the charging icon, the charge-complete flash, the plug-in overlay — was gated
  behind macOS's Reduce Motion, so on a Mac with it enabled, turning "animate the charging
  icon" on had no visible effect whatsoever. Reduce Motion is still respected by default,
  but Settings → Sleep & Power now offers **Animate anyway**, shown only when Reduce Motion
  is actually on, and every animation reads the same resolved answer instead of each one
  checking for itself.

  **The animations were also linear, and linear reads as mechanical.** Nothing physical
  moves at constant velocity. Progress now runs through real easing curves
  (`cubic-bezier(0.23, 1, 0.32, 1)` and friends, solved the same way a browser solves
  `cubic-bezier()`), and the timings came down to where a state change belongs:

  - The charging fill sweeps in 6 steps rather than 8, front-loaded by the ease-out, so it
    surges and settles instead of crawling. The menu-bar tick can't safely go faster — each
    one relayouts the status item — so a shorter cycle is what buys the speed.
  - Connect and disconnect morph in ~220ms (was 630ms and linear), which puts them in the
    same band as a dropdown. Ease-out, never ease-in: withholding motion at the start is
    what makes a short animation still feel slow.
  - The overlay's dot wave has a narrow front (0.3 of the cycle, was 0.6) — at the old
    width most of the screen lit at once and it read as "dots everywhere" rather than a
    ripple crossing it.

  **The menu-bar glyph now reacts to power changes.** Plug in and the bolt grows out of a
  flat spark; unplug and it collapses back into one, both by real shape interpolation.

  **Six more shortcuts:** brightness up and down (⌃⌥⌘] and ⌃⌥⌘[), battery saver (⌃⌥⌘E),
  don't-charge (⌃⌥⌘H), and Wi-Fi and Bluetooth toggles — the last two ship deliberately
  unbound, since cutting Wi-Fi by a mistyped chord is not a surprise worth shipping.

- 5bdbb4b: **Don't charge while plugged in.** A switch that runs the Mac off the adapter and leaves
  the battery exactly where it is — no charging, whatever the level and whatever the limit
  says. It sits above the limit, schedules and ready-by top-ups deliberately: it's the
  switch you reach for when the battery should be left alone, and being second-guessed by
  another setting would defeat it. Only an explicit pause overrides it. On Macs with a
  MagSafe light, the light holds **amber** while it's on, so the state is visible without
  opening anything. Available in the menu, in Settings → Charging, and on ⌃⌥⌘H.

  **Plug-in feedback (experimental).** Two opt-in bits of feedback for the moment the
  adapter connects:

  - **Trackpad taps** — two on connect, one on unplug, three when the charge limit is
    reached. It needs a Force Touch trackpad, and does nothing with the lid shut (the
    trackpad is asleep with it); there's no API to detect the hardware, so Settings says so
    rather than pretending to gate it.
  - **A charging animation** over the screen for about a second: **Dot Grid** (a grid of
    dots ripples out from the port, each dot jittering as the wave passes), **Rings** (rings
    push out with the charge level in the middle), or **Glow** (a soft light rising off the
    bottom edge). The window is click-through, sits on the screen the pointer is on, and is
    torn down afterwards rather than kept around. Duration is capped at 2 seconds — it
    covers the screen, so it has to be over before it becomes something to wait out — and
    Reduce Motion replaces the motion with the level fading in place.

  **Morphing glyphs.** The charging bolt now breathes between a slim and a fat bolt, and
  the charge-complete flash grows that bolt into a checkmark, both via real shape
  interpolation (`PathMorph`: outlines resampled by arc length, closed rings rotated into
  least-travel alignment) rather than cross-fading two glyphs over each other. Covered by
  eight unit tests.

- 5bdbb4b: Removed fan control and Endurance mode.

  **Fan control** is gone. Apple silicon refuses SMC fan writes — it returns success and
  leaves the key reading what it was, which is why the feature spent three releases
  learning to detect its own failure. On the hardware it did work on, it was a fan-speed
  utility bolted to a battery app.

  The one part that stays is the part that can't safely be deleted: forced fan mode lives
  in the SMC and outlives the build that set it, across quit, log-out and restart. The
  helper now hands every forced fan back to macOS once, at startup, and never touches them
  again. A Mac left pinned by an older build fixes itself the first time this version runs.

  **Endurance** is gone too. It dimmed the screen, turned on Low Power Mode, trimmed
  background wake and switched Bluetooth off — overlapping Super Saver on three of four
  levers, and driven by a drain meter whose reading depended more on what you were doing
  than on whether the mode was on.

  Existing configs load unchanged; the settings both features wrote are ignored and
  dropped on the next save.

- 5bdbb4b: **Battlify is now eWiz.** New name, same app: settings, license key, history and the
  charge limit all carry over by themselves.

  On first launch eWiz copies Battlify's settings across, and its helper takes over from
  Battlify's, moving the config, charge history and limit ownership with it. A copy of
  Battlify that updates itself installs eWiz in place, and eWiz then renames its own
  bundle. Homebrew users move across with `brew upgrade`. Licenses sold as Battlify keep
  working.

  macOS treats eWiz as a new app, so it asks once more for notifications and the helper,
  and Launch at Login needs switching on again.

- 5bdbb4b: Add a **"Give your Mac a rest"** reminder. When your Mac has been running for over a
  week, eWiz gently suggests an occasional restart — which clears out memory and
  helps it run cooler — with a one-tap **Restart…** (or **Later** to snooze). The wording
  sharpens when the battery is running warm. It shows as a dismissible banner in the menu
  and, if notifications are on, a notification. Toggle it under Settings › Notifications
  ("Suggest an occasional restart").
- 5bdbb4b: **Rest the Mac without closing the lid.** Closing the lid is the usual way to make a Mac
  stop spending power — screen and keyboard backlight out, the machine quiesced. This does
  the same thing with the lid open, and puts back exactly what it changed when you return.

  - **Rest Now** in the menu's Quick Actions and in Settings → Sleep & Power.
  - **Automatically when you're away**, after 5–120 minutes with no keyboard, mouse or
    trackpad activity anywhere in the session (not just in eWiz). It never rests while
    an external display is connected — that usually means someone is looking at something.
  - Optionally **Low Power Mode while resting**, snapshotted first and restored on wake, so
    it puts back what you had rather than imposing a default.
  - Optionally **Wi-Fi and Bluetooth off**, off by default: losing the network mid-download
    or mid-call costs more than the power it saves. Only radios eWiz switched off are
    switched back on.
  - Optionally **sleep outright** after a further delay, for leaving it overnight lid-up.

  Any input at all ends it. Fans are left alone and the Settings copy says why: Apple
  silicon refuses SMC fan writes, and the fans wind down by themselves once the Mac is
  genuinely idle — which is the thing resting it achieves.

- 5bdbb4b: **Sealed Sleep** — close the lid and the charge stops moving.

  A closed Mac isn't off. Memory stays powered for as long as the lid is shut, and macOS
  wakes the machine on a timer for maintenance, for the network, and to answer Find My.
  Each wake is seconds. Over a weekend they add up to a number nobody expects.

  There is one lever that removes the trickle rather than trimming it: powering memory
  down and writing it to disk. Sealed Sleep pulls that lever (`hibernatemode 25`,
  `standby 1`) and then switches off everything that would hold the Mac up before it can
  get there — Power Nap, wake-for-network, TCP keep-alive, terminal sessions — plus Wi-Fi
  and Bluetooth as the lid actually closes.

  What's new beyond the settings themselves:

  - **A checklist instead of a promise.** Nine named causes of closed-lid drain, each
    shown as sealed or still costing power. Two aren't eWiz's call and say so: Find My
    can't reach a sealed Mac, and a keep-awake you turned on deliberately stays on until
    you release it.
  - **Verified writes.** `pmset` exits 0 for keys a Mac silently ignores, so everything is
    read back and anything refused is named rather than quietly counted as success.
  - **Measured, not projected.** The charge is read at close and again at open, so the
    panel reports what the last closed-lid stretch actually cost, per hour and per night.
  - **Reversible.** Every displaced setting is snapshotted on the way in and written back
    on the way out, including the two radio preferences the app owns.
  - **Held against everything that used to undo it.** A save mode switch, or a Mac that
    drifted after a macOS update, no longer silently unseals it.

  The cost is stated where the switch is, because it applies to every sleep and not just
  the long ones: opening the lid takes fifteen to thirty seconds while memory is read back
  from disk.

  Replaces the **Deep sleep** picker and **Super Save when lid closed** — three controls
  aimed at one outcome, none of them sufficient alone. Anyone who had chosen Deep sleep
  keeps it: that setting migrates to Sealed Sleep on first launch.

### Patch Changes

- 5bdbb4b: **Fixed: the charge limit could be crossed while the Mac slept, charging to full.**

  Enforcement is a tick loop in the root daemon, and that loop is frozen for the whole
  time the Mac is asleep — so whatever the SMC was last told is what stands. Sleep while
  charging below the limit and macOS carries on charging, unsupervised, to 100%.

  Cutting charging on the way into sleep was the protection, but it had two holes. It was
  gated behind the "Stop charging before sleep" option, which is off by default, so a
  limit set by itself wasn't protected at all. And the request came from the app, over the
  control socket, which means it only happened while the app was running — quit eWiz,
  log out, or have it crash, and the protection vanished with no sign that it had.

  The daemon now registers for sleep and wake notifications itself, on its own thread and
  run loop, so the cut happens whether or not anything is running in user space. It
  applies whenever a charge limit is enforced, not only when the option is ticked: the
  limit exists to keep the battery off full, and there is no way to stop at it while
  frozen. Charge still creeps towards the limit across the maintenance wakes macOS takes
  anyway — the tick runs during those and re-enables charging while below the resume
  threshold — and enforcement is re-evaluated the moment the Mac powers back on instead of
  waiting out the tick interval. The app's own pre-sleep request stays, so older app builds
  keep working; both paths are idempotent.

- 5bdbb4b: **Fixed: the app could hang on a helper that looked perfectly healthy.** launchd reported the
  job running, the binary and plist were in place, the process was alive — and every request the
  app made got "connection refused", so the app blocked forever with nothing to show for it.

  The cause was an install race one step further along than the installer guards for: two
  daemons overlap briefly, the second removes the first's socket and binds its own, then the
  second goes away. The survivor is still listening on a socket that no longer has a name.
  Every health signal says fine; nothing can reach it.

  Socket, bind and listen failures are now fatal — a helper with no control channel is worse
  than none, because launchd keeps it and stops trying, whereas exiting gets it restarted with a
  clean bind. The enforcement loop also checks that the socket path still refers to the socket it
  bound, and exits if it doesn't, which is the only way that state is visible from inside the
  process. Startup logs the path it's serving, so diagnosing this is now one line of log.

- 5bdbb4b: The dot-grid charging animation read as a boomerang: three fronts launched diagonally out
  of the port, one after another, which looked like something swinging out and back rather
  than a battery charging.

  It's a dot-matrix charge meter now, closer to what a Nothing phone shows. The whole matrix
  stays faintly lit for the duration — before, only the moving band was drawn, so there was
  no grid to move _through_, just a stripe crossing the screen, which made the motion the
  subject instead of the charge. Dots below your actual charge level are lit brighter, so the
  animation says how full the battery is, and the level appears in monospace in the middle.
  The highlight rises once, from the bottom edge to the fill line, and stops: charging goes
  up, and anything that repeats or reverses reads as a loading spinner.

- 5bdbb4b: **Shortcuts added by an update never reached anyone who had already launched the app.**
  Saved bindings were loaded exactly as stored, so every action introduced after a user's
  first launch arrived unbound — it appeared in Settings › Shortcuts with "Not set" beside it
  and nothing ever shipped it. Defaults are now applied to actions this install has never
  seen, tracked by id, so a shortcut you deliberately cleared stays cleared and nothing gets
  re-seeded on every launch. In practice that means don't-charge (⌃⌥⌘H), brightness
  (⌃⌥⌘] / ⌃⌥⌘[), battery saver (⌃⌥⌘E), rest/wake (⌃⌥⌘R) and cycle icon style (⌃⌥⌘I) turn up
  bound on the next launch, and a combination already assigned to something else is left
  alone.

  **Resting now ends within a couple of seconds of you touching the Mac.** It was checked on
  the same 60-second timer used to notice you'd gone away, so the display woke on the keypress
  while Low Power Mode and the radios stayed held for up to a minute — the Mac felt throttled
  after you'd come back to it. While resting, the check runs every two seconds instead, with a
  four-second grace window at the start so the keystroke that began resting doesn't
  immediately end it.

  **Defensive: two actions sharing one shortcut are repaired on load.** Assigning through the
  recorder moves a taken combination rather than duplicating it, so this shouldn't happen — but
  if a saved file ever holds the same chord twice, Carbon registers exactly one of them and the
  other silently never fires, with nothing in the UI to hint at it. The first action in the
  canonical order keeps the chord and the rest are cleared, because an action that plainly has
  no shortcut can be fixed in Settings while one that looks bound and does nothing cannot even
  be diagnosed.

  **Shortcuts without ⌃ or ⌥ are now flagged.** A global ⌘D or ⇧⌘D is grabbed before every
  other app sees it, so binding one quietly breaks Duplicate, Send and whatever else that chord
  means in the app you're using. Settings › Shortcuts says so next to the binding rather than
  refusing it — it's a legitimate choice, just one worth making on purpose.

- 5bdbb4b: Shortcut banners now show the icon of the action that fired — a bolt for force
  discharge, a coffee cup for keep awake, a gauge for save mode — instead of the app
  icon, which looked identical whatever you pressed. The glyph comes from the same
  catalogue key each row shows in Settings › Shortcuts, so the two can't drift apart.
  Pro-gated actions show a lock, and a missing helper or unsupported hardware shows an
  alert. Messages without a glyph still fall back to the app icon, in the same tile, so
  nothing shifts.

  Shortcut pills read as a keyboard shortcut again. `⌃⌥⌘P` was set solid in a
  monospaced face at 12pt, which collapsed the modifiers into one dense mark; each glyph
  now gets real space, with a slightly wider gap before the key name.

## 0.17.0

### Minor Changes

- 0a3d5ab: Global keyboard shortcuts, with a full remapping UI in Settings › Shortcuts.

  - **15 bindable actions**: toggle the charge limit, raise/lower it in 5% steps, pause/resume charging, cycle save mode, Low Power Mode, force discharge, Caffeine, Always Active, dim/restore the display, display off, sleep now, and open the Settings/Details/History windows.
  - **Remap anything**: click a shortcut, type the new combination. Assigning a combination that's already taken moves it and tells you which action lost it. ⌫ removes a binding, ⎋ cancels, and **Reset to Defaults** restores the shipped set.
  - **Defaults on ⌃⌥⌘** (⌃⌥⌘C for Caffeine, ⌃⌥⌘L for Low Power Mode, ⌃⌥⌘B for the charge limit, …). Sleep, force discharge, display-off, and the Details/History windows ship unbound so nothing disruptive is one stray keystroke away.
  - **Needs no Accessibility permission.** Shortcuts are claimed through `RegisterEventHotKey`, so the window server delivers only the specific combinations Battlify registers — the app never sees anything else you type.
  - A brief **on-screen HUD** confirms what fired, since toggling something invisible like Low Power Mode is otherwise indistinguishable from a shortcut that isn't working. Combinations another app already owns are flagged as "in use" in Settings rather than failing silently, and the menu tooltips now show each action's shortcut.

- Stop the two settings that let a closed Mac stay awake in a bag.

  "Super Save when lid closed" already cut the radios, Low Power Mode, Power Nap, wake-on-network and TCP keep-alive — and restored each one exactly as it was on wake. It missed the only two settings that decide whether the Mac sleeps **at all**:

  - **Wake when a nearby device is close** (`proximitywake`) — an iPhone or Watch nearby wakes the Mac. In a bag that isn't one wake, it's a wake every time your phone stirs, all night.
  - **Stay awake for terminal sessions** (`ttyskeepawake`) — an open terminal or SSH session blocks sleep outright. Lid shut, in a bag, fully awake and warm.

  Both are now switched off by Super Save on lid close, snapshotted first and put back verbatim on wake. Both also appear as their own rows in **Sleep & Power › Wake while closed**, so you can control them independently of lid close.

  Turning radios off saves milliwatts; these two decide whether the machine sleeps in the first place. If your Mac has been coming out of your bag hot and empty, this is almost certainly why.

  For the largest remaining win, set **Sleep & Power › Deep** — powering memory down (`hibernatemode 25`) does more for a Mac left closed for hours than every radio toggle combined.

## 0.16.0

### Minor Changes

- f8eed8d: New **Deep sleep** setting (Sleep & Power) for Macs that stay closed for days.

  macOS normally keeps memory powered while the Mac sleeps so it wakes the instant you open the lid, writing a disk image only as a safety net. Deep sleep powers memory down and restores it from disk instead, which saves the small trickle that keeping memory alive costs over a long sleep. The trade is the wake: opening the lid takes several seconds while memory is read back, instead of being instant — so it's off by default and stays off when you upgrade.

  On Apple silicon `hibernatemode` is the only lever that exists for this; the `standbydelay` knobs Intel Macs had aren't available, so there's nothing else to tune. Writing it needs root, so the root helper applies it — and reports back if pmset refuses.

- 0dd03e5: The menu-bar glyph no longer animates while charging unless you ask it to.

  The animation ticked twice a second, and every tick re-rendered the status item. A status-item relayout is expensive: measured on an M3 Pro, it cost about a tenth of a core continuously, for as long as the Mac was plugged in. Turning it off drops the app to 0% CPU at idle. That is not a trade a battery app should make on your behalf, so it is now a setting in General — off by default, with a static charging bolt instead. The brief flash when charging completes still runs; it lasts about three seconds rather than the whole charge.

- 875aada: The helper stops working while your Mac sleeps.

  It used to run its enforcement loop every 10 seconds regardless. With the lid shut on battery the only moment that loop can run is inside one of the maintenance wakes macOS schedules roughly hourly — and everything it did there (reading its config off disk, walking IOKit for the battery, probing the SMC) was pure cost, holding the chip awake in exactly the window that should end as fast as possible. Measured dark wakes ran 6–45 seconds, so a 10-second loop fired three or four times inside one.

  There was also nothing for it to decide: the charge limit and the heat cap only act while current is flowing in. So it now drops to a 60-second loop once the lid is closed on battery, which leaves a typical maintenance wake seeing at most one pass. Measured cost after the change: 0.03% CPU.

  Anything that genuinely has to react with the lid shut keeps the fast loop — Always Active's task gating, a discharge run, a schedule boundary, a ready-by top-up, a calibration, or a pause that has to expire on time.

## 0.15.0

### Minor Changes

- 3d7be5a: Automation rules: apply a charging or power setting while something is true of your Mac.

  A rule combines any of twelve conditions — external display connected, USB or Bluetooth device connected, an app running (or running and frontmost), battery charging or above a level, power adapter connected, a specific IP address or subnet, a Wi-Fi network, a VPN, headphones/other audio output in use, a drive or volume mounted, or CPU usage above a threshold. Match all or any of them, and invert any single condition.

  While a rule holds it can switch save mode, set or lift the charge limit, hold charging, keep the Mac awake, turn on Low Power Mode, or dial charge power down. When it stops holding, the previous setting comes back — unless you changed that setting yourself in the meantime, in which case your choice stands.

  The new Automation tab in Settings shows a live readout of every condition Battlify can see, so a rule can be filled in with the real name of the dock, drive, or network in front of you, and the menu lists any rule that's currently holding a setting.

### Patch Changes

- 3d7be5a: Cut the menu-bar app's idle CPU by roughly 17× (0.73% → 0.04% on an idle Mac).

  The status item re-lays out on every published change, so republishing values that hadn't actually moved was costing continuous SwiftUI layout work in the background. The battery poll was the main offender: the temperature sensor jitters by hundredths of a degree, so every poll looked like a change. It now rounds to the precision actually displayed and publishes only real changes, skips reading live wattage entirely when no window is showing it, and does two follow-up reads per power event instead of four. The lid/display poll and the automation rule engine got the same treatment.

- 3d7be5a: Settings tabs no longer overflow the window.

  Each tab claimed a fixed 76pt minimum plus padding, so a sixth tab pushed the row past the width of the window — the gaps went uneven and the last tab was clipped by the window edge. Tabs now share the bar equally, with margins at both ends, and the stray focus ring on the selected tab is gone.

## 0.14.0

### Minor Changes

- d30e805: Add **Endurance** — a battery-saver mode that targets ~25% less drain by layering the
  biggest real power levers and restoring everything when turned off:

  - Caps screen brightness (the single largest lever) via DisplayServices — works on
    Apple Silicon and Intel across macOS 12–15.
  - Turns on macOS Low Power Mode.
  - Trims battery-wasteful background wake (Power Nap / wake-on-network / TCP keep-alive)
    and turns Bluetooth off.
  - Prior brightness, Low Power Mode, toggles and Bluetooth are snapshotted on activation
    and restored on exit.

  Activation: a toggle in the menu and in Settings → Sleep & Power, plus optional
  auto-on-battery (on by default) that activates when you unplug and deactivates when you
  plug back in. The brightness cap is adjustable (default 40%).

  **Measured drain meter** proves the effect: it shows live discharge watts and rolling
  averages for normal vs. saver mode, and the measured % reduction — so you can confirm the
  savings rather than trust an estimate (the exact figure is workload-dependent).

- d30e805: Keep-awake improvements and charging-correctness fixes:

  - **Process picker**: pick the apps/processes that keep the Mac awake from a
    searchable list of what's currently running, instead of typing command names by
    hand ("Choose…" next to the process field). Selections are added to the list.
  - **Sleep when the task finishes**: optionally put the Mac to sleep automatically
    once the monitored task stops (debounced ~30s so a gap between a build's
    sub-processes doesn't sleep mid-job), so an overnight build/download finishes and
    then the Mac sleeps.
  - **Fix (Charge Power)**: with charge power below 100%, the duty-cycle rest phase was
    misread as "holding at the limit", so the battery drained to the bottom of the
    recharge band and never cycled back up. Hysteresis is now tracked explicitly and
    independent of the duty cycle.
  - **Fix (heat)**: a failed battery-temperature read no longer silently disables the
    thermal cap; if the sensor has worked before, charging pauses as a precaution.
  - **Fix (legacy SMC)**: charge state now reads both CH0B and CH0C, so a partial write
    that leaves one key allowing charge is retried instead of overshooting the limit.

### Patch Changes

- d30e805: Fix: the charge limit is now held through shutdown and restart. The helper's exit
  cleanup used to re-enable charging on every SIGTERM (which launchd sends on
  shutdown/restart), clearing the SMC charge inhibit. Because that inhibit persists
  while the Mac is powered off but plugged in, the battery would then charge past
  the limit — all the way to full — while the Mac was off. The daemon now leaves the
  inhibit in place on exit whenever limiting is enabled, and only re-enables charging
  when limiting is off. Uninstall re-enables charging after unloading the daemon.

## 0.12.0

### Minor Changes

- 11b112e: Give the UI a premium refresh with **HugeIcons**. A lightweight HugeIcons renderer
  (real stroke icons from `@hugeicons/core-free-icons`, drawn as SwiftUI shapes — no
  runtime dependency) now powers the menu popover and the Settings window (tab bar +
  About). Also shortened the "Display Off" Quick Action to "Off".

## 0.11.0

### Minor Changes

- d506d35: Add **Keep Awake (Caffeine)** mode — a one-tap "never off, never sleeps" toggle.

  A new tile in the menu's Quick Actions keeps the display from turning off and the
  Mac from idle-sleeping, the same thing `caffeinate -d` does.

  - Works on battery _and_ wall power (unlike the AC-gated "Always Active" keep-awake).
  - Needs no root and no helper daemon — it's a user-space `PreventUserIdleDisplaySleep`
    power assertion held by the app, so it works even before the helper is installed.
  - Tap to hold indefinitely, or press-and-hold the tile for a timed session (30 min /
    1 / 2 / 5 hours) that auto-releases.
  - Closing the lid still sleeps the Mac, and the assertion is released the instant
    Battlify quits — so it can never leave the Mac stuck awake.

  Also bootstraps the project's **first automated tests**: a `BattlifyKitTests` suite
  (swift-testing) covering the Caffeine state machine, timer expiry/cancellation, and a
  system-level integration test that asserts the real IOKit power assertion is
  registered and cleared — plus toggle benchmarks. Run with `./scripts/test.sh`; a new
  CI workflow runs them on every push/PR.

- d506d35: Animated menu-bar battery icons.

  - New "Pixel" icon style: a chunky 8-bit battery with notched corners. While
    charging, its fill sweeps from the current level up to full, one column at a
    time — like a classic handheld.
  - Every other style's charging bolt now gently pulses while charging.
  - When charging completes — the battery reaches 100% or lands at your charge
    limit — the icon flashes green a few times (or blinks monochrome when icon
    coloring is off), then settles.
  - Micro-details: animations respect the system Reduce Motion setting, never run
    while discharging (a battery saver shouldn't spend cycles on battery), and the
    driving timer only exists while an animation is actually visible.

### Patch Changes

- d506d35: Fix Always Active leaving the internal display and keyboard backlight on with the lid
  closed. Keeping the Mac awake with the lid shut skips macOS's normal clamshell
  display-off, and the previous one-shot display sleep didn't hold. Battlify now
  re-issues a forced display sleep while the lid is shut and Always Active is holding —
  so the panel and keyboard backlight go dark and stay dark — and it never runs when an
  external display is attached, so a docked monitor is untouched.
- d506d35: Relicense under the PolyForm Noncommercial License 1.0.0. You may use, modify, and
  contribute to Battlify freely for noncommercial purposes; selling it or using it
  commercially (paid products, hosted services, enterprise support) is not permitted. All
  commercial rights are reserved by the author.
- d506d35: Performance: cut needless background wakeups. Live-watts polling now runs only while
  the popover or Details window is open (instead of every 5 seconds for the app's whole
  life), the daemon caches its `pmset` reads longer so periodic status polls stop forking
  processes, and status refreshes only publish state that actually changed. Lower energy
  impact with no change in behaviour.
- d506d35: Fix the helper installer failing intermittently on reinstall/auto-update.

  The install scripts unloaded the LaunchDaemon (`launchctl bootout`) and immediately
  reloaded it (`launchctl bootstrap`). `bootout` is asynchronous, so bootstrapping
  before the old job finished tearing down races and fails with `Bootstrap failed: 5:
Input/output error` — and because the scripts run under `set -e`, that aborted the
  install and made the app report "Install cancelled or failed." This bit the common
  path now that the app auto-reinstalls the helper whenever it's out of date.

  - Wait for the old daemon instance to fully unload before bootstrapping, then retry
    bootstrap while the label frees up (and treat an already-loaded service as
    success, kickstarting it onto the new binary).
  - `launchctl enable` the service before bootstrap, so a service left disabled by a
    prior failed install can still load.
  - Strip the quarantine flag from the installed helper binary, so the (not-yet-
    notarized) daemon isn't killed by Gatekeeper right after install.

  Applies to both the app-bundled installer and `scripts/install-helper.sh`.

- d506d35: Make the app relaunch reliably after an in-app update.

  The post-update relaunch fired a single `open` and assumed it worked. It now
  re-registers the swapped bundle, waits briefly for Launch Services to settle, then
  relaunches with `open -n` and verifies the process actually came up — retrying a
  few times (checking first, so it never spawns a duplicate) and falling back to a
  launch by bundle id. If the app still isn't visible it logs a warning instead of
  silently giving up.

## 0.10.1

### Patch Changes

- 20e83a7: Fix the missing app icon in notifications.

  macOS Notification Center resolves the app icon through a compiled asset catalog
  (`Assets.car` referenced by `CFBundleIconName`), which the bundle didn't include —
  so notification banners showed a blank placeholder even though Finder and the Dock
  looked fine. The build now compiles an asset catalog with `actool` (and only sets
  `CFBundleIconName` when that catalog is actually present, so it never points at a
  missing target). `scripts/make-icon.sh` also emits the catalog source from the SVG
  master.

## 0.10.0

### Minor Changes

- 1d4e145: New app icon.

  A dark, premium "graphite" mark: a near-black squircle with a machined bevel and a
  brushed-metal battery whose three charge bars glow green. Ships as `AppIcon.icns`
  in the bundle (referenced via `CFBundleIconFile`), with the vector master at
  `branding/battlify-icon.svg` and a `scripts/make-icon.sh` to regenerate the iconset.

### Patch Changes

- bcf8b04: Fix save mode / charge settings resetting on their own.

  - **Lid-close deep save** ("Super save on lid close") no longer re-applies a whole save mode on wake. It now restores only what it actually changed — Low Power Mode and the sleep/wake toggles — so your custom charge limit and heat settings survive a lid close/open cycle, and the mode can no longer silently reset to **Off** when it couldn't be read at sleep.
  - **Switch mode by Wi-Fi network** no longer re-applies the mode that's already active (on launch or reconnect), which previously overwrote custom charge-limit/heat tweaks made within that mode.

## 0.9.3

### Patch Changes

- a546cbf: Always Active: optional "Also keep awake on battery".

  "Always Active" still defaults to AC-power-only (it releases when you unplug), but a new opt-in sub-toggle in Settings lets it keep the Mac awake with the lid closed on battery too. Off by default because a closed, unventilated Mac kept awake on battery drains fast and can run hot — the temperature guardrail still applies as a safety net, and the display/keyboard backlight still switch off to save power.

## 0.9.2

### Patch Changes

- 28119c5: Fix force-discharge ("Discharge to limit" / recharge range) not draining the battery.

  Cutting the power adapter to run off the battery makes macOS report the power source as "Battery Power", so the daemon read itself as unplugged on the very next tick, restored the adapter, and oscillated the adapter on/off every ~10s — the battery barely drained and the charge indicators flickered.

  - The daemon now gates discharge on **physical adapter presence** (the raw SMC `AC-W` key, which stays true through a force-discharge, falling back to IOKit's `ExternalConnected`) instead of the providing-source flag. Discharge now runs continuously until it reaches the limit (or the cable is genuinely unplugged).
  - Same fix applied to the MagSafe status LED (no longer flips to "Auto" mid-discharge), the prevent-idle-sleep assertion (no longer drops and lets the Mac sleep before draining finishes), and keep-awake.
  - Bumps the helper build version so an already-installed daemon auto-updates.

## 0.9.1

### Patch Changes

- 3073d57: Battery capacity mAh now matches the health percentage.

  The Details view derived "Maximum capacity" (%) from `NominalChargeCapacity` (matching macOS System Settings) but printed the "Capacity" mAh from `AppleRawMaxCapacity`, so the two disagreed — e.g. 5133/6249 mAh (82%) shown right beside a Health of 85%. Both now use the same figure, so the mAh ratio equals the percentage and matches macOS. Verified every displayed value (charge %, charging/plugged state, time remaining, cycles, temperature, health, capacity, and watts) against `pmset`, `ioreg`, and `system_profiler`.

- 86829c6: Premium HugeIcons menu-bar battery + selectable icon themes.

  The menu-bar battery is now drawn from HugeIcons' battery geometry and you can pick from four looks in Settings › Menu Bar: **Rounded** (HugeIcons squircle, smooth proportional fill — the new default), **Bars** (squircle with discrete level bars), **Classic** (traditional rectangular battery), and **Minimal** (clean capsule). All styles fill to your exact charge and draw the charging bolt inside the glyph, and they keep the adaptive template look plus the low/warm/charging colours.

- 71b305b: Always Active: turn off the display and keyboard backlight while the lid is closed.

  When "Always Active" is holding the Mac awake and you close the lid, the daemon now forces the display to sleep (the keyboard backlight follows it) so background jobs keep running without the hidden panel and backlight draining power. It re-triggers each time the lid closes and resets when the lid opens or keep-awake stops holding.

- 621aadc: Subtle animations and micro-interactions in the menu popover and Settings.

  The charge bar now fills with a spring and the limit marker slides when values change; the big percentage rolls with a numeric-text transition; the bar gains a gentle breathing glow while charging; quick-action buttons have press + hover feedback; and the battery-style tiles lift on hover with a spring selection. All motion lives in views that only render while open (popover / Settings), so idle CPU stays at ~0% and the always-visible menu-bar icon is never animated — no background drain on a battery app.

- 5f294f5: Notifications: register at launch, cleaner content, no emojis.

  When notifications are enabled, the app now registers with the system at launch (via a shared authorization path) instead of waiting for an unpredictable state change, so it shows up in System Settings › Notifications and can deliver. Alerts are grouped under one thread and a same-kind alert is cleared (pending and delivered) before re-posting so they don't stack. Removed the emoji from the test-notification message; the charge alerts (limit, heat, low, full) stay plain text.

- 6a600dd: Menu-bar battery icon now fills proportionally to the exact charge.

  The status-item battery was drawn with SF Symbols, which only offer five fixed fills (0/25/50/75/100), so the level appeared to jump in big steps and looked unchanged for wide percentage ranges. It's now a custom-drawn battery whose inner fill width tracks the real percentage, while keeping the adaptive template look and the low/warm/charging colours.

## 0.8.4

### Patch Changes

- Build the released binary on macOS 26 (was macOS 15). A binary built against the
  macOS 15 SDK silently failed to launch (exited immediately) on macOS 26 due to a
  Swift concurrency runtime mismatch — even though the same source runs fine when
  built on macOS 26. No code change; this rebuilds the release on the matching SDK.

## 0.8.3

### Patch Changes

- **Fixed another launch/enable crash.** Two more `MainActor.assumeIsolated` calls
  (the lid sleep/wake callbacks) could trap on macOS 26 when the callback wasn't on
  the main actor's executor — the same isolation-assertion crash. All such calls now
  hop safely with `Task { @MainActor }`.
- **Notifications now guide you instead of doing nothing.** Turning notifications on
  requests permission if it's undetermined, and if it's denied it opens an alert
  pointing to System Settings › Notifications rather than silently failing.
- **Restored the smooth, rounded menu.** Removed a custom background layer that made
  the popover look flat/square in the production build; it's back to the native
  translucent rounded style.

## 0.8.2

### Patch Changes

- Fixed a crash on launch (the app opened then immediately quit) on macOS 26. A
  notification/observer callback used `MainActor.assumeIsolated`, which the macOS 26
  Swift runtime turns into a hard trap when the callback isn't on the main actor's
  executor. Those callbacks now hop to the main actor safely with `Task { @MainActor }`.

## 0.8.1

### Patch Changes

- **Fixed the self-updater failing to reopen / relaunch after an update.** The
  update script now runs fully detached from the app (so quitting to swap the
  bundle can't kill it mid-update), refreshes Launch Services so the new bundle
  isn't shadowed by a stale registration, clears quarantine, and retries the
  relaunch. It also logs each step for diagnosis.
- **Homebrew install** — `brew tap broisnischal/battlify-releases https://github.com/broisnischal/battlify-releases`
  then `brew install --cask battlify`. The cask clears the download quarantine on
  install so the app launches without a Gatekeeper warning, and it tracks each
  release automatically.

## 0.8.0

### Minor Changes

- **Notifications** — optional macOS alerts for charge events: charge limit
  reached, charging paused because the battery is warm, low battery, and fully
  charged. Enable them in Settings › General, with a "Send Test Notification"
  button to confirm they're working.
- **Recharge range** — an opt-in band under the charge limit: set a lower
  "Recharge at" level so the battery drains to it before topping back up to the
  limit, instead of sitting pinned at the top. Hidden unless you turn it on.
- **Red warning indicator** — the menu-bar icon and the in-app charge gauge now
  turn red when the battery is critically low or running warm.
- **Manage License from About** — a License row in Settings › About to activate
  or, once purchased, remove the license at any time.
- **Locked UI when the trial ends** — Details and History are disabled (alongside
  the charge controls) until the app is activated.
- **Snappier live updates** — plugging/unplugging the charger updates the menu
  immediately, re-reading a few times so IOKit's lagging charge flag settles.
- **Cleaner menu** — solid native popover background, a tidied footer, and the
  menu re-syncs its state every time it opens.

## 0.7.3

### Patch Changes

- Update the embedded license public key to the production storefront key so
  license keys issued after checkout activate correctly (previously valid keys
  failed with "This license key couldn't be verified").

## 0.7.2

### Patch Changes

- **In-app updates now install themselves** — clicking Update downloads the new
  version, replaces the app in place, and relaunches it automatically, instead of
  opening the download page for a manual drag-install. Falls back to the download
  page only if the app lives somewhere it can't update itself.

## 0.7.1

### Patch Changes

- **Fixed the menu popover on multi-monitor setups** — it now sizes to the display
  it actually opens on (the one under the cursor) instead of the screen holding
  keyboard focus, so it no longer gets clipped off the bottom or forced to scroll.
- **Consistent, native corner radii** — every card, banner, button, and tab now uses
  one harmonized radius scale with continuous (squircle) corners that match macOS's
  own windows and controls, instead of the previous mix of mismatched round corners.
- **Removed the Optimized Battery Charging prompt** — dropped the "Recommended Setup"
  card and the one-time menu nudge to streamline the UI.

## 0.7.0

### Minor Changes

- **Redesigned menu bar dropdown** — decluttered to the day-to-day essentials
  (battery status, Save Mode, charge limit, quick actions). The wordy per-toggle
  captions are gone; explanations now live where there's room for them.
- **New Settings window** — a dedicated window with **Charging**, **Sleep & Power**,
  and **General** tabs. Everything set-once (heat pause, MagSafe LED, sleep/wake
  behavior, menu-bar appearance, updates) moved here to keep the menu simple.
- **Helper management in Settings** — install, reinstall, or uninstall the root
  helper from the General tab, with live status (installed / not installed).
- **Optimized Battery Charging guidance** — a one-time nudge under the limit slider
  plus a Recommended Setup note in Settings, both with an "Open Battery Settings"
  button, so macOS's own charge management doesn't override your limit.
- **Slightly dim the display on battery** — a new toggle (Sleep & Power › On Battery)
  that lowers brightness a little when unplugged to stretch battery life.
- **Fixed Display Off** — turning the display off now waits briefly so the click
  that triggered it doesn't immediately wake the screen back up; it stays off until
  the next key press or trackpad tap.

## 0.6.1

### Patch Changes

- **Menu-bar display options** — hide the battery percentage (show just the icon)
  and turn off state coloring to keep the icon monochrome.
- **Fixed the stale charge indicator** — changing the limit (or pausing,
  calibrating, etc.) now updates the menu-bar icon and color within seconds instead
  of waiting for the next poll, so "started charging" shows right away.
- **Clearer Low Power Mode** — labeled to explain it lowers the ProMotion refresh
  rate, making it the obvious switch to restore full refresh rate after Super Saver.
- Added tooltips to the quick actions, the charge gauge, and Low Power Mode.

## 0.6.0

### Minor Changes

- **MagSafe LED modes** — Auto (macOS controls it) / Show status (orange charging,
  green holding the limit) / Off. Adds a post-wake "settling" window where the LED
  turns off and charging is briefly held before control resumes.
- **Stop charging before sleep** — cuts charging as the Mac sleeps so macOS can't
  top the battery past your limit overnight while the daemon is frozen.
- **Prevent idle sleep while plugged in** — optional power assertion (AC only) that
  keeps the limit continuously enforced.
- **Charge to 100% once** — one-tap calibration that temporarily ignores the limit
  and auto-reverts as soon as the battery is full.
- **Helper version handshake** — the app now detects and warns when the installed
  helper is older than it expects, instead of pause/other actions silently failing.

### Patch Changes

- **Battery indicator fixes** — the menu-bar glyph shows the real charge level, the
  charging bolt appears only while actually charging (not when paused), state color
  (green charging / red critically low) renders via a non-template image, and the
  icon updates reliably. Added a tooltip explaining why charging is paused.
- **Charge pause/resume reliability fixes** and a "settling after wake" status.
- **Lower energy use** — release builds are size-optimized and symbol-stripped, and
  all background polling timers now declare tolerance so macOS can coalesce wakeups.

## 0.5.0

### Minor Changes

- **Scheduled charge pause** — pause charging for 1h / 3h / 5h or until you resume;
  auto-resumes when the timer runs out, with remaining time shown in the menu.
- **MagSafe LED fix** — the LED re-asserts each tick (green when held/paused, orange
  while charging) so it reliably changes when charging stops.
- **Reverted licensing to offline Ed25519** (removed Gumroad); keys verify locally
  against an embedded public key, minted by `licensetool`.

### Patch Changes

- Native **monochrome** UI (system accent only; grayscale elsewhere) and a
  "Last closed" lid readout in the menu.

## 0.4.1

### Minor Changes

- **Quick Actions** — dim/brighten the display, turn the display off, and sleep the
  Mac from the menu. (Fan control omitted — locked & unsafe on Apple Silicon.)
- **UI refresh** — a charge gauge in the header marking where your limit sits,
  rounded numerals, icon-led section headers, and a cohesive battery-green accent.

## 0.4.0

### Minor Changes

- **Discharge to limit (hold-in-range)** — when plugged in above the limit, run off
  battery (force-discharge via the adapter SMC key, CHIE on Tahoe) until it drops
  back to the limit. Adapter is always restored when not sailing down and on exit.
- **MagSafe LED status** — orange while charging, green when holding at the limit;
  handed back to macOS when disabled or on exit.
- **Lid-closed drain history** — records charge at lid close vs reopen and shows the
  drop and %/hour in Battery History.

### Patch Changes

- Fix crash on lid reopen (added `NSBluetoothAlwaysUsageDescription`) and big CPU
  cuts: process polling only while the Details window is open; slower background
  pollers; reliable Wi-Fi/Bluetooth restore-on-wake; faster post-wake refresh.
- Install docs: quarantine-flag fix, disable macOS Optimized Battery Charging.

## 0.3.1

### Patch Changes

- Optimization: drop the unused offline Ed25519 licensing code (`License.swift`)
  and the `licensetool` target now that licensing runs through Gumroad — smaller
  build, fewer targets, one clear licensing path.

## 0.3.0

### Minor Changes

- 38dfbbe: Monetization: use-based 30-day free trial (free days are only spent on days you
  actually use the app), $2.99 one-time purchase verified via Gumroad (Apple Pay at
  checkout), a source-available Battlify License, Changesets release management, and
  a polished README.

## 0.2.0

### Minor Changes

- **Super Save when lid closed** — closing the lid applies maximum battery saving
  (Low Power Mode, all sleep wake-ups off, Wi-Fi/Bluetooth off) and opening it
  restores your previous state, sleepwatcher-style.
- **Live lid / clamshell sensor** with a docked-mode battery-health warning.
- **Launch at Login** (via `SMAppService`).
- **In-app auto-update** — checks a public feed and offers a one-click download.

## 0.1.0

### Initial release

- Menu-bar battery monitoring (%, health, cycle count, temperature, capacity).
- **Charge limiting** via SMC (handles legacy `CH0B/CH0C` and Tahoe `CHTE`).
- **Heat-aware charging** — pause charging when the battery gets too warm.
- One-tap **Save Modes** (Off / Normal / Super Saver).
- **Sleep & Idle** controls (Power Nap, wake-on-network, TCP keep-alive).
- **Low Power Mode** toggle + top energy-using processes (suspend/resume).
- **Usage history** charts and a **Battery Health** tips card.
- Privileged root helper + Unix-socket control, with safe charge re-enable on exit.
