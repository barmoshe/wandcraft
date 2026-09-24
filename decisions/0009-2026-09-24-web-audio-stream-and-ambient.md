# 0009. Web audio: Stream playback and an ambient session

- Date: 2026-09-24
- Status: Accepted. It supersedes the "iPhone audio" part of 0008.

## Context
Bar still had no sound on the iPhone after 0008. The game also now claimed the phone's audio like a music app: a lock-screen player appeared and other audio paused. The ringer was on and the volume up.

Measuring real output settled it. `tools/webtest.sh` taps every connection to the audio destination and reads the peak level:
- **Godot's default web playback, "Sample", was silent in every browser:** peak 0.000 in Chromium too. The AudioContext still reported "running", which is why earlier checks missed it.
- All our sounds are QOA-compressed `AudioStreamWAV`, and the Sample path does not play them.
- Godot's own docs and open issues point the same way: Sample mode on iOS Safari has crashes and missing features, and "Stream" is the documented workaround (godotengine/godot #116750, #107390).

## Decision
- **Web audio uses Stream playback:** `audio/general/default_playback_type.web=0` in `project.godot`. With it, the title music measures a peak of about 0.13. Native builds are unaffected.
- **The page asks iOS for the "ambient" audio session**, which Bar chose:
  - The game mixes with the phone's music instead of pausing it.
  - There is no lock-screen player.
  - The silent switch mutes the game, as in most games.
- **Dropped from 0008:** the silent looping `<audio>` element and the "playback" session.
- **Kept from 0008:** resuming the engine's audio contexts on touchend, click, keydown and visibility.
- **`tools/webtest.sh` joins the checks.** It plays the build as a landscape iPhone and fails if the canvas doesn't fill the window, if the page throws errors, or if no sound comes out after the first tap.

## Consequences
- **Stream mode mixes on the main thread** (single-threaded web build). A busy fight on an older phone may crackle; if it does, raise `audio/driver/output_latency.web`.
- **Bus effects work in Stream mode**, so they are no longer off-limits on the web.
- **Test every web build with `tools/webtest.sh`**, locally or against the deployed URL.
