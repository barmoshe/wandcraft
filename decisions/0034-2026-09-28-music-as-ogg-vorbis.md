# 0034. Music ships as Ogg Vorbis

- Date: 2026-09-28
- Status: Accepted
- Supersedes the encoding line of ADR 0019 ("32 kHz mono WAV, QOA-compressed on import"). The rest of 0019 and ADR 0025 stand: the music is still generated in code, the same score, the same stems, layers and loop points. Research: `research/polish-0.22.md` ("Not taken").

## Context
- The web download is the pck, and music was the second biggest part of it: 11.21 MB of 28.31 MB, as QOA.
- ADR 0019 chose QOA because there was no Vorbis encoder on the Mac, and MP3 cannot loop cleanly.
- The pip package `soundfile` bundles libsndfile with libvorbis. So an encoder is one `pip install` away on Linux and on the Mac, with no system tools.
- The polish research asked for three things before the switch: this ADR, loop-seam work, and a phone profile.

## Decision
- **The music and the ambience beds ship as Ogg Vorbis, quality 4** (`game/assets/audio/music_*.ogg`, 24 files, 6.8 MB). The stems stay 32 kHz mono, the beds 22.05 kHz stereo.
- **Effects and stingers stay WAV with QOA.** They are short one-shots, the stingers land on the beat, and together they are 2.6 MB of the pck.
- **The WAV masters leave the repo.** `tools/gen_music.gd` writes them to `build/music_wav/`, which git ignores. The generator is the source, and it is deterministic, so the 55 MB of music WAV in the tree was a build product. Git history still holds the old files.
- **The pipeline** (`tools/audio.sh`):
  - gen_music writes the masters and prints each loop window, as before.
  - `tools/encode_music.py` writes the Oggs. It runs in a venv (`tools/.venv-audio`, set up on first run from `tools/requirements-audio.txt`, which pins `soundfile`).
  - audio.sh writes `loop=true` and `loop_offset` into each `.ogg.import`.
- **Loops.** An Ogg loops by playing to its end and seeking back to `loop_offset`. So the encoder cuts each master at `loop_end` and drops the WAV's guard sample. `loop_offset` is `loop_begin / rate`: 6.4 s for the boss, 3.75 s for the mini boss, 0 for the rest. The intros still play once, and the bar clock is unchanged.
- **Stems stay locked.** Every stem is still a whole number of bars, and each loops back to the same point.
- **Deterministic.** libvorbis is deterministic. libsndfile picks a random Ogg serial number, so the encoder replaces it with a CRC of the file name and redoes each page checksum. Two runs give the same bytes.
- **Code.** `Audio.audio_path()` maps `music_*` to `.ogg` and everything else to `.wav`. `stream()`, `track_ready()` and `music_v2()` use it.

## Checks
- **Seams, in the engine.** `test_music_loops_are_seamless` plays every Ogg through Godot's own playback across its seam, one output frame per sample. What follows the end matches a playback started at the intended loop point, sample for sample, for all 24 files. A loop point moved by one sample fails it.
- **Seams against the WAV.** The first builds were compared with the WAV masters through the same mixer. The seam lands on the same sample (shift 0), and the step across it is the same as the WAV's.
- **Codec error.** Vorbis is a perceptual codec, so its waveform error is larger than QOA's. Each loop's first 20 ms are encoded with silence before them. Their error is inside the range of other transients in the same file. The shop's is the highest (a little above its own 95th percentile).
- **Peaks.** Every decoded Ogg peaks at or under -4.5 dBFS.
- **Decode cost.** 60 s of the Cellar (three stems) plus its bed takes 250 ms to mix as Ogg and 92 ms as QOA, on one 2.1 GHz server core. That is 0.4% of a core against 0.15%.
- **Web.** `tools/webtest.sh` passes on the new build in headless Chromium, and the title music plays. The web export mixes in the engine (`default_playback_type.web=0`), so the browser never decodes the Ogg itself.

## Consequences
- **The web pck goes from 28.31 to 24.31 MB** (gzip-9: 25.59 to 21.65 MB). Music in the pck goes from 11.21 to 7.21 MB.
- `test_audio_budget.gd` counts `.ogg.import` too. Imported audio went from 13.74 to 9.74 MB, and the budget drops from 28 to 24 MB.
- A clone is about 55 MB lighter. A fresh machine needs `tools/audio.sh` (a few minutes) to get the masters back, for example to audition them as WAV.
- `tools/audiosheet.sh` lists the Oggs.
- The research note said about 5 MB. It is 4 MB at quality 4. Quality 3 would save 0.6 MB more; quality 5 about 0.8 MB less.
- **Not done:**
  - Nobody has listened on a phone yet. Bar should A/B the title and the shop, whose loop start carries the most codec error, on a phone speaker and on headphones.
  - The decode cost was measured on a desktop core, not on a phone. Profile an iPhone and a low-end Android before the store build.
  - The bytes are the same only with the same libsndfile build. A different wheel or CPU may give different, equally valid bytes.
