# GitHub → IPA → iPhone (Windows, no Mac)

Follow this once. After that, rebuilding is just "run the workflow again."

---

## 1. Create the repository

1. Go to <https://github.com/new> while signed in.
2. **Repository name:** `frickbears3-ios` (any name works).
3. Leave it **Public** (free macOS build minutes).
4. **Do not** tick "Add a README" or "Initialize with a license" — just create.

### Method A — GitHub Desktop (recommended, handles hidden folders)

1. Download <https://desktop.github.com/> and sign in.
2. **File → Clone repository** → pick the empty repo you just made → clone it.
3. In Windows Explorer, open the cloned repo folder and copy **the contents**
   of this `Frickbears3iOS` folder into it (not the folder itself).
4. Back in GitHub Desktop, you'll see all files listed. Write a summary like
   "initial port" and click **Commit to main**, then **Publish origin**.

### Method B — browser upload

1. On the next screen after creating the repo, click **uploading an
   existing file**.
2. In Windows Explorer, open this `Frickbears3iOS` folder. In the **View**
   ribbon tick **Hidden items** so you can see `.github`.
3. Select everything inside (`Ctrl+A`) and drag it into the GitHub upload box:
   - `.github`, `App`, `Game`, `Scripts`
   - `CREDITS.md`, `GITHUB-SETUP.md`, `README.md`, `project.yml`
4. Click **Commit changes**.

> Don't upload the outer `Frickbears3iOS` folder itself — GitHub should end up
> with `project.yml` at the root of the repo. If `.github` is missing, the
> Actions workflow won't exist and there will be nothing to run.

---

## 2. Run the build

1. In the repo, click the **Actions** tab.
2. If you see "Get started with GitHub Actions", ignore it — the workflow file
   is already there from `.github/workflows/build-ipa.yml`.
3. In the left sidebar click **Build Frickbear's 3 4LD iOS IPA**.
4. Click **Run workflow** (right side) → **Run workflow**.
5. Wait 5–10 minutes. You can watch the live log; the last steps should say
   `Build succeeded` and print the IPA file size.

**If it fails:** click the red run → the failed job → scroll to the red error
line and read it. The most common causes are a missing `Game/index.html` (make
sure you uploaded the whole folder) or a temporary macOS runner issue (re-run
the workflow). The game data is fetched by the app itself, so there is no big
download during the build.

---

## 3. Get the IPA onto your PC

1. Go back to the completed workflow run.
2. Scroll to **Artifacts** → click **Frickbears3-4LD-IPA**.
3. It downloads as `Frickbears3-4LD-IPA.zip`. Extract it.
4. Inside is `Frickbears3iOS.ipa` — that's your app. (The filename stays the
   same because it is the Xcode target name; the 4LD build is inside.)

---

## 4. Sign and install with Sideloadly

1. Download Sideloadly from <https://sideloadly.io/> and install it on Windows.
2. Connect your iPhone with USB. On the phone, tap **Trust** if asked.
3. In Sideloadly:
   - **Apple ID:** your free Apple ID email
   - **Password:** an *app-specific* password from <https://appleid.apple.com>
     (your normal password often fails)
   - **IPA:** drag `Frickbears3iOS.ipa` into the box
   - **Bundle ID:** change to something unique like `com.yourname.frickbears3`
4. Click **Start**. It may ask for the 6-digit 2FA code — enter it.
5. When it says "Installed", on the iPhone go to:
   **Settings → General → VPN & Device Management → your Apple ID → Trust**.

Free Apple ID certificates expire after **7 days**. When the app stops opening,
just repeat step 4 to refresh it — your save data stays.

---

## 5. Rebuilding after a change

Any edit you make to files in the repo (for example the default mapping in
`App/TouchMappingStore.swift`) just needs a new **Run workflow**, then repeat
steps 3–4. Remapping *on the device* via the ⚙ button does not need a rebuild.
