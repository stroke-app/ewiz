---
"ewiz": patch
---

**Switching the charge limit on stops charging at once, and the cable no longer reads as unplugged while the battery runs down to the limit.** On Macs that limit through macOS's own charge limit, macOS took about 40 seconds to act after the limit was set, so the battery kept charging past it and the panel said "Charging". eWiz now cuts the adapter for that gap: charging stops in about a second, and macOS's limit takes over within 90 seconds. On these Macs, an adapter cut (eWiz's, or macOS's own while it drains to the limit) also looked exactly like pulling the cable, so the panel said "On battery" and a hold could play the unplug sound. eWiz now reads the cable from the charger's own "can charge" signal, which only a real unplug clears.
