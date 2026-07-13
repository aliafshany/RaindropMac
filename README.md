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

## How the API works (and what you type in)

RaindropMac does **not** ship with a shared Raindrop app key. Each user creates their own OAuth “app” on Raindrop, then pastes two values into this Mac client. After that, the app opens a normal Raindrop login page in your browser, receives a short-lived code on `localhost`, and exchanges it for an access token. Bookmarks, collections, tags, and the rest go through Raindrop’s public REST API using that token.

You do **not** need to call the API by hand or write code — only fill in the fields below once.

### What you will enter (inputs)

| Where | Field | What it is | Example shape |
|-------|--------|------------|----------------|
| Raindrop website | **Name** (of the integration) | Any label for yourself | `RaindropMac` |
| Raindrop website | **Redirect URI** / callback URL | Must match the app **exactly** | `http://localhost:54321/auth/callback` |
| RaindropMac → Settings → Account | **Client ID** | Public ID of your integration | long hex string |
| RaindropMac → Settings → Account | **Client Secret** | Private secret of your integration | UUID-like string |

Nothing else is required for first login (no API base URL, no custom scopes form in the app).

**Redirect URI (copy exactly — no trailing slash, no `https`):**

```text
http://localhost:54321/auth/callback
```

That URI is fixed in the app. If it does not match what you registered on Raindrop, sign-in will fail after you approve access in the browser.

### Step-by-step: create API credentials on Raindrop

1. Sign in to Raindrop in a browser: [https://app.raindrop.io](https://app.raindrop.io)  
2. Open **[Settings → Integrations](https://app.raindrop.io/settings/integrations)**  
3. Create a **new application / integration** (wording may be “Create new app”, “For developers”, or similar)  
4. Fill in:
   - **Name:** e.g. `RaindropMac` (only for your reference)  
   - **Redirect URI / Callback URL:**  
     `http://localhost:54321/auth/callback`  
5. Save / create the integration  
6. Raindrop shows you two values — copy them somewhere temporary (password manager is fine):
   - **Client ID**  
   - **Client Secret**  

Official API overview (optional reading): [https://developer.raindrop.io](https://developer.raindrop.io)

### Step-by-step: paste them into RaindropMac

1. Open **RaindropMac**  
2. Open **Settings** (macOS menu **RaindropMac → Settings…**, or `⌘,`)  
3. Open the **Account** tab  
4. Paste:
   - **Client ID** → into the **Client ID** field  
   - **Client Secret** → into the **Client Secret** field  
5. Close Settings  
6. On the login screen, click **Sign in with Raindrop** (or the main connect button)  
7. Your browser opens Raindrop’s authorize page — approve the app  
8. Raindrop redirects to `localhost:54321…`; the app catches that and finishes login  
9. You should land in your library (All / collections / etc.)

If the Sign in button stays disabled, the **Client ID** field is still empty — paste it first.

### What happens under the hood (simple version)

```text
You paste Client ID + Secret
        ↓
App opens:  raindrop.io/oauth/authorize?client_id=…&redirect_uri=…
        ↓
You log in / allow access in the browser
        ↓
Browser hits:  http://localhost:54321/auth/callback?code=…
        ↓
App exchanges code + Client Secret for access_token (and refresh_token)
        ↓
App calls Raindrop REST API with Authorization: Bearer <token>
```

After that, normal use (add bookmark, move collection, tags, Quick Save, etc.) is just the app talking to Raindrop’s API as **you**. No extra API keys per feature.

### Security (read this)

| Do | Don’t |
|----|--------|
| Keep Client Secret only on your Mac | Commit ID/secret to Git, screenshots, or issues |
| Use **Clear credentials & sign out** if this Mac is shared | Put secrets in the README or release notes |
| Create your **own** integration | Share someone else’s Client Secret |

- Credentials and tokens live in **this Mac’s app preferences** only.  
- They are **not** in this GitHub repo, not in source, and **not** baked into the DMG.  
- Settings → Account → **Clear credentials & sign out** wipes Client ID, Client Secret, and tokens.  
- If a secret ever leaked, **rotate / recreate** the integration on [Raindrop Integrations](https://app.raindrop.io/settings/integrations) and paste the new pair.

### Troubleshooting login

| Symptom | What to check |
|---------|----------------|
| Sign in button disabled | Client ID empty in Settings → Account |
| Browser says redirect mismatch | Redirect URI must be exactly `http://localhost:54321/auth/callback` |
| Browser opens but app stays logged out | App must be running; nothing else should bind port **54321** |
| “Invalid client” / token error | Wrong Client Secret, or integration was deleted — recreate and re-paste |
| Need a fresh start | Settings → Account → **Clear credentials & sign out**, then re-enter ID/secret |

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
