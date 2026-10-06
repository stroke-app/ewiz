---
"ewiz": minor
---

**Battlify is now eWiz.** New name, same app: settings, license key, history and the
charge limit all carry over by themselves.

On first launch eWiz copies Battlify's settings across, and its helper takes over from
Battlify's, moving the config, charge history and limit ownership with it. A copy of
Battlify that updates itself installs eWiz in place, and eWiz then renames its own
bundle. Homebrew users move across with `brew upgrade`. Licenses sold as Battlify keep
working.

macOS treats eWiz as a new app, so it asks once more for notifications and the helper,
and Launch at Login needs switching on again.
