# Wandcraft in the browser: play on the iPhone today

**Link: https://wandcraft-test.vercel.app**

This is the web version of the game. It needs no Mac, no Apple account and no App Store. Use it to test gameplay and art on your phone while the native iOS build waits for TestFlight (see `ios-first-build.md`).

## On the iPhone 15 Pro Max
1. Open the link in **Safari**. The first load downloads about 40 MB; after that it's cached.
2. Tap **Share → Add to Home Screen → Add**. Wandcraft now has its own icon and opens full screen, without Safari's bars.
3. Hold the phone **sideways** (landscape). In portrait the game asks you to turn it.
4. Tap anywhere once so sound can start (Safari only allows audio after a tap).

The game fills the whole screen, including behind the Dynamic Island. The HUD and menus stay clear of the island, the rounded corners and the home bar.

**Black bars or a cut-off bottom?** The icon was added before the full-screen fix (2026-09-24). iOS remembers a web app's settings from when its icon was added. To fix it:
1. Long-press the icon and choose **Remove App → Delete from Home Screen**. This also deletes the run saved inside that icon: iOS gives each Home Screen app its own storage.
2. Open the link in Safari and reload once.
3. Add the icon to the Home Screen again.

## How it differs from the native app
- **Renderer:** the browser version uses Godot's WebGL renderer. Lights and glow can look slightly different.
- **Performance:** it runs a little slower than a native build. A busy fight is the thing to watch.
- **Vibration:** iPhone Safari does not allow vibration.
- **Saves:** they live in the browser storage of whatever opened the game. Safari and the Home Screen icon each keep their own, and deleting the icon deletes its saves.

## Publishing a new version (from the repo)
```bash
tools/build_web.sh     # exports build/web (single-threaded, works in iPhone Safari)
tools/deploy_web.sh    # uploads it to Vercel (project wandcraft-test); needs `vercel login` once
```
The page itself is `game/web/shell.html`: Godot's default web page, changed to fill the iPhone screen and to report the safe-area insets to the game (`Game.safe_rect`).

If the phone keeps showing the old version, close the app and open it again. The offline cache updates on the next launch.
