---
"ewiz": minor
---

**Rest the Mac without closing the lid.** Closing the lid is the usual way to make a Mac
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
