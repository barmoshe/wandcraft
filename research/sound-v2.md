# Wandcraft sound v2: research, sonic brief, synthesis toolkit, cue spec, music, mix

- Date: 2026-09-27. Author: the studio's Audio Director (wave 1: research and design only; no code or audio changed).
- Goal (Bar): research, design and improve the game's sound design: reinvent and redesign every sound, and redevelop the relevant code.
- Binding constraints: everything stays **generated in code** by deterministic generators in `tools/` (ADR 0019, ADR 0002). There are no downloaded packs. The Loudness meter and the licence-manifest flow in `tools/audio.sh` stay. Phone speakers come first, then earbuds, then iOS Safari (Stream playback, main-thread mixing). Files are QOA-compressed on import.
- Reconciles with: `research/sound-v2-runtime-audit.md` (the Game Developer's audit, written in parallel and **folded in here**). Anything below marked **HOOK** or **RUNTIME** is a request to that role. Every place this document **accepts** or **objects to** a Developer proposal is tagged **[DEV-Ax: ACCEPT]**, **[DEV-Ax: ACCEPT, amended]** or **[DEV-Ax: OBJECT]**, and all of them are collected in §10.

---

## 1. Research findings and a critique of the current audio

### 1.1 What the reference games do (mechanics of the sound, nothing copied)

| Finding | What we take from it | Source |
|---|---|---|
| **Enter the Gungeon keeps the player's guns deliberately soft.** Community analysis explains it: louder guns would drown out off-screen enemy fire and cut the warning time. Each enemy also has a death sound, so you know an off-screen kill landed. | The player's casts are the quietest combat family. Enemy intent is louder than your own output. A kill always confirms, even off-screen. | [Steam discussion "Why do the guns sound so weak"](https://steamcommunity.com/app/311690/discussions/0/3103518890053783142/) (a community source, so treat it as practitioner lore), [ETG wiki: Sound Effects](https://enterthegungeon.wiki.gg/wiki/Sound_Effects) |
| **Overwatch mixes by importance, not by physics.** Sounds go into priority buckets, and only one "high importance" sound is allowed at a time. Enemy footsteps are louder than allies'. Threat is scored per listener. | Voice classes carry priorities and per-cue caps. Only the Critical class may duck other classes. Threats beat self-feedback. | [GDC 2016, Lawlor & Neumann, "Play by Sound"](https://gdcvault.com/play/1023317/Overwatch-The-Elusive-Goal-Play), [PC Gamer summary](https://www.pcgamer.com/how-overwatch-uses-sound-to-pinpoint-threats-you-cant-see/), [Awesome Game Audio notes](https://awesomegameaudio.wordpress.com/2017/02/06/overwatch-play-by-sound/) |
| **DICE's HDR audio treats loudness as priority.** A sliding window follows the loudest sounds and culls whatever falls under it. "Every sound is important, but not at the same time." | Cues that fall far below the current loudest event get dropped, not mixed. Here that becomes a per-cue cap plus priority-steal rule. | [Frostbite: How HDR audio makes Battlefield go BOOM](https://www.ea.com/frostbite/news/how-hdr-audio-makes-battlefield-bad-company-go-boom), [Designing Sound: HDR in Wwise](https://designingsound.org/2013/06/21/finding-your-way-with-high-dynamic-range-audio-in-wwise/) |
| **Hades uses vertical stems.** Drums come on while enemies are present and drop when the last one dies. Stems are chosen semi-randomly per chamber, and the between-fight mix thins to bass only, bass and guitar, or nothing. Bosses get the full band. | Keep drums-with-enemies and lead-on-elites. Thin the base between waves. Give the final boss a finale layer. | [Laced Records: How Rock Band influenced Hades](https://www.lacedrecords.com/blogs/blog/how-rock-band-influenced-hades-soundtrack), [Everything Is Noise: Korb](https://everythingisnoise.net/features/sound-test-darren-korb-and-supergiant-games/), [JSMG interview with Korb](https://online.ucpress.edu/jsmg/article/6/1/8/205397/Interview-with-Darren-Korb) |
| **Peggle 2 plays peg hits as ascending diatonic scales that follow the harmony of the current music phrase.** Stingers and timpani stay in tune with the bed. | Kill chains, coin chains and the wand's slot order pitch-walk on a scale in the area's key. Stingers are rendered in the area's key. | [GANG: Peggle 2, Sonic Joy](https://www.audiogang.org/peggle2-sonic-joy/), [GANG: Peggle Blast peg hits and the music system](https://www.audiogang.org/peggle-blast-peg-hits-and-the-music-system-2/) |
| **Vlambeer / Nuclear Throne favour feedback over fidelity.** Crunchy, loud explosion sounds are paired with shake and a frame of pause. Joonas Turner's explosions carry the impact. | Impacts need a saturated, harmonically rich body that survives small speakers, plus a hit-stop-synchronised duck. | [Nijman, "The Art of Screenshake"](https://www.youtube.com/watch?v=AJdEqssNZ-U), [CONTROL500: Explosions in Nuclear Throne](https://ctrl500.com/game-design/explosions-in-vlambeers-nuclear-throne/), [Game Developer: Meet Joonas Turner](https://www.gamedeveloper.com/business/meet-joonas-turner-vlambeer-s-sound-guy) |
| **Enemies firing in sync with identical sounds get very loud.** Desync them and randomise variants. | Per-cue caps, burst merging and real recipe variants, not only pitch. | [SFX Engine: sound design for games](https://sfxengine.com/blog/sound-design-for-games) (practitioner blog) |
| **Brotato's designer built enemy-hit sounds as a small composition of whoosh, hit and "ouch".** | Every hit is transient + body + (optional) tail. | [Brotato Steam discussion](https://steamcommunity.com/app/1942280/discussions/0/3364776031348224108/) (designer comment; lore-grade) |
| **Noita, Vampire Survivors and Magicraft** have no public, citable account of their audio method (searched: [Noita press](https://noitagame.com/press/), [Noita wiki interviews](https://noita.wiki.gg/wiki/Official_Interviews_and_Videos)). | They are cited here as feel references only, never as method sources. | — |

### 1.2 Game-audio practice this design relies on

- **Loudness for mobile:** Sony's ASWG recommends about -18 LUFS for portable games. GANG, via console makers, cites -16 LUFS for portable against -24 for console, because portable play happens in noise. ([ASWG-R001](http://gameaudiopodcast.com/ASWG-R001.pdf), [Designing Sound: Garry Taylor interview](https://designingsound.org/2012/07/30/video-games-and-loudness-standards-interview-with-sonys-garry-taylor/), [Audio Media International: mobile loudness](https://www.audiomediainternational.com/feature/mobile-loudness-an-adaptive-approach))
- **Short-window loudness:** EBU R128 defines momentary loudness over a 400 ms sliding window. That is the right yardstick for sub-second effects, whose integrated value is ill-defined. ([EBU R128](https://tech.ebu.ch/docs/r/r128.pdf), [EBU loudness](https://tech.ebu.ch/loudness))
- **Phone speakers:** small devices cannot produce much output below about 250 Hz. Designing with a 300 Hz high-pass as the phone model is standard, and the phantom fundamental (harmonics that imply a missing fundamental) is the tool that carries weight. ([Audiokinetic: loudness and frequency response on popular phones](https://www.audiokinetic.com/en/loudness-and-frequency-response-on-popular-smart-phones/), studio references `mix-and-mastering/references/small-speaker-translation.md` and `frequency-slot-map.md`)
- **Synthesis literature:**
  - Farnell, *Designing Sound*: any effect can be built from first principles by analysis, then synthesis. ([MIT Press](https://mitpress.mit.edu/9780262014410/designing-sound/))
  - The Karplus-Strong algorithm and its extended form (Jaffe & Smith 1983). ([CCRMA: KS](https://ccrma.stanford.edu/~jos/pasp/Karplus_Strong_Algorithm.html), [CCRMA: extended KS](https://ccrma.stanford.edu/~jos/pasp/Extended_Karplus_Strong_Algorithm.html))
  - Modal synthesis as a bank of damped resonators: free-bar ratios 1 : 2.756 : 5.404 : 8.933, and higher modes decay faster. ([Tonalux: modal resonator banks](https://tonalux.org/blog/modal-synthesis-resonator-banks-explained), [Perceptual evaluation of modal impacts](https://www.researchgate.net/publication/333661332_Perceptual_Evaluation_of_Modal_Synthesis_for_Impact-Based_Sounds), [CCRMA: FM for inharmonic spectra](https://ccrma.stanford.edu/software/clm/compmus/clm-tutorials/fm2.html))
  - The Cytomic (Simper) trapezoidal state-variable filter, which is stable under audio-rate modulation. ([SvfLinearTrapOptimised2.pdf](https://www.cytomic.com/files/dsp/SvfLinearTrapOptimised.pdf))
  - Freeverb/Schroeder comb and allpass lengths. ([CCRMA: Freeverb](https://ccrma.stanford.edu/~jos/pasp/Freeverb.html))
- **QOA** stores 3.2 bits per sample (1/5 of 16-bit PCM). It works on 20-sample slices with an LMS predictor. Its artifact is added white noise, audible at high listening levels on quiet material. It does not low-pass the signal. ([phoboslab: QOA](https://phoboslab.org/log/2023/02/qoa-time-domain-audio-compression), [QOA spec](https://qoaformat.org/)) **Consequence:** long, very quiet tails (reverb decaying past about -50 dBFS) are where QOA hiss shows. Tails get a hard fade to zero and are trimmed.
- **Godot runtime facts that shape this design:**
  - `AudioStreamInteractive` can switch on the next beat or bar, but that needs tempo metadata. `AudioStreamWAV` has no `bpm`/`beat_count`/`bar_beats` ([AudioStreamWAV docs](https://docs.godotengine.org/en/latest/classes/class_audiostreamwav.html), [AudioStreamInteractive docs](https://docs.godotengine.org/en/latest/classes/class_audiostreaminteractive.html), [Blips: 4.3 music features](https://blog.blips.fm/articles/the-new-music-features-in-godot-43-explained)). **Bar-quantised layer switches must therefore stay clock-driven in `audio.gd`** (as the boss's p2 is today), or the music moves to Ogg, which ADR 0019 rules out.
  - The Developer's 4.7.2 probe adds three facts:
    - `get_playback_position()` is correct on an `AudioStreamSynchronized`;
    - it is **always 0 on an `AudioStreamInteractive`** (so today's boss intro → loop hand-over hides the clock);
    - the headless Dummy driver mixes, so bar-clock tests can run in `tools/test.sh`.
  - Known web issues: `pitch_scale` reset by `play()` in web exports ([#95850](https://github.com/godotengine/godot/issues/95850); the workaround is to set it after `play()`; `AudioStreamPlayer2D` is not affected), and composite streams crashing on pause in *Sample* mode ([#109728](https://github.com/godotengine/godot/issues/109728); we use Stream mode, so we are not affected). Stream mode mixes on the main thread and crackles when frames drop ([Godot: web export in 4.3](https://godotengine.org/article/progress-report-web-export-in-4-3/)). **The runtime audit must confirm #95850 on 4.7.2 web before the pitch-walk ships.**

### 1.3 Critique of the current audio (measured, not by ear)

I analysed the shipped WAVs with a spectral script (FFT energy by band) and a phone-speaker model (4th-order high-pass at 300 Hz, low-pass at 12 kHz). The scripts are in the session scratchpad and are reproducible.

| File | Energy below 300 Hz | Dominant band | Loss through phone model | Verdict |
|---|---|---|---|---|
| `sfx_boom` | 88% | 100–200 Hz | **-6.0 dB** | The player's explosions are mostly sub-phone: a "pff" on an iPhone |
| `sfx_bigboom` | 92% | 100–200 Hz | **-8.4 dB** | Boss death is quieter on a phone than a coin |
| `sfx_slam` | 91% | 100–200 Hz | **-8.5 dB** | The golem's slam, a Critical cue, vanishes on phones |
| `sfx_roar` | 71% | 100–200 Hz | -5.1 dB | Boss phase roar thins out |
| `sfx_hurt` | 61% | **100–200 Hz** | -3.4 dB | The most important cue has its peak band below the phone's range |
| `sfx_kill` / `kill_mid` | 64% / 72% | 200–400 Hz | -2.1 / -3.0 dB | The classic 8-bit "bloop" slides down out of range |
| `sfx_hit` | 0% | **12.8–20 kHz** (centroid 12 kHz) | -2.9 dB | The most frequent sound in the game is hiss above what a phone plays |
| `sfx_crit` | 0% | 1.6–3.2 kHz (93% in 1.5–4 kHz) | -1.2 dB | Same band as `cast_ice` (97.5%) and `hit_ice` (95.6%): a frost build masks its own crits |
| `sfx_tele_*` | 0% | **400–800 Hz** | -0.3 dB | Same dominant band as `music_cellar_lead` (400–800 Hz). The music lead masks the telegraph, with only a 4:1 duck to help |
| `music_cellar_drums` | 87% | 100–200 Hz | **-7.3 dB** | The "combat starts" layer is nearly inaudible on a phone |
| `music_boss_loop` | 86% | 100–200 Hz | -7.2 dB | The boss band loses its drums and bass on phones |

**Synthesis.** Every primitive is one oscillator with an exponential decay tied to the note length, a fixed 3 ms attack and a one-pole (6 dB/oct) static noise filter. That gives:
- no resonant or moving filters (so no zaps, whooshes or vowel-like growls);
- no saturation (so no phone-audible harmonics on low bodies);
- no pitch envelope other than a start-to-end slide;
- no modal or physical models (so "ice", "armor" and "forge" are square waves at 1.5–3 kHz, not glass or metal);
- no stereo and no baked space.

Many sounds are single-layer (`coin`, `ui`, `deny`, `swap`, `fuse`, `eshot`, `cast_laser`, `cast_orbit`, `spawn`, `pit_fall`, `door`, `tele`). "Thin chip blips" is an accurate description.

**Identity.**
- 28 spells map to 12 cast sounds. `mote`, `seed`, `duck` and `replicator` share `cast_spark`. `bitrot`, `hexcursor`, `ping` and `daemon` all share `cast_arcane`, a 0.35 s FM bell: a long bell on fast, frequent casts is the most fatiguing choice possible. `lance`, `needle` and `exploit_needle` share `cast_laser`.
- `cast_chain` exists but no spell maps to it.
- `HIT` gives an element hit only to fire, ice, static, arcane and void. Rot has none.

**Dead cues.** 10 of 84 ids are never played: `mana_empty`, `low_hp`, `freeze`, `door`, `altar`, `win`, `lose`, `swap`, `ui_drag`, `cast_chain`. That is 12% of the set.

**Variation.** Variants are the same recipe with a new noise seed at pitch 1.0 / 1.04 / 0.96. Then runtime jitter adds up to ±20% (`Audio.sfx("hit", 0.2, ...)`), which wipes out any tonal identity and any key.

**Loudness hierarchy.** Every effect is normalised to the same -18 LUFS (UI -24). The hierarchy is then rebuilt by `volume_db` offsets scattered across 60 call sites: casts -2, hits -6, enemy shots -6, telegraphs -3, burn -8, and so on.
- The result is that a telegraph (-3 dB) plays *quieter* than a crit (0 dB) or a kill (0 dB). The game's most important warning sits under routine feedback.
- Nothing in the data states the hierarchy, so it cannot be reviewed.

**Voices.**
- The combat pool (12 voices) has no per-cue cap. One Spectrum Fan (7 bolts) plus a Callback can fill every combat voice with `hit`, and "steal the oldest" then cuts a kill sound 20 ms after it starts.
- Critical sends *into* SFX. So SFX cannot be ducked under Critical, and the SFX room reverb smears the telegraphs.

**Music.**
- Every instrument is a raw oscillator through a one-pole low-pass. Pads are 2–3 saws at 6 dB/oct: buzzy.
- The kick is a 180→55 Hz sine: 87% of the drum energy is below 300 Hz.
- There is no swing, humanisation or sidechain, and the drums are generic.
- **No leitmotif:** the title melody never recurs, and the stingers are in unrelated keys (clear in A major, reward in D, boss in E minor, victory in D major, defeat in D minor). There is no audible brand.
- Title and Foundry are both D minor.
- Four bosses share one "boss" track with a single p2 layer, although the Loop and Deadlock have three phases. design-v3 asked for "a theme for each area and each boss" and "a finale layer".
- **A live invariant break:** the Foundry runs at 112 bpm at 32 kHz, so a bar is 68,571.43 samples, not a whole number. `music_foundry_base` is 2,194,286 samples and `music_foundry_drums` is 274,286 (= 4 × 68,571.5), so the stems drift about 2 samples per base cycle. `test_audio_d8` only checks the Cellar and the boss, which is why nobody caught it.

**Ambience.** The Cellar's "drips" are FM bells at MIDI 88–95 (1.3–2 kHz): the same band as coins and UI. The beds are mono 16 s loops, short enough to recognise the repeat inside one room.

**Mix and web cost.** The five active bus effects are the limiter, the Music compressor, chorus and reverb, and the SFX reverb. The two reverbs and the chorus are the costly ones on a main-thread web mixer. The chorus only makes up for mono raw oscillators.

**Event coverage** (the runtime audit's §1, accepted as fact): 34 events are silent that should not be, 14 play the wrong sound or at the wrong time, and 9 over-fire. The worst for sound design:
- **Still hazards play as "shots".** Thorn trails, the Loop's chase trail, Select All's box fill and the Collector's trash play `eshot` 8–16 times a second.
- **Boss wind-ups end up to 0.68 s before the attack.** The generic `tele` fires at the *start* of a 0.5–1.2 s wind-up.
- **A crit replaces the element hit** instead of layering on it.
- **Coats never change the hit sound.**
- **A boss kill gets the everyday `sting_clear`.**
- **The Deadlock beam, the one continuous threat, is silent.**

**Determinism.** `gen_music.gd` draws unison phases from one sequential RNG, so adding a note shifts every later cue. That is why the ambience had to be generated "after everything else". Per-cue seeds fix this.

---

## 2. `sonic-brief` — Wandcraft v2

**Version:** v2.0 · **Locked:** 2026-09-27 · **Audio Director:** studio AD · **Visual coherence with:** ADR 0012 (quiet floor, outline rule, reserved `threat` red), ADR 0007 Style ramps, "arcane grimoire" (stone, gold filigree, gem sockets) · **Voice:** project

### 2.1 Audio pillars
1. **Code you can hear.** Every sound is a *physical material* (stone, gem-glass, gold, iron, wood, spore) struck by a *digital pulse* (the "sigil": a 10–30 ms band-limited, pitched pulse). The wand reads its program left to right as a melody: each slot's cast is pitched one scale step higher, and the wand's recharge is the cadence. Triggers chain upward in fifths.
2. **Threats speak louder than you.** Hierarchy, loudest to quietest:
   - you got hurt;
   - an enemy is about to act (telegraph);
   - a kill, crit or break;
   - your hits;
   - your casts;
   - the world.

   Your own output is soft and bright. Enemy intent is mid-band, rising, warbling and unmistakable.
3. **Phone-first weight.** Impact lives in saturated 200–900 Hz harmonics. Sub-bass is a bonus for earbuds and never the carrier.
4. **One key per room.** Music, stingers, pickups, kill chains and cast melodies share the area's key and the leitmotif.
5. **Glitch is seasoning.** Bit-crush, stutter and comb "digital" colour are reserved for corruption: the Grove, bosses, Copy-Paste, the Glitch Door, Bitrot, mana failure. Because glitch is rare, it means "something is wrong".

### 2.2 No-go list
- **No single-oscillator blips.** Every cue has at least two layers, or one layer with a moving filter or pitch envelope. The old chip language is gone.
- **No energy-carrying content below 150 Hz without a 200–900 Hz harmonic partner.** Sub alone disappears on phones.
- **Nothing load-bearing above 10 kHz.** Air is texture only.
- **No random pitch jitter above ±25 cents on tonal cues.** Variety comes from recipe variants. Musical movement comes from scale-quantised walks.
- **No white-noise risers for telegraphs.** They read as wind. Telegraphs are tonal, rising and warbling (§5.5).
- **No reverb on Critical cues.** They stay dry and immediate.
- **No 8-bit "bloop" kills** (square sliding down) and **no arpeggiated square "ta-da"** rewards.
- **No human voices, no realistic guns, no sampled-sounding explosions.** The Duck's babble is formant-synthesised and non-verbal.
- **No tri-tones or chimes that resemble iOS/Android system sounds**, which make players reach for the phone.
- **No stereo-only information.** Everything must read in mono on one phone speaker. Panning is extra direction only.

### 2.3 Sonic palette

| # | Element | Role | Source (toolkit §3) | Process tail | Visual pair | Replacement |
|---|---|---|---|---|---|---|
| 1 | **Gem-glass** | Pickups, arcane, ice, UI confirm, kill confirm | `modal.glass`, FM ratio √2 | Short baked room, T60 ≤ 120 ms in combat | Gem sockets, cyan/white highlights | FM 1:1.41 alone |
| 2 | **Grimoire stone** | Impacts, doors, slams, crates | `modal.stone` + saturated sine drop + brown noise | tanh drive 4–8, LP 1.5–2.5 kHz | Stone walls, dark faces | Filtered noise + sine drop |
| 3 | **Gold filigree (brass bar)** | Crit ring, relics, level-up, compile, "opening" chime | `modal.brass` (free bar 1 : 2.756 : 5.404) | None; its own ring is the tail | Gold filigree frames | FM 1:2.76 |
| 4 | **Sigil pulse** | The "code" layer on every cast, UI tick, trigger | `sigil()`: PolyBLEP pulse 25% → SVF band-pass at 2f, 10–30 ms | Dry | The cast pointer on the HUD, runes | Sine tick + click |
| 5 | **Arcane FM bell** | Leitmotif carrier, title, stingers | `fm(ratio 3.5, index 2.2→0.3)` | Baked `room.M` in the stems | Violet arcane light | `modal.bell` |
| 6 | **Plucked string (KS)** | Shop music-box, title harp, Grove plucks, bramble | `ks()` | Wow on the Grove only | Parchment, vines | Pulse + fast LP env |
| 7 | **Corruption** | Grove, glitch, bosses, Bitrot, mana fail | `crush()`, `stutter()`, `comb()` | — | `glitch` ramp, corrupted relics | Ring-mod at 30–80 Hz |
| 8 | **Furnace iron** | Foundry, forge, armour, anvil ostinato | `modal.plate` (membrane ratios) + steam noise | Hiss swells | Rust-red plates, orange seams | FM 1:1.59 |
| 9 | **Warm pads and saturated bass** | Music harmony and floor | `supersaw` (5 voices) → 24 dB SVF; `pulse` → tanh bass | Baked `room.M` + baked chorus | Candle and torch light | Triangle pad |

### 2.4 Motif lock: "The Incantation"
- **Main motif (home key D minor):** `D4 – A4 – F4 – G4 – A4 ‖ C5 – D5`
  - Scale degrees: 1 – 5 – ♭3 – 4 – 5 ‖ ♭7 – 1'.
  - Rhythm: four eighths then a half note (bar 1), then two quarters (bar 2).
  - The *head* is the first three notes (1 – 5 – ♭3). The rising fifth, then a fall to the minor third, is the recognisable interval.
  - The *tag* (♭7 – 1') is the "compile succeeded" resolution.
- **Function:** main theme; the grimoire's voice.
- **Transformation map:**

| Context | Variant | How |
|---|---|---|
| Title | Full statement | FM bell over harp, D minor |
| Shop | Music-box | KS pluck, D **dorian** (raised 6th = warmth), swung 58% |
| Cellar lead | Motif as the phrase head | A minor: A E C D E ‖ G A |
| Grove lead | **Corrupted** | ♭2 replaces the 4th: 1–5–♭3–♭2–1. Bit-crushed, and the 2nd pass stutters |
| Foundry | **Ostinato** | Motif as a machine riff in steady eighths on iron, F minor: F C A♭ B♭ C ‖ E♭ F |
| Mini-boss (Copy-Paste, GC) | **Retrograde plus echo** | Backwards (5–4–♭3–5–1), then "pasted" as a 3/16 echo |
| Final boss (Loop, Deadlock) | **Diminution** | 16ths as a looping cell (the Loop). p3 finale: **augmentation** on brass |
| Room clear sting | Head, resolved | 1–5 → 1 in the area key |
| Reward / level-up | Major mode | 1–5–3–4–5–(7)–1, fast |
| Boss sting | Tritone corruption | 1–♯4 (the fifth becomes a tritone) |
| Victory | Full motif in major | Final 1 held |
| Defeat | Inversion, descending, ritardando | Ends on ♭6 → 5, unresolved |
| Secret / chest | Head only | Glass bells |

- **Subordinate motif, "the Threat Warble":** a rising pulse dyad with a 14→22 Hz tremolo (§5.5). It is not melodic, and it is reserved for enemy intent.

### 2.5 Reference qualities (described, never copied)

| # | Title | Take | Reject | Tags |
|---|---|---|---|---|
| 1 | Hades (Korb) | Drums with enemies, thinning between waves, full band for bosses | Its rock instrumentation | adaptive, pillar 4 |
| 2 | Enter the Gungeon | Soft player weapons, loud enemy intent, death confirms | Its realistic gun Foley | pillar 2 |
| 3 | Nuclear Throne (Turner) | Crunchy, saturated impacts synced to hit-stop | Its harsh loudness, too fatiguing on phones | pillar 3 |
| 4 | Peggle 2 | Pitch-walks on a scale that follows the harmony | Its orchestral palette | pillar 1, 4 |
| 5 | Overwatch | Importance buckets; threats outrank self | Its 3D positional complexity | mix |

### 2.6 Emotional register per world

| Place | Anchor | Register | Key / tempo | Palette subset | Glitch amount |
|---|---|---|---|---|---|
| Title / hub | "A spellbook left open on a server rack" | Wonder, mischief | D minor, 96 | Bell, harp, pads, soft glitch hats | Low |
| Shop / forge | "The merchant's ledger" | Safe, warm, a little comic | D dorian, 96 | Music-box KS, pizzicato KS bass, shaker | None |
| The Cellar (W1 a) | "Apprentice nerves in damp stone" | Curious, tense but hopeful | A minor, 120 | Stone, wood, harp, warm pads, drips | Low |
| The Corrupted Grove (W1 b) | "Nature that has been miscompiled" | Uneasy, lurching, organic-wrong | C# phrygian, 120 half-time | Detuned KS with wow, crushed pads, glitch chirps | High |
| The Overheated Foundry (W2) | "A machine that won't stop turning over" | Pressure, heat, determinism | F minor, 125 | Iron anvil ostinato, steam, driving 16ths | Medium (overclocked) |
| Mini-bosses | "It's mocking you with your own program" | Sardonic, jittery | E minor, 128 | Chopped pads, stutter, echo-paste | High |
| Final bosses | "An infinite loop you must break" | Relentless, then heroic at p3 | C minor, 150 | Ostinato cell, brass-saw, choir-formant pad, big drums | Medium, dropping at p3 |

### 2.7 Visual–audio coherence pairings

| Visual decision | Sonic implication | Reason |
|---|---|---|
| Reserved `threat` red, only for enemy attacks (ADR 0012) | A reserved **threat warble** only for telegraphs | One reserved channel per modality means one meaning each |
| Gem sockets on the wand row; the HUD pointer walks the slots | Cast pitch walks the slots; recharge = cadence | You can hear the pointer |
| Gold filigree frames | The crit and "opening" rings are brass bars | Gold = reward and opportunity |
| Quiet floors, figures pop | Ambience at -30 LUFS, rolled off above 8 kHz | The bed never competes with figures |
| Glitch palette on corrupted relics and the Grove | Crush and stutter only there | Rarity keeps the meaning |

### 2.8 Differentiation and hand-off
- **Self-test (§7 DOG):** two decisions that mark this apart from asset-pack soundtracks are the slot-melody wand and the in-key kill chains. Both are audible within one room.
- **Hand-off:** Composition §5, Adaptive §5.2, Sound design §4, Mix §6, and engineering (Game Developer, wave 2). **Visual sign-off:** ADR 0012 already constrains this. No 2D Artist round-trip is needed for audio-only changes.

---

## 3. The synthesis toolkit (`tools/lib_dsp.gd`, shared by both generators)

One shared GDScript library, a `RefCounted` with static functions, used by `gen_audio.gd` and `gen_music.gd`. Every function *adds into* a `PackedFloat32Array` (mono) or a pair (L, R) at a start sample. All randomness comes from a `RandomNumberGenerator` seeded per **(cue id, variant, layer index)**: `seed = hash("%s/%d/%d" % [cue, variant, layer])`. Adding or reordering a cue can never change another cue's bytes.

### 3.1 Measured cost (GDScript, headless, Apple Silicon, Godot 4.6)
The benchmark is in the scratchpad and is re-runnable. Cost is **milliseconds of CPU per second of 44.1 kHz audio** (32 kHz ≈ ×0.73):

| Primitive | ms per audio-second |
|---|---|
| PolyBLEP saw + exponential pitch envelope | 8.0 |
| Simper SVF, coefficients updated every 32 samples | 11.4 |
| 6-mode modal bank | 37.5 (about 6 per mode) |
| tanh waveshaper + noise | 5.5 |
| Feedback comb (ring buffer) | 6.5 |

*Design rules that follow:* modulated filter coefficients are updated at **control rate (every 32 samples)**. Modal banks are capped at **8 modes** (4 for chatter cues). Repeated musical events are **rendered once and tiled** (§3.12).

### 3.2 Envelopes
- **`env(points)`:** a multi-segment breakpoint envelope `[[t_ms, level, curve], …]`. Within a segment, `level = a + (b − a)·s(k)` with `s(k) = (1 − e^(−c·k)) / (1 − e^(−c))`: c > 0 is fast-then-slow (natural decay), c < 0 is slow-then-fast (swell), and c = 0 is linear. Evaluated per sample; it costs about as much as one multiply-add with precomputed segment constants.
- **`adsr(a, d, s, r)`:** convenience built on `env`. The release starts from the current level (no clicks).
- **`aenv(a_ms, d_ms)`:** a two-segment percussive envelope. The decay reaches -60 dB at `d_ms` (exponential, `c = 6.9`).
- **Anti-click rule:** every rendered layer gets a minimum 0.5 ms fade-in and a 2 ms fade-out, unless a transient explicitly asks for an instant onset (`onset: hard`).

### 3.3 Pitch envelopes
- **`penv(f_start, f_end, ms, shape)`:** `exp` (the default) is `f(t) = f_end·(f_start/f_end)^(1−k)`; `drop` is `f(t) = f_end + (f_start − f_end)·e^(−t/τ)` with τ = ms/5 (kicks, impacts).
- **`penv_semis(points)`:** a breakpoint envelope in semitones, `f = f0·2^(s(t)/12)` (vibrato, wobble, "rewind").
- **Vibrato / LFO:** `lfo(rate_hz, depth, shape ∈ {sine, tri, square, sh}, delay_ms)`. `sh` is sample-and-hold (for glitch).

### 3.4 Oscillators (all phase-accumulator, band-limited where it matters)
- **`saw`, `pulse(duty)`** with PolyBLEP (as today). **`pulse` accepts a modulated duty** (PWM).
- **`tri`** (naive is fine up to 3 kHz; above that use the integrated PolyBLEP square). **`sine`.**
- **`supersaw(f, n=5, detune_cents=±12, mix=0.6)`:** the centre voice at full level, the side voices at `mix`, and random start phases from the layer seed.
- **`noise(kind)`:** `white` (the seeded RNG), `pink` (Paul Kellet's 3-pole approximation), `brown` (leaky integrator, `y = 0.98y + 0.02x`, rescaled).
- **`sigil(f, ms, bright=1.0)`** *(the signature)*: `pulse(0.25)` at f → SVF band-pass at 2f, Q = 6, → `aenv(0.3, ms)`, plus a 1-sample click at onset scaled by `bright`. It is the "code" tick carried by every cast, trigger and UI tap.

### 3.5 Filters
- **Simper TPT SVF** `svf(mode, fc, q)`, mode ∈ {lp, bp, hp, notch, peak}. It can be chained twice for 24 dB/oct.
  - Coefficients: `g = tan(π·fc/fs)`, `k = 1/Q`, `a1 = 1/(1 + g(g + k))`, `a2 = g·a1`, `a3 = g·a2`.
  - Per sample: `v3 = v0 − ic2; v1 = a1·ic1 + a2·v3; v2 = ic2 + a2·ic1 + a3·v3; ic1 = 2v1 − ic1; ic2 = 2v2 − ic2`.
  - Outputs: `lp = v2`, `bp = v1`, `hp = v0 − k·v1 − v2`.
  - `fc` and `q` accept envelopes (control rate, 32 samples). `fc` is clamped to `[20, 0.45·fs]`.
- **One-pole LP/HP** (kept for cheap tone shaping). **DC blocker** `y = x − x1 + 0.995·y1` on every output.
- **RBJ biquad** `eq(peak | lowshelf | highshelf, f, gain_db, q)` for static EQ: the music lead's dip at 800 Hz, the phone tilt on booms.
- **Mandatory output filter:** a 2nd-order Butterworth high-pass at **70 Hz** (SFX) / **45 Hz** (music; the earbud floor), replacing the 80 Hz one-pole. Loops use the existing two-pass wrap trick so the filter state is continuous across the seam.

### 3.6 Nonlinearity (phone-audible weight)
- **`sat(drive, kind)`:** `tanh(drive·x)/tanh(drive)` (symmetric, odd harmonics); `asym`: `tanh(drive·(x + 0.2x²))` (adds even harmonics, a warmer "thump"); `fold`: `sin(drive·x·π/2)` (wavefolder, for Foundry metal); `hard`: clamp.
- **`phantom(buf, split=180, drive=4, mix=0.5)`:** isolate below `split` (SVF LP), saturate, band-pass the result 200–700 Hz, and add back. It generates 2f and 3f of a low body so the ear infers the fundamental on phones. **Every cue with >25% of its energy below 300 Hz runs through `phantom`.**
- **`crush(hold, bits, wet)`:** sample-and-hold every `hold` samples, then quantise to `bits`. `stutter(slice_ms, repeats)`: repeat a slice N times (glitch, the Grove's second pass).

### 3.7 FM
- **`fm(f, ratio, index_env, amp_env, ops=2)`:** 2-operator (modulator → carrier). An optional 3rd operator stacks (`ops=3`, ratio2) for richer metal.
- **Ratio sets (material presets):** `bell` 3.5 (index 2.2→0.3); `glass` 1.414 (1.6→0); `metal` 2.756 (3→0.5); `wood` 1.0 (0.8→0); `growl` 0.5 (4→1, sub-octave grit).
- The index follows its own envelope, not the amplitude envelope: a bright attack with a pure tail.

### 3.8 Physical models
- **Karplus-Strong `ks(f, t60, bright, pick_pos)`** (extended form, Jaffe & Smith):
  - Delay line length `N = fs/f − 0.5`, with a first-order allpass for the fractional part (tuning).
  - Loop filter `y = ρ·(0.5 + 0.5·(1 − bright))·(x[n] + x[n−1])` with `ρ` chosen for `t60`.
  - Excitation: a noise burst of N samples through a one-pole LP at `bright·8 kHz`, comb-filtered by `pick_pos` (a delay of `pick_pos·N`).
  - Cost ≈ one comb (6.5 ms/s).
- **Modal resonator bank `modal(material, f0, t60, excite)`:**
  - Each mode is a 2-pole resonator: `y = 2r·cos(ω)·y1 − r²·y2 + g·x`, with `ω = 2π·f0·ratio/fs` and `r = exp(−6.91/(t60_mode·fs))`, where `t60_mode = t60 · ratio^−0.7` (higher modes die faster).
  - `excite` ∈ {impulse, noise burst 1–8 ms, a click through SVF-LP (soft mallet)}.
  - Mode gains are normalised so the sum of the first 20 ms peaks at 1.
  - Material presets (ratios; relative gains):

| Material | Mode ratios | Gains | Base T60 |
|---|---|---|---|
| `stone` | 1, 1.52, 2.23, 3.17, 4.02 | 1, .6, .45, .3, .2 | 80 ms |
| `wood` | 1, 2.76, 5.40 | 1, .35, .15 | 120 ms |
| `brass` (free bar) | 1, 2.756, 5.404, 8.933 | 1, .5, .3, .15 | 600 ms |
| `glass` | 1, 2.32, 4.25, 6.63 (empirical; tune by ear) | 1, .5, .35, .2 | 400 ms |
| `plate` (iron; membrane Bessel ratios) | 1, 1.594, 2.136, 2.296, 2.653, 2.918, 3.156, 3.5 | 1, .8, .7, .6, .5, .4, .35, .3 | 350 ms |
| `bell` | 0.5, 1, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011 | .6, 1, .5, .6, .7, .3, .25, .2 | 1.5 s |

  - **Chatter cues use at most 4 modes.**

### 3.9 Textures
- **`grain(density_hz, len_ms, source, band, scatter)`:** sparse grains. Each grain is a Hann-windowed snippet of `source` (noise, sine or modal ping) at a seeded random time and pitch within `band`. Used for fire crackle, debris, glass shards, steam, spore rustle and glitch chirps.
- **`crackle(rate, ring)`:** kept, but band-passed through the SVF (4 kHz, Q 1) so it stops being a full-band click.
- **`whoosh(f_lo, f_hi, ms, q)`:** pink noise → SVF band-pass whose `fc` rises then falls (60/40 split) with amplitude following `fc`.
- **`rev(layer)`:** render then reverse (void, telegraph pre-swells, "rewind").

### 3.10 Delay, comb, space (baked, so no runtime reverb is needed on SFX)
- **`delay(ms, fb, lp_hz, wet)`:** a feedback delay with a one-pole LP in the loop (ping, arcane echo, the mini-boss "paste").
- **`comb(ms, fb)`:** a short feedback comb, 0.5–3 ms = a pitched "digital ring" (triggers, copy_cast, derail screech).
- **`room(size ∈ {S, M}, wet, damp)`:** a Freeverb-lite with **4 combs + 2 allpasses**.
  - Freeverb lengths are scaled to fs (44.1 kHz: combs 1116, 1188, 1277, 1356 × size factor S = 0.55 / M = 0.85; allpasses 556, 441; comb feedback 0.70 (S) / 0.80 (M); damping LP 0.3).
  - SFX: used only by the Event and Moment families. The tail gets a hard fade to 0 by `len`, and the file is trimmed.
  - **Music: every stem is rendered through `room.M` (wet 14%, damp 0.5) plus a baked 2-voice chorus on pads** (a ±6 ct, 0.4 Hz modulated 12 ms delay at 25% wet). This replaces the runtime Music chorus and reverb. **[DEV-A3: ACCEPT]**
  - Stems with baked space are rendered at 2× length, and the second half is kept, so the tail is continuous across the loop seam.
  - Cost ≈ 6 × 6.5 = 40 ms/s.

### 3.11 Stereo (only where width pays)
- **SFX and music stems stay mono** (§5.9 explains the size and CPU trade). Width at runtime comes from panning SFX by screen position (§6.4) and from the stereo ambience beds. Music is mono-centred, because baking the reverb into mono stems gives up the runtime reverb's stereo spread. That trade is accepted: phones come first, and it is the largest web saving (§5.9, DEV-A3).
- **Ambience beds are stereo.** L and R are rendered with **decorrelated seeds** (the same recipe, different noise and grain seeds). Point sources are placed with `pan(p)` equal-power: `gL = cos((p+1)π/4)`, `gR = sin((p+1)π/4)`. The mid is checked to keep mono compatibility (the L+R sum must not lose more than 3 dB against the sum of the channels' loudness).

### 3.12 Pipeline utilities
- **Note/tile cache (music):** render each unique `(instrument, midi, dur_16ths, vel)` once per cue into a cached buffer and mix copies. Drum bars and repeated arp bars are rendered once and tiled. This is the main speed lever. It is deterministic because the cache key includes the layer seed.
- **Loop seam:** tails wrap to the start (kept). For stems with baked space, render 2× the length and keep the second half.
- **`Loudness` additions** (in `game/scripts/audio/loudness.gd`, so the tests use the same meter):
  - `momentary_max(buf, rate)`: the maximum of 400 ms K-weighted blocks, hop 100 ms. A buffer shorter than 400 ms is zero-padded to 400 ms (EBU R128 momentary).
  - `true_peak_db(buf, rate)`: 4× oversampling with a 48-tap windowed-sinc polyphase FIR (BS.1770-4 Annex 2 style), evaluated only in 64-sample windows whose sample peak is within 6 dB of the file peak, which keeps it cheap.
  - `band_share(buf, rate, lo, hi)`: the FFT-free energy share in a band via the SVF band-pass. It feeds the DOG checks and the audition report.
- **Normalisation:** each SFX file is scaled to its family's `momentary_max` target, capped so `true_peak_db ≤ −1.0 dBTP`. Music: the full mix of all layers at `integrated = −20 LUFS`, capped at −1.0 dBTP.

### 3.13 Regeneration-time estimate
- SFX: about 120 ids, about 255 files, about 90 s of 44.1 kHz audio, at about 150 ms per audio-second layered with baked space and meters → **about 15–40 s**.
- Music at 32 kHz with the note cache: about 12 s per area track × 3, title and shop 15 s, bosses 20 s, stingers 5 s; stereo ambience about 12 s; loudness and TP on about 1,000 s of audio about 20 s → **about 2.5–3.5 min**.
- Baked music reverb and chorus (about 900 s of stems × about 50 ms/s): **+45 s**.
- Import and QOA re-import: about 30 s.
- **Estimated total: 5–7 min** (today about 3). The DOG ceiling is 8 min on Bar's Mac.

---

## 4. `cue-spec` inventory (sound effects)

### 4.1 Conventions
- **Families**, as the baked file level measured as `Loudness.momentary_max` (LUFS-M), with true peak ≤ -1.0 dBTP:

| Family | Target LUFS-M | Used for |
|---|---|---|
| **W** whisper | -30 | DoT ticks, steps, fuse ticks, heartbeat, recharge |
| **C** chatter | -24 | Casts, hits, coins |
| **C+** threat chatter | -22 | Enemy shots, defence feedback, summons, info |
| **E** event | -20 | Kills, booms, world objects, pickups |
| **A** alarm | -17 | Hurt, telegraphs, boss attacks, breaks |
| **M** moment | -15 | Boss phase, elite kill, boss death, compile, relic save |
| **U** UI | -24 | Taps |
| **U+** UI confirm | -21 | Buy, equip, pick, deny |

  *This replaces the flat -18/-24 plus call-site offsets.* The hierarchy lives in the files and in one runtime table. Call sites stop passing `volume_db` (**RUNTIME**, see the objection in §8).
- **Bands** are the load-bearing band (≥ 50% of the cue's energy after the 70 Hz high-pass). **Reserved bands:**
  - **R1 threat band = 330–1200 Hz**, owned by telegraphs, enemy shots, hurt and alarms.
  - **R2 ring band = 2.2–3.6 kHz sustained (≥ 150 ms ring)**, owned by crit and the "opening" chimes. Chatter may touch 2–4 kHz only with decays ≤ 60 ms.
  - **Chatter (casts, hits) lives at 1.2–8 kHz, with ≤ 15% of its energy in R1.**
- **Recipe notation:**
  - `T` = transient (0–20 ms), `B` = body, `L` = tail, `S` = sub/weight layer. Levels in dB are relative within the cue.
  - `aenv(a/d)` in ms; `penv(f1→f2/ms)`; `svf.bp(fc→fc2/ms, Q)`.
  - `modal.x(f0, T60)`; `ks(f, T60, bright)`; `fm(f, ratio, idx1→idx2/ms)`; `sat(drive)`; `phantom` as in §3.6; `room.S/M(wet%)`.
- **Tuning:** tonal components are tuned to **A (A6 = 1760 Hz, A5 = 880 Hz)** unless noted. The runtime shifts by the area key offset (Cellar 0, Grove +4 semitones, Foundry −4, title/shop +5 = D) for cues with a walk (§6.5).
- **Class / prio / cap:**
  - Classes are `crit` (Critical bus), `cmb` (SFX bus), `ui` (UI bus), `det` (a new "detail" class on SFX, lowest).
  - Prio is 0–100, higher wins steals.
  - Cap is the maximum number of simultaneous voices of the cue's *group*.
- **Walk:**
  - `slot`: the cast pitch climbs the scale with the slot index.
  - `chain`: consecutive events within a window climb the scale.
  - `depth`: trigger depth.
  - `—`: no walk.
- **Variants** are recipe variants: different modal excitation, a body retuned by ±1–2 semitones where the cue is not in-key, different grain seeds. They are not pitch copies.
- **[DEV-A2: ACCEPT]** The Developer's own no-repeat variant picker replaces `AudioStreamRandomizer`. The cue table carries `jitter_cents`: 0 for walked cues (±10 ct humanise), 25 for the rest. Volume varies ±1 dB.
- **Prio and cap feed the Developer's queued voice manager [DEV-A1: ACCEPT].** Requests are queued, same-name requests in a frame coalesce (the loudest is kept, `+10·log10(n)` dB, capped at **+3 dB**: amended from +4 so a coalesced chatter hit cannot out-shout an Event cue), and at most 6 new voices start per frame (8 native). Steals take the lowest prio first, then the quietest, then the one with least time left. **One Critical voice is reserved for `hurt`.**
- **Ids:** existing ids are kept wherever the event is the same. **NEW** marks a new id. **HOOK** means a gameplay call site is needed (Game Developer). **TABLE** means only `audio.gd` data changes (the CAST/HIT maps or the cue table).
- **Where the Developer's audit already named a new cue at a call site, this spec adopts the Developer's id** to avoid churn. Examples: `thermal`, `crash`, `caught`, `gulp`, `key_turn`, `glitch_toll`, `duck_say`, `blink_charge`/`blink_land`. Those rows cite the audit's file:line.

### 4.2 Casts (the player's output; soft and bright; pillar 1)
All casts: family **C**, class `cmb`, prio 30, group `cast` cap 3, walk **slot**. Every cast carries `sigil(1760, 15–25)` as its first layer, so the wand's melody is always the same instrument.

| id | Spells (CAST map) | Recipe | Band | Var | Gap s |
|---|---|---|---|---|---|
| `cast_spark` | mote, replicator (−2 st, +2 dB) | T `sigil(1760,20)`; B `pulse(.25)` penv(2640→1320/60) → svf.bp(2.5k, Q3); L pink noise hp 4k aenv(2/70) −12 dB. 110 ms | 1.5–5k | 3 | 0.045 |
| `cast_laser` | lance | T sigil(1760,15); B 2× saw 3520 ±15 ct → svf.hp 2k → svf.bp(7k→3k/80, Q5) "zzt"; L comb(0.57 ms, fb .6) 60 ms. 120 ms | 3–7k | 3 | 0.05 |
| `cast_needle` **NEW, TABLE** | needle, exploit_needle (−2 st) | T white hp 6k 4 ms; B sine penv(4400→2200/35) + sigil(3520,15). Dry. 60 ms | 3–6k | 3 | 0.04 |
| `cast_fan` | fan | Three sigils 1760 / 2093 / 2637 (A C E) at 0/18/36 ms; whoosh(3k→6k, 90, Q1) −6 dB. 140 ms | 1.7–6k | 3 | 0.08 |
| `cast_missile` | moths | T sigil; B pink noise svf.bp(3k, Q4) with 28 Hz AM (wing flutter), 120 ms; sine penv(1320→1980/100) −10 dB. 150 ms | 2–4k | 3 | 0.06 |
| `cast_carry` **NEW, TABLE** | seed (Carry) | ks(880, 0.15, .4) + sigil(1760,15). 150 ms | 0.9–4k | 3 | 0.06 |
| `cast_orbit` | wheel, disc | fm(1320, 1.41, 3→.5/180) with 9 Hz ±30 ct vibrato; whoosh(1.5k→4k, 180). 220 ms | 1.3–4k | 2 | 0.08 |
| `cast_boom` | burst | T white hp 3k 6 ms; B sine penv drop(660→220/60) sat(4) → LP 1.8k, phantom; L pink LP 2.5k aenv(1/180). 260 ms. *Exempt from the R1 rule (it is an explosion at your wand tip; rare)* | 200–1.8k | 3 | 0.08 |
| `cast_mine` **NEW, TABLE** | mine | sigil; two mechanical clicks (white → svf.bp 3k Q6, 5 ms) at 0/60 ms; fm tick 2637. 110 ms | 2.5–5k | 2 | 0.08 |
| `cast_fire` | ember, meltdown (−3 st, +2 dB) | T white bp 2k 8 ms; B pink → svf.bp(1.2k→3.5k/150, Q1.5) + grain crackle 40/s 3 ms bp 4k; saw 440→330 sat −14 dB; L crackle 100 ms. 220 ms | 1.2–5k | 3 | 0.05 |
| `cast_wall` **NEW, TABLE** | firewall | pink → svf.lp(800→4k/250); grains crackle 80/s for 400 ms; sigil. 450 ms | 0.8–5k | 2 | 0.2 |
| `cast_ice` | frost, absolute_zero (−2 st) | T modal.glass(3520, **60 ms**) + white hp 7k 10 ms; B fm(5274, 1.41, 2→0/80). 120 ms | 3.5–8k | 3 | 0.05 |
| `cast_chain` *(was dead)* | spark, storm_protocol (−2 st) — **TABLE: remap from cast_static** | T crackle 30 ms 800/s bp 4k; B sigil + saw penv(6k→1.5k/40) → svf.bp tracking, Q8. 90 ms | 1.5–6k | 3 | 0.05 |
| `cast_static` | static (cone) | crackle 60 ms 1500/s → bp 4k; whoosh(7k→3k/80); sigil. 110 ms | 3–7k | 3 | 0.05 |
| `cast_arcane` | hexcursor | fm(1760, 3.5, 2.5→.2/**120**) + sigil; delay(90, .25, 3k) wet 20%. 220 ms (shortened from 350) | 1.7–5k | 3 | 0.06 |
| `cast_ping` **NEW, TABLE** | ping | sine 2637 aenv(1/250) + delay(70, .35, 4k); sigil. 350 ms (ping fires at most every 0.25 s) | 2.4–5k | 2 | 0.1 |
| `cast_rot` **NEW, TABLE** | bitrot | brown → svf.bp(1.4k→2.4k/200, Q6) with 9 Hz wobble; crush(6, 6, .5); sigil. 220 ms | 1.4–2.6k | 2 | 0.1 |
| `cast_void` | null_orb, singularity (−3 st) | L-first: rev(pink svf.bp(3k→800/250, Q2) + sine 110 sat) 220 ms; then T "thup": sine drop(180→90/40) sat(5) LP 1k, phantom. 280 ms | 180–700 + 1–3k | 2 | 0.1 |
| `cast_summon` **NEW, TABLE** | daemon, turret, duck | fm(880→1760 penv 120, 2, 1.5); modal.glass(3520, 200) at 120 ms; sigil. 300 ms | 0.9–4k | 2 | 0.2 |
| `trigger` | a trigger fires its payload | Two sigils 1760 → 2637 (a fifth) at 0/35 ms + comb(1.13 ms, fb .5) 40 ms. 110 ms. Walk **depth**: +0 / +7 / +12 semitones for depth 1/2/3 (**HOOK: pass depth**) | 1.7–3k | 2 | 0.06 |

- **Hit mapping (TABLE):** `HIT` gains `cast_rot → hit_rot`, `cast_chain → hit_static`, `cast_arcane → hit_arcane`, `cast_ping → hit_arcane`, `cast_summon → hit`, `cast_wall → hit_fire`.
- **Coats (RUNTIME, optional):** if the bolt's mods carry `burn`/`chill`/`static_on`/`rot`, the hit uses that element's hit. It costs one lookup in `SpellRunner` where `world.hit_sound` is set.
- **Casts drop the random ±8% jitter.** The slot walk replaces it.
- **Coats and hits [DEV-A6: ACCEPT]:** the coat decides the element (`hit_for_bullet`). Priority when several coats apply: rot > static > chill > burn, because the rarer mechanic is the one to announce.
- **Multicast and weight [DEV-A7: ACCEPT, amended]:** `cast(id, at, weight)`.
  - Up to **two distinct** cast timbres per cast: the first two different cast ids among `plan.groups`, the second at −4 dB and +20 ms.
  - Gain is `+2·log2(weight)` dB, capped at +3.
  - When the plan carries Heavy or Empower, the cue's variant **"heavy"** (a 4th variant with an extra `phantom`-saturated 300 Hz body at −8 dB) is picked. This is how boosts become audible without a new voice.

| id | Meaning / call site (audit) | Recipe | Band | Fam | Var | Class/prio/cap | Gap |
|---|---|---|---|---|---|---|---|
| `cast_delayed` **NEW, HOOK** | A Pipeline or `_later` copy releases (`spell_runner.gd:874-891`) | sigil only, at the walk pitch, at −6 dB against a cast. 40 ms | 1.7–3.5k | W (−28) | 1 | cmb/25/`cast` | 0.04 |
| `fizzle` **NEW, HOOK** | Race Condition eats a paid cast (`spell_runner.gd:153`) | sigil(1760) → stutter(8 ms × 3) + crush(6, 4); white svf.bp(3k→1k/60). 90 ms | 1–3k | C | 2 | cmb/45/1 | 0.2 |
| `familiar_shot` **NEW, HOOK** | A Daemon payload or Turret bolt fires (`spell_runner.gd:633-667`) | The payload's cast id at −6 dB (runtime gain), panned at the familiar. **No new file** | as the cast | C | — | cmb/20/`cast` | 0.08 |
| `familiar_end` **NEW, HOOK** | A familiar expires (`spell_runner.gd:594`) | Soft pop: sine drop(880→440/40) + modal.glass(1760, 60) −8 dB. 90 ms | 0.4–1.8k | C | 1 | cmb/30/1 | 0.2 |
| `duck_soak` **NEW, HOOK** | The Rubber Duck decoy soaks a shot (`spell_runner.gd:566`; replaces `hit`) | Rubber squeak: saw penv(900→1300→700 / 90 ms) → formant bp 1.2k + 2.6k Q5; tiny click. 100 ms | 0.9–2.6k | C | 3 | cmb/35/1 | 0.1 |

### 4.3 Hits, crits, defences

| id | Meaning / call site | Recipe | Band | Fam | Var | Class/prio/cap | Gap | Walk |
|---|---|---|---|---|---|---|---|---|
| `hit` | A plain spell hits (`world.gd:1415`) | T white hp 5k 3 ms + 1-sample click → svf.bp 4k Q2; B modal.stone(1200, 35) (4 modes) sat(2). 60 ms. *Replaces the 12 kHz hiss* | 1.2–6k | C | **4** (f0 1000/1100/1200/1300) | cmb/40/group `hit` 4 | 0.03 | — |
| `crit` | A crit: **a sweetener layered on the element hit** (`world.gd:1415` → `hit(name, at, crit, heavy)`) **[DEV-A8: ACCEPT]** | T white hp 4k 3 ms; B **modal.brass(880, 280)**: partials 880 / 2425 / 4755. 300 ms. No body of its own; the element hit supplies the impact. The only combat cue with a ≥ 150 ms ring in R2 | **2.2–3.6k ring** | E | 3 (mallet brightness, mode mix) | cmb/80/2 | 0.05 | — |
| `hit_heavy` **NEW, HOOK** | A sweetener when the target is heavy, a boss or a boss part (`hit(..., heavy)`) **[DEV-A9: ACCEPT]** | modal.stone(300, 70) sat(3), phantom; white bp 1.5k 4 ms. 90 ms | 250–900 (exempt from R1; it co-fires with a hit, never alone) | C | 3 | cmb/45/`hit` | 0.08 | — |
| `hit_fire` | Fire element hit | T white bp 3k 5 ms; B pink svf.bp(1.8k→900/80, Q1.2) "fsh" + grain crackle 40/s. 120 ms | 0.9–4k | C | 4 | cmb/40/`hit` | 0.04 | — |
| `hit_ice` | Ice hit | T modal.glass(3520, 50) + white hp 7k 10 ms; B fm(5274, 1.41, 1.5→0/60). 90 ms | 3.5–8k | C | 4 | cmb/40/`hit` | 0.04 | — |
| `hit_static` | Shock hit | crackle 60 ms 2500/s ring .85 → svf.bp 4k Q1; saw penv(5k→2k/30) −8 dB. 80 ms | 3–7k | C | 4 | cmb/40/`hit` | 0.04 | — |
| `hit_arcane` | Arcane hit (cursor, ping) | T click; fm(2637, 3.5, 2→0/**50**). 80 ms | 2.4–5k (decay ≤ 60 ms) | C | 3 | cmb/40/`hit` | 0.04 | — |
| `hit_void` | Void hit | rev(pink bp 1.5k, 60 ms) → sine drop(300→150/30) sat(4), phantom. 100 ms | 150–700 + 1–2k | C | 3 | cmb/40/`hit` | 0.04 | — |
| `hit_rot` **NEW, TABLE** | Bitrot / rot coat hit | brown svf.bp(900→1.8k/60, Q5) + crush(4, 5, .6). 90 ms | 0.9–2k | C | 3 | cmb/40/`hit` | 0.04 | — |
| `hit_armor` | Blocked by armour: "use Blast" (`world.gd:1377`) | T white hp 4k 3 ms; B modal.plate(1480, 120) "tink"; sine 260 aenv(1/40) −10 dB. 180 ms | 1.4–5k | C+ | 3 | cmb/60/2 | 0.05 | — |
| `hit_ward` | Ward absorbs: "use Static/Multi" | fm(2093, 1.5, 1→0/140) with 20 Hz tremolo; white hp 6k 20 ms. 160 ms | 2–6k | C+ | 3 | cmb/60/2 | 0.05 | — |
| `hit_shield` | Frontal shield blocks: "use Pierce" | svf.bp 1.6k Q4 on pink 40 ms (a force-field "bwomp") + sine penv(1900→1500/60) + comb(2.27 ms, .6). 140 ms | 1–2.5k | C+ | 3 | cmb/60/2 | 0.05 | — |
| `armor_break` | Armour destroyed | T white hp 3k 10 ms; B modal.plate(740, 400) (hard excite) + sine drop(220→110/150) sat(4), phantom; L pink LP 2k 300 ms + grains of modal.stone(2k) 40/s for 300 ms (fragments). 700 ms | 200–3k wide | A | 2 | crit/85/1 | 0.2 | — |
| `shield_break` **NEW, HOOK** | A frontal shield is broken (`world.gd:1531`; replaces `armor_break`) **[DEV-A10: ACCEPT]** | Force-field collapse: fm(1600, 1.5, 3→0) with penv(1600→400/300); crackle 200 ms 1000/s bp 3k; T white hp 3k 6 ms. 450 ms. Distinct from armour (metal) and ward (glass) | 0.4–3k | A | 2 | crit/85/1 | 0.2 | — |
| `locked` **NEW, HOOK** | Deadlock: a hit on the locked Mutex does nothing (`world.gd:1350`) **[DEV-A11: ACCEPT]** | Dull iron clank: modal.plate(300, 60) heavily damped + pulse 220/233 buzz 50 ms −8 dB (a cousin of `deny`). 110 ms | 0.2–1.2k | C+ | 2 | cmb/55/1 | **0.25** | — |
| `ward_break` | Ward shattered | 25 grains of modal.glass (f0 2–6k, seeded) over 250 ms with falling density; fm penv(3520→1760/200); white hp 5k 200 ms. 600 ms | 2–8k | A | 2 | crit/85/1 | 0.2 | — |

### 4.4 Kills and explosions

| id | Meaning / call site | Recipe | Band | Fam | Var | Class/prio/cap | Gap | Walk |
|---|---|---|---|---|---|---|---|---|
| `kill` | A small enemy dies (`world.gd:1660`) | T white bp 3k 5 ms; B "pop": sine drop(330→165/60) sat(4) → LP 900, phantom; C "confirm": **modal.glass(1760, 70)**, in key. 150 ms | 200–900 pop + 1.7–3k confirm | E | 3 (pop shape) | cmb/70/3 | 0.04 | **chain** |
| `kill_mid` | A heavy enemy dies | T same; B sine drop(250→110/120) sat(5) + pink LP 1.2k 150 ms (splat), phantom; C modal.glass(1760, 120); room.S 12%. 350 ms | 200–900 + 1.7k | E | 3 | cmb/75/2 | 0.05 | **chain** |
| `kill_big` | An elite dies (hit-stop 80 ms) | T white hp 3k 8 ms; B sine drop(200→80/250) sat(6) LP 1.5k + modal.stone(420, 200), phantom; C **modal.brass(880, 600)**, A then E at 0/90 ms (the motif head); L room.M 18% + pink LP 1.5k 400 ms. 900 ms. **Moves to Critical** | wide | **M** | 2 | **crit**/90/1 | 0.1 | — |
| `kill_burn` **NEW, HOOK** | Death while burning (`world.gd:1642` already branches) | `kill` + an ember flare: grains crackle 120/s for 250 ms, whoosh(2k→4k, 250). Replaces `kill` for that death | 200–900 + 2–5k | E | 3 | cmb/70/3 | 0.04 | chain |
| `kill_shatter` **NEW, HOOK** | Death while frozen or chilled | `kill` pop at −4 dB + 18 modal.glass grains (3–8k) over 200 ms | 3–8k | E | 3 | cmb/70/3 | 0.04 | chain |
| `kill_spark` **NEW, HOOK** | Death while charged (the static spit, `world.gd:1644-1655`; `kill(..., how=&"static")`) | `kill` pop + crackle 120 ms 1500/s bp 5k + saw penv(5k→1.5k/40). 180 ms | 200–900 + 3–6k | E | 3 | cmb/70/3 | 0.04 | chain |
| `split` **NEW, HOOK** | A Moss Blob splits in two (`world.gd:1693-1705`) | Wet squelch: brown svf.bp(500→1.2k/120, Q4) + sine penv(300→500/80) sat. 150 ms | 0.3–1.2k | C | 2 | cmb/40/1 | 0.08 | — |
| `crash` **NEW, HOOK** (the audit's id; was my `kill_crash`) | A Bitrot "CRASH" burst at 5 stacks (`world.gd:1567`) | Glitch burst: crush(3, 5) on a pink burst; stutter(20 ms × 3); sine drop(400→150) sat; sigil down a tritone. 300 ms | 0.4–3k | E | 3 | cmb/72/2 | 0.05 | — |
| `boom` | Player explosions: bomb, mine, burst area (`spell_runner.gd:429,738`, `world.gd:1494`) | T white hp 2.5k 6 ms; B sine drop(150→60/200) sat(8) → LP 1.6k, **phantom**; pink svf.lp(3k→500/300); L room.S 10% + debris grains 30/s. 500 ms | **200–1.6k** (was 100–200) | E | 3 | cmb/70/2 | 0.06 | — |
| `bigboom` | Boss defeated (`audio.gd` Events.boss_defeated) | T white hp 2k 15 ms; B two drops sine(110→40/600) sat(10), phantom; brown svf.lp(1.2k→300/900); modal.stone(160, 500); L room.M 25%, 1.5 s. 2.0 s | 150–2k | M | 1 | crit/95/1 | 0.5 | — |

### 4.5 The player

| id | Meaning / call site | Recipe | Band | Fam | Var | Class/prio/cap | Gap |
|---|---|---|---|---|---|---|---|
| `hurt` | You got hit (`audio.gd` Events.player_hurt; hit-stop 90 ms) | T "crack": white svf.bp(2.5k, Q1) 8 ms + click; B **dissonant stab**: saw 311 + saw 330 (a minor 2nd) sat(5) → svf.lp(3k→600/180, Q3), pitch −3 st over 150 ms; S sine drop(150→80/120) sat, phantom. **Dry.** 280 ms | **250–900** (R1) + 2.5k crack | **A (−16)** | 3 (stab pairs 311/330, 294/311, 330/349) | crit/100/1 | 0.15 |
| `dash` | Dash (`player.gd:156`) | whoosh(600→3.5k→1.2k, 60/120 ms, Q2); sine penv(330→660/100) −14 dB. 200 ms | 0.6–3.5k | C | 3 | cmb/50/1 | 0.1 |
| `mana_empty` *(dead)* **HOOK** | The wand can't afford its next spell (`spell_runner.gd:113`, `w.mana < cost`) | "Fizzle": sigil(1760) cut at 15 ms; white svf.bp(2k→800/80, Q4); crush(8, 4). 140 ms | 0.8–2k | C+ | 2 | cmb/55/1 | **0.5** |
| `low_hp` *(dead)* **HOOK** | One heartbeat while HP < **30%** (the HUD glow threshold). The Developer schedules one beat every 1.2 → 0.9 s as HP falls (`player_hp(frac)`, `world.gd:821`) **[DEV-A12: ACCEPT; replaces my loop, because a one-shot lets the tempo rise]** | Lub: sine drop(110→70/60) sat(6) LP 700, phantom; dub at +180 ms, −4 dB. 350 ms, one-shot | 150–700 | **W (−28)** | 2 | crit/60/1 (never steals `hurt`) | 0.8 |
| `die` **NEW, HOOK** | The player dies (`player.gd:320`), before `sting_defeat` **[DEV-A13: ACCEPT]** | "Program terminated": the `hurt` stab held 400 ms with LP 3k→300; a descending sigil run 1760→880→440 (60 ms steps) that crushes to 4 bits; sine drop(150→40/600) sat, phantom. **Dry.** 900 ms | 0.2–2k | M | 1 | crit/100/1 | 1.0 |
| `graze` **NEW, HOOK** | A dash passes through a shot on i-frames (`player.gd:283`) **[DEV-A14: ACCEPT]** | Bright near-miss: whoosh(3k→6k, 70, Q3) + sigil(3520, 10). 90 ms | 3–6k | C | 2 | cmb/50/1 | **0.25** |
| `shield_soak` **NEW, HOOK** | Buffer Overflow shield soaks a hit (`player.gd:297`) | Glass absorb: modal.glass(1319, 150) + fm(2637, 1.41, 1→0) + a low thump sine 200 sat −10 dB. 220 ms | 1.3–2.7k | C+ | 2 | crit/70/1 | 0.2 |
| `swap` *(dead)* **HOOK** | The active wand changes (`player.gd:134`, only when `cur` changes; HUD button and keys) | See §4.10 | | | | | |
| `step_stone` / `step_moss` / `step_metal` **NEW, HOOK (P3)** | Footsteps by biome (the walk-cycle foot frames) | stone: modal.stone(900, 25) + white bp 3k 4 ms; moss: pink svf.bp 1.2k 30 ms + grain rustle; metal: modal.plate(1300, 40). 60–80 ms | 0.9–3k | W (−32) | 4 each | det/10/1 | 0.18 |

### 4.6 Enemies (threat language)

| id | Meaning / call site | Recipe | Band | Fam | Var | Class/prio/cap | Gap |
|---|---|---|---|---|---|---|---|
| `eshot` | Weaver, generic, Collector shot (`world.gd:965`) | pulse(.3) penv(1100→550/70) → svf.lp 1.6k Q1.5; white bp 900 5 ms. **Dull and mid**, the opposite of player casts. 90 ms | **500–1.2k** (R1) | C+ | 3 (start 1000/1100/1200) | cmb/60/group `eshot` 3 | 0.06 |
| `eshot_ring` | Puffcap 8-ring | pink svf.bp 700 Q2 aenv(5/150) + tri penv(620→470/140) with 30 Hz AM. 220 ms | 450–900 | C+ | 2 | cmb/60/`eshot` | 0.1 |
| `eshot_laser` | Sentry shot | 2× saw 880 ±10 ct → svf.bp(1.2k→700/120, Q6); T white bp 1.5k 5 ms. 140 ms | 0.6–1.3k | C+ (−21) | 2 | cmb/65/`eshot` | 0.06 |
| `tele` (shooters: weaver, rot weaver, sentry sight, puffcap) | Enemy attack wind-up, **ending exactly on release**. Played by the Developer's `tele(total_s, at, who)` **[DEV-A15: ACCEPT, amended]** | **The Threat Warble, one 1.5 s master file:** 2× pulse(.3) ±12 ct rising exponentially from 220 to **880 Hz at the end**; svf.bp tracking f (the fundamental), Q3, so the energy stays inside R1; amplitude +18 dB exponential rise; tremolo 10 → 22 Hz (depth 40%); hard 1 ms stop; release tick white bp 1k 4 ms. **Runtime plays it with `play(from_position = 1.5 − total_s)`**, so every telegraph of any length ends on the same top pitch at the same moment: the "now!" is invariant and learnable. No start delay and no length buckets | **330–1200 (R1)** over its last 0.5 s | **A (−17)** at the end | 1 | crit/80/group `tele` 3 | 0.1 |
| `tele_charge` **NEW** (ram, bugling, spark plug, thorn ram, Kernel Panic's run) | Charge wind-up (`enemy.gd:398-400`) | The same warble, **one register lower** (165 → 660 Hz) with an 8 Hz "stamp" AM in the last 0.3 s; release tick = a low stomp, sine drop(200→90/40) sat | R1 | A | 1 | crit/80/`tele` | 0.1 |
| `tele_slam` **NEW** (golem slam ring, tick fuse, Collector dump) | Area wind-up (`enemy.gd:436-448`, `590-598`) | The warble with a **falling sub partner**: a second voice from 440 down to 220 Hz under the rising one (the interval opens), release tick = a thud, modal.stone(240, 60) | R1 | A | 1 | crit/80/`tele` | 0.1 |
| `tele_short` / `tele_mid` / `tele_long` | **Retired** (`tele` + offset play replaces the three length buckets). The files are removed; the ids stay as aliases to `tele` in the cue table until the call sites move | — | — | — | — | — | — |
| `slam` | Golem slam lands | T white bp 1.5k 10 ms; B sine drop(130→55/300) sat(8), **phantom**; modal.stone(240, 250); brown LP 900 400 ms; room.S 12%. 700 ms | **200–1.2k** (was 100–200) | A | 2 | crit/75/2 | 0.1 |
| `fuse` | Glitch Tick blinking (every 0.2 s) | pulse 880 → svf.bp 880 Q8, 5 ms; white bp 3k 3 ms −10 dB. 40 ms | 0.8–3k | W (−26) | 1 | cmb/50/2 | 0.1 |
| `fuse_pop` | A Tick bursts | T white hp 2k 5 ms; B sine drop(260→90/150) sat(6), phantom; pink LP 2.5k 200 ms; crush(3, 8, .4). 350 ms | 200–2.5k | A | 2 | crit/75/2 | 0.08 |
| `summon` | The Brood Stump spawns buglings | ks(220, .4, .2) creak with +2 st bend; chitter grains (sine 3–5k, 8 ms) 30/s for 250 ms. 450 ms | 0.2–5k | C+ | 2 | cmb/55/1 | 0.3 |
| `ward_up` | A Wisp wards allies | fm(1047→2093/200, 1.41, 1); modal.glass(4186, 300) at 200 ms. 450 ms | 1–4k | C+ | 2 | cmb/55/1 | 0.2 |
| `charge` | A Ram's charge starts | pink svf.bp(500→1.5k/250, Q2); saw 110 sat with 18 Hz AM (stomps), phantom. 350 ms | 0.3–1.5k | C+ (−21) | 2 | cmb/65/2 | 0.1 |
| `bonk` | A Ram hits a wall, stunned: **an opening** | T white bp 2k 5 ms; B modal.wood(300, 120) + sine drop(180→120/80) sat; "stars": glass trill 2637/3136/3520 over 150 ms −12 dB. 400 ms | 0.3–3.5k | E | 2 | cmb/60/1 | 0.1 |
| `spawn` | The spawn rune appears (`world.gd:574`) | whoosh-up: pink svf.bp(400→2.5k/700, Q5) amplitude rising; fm(440→880/700, 1.41, 1); release tick. 800 ms. *Tonal but no warble*, so it does not read as an attack | 0.4–2.5k | C+ | 1 | cmb/55/1 | 0.3 |
| `burn` | Burn DoT tick (`enemy.gd:272`) | crackle 40 ms 300/s → bp 3k. 60 ms | 2–5k | W (−30) | 3 | det/10/1 | 0.15 |
| `freeze` *(dead)* **HOOK** | An enemy freezes (`world.gd:1474`) | modal.glass(2637, 250); white hp 5k svf(8k→4k/200) "crystallise"; fm(1319, 1.41, 1→0). 350 ms | 1.3–8k | C+ | 2 | cmb/50/2 | 0.1 |
| `panic` **NEW, HOOK** | Kernel Panic at half HP (`enemy.gd` ~477, which today reuses `tele_mid`) | A two-tone siren: pulse 1320 ↔ 1245 alternating at 8 Hz, sat(2) → svf.lp 3k; 600 ms, rising 3 dB | 1.2–2.6k | A | 1 | crit/85/1 | 0.5 |
| `blink_charge` **NEW, HOOK** (the audit's ids; replaces my `blink`) | The Blink Tick's 0.45 s wind-up (`enemy.gd:508-513`), played **at the landing spot** | `tele_charge`'s last 0.45 s is not used here. It is its own 0.45 s cue: a crushed rising sigil trill 880 → 1760 (30 ms steps) at the destination; a *where*, not an attack | 0.9–1.8k | C+ | 1 | cmb/65/2 | 0.1 |
| `blink_land` **NEW, HOOK** | The Tick arrives (`enemy.gd:503`, replaces `tele_short` there) | rev(whoosh 1k→5k, 120 ms) → pop sine drop(600→300/30) + crush. 180 ms | 0.6–5k | C+ | 2 | cmb/60/2 | 0.1 |
| `thorns` **NEW, HOOK** (via `enemy_shot` prefix `thorns:`) | A charge lays a line of thorns (Bramble Ram, Spark Plug; `enemy.gd:414-418`). **One cue per dash, not per thorn** **[DEV-A16: ACCEPT the prefix mapping]** | Bramble: ks(330, .2, .5) plucks ×6 in a 400 ms scatter (seeded) + a pink rustle; Spark Plug gets the `static` variant (crackle trail 400 ms). 450 ms | 0.3–4k | C+ | 2 (bramble, spark) | cmb/55/1 | **0.4** |
| `trail_loop` **NEW, HOOK** (loop) | The Loop's burning chase trail (`boss_loop.gd:273`, 3 s) | **Seamless 2.0 s loop:** pink svf.bp 1.2k Q1.5 + grain crackle 60/s + a low 55 Hz sat hum with phantom (a burning cable), −22 LUFS-M. Played by `Audio.loop(&"trail", on, at)` with the pan following the head | 0.2–3k | C+ | 1 | dedicated loop voice | — |
| `box_fill` **NEW, HOOK** (prefix `box:`) | Select All's box fills with shots (`boss_copy_paste.gd:185-190`) | One cue: a crushed "selection fill" white svf.bp(800→4k/250, Q2) + 8 rapid sigils 1760→3520 over 200 ms + a threat thud. 350 ms | 0.8–4k | A | 1 | crit/80/1 | 0.5 |
| `trash` **NEW, HOOK** (prefix `trash:`) | The Collector's compact charge sheds trash (`boss_collector.gd:86-89`) | One 0.6 s grinding cue per compact: brown svf.bp 300–900 AM 16 Hz + clanks modal.plate(700) ×4 scattered + crush | 0.3–1.5k | C+ | 1 | cmb/60/1 | 0.6 |
| `elite_arrive` **NEW, HOOK** | An elite spawns (encounter director) | 2× saw 440/445 sat(3) → svf.lp 2.2k: motif head with a tritone, A → D♯ (0/120 ms); modal.brass(880) on the downbeat. 500 ms | 0.4–2.5k | A | 1 | crit/70/1 | 0.5 |
| `hit_proxy` **NEW, HOOK (P3)** | A hit is redirected to the Proxy (`world.gd:1355-1358`; the audit rates it low priority) | T click; modal.plate(2093, 60) "deflect" + sine penv(2637→1760/120) ricochet whine. 150 ms | 1.7–3k | C+ | 3 | cmb/55/2 | 0.05 |
| *(`static_arc` dropped)* | **[DEV-A17: ACCEPT]** The audit shows the arced hit already plays `hit_static`; a separate cue would be spam | — | — | — | — | — | — |
| `thermal` **NEW, HOOK** (the audit's id; was my `thermal_shock`) | Fire meets ice (`world.gd:1494`; replaces `boom`) | white hp 3k svf.bp(6k→2k/250) "steam"; modal.glass(1760, 120) crack at 0; sine drop(400→200) sat. 350 ms | 0.4–6k | E | 2 | cmb/65/1 | 0.1 |

### 4.7 Bosses

#### 4.7.1 Boss telegraphs, one per move (the audit's point (e) **[DEV-A18: ACCEPT, amended]**)
Today `boss.gd:138` plays a 0.52 s `tele` at the *start* of every wind-up, so it ends up to 0.68 s early, and some moves add a second cue on top. The new rule:
- **Every boss move has exactly one wind-up cue.** It is played through `tele(total_s, at, move)` from a **1.5 s master** with `from_position = 1.5 − total_s`, so it **ends on the frame the attack releases**.
- **Moves with a signature cue** (identity matters: what is coming) use a *signature telegraph*. It is the Threat Warble's rising envelope and hard stop, with the move's identity layered in. The other moves use `tele_boss`.
- **Nothing else plays at wind-up start.** The announce text stays visual.

Wind-up = `move_table[move][0]` s, × 0.85 from phase 2 (`boss.gd:133`). The 2.0 mini-boss versions and any haste scale pass through `total_s` unchanged.

| Boss | Move | Wind-up p1 / p2+ (s) | Wind-up cue | Replaces (audit) |
|---|---|---|---|---|
| Copy-Paste | copy_cast | 0.60 / 0.51 | **`copy_cast`** (signature) | `copy_cast` at `_start` (`:130`) + generic `tele` |
| | undo | 0.70 / 0.595 | `tele_boss` (then `ctrl_z` on the jump, `:165`) | generic `tele` |
| | dup_row | 0.80 / 0.68 | `tele_boss` | generic `tele` |
| | paste | 0.60 / 0.51 | `tele_boss` (then `paste` on act, `:179`) | generic `tele` |
| | select_all | **1.20 / 1.02** | **`select_all`** (signature) (then `box_fill` on the fill) | `select_all` at `_start` (`:146`) + generic `tele` |
| Garbage Collector | collect | 0.70 / 0.595 | **`tele_collect`** (signature) | `tele_mid` (`:62`) + generic `tele` |
| | compact | 0.80 / 0.68 | `tele_charge` (register of a charge) | generic `tele` |
| | dump | 0.60 / 0.51 | `tele_slam` | generic `tele` |
| The Infinite Loop | lap_charge | 0.80 / 0.68 | **`tele_lap`** (signature) | `chomp` at `_start` (`:223`) + generic `tele` |
| | tail_volley | 0.50 / 0.425 | `tele_boss` | generic `tele` |
| | while_true | 0.60 / 0.51 | `tele_boss` | generic `tele` |
| | chase | 0.60 / 0.51 | `tele_charge` | generic `tele` |
| Deadlock | volley | 0.60 / 0.51 | `tele_boss` | generic `tele` |
| | sweep | 0.90 / 0.765 | **`tele_sweep`** (signature), which hands over to the `beam` loop | `chomp` at `_start` (`:190`) + generic `tele` |
| | crossfire | 0.70 / 0.595 | `tele_slam` (two rings) | generic `tele` |

All wind-ups are ≤ 1.2 s, so the 1.5 s masters cover every move with 0.3 s to spare.

| id | Meaning / call site | Recipe (1.5 s masters are offset-played; the recipe describes the full 1.5 s) | Band | Fam | Var | Class/prio/cap | Gap |
|---|---|---|---|---|---|---|---|
| `tele_boss` **NEW** | Generic boss wind-up | The Threat Warble at boss scale: 3× pulse(.3) (±12 ct and an octave below) rising 165 → 660 Hz; plus a sub sine at half f through sat, phantom; tremolo 10 → 22 Hz; hard stop; release tick = modal.stone(240, 80) + white bp 1k | R1 + 200–400 | A | 1 | crit/85/`tele` | 0.1 |
| `copy_cast` (kept id, now a signature telegraph) | Copy-Paste winds up your program | The warble envelope carrying **your own cast sigils reversed and glitching**: rev(sigils 1760, 2093, 2637, 3520 in a loop) → stutter + crush(6, 5), comb(2.3 ms, .7), rising to the hard stop | 1–4k + R1 | A | 1 | crit/85/1 | 0.3 |
| `select_all` (kept id, now a signature telegraph) | Box outline wind-up | The Ctrl-A chime (sigils 1760 / 2093 / 2637) at the head of the file, then a rising warble whose tremolo is replaced by **selection ticks** at 8 → 24 Hz (a marching-ants rhythm); hard stop | 1.7–2.7k + R1 | A | 1 | crit/85/1 | 0.3 |
| `tele_collect` **NEW** | The Collector starts pulling | A suction warble: brown svf.bp(200→900, Q3) rising, with the warble pulse inside it; hard stop with a "gulp" click | 0.2–1.2k | A | 1 | crit/85/1 | 0.3 |
| `tele_lap` **NEW** | The Loop's lap charge (the track lights up) | The warble + **jaw clacks accelerating** (modal.wood 180 at 4 → 16 Hz); ends with `chomp`'s double clack exactly on release | 0.2–2k + R1 | A | 1 | crit/85/1 | 0.3 |
| `tele_sweep` **NEW** | The Deadlock beam charges | The warble tuned into the beam's own hum (a saw 110 + 165 fifth rising one octave) → hard stop that **lands on the `beam` loop's first sample** | 0.2–1.2k | A | 1 | crit/85/1 | 0.3 |
| `ctrl_z` | The undo jump (act, `:165`) | saw penv(2640→330/300) "rewind" → svf.bp tracking Q5; rev pink; end click. 350 ms | 0.3–2.6k | A | 1 | crit/85/1 | 0.3 |
| `paste` **NEW, HOOK** | CTRL+V pastes buglings (`boss_copy_paste.gd:179`) | sigil 2637 → 1760 (a descending "paste") + comb(1.13, .6) + three quick `summon` chitters. 300 ms | 1.7–5k | C+ | 1 | cmb/65/1 | 0.3 |
| `chomp` | A bite that lands (the Loop's head, Deadlock) | T white bp 2k 8 ms; two jaw clacks modal.wood(180, 80) at 0/60 ms; sine drop(200→90/100) sat, phantom. 250 ms. **No longer used as a wind-up** | 0.2–2k | A | 2 | crit/75/1 | 0.2 |
| `beam` **NEW, HOOK** (loop) **[DEV-A19: ACCEPT]** | The Deadlock beam is live (`boss_deadlock.gd:203-207` on, `232-235` off, `168-169` phase 3 permanent) | **Seamless loop of 1.0 s** (44,100 samples; every partial completes whole cycles): saw 110 + saw 165 (a fifth) sat(4), phantom; svf.bp 800 Q3 swept by an LFO at 2 Hz (a whole number of cycles per loop); crackle 400/s bp 4k −14 dB; −21 LUFS-M. **Phase 2** ("the beam turns faster"): the loop player's `pitch_scale = 2^(2/12)`, set after `play()` (web bug #95850). Pan: the beam midpoint's screen x at 0.4 strength | 0.2–1.2k + 3–5k | C+ (continuous; kept under A so the warbles on top still read) | 1 | dedicated loop voice (the audit's 3.11) | — |
| `derail` | The Loop derails (an opening, ×2 damage) | Screech: saw penv(1760→440/600) → comb(2.2 ms, .8); modal.plate(300, 600) impact at 400 ms; then an "opening" chime modal.brass(880 → 1319 fifth, 0/100 ms). 1.0 s | 0.3–2k + R2 ring | M | 1 | crit/90/1 | 0.5 |
| `roar` | Boss phase roar (`boss.gd:78`) | saw 110 + saw 111.5 + pulse 55, sat(8) → svf.lp(2.5k→700/900, Q3); formant band-passes 700 and 1200 Hz ("aw"); 25 Hz AM grit 30%; phantom; crush wet .2. 1.1 s | 0.2–1.5k | M | 1 | crit/95/1 | 0.5 |
| `phase` | Boss phase change (`boss.gd:77`) | T white hp 2k 10 ms; rev(fm(220, 2.76, 4→0/600)) swell into modal.bell(220, 1.5 s); sine 55 sat, phantom; crush bits 12 → 4 over 1 s ("the program corrupts"). 1.8 s | 0.2–3k | M | 1 | crit/95/1 | 0.5 |
| `key_turn` **NEW, HOOK** (the audit's id; was my `lock_swap`) | Deadlock: which Mutex is open changes (`boss_deadlock.gd:138`; replaces `tele_mid`, which warned of an attack that never came) **[DEV-A20: ACCEPT]** | A *good* event: a key turning. Two iron clacks modal.plate(880, 200) at 0/70 ms; sigil up a fifth (1760 → 2637) = "unlocked"; panned to the open Mutex. 300 ms | 0.9–2.7k | E (not A: it is an opportunity, not a threat) | 1 | cmb/80/1 | 0.3 |
| `weak_open` **NEW, HOOK** | A boss weak window opens (Copy-Paste lag after Ctrl+Z; Deadlock lock break) | "Opening" chime: modal.brass(880) then (1319) at 0/100 ms + sigil 3520. 400 ms | **R2 ring** | E | 1 | cmb/80/1 | 0.5 |
| `gulp` **NEW, HOOK** (the audit's id; was my `gc_eat`) | The Collector swallows one of your shots (`boss_collector.gd:81`), rate-limited | Gulp: brown svf.bp(400→200/200, Q4) + sine drop(300→120/150) sat; crush(5, 6, .5). 300 ms. Walk **chain**: +1 step per gulp within 0.4 s (the stomach filling up), capped at 5 | 0.2–0.9k | C+ | 2 | cmb/65/1 | 0.12 |
| `choked` **NEW, HOOK** | The Collector CHOKES on Blast (`boss_collector.gd:83`): **an opening** | A cough (brown bursts ×2 at 0/140 ms, svf.bp 600) + the `weak_open` brass fifth. 600 ms | 0.3–3k | E | 1 | cmb/80/1 | 0.5 |
| *(`gc_spit` dropped)* | **[DEV-A21: ACCEPT]** The audit rates the returned fan's `eshot` as OK | — | — | — | — | — | — |
| `segment_break` **NEW, HOOK** | A Loop segment breaks (`boss_loop.gd:187`) | modal.plate(520, 250) + crackle 150 ms + a "code block" sigil run 2637→1760 crushed. 350 ms | 0.5–3k | E | 2 | cmb/75/1 | 0.15 |
| `loop_jr` **NEW, HOOK** | Loop Jr. splits off (`boss_loop.gd:199`) | A small `roar` at +12 st, 400 ms, with a comb(1.13, .5) "copy" ring | 0.4–2.5k | A | 1 | crit/80/1 | 0.5 |
| `back_on_track` **NEW, HOOK** | The Loop re-rails; the opening closes (`boss_loop.gd:144`) | Reversed `derail` screech (440→1760 / 500 ms) + a clack | 0.4–2k | A | 1 | crit/80/1 | 0.5 |
| Copied spells | Copy-Paste's copies of your spells (`boss_copy_paste.gd:221`, today `eshot`) **[DEV-A22: ACCEPT, amended]** | **No new files:** the player's own cast id plays at −2 st through a new **`Glitch` bus** (→ SFX) carrying one `AudioEffectDistortion` in LOFI mode (bit-crush), which only costs CPU while signal flows (Copy-Paste fights) | as the cast | C+ | — | cmb/60/`eshot` | 0.06 |

### 4.8 The world

| id | Meaning / call site | Recipe | Band | Fam | Var | Class/prio/cap | Gap |
|---|---|---|---|---|---|---|---|
| `crate` | A crate breaks (`world.gd:1094`) | modal.wood(260, 90); white bp 1.5k 60 ms; splinter grains 30/s for 150 ms. 250 ms | 0.26–2k | E | 3 | cmb/50/2 | 0.05 |
| `pod_pop` | A spore pod pops | sine penv(600→200/40) sat; pink bp 1k Q2 150 ms; wet grains. 300 ms | 0.2–1.5k | E | 2 | cmb/50/1 | 0.1 |
| `bramble_burn` | Brambles burn away | grain crackle 120/s for 500 ms; pink svf.bp(1k→3k/500). 600 ms | 1–5k | E | 2 | cmb/45/1 | 0.2 |
| `crack_open` | A secret wall cracks | modal.stone(200, 300), phantom; brown LP 1.5k 500 ms (crumble); stone grains 60/s. 700 ms | 0.2–1.5k | E | 1 | cmb/60/1 | 0.3 |
| `secret` | A secret found (with crack_open) | Motif head on glass bells: A E C (1760/2637/2093) at 0/110/220 ms; shimmer grains 5–8k. 1.0 s | 1.7–8k | E | 1 | cmb/65/1 | 0.5 |
| `pylon` | A pylon is hit (4 derail the Loop) | modal.bell(440, 1.2) + fm(880, 3.5, 2→0). Walk **chain by pylon count**: A, C, E, A' (1..4). **HOOK: pass count** (or `audio.gd` counts and resets on `derail`) | 0.4–3k | E | 1 | cmb/70/1 | 0.2 |
| `pit_fall` | Something falls into a pit | sine penv(1320→330/450) + pink LP 1k fading. 500 ms | 0.3–1.3k | E | 1 | cmb/50/1 | 0.2 |
| `chest` | A chest opens (with sting_reward) | **Lid only; the sting carries the music:** ks(90, .3) creak with +1 st bend; modal.wood(180, 150) thunk at 250 ms; glass shimmer grains 3–6k for 400 ms. 700 ms | 0.2–6k | E | 1 | cmb/60/1 | 0.5 |
| `forge` | Buy at the forge (`shop_screen.gd:152`) | Anvil: modal.plate(620, 600) + modal.brass(1240); white hp 3k 10 ms; quench hiss white hp 4k 300 ms. 900 ms | 0.6–5k | U+ (−21) | 2 | ui/60/1 | 0.2 |
| `altar` *(dead)* **HOOK** | An Altar gift is taken (costs 15% max HP) | rev(modal.bell(220)) 500 ms swell → modal.bell(220, 1.2 s) in minor; sine 110 sat, phantom. 1.5 s | 0.2–2k | E | 1 | crit/70/1 | 0.5 |
| `door` *(dead)* **HOOK** | Doors unlock at room clear, once (`world.gd:691` `_open_doors`, guarded by `not doors_open`) | Stone slide: brown svf.lp(400→1.2k/500); grind grains 60/s; end thunk modal.stone(120), phantom. 700 ms | 0.2–1.2k | E | 1 | cmb/55/1 | 0.5 |
| `door_shut` **NEW, HOOK** | The room locks as combat starts | modal.stone(160, 200) slam, phantom; dust grains; room.S 10%. 500 ms | 0.2–1.5k | E | 1 | cmb/60/1 | 0.5 |
| `glitch_toll` **NEW, HOOK** (the audit's id; was my `glitch_door`) | Pay the Glitch Door's toll, −10 max HP (`world.gd:742`) | Corrupted chime: modal.glass(1760) crushed (4, 5) and stuttered ×3; sine drop(110→55) sat, phantom. 800 ms | 0.2–3k | E | 1 | crit/70/1 | 0.5 |

### 4.9 Rewards and progression

| id | Meaning / call site | Recipe | Band | Fam | Var | Class/prio/cap | Gap | Walk |
|---|---|---|---|---|---|---|---|---|
| `coin` | Gold pickup (`world.gd:676`, rewards) | modal.glass(3520, 80) + sigil(5274, 8). 110 ms | 3.5–6k | C | 3 (glass excite) | cmb/35/2 | 0.04 | **chain** (≤ 6 steps within 0.25 s) |
| `heal` | Healing: the spring (`world.gd:879`), the boss full heal (`world.gd:656`) | A–C♯–E glass bells (1760/2217/2637) 60 ms apart; sine 880 aenv(50/400) −10 dB. 600 ms | 0.9–2.7k | E | 1 | cmb/60/1 | 0.3 | — |
| `heal_small` **NEW, HOOK** | Small heals: room-clear +6 (`world.gd:644`), Leech Loop (`world.gd:1627-1630`) **[DEV-A23: ACCEPT]** | One glass bell 2637 + a soft sine 1319 swell. 250 ms | 1.3–2.7k | W (−28) | 2 | det/20/1 | 0.5 | — |
| `heart` **NEW, HOOK** | The MAX HP +15 room reward (`world.gd:679-682`) | `heal`'s triad + a lub-dub (the `low_hp` beat, inverted: warm and rising) + a brass ring 880. 800 ms | 0.2–2.7k | E | 1 | cmb/65/1 | 0.5 | — |
| `relic_proc` **NEW, HOOK (P3)** | A relic effect fires (Watchdog free cast, Loop Counter's 10th: the audit's `spell_runner.gd:86-88, 119-121`; the Developer may add others) | modal.glass(3136, 150) + modal.brass(1568, 200) −6 dB. 250 ms | 1.5–3.5k | C | 2 | cmb/45/1 | 0.3 | — |
| `caught` **NEW, HOOK** (the audit's id; was my `relic_save`) | Try/Catch saves you from death (`player.gd:289`) | Brass bell modal.brass(880, 900) + major motif fragment on glass (1–3–5) + shimmer; dry onset. 1.2 s | 0.9–3k | M | 1 | crit/98/1 | 1.0 | — |
| `wand_recharge` **NEW, HOOK (P2)** | The wand's program wraps and recharges | "Cadence": sigil at the root **one octave down** (880) + a soft ratchet (3 clicks, white bp 3k, 25 ms apart). 90 ms | 0.9–3k | W (−30) | 1 | det/20/1 | 0.15 | resets the slot walk |

### 4.10 UI (class `ui`, UI bus; dry)

| id | Meaning / call site | Recipe | Band | Fam | Var | Prio/cap | Gap |
|---|---|---|---|---|---|---|---|
| `ui` | Generic tap (`screen.gd:130`, …) | sigil(2093, 12) + modal.wood(1400, 30). 50 ms | 1.4–3k | U | 2 | 30/3 | 0.03 |
| `ui_back` | Back / close / done | sigil(1568, 12) + modal.wood(1050, 30). 50 ms. *Lower = back* | 1–2.5k | U | 2 | 30/3 | 0.03 |
| `ui_open` | Open a panel: **a grimoire page turn** (`main.gd:340`) | pink whoosh svf.bp(1.5k→4k/90, Q1.5) "paper"; sigil(1760, 12). 140 ms | 1.5–4k | U | 2 | 40/3 | 0.05 |
| `ui_close` | Close a panel | Reverse sweep 4k→1.5k; sigil(1319, 12). 130 ms | 1.3–4k | U | 2 | 40/3 | 0.05 |
| `ui_equip` | Slot a spell into the wand (+ haptic snap) | T white hp 4k 3 ms click; B modal.glass(2637, 90) + modal.brass(1319, 150): **a gem seating in gold**. 200 ms | 1.3–3k | U+ | 2 | 50/2 | 0.05 |
| `ui_drag` *(dead)* **HOOK** | Pick up a rune in the editor | sine penv(880→1320/60); white bp 3k 30 ms −8 dB. 80 ms | 0.9–3k | U | 1 | 30/2 | 0.05 |
| `ui_drop` | Drop into the bag | modal.wood(700, 60) + sigil(1319, 10). 90 ms | 0.7–2k | U | 2 | 40/2 | 0.05 |
| `swap` *(dead)* **HOOK** | Swap the active wand (HUD `swap` button, `main.gd:451`) | Two card-shuffle swishes (white svf.bp 2.5k Q2, 20 ms) at 0/45 ms; sigil 1760 → 2349. 110 ms | 1.7–3k | U | 1 | 40/2 | 0.1 |
| `deny` | Can't afford / invalid | Two dull buzzes, pulse(.25) 220 + 233 → svf.lp 1.2k, 60 ms each at 0/80 ms. 160 ms | 0.2–1.2k | U+ | 1 | 50/1 | 0.1 |
| `buy` | Purchase | Two tinks modal.glass(2349 D7) → (3520 A7) at 0/70 ms; modal.brass(1760) "ka". 300 ms (shop key D) | 1.7–3.5k | U+ | 1 | 50/1 | 0.1 |
| `pick` | Take a reward (`reward_screen.gd:233`) | Motif head in D on FM bells: D5 A5 F5 (587/880/698) 60 ms apart; sigil. 450 ms | 0.6–3k | U+ | 1 | 50/1 | 0.2 |
| `levelup` | A merge / level-up (`shop_screen.gd:155`, `reward_screen.gd:233`) | Motif in **major**, fast: A E C♯ D E ‖ G♯ A (45 ms steps) on FM bells; final modal.brass(880, 800) + shimmer. 1.1 s | 0.4–4k | **M (−18 on UI)** | 1 | 60/1 | 0.3 |
| `ui_confirm` **NEW, HOOK** | A big confirm: start run, TAKE & EQUIP, choose door on map | sigil 1760 + 2637 dyad; modal.glass(3520, 150). 180 ms | 1.7–3.5k | U+ | 1 | 50/1 | 0.1 |
| `compile` **NEW, HOOK (P3; my addition, since the audit rates today's `forge` + `levelup` as OK)** | A forge evolution (Compile); it replaces that pair for evolutions only | Anvil modal.plate(620) + full motif on brass bars (40 ms steps) + tag ♭7–1 + shimmer. 1.6 s | 0.6–4k | M | 1 | 70/1 | 0.5 |
| `unlock` **NEW, HOOK (P3)** | A goal done / meta unlock (end screen) | Glass bells, motif head in major + brass ring. 1.2 s | 0.9–3.5k | U+ | 1 | 60/1 | 0.3 |
| `ui_pick` **NEW, HOOK** | Tap-select a slot in the editor (`editor_screen.gd:527`) | modal.glass(2093, 50) + sigil(1760, 8). 60 ms | 1.7–2.5k | U | 2 | 30/2 | 0.04 |
| `tip` **NEW, HOOK** | A first-run tip is *shown* (`hud.gd:112`) | A soft page tick: pink svf.bp 3k 25 ms + sigil(2637, 10) −6 dB. 60 ms | 2.5–3.5k | U (−27) | 1 | 20/1 | 1.0 |
| `duck_say` / `glitch_say` **NEW, HOOK (P3; WIP code, coordinate with its owner)** (the audit's id; was my `duck_talk`) | The Duck's lines / "???" lines pop (`hud.gd:108`, uncommitted WIP) | Non-verbal babble, one syllable per 2–3 characters (runtime schedules). Duck: saw 700 ±2 st random per syllable → formant band-passes 1.2k + 2.6k (Q5), 60–90 ms, a squeaky rubber attack. Glitch: the same with crush(4, 4) and a fixed pitch | 0.7–3k | U (−26) | 3 each | 20/1 | 0.06 |

**UI stacking [DEV-A24: ACCEPT]:** `Screen.press` becomes overridable (B13). One tap makes one sound: the handler's specific cue (`pick`, `buy`, `ui_confirm`, `deny`) replaces the generic `ui`/`ui_back`, and `main.gd:342` drops `ui_close` when a close sound already played this frame. The editor's drop reads `place_spell`'s result: "place"/"insert" → `ui_equip`, "swap" → `swap`, bag full → `deny`.

**Deleted:** `win` and `lose` (never played; superseded by `sting_victory` / `sting_defeat` and the new `die`), and `tele_short`/`tele_mid`/`tele_long` (aliases to `tele`). `test_feel.gd::test_every_sound_the_game_asks_for_exists` requires `win` and `lose` today, so the Developer updates that list. The tests' "≥ 70 distinct SFX" stays satisfied: the new set is **about 140 ids**.

### 4.11 Ambience spots (NEW; played by `audio.gd` itself, no gameplay hook)
Every 3–9 s (seeded), one random spot from the area's list plays on the Ambience bus with a random pan of ±0.7. 22.05 kHz mono, family W (−32).

| Area | Spots |
|---|---|
| Cellar | `amb_drip` ×4: modal.glass(2–3k, 60) + a 180 ms echo at −9 dB; `amb_creak` ×2: ks(70, .5, .1) with a 1 st bend |
| Grove | `amb_rustle` ×3: pink svf.bp 2–4k grain rustle 600 ms; `amb_glitch` ×3: FM chirps 3–5k crushed |
| Foundry | `amb_steam` ×3: white hp 2k svf sweep 1.2 s; `amb_clank` ×3: modal.plate(400–700, 300) at −6 dB with room.M |

This breaks the 20 s bed's loop recognition at the cost of one voice.

---

## 5. Music spec

### 5.1 Global
- **Format:** 32 kHz mono 16-bit WAV, QOA on import (kept). Every tempo gives a **whole-sample bar** at 32 kHz: bar = 7,680,000 / bpm. The usable integer tempos are 80, 96, 100, 120, 125, 128, 150 and 160.

| bpm | Samples per bar | Samples per 16th |
|---|---|---|
| 96 | 80,000 | 5,000 |
| 120 | 64,000 | 4,000 |
| 125 | 61,440 | 3,840 |
| 128 | 60,000 | 3,750 |
| 150 | 51,200 | 3,200 |

- **Instruments** (all from §3, replacing today's `INST`):
  - `pad_warm`: supersaw 5 voices ±10 ct → 2× SVF-LP 24 dB at 1.8–2.4 kHz, a 0.1 Hz LFO ±300 Hz on cutoff, ADSR 400/400/.8/600.
  - `pad_dark`: supersaw ±16 ct, SVF-LP 1.1 kHz, wow 0.7 Hz ±12 ct.
  - `harp`: ks with bright .6.
  - `musicbox`: ks with bright .9 + modal.glass(2f, 80) ping.
  - `pizz`: ks with bright .3, t60 .25.
  - `bass_sat`: pulse(.3) → SVF-LP env (fc 400→1.4k per note, Q1.2) → sat(3), phantom.
  - `lead_pwm`: pulse, duty .3 ± .1 at 0.3 Hz → SVF-LP env 900→2.8k per note, Q1.5, vibrato 5.5 Hz ±18 ct after 180 ms.
  - `bell_fm`: ratio 3.5, index 2.2→0.3.
  - `glass`: modal.
  - `brass_saw`: 2× saw ±7 ct → SVF-LP env 600→3k, attack 30 ms, sat(1.5).
  - `furnace_lead`: saw → fold(1.5) → SVF-LP 2 kHz.
  - `choir_pad`: supersaw → formant band-passes 700/1200 Hz.
  - **Drums:**
    - `kick`: sine drop(150→50/120) + click + sat(3) → phantom, so its **body reads at 150–450 Hz**;
    - `snare`: white svf.bp 1.8k Q.8 + modal.wood(240, 80) body;
    - `hat`: crush(2, 8) of white hp 6k, 30 ms closed / 120 ms open;
    - `tom`: modal membrane (the plate ratios at 90 Hz, T60 200) sat;
    - `anvil`: modal.plate(349, 250);
    - `glitch`: crushed burst (kept).
- **Humanisation:** seeded ±4 ms timing on non-downbeat 16ths, ±1.5 dB velocity, and hat swing of 54% (Cellar) / 58% (shop) / 50% (Foundry, machine-straight).
- **Mix inside each cue:**
  - lead stems get a static EQ dip of −4 dB at 800 Hz, Q1 (so R1 stays clear for telegraphs);
  - bass below 120 Hz is mono (everything is mono anyway) and at least 40% of its energy is above 200 Hz (phantom);
  - drum stems have at least 55% of their energy above 250 Hz (today 13%).
- **Loudness:** each cue's full mix (all layers on) is **−20 LUFS-I (±0.5)**, true peak ≤ −1.0 dBTP.
  - Documented layer deltas: base alone −24.5 ±1; +drums +3 LU; +lead +1.5 LU; cumulative ≤ 4.5 LU (per the adaptive-music DOG).
  - Stingers −19 LUFS-I (kept).
- **Leitmotif placement:** each track states its transformation (§2.4) **by bar 4** of the first layer that plays in that state.

### 5.2 Adaptive plan (layers, drivers, quantisation)

| Track id (kept unless NEW) | Stems (files) | State → layer | Quantisation |
|---|---|---|---|
| `cellar`, `grove`, `foundry` | `music_<area>_base` (32 bars), `_drums` (**8 bars**, was 4: drums + motor bass), `_lead` (16 bars) | Driven by the Developer's **hysteretic intensity 0/1/2** **[DEV-A25: ACCEPT]**: 0 = explore (base only), 1 = fighting (+drums), 2 = an elite, ≥ 8 alive, or a boss (+lead). A 2 s hold before stepping down | **Every layer change lands on the next bar** (≤ 2.0 s at 120 bpm), with a 60 ms fade at the barline **[DEV-A26: ACCEPT; replaces my "drums on the next beat"; the spawn rune's 0.8–1.0 s already covers the wait]**. Drums off at clear: a 1-bar fade from the next bar. The clock is the sample clock from `get_playback_position()` (each track gets `bpm`, `beats_per_bar`, `intro_s`) |
| `boss` (final: Loop, Deadlock) | **One file per stem with the intro folded in** **[DEV-A4: ACCEPT]**: `music_boss_loop` = 4 intro bars + 32 loop bars, `loop_begin` = **204,800** (4 × 51,200); `music_boss_p2` = 4 bars of silence + 16 bars, same `loop_begin`; **`music_boss_p3` NEW** = 4 bars of silence + 8 bars, same `loop_begin`. `music_boss_intro` is **retired** | p2 from phase 2 (kept); **p3 from phase 3: HOOK** (one line beside `world.gd:383`) | Next bar from the sample clock (a plain `AudioStreamSynchronized` now reports position). 32 ÷ 16 ÷ 8 keeps the stems aligned after `loop_begin`. **`tools/audio.sh` writes `edit/loop_begin` into the `.import` files** (pipeline change, Technical Artist / Developer) |
| `mini` **NEW** (Copy-Paste, Garbage Collector) | `music_mini_loop` = 2 intro bars + 16 loop bars, `loop_begin` **120,000**; `music_mini_p2` = 2 silent bars + 8 bars, same `loop_begin` | p2 from phase 2 | Next bar. **HOOK:** `room_music()` returns `"mini"` for `kind == &"mini"` |
| `title`, `shop` | One loop each | — | Crossfade 0.8 s (kept) |
| Ambience `amb_<area>` | Stereo bed + spots (§4.11) | Area | Crossfade 1.2 s (kept) |

- **Clock accuracy (RUNTIME):** compute the bar phase from the music player's playback position plus `AudioServer.get_time_since_last_mix()` minus `AudioServer.get_output_latency()`, not from `Time.get_ticks_msec() − _track_t0`. On web Stream mode, output latency is large, so the ticks clock lands early.
- **Keyed stingers (RUNTIME, no call-site change):** `sting(name)` first looks up `sting_<name>_<track>`, then falls back to `sting_<name>`. Files: `sting_clear` (Cellar, A) / `sting_clear_grove` (C#) / `sting_clear_foundry` (F); the same pattern for `sting_reward`.
- **Stinger timing [DEV-A27: ACCEPT]:** `sting_clear` waits for the next *beat* (≤ 0.5 s at 120 bpm) so it lands in time with the bed. `reward`, `boss`, `boss_down`, `victory`, `defeat` and `world` fire immediately. Stingers get a 2-voice pool with priority (B11): `boss_down` > `victory`/`defeat` > `boss` > `reward` > `clear`.
- **A boss kill plays `sting_boss_down`, not `clear` [DEV-A28: ACCEPT]** (§5.10).
- **The area track keeps playing across rooms of the same biome [DEV-A29: ACCEPT].** It restarts only on a biome, shop or boss change, so a 10-room run does not hear bar 1 of the Cellar ten times.
- **Low HP (RUNTIME + HOOK) [DEV-A12: ACCEPT]:** while HP < **30%**, the `low_hp` snapshot puts the Music low-pass at **3 kHz** and −2 dB over 0.4 s, and one `low_hp` beat plays every 1.2 → 0.9 s. It lifts on heal, death or room change, and it has an off switch (**UX Designer owns the setting**: its own toggle, or with Flash/Shake).
- **Snapshots (RUNTIME) [DEV-A30: ACCEPT, the Developer's values]:**
  - `menu` (pause, editor, map, reward, shop over gameplay): Music LPF 1.2 kHz and −4 dB, Ambience −8 dB, SFX tails left alone.
  - `dead`: today's sweep (fixes B4).
  - `low_hp`: as above.
  - `play`: all off.
- **Optional (flagged, not required):** `boss` on Deadlock plays at `pitch_scale = 2^(2/12)` ("overclocked") to give W2's boss its own colour for zero megabytes. It needs the bar clock divided by `pitch_scale`, and the web pitch bug checked (§1.2).

### 5.3 Title: "Incantation"
- D minor, 96 bpm, **24 bars (60 s)**.
- **Form:**
  - Intro, 4 bars: `pad_warm` Dm(add9) + harp arpeggio; motif fragments on glass.
  - **A**, 8 bars: full motif on `bell_fm` over harp and `bass_sat` (root, octave 2); no drums.
  - **B**, 8 bars: the motif sequenced up a 4th, with `brass_saw` doubling an octave below at −10 dB, soft glitch hats and kick on 1 and 3.
  - Tag, 4 bars: the motif augmented, resolving to Dm(add9); the loop wraps to the intro.
- **Progression:** Dm B♭ F C | Dm B♭ Gm A (kept feel).

### 5.4 Shop: "Merchant's Ledger"
- D dorian, 96 bpm, **16 bars (40 s)**.
- `musicbox` plays the motif (dorian, swung 58%) twice, the second time an octave up with a counter-line. There is a `pizz` walking bass, a shaker (white svf.bp 6k with 16th AM, swung), and a `pad_warm` triangle-voiced at −8 dB.
- No kick or snare: the shop is safe.

### 5.5 The Cellar (World 1, rooms 1–4)
- A minor, **120 bpm**, bar 64,000.
- **Base (32 bars = 64 s):**
  - Form: A (8), A′ (8, the harp arp inverted), **B breakdown** (8: pads + drips + wood-block pulse, no arp), A″ (8).
  - Progression (kept): Am F C G | Am F Dm E. The B section keeps the roots and changes the voicings (Fmaj7, Cadd9), so the 8-bar drum stem stays consonant.
  - Instruments: `pad_warm`, `harp` arp in 16ths, a modal.wood block on the off-beats, `bass_sat` on roots in quarters.
- **Drums (8 bars = 16 s):** kick on 1 and the "and" of 2, snare on 2 and 4, swung 16th hats, a fill in bar 8, and a motor `bass_sat` in eighths (the combat drive).
- **Lead (16 bars):** `lead_pwm` opens with the **motif (A E C D E ‖ G A) in bars 1–2**, then develops (keep today's phrase shape), with the answer in bars 9–16 turning home to A. Glass doubling an octave up at −12 dB.
- **Loudness:** −20 LUFS-I full.

### 5.6 The Corrupted Grove (World 1, rooms 5–8)
- C♯ phrygian, **120 bpm with a half-time feel**, bar 64,000.
- **Base (32):** `pad_dark` with crush wet 30% (hold 3, 7 bits); a reversed pad swell into every 4th bar; a detuned `harp` (wow ±15 ct) playing a broken arpeggio; FM bass (ratio 1, index 2) with sat.
- **Progression (kept):** C♯m D C♯m B | A D B C♯.
- **Drums (8):** half-time kick (bar 1) / snare (bar 3) with a long gated noise snare; rim clicks modal.wood(1.2k); glitch stutters on the last 16th of every 2nd bar; a "wub" motor bass (8th notes with a 4 Hz LP LFO).
- **Lead (16):** **the corrupted motif** C♯ G♯ E D **D♮** (1–5–♭3–♭2–1) on crushed `glass`/FM. The second 8 bars stutter every long note into 16ths (kept idea).

### 5.7 The Overheated Foundry (World 2)
- **F minor, 125 bpm** (was D minor at 112, which broke the bar invariant and doubled the title key). Bar 61,440.
- **Base (32 = 61.4 s):** **anvil ostinato** (modal.plate at F4 = 349 Hz: the motif as a riff in steady eighths, F C A♭ B♭ C ‖ E♭ F); steam swells (white hp 2k, 2-bar period, off-beat); `pad_dark` low; `bass_sat` in driving eighths.
- **Progression:** Fm Fm D♭ E♭ | Fm Fm B♭m C (the C major pulls it round, harmonic minor).
- **Drums (8):** four-on-the-floor kick, anvil + noise snare on 2 and 4, straight 16th "hammer" hats (modal.plate 3k tiny), a fill with tom rolls.
- **Lead (16):** `furnace_lead` states the motif as a melody; the second pass adds a `bell_fm` answer an octave up at −10 dB.

### 5.8 Bosses
**`mini` (NEW): Copy-Paste and the Garbage Collector**
- E minor, **128 bpm**, bar 60,000.
- **Intro (2 bars, before `loop_begin` = 120,000):** the motif **retrograde** B A G B E on glitched glass, then a crash.
- **Loop (16 bars = 30 s):** chopped `pad_dark` (a 16th gate stutter pattern); FM bass; glitch drums; the **"copy" lead**, where the motif is played and then "pasted" as a 3/16 feedback delay (3 repeats, fb .45).
- **p2 (8 bars):** `brass_saw` retrograde motif in 8ths, doubled a fifth up.

**`boss` (kept id): the Infinite Loop and Deadlock**
- **C minor, 150 bpm**, bar 51,200.
- **Intro (4 bars, the head of `music_boss_loop`, before `loop_begin`):** a riser (pink svf.bp 400→4k) + tom crescendo + `sting_boss`-style tritone brass. It runs straight into bar 5, the loop point, so there is no hand-over and no clock blind spot.
- **Loop (32 bars = 51.2 s):** the **"infinite loop" ostinato**: the motif in 16th-note diminution (C G E♭ F G B♭ C G) as a 1-bar cell on `bass_sat`. A `harp` counter-cell in **3 : 4 polymeter** (a 12-step cell) restarts every 8 bars, so it phases and realigns. Big drums (kick 1 / "and" of 2 / 3, snare 2 and 4, 16th hats); `pad_dark` on Cm A♭ E♭ B♭ | Cm A♭ Fm G.
- **p2 (16 bars):** `brass_saw` lead in diminution + `choir_pad`.
- **p3 finale (8 bars) NEW:** the motif **augmented** in half notes on brass + `bell_fm`, with half-time big toms. The "full band" moment (Korb).

### 5.9 Stereo and size decisions (justified)
- **Music stems stay mono at 32 kHz, with chorus and reverb baked in [DEV-A3: ACCEPT].**
  - Stereo would double the repo WAV (about +30 MB), the shipped QOA (about +6 MB) and the per-voice decode/mix cost on the web main thread. The layered tracks already run 3–4 synchronised voices.
  - Baking the Music chorus and reverb removes the heaviest always-on DSP from the web main thread (the audit's largest single saving). The cost is the headphone width the runtime reverb's `spread` gave. Phones are mono-ish anyway; headphone width now comes from the stereo ambience beds and panned SFX.
  - A stereo re-render of the stems stays possible later, as a pure generator change, if the web budget allows.
- **Ambience beds go stereo at 22.05 kHz, 20 s loops.** Width matters most there (envelopment on headphones). The content is rolled off above 8 kHz, so 22.05 kHz loses nothing. Three beds cost 5.3 MB of WAV, against 3.1 MB today (mono 32 kHz, 16 s).
- **SFX stay mono at 44.1 kHz.** Bright transients alias less at 44.1 kHz. Width comes from runtime panning.

### 5.10 Stingers (mono 32 kHz, Sting bus, −19 LUFS-I)

| id | Length | Content |
|---|---|---|
| `sting_clear` (+ `_grove`, `_foundry`) | 1.4 s | Motif head 1–5 → 1 on glass bells + modal.brass on 1, in the area key (A / C♯ / F) |
| `sting_reward` (+ `_grove`, `_foundry`) | 2.0 s | Motif in major, ascending, on FM bells + shimmer, in the area key |
| `sting_boss` | 2.5 s | Tritone head 1–♯4 on low `brass_saw` + tom (membrane 90 Hz sat) + a reversed cymbal lead-in |
| `sting_victory` | 5.0 s | The full motif in D major on brass and bells over `pad_warm`; the final 1 held with shimmer |
| `sting_defeat` | 4.0 s | Motif inversion, descending in D minor, ritardando, on harp + `pad_dark`; ends ♭6 → 5, unresolved |
| `sting_world` **NEW, HOOK** | 3.0 s | Entering World 2: the motif in F minor on anvil + brass (`world.gd:762`, `_next_world`) |
| `sting_boss_down` **NEW, HOOK** **[DEV-A28]** | 3.0 s | A boss falls (`world.gd:646` for a boss room, or Audio's `room_cleared` handler keyed on the room kind): motif head in **major** on brass over a held tonic, with shimmer. Distinct from `victory` (the run) and `clear` (a room) |

### 5.11 Size budget (WAV in the repo; the build ships QOA at 1/5)

| Asset | WAV MB |
|---|---|
| title 24 bars @ 96 | 3.84 |
| shop 16 @ 96 | 2.56 |
| cellar: base 4.10 + drums 1.02 + lead 2.05 | 7.17 |
| grove (same shape) | 7.17 |
| foundry @ 125: 3.93 + 0.98 + 1.97 | 6.88 |
| mini @ 128, intro folded: loop (2 + 16 bars) 2.16 + p2 (2 silent + 8) 1.20 | 3.36 |
| boss @ 150, intro folded: loop (4 + 32) 3.69 + p2 (4 + 16) 2.05 + p3 (4 + 8) 1.23 | 6.97 |
| stingers (11 files, 27.7 s) | 1.77 |
| ambience beds (stereo 22.05 kHz, 3 × 20 s) | 5.29 |
| ambience spots (16 × about 1 s, 22.05 kHz mono) | 0.70 |
| SFX (about 140 ids, about 290 files incl. nine 1.5 s telegraph masters and two loops, about 0.35 s mean, 44.1 kHz) | about 9.0 |
| **Total** | **about 54.7 MB (today 41 MB)** |

**Shipped QOA ≈ 10.9 MB (today ≈ 8.2 MB).** The folded intros cost about 1 MB of silence at the head of the p2/p3 stems (QOA does not shrink silence). That is the price of a readable boss clock, and it is accepted.

---

## 6. `mix-bus-topology`

### 6.1 Buses and effects (web-cost aware: 3 always-on effects plus 2 conditional ones, against 5 always-on today)
```
Master        [HardLimiter ceiling -1.0 dB, release 0.1 s]
├─ Music      [Compressor, sidechain=Critical: thr -24 dB, ratio 3, atk 5 ms, rel 300 ms]   (≈4–6 dB duck)
│             [LowPass, enabled only while a snapshot's cutoff < 18 kHz: menu / low_hp / dead]
│             (Chorus and Reverb REMOVED: both are baked into the stems  [DEV-A3: ACCEPT])
├─ SFX        [Compressor, sidechain=Critical: thr -30 dB, ratio 2.5, atk 2 ms, rel 180 ms]  (≈3 dB duck of chatter)
│             (Room reverb REMOVED: space is baked into the E/M families only)
│  └─ Glitch  NEW → SFX  [Distortion, mode LOFI]  (Copy-Paste's copies of your spells; costs CPU only while it carries signal)
├─ Critical   → Master (was → SFX)   no effects; dry   (muted with Sound)
├─ Sting      NEW → Master           no effects        (muted with Music; the music ducks under it by a -6 dB tween, not a sidechain; fixes B3)
├─ UI         no effects
└─ Ambience   no effects
```
- **The SFX sidechain compressor is this document's addition,** not in the audit. It is one compressor, much cheaper than the reverb it replaces. **[Open for the Developer to accept or counter in wave 2.]**
- **Why Critical moves to Master:**
  - The SFX bus can then be ducked under Critical: hurt and telegraphs pull chatter down, which is the Overwatch one-at-a-time rule in bus form.
  - Critical cues stop getting reverb.
  - **RUNTIME consequence:** the Sound toggle must now also mute Critical (today it inherits the mute through SFX).
  - **Mute routing [DEV-A31: ACCEPT, amended]:** the audit proposes Ambience follows *Music* (B1). I agree that it must be muted by a setting, but I propose it follows **Sound**: the beds are world sound, not score. Stingers follow **Music** (they are score) and move to their own **Sting** bus. A stinger is then heard when sound is off and music is on (B3), and the Critical sidechain never ducks the music under a silent cue. While a stinger plays, the music ducks by a −6 dB, 80 ms tween in `sting()` and returns over its tail. **This is the Developer's call on the setting's meaning. The UX Designer may prefer the audit's version, and either one fixes B1.**
- **Master gain structure:** Music player at −4 dB (kept `MUSIC_DB`); Ambience bed at −13 dB (kept `AMB_DB`) against −30 LUFS files, so about −43 at master, about 20 LU under Event cues. SFX/UI/Critical at 0 dB, since the hierarchy is in the files (§4.1).
- **Whole-game target:** combat on Master **≈ −17 LUFS-I ±2** (Sony ASWG portable −18, GANG −16), true peak ≤ −1 dBTP. The limiter reduces gain by more than 3 dB in under 5% of a busy minute.

### 6.2 Voices, classes, priorities (RUNTIME: replaces the `CRITICAL` / `UI` / `GAP` lists with one cue table)

| Class | Bus | Voices | Steal rule |
|---|---|---|---|
| `crit` | Critical | **6** (was 4), **1 reserved for `hurt`/`die`** | Per the Developer's manager **[DEV-A1]**: the lowest prio first, then the quietest effective gain, then the least time left; drop the new cue if every voice outranks it |
| `cmb` | SFX (+ Glitch) | **14** (was 12) | Per-group caps first (a group never exceeds its cap: the new cue replaces the weakest voice *of its own group*); then the manager's order |
| `ui` | UI | 3 | Oldest |
| `det` **NEW** | SFX | 2 | Lowest priority; never steals from other classes |
| Dedicated players | — | music A/B, sting ×2, ambience bed, ambience spot, world loops ×2 (`beam`, `trail_loop`) | — |

All `cmb` and `tele` voices are **`AudioStreamPlayer2D`** with `panning_strength 0.6`, `max_distance 900`, `attenuation 0.6` and `area_mask 0`. Critical cues pan but are not attenuated. **[DEV-A5: ACCEPT, the audit's values; they replace my "no attenuation" suggestion]**

- **Groups and caps:** `cast` 3, `hit` 4 (all `hit_*` + `hit_heavy`), `eshot` 3, `tele` 3; everything else per its row in §4.
- **Priorities:** see §4.
- **Burst merge:** superseded by the Developer's per-frame coalescing (§4.1, DEV-A1, capped at +3 dB). The per-cue `gap` stays as a second guard. The per-frame start budget (6 web / 8 native) replaces my "drop if outranked" as the global limit.
- **The cue table** (one `const CUES := {id: {class, prio, group, cap, gap, gain_db, jitter_cents, pan, walk}}` in `audio.gd`) is the single source that the tests read and the audition sheet prints. Call sites keep `Audio.sfx(id)` and pass only context (`pos`, `slot`, `depth`, `count`), never `volume_db`.

### 6.3 Ducking and sidechain rules
| Rule | Detail |
|---|---|
| Critical → Music | Compressor as above, about −5 dB during hurt/telegraph/moments |
| Critical → SFX | About −3 dB on chatter |
| Hit-stop duck (RUNTIME) **[DEV-A32: ACCEPT, the audit's numbers]** | `on_hitstop(t)` from `world.gd:1216`: when t ≥ 0.08 s (elite kill, hurt, boss phase or kill), duck the SFX bus **−5 dB** for `t`, then release over **80 ms**. Crits (0.045 s) get none; the crit sweetener does that job. The freeze becomes an audible gap and the Critical cue lands in it: the "pause for a frame" of the Art of Screenshake, in audio |
| Stingers | On the Sting bus. `sting()` tweens the Music −6 dB for the sting's length (replaces the Critical routing) |
| UI | Not ducked, and it ducks nothing (menus are mostly paused gameplay) |

### 6.4 Runtime features requested from the Game Developer (prioritised; aligned with the audit's wave-2 order)
1. **The voice manager** (the audit's 3.1 + 3.2): queue, coalesce, per-frame budget, priority steal, the `hurt` reserve, our own variant picker. **The cue table** (§6.2) drives it. Remove the scattered `volume_db` call-site offsets. **[DEV-A1, DEV-A2: ACCEPT]**
2. **Pan** (the audit's 3.3): `AudioStreamPlayer2D` world voices at the audit's values (§6.2). It also sidesteps the web `pitch_scale` bug that `AudioStreamPlayer` has. **[DEV-A5: ACCEPT]**
3. **Buses** (§6.1): Critical → Master, the new Sting and Glitch buses, the SFX sidechain compressor, and no runtime chorus or reverb (baked). Mute routing per DEV-A31.
4. **Snapshots** (the audit's 3.4): `menu`, `dead`, `low_hp`, `play`, which fix B1–B5 on the way. **[DEV-A30: ACCEPT]**
5. **The bar clock** (the audit's 3.5): sample-position clock, `bpm` on every track, intensity 0/1/2 with a 2 s hold, next-bar layer switches, the `p3` layer and the `mini` track. The boss clock depends on the folded-intro pipeline change. **[DEV-A4, DEV-A25, DEV-A26: ACCEPT]**
6. **Length-matched telegraphs:** `tele(total_s, at, who)` plays the class's or move's 1.5 s master from `1.5 − total_s` (§4.6, §4.7.1). **[DEV-A15, DEV-A18: ACCEPT, amended]**
7. **World loops:** `loop(&"beam" | &"trail", on, at)` and `stop_world()` on a room change. **[DEV-A19: ACCEPT]**
8. **Pitch-walks** (the audit's 3.6). Here I **object to the audit's scale** (**[DEV-A33: OBJECT]**, see §8): walks step on the **minor pentatonic of the area key**, `[0, 3, 5, 7, 10, 12, 15]` semitones, not chromatic or half-steps. `pitch_scale = 2^((key_offset + step)/12)`, where `key_offset` is Cellar 0, Grove +4, Foundry −4, title/shop +5 (D).
   - `slot`: the step is the slot index (mod 5); `wand_recharge` resets it.
   - `chain` (kill): +1 step per kill within **0.6 s**, capped at step 5 (+12 st), held, and reset after **0.8 s** of quiet (the audit's timings, accepted).
   - `chain` (coin and crate gold): +1 per pickup within 0.25 s, capped at 6.
   - `chain` (gulp): +1 per gulp within 0.4 s, capped at 4.
   - `depth` (trigger): [0, 7, 12].
   - **No walk on hits** (the audit's "+0.5 st per rapid hit on one target" is declined in DEV-A33).
   - Walked cues get jitter 0 (only ±10 cents humanise).
   - **Verify #95850 on the 4.7.2 web build** (set pitch after `play()`; the 2D players are not affected).
9. **Hit-stop duck** (the audit's 3.7; §6.3). **[DEV-A32: ACCEPT]**
10. **Low-HP heartbeat** (the audit's 3.9; §5.2). **[DEV-A12: ACCEPT]**
11. **Keyed stingers**, the sting pool and `boss_down` (§5.2). **[DEV-A27, DEV-A28: ACCEPT]**
12. **Ambience spots** scheduler (§4.11) and **stereo ambience** (the bed stream is stereo; nothing else changes). Ambience stops on the title and end screens (B2).
13. **Tests** (merge with the audit's §5):
    - family targets from the cue table using `Loudness.momentary_max` and `true_peak_db`;
    - whole-bar stems for **every** layered track at its bpm (the Foundry included), measured after `loop_begin` for the boss and mini;
    - every cue-table id has a file and every file has a cue entry and a manifest row;
    - no id without a call site unless it is marked `hook_pending`;
    - telegraph alignment: `tele(t)` ends within one physics tick of `t`;
    - the audit's storm, priority, critical-reserve, settings, music-state, bar-clock, over-firing and quiet tests.

---

## 7. DOG for this redesign (falsifiable)
A reviewer can disprove each line with the named measurement. The shared tool is the spectral and phone-model script (§1.3), which should be promoted to a new `tools/audio_report.gd`. (`tools/audiosheet.sh` is the orchestrator's audition page and stays untouched; the report can print next to it.)

1. **Family loudness:** every SFX file's `momentary_max` is within **±1 LU** of its family target (§4.1), **or** its true peak is at −1.0 dBTP ±0.2 and its loudness is within 3 LU below target. No file is above target +1 LU.
2. **Peaks:** every shipped file has true peak ≤ **−1.0 dBTP** (4× oversampled).
3. **Music loudness:** every cue's full mix is **−20.0 ±0.5 LUFS-I**. Base-only is −24.5 ±1. The documented layer deltas sum to ≤ 4.5 LU. Stingers −19 ±0.5.
4. **Phone translation:** through the phone model (4th-order HP at 300 Hz, LP at 12 kHz), **no E, A or M family cue loses more than 3.0 dB** (today `slam` −8.5, `bigboom` −8.4, `boom` −6.0). **No drum stem loses more than 4 dB** (today −7.3). **No cue has its dominant octave band below 200 Hz or above 10 kHz** (today `hurt` 100–200 Hz, `hit` 12.8–20 kHz).
5. **Spectral slots:**
   - every telegraph (`tele*`) has **≥ 50% of its energy in 330–1200 Hz**;
   - `hurt` has ≥ 50% in 250–900 Hz;
   - every *dense* combat cue (`hit`, `hit_*`, `cast_*` except `cast_boom`/`cast_void`) has **≤ 15% in 330–1200 Hz**;
   - `crit` has ≥ 45% of its energy in 2.2–3.6 kHz and is the only combat cue whose 2–4 kHz band stays above −30 dB relative for ≥ 150 ms (every other chatter cue decays below that within 60 ms);
   - every music lead stem shows the −4 dB dip at 800 Hz (band energy 600–1000 Hz ≥ 3 dB below the 1.2–2 kHz band's, per unit bandwidth).
6. **Loops:** every music stem and ambience bed is seamless.
   - The first-to-last sample difference is < 0.002 FS.
   - The RMS of the last 50 ms and the first 50 ms are within 3 dB.
   - There is no DC step, and playback shows no click over 3 cycles (audition).
   - Every layered stem's length is a whole multiple of its bar length at its bpm (`samples % bar == 0`), **the Foundry included**. For the boss and mini, this is measured from `loop_begin`, and `loop_begin` is itself a whole number of bars (204,800 / 120,000).
   - The loops `beam` (1.0 s) and `trail_loop` (2.0 s) contain whole cycles of every periodic partial and LFO.
7. **Motif:** a reviewer holding §2.4 identifies the motif and its named transformation by **bar 4** of every music cue and within the first 1.5 s of every stinger, `levelup`, `pick`, `secret` and `compile`.
8. **Coverage:** every cue id in the table has its file(s) and a manifest row. Every id has a call site or is marked `hook_pending` with its hook named. **Zero silent dead ids** (today 10).
9. **Variation:** within each variant set, members differ by **≥ 2 dB in at least one octave band or ≥ 1 semitone in body pitch**, not only by noise seed. No tonal cue has random jitter above ±25 cents.
10. **Determinism:** running `tools/audio.sh` twice on the same machine gives identical SHA-256 for every WAV. Adding a cue changes no other cue's bytes (per-cue seeds).
11. **Regeneration time:** the full `tools/audio.sh` runs in **≤ 8 min** on Bar's Mac (estimate 4–6).
12. **Size:** repo audio WAV **≤ 56 MB**, shipped audio (QOA) **≤ 12 MB**. SFX ≤ 1.2 s except the M family (≤ 2.0 s); stingers ≤ 5 s.
13. **Mix in play:** in a 60 s bot-played combat capture on desktop (`--demo`, an `AudioEffectCapture` on Master):
    - Master is **−17 ±2 LUFS-I**, true peak ≤ −1 dBTP, and limiter gain reduction exceeds 3 dB in < 5% of blocks;
    - at each `tele*` onset, the Critical bus capture's 330–1200 Hz band is **≥ 6 dB above the SFX + Music buses' combined energy in that band** over the telegraph's last 200 ms.
14. **Web cost:** at most **3 always-on bus effects** (limiter, Music compressor, SFX compressor), plus the snapshot low-pass only while a snapshot is active and the Glitch LOFI only during Copy-Paste. No runtime reverb or chorus. At most **6 new voice starts per frame** on web, and at most **30 simultaneous voices** (14 + 6 + 3 + 2 + dedicated). `tools/webtest.sh` passes, with the music peak check.
15. **Telegraph alignment:** every enemy and boss wind-up cue ends within **one physics tick (≤ 17 ms)** of the attack's release, for every move in §4.7.1 at both phase multipliers. Exactly **one** wind-up cue plays per boss move.
16. **Over-firing:** a thorn dash, a Loop chase, a Select All fill and a Collector compact each start **≤ 1** one-shot (or one loop) of their family. No still hazard ever plays `eshot`.

---

## 8. Objections (per `contracts/objection.md`)

### 8.1 Raised against the current runtime, both now **resolved by agreement** with the audit
The first objection is resolved by the cue table + voice manager (DEV-A1, DEV-A2). The second is resolved by baking the effects and re-routing Critical (DEV-A3, plus §6.1). They are kept here for the record.

```yaml
objection:
  skill_or_agent: audio-director (mix-and-mastering)
  against_artifact: mix-bus-topology (as implemented in game/scripts/autoload/audio.gd + ~60 call sites)
  reason: |
    The loudness hierarchy is not stated anywhere. Every SFX file is normalised to the same
    -18 LUFS, and the hierarchy is rebuilt by volume_db arguments scattered over call sites.
    As a result a telegraph (-3 dB) plays under a crit or a kill (0 dB), which inverts
    pillar 2. Voices have no per-cue caps, and the oldest voice is stolen first (the audit's
    B9/B10), so a storm cuts kill_big and boom tails.
  proposed_alternative: |
    Bake the families into the files (§4.1). One CUES table in audio.gd (class, prio, group,
    cap, gap, gain_db, jitter_cents, pan, walk) feeds the audit's queued voice manager. Call
    sites pass context only.
  status: RESOLVED (DEV-A1, DEV-A2)
```

```yaml
objection:
  skill_or_agent: audio-director (mix-and-mastering)
  against_artifact: mix-bus-topology (Critical routed into SFX; SFX room reverb; Music chorus + reverb)
  reason: |
    SFX cannot be sidechain-ducked under Critical while Critical sends into SFX. The SFX
    reverb smears Critical cues. Runtime reverbs and the chorus are the heaviest main-thread
    DSP on the web build (ADR 0009).
  proposed_alternative: |
    Route Critical to Master, add a Critical-keyed compressor on SFX, bake every reverb and
    chorus into the files, and move stingers to their own Sting bus (§6.1).
  status: RESOLVED (DEV-A3; the SFX compressor stays open for the Developer's review)
```

### 8.2 Raised against Developer proposals in the audit (for wave-2 reconciliation)

```yaml
objection:
  skill_or_agent: audio-director (sound-design + sonic-identity-and-direction)
  against_artifact: runtime audit §3.6 "Pitch-walk for streaks" (DEV-A33)
  reason: |
    The audit walks kills +1 *semitone* per kill (up to +5) and rapid hits on one target
    +0.5 semitone each (up to +3). Chromatic and quarter-tone steps are out of key against
    every music bed, so a kill streak over the Cellar (A minor) runs A, B-flat, B, C, C#:
    three of those are outside A minor pentatonic and two clash with the bed's harmony.
    That breaks pillar 4 ("one key per room") and the Peggle-2 precedent this feature comes
    from (the steps follow the harmony). The quarter-tone hit walk also detunes the densest
    cue continuously, which reads as a pitch fault rather than momentum, and it fights the
    no-jitter-over-25-cents rule on tonal cues.
  proposed_alternative: |
    Keep the audit's windows (0.6 s chain, 0.8 s reset) and its mechanism. Step on the
    minor pentatonic of the current area key: [0, 3, 5, 7, 10, 12] semitones, plus the
    area key_offset (Cellar 0, Grove +4, Foundry -4, title/shop +5). Cap kill chains at
    step 5 (+12 st). Apply the same rule to coin/crate gold and gulp. Do not walk hits: the
    per-frame coalescing (+10·log10(n) dB) already makes a hit storm read as *more*. Cost is
    identical (one table lookup).
```

```yaml
objection:
  skill_or_agent: audio-director (sound-design)
  against_artifact: runtime audit §1 "Shooter telegraph — WRONG identity" + §4 "the cue picked per enemy family" (DEV-A15)
  reason: |
    The audit wants per-enemy telegraph identity ("you can't tell a weaver from a ram
    offscreen"). Ten enemies × distinct wind-up sounds would dissolve the one reserved
    threat channel. The brief pairs it with the reserved `threat` red (ADR 0012): one sound
    that always means "an attack releases *now*". Its value comes from being invariant and
    learnable in one death. Ten timbres spread across R1 would also mask each other in a
    mixed wave. The telegraphs cap at 3 voices, so identity would be stolen exactly when
    several enemies wind up at once.
  proposed_alternative: |
    Identity by attack CLASS, not by enemy. Three masters share the warble, the rising
    contour and the invariant end pitch: `tele` (shooters: a high register, a shot tick),
    `tele_charge` (a low register, a stamp AM, a stomp release) and `tele_slam` (an opening
    interval, a thud release). Bosses use one signature telegraph per identity-critical move
    (§4.7.1). Pan (DEV-A5) supplies *where*. The player learns three shapes, and each tells
    them how to dodge (sidestep a line, leave a lane, leave a circle), which is what identity
    is for.
```

No objection to the goal itself: redesigning everything while keeping generation in code, deterministic and loudness-normalised is sound and achievable in the stated budget. **Beat-quantised `AudioStreamInteractive` transitions are unavailable with WAV** (no bpm), so quantisation stays clock-driven. The folded boss intro (DEV-A4) removes the one clock blind spot.

---

## 9. Hooks for the Game Developer (consolidated with the audit's call-site table §4)
The ids follow the audit wherever it named one. Line numbers are the audit's (working tree, including the uncommitted WIP).

| Pri | Cue / param | File:line (audit) |
|---|---|---|
| **P1** | `cast(id, at, weight)` + **`slot`** param | `spell_runner.gd:169` |
| | `hit(name, at, crit, heavy)` → element hit + `crit`/`hit_heavy` sweeteners | `world.gd:1415` |
| | `hit_for_bullet(...)` (coats) | `spell_runner.gd:990` |
| | `kill(kind, at, size, how)` → `kill*`, `kill_burn`/`kill_shatter`/`kill_spark` | `world.gd:1660` |
| | `enemy_shot(sound, by, at)` → `thorns` / `trail_loop` / `box_fill` / `trash` / silent | `world.gd:965` |
| | `tele(total, at, who)` → `tele` / `tele_charge` / `tele_slam` | `enemy.gd:608` |
| | `tele(st_t, at, move)` → `tele_boss` / signature telegraphs | `boss.gd:138`; drop the duplicates at `boss_loop.gd:223`, `boss_collector.gd:62`, `boss_deadlock.gd:190`; `copy_cast` and `select_all` move out of `_start` (`boss_copy_paste.gd:130, 146`) into `tele()` |
| | `loop(&"beam")` | `boss_deadlock.gd:203-207`, `232-235`, `168-169` |
| | `mana_empty` (edge-triggered) | `spell_runner.gd:114-115` |
| | `freeze` | `world.gd:1476` |
| | `shield_break` | `world.gd:1531` |
| | `locked` | `world.gd:1350` |
| | `panic` | `enemy.gd:477` |
| | `blink_charge` / `blink_land` | `enemy.gd:508-513` / `503` |
| | `key_turn` | `boss_deadlock.gd:138` |
| | `die` | `player.gd:320` |
| | `player_hp(frac)` → `low_hp` | `world.gd:821` |
| | `snapshot(...)` | `world.gd:768`, `main.gd:339-342` |
| | `on_hitstop(t)` | `world.gd:1216` |
| | `stop_world()` | `world.gd:386` |
| | `p3` layer | `world.gd:374-383` |
| | `mini` track | `room_music()` |
| | `sting_boss_down` | `world.gd:646` |
| | `door` | `world.gd:691` |
| **P2** | `trigger` + **`depth`** param | `spell_runner.gd:1153` |
| | `thermal` | `world.gd:1494` |
| | `crash` | `world.gd:1567` |
| | `split` | `world.gd:1693-1705` |
| | `caught` | `player.gd:289` |
| | `shield_soak` | `player.gd:297` |
| | `graze` | `player.gd:283` |
| | `swap` | `player.gd:134` |
| | `fizzle` | `spell_runner.gd:153` |
| | `cast_delayed` | `spell_runner.gd:874-891` |
| | `familiar_shot` | `spell_runner.gd:666` |
| | `familiar_end` | `spell_runner.gd:594` |
| | `duck_soak` | `spell_runner.gd:566` |
| | `glitch_toll` | `world.gd:742` |
| | `sting_world` | `world.gd:762` |
| | `heal` / `heal_small` / `heart` | `world.gd:644`, `656`, `681`, `1630` |
| | `gulp` / `choked` | `boss_collector.gd:81`, `83` |
| | `segment_break` / `loop_jr` / `back_on_track` | `boss_loop.gd:187`, `199`, `144` |
| | `paste` | `boss_copy_paste.gd:179` |
| | Copied spells on the Glitch bus | `boss_copy_paste.gd:221` |
| | `ui_drag` | `editor_screen.gd:472` |
| | `ui_pick` | `editor_screen.gd:527` |
| | `deny` (bag full) | `editor_screen.gd:493` |
| | Swap-aware equip | `editor_screen.gd:495` |
| | Press-sound override | `screen.gd:129-130` |
| | `ui_confirm` | Screen handlers |
| | `wand_recharge` | Recharge start (spell_runner) |
| | `elite_arrive` | Encounter director |
| | `weak_open` | `boss_copy_paste.gd:214` (the lag); the Deadlock break |
| | `altar` | Reward screen, altar gift |
| | `pylon` count param | `world.gd:1192` |
| **P3** | `tip` | `hud.gd:112` |
| | `duck_say` / `glitch_say` | `hud.gd:108`, **WIP; coordinate with its owner and do not touch now** |
| | `step_stone` / `step_moss` / `step_metal` | Walk-cycle foot frames |
| | `hit_proxy` | `world.gd:1355-1358` |
| | `relic_proc` | `spell_runner.gd:86-88, 119-121` |
| | `door_shut` | Combat start |
| | `compile` | `shop_screen.gd:152-155` for evolutions |
| | `unlock` | End-screen goals |

**Table-only (no gameplay hook):**
- `cast_needle`, `cast_carry`, `cast_mine`, `cast_wall`, `cast_rot`, `cast_ping`, `cast_summon`, `hit_rot`;
- remapping `spark` → `cast_chain`;
- evolved-spell pitch/gain offsets;
- keyed stingers;
- ambience spots.

**Retired:** `win`, `lose`, `tele_short`, `tele_mid`, `tele_long` (aliases), `music_boss_intro` (folded). Update `test_feel.gd`'s required-names list.

---

## 10. Reconciliation ledger: the runtime audit's proposals

| # | Audit proposal | Verdict | Where |
|---|---|---|---|
| DEV-A1 | 3.1 queued voice manager, per-frame budget (6 web / 8 native), coalescing, steal order, `hurt` reserve | **ACCEPT, amended**: coalescing capped at +3 dB (not +4) so chatter cannot pass the Event family | §4.1, §6.2 |
| DEV-A2 | 3.2 own variant picker instead of `AudioStreamRandomizer` | **ACCEPT** | §4.1 |
| DEV-A3 | Bake the music's chorus and reverb into the stems (the largest web saving); keep or bake the SFX room | **ACCEPT**: both baked; stems stay mono and lose runtime width | §3.10, §3.11, §5.9, §6.1 |
| DEV-A4 | Fold the boss intro into the loop file with `loop_begin`; silent-headed p2 | **ACCEPT**: also for `mini`; `audio.sh` writes `loop_begin` | §5.2, §5.8, §5.11 |
| DEV-A5 | 3.3 `AudioStreamPlayer2D` pan: 0.6, `max_distance` 900, attenuation 0.6, `area_mask` 0 | **ACCEPT** (replaces my "no attenuation") | §6.2, §6.4 |
| DEV-A6 | The element hit comes from the bullet's coat | **ACCEPT**, plus a precedence rule (rot > static > chill > burn) | §4.2 |
| DEV-A7 | `cast(id, at, weight)` | **ACCEPT, amended**: 2 distinct timbres, weight gain, a "heavy" variant for Heavy/Empower | §4.2 |
| DEV-A8 | The crit is a sweetener on the element hit | **ACCEPT**: the crit recipe loses its body | §4.3 |
| DEV-A9 | Weight by target size (heavy) | **ACCEPT** as `hit_heavy` | §4.3 |
| DEV-A10 | Its own `shield_break` | **ACCEPT** | §4.3 |
| DEV-A11 | `locked` for Deadlock | **ACCEPT** | §4.3 |
| DEV-A12 | 3.9 heartbeat one-shots under 30% HP + low-pass about 3 kHz + an off switch | **ACCEPT** (replaces my 25% loop); the setting is the UX Designer's | §4.5, §5.2 |
| DEV-A13 | `die` | **ACCEPT** | §4.5 |
| DEV-A14 | `graze` | **ACCEPT** | §4.5 |
| DEV-A15 | 3.8 length-matched `tele()` + per-enemy identity | **ACCEPT** length matching (implemented as offset play of a 1.5 s master, so the end pitch is invariant). **OBJECT** to per-enemy identity; counter: per-attack-class identity | §4.6, §8.2 |
| DEV-A16 | `enemy_shot` prefix mapping for still hazards (point f) | **ACCEPT**, with the cues `thorns`, `trail_loop`, `box_fill`, `trash` | §4.6 |
| DEV-A17 | Static arc is OK as `hit_static` | **ACCEPT** (my `static_arc` dropped) | §4.6 |
| DEV-A18 | Boss telegraphs end on release; the move cue *is* the telegraph (point e) | **ACCEPT, amended**: the per-move table with signature telegraphs | §4.7.1 |
| DEV-A19 | 3.11 `loop()` for the Deadlock beam (point g) | **ACCEPT**: `beam` spec, with a phase-2 pitch | §4.7 |
| DEV-A20 | `key_turn` in place of `tele_mid` | **ACCEPT** (my `lock_swap` renamed) | §4.7 |
| DEV-A21 | The Collector's returned fan as `eshot` is OK | **ACCEPT** (my `gc_spit` dropped) | §4.7 |
| DEV-A22 | Copied spells sound like yours, glitched | **ACCEPT, amended**: a Glitch bus with LOFI distortion, no new files | §4.7, §6.1 |
| DEV-A23 | The missing heals (room clear, Leech Loop, heart) | **ACCEPT**: `heal_small`, `heart` | §4.9 |
| DEV-A24 | B13: overridable press sounds; no UI stacking | **ACCEPT** | §4.10 |
| DEV-A25 | 3.5 hysteretic intensity 0/1/2 | **ACCEPT** | §5.2 |
| DEV-A26 | Layers on the next downbeat, 50–80 ms fade | **ACCEPT** (replaces my next-beat drums) | §5.2 |
| DEV-A27 | `clear` on the next beat, others immediate; 2-voice sting pool | **ACCEPT** | §5.2 |
| DEV-A28 | The boss kill gets its own stinger | **ACCEPT**: `sting_boss_down` | §5.2, §5.10 |
| DEV-A29 | The area track keeps playing across same-biome rooms | **ACCEPT** | §5.2 |
| DEV-A30 | 3.4 snapshots (`menu` LPF 1.2 kHz −4 dB, Ambience −8 dB) | **ACCEPT**, the audit's values | §5.2, §6.4 |
| DEV-A31 | B1: Ambience muted with Music | **ACCEPT, amended**: a mute is required; I propose Ambience follows *Sound* and stingers get a Sting bus that follows *Music*. The setting's meaning is for the Developer and UX to settle | §6.1 |
| DEV-A32 | 3.7 hit-stop duck −5 dB, 80 ms release, no crit duck | **ACCEPT** | §6.3 |
| DEV-A33 | 3.6 pitch-walk: chromatic kills, +0.5 st hits | **OBJECT**: pentatonic in the area key; no hit walk | §6.4, §8.2 |
| — | 3.12 Doppler/HRTF: no; 3.13 measure the resampler first | **ACCEPT** (SFX stay 44.1 kHz until profiling says otherwise) | §5.9 |
