# 0019. Music and sound generated in code, mixed on buses (D8)

- Date: 2026-09-25
- Status: Accepted
- Builds on `research/design-plan.md` §9 and ADR 0011. Supersedes the plan's sourcing line ("audition CC0 packs, Bar picks by ear") by Bar's call on 2026-09-25: generated in code, no downloaded packs.

## Context
The POC had three short chip loops and 37 effects, normalised by a home-made RMS measure, all on two buses with one round-robin pool. The plan wanted six cues with layers and an interactive boss track, about 70 effects with variants, a licence manifest with a failing test, a BS.1770 meter, a proper mix, a credits screen and a haptics map, at $0.

## Decision
- **Everything is generated** (`tools/gen_music.gd`, `tools/gen_audio.gd`, run by `tools/audio.sh`). It is original by construction, so ADR 0002 and the $0 budget hold with no licence risk. The manifest (`assets_src/audio/LICENSES.csv`) and its test still exist, so a CC0 or CC-BY file can replace any cue later with a row, and the credits screen names CC-BY rows automatically (`CreditsData`).
- **Music:** five cues (title and shop in D minor at 96 bpm; the Cellar in A minor and the Corrupted Grove in C# phrygian at 120 bpm, each as base, drums and lead stems; the boss in E minor at 128 bpm as intro, loop and a phase-2 lead) plus five stingers. 32 kHz mono WAV, QOA-compressed on import: there is no Vorbis encoder on the Mac, and MP3 cannot loop cleanly. Tempos make every bar a whole number of samples, so a 4-bar drum stem stays locked under a 32-bar base.
- **Adaptive playback:** the areas are `AudioStreamSynchronized` stems (drums while enemies are up, lead while an elite is); the boss is an `AudioStreamInteractive` whose intro hands over to the loop, with the phase-2 layer switched in on the next bar. Stingers play on Critical.
- **Effects:** 84 sounds, most a transient, a body and a tail; one timbre per element; telegraph cues are reversed swells that end exactly when the attack releases; the twenty busiest have three variants played through `AudioStreamRandomizer`.
- **Loudness:** `Loudness` measures BS.1770-4 integrated loudness at any sample rate (it reads the calibration tone to within 0.1 LU). Effects are normalised to -18 LUFS (UI -24) or as loud as a -1.5 dBFS ceiling allows; each music cue's full mix to -20 LUFS.
- **Mix:** Master has a -1 dB hard limiter; Music is ducked by a sidechain compressor keyed from Critical; voices are three classes (critical 4, combat 12, ui 3) that steal only within their class.
- **Haptics** only on getting hurt, crits (at most every 0.25 s), elite kills, boss phases and kills, and UI snaps.
- **Credits screen** from the title, including the Godot Engine and third-party licence texts the engine reports (required by their licences).
- **Web check:** the web build publishes the Music bus peak; `webtest.mjs` requires the music to play.

## Consequences
- 168 tests; `test_audio_d8.gd` covers the meter, the manifest, loudness targets, stems, layers and voice classes.
- The repo carries about 28 MB of music WAV. A full regeneration takes about three minutes.
- Bar has not heard it yet: the previews went to him, and his notes become a revision pass on the generators rather than a swap of files.
- The stress test changed method in the same milestone: on a desktop in use the mean tick swings 9-18 ms with the rest of the machine, so it now asserts the lower quartile of the full-storm ticks, best of two runs. An A/B against the pre-D8 commit showed no difference.
- **Not done:** true-peak metering (the ceiling is a sample peak with 0.5 dB of margin), per-area music beyond the two biomes, and a mixer screen.
