# wandcraft — scope

The agreed, buildable contract for this project. It is derived from `brief.md`. Revisit it only via an ADR.

## Problem
The Wandcraft prototype lives in a single HTML file on claude.ai. It can't be sold, installed or trusted on a phone, and its content borrows Magicraft's names and text. We need a store-grade game with original content that runs at a phone's native refresh rate and passes App Store and Google Play review.

## Appetite
Several weeks of agent work across sessions. The quality bar is production-grade: this is a store release.

## Solution sketch
- **Engine and language:** Godot 4.7 with typed GDScript.
- **Proven design, ported:** the v3-v5 rules (wand programming engine, triggers, door-choice rooms, 5 worlds with 10 bosses, Magicraft-style HUD) are ported as clean, tested code.
- **Original content:** every spell, relic, wand, enemy and boss gets our own name, text and balance.
- **Generated assets:** all art and audio come from deterministic generators in `tools/`.
- **Platform services:**
  - StoreKit 2 and Game Center on iOS.
  - Play Billing and Play Games on Android.

## Acceptance criteria
- [ ] Runs at 60fps (120 on ProMotion) on a mid-range iPhone and Android phone with 45 enemies and 1000+ bullets on screen.
- [ ] A full run (5 worlds, 10 bosses) is completable, and a headless bot completes it in CI-style tests.
- [ ] The wand engine is covered by golden tests, and a sweep of every spell against every boost and trigger shows no errors and nonzero damage.
- [ ] World 1 is free. The "Full Game" unlock works, can be restored, and is verified in the App Store sandbox and Play license testing.
- [ ] Game Center and Play Games achievements and a leaderboard work.
- [ ] No content is copied from another game; a manual review is done before submission.
- [ ] Store readiness:
  - [ ] Privacy manifest and labels.
  - [ ] Age rating answered.
  - [ ] Screenshots at the required sizes.
  - [ ] Icon, including an iOS 26 layered icon.
  - [ ] Export compliance key set.
- [ ] The app is approved and live on both stores.

## No-gos (v1)
- Ads, consumable IAP, loot boxes or any gacha.
- Online multiplayer and accounts.
- Analytics SDKs.
- Cloud save. This comes after launch: iCloud KVS on iOS, Play Games Saved Games on Android.
- Localization beyond English. The `tr()` keys are there from day one.

## Rabbit holes
- **IP:** close resemblance to Magicraft's look and feel (Tetris v. Xio). Mitigation: original art, text and names, plus a signature twist.
- **iOS store plugins:** GodotApplePlugins requires iOS 17+, and godot-storekit2's API is not stable yet. Pin versions and test in the sandbox early.
- **Rendering on older devices:** Metal builds need A12+. The fallback is the Compatibility renderer on a low quality tier.
- **Google Play:** new personal accounts need a closed test (reportedly 12 testers for 14 days). Start it early.
