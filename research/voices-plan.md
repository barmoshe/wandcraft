# Wandcraft voices: a duck and a robot who speak (plan)

Bar's asks (2026-09-27):
- "Plan to add a robot narrator that speaks."
- "There should be both duck and robot characters who can speak."
- Real words, pre-rendered.

This plan builds on the story system in `research/plan-0.18.md` Step 1 (`game/scripts/sim/story.gd` and the HUD speech box). Research, with sources, is in the hand-back summarised under *Sources* below (engine licences, DSP, Godot limits).

## The two characters

| | **DUCK** | **LINT** (new) |
|---|---|---|
| Who | Your rubber duck. You debug out loud to it, and it talks back. Warm, dry, on your side. | The Guild's linting robot, sent in after the rollback failed. Precise, literal, deadpan, and always sure something is wrong (it usually is). |
| Job in the story | Personal: tips, encouragement, jokes, reactions | The system voice: world entries, boss warnings, "BUILD FAILED" when you die, "BUILD PASSED" when you win, reading found commit logs aloud, naming the heat tiers |
| Face in the speech box | `duck_face()` (hud.gd) | A new 12 px robot head (a monitor face with a cyan scanline eye) |
| Voice | Kokoro `af_heart` (or `af_bella`) at speed 1.1, then the duck chain | Kokoro `am_michael` (or `am_fenrir`) at speed 0.9, then the robot chain |

**The pair talk to each other.** Beats can be two-line exchanges, for example:
- DUCK: "It copied your wand." LINT: "Plagiarism detected."
- LINT: "Exception: apprentice not found." DUCK: "Found them. Try again."

LINT gives the world's news, and the Duck gives your side of it.

**Example LINT lines:**
- "Entering World 2. The Overheated Foundry. Temperature: unwise."
- "Warning. Infinite loop detected."
- "Build failed."
- "Commit c0ffee. Author: Moss. Message: why do I have eyes."

## How the lines are made (offline, committed as files)

**Engine: Kokoro-82M.**
- Its weights and every voice are Apache-2.0, it's used commercially, and its output is ours to ship.
- Run it on CPU with `torch.manual_seed(0)` before each line so the output is repeatable.
- Ruled out by their licences: macOS `say` (personal use only), Coqui XTTS (non-commercial), SAM (no licence), and the Piper `lessac`, `amy` and `ryan` voices (research-only or NC).
- espeak-ng is used only to turn text into phonemes, so none of its audio ends up in the output.

**Robot chain,** baked with numpy/scipy:
1. A channel vocoder on a 110 Hz saw carrier, 70% wet (the monotone).
2. A 50 Hz ring modulator at 40% (the Dalek sound).
3. A 6 ms comb filter with 0.6 feedback (metallic).
4. A 9-bit, 12 kHz sample-and-hold crush.
5. A high-pass at 150 Hz and a light compressor.

**Duck chain:**
1. +3 semitones of formant-preserving shift plus +3 semitones of varispeed (small, but not a chipmunk).
2. A band-pass from 250 Hz to 6 kHz.
3. +4 dB at 1.4 kHz (the honk).
4. A 6 Hz vibrato at 0.07 depth.
5. A +8% glide on the last word.

**Why bake it:**
- Godot has no ring modulator, vocoder or sample-rate reducer.
- The web build plays in sample mode, where bus effects don't run at all.
- Runtime effects are therefore limited to a ±2% `pitch_scale` for variety.

