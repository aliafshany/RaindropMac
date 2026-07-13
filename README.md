# RaindropMac

**A native SwiftUI macOS client for [Raindrop.io](https://raindrop.io).**

This is **not** the official Electron desktop app. It is a from-scratch SwiftUI rewrite for people who want a lightweight, native Mac experience that talks to the same Raindrop account and API.

- **Author:** [Ali Afshanisoumeeh](https://github.com/aliafshany) (`@aliafshany`)
- **Version:** 1.1.0
- **Platform:** macOS 14+
- **Stack:** SwiftUI · Raindrop REST API · optional Stella AI chat

> Official Raindrop products live at [raindrop.io](https://raindrop.io) and [github.com/raindropio](https://github.com/raindropio). This project is an independent, unofficial client.

---

## Why this exists

I wanted a **tiny, cozy native Mac app** for Raindrop — not a wrapped web view. RaindropMac is built in SwiftUI with:

- Native sidebar, list/grid library, and detail pane  
- System Light / Dark / Auto appearance  
- Low idle footprint (no Chromium, no constant JS timers)  
- Keyboard shortcuts that feel at home on macOS  

If you are searching for a **Swift / SwiftUI version** of the Raindrop desktop app, this is that project.

---

## Features

| Area | What you get |
|------|----------------|
| Library | All, Favorites, Unsorted, Trash · collections · list & grid |
| Bookmarks | Add, edit, open, favorite, move, delete |
| Bulk | Multi-select, bulk favorite / move / delete |
| Quick Save | Fast paste-URL sheet (`⌘⇧S`) |
| Tags | Tag manager UI |
| Filters | Broken links, duplicates |
| Reader | In-app article-style reading for cached content |
| Import / Export | HTML bookmark file workflows |
| Stella | Native chat UI + browser fallback for Raindrop’s AI |
| Theme | System / Light / Dark · coral accent |

Browser extensions, page highlights drawn in the page, and “save all tabs” still need the official browser extension — those are not reimplemented here.

---

## Download (DMG)

Prebuilt installers are on the **[Releases](https://github.com/aliafshany/RaindropMac/releases)** page.

1. Download `RaindropMac-1.1.0.dmg`  
2. Open the DMG and drag **RaindropMac** into Applications  
3. First launch: if macOS says the app is from an unidentified developer, right-click → **Open** (or allow it in System Settings → Privacy & Security)

The app is **ad-hoc signed** for distribution outside the Mac App Store. It is not notarized with Apple unless a later release says otherwise.

---

## Setup (API keys)

Raindrop requires your own OAuth app credentials:

1. Open [Raindrop → Settings → Integrations](https://app.raindrop.io/settings/integrations)  
2. Create a new app / integration  
3. Set the redirect URI to:

   ```text
   http://localhost:54321/auth/callback
   ```

4. In RaindropMac → **Settings → Account**, paste **Client ID** and **Client Secret**  
5. Sign in with the button on the login screen  

Your secrets stay **only on your Mac** (app preferences). They are **never** committed to this repository, included in source, or baked into the DMG. Use **Settings → Account → Clear credentials & sign out** to wipe them locally anytime.

If a Client ID/Secret was ever shared by accident, rotate it in [Raindrop Integrations](https://app.raindrop.io/settings/integrations).

---

## Build from source

```bash
git clone https://github.com/aliafshany/RaindropMac.git
cd RaindropMac
open RaindropMac.xcodeproj
```

In Xcode: select the **RaindropMac** scheme → **My Mac** → Run (`⌘R`).

Command-line release build:

```bash
xcodebuild \
  -project RaindropMac.xcodeproj \
  -scheme RaindropMac \
  -configuration Release \
  -derivedDataPath build/DerivedDataRelease \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES
```

App product:

```text
build/DerivedDataRelease/Build/Products/Release/RaindropMac.app
```

### Make a DMG locally

```bash
./scripts/make-dmg.sh
```

Output: `dist/RaindropMac-<version>.dmg`

---

## GitHub Actions

On every push of a tag like `v1.1.0`, the workflow:

1. Builds a Release `.app` on `macos-latest`  
2. Packages a DMG  
3. Uploads it to a GitHub Release  

See [`.github/workflows/release.yml`](.github/workflows/release.yml).

---

## Project layout

```text
RaindropMac/
├── RaindropMac/           # App sources
│   ├── Models/
│   ├── Services/          # Auth, API, Stella
│   ├── ViewModels/
│   ├── Views/
│   └── Utils/             # Theme, tooltips, modals
├── RaindropMac.xcodeproj
├── scripts/make-dmg.sh
└── .github/workflows/
```

---

## Relationship to official Raindrop

| | Official desktop | RaindropMac |
|--|------------------|-------------|
| Tech | Electron | Native SwiftUI |
| Maintainer | Raindrop.io | Ali Afshanisoumeeh |
| Repo | [raindropio/desktop](https://github.com/raindropio/desktop) | this repo |
| Account data | Raindrop cloud | Same (public API) |

Raindrop.io, logos, and the service itself are trademarks of their respective owners. This client only uses the public API for personal access to *your* library.

---

## License

Source in this repository is provided under the **MIT License** (see [LICENSE](LICENSE)) unless noted otherwise.  
Raindrop.io itself is a separate commercial product; use of their API is subject to their terms.

---

## Author

**Ali Afshanisoumeeh**  
GitHub: [@aliafshany](https://github.com/aliafshany)

If this SwiftUI client helps you, a star on the repo is appreciated — and if you were looking for a native Mac alternative to the Electron app, you found it.
