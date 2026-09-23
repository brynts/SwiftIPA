<div align="center">
  <img src=".github/assets/icon.png" width="120" height="120" alt="SwiftIPA icon" />

  # SwiftIPA

  **Sign IPAs, fast.**

  [![Platform](https://img.shields.io/badge/platform-iOS%2016%2B-FF9F0A?style=flat-square&logo=apple&logoColor=white&labelColor=000000)](#)
  [![Swift](https://img.shields.io/badge/Swift-5-FF9F0A?style=flat-square&logo=swift&logoColor=white&labelColor=000000)](#)
  [![Signing Engine](https://img.shields.io/badge/engine-zsign-FF9F0A?style=flat-square&labelColor=000000)](https://github.com/zhlynn/zsign)
  [![License](https://img.shields.io/badge/license-MIT-FF9F0A?style=flat-square&labelColor=000000)](LICENSE)

</div>

<br>

Every sideloading app does roughly the same thing: unpack an IPA, rewrite a few plist values, sign the binaries, zip it back up. What they don't do is make that fast, and they don't make it feel like it belongs on your phone. SwiftIPA is my answer to both: the actual signing work runs through [zsign](https://github.com/zhlynn/zsign) compiled straight into the app, resigning something you already signed once is instant instead of redone from scratch, and signing a batch of apps uses every core on your device instead of one at a time.

Everything happens on-device. There's no backend, no account, no telemetry. The only network calls SwiftIPA ever makes are the ones you ask for: downloading an IPA from a URL you gave it, fetching a source repo you added, checking this repo's GitHub releases from Settings, or — only while you're actually installing — handing a manifest pointer to the relay described below.

<br>

## What it does

<table>
<tr>
<td width="50%" valign="top">

**⚡ Sign, fast**
Bundle identifier (keep it, suffix it, randomize it, or replace it outright), display name, version, build number, minimum iOS version, custom icon, raw entitlements editing.

**🗄️ Instant-Resign Cache**
Sign the exact same app + certificate + options combination twice, and the second time comes back in a fraction of a second instead of re-running the whole pipeline.

**🧩 Parallel batch signing**
Select a pile of apps, pick a certificate and a preset, and SwiftIPA signs all of them at once, spread across every CPU core on your device.

**💾 Signing presets**
Save a certificate + bundle ID rule + modifiers + tweaks combination once, reuse it forever.

</td>
<td width="50%" valign="top">

**🛡️ Certificate watchdog**
Real health at a glance — valid, expiring soon, expired, revoked — with a local notification a few days before a certificate goes dark.

**🔍 IPA Inspector**
Architectures, FairPlay encryption, linked dylibs, rpaths, frameworks, extensions, a bundled Watch app — with plain-language findings before you sign anything.

**📡 Sources**
Add AltStore- or ESign-format repo URLs, browse them, and pull an app straight into your library.

**🧬 Tweaks & Modifiers**
Inject a `.dylib` or `.deb`. Strip extensions, the Watch app, or embedded provisioning. Force file sharing, full screen, 120Hz. Drop non-English localizations.

</td>
</tr>
</table>

**📲 Install without a cable** — tap "Install," stay on Wi-Fi, and the app lands on your Home Screen. No certificate to trust, no configuration profile, no AltServer, no Mac (though "Export IPA" is right there too, for AltStore, Sideloadly, or TrollStore).

**🎨 Same look as my other apps** — same design system as [FileManager](https://github.com/xsxs18-dev/FileManager) and [HTMLViewer](https://github.com/xsxs18-dev/HTMLViewer): six built-in themes — orange & black by default, plus light blue and red, each in dark and light — same spacing and type scale.

<br>

## How on-device install actually works

iOS installs apps over Wi-Fi through `itms-services://`, but it only trusts a manifest that's served from a real, publicly-trusted HTTPS domain — a manifest served straight from your phone gets silently ignored. SwiftIPA's default install path works around that without asking you to trust anything: the app you just signed is served from a tiny server running on your own device, and only the small `manifest.plist` pointer — bundle ID, version, and a link back to your device — is handed off through [`api.palera.in`](https://api.palera.in), a small public relay built for exactly this. Your `.ipa` itself never leaves your phone; the relay only ever sees a URL, not your app.

If that path can't reach your device — some routers isolate clients from each other — SwiftIPA can retry over `localhost` instead of your Wi-Fi address, no settings menu required, right from the same install screen.

There's also a fully local fallback that needs no third party at all: a self-signed certificate generated once on your device (Settings → General → VPN & Device Management → SwiftIPA Local Server → Trust), after which installs go straight from phone to phone with nothing else involved. It's one extra step, so it's the fallback, not the default.

<br>

## Get it

Every push to `main` cuts a fresh unsigned build via GitHub Actions — see [Releases](https://github.com/xsxs18-dev/SwiftIPA/releases) for the latest `.ipa`, sign it with SwiftIPA itself (chicken, meet egg) or with Sideloadly / AltStore using your own Apple ID.

There's also a self-updating AltStore/ESign source at [`altstore-source.json`](altstore-source.json) — add this raw URL to AltStore, ESign, or SwiftIPA's own Sources tab:

```
https://raw.githubusercontent.com/xsxs18-dev/SwiftIPA/main/altstore-source.json
```

### Building it yourself

SwiftIPA needs a Mac with Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), and your own signing certificate — none of that is included here, and it never will be.

```bash
brew install xcodegen
git clone https://github.com/xsxs18-dev/SwiftIPA.git
cd SwiftIPA
./Scripts/fetch-dependencies.sh   # pulls zsign's source + OpenSSL headers into Vendor/
xcodegen generate
open SwiftIPA.xcodeproj
```

Build and run onto your device from Xcode with your own Apple ID or paid developer account, exactly like any other app you build yourself.

zsign's C++ source isn't vendored directly in this repo — the fetch script clones it into `Vendor/zsign` (gitignored) so this repo stays small and always picks up zsign's latest fixes. The Swift side of the app talks to it through one small Objective-C++ bridge (`Signing/ZSign/ZSignBridge.mm`) — that's the entire C++ surface area, everything else is Swift.

<br>

## Tech stack

| | |
|---|---|
| UI | SwiftUI everywhere |
| Signing | [zsign](https://github.com/zhlynn/zsign) (C++, vendored via the fetch script) behind a thin Objective-C++ bridge |
| Crypto / X.509 | OpenSSL (headers vendored, linked via [krzyzanowskim/OpenSSL](https://github.com/krzyzanowskim/OpenSSL)), `CryptoKit` for hashing |
| ZIP | [`ZIPFoundation`](https://github.com/weichsel/ZIPFoundation) |
| Certificates & Keychain | `Security` framework — `SecPKCS12Import`, `CMSDecoder` for provisioning profiles, Keychain for p12 passwords |
| Local install server | `Network` framework (`NWListener` + TLS), self-signed identity generated on-device for the fallback path, [`api.palera.in`](https://api.palera.in) for the default manifest relay |
| Mach-O inspection | a small hand-written parser (`Signing/MachO.swift`) — architectures, encryption, linked dylibs, rpaths |
| Localization | a String Catalog (`Localizable.xcstrings`), English source + German, follows your system language |
| App ↔ Share Extension | the system pasteboard, no App Group, no extra entitlements |
| CI | GitHub Actions — an unsigned `.ipa` and a new release for every push to `main` |

<details>
<summary><strong>Project layout</strong></summary>

```
SwiftIPA/
├── App/            entry point
├── DesignSystem/   colors, spacing, type, theme definitions, shared styles
├── Models/         AppEntry, SigningCertificate, SigningOptions, SigningPreset,
│                   InjectedDylib, RepositorySource, InspectionReport
├── Signing/         IPAService, ZSignEngine, SigningEngine (cache + parallel queue),
│                   MachO parser, DebExtractor, InfoPlistPatcher
│   └── ZSign/       the Objective-C++ bridge into zsign
├── Services/       AppLibraryStore, CertificateStore, CertificateService,
│                   DylibLibraryStore, PresetStore, SourceStore, RepositoryService,
│                   DefaultSigningOptionsStore, InstallServer, LocalServerIdentity,
│                   InspectorService, KeychainStore, ThemeManager, UpdateChecker
├── Shared/         InboxStore (shared with the extension), FileHashing,
│                   FileManager+Replace (hard-link-first file replace, keeps
│                   cache hits and re-signs off the disk-copy path)
├── Views/          screens and sheets, grouped by tab
└── Resources/      Assets.xcassets, Info.plist, Localizable.xcstrings

ShareExtension/     the Share Sheet extension target — send an .ipa in from Files or Safari
Vendor/             pulled in by Scripts/fetch-dependencies.sh, gitignored
project.yml         XcodeGen project definition
.github/workflows/  CI — builds an unsigned .ipa and cuts a GitHub Release for every push
```

</details>

<br>

## Known rough edges

<details>
<summary>Click to expand</summary>

- `.deb` tweak packages only unpack if they use gzip compression (`data.tar.gz`) — the vast majority do, but a `.deb` compressed with `xz` or `zstd` will get rejected with a clear error instead of silently failing. Re-export it as a raw `.dylib` and it'll work.
- The local install server needs you to actually be on Wi-Fi — it won't work over cellular-only or a USB-tethered connection. If your router isolates clients from each other, switch to the `localhost` retry right on the install screen.
- The default (no-certificate) install path depends on a third-party relay being up. If it's ever down, the certificate-based fallback still works fully offline.
- Revocation checking is limited to what's visible in the provisioning profile and certificate expiry dates; it doesn't call out to Apple's OCSP responder.
- The Share Extension's own UI is English-only for now, regardless of your system language — only the main app is fully localized.
- No landscape-optimized layout yet, and no iPad-specific split view.

</details>

<br>

This repo is private for now — it'll go public once it's had a proper shakedown. Contributions and bug reports welcome once it does; this is a small side project, not a polished product, and it'll stay that way unless people find it useful enough to push on.

## License

MIT — see [LICENSE](LICENSE). Do whatever you want with it.
