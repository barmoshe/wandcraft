# 0006. v0.3: generated audio, a feel pass, a balance guardrail, and phone builds

- Date: 2026-09-24
- Status: Accepted

## Context
v0.2 had these gaps:
- It was silent.
- It never ran on a phone.
- Its balance was proven only by a god-mode bot.

Bar asked for "feel + phone build" and will test on both platforms. This container has no numpy and no ffmpeg, but it does have Java, the Godot export templates and the Android SDK.

## Decision
- **Audio is generated, not licensed.**
  - `tools/gen_audio.gd`, a headless Godot script, ports our own prototype synth (oscillators with a pitch slide, filtered noise). It renders 34 SFX and 3 music loops to WAV, imported as QOA.
  - The output is deterministic: two runs give identical bytes.
  - The `Audio` autoload plays SFX through a pool with per-sound rate limits and crossfades the music.
- **The feel pass has to be switchable:**
  - Hit-stop lives in the simulation step, so tests stay deterministic.
  - Flashes are white and rate-limited, behind a setting.
  - Haptics sit behind a setting.
  - Every accessibility-sensitive effect has an off switch in pause.
- **Tips, not a tutorial:** six contextual tips, each shown once and queued, reset from pause.
- **Balance has a guardrail.**
  - `tools/balance.sh` runs a non-god bot over 10 seeds and must land at 40–85% survival, with boss times in range and **no stalls**.
  - It lives outside `tools/test.sh` because it takes minutes.
  - Results are in `research/balance-w1.md`.
- **Phone builds:**
  - `export_presets.cfg` is committed without secrets.
  - Android: an arm64 APK, min SDK 24, built here by `tools/build_android.sh` with the toolchain cached outside the repo and a throwaway debug key.
  - iOS: exported on Bar's Mac per `store/ios-first-build.md`.
  - The app icon is generated from the game's own sprite (`tools/icon.sh`).
  - The bundle and package id `com.barbuilds.wandcraft` is a placeholder until Bar decides.

## Consequences
- Anyone can regenerate all art, icons and audio from code. There are no binary sources to lose.
- The balance bench found four real gameplay bugs (a wand reward taking the hand, bodies stuck in walls, aim from the feet, crates blocking aim). Keep it running after every tuning change.
- Play Store and App Store releases still need Bar's release key, accounts and final ids (M5–M7).