**Format and budget:**
- Mono, 24 kHz (Kokoro's native rate), QOA in the build, at about 9.6 KB/s.
- About 80 lines of about 3 s each comes to roughly 2.3 MB.
- Loudness is normalised per line to a dialogue target set with the sound session (about −18 LUFS, so it sits above the music's −20).

**Pipeline** (every new file here is this plan's):
- **`tools/export_lines.gd`** (Godot, headless) dumps every line from `Story` to `build/voice_lines.json`, one row per line: `{id, who, text}`.
  - `story.gd` stays the only place lines are written.
  - Every line gets a stable `id`, for example `boss.loop.1` or `log.c0ffee`.
- **`tools/gen_voices.py`** renders each line with Kokoro, then that speaker's chain, then normalises loudness. It writes `game/assets/voice/<who>_<id>.wav`.
  - `assets_src/voice/manifest.json` keeps the hash of text + voice + chain version, so only changed lines are rendered again.
- **`tools/voices.sh`** does the setup and the import:
  - one-time setup: creates `tools/.venv-voice` (git-ignored), runs `pip install kokoro soundfile numpy scipy pyloudnorm`, and checks for `brew espeak-ng`
  - runs the generator
  - re-imports with QOA compression, as `tools/audio.sh` does
  - appends rows to `assets_src/audio/LICENSES.csv`: "generated with Kokoro-82M (Apache-2.0)"
- **The credits screen** gets one line: "Voices synthesized with Kokoro-82M (Apache-2.0)".

## In the game

- **The content model:** `story.gd`'s LINES become `{id, who, text}`, and an event can hold an exchange of up to 2 lines. `Story.say(event)` emits `Events.say(who, text, id)`.
- **A new `game/scripts/autoload/voice.gd`,** separate from `audio.gd`, which the sound session owns:
  - one `AudioStreamPlayer` on a `Voice` bus
  - `play(id)` returns the line's length, and missing files fall back to text only
  - it is silent when `Game.quiet` is on, and when the voice setting is off
- **Pacing:**
  - Only one line plays at a time; exchanges play back to back.
  - Lines older than 6 s in the queue are dropped.
  - During fights, at most one non-boss line every 20 s. Boss beats, world entries and deaths always play.
- **Music under speech:** while a line plays, the Music bus dips −6 dB via `AudioServer.set_bus_volume_db` (bus volume works in the web build's sample mode) and returns over 150 ms. The sound session decides whether that becomes a sidechain on native builds.
- **The HUD speech box:**
  - It shows the speaker's face and name (DUCK in gold, LINT in cyan).
  - It stays up for the audio length plus 0.4 s, or the reading time if there is no audio.
  - Text is always shown, so it doubles as subtitles.
- **Settings:** the pause menu gets a VOICE toggle beside Sound and Music, on by default and stored in settings.

## Coordination with the sound session (it owns `audio.gd`, `tools/gen_*`, `game/assets/audio`, `research/sound-v2*.md`)

- **Its brief has to change.** `research/sound-v2.md` §2.2 says "No human voices… The Duck's babble is formant-synthesised and non-verbal", and its cue list includes `duck_say`/`glitch_say` babble. Bar's decision replaces both.
  - The ask to that session: amend §2.2 to allow two baked character voices on a Voice bus, and drop `duck_say` and `glitch_say`.
  - The Glitch's "???" lines can keep a short non-verbal sting.
- **Bus layout:** the sound session adds the `Voice` bus (routed to Master, dry) to the bus layout it is already rewriting (§6.1), and decides whether Critical cues cut through speech. This plan only uses the bus by name.
- **Loudness:** agree the dialogue loudness target and the music dip together.

## Steps (each one committed, with its hash logged here)

1. **Audition (checkpoint with Bar).**
   - Set up the pipeline, then render 6 lines for each character: two chain strengths, and two voices for each character.
   - Send the WAVs to Bar and let him pick the voices and the amount of processing before anything else is generated.
   - Also decide LINT's name, if Bar prefers another.
2. **The script.**
   - Refactor `story.gd` to `{id, who, text}` and add LINT.
   - Write about 80 lines:
     - world entries and area changes
     - four bosses, each with an entrance and a fall
     - deaths grouped by what killed you
     - a win
     - the 10 commit logs read aloud
     - the intro and ending panels, voiced
     - 8 Duck/LINT exchanges
     - the heat tiers
   - Put the script in `research/story.md`.
3. **Runtime.**
   - The `voice.gd` autoload.
   - Two speakers in the HUD box, with the LINT face art.
   - Queue and pacing, the music dip, and the VOICE toggle.
   - The intro and ending screens play their panels voiced.
4. **Generate, import, ship.**
   - Render every line, then check size (about 2–3 MB), loudness and length (at most 6 s per line).
   - Web test in sample mode, then 0.18.x.

## Verification

- **New tests (`tests/unit/test_voice.gd`):**
  - Every `Story` line has a WAV and a manifest hash that matches its text.
  - No line runs over 6 s.
  - Voice is silent when quiet is on or the voice setting is off.
  - The queue drops stale lines and never overlaps two.
  - Exchanges play in order.
- **Existing tests:** the loudness meter (the existing `Loudness` tool) checks every voice file is within ±1.5 LU of the target, and the licence manifest has a row for every voice file.
- **By ear:**
  - Play the audition set on a phone speaker and on headphones.
  - The LINT chain must stay intelligible: aim for 5 of 5 audition lines understood by Bar without reading.
- **Web:** check in the browser pane that lines play in the web build's sample mode, that the music dips and comes back, and that there are no console errors.

## Sources

The full research hand-back is in the session transcript of 2026-09-27; the key sources are these:
- Kokoro-82M model card and VOICES.md (Apache-2.0): https://huggingface.co/hexgrad/Kokoro-82M
- The macOS Tahoe 26 SLA §2.F, personal non-commercial use only: https://www.apple.com/legal/sla/docs/macOSTahoe.pdf
- The XTTS-v2 CPML, non-commercial: https://huggingface.co/coqui/XTTS-v2/blob/main/LICENSE.txt
- The Piper voice model cards (lessac is research-only; ljspeech is public domain): https://huggingface.co/rhasspy/piper-voices
- GNU GPL FAQ on output: https://www.gnu.org/licenses/gpl-faq.html#WhatCaseIsOutputGPL
- The Godot web build's sample playback and bus effects: https://github.com/godotengine/godot/issues/95991
- QOA bitrate: https://qoaformat.org
- The Dalek ring modulator: https://intelligentsoundengineering.wordpress.com/2016/04/04/ring-modulation-in-science-fiction/
