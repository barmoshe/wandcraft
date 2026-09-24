# First iPhone build: step by step (Bar's Mac)

iOS apps can only be built and signed on a Mac with Xcode. Everything else (game, icon, export settings) is already in the repo. Budget about an hour the first time.

## What you need
- A Mac with **Xcode 26** from the App Store. Apple requires the iOS 26 SDK for uploads.
- **Godot 4.7.2** (the standard build, not .NET) from godotengine.org, plus its **export templates**: in Godot, *Editor → Manage Export Templates → Download and Install*.
- An **Apple Developer account** ($99/yr). Without one you can still run the game on your own iPhone for 7 days with a free Apple ID. TestFlight needs the paid account.
- Your iPhone, a cable, and **Developer Mode** turned on (*Settings → Privacy & Security → Developer Mode*).

## 1. Get the project
```bash
git clone <bar_builds repo> && cd bar_builds
git checkout claude/artifact-short-game-6qq646   # until it is merged
open -a Godot projects/wandcraft/game/project.godot
```
The first open takes a minute while Godot imports the art and audio.

## 2. Try it on the Mac first
Press **Play** (▶). Controls:
- WASD to move, hold the mouse to aim.
- Tab for the wand editor, Esc to pause.

## 3. Fill in your identity (once)
*Project → Export… → iOS* (the preset is already there):
- **App Store Team ID:** your 10-character Team ID, from developer.apple.com → Membership.
- **Bundle Identifier:** `com.barbuilds.wandcraft` is a placeholder. Pick the final one now. It can't change after the first App Store upload. Use the same one on Android.
- Leave everything else as it is. The preset already sets:
  - The icon.
  - Landscape orientation.
  - iOS 17 minimum.
  - `ITSAppUsesNonExemptEncryption = NO` (no export-compliance questions).
  - `CADisableMinimumFrameDurationOnPhone` (120 Hz on ProMotion iPhones).
  - Privacy: no tracking.

Godot saves the Team ID in `.godot/export_credentials.cfg`, which is git-ignored, so nothing private reaches the repo.

## 4. Export and run on your iPhone
1. In the export dialog, choose **Export Project…**, pick a folder outside the repo (for example `~/wandcraft-ios`), and untick **Export With Debug** for a smoother build.
2. Open the generated `.xcodeproj` in Xcode.
3. Select the **Wandcraft** target → **Signing & Capabilities** → tick *Automatically manage signing* and choose your team.
4. Plug in the iPhone, select it as the run destination, and press **Run**.
5. The first time, the iPhone asks you to trust the developer: *Settings → General → VPN & Device Management*.

## 5. TestFlight (paid account)
1. In App Store Connect → **My Apps → +**, create the app with the same bundle id. The name must be unique on the store; it is still a working title (see STATUS).
2. In Xcode: *Product → Archive*, then **Distribute App → App Store Connect → Upload**.
3. After processing (about 15–30 min), add yourself as an internal tester in TestFlight and install from the TestFlight app.

## What to check on the phone
- The game fills the screen and the HUD avoids the Dynamic Island.
- The frame rate stays smooth in a busy fight (ProMotion phones should run at 120 Hz).
- Sound plays, and the vibration setting works.
- Backgrounding the app mid-fight, then reopening, lands in the pause menu.
- The 2D lighting looks like the screenshots (ADR 0004: check that `hdr_2d` really needs to be off on Metal).

Send a short screen recording of a fight. It is the fastest way to tune the feel.
