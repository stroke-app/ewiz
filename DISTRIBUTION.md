# Distributing & selling eWiz

This covers shipping eWiz as a **closed-source, paid** macOS app outside the
Mac App Store. (It can't go on the App Store — charge limiting needs SMC access
+ a root helper, which the sandbox forbids.)

## 1. Apple Developer setup (one-time, required)

You need an **Apple Developer Program** membership ($99/year). Without it,
Gatekeeper blocks downloaded apps with no clean way for buyers to open them.

1. **Developer ID Application certificate** — create in Xcode or the Apple
   Developer portal. Export it as a `.p12` (with a password). This signs the app.
2. **App Store Connect API key** (for notarization) — App Store Connect →
   Users and Access → Integrations → keys. Create a key with the **Developer**
   role. Download the `AuthKey_XXXX.p8` (you can only download it once). Note the
   **Key ID** and **Issuer ID**.

Why both: the certificate *signs* the app so macOS trusts the author;
**notarization** is Apple scanning the build and issuing a ticket so Gatekeeper
opens it without warnings. We staple the ticket into the DMG so it works offline.

## 2. GitHub secrets

Add these in the repo → Settings → Secrets and variables → Actions:

| Secret | What it is |
|--------|------------|
| `DEVELOPER_ID_CERT_P12_BASE64` | `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | any random string (ephemeral CI keychain) |
| `NOTARY_KEY_ID` | App Store Connect key ID |
| `NOTARY_ISSUER_ID` | App Store Connect issuer UUID |
| `NOTARY_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

> macOS GitHub Actions runners bill minutes at a **10× multiplier**. On a private
> repo this eats your included minutes fast — expect to pay for build minutes, or
> build/notarize locally with the same scripts (see below).

## 3. Cutting a release

Tag and push:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The `Release` workflow builds → signs → notarizes → staples → creates a **draft**
GitHub Release with `eWiz-0.1.0.dmg`. Review it, then publish.

**Locally** (no CI), same result:

```bash
export CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_KEY_ID=...  NOTARY_ISSUER_ID=...  NOTARY_KEY_PATH=~/AuthKey_XXXX.p8
./scripts/package-app.sh 0.1.0
./scripts/make-dmg.sh 0.1.0
./scripts/notarize.sh dist/eWiz-0.1.0.dmg
```

## 4. Selling it (payments + licensing)

eWiz is sold on **ewiz.app**: a one-time $2.99, with a use-based 30-day trial
(`LicenseManager` only spends a free day on a day the app is actually used). Keys
are verified **offline**: the website signs them with an Ed25519 private key, the
app checks them against the public key in `Sources/EWizKit/License.swift`. Nothing
phones home after purchase.

### Pages ewiz.app has to serve

Every address the app links to is in `Sources/EWizKit/EWizLinks.swift`:

| Page | Linked from | What it does |
|---|---|---|
| `https://ewiz.app` | Settings › About › Visit the Website, the Homebrew cask | Home page |
| `https://ewiz.app/buy` | License window › Buy, README | Checkout. Asks for the buyer's **device code** (shown in the license window, `XXXX-XXXX-XXXX`) and emails a key signed for it |
| `https://ewiz.app/license` | License window › Find your key, the "isn't linked to a Mac" error | Look up a lost key by email, or issue one for a new Mac |
| `https://ewiz.app/donate` | Settings › About › Donate | Donations |
| `hello@ewiz.app` | Contact Support, the license window's help link | Support mailbox; the app pre-fills version, macOS and diagnostics |

Source, issues and the update feed stay on GitHub (`stroke-app/ewiz`,
`stroke-app/ewiz-releases`).

### Minting keys

A key is `base64url(payload).base64url(signature)`, unpadded, where the signature is
Ed25519 over the exact payload bytes. The payload is JSON:

| Field | Meaning |
|---|---|
| `e` | buyer's email (required) |
| `n` | buyer's name (required, may be empty) |
| `iat` | issued at, Unix seconds |
| `exp` | expiry, Unix seconds; leave out for a perpetual license |
| `p` | product: `"battlify"` for now. Every version accepts it; `"ewiz"` is accepted from the eWiz builds on, so switch once installs from before the rename have updated |
| `d` | device code, 12 hex digits, upper case (dashes optional) |

`scripts/license-mint.mjs` is a dependency-free Node reference for the checkout:

```bash
LICENSE_SIGNING_PRIVATE_KEY=<base64> \
  node scripts/license-mint.mjs --email a@b.com --device 7F3A-92C1-D04B --name "A B"
swift run licensetool verify --token <token> --device 7F3A-92C1-D04B   # check it
```

The private key must be the one `License.publicKeyBase64` was made from. Keep it
in the website's secrets as `LICENSE_SIGNING_PRIVATE_KEY`, never in the app or this
repo. A new key pair would void every key already sold.

## 5. Homebrew note

A public Homebrew cask means anyone can `brew install` it for free, which
conflicts with charging. For a paid app, **drop the public cask** (or keep one
that only fetches a free/trial build). `Casks/ewiz.rb` is kept in-repo for
reference / a future free tier.

## 6. Auto-update

eWiz updates through **Sparkle 2** (a SwiftPM dependency): a check on launch and daily
(`SUEnableAutomaticChecks`, `SUScheduledCheckInterval` = 86400), or from About › "Check
for Updates…" and the menu's Update banner. Sparkle's window shows the check, the notes,
the download's progress and the install, then relaunches the new version.

- The app reads `SUFeedURL` from Info.plist (written by `scripts/package-app.sh`):
  `raw.githubusercontent.com/stroke-app/ewiz-releases/main/appcast.xml`.
- **Trust** is the EdDSA key, not a Developer ID: `SUPublicEDKey` in Info.plist is
  `UpdateSignature.publicKeyBase64`, and every DMG in the feed carries that key's
  `sparkle:edSignature`, made by `licensetool sign-update` from the
  `UPDATE_SIGNING_PRIVATE_KEY` secret (a 32-byte Ed25519 seed, base64 — the same format
  Sparkle's `generate_keys`/`sign_update` use). The app is ad-hoc signed; Sparkle accepts an
  update when *either* the EdDSA signature *or* the Apple code-signing match holds, so
  EdDSA alone carries it. Rotating the key means signing the release that introduces the
  new key with the old one too; dropping it isn't supported.
- `CFBundleVersion` is a build number derived from the version (`scripts/build-number.sh`:
  `0.18.5` → `1805`), and the appcast's `sparkle:version` is the same number.
- `scripts/package-app.sh` copies `Sparkle.framework` from the package artifact into
  `Contents/Frameworks`, links the app with an `@executable_path/../Frameworks` rpath, and
  re-signs the framework's XPC services, Autoupdate and Updater.app innermost-first.
- `scripts/make-appcast.sh` writes `dist/appcast.xml` **and** `dist/appcast.json`. The JSON
  feed is what copies up to 0.18.5 poll with the app's old updater (`{version, url, notes,
  sha256, signature}`, signature over the digest's hex); they can only reach a Sparkle build
  through it, so the release workflow keeps publishing both to `stroke-app/ewiz-releases`.
  It can be retired once those copies have moved on.

## 7. Icons & branding (later)

Add `eWiz.icns` to the bundle: create an `AppIcon.iconset` (16–1024 px),
`iconutil -c icns AppIcon.iconset`, drop the `.icns` in `Contents/Resources`, and
set `CFBundleIconFile` in `package-app.sh`'s Info.plist. The menu-bar glyph is
already an SF Symbol; you can swap it for a custom template image later.
