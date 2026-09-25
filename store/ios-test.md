# Wandcraft on your iPhone 15 Pro Max: test build (no App Store)

This installs the game on **your own iPhone**, straight from your Mac over a cable.

- No paid Apple Developer account is needed. Your normal Apple ID is enough.
- Nothing goes to the App Store.
- The first time takes about 45 minutes, mostly downloads. After that each new version takes about 2 minutes.

**Your phone is a good match:**
- The iPhone 15 Pro Max runs iOS 17 or newer, which the game requires.
- Its A17 Pro chip is far above what the game needs.
- The game already asks for 120 Hz (ProMotion) and keeps the HUD clear of the Dynamic Island.
- The cable is **USB-C**, so a USB-C Mac port or the cable that came with the phone works.

## What you need
- A Mac with a recent macOS that runs Xcode 26
- The iPhone and a USB-C cable
- Your Apple ID (the one on the phone is fine)

## One-time setup

1. **Xcode:** install it from the Mac App Store (free, large download). Open it once and let it install its extra components.

2. **Godot 4.7.2:** download it from godotengine.org (the standard build, not .NET).
   - Drag `Godot.app` into `/Applications`.
   - Open it and choose **Editor → Manage Export Templates → Download and Install**.

3. **The project:**
   ```bash
   git clone https://github.com/barmoshe/wandcraft.git
   cd wandcraft
   ```

4. **Your Apple ID in Xcode:** go to **Xcode → Settings → Accounts → + → Apple ID** and sign in.
   - A team called **"Your Name (Personal Team)"** appears.
   - Its **Team ID** is a 10-character code. It is also shown when you pick the team under Signing in step 2 of "Every new version".

5. **The Team ID in Godot:**
   - Open `game/project.godot` in Godot. The first import takes about a minute.
   - Go to **Project → Export → iOS**, paste it into **App Store Team ID**, then close the dialog.
   - If git later shows that line as changed, don't commit it. It is local to your Mac.

6. **On the iPhone:** go to **Settings → Privacy & Security → Developer Mode** and turn it on.
   - The phone restarts and asks you to confirm.
   - If the option is missing, it appears after the phone has been connected to Xcode once.

## Every new version

1. In Terminal, inside `wandcraft`:
   ```bash
   git pull
   tools/export_ios.sh
   ```
   The script checks that everything is installed, writes the Xcode project to `~/wandcraft-ios` (outside the repo), and opens it in Xcode.

2. In Xcode:
   - Click **Wandcraft** (the blue project icon at the top left).
   - Open the **Signing & Capabilities** tab.
   - Tick **Automatically manage signing** and pick your Personal Team.

3. Plug in the iPhone, choose it in the device menu next to the ▶ button, and press **▶ Run**.

4. **First time only,** on the iPhone:
   - Go to **Settings → General → VPN & Device Management**, tap your Apple ID, then **Trust**.
   - Press ▶ Run again.

## Limits of the free route
- **7 days per install.** After a week the app stops opening. Plug the phone in and press ▶ Run again; there is no need to re-export.
- **Only your own devices.** You can't send the build to friends.
- **At most 3 apps** installed this way at once.

To share with friends later you need **TestFlight**. That requires the $99/year Apple Developer Program, and it still does not publish to the store. See `ios-first-build.md`, step 5.

## What to check on the phone
- Buttons respond to taps: NEW RUN, reward cards, WANDS and PAUSE.
- The game fills the screen, and nothing important sits under the Dynamic Island. Try both landscape directions.
- A busy fight stays smooth at 120 Hz.
- Sound plays, and haptics work. Vibration can be turned off in PAUSE.
- Leaving mid-fight and coming back lands you on the PAUSE screen.

A screenshot or a short screen recording of a fight is the most useful feedback.

## If something goes wrong

| You see | Do this |
|---|---|
| Script: "Xcode not found" | Install Xcode, open it once, then run `sudo xcode-select -s /Applications/Xcode.app` |
| Script: "export templates missing" | In Godot: Editor → Manage Export Templates → Download and Install |
| Script: "No Team ID yet" | Do steps 4 and 5 of the one-time setup |
| Xcode: "Signing requires a development team" | Pick your Personal Team under Signing & Capabilities |
| Xcode: "Developer Mode disabled" | On the phone: Settings → Privacy & Security → Developer Mode |
| Phone: "Untrusted Developer" | Settings → General → VPN & Device Management → Trust |
| The app stopped opening after a week | That's the 7-day limit. Plug in and press ▶ Run again |
| Xcode: the bundle ID is taken | Under Signing, change the Bundle Identifier to something unique, e.g. `com.bar.wandcraft.test` |
