# Frickbear's 3 — Four Layers Down 2.1.5 (iOS IPA wrapper)

An unofficial iOS wrapper for the **4LD / 2.1.5** web build of
**Five Nights at Frickbear's 3**. It runs the same pinned build as the
standalone browser loader (`../frickbears3-4ld-v215-loader/index.html`), but
inside a native app with:

- a real fullscreen canvas and audio unlocked by a native tap
- an on-screen gamepad overlay plus optional tap-to-mouse mode
- automatic pause/resume when the app backgrounds
- configurable game speed, FPS/RAM HUD and a 1×/2×/3× zoom button for minigames
- control profiles, overlay scaling and Fredsweeper touch-scheme settings
- a small bundled `PortAssets/` index of recovered GML/sprites/audio for the native rewrite
- no Safari UI, no ads

The build is pinned to commit `2e796a35225c3036b755517d69215d923c0a181f` of
`Reeyuki/frickbears3port`. The "4LD · 2.1.5" loading label fades out as soon as
the game itself is running.

> **Internet is required.** The IPA contains only the tiny HTML shell. The
> runtime and game data (several hundred MB) are downloaded on first launch
> from jsDelivr / GitHub raw. Use a stable Wi-Fi connection and be patient.
> Saves live in the app's own WebKit storage, not in the IPA — deleting the app
> deletes your saves.

> Personal, non-commercial use only. See [CREDITS.md](CREDITS.md).

---

## Build & install (no Mac required)

You need: a GitHub account, this folder uploaded as a repo, your Windows PC,
your iPhone on the same Wi-Fi/USB, a free Apple ID, and
[Sideloadly](https://sideloadly.io/) (free).

### 1. Put the files on GitHub

Create a new **public** repository and upload the **contents** of this
`Frickbears3iOS` folder (so `project.yml` is at the repo root). Include the
hidden `.github` folder — that is where the build workflow lives.

Public repos get free macOS GitHub Actions minutes. Private repos also work but
consume your monthly free quota.

### 2. Build the IPA in the cloud

1. Open the repo on GitHub → **Actions** tab.
2. Select **Build Frickbear's 3 4LD iOS IPA** → **Run workflow** → green button.
3. Wait ~5 minutes. The workflow generates the Xcode project with XcodeGen,
   builds an unsigned `.app` and zips it into an `.ipa`.
4. Click the completed run → **Artifacts** → download
   **Frickbears3-4LD-IPA** (a .zip). Extract it to get `Frickbears3iOS.ipa`.
   The IPA is small (~1 MB) because the game data is fetched on the device.

### 3. Sign & install on your iPhone with Sideloadly (Windows)

1. Install and open [Sideloadly](https://sideloadly.io/).
2. Connect your iPhone via USB and trust the computer prompt.
3. Enter your **Apple ID + password** (an app-specific password is safest —
   generate one at <https://appleid.apple.com>).
4. Drag `Frickbears3iOS.ipa` into Sideloadly.
5. Optionally set a custom bundle ID so it doesn't clash with other sideloaded
   apps (e.g. `com.yourname.frickbears3`).
6. Click **Start**. It signs with your free personal team and installs.
7. On the iPhone: **Settings → General → VPN & Device Management → your Apple
   ID → Trust**.

Free Apple ID signing lasts **7 days**; just repeat steps 3–6 to refresh. A paid
Apple Developer account lasts a year. Your save data stays as long as you do
not delete the app.

---

## Controls

| On-screen | Sends |
| --- | --- |
| ▲ ▼ ◀ ▶ | Arrow keys (minigame movement) |
| A | Space |
| B | Escape |
| X | E |
| Y | Tab |
| L / R | Q / F |
| II | Pause / resume |
| ⚙ | Open Settings |
| 🔍 1× | Cycle game zoom: 1× → 2× → 3× → 1× |
| MOUSE: ON | Tap anywhere to send mouse clicks to the game |

- **MOUSE: ON** is what you want in the office for doors, the monitor and
  camera tabs. Turn it off for minigames that use direct touch movement.

## Settings (⚙)

All options are saved on the device instantly — **no rebuild required**.

- **Button Mapping** — tap any action, choose the key it should send. **Reset**
  restores the defaults shown in the table above.
- **Game Speed** — pick from 0.25× to 2.0× (default 1.0×).
  ⚠️ **Experimental:** the engine has no official speed control, so this scales
  the game's internal clock. Set it back to **1.00× (normal)** if anything
  behaves oddly.
- **FPS Counter** / **Memory Counter** — toggle a small HUD at the top of the
  screen showing rendered frames per second and the app's real RAM usage in MB.
- **Minigame Zoom Button** — show/hide the 🔍 button. While zoomed: **tap to
  click**, **drag to pan**. Zoom wins over MOUSE mode until you return to 1×.
- **Control Profiles** — separate Free Roam / Office / Minigame bindings, camera
  mode, button size and opacity. The web shell switches manually; the native
  port will switch automatically by room.
- **Overlay Scale** — global multiplier applied on top of the active profile.
- **Fredsweeper Controls** — `FLAG toggle` (default), `Hold FLAG + tap`,
  `Long-press flag` or `D-pad cursor`.
- **Minigame Board Scale** — 2×–4× board fit target. Golden Fredsweeper still
  benefits from pan/zoom or cursor mode.
- **Haptics** — vibration feedback for controls.
- **Mods** — toggles for future JSON/asset-override mods. No mod loader is
  active in the current web shell yet.
- **Reset All** (top right) restores every option and all key mappings.

## Native port assets

`PortAssets/` contains a curated, tiny slice of the recovered GameMaker dump:

- `manifest.json` — logical asset index and board constants
- `Code/Reference/` — decompiled Fredsweeper/minigame GML for reference
- `Fredsweeper/` — tile sprites, font frames and three SFX
- `Rooms/` — office/minigame room images

The full ~1 GB dump stays on your PC. To refresh this curated slice after a new
decompile/export, run:

```powershell
.\Scripts\import-port-assets.ps1
```

The current IPA still uses the web loader and still needs internet on first
launch. These assets are the foundation for the offline native port.

---

## Troubleshooting

- **Stuck on "Reading build manifest…" / "Loading runtime…"** — check your
  internet connection. jsDelivr and GitHub raw must both be reachable; the
  48 MB `voicelines_death.dat` comes from GitHub raw because jsDelivr rejects
  files over 20 MB.
- **First launch takes a long time** — expected. Several hundred MB of split
  archives are downloaded and reassembled. Later launches are faster where
  WebKit can reuse its cache.
- **Black screen after TAP TO START** — the device may be low on RAM.
  Close other apps, restart the phone, and reopen. The runtime needs enough
  memory to hold the reassembled archives.
- **Sideloadly: "provisioning profile missing / could not verify app"** — use a
  real Apple ID, an app-specific password, and a unique bundle ID.
- **Rotation** — the app is landscape-only. Turn the phone sideways before
  tapping **TAP TO START**.

---

## Updating the loader

`Game/index.html` is a copy of the standalone browser loader. After changing
that loader, refresh the bundled copy and commit it:

```powershell
# Windows
.\Scripts\sync-loader.ps1
```

```bash
# macOS / Linux
bash Scripts/sync-loader.sh
```

Then run the GitHub Actions workflow again.

If you have a Mac, you can also skip GitHub Actions entirely:

```bash
cd Frickbears3iOS
brew install xcodegen
xcodegen generate
open Frickbears3iOS.xcodeproj
```

Then in Xcode pick your device/team and **Product → Archive → Distribute App**
(Development) to install directly.
