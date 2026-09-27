# Sound v2: runtime audit and runtime design (wave 1)

- Date: 2026-09-27
- Author: Game Developer (studio dispatch, wave 1: audit and design only, no code changed)
- Companion: `research/sound-v2.md` (Audio Director: sonic brief and cue spec, written in parallel). This file is the engine side: what fires where today, what the runtime does wrong, and the runtime the new cue spec will plug into.
- Engine: Godot 4.7.2, GDScript, Mobile renderer. The web build is single-threaded (`variant/thread_support=false`) with `audio/general/default_playback_type.web=0` (Stream), so **all mixing and every bus effect runs on the web main thread** (ADR 0009).
- **Line numbers are against the working tree, which includes someone's uncommitted WIP** (`events.gd` `signal say`, `hud.gd` say box, `world.gd` `_story_on_enter` and two `Story.say` calls, new `sim/story.gd`). In `world.gd` everything after line 491 sits up to 27 lines lower than in `HEAD`. None of that WIP is ours, and none of it was touched.

API facts checked by running Godot 4.7.2 (a probe project in the scratchpad, not in the repo):

| Fact | Result | Consequence |
|---|---|---|
| `AudioStreamWAV` has `bpm` / `beat_count` / `bar_beats` | **No** (only `loop_mode/begin/end`) | `AudioStreamInteractive` `TRANSITION_FROM_TIME_NEXT_BAR` cannot know our WAV tempo, so bar sync has to be done by us |
| `AudioStreamPlayer.get_playback_position()` on an `AudioStreamSynchronized` | Correct (1.152 s after 1.15 s) | The area tracks can use a **sample clock** for bar quantization |
| The same on an `AudioStreamInteractive` (the boss) | **Always 0.000** | The boss track's clock can't be read, which is why `layer()` guesses the bar from `Time.get_ticks_msec()` |
| The headless `Dummy` driver mixes | Yes: positions advance in `--headless` | Bar-clock and voice tests can run in `tools/test.sh` |
| `AudioStreamPlayer2D` `panning_strength`, `max_distance`, `attenuation`, `area_mask`, `max_polyphony` | Present | Per-voice stereo pan needs no extra buses |
| `AudioStreamPlaybackPolyphonic.play_stream(stream, from_offset, volume_db, pitch_scale, playback_type, bus)` | Present | Per-stream bus and pitch are possible, but there is **no pan**, so it is not a fit for world sounds |
| `AudioServer.get_time_since_last_mix()` and `get_output_latency()` | Present (latency reads 0.0 natively) | Use them in the bar clock |

---

## 1. Event coverage

Verdicts: **OK**, **MISSING** (no sound; an asset may already exist), **WRONG** (the sound, its timing or its routing does not match the event), **OVER** (fires too often or stacks). Ten shipped files are never played (orphans): `sfx_altar`, `sfx_door`, `sfx_freeze`, `sfx_lose`, `sfx_low_hp`, `sfx_mana_empty`, `sfx_swap`, `sfx_ui_drag`, `sfx_win`, and `sfx_cast_chain` (`HIT` maps `cast_chain`, but no `CAST` entry ever yields it).

### Player: casting and spells
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Wand cast (any slot, player) | `spell_runner.gd:169` | `cast(plan.groups[0].spell.id)`: one element timbre, -2 dB, ±8% pitch | **WRONG**: only the *first* group sounds. A multicast (Chorus, Twin, fans plus bolts) or a two-element wand plays one timbre. Boost modifiers (Empower, Heavy, Wide) change nothing audible. Fixed volume regardless of cast weight |
| Cast per wand slot highlight | `spell_runner.gd:171` (`Events.wand_cast`) | none | OK (the HUD flash only; a per-slot tick would be noise) |
| Pipeline or delayed casts (`_later`) | `spell_runner.gd:181` / `_run_later` 874 | none | MISSING (the delayed copy is silent, so Pipeline reads as nothing happening) |
| Stack Trace / Tail Call extra casts | `spell_runner.gd:157-167` | none (covered by the one cast sound) | OK |
| Race Condition fizzle | `spell_runner.gd:152-155` | none | MISSING (a paid cast that does nothing needs a dud) |
| Out of mana (tries to fire dry) | `spell_runner.gd:113-116` (`w.dry_at`) | none (`sfx_mana_empty` is an orphan) | MISSING. **Must be edge-triggered**: it re-fires every 0.06 s while auto-fire holds |
| Watchdog free cast / Loop Counter 10th cast | `spell_runner.gd:119-121`, `86-88` | none (ring FX only) | MISSING (low priority sweetener) |
| Trigger fires (then/callback/loop/fork/finally/sleep/ping) | `spell_runner.gd:1153` | `trigger` -4 dB, GAP 60 ms | OK in kind. **OVER** in a deep recursion wand (every carrier release chimes at up to 16/s); pitch should climb with `opt.depth` |
| Familiar placed (daemon/turret/duck) | `spell_runner.gd:519` | covered by `cast` (CAST has daemon/turret/duck) | OK |
| Familiar shot (daemon payload, turret bolt) | `spell_runner.gd:633-667` | none | MISSING (quiet, low priority) |
| Familiar expires | `spell_runner.gd:593-597` | none | MISSING (small pop) |
| Duck soaks a shot | `spell_runner.gd:566` | `hit` -6 dB | WRONG (a player-side decoy getting hit sounds like the player's bolt hitting an enemy) |
| Explosion (burst/bomb/mine/blast) | `spell_runner.gd:429`, `738` | `boom` -3 / -5 dB, **no GAP entry** (default 20 ms) | **OVER**: a mine field or chained Blast can start `boom` (0.42 s) up to 50 times a second and hog the 12-voice combat pool |

### Hits, crits and statuses
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Projectile hit, per element | `spell_runner.gd:990` sets `world.hit_sound`; plays at `world.gd:1415` | `hit_fire/ice/static/arcane/void` or `hit`, -6 dB, GAP 30-40 ms per name | **WRONG** for coats: the element comes from the *spell id*, so a Mote with Ember Coat, Frost Coat or Static Coat hits as plain `hit`. It should come from the bullet (`b.burn`, `b.chill`, `b.static_on`, `b.rot`). Five element names each with its own GAP gives up to ~125 hit starts/s into the combat pool |
| Crit | `world.gd:1415` | `crit` 0 dB **instead of** the element hit; haptic | WRONG: a crit loses its element identity. The crit should be a sweetener layered on the element hit |
| Enemy hurt by size (heavy/boss vs fodder) | `world.gd:1415` | same `hit` for a Moss Blob and a Bark Golem | MISSING (no weight difference) |
| Armour chip / armour break | `world.gd:1377`, `1382` | `hit_armor` -4, `armor_break` (critical) | OK |
| Ward absorb / ward stripped | `world.gd:1519`, `1513` | `hit_ward`, `ward_break` (critical) | OK |
| Shield block / shield broken | `world.gd:1538`, `1531` | `hit_shield`, `armor_break` | WRONG (shield break reuses armour break; the counters exist to be learnt, so each needs its own break) |
| Deadlock "LOCKED" (no damage) | `world.gd:1346-1352` | none | MISSING (a dull clank tells you to switch target) |
| Proxy redirects the hit | `world.gd:1355-1358` | the proxy's hit only | OK (a tether zap would help, low priority) |
| Burn tick | `enemy.gd:272` | `burn` -8 dB, GAP 150 ms | OK (it would benefit most from pan) |
| Freeze (3 chills) | `world.gd:1473-1476` | none (`sfx_freeze` orphan) | MISSING |
| Thermal Shock | `world.gd:1494` | `boom` -6 dB | WRONG (the reaction is a named event; it shares the plain explosion) |
| Static arc to a neighbour | `world.gd:1418-1436` | the arced hit plays `hit_static` (GAP-limited) | OK |
| Bitrot CRASH (5 stacks) | `world.gd:1564-1571` | none | MISSING |
| Mark (Hex Cursor) | `world.gd:1576` | none | OK (silent is fine) |
| Cascade Failure crit arc | `world.gd:1437-1443` | none beyond the hit | OK |

### Enemies
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Wave spawn rune | `world.gd:574` | `spawn` once per wave | OK |
| Enemy lands (spawn_t ends) | `enemy.gd` tick | none | MISSING (low priority; the rune already warned) |
| Death: fodder / heavy / elite | `world.gd:1660` | `kill` / `kill_mid` / `kill_big` | OK in kind. WRONG in detail: the death visuals already vary by status (`world.gd:1644-1655`: ember flare, frost shatter, static spit) and the sound doesn't. No kill streak |
| Death: Moss Blob split / Mirrored copy / Forked ring | `world.gd:1693-1705` | Forked ring plays `eshot` (default `shot_sound`) | MISSING (split squelch); OK (forked) |
| Fell in a pit | `world.gd:1211` | `pit_fall` plus the kill sound | OK |
| Shooter telegraph (weaver, rot weaver) | `enemy.gd:604-608` (`_tele_cue`) | `tele_short/mid/long`, length-matched so it ends on release | OK timing; **WRONG identity**: every enemy shares three generic swells, so you can't tell a weaver from a ram offscreen |
| Shooter shot | `enemy.gd:687` sets `shot_sound`, plays at `world.gd:965` | `eshot` / `eshot_ring` (puffcap) / `eshot_laser` (sentry), -6 dB | OK |
| Sentry laser sight (0.8 s aim) | `enemy.gd:524-529` | `tele_mid/long` through `_tele_cue` | OK |
| Ram / bugling / spark plug charge wind-up | `enemy.gd:398-400`, cue via `_tele_cue` | `tele_*` during the wind-up, then `charge` **at release** | OK |
| Thorn trail during a charge (Bramble Ram, Spark Plug) | `enemy.gd:414-418` → `world.gd:965` | `eshot` every 70 ms while dashing (GAP 60 ms lets each through) | **OVER + WRONG**: a still thorn is not a shot; about 7 shot sounds per dash |
| Ram hits a wall | `enemy.gd:424` | `bonk` | OK |
| Golem slam (1 s ring telegraph, then the slam) | `enemy.gd:436-448` | `tele_long` then `slam` (critical) | OK |
| Stump summons buglings | `enemy.gd:461` | `summon` | OK |
| Tick fuse (0.8 s blink) | `enemy.gd:590-598` | `fuse` every 0.2 s, and `tele_mid` | OK |
| Tick bursts | `enemy.gd:485` | `fuse_pop` (critical) | OK |
| Kernel Panic (at half HP) | `enemy.gd:477` | `tele_mid` | WRONG (a panic is a state change, not a 0.5 s telegraph, and the actual burst comes 1.3 s later) |
| Blink Tick wind-up / arrival | `enemy.gd:508-513` / `503` | none / `tele_short` at **arrival** | WRONG (the telegraph cue plays after the blink, when nothing is left to warn about; the 0.45 s wind-up is silent) |
| Wisp wards allies | `enemy.gd:625` | `ward_up` | OK |
| Enemy shot blocked by Firewall / Duck / wall | `world.gd:930-938` | none (except the duck, above) | OK (silence is right; it would be spam) |

### Bosses
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Boss appears | `world.gd:622` | `sting("boss")` (the boss music started at room build, `world.gd:488`) | OK |
| Phase change (all bosses) | `boss.gd:77-78` | `phase` + `roar` (both critical, same frame) | OK |
| Every boss move's wind-up | `boss.gd:138` | generic `tele` (0.52 s) at the **start** of a 0.5-1.2 s wind-up | **WRONG**: the cue ends up to 0.68 s before the attack releases (Select All: 1.2 s wind-up), which breaks ADR 0019's rule that telegraphs end on release. It also doubles with the move's own cue where there is one (below) |
| Loop: lap charge / tail volley / while(true) / chase | `boss_loop.gd:223` (`chomp` on lap charge) + `boss.gd:138` | `tele` + `chomp`; the volleys through `eshot` | OVER (two cues at once for lap charge); volleys OK |
| Loop: chase trail | `boss_loop.gd:273` | `eshot` every 0.12 s for 3 s | **OVER + WRONG** (a burning trail is not a shot) |
| Loop: rings (while(true)) | `boss.gd:205` via `ring()` | `eshot` (plain; `shot_sound` is only set by `Enemy.shoot`) | WRONG (it should be the ring sound) |
| Loop: "THE LOOP CRACKS", segment broken, Loop Jr. | `boss_loop.gd:165`, `187`, `199` | none (the phase sound covers the crack) | MISSING (segment break, Jr. spawn) |
| Loop: pylon pulse count / DERAILED / BACK ON TRACK | `boss_loop.gd:206`, `210`, `144` | `pylon` (world) / `derail` / none | OK / OK / MISSING |
| Copy-Paste: CASTING YOUR SPELLS | `boss_copy_paste.gd:130` | `copy_cast` (+ `tele`) | OK. The copied spells themselves (`cast_copy` 221) come out as `eshot`: WRONG, they should sound like *your* spell, glitched |
| Copy-Paste: undo (CTRL+Z), dup row, paste (CTRL+V), select all | `:165`, `:170-177`, `:178-182`, `:146` + `:185-190` | `ctrl_z` / `eshot` / none / `select_all`, then box fill → `eshot` | OK / OK / MISSING / fill WRONG (dozens of still shots → one `eshot`) |
| Copy-Paste: split (ghost) | `boss_copy_paste.gd:122` | the phase sound | OK |
| Deadlock: UNLOCKED swap | `boss_deadlock.gd:138` | `tele_mid` | WRONG (a telegraph swell with no attack after it; the swap is a *good* event, a key turning) |
| Deadlock: sweep beam (wind-up, live beam, phase 3 permanent beam) | `:186-190`, `:203-207`, `:168-169` | `chomp` at wind-up; the live beam is silent | MISSING: a looping beam hum is the one continuous threat in the game |
| Deadlock: crossfire, volley, beam hurts | `:207-211`, `:223-227`, `:162` | `eshot`; hurt | OK |
| Deadlock: LOCKS BROKEN | `:182` | the phase sound | OK |
| Collector: COLLECTING / eating shots / CHOKED | `boss_collector.gd:62`, `80-83` | `tele_mid` (+ `tele`) / none / none | OVER (double cue) / MISSING (a gulp per eaten shot, rate-limited) / MISSING |
| Collector: compact charge trash | `boss_collector.gd:86-89` | `eshot` at up to ~16/s for 0.6 s (random 35% per tick) | **OVER + WRONG** |
| Collector: dump (3 slimes + ring), returned fan | `:94-98`, `:105-112` | `eshot` | OK |
| Boss defeated | `world.gd:1679` → `audio.gd:101` | `bigboom` (critical), and in the same tick `_clear_room` → `sting("clear")` | WRONG: the boss kill gets the everyday room-clear stinger; the victory is undersold |

### Player state
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Hurt | `player.gd:316-317` → `audio.gd:99` | `hurt` (critical, ducks music) | OK |
| Death | `player.gd:318-321`, `world.gd:766-768` | the lethal `hurt`, then `death_sweep()` on the music | MISSING (no death sound; `sfx_lose` orphan). See the defeat-pop bug in §2 |
| Dash | `player.gd:156` | `dash` | OK |
| Dash through a shot (i-frames) | `player.gd:283` | none | MISSING (a "graze" rewards the skill; it needs a rate limit) |
| Try/Catch CAUGHT | `player.gd:286-291` | none | MISSING |
| Buffer Overflow shield soaks | `player.gd:295-301` | none | MISSING |
| Low HP (< 30%, the HUD glow) | `hud.gd:171-184` | none (`sfx_low_hp` orphan) | MISSING |
| Heal: spring | `world.gd:879` | `heal` | OK |
| Heal: room clear +6, boss full heal, Leech Loop, MAX HP +15 room | `world.gd:644`, `656`, `1627-1630`, `679-682` | none | MISSING (the heart reward and Leech Loop at least) |
| Memory Leak -1 | `world.gd:1602-1605` | none | OK (silent is kinder) |
| Wand swap (HUD button, keys) | `main.gd:451`, `player.gd:132-135` | none (`sfx_swap` orphan) | MISSING |
| Wand auto-switch (empty wand) | `player.gd:137-141` | none | MISSING (low priority) |
| Spikes rising | `world.gd:1234` | none | MISSING (a hazard telegraph; low priority) |

### Rooms, rewards, economy
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Room enter / music / ambience | `world.gd:488-489` | `music(...)`, `ambience(...)` | OK (see the ambience bug) |
| Room clear | `world.gd:646` → `audio.gd:100` | `sting("clear")` | OK. Unquantized (see §3) |
| Doors open | `world.gd:688-697` | none (`sfx_door` orphan) | MISSING |
| Go through a door / Glitch Door toll | `world.gd:725`, `742` | none / none | OK (the music change covers it) / MISSING (losing max HP silently) |
| Next world | `world.gd:752-763` | the music only | MISSING (a world transition stinger) |
| Gold room reward | `world.gd:676` | `coin` | OK |
| Gold per kill | `world.gd:1623` | none | OK (every kill already makes a sound) |
| Crate breaks (+1-3 gold) | `world.gd:1094` | `crate` | OK. With a mine field, several crates break in one tick and the GAP swallows all but one: fine |
| Pod pop / bramble burn / pylon / secret | `world.gd:1147`, `1164`, `1192`, `1178-1179` | each has a sound | OK (`crack_open` + `secret` stack in the same frame: fine, intended) |
| Reward orb touched | `world.gd:860` | `sting("reward")` | OK. It cuts `sting("clear")` if you reach the orb within 1.8 s: the single `_sting` player |
| Secret chest | `world.gd:867-868` | `chest` + `sting("reward")` | OK |
| Altar gift (15% max HP each) | reward screen, `rewards.gd:162` | only the generic pick | MISSING (`sfx_altar` orphan) |
| Shop: select / buy / reroll / ban | `shop_screen.gd:115`, `152`, `122`, `139` | `ui`, `buy`, `coin`, `deny` | **OVER**: `Screen.press` (`screen.gd:130`) already played `ui` for "buy" and "reroll" |
| Forge / Compile | `shop_screen.gd:152-155` | `forge` + `levelup` | OK |
| Reward: take / merge / skip for gold / locked | `reward_screen.gd:233`, `236`, `222` | `pick` / `levelup` / `coin` / `deny` | **OVER**: "skip" plays `ui_back` (press) + `coin` + `ui_close` in the same frame; "take" plays `ui` + `pick` + `ui_close` |

### UI, editor, meta
| Event | Where | Audio today | Verdict |
|---|---|---|---|
| Any button | `screen.gd:129-130` | `ui` / `ui_back` | OK as a default, but it is not overridable, so it stacks (above) |
| Screen opens / closes | `main.gd:340`, `342` | `ui_open` / `ui_close` | **OVER** with `ui_back` on every close button |
| Pause | `main.gd:413-424` | `ui_open` only; music, ambience and tails play on unchanged | MISSING (no pause snapshot) |
| Editor: pick up (drag starts) | `editor_screen.gd:471-473` | none (`sfx_ui_drag` orphan) | MISSING |
| Editor: tap-select a slot | `editor_screen.gd:519-529` | none (`slot:` ids are excluded from the press sound) | MISSING |
| Editor: drop into a wand / into the bag | `editor_screen.gd:500`, `504` | `ui_equip` + haptic / `ui_drop` | OK. It ignores `place_spell`'s result ("place" / "insert" / **"swap"**): a swap should sound like one |
| Editor: drop cancelled / bag full | `editor_screen.gd:480-481` / `493` | none / none | MISSING (`deny` for bag full) |
| Editor: revert | `editor_screen.gd:510-513` | the generic `ui` | OK |
| Firing range (wand lab) | `wand_lab.gd:67-149` | silent by design (`Game.quiet`) | OK |
| Codex / goals | `codex_screen.gd:127`, `131` | `ui` | OK |
| First-run tip appears | `hints.gd:44` → shown at `hud.gd:111-113` | none | MISSING (a soft tick when the tip *shows*, not when it is queued) |
| Story: the Duck says a line (WIP) | `story.gd:161` → shown at `hud.gd:107-109` (WIP) | none | MISSING (a short duck blip when the box *pops*; this is WIP code, wave 2 must coordinate) |
| Victory / defeat screens | `main.gd:403-404` | `music("")` + `sting(...)` | OK. Ambience keeps playing (bug) |
| Title | `main.gd:100` | `music("title")` | OK. The last area's ambience keeps playing under it (bug) |

**Count:** 34 events are silent and should not be, 14 play a wrong sound or at a wrong time, and 9 over-fire or stack.

---

## 2. Runtime audit of `audio.gd`

### Bugs (each confirmed by reading the code; the test column says how to prove it)

| # | Bug | Where | Effect | Proof in a test |
|---|---|---|---|---|
| B1 | **The Ambience bus is never muted.** `apply()` mutes SFX, UI and Music only; `ambience()` checks `music_on` once, at fade-in | `audio.gd:158-165`, `350` | Music off still leaves the cellar/grove/foundry bed playing. Music back on mid-room leaves it at -80 until the next area | `apply({"music": false})` then read `AudioServer.is_bus_mute(Ambience)` |
| B2 | **Ambience never stops.** Only `world.gd:489` calls `ambience()`; the title, the end screens and the shop keep the last area's bed | `main.gd:100`, `403` | The grove bed under the title music after a run | after `music("title")`, `_amb.playing` should be false |
| B3 | **Stingers are silent when sound is off and music is on.** `sting()` checks `music_on` but plays on Critical, which sends into the muted SFX bus. Critical still keys the Music compressor, so the music ducks under a stinger nobody hears | `audio.gd:244-251`, `109`, `119-125` | With "sound off, music on", no clear/boss/victory stinger, and an unexplained dip in the music | bus routing assertion |
| B4 | **The death sweep pops at defeat.** `_open_end` → `music("")` → `_clear_sweep()` disables the low-pass *before* the 0.8 s fade-out, so the muffled music jumps back to full brightness while it fades, under the defeat stinger | `audio.gd:353-354`, `main.gd:403` | An audible brightening just as the defeat screen opens | the low-pass is still enabled when `music("")` starts |
| B5 | **`music("")` in the middle of a crossfade leaves a player stuck on.** When A is fading out (still > -40 dB) and B fading in, `incoming = B`; with no stream only `outgoing` (A) is faded, the old tween is killed, and B keeps playing at its mid-fade level | `audio.gd:376-387` | Rare (a door plus victory or death within 0.8 s of a room change), but the music never stops | two `music()` calls 0.3 s apart, then `music("")`: neither player may be playing after the fade |
| B6 | **Stale layer tweens survive a track change.** `music()` clears `_layers` and `_layer_on` but not `_layer_tw`; a bar-delayed boss `p2` tween still fires on the cached boss stream | `audio.gd:360-361`, `409-419` | The boss stream can be left with p2 on when it is next reused | re-enter "boss" after a pending `layer("p2", true)` |
| B7 | **The boss bar clock is wall-clock time, not the music.** `layer()` computes the next bar from `Time.get_ticks_msec() - _track_t0`. That drifts by the output latency, and is simply wrong after any audio suspend (an iOS interruption, a tab in the background, the ambient session): the ticks keep running while playback stops. The probe shows `get_playback_position()` is **0 for `AudioStreamInteractive`**, which is why wall time was used | `audio.gd:401-405` | Phase 2 lands off the beat after a phone call or a tab switch | Dummy-driver test (below) |
| B8 | **The area tracks have no bar quantization at all.** `TRACKS` has no `bpm` for cellar (120), grove (120) or foundry (112, 32 bars = 68.571 s), so drums and lead fade in on arbitrary beats over 0.6 s | `audio.gd:46-48`, `402` | The drums enter mid-bar at every room start | a layer change time mod the bar length |
| B9 | **Voice stealing ignores importance.** The combat pool (12) steals the *oldest* voice. `kill_big` (0.62 s), `boom`, `chest`, `heal`, `secret` and `levelup` are all combat class and get cut 30-80 ms after they start by the next `hit` in a storm. The critical pool (4) is shared by `hurt`, four telegraph cues, `slam`, `fuse_pop`, `ward_break`, `armor_break`, `phase`, `roar` and `bigboom`: five enemies winding up at once steals `hurt` | `audio.gd:21-24`, `216-224` | Elite kills and explosions lose their tails exactly when they matter; the player's own hurt can be cut by a telegraph | fill the pool, then `sfx("kill_big")`; the next `hit` must not steal it |
| B10 | **`boom` has no GAP entry** (default 20 ms), and neither do `kill_mid`, `kill_big`, `spawn` or `ward_up` | `audio.gd:27-30` | 50 booms/s possible in a mine or bomb chain | count starts in one tick |
| B11 | **The stinger player is single.** A new `sting()` cuts the previous one, with no priority: `reward` (orb touched early) cuts `clear`; the boss `clear` fires in the same tick as `bigboom` | `audio.gd:96-98`, `244-251` | Clipped stingers | |
| B12 | **`world.shot_sound` and `world.hit_sound` are global mutables** used to pass a parameter through `enemy_shoot()` and `hurt_enemy()`. Anything that shoots outside `Enemy.shoot` (boss rings, thorn and loop trails, select-all boxes, trash, forked deaths, the panic ring) gets the default `eshot` | `world.gd:214-215`, `965`, `enemy.gd:687`, `spell_runner.gd:990-992` | The over-firing rows in §1 | |
| B13 | **UI sounds stack.** `Screen.press()` plays a sound before the handler runs, and the handler plays its own; `_open`'s finished callback adds `ui_close` | `screen.gd:129-130`, `main.gd:340-342` | 2-3 sounds on one tap (take, skip, buy, reroll, close) | |
| B14 | **`_last[name]` is set before the stream or tree check**, so a sound that failed to play still blocks the next one for its GAP | `audio.gd:201-206` | Minor | |
| B15 | **No death sound, and `death_sweep()` is not `quiet`-gated** (`Events.player_died` is not gated either) | `player.gd:318-321`, `world.gd:768` | Minor | |

### Performance on the web (single-threaded, Stream playback, main-thread mixing)

- **Bus effects, always on:** Master `HardLimiter`; Music `Compressor` (sidechain), `Chorus` (2 voices) and `Reverb`; SFX `Reverb`. That is 5 effects, plus the death low-pass once added. **The two Freeverb reverbs and the chorus are the heaviest DSP in the game, and all three run on the web main thread**: the Music one runs every frame the music plays, which is always. Godot only processes a bus's effects while that bus carries signal, so the SFX reverb costs something only in combat, but the music chain never rests.
  - **Recommendation:** render the music's chorus and reverb into the stems offline (`tools/gen_music.gd` is deterministic, so it costs nothing at runtime). Keep the Music bus to the sidechain compressor plus one shared, normally-bypassed low-pass (used by the snapshots in §3). Keep one short SFX room reverb, or bake that too. This is a pipeline change for the Audio Director and Technical Artist, and it is the **largest single web saving**.
- **Voices in flight:** critical 4 + combat 12 + ui 3 + sting 1 + ambience 1 + music (a synchronized track is 3 decoders; a crossfade is 6; the boss adds the intro) comes to about 22 in a normal fight and 28 during a room change. Every file is QOA-decoded and resampled per voice (SFX at 44.1 kHz, music at 32 kHz, to the browser's 48 kHz on iPhone). A layer "off" at -60 dB is still decoded and mixed. Numbers here are estimates; they have not been profiled on a phone.
- **Allocation in the hot path:** `sfx()` builds a `"sfx_" + name` string and does two linear `in` scans over string arrays (`voice_class`) for every sound that passes its GAP. That's small, but it's per sound, and a storm passes over 100 a second. Precompute a `StringName → cue` dictionary once.
- **The GAP limiter** is per name and wall-clock (`Time.get_ticks_msec`). That's right in spirit (it collapses physics catch-up ticks on a slow frame), but it is the *only* budget: there is no global cap on starts per frame, so five hit names, crits, kills, casts, triggers and enemy shots can together start about 150 voices a second into a 12-voice pool. Each voice then lives about 80 ms, so tails are cut and the pool churns.
- `_process` publishes the Music bus peak to the page twice a second (`JavaScriptBridge.eval`): negligible, keep it.

### Voice stealing under a full bullet storm (the `test_world` stress roster, about 1,300 bullets)

The combat pool gets requests from casts (`cast_spark` capped at 22/s), five element hits (up to 25/s each), `crit` (20/s), `kill` (25/s), `eshot` (16/s), `trigger` (16/s), `boom` (50/s), `burn` (7/s), `fuse`, crates and pods. Oldest-first stealing means the longest sounds (`boom` 0.42 s, `kill_big` 0.62 s) are always the ones taken, because they are always the oldest. The combat class ends up sounding like a wall of 80 ms transients. Godot fades a stopped playback over one mix buffer, so this cuts rather than clicks, but the meaning of the big events is lost. **This is the main craft defect of the runtime.** §3.1 fixes it.

### Settings and mute
- `Game.apply_settings` → `Audio.apply()` mutes SFX and UI (sound) and Music (music). Ambience is not covered (B1); stingers route wrong (B3). There are no volume sliders, only on/off; the Critical sidechain keys even while muted (B3).
- `Game.quiet > 0` (the firing range) correctly silences `sfx`, `sting` and `ambience`, but not `music()` or `layer()`. Those are only called from `build_room` behind a `quiet` check, so this holds in practice.

### Pause, screens and scene changes
- Every menu (pause, editor, map, reward, shop) sets `world.paused` and plays `ui_open`. The music keeps its combat layers (drums and lead stay on, since `_music_layers()` isn't called while paused) at full level, the ambience keeps playing, and nothing ducks. There is no pause or menu snapshot.
- `Audio` is `PROCESS_MODE_ALWAYS` and its players are its children, so nothing ever pauses. That is correct for menus, but it means a snapshot has to be explicit.
- Room change: `build_room` crossfades the music. Long world sounds already playing (`boom`, `phase` tails, the future beam loop) aren't stopped; that's harmless today, and it matters once loops exist.
- Hit-stop (`world.gd:1216`) freezes the simulation for 33-300 ms while audio runs on. That is the right choice (Vlambeer's "sleep"), and there's room for a short duck (§3).

### Music: crossfade, layers, bar quantization
- **Crossfade:** two players, a dB-linear tween from -40 to -4 over 0.8 s, and the outgoing player to -80 and then `stop`. Sound apart from B5. The new track always starts at sample 0. A room change within one biome starts the cellar again from bar 1, which is audible repetition in a 10-room run. Proposal: keep the area track playing across rooms of the same biome (`music()` already returns early when the track is unchanged; the track changes only because shop/forge rooms switch to "shop", which is fine).
- **Layers:** `AudioStreamSynchronized` keeps the stems sample-locked, so volume is the only thing that changes, and a layer never drifts. Good. Quantization is wrong on both counts (B7, B8).
- **The bar clock that works:** `pos = player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()`, then `wait = bar - fposmod(pos - intro, bar)`. That works for the area tracks today. For the boss it needs the **intro folded into the loop file** (one WAV whose `loop_begin` is at 4 bars, 7.5 s; the p2 stem gets 7.5 s of silence at the head and the same `loop_begin`). The track then becomes a plain `AudioStreamSynchronized` whose position reads correctly. The loop lengths (60 s and 15 s after the intro) still divide evenly. `tools/audio.sh` would have to write `edit/loop_begin` into the `.import` files as well as `loop_mode`. That is a pipeline change to agree with the Audio Director and Technical Artist.
- **The death sweep:** a low-pass added lazily at the end of the Music chain, swept from 16 kHz to 500 Hz over 1 s (exponential ease). Fine apart from B4. Fold it into the snapshot system.

---

## 3. Runtime features (Godot 4.7 APIs, cost, benefit, recommendation)

| # | Feature | How (4.7 API) | Web cost | Benefit | Do it? |
|---|---|---|---|---|---|
| 3.1 | **Priority voice manager, plus a per-tick budget and coalescing** | `sfx()` no longer plays at once: it queues `{cue, prio, vol, pos, pitch}`; one `flush()` per frame (`Audio._process`, or the end of `World.step`) merges same-name requests (keep the loudest, add `+10·log10(n)` dB capped at +4), sorts by priority, and starts at most **N = 6 new voices a frame** (8 native). Stealing: the lowest-priority voice first, then the quietest effective gain, then the least time left. The time left comes from `get_playback_position()` against the picked variant's `get_length()`, so we pick variants ourselves (below) | Lower than today: fewer starts, fewer decoders churning | Fixes B9/B10 and the §2 storm; `kill_big` and `boom` survive; telegraphs can't steal `hurt` (reserve 1 critical voice for `hurt`) | **Yes, first** |
| 3.2 | **Our own variant picker** in place of `AudioStreamRandomizer` | An array of `AudioStreamWAV` per cue, no-repeat pick, cue-spec pitch range in semitones and volume range | Nil | Known length (for 3.1), per-cue variance from the cue-spec, pitch-walk (3.6) | **Yes** (it comes with 3.1) |
| 3.3 | **Stereo pan by screen x, plus light distance attenuation** | World voices become `AudioStreamPlayer2D` children of the autoload. The world and the `Camera2D` live in the root viewport, and `main.gd` and `world` sit at the origin, so world coordinates are global and the camera is the listener. Settings: `panning_strength ≈ 0.6` (phone speakers are close together; full width is harsh on headphones), `max_distance ≈ 900`, `attenuation ≈ 0.6`, **`area_mask = 0`** (skips the per-frame physics point query for Area2D reverb overrides). Critical cues pan but don't attenuate. UI, music, stingers and ambience stay plain `AudioStreamPlayer`s | About the same mixing cost as now (non-2D players already mix stereo); a small per-frame pan update per playing voice | An offscreen telegraph says *where*; burn ticks and shots spread; storms stop sounding mono and muddy | **Yes** |
| 3.3b | The alternative: pan buses (SFX_L/C/R with `AudioEffectPanner`) | 3 buses, 3 quantized positions | More buses, and more complex routing to Critical and the sidechain | Worse (3 positions) | No |
| 3.3c | The alternative: `AudioStreamPolyphonic` | One player, `play_stream(..., bus)` | Least node overhead | No pan | Only for UI, if at all; No for the world |
| 3.4 | **Snapshots** | `snapshot(&"play" / &"menu" / &"dead" / &"low_hp" / &"boss_intro")` tweens a small fixed set: Music volume and its one shared `AudioEffectLowPassFilter` (enabled only while its cutoff < 18 kHz), Ambience volume, and SFX volume. Menu: Music low-pass about 1.2 kHz and -4 dB, Ambience -8 dB, SFX tails left alone. Dead: today's sweep. Low HP: Music low-pass about 3 kHz | One filter, enabled only in menus, death and low HP | Pause and editor sound like a pause; the death sweep becomes one case of the system; fixes B4 | **Yes** |
| 3.5 | **The bar/beat clock, quantized layers and stingers, and hysteretic intensity** | The clock from §2 (a sample position, not wall time). Add `bpm`, `beats_per_bar`, `intro_s` per track to `TRACKS`. Layers switch on the next downbeat (a 50-80 ms fade at the bar); `sting("clear")` waits for the next beat (≤ 0.5 s at 120 bpm). Hit-feedback stingers (`reward`, `boss`, `victory`, `defeat`) stay immediate. Intensity: `0` explore, `1` fighting (drums), `2` elite or ≥ 8 alive or boss (lead), with a 2 s hold before stepping down, so the layers don't flap as the last enemies die | Nil | The music follows the fight on the beat (Hades style) | **Yes.** The boss part depends on the loop_begin pipeline change |
| 3.6 | **Pitch-walk for streaks** | Kills within 0.6 s of each other raise `kill` by +1 semitone, up to +5, and reset after 0.8 s of quiet; the same for crate gold and coin rewards; rapid hits on one target +0.5 semitone each, up to +3 | Nil | Momentum you can hear; multi-kills read as combos | **Yes**, small |
| 3.7 | **Hit-stop and crit duck** | `on_hitstop(t)` from `world.gd:1216`: when t ≥ 0.08 (hurt, elite kill, boss phase or kill), duck the SFX bus -5 dB for t, with an 80 ms release, so the impact sample stands alone. Crits (0.045 s) get none; the crit sweetener does that job | One bus volume tween | The punch reads through a storm | **Yes**, small |
| 3.8 | **Length-matched telegraphs for bosses** (and one path for enemies) | `tele(total_s, pos, who)`: picks the longest cue ≤ total and starts it `total - cue_len` later with a one-shot timer, so it ends on release. It replaces `boss.gd:138`'s immediate `tele`, and the moves that add their own cue stop doubling | Nil | Restores ADR 0019's rule for bosses | **Yes** |
| 3.9 | **Low-HP heartbeat plus music filter** | `player_hp(frac)` each tick; under 0.3 (the HUD glow threshold, `hud.gd:173`) a `low_hp` beat on Critical every 0.9-1.2 s (faster as HP falls), plus the low-HP snapshot. It stops on heal or death. It needs an off switch (with the Flash or Shake settings, or its own) | One voice every ~1 s | Danger you can hear without looking at the HUD | **Yes**, with a setting |
| 3.10 | **Music intensity from danger** (beyond the enemy count) | Add the threat of live enemy shots near the player and the player's HP to the 0-2 intensity in 3.5 | Nil | Marginal over 3.5 | Later |
| 3.11 | Continuous loops (the Deadlock beam, the Collector's suction) | `loop(id, on, pos)`: a looped WAV on a dedicated 2D player, stopped on room change | 1 voice while active | The one continuous threat gets a sound | **Yes** for the beam |
| 3.12 | Doppler, reverb zones, HRTF | n/a | High | Low for a 480×270 top-down game | **No** |
| 3.13 | Output latency and mix rate | Keep `output_latency.web` at its default. Generate SFX at 48 kHz only if profiling shows the resampler matters | n/a | n/a | Measure first |

**Recommended wave-2 order:** 3.1+3.2 (the voice manager), then 3.3 (pan), 3.4 (snapshots, which fix B1-B5 on the way), 3.5 (the bar clock; the boss half after the pipeline change), 3.8, 3.11, 3.6, 3.7, 3.9. Separately, and in parallel, bake the music effects into the stems (the web saving).

---

## 4. Proposed public API for the rewritten `Audio` autoload

Existing names are kept, so call-site churn stays small. The tests read `Audio.CAST`, `Audio.TRACKS`, `Audio.UI`, `track_stream`, `stream`, `voice_class`, `hit_for`, `music`, `layer` and `layer_on`; all of them survive, extended where needed.

```gdscript
# settings and lifecycle
func apply(settings: Dictionary) -> void            # unchanged; now also mutes Ambience with music, and routes stingers by the music setting (B1, B3)

# one-shots (queued, flushed once a frame by priority; see 3.1)
func sfx(name: String, jitter := -1.0, volume_db := 0.0, at := Vector2.INF) -> void
    # unchanged for every existing call; jitter -1 = the cue-spec default; `at` = a world position, which pans it (3.3)
func cast(spell_id: StringName, at := Vector2.INF, weight := 1.0) -> void   # weight from the plan (group count, boosts)
static func hit_for(spell_id: StringName) -> String                         # kept (tests)
static func hit_for_bullet(spell_id: StringName, burn: int, chill: int, static_on: bool, rot: int) -> String   # the coat decides the element
func hit(name: String, at: Vector2, crit: bool, heavy: bool) -> void        # the element hit, plus the crit sweetener layered on top
func kill(e_kind: StringName, at: Vector2, size: int, how: StringName) -> void   # size 0/1/2 (fodder/heavy/elite); how = &"" | &"burn" | &"frost" | &"static"
func enemy_shot(sound: String, by: String, at: Vector2) -> void             # maps the `by` prefix: trail:/box:/trash:/thorns: → silent or a one-shot "settle"
func tele(total_s: float, at: Vector2, who := &"") -> void                  # length-matched, ends on release (3.8)
func loop(id: StringName, on: bool, at := Vector2.INF) -> void              # continuous threats (the Deadlock beam)
func stop_world() -> void                                                    # kills world tails and loops on a room change or back to the title

# state hooks
func snapshot(name: StringName) -> void                                      # &"play" | &"menu" | &"dead" | &"low_hp" (3.4)
func player_hp(frac: float) -> void                                          # heartbeat and the low-HP snapshot (3.9)
func intensity(level: int) -> void                                           # 0..2, hysteretic, bar-quantized (3.5)
func on_hitstop(t: float) -> void                                            # the SFX duck (3.7)
func mana_empty(w_id: int) -> void                                           # edge-triggered inside (one per dry spell)

# music (kept)
func music(track: String, fade := 0.8) -> void      # fixes B4/B5/B6; "" or "title" also fades out the ambience (B2)
func layer(name: String, on: bool, fade := 0.6) -> void   # now quantized to the next bar from the sample clock (B7/B8)
func layer_on(name: String) -> bool
func current_track() -> String
func ambience(area: String, fade := 1.2) -> void
func sting(name: String, quantize := false) -> void      # stingers get a small priority pool of 2 voices (B11)
func death_sweep() -> void                               # kept as a thin wrapper around snapshot(&"dead")
func bar_clock() -> Dictionary                           # {"pos": s, "bar": s, "beat": s, "to_next_bar": s}; for tests and quantizing
```

### Where each new or changed call goes (working-tree line numbers)

| Call | File:line | Replaces or adds |
|---|---|---|
| `cast(id, origin, weight)` | `spell_runner.gd:169` | replaces `cast(groups[0])`; weight = `plan.groups.size()` and boost count |
| `sfx("fizzle", ..., origin)` | `spell_runner.gd:153` | adds |
| `mana_empty(...)` | `spell_runner.gd:114-115` | adds (edge-trigger inside Audio) |
| `sfx("cast_delayed", ...)` on a `_later` release | `spell_runner.gd:874-891` (`_run_later`) | adds, quiet |
| `hit_for_bullet(...)` | `spell_runner.gd:990` | replaces `hit_for` |
| `sfx("trigger", ..., b.pos)` + depth pitch | `spell_runner.gd:1153` | changes |
| `sfx("familiar_shot", ..., p)` | `spell_runner.gd:666` (`_familiar_bolt`) | adds, quiet |
| `sfx("familiar_end", ..., s.pos)` | `spell_runner.gd:594` | adds |
| `sfx("duck_soak", ..., dk.pos)` | `spell_runner.gd:566` | replaces `hit` |
| `sfx("boom", ..., pos)` | `spell_runner.gd:429`, `738`; `world.gd:1494` → `"thermal"` | adds position; Thermal Shock gets its own cue |
| `hit(...)` | `world.gd:1415` | replaces the crit-or-element choice |
| `sfx("locked", ..., e.position)` | `world.gd:1350` | adds (inside the `_def_fx` rate limit) |
| `sfx("freeze", ..., pos)` | `world.gd:1476` | adds (orphan asset exists) |
| `sfx("crash", ..., pos)` | `world.gd:1567` | adds |
| `sfx("shield_break")` | `world.gd:1531` | replaces `armor_break` |
| `kill(e.kind, e.position, size, how)` | `world.gd:1660` | replaces |
| `enemy_shot(shot_sound, by, pos)` | `world.gd:965` | replaces `sfx(shot_sound)` and fixes the four still-shot over-firers without touching them |
| `sfx("door")` (once, when the doors actually open) | `world.gd:691` (`_open_doors`, guarded by `not doors_open`) | adds (orphan asset exists) |
| `sfx("glitch_toll")` | `world.gd:742` | adds |
| `sting("world")` | `world.gd:762` (`_next_world`) | adds |
| `sfx("heal")` / `sfx("heart")` | `world.gd:644` (quiet), `681`, `1630` (Leech Loop) | adds |
| `sting("boss_down")` instead of `clear` for a boss room | `world.gd:646` (or in Audio's `room_cleared` handler, keyed on `room_kind`) | changes |
| `intensity(level)` + `layer("p2")` | `world.gd:374-383` (`_music_layers`) | replaces the drums/lead booleans |
| `stop_world()` | `world.gd:386` (top of `build_room`) | adds |
| `player_hp(player.hp / run.max_hp)` | `world.gd:821` (right after `player.tick(dt)` at 820, only when `Game.quiet == 0`) | adds |
| `on_hitstop(t)` | `world.gd:1216` (`hitstop`) | adds |
| `snapshot(&"dead")` | `world.gd:768` | replaces `death_sweep()` |
| `sfx("graze", ..., position)` | `player.gd:283` (return path when `dash_inv > 0`), rate-limited 0.25 s | adds |
| `sfx("caught")`, `sfx("shield_soak")` | `player.gd:289`, `297` | adds |
| `sfx("die")` | `player.gd:320` | adds (orphan `sfx_lose` or new) |
| `sfx("swap")` | `player.gd:134` (only when `cur` changes) | adds (orphan asset exists) |
| enemy telegraph routing | `enemy.gd:608` → `tele(total, position, kind)`, and the cue picked per enemy family | changes (per-enemy identity from the cue-spec) |
| `sfx("blink_charge", ..., to)` | `enemy.gd:508-513` | adds; `enemy.gd:503` becomes `"blink_land"` |
| `sfx("panic")` | `enemy.gd:477` | replaces `tele_mid` |
| `tele(st_t, position, title)` | `boss.gd:138` | replaces the immediate `tele` |
| drop the duplicate cue | `boss_loop.gd:223`, `boss_collector.gd:62`, `boss_deadlock.gd:190` | the move cue *is* the telegraph, passed to `tele()` |
| `sfx("key_turn")` | `boss_deadlock.gd:138` | replaces `tele_mid` |
| `loop(&"beam", true/false, ...)` | `boss_deadlock.gd:203-207` (on), `232-235` (off), `168-169` (phase 3 on) | adds |
| `sfx("segment_break")`, `sfx("loop_jr")`, `sfx("back_on_track")` | `boss_loop.gd:187`, `199`, `144` | adds |
| `sfx("paste")` | `boss_copy_paste.gd:179` | adds |
| copied spells sound glitched | `boss_copy_paste.gd:221` (`cast_copy`) → `cast(id, from, 1.0)` on a "glitch" variant | changes |
| `sfx("gulp", ..., position)` (rate-limited) / `sfx("choked")` | `boss_collector.gd:81`, `83` | adds |
| `snapshot(&"menu")` / `snapshot(&"play")` | `main.gd:339-340` (`_open`) / `main.gd:342` (finished callback, when `_playing`) | adds |
| `music("title")` also stops the ambience | `main.gd:100` (inside Audio, no call-site change) | fix |
| screen press sound becomes overridable | `screen.gd:129-130`: the handler returns or declares its own sound; `main.gd:342` drops `ui_close` when a close sound already played | fix (B13) |
| `sfx("ui_drag")` | `editor_screen.gd:472` | adds (orphan asset exists) |
| `sfx("ui_pick")` on a slot tap | `editor_screen.gd:527` | adds |
| `sfx("deny")` | `editor_screen.gd:493` | adds |
| swap-aware equip sound | `editor_screen.gd:495` (use the returned "place"/"insert"/"swap") | changes |
| `sfx("tip")` | `hud.gd:112` (when a hint is *shown*) | adds |
| `sfx("duck_say")` | `hud.gd:108` (when a say line pops; **WIP code, coordinate with its owner**) | adds |

---

## 5. Test impact

### What `test_audio_d8.gd` asserts today (5 tests, all passing)
1. The BS.1770 meter reads the calibration tone to ±0.15 LU at 32 and 44.1 kHz; silence is -inf.
2. Every WAV has a `LICENSES.csv` row; no NC licences; CC-BY rows name an author.
3. Every file peaks ≤ -1 dBFS, and each SFX sits on -18 LUFS (or -24 for `Audio.UI` names and `coin`). **Coupled to `Audio.UI`**, through `rstrip("_23")` on the file name.
4. Every `TRACKS` entry builds; the cellar is `AudioStreamSynchronized`; **the boss is `AudioStreamInteractive`**; drums, lead and boss p2 are whole bars; `layer("drums")` turns on.
5. Voice classes (`hurt` and `tele_mid` critical, `ui_equip` ui, `hit` combat); `hit_for` (ember → fire, frost → ice, mote → hit); **`stream("sfx_hit") is AudioStreamRandomizer`**; the five stingers exist; ≥ 70 distinct SFX names.

`test_feel.gd::test_every_sound_the_game_asks_for_exists` also requires `door`, `win`, `lose` and `swap` to exist, and every PROJ spell to be in `Audio.CAST`.

### What must change
- Test 4: "the boss is `AudioStreamInteractive`" becomes "the boss is synchronized with `loop_begin` after the intro", once the pipeline change lands.
- Test 5: "`AudioStreamRandomizer`" becomes "the cue has N variants and no-repeat picks" (3.2). The voice-class assertions become priority assertions.
- Test 3: keep the loudness gate, but read the target from the cue table (the cue-spec's bus and loudness) rather than `rstrip("_23") in Audio.UI`.
- `test_feel`: the required-names list follows the new cue-spec; drop names the spec retires.

### What to add (headless; the Dummy driver mixes, as the probe shows)
1. **Storm budget:** 200 `sfx("hit")` + 50 `sfx("boom")` in one frame produce ≤ 6 voice starts after `flush()`, with one `boom` among them.
2. **Priority:** fill the combat pool with `hit`s, request `kill_big`, then 20 more `hit`s: `kill_big` is still playing.
3. **Critical reserve:** 6 telegraphs, then `hurt`: `hurt` plays.
4. **Settings:** music off mutes Ambience; with sound off and music on, a stinger routes to an unmuted bus (B1, B3).
5. **Music state:** `music("")` 0.3 s into a crossfade leaves no player playing after the fade (B5). `music("title")` stops the ambience (B2). The `dead` snapshot's low-pass is still enabled while `music("")` fades (B4).
6. **Bar clock:** play "cellar", wait 1.3 s, `layer("drums", true)`: the switch lands within one mix buffer of a bar boundary, measured on `get_playback_position()`.
7. **Telegraph alignment:** `tele(1.2, ...)` makes the chosen cue end within one physics tick of 1.2 s.
8. **Coverage:** every cue the cue-spec names exists as a file, and **every shipped `sfx_*` is referenced by the cue table** (catches the 10 orphans).
9. **Over-firing:** a Loop chase, a thorn charge and a Collector compact start ≤ 1 shot-class voice each (`enemy_shot` prefix mapping).
10. **Quiet:** during a wand-lab step (`Game.quiet > 0`), `flush()` starts nothing, including loops and the heartbeat.
11. **Perf:** `test_world::test_stress_tick_budget` must not regress: the flush and coalesce happen once a frame, not once per hit.

---

## 6. How to verify on this Mac

| Command | Works here? | Notes |
|---|---|---|
| `tools/test.sh` | **Yes.** Baseline now (with the WIP tree): **`TESTS: 211 passed, 0 failed`**, exit 0 | Stress line: avg 10.48 ms, full-storm median 10.67, p25 10.23, worst 15.72, peak 1,292 bullets. The engine prints a harmless leaked-RID/ObjectDB warning at exit |
| `tools/test.sh --only=audio` | **Yes**, 12 s: 5 passed | The fast loop for wave 2 (`--only` matches file names) |
| `tools/godot.sh --path game -- --demo` | Yes (windowed, audible) | The bot plays with sound: the ear check for storms, pan and stealing |
| `tools/godot.sh --path game -- --step=9 --kind=boss` / `--kind=mini` | Yes | Boss cues, the phase-2 layer on the bar, the beam loop |
| `tools/godot.sh --path game -- --screen=pause` / `--screen=editor` | Yes | Menu snapshot; editor drag, drop and swap sounds |
| `tools/taptest.sh` | Yes, but on a Mac `with_display` drops Xvfb, so it opens real windows on screen (no `xvfb-run` here) | Needed only if UI input changes (the press-sound override touches `screen.gd`) |
| `tools/build_web.sh` then `tools/webtest.sh` | **Build: yes** (4.7.2 `web_nothreads_*` templates are installed). **Webtest: not yet**: node v26 is present but Playwright is not; the script's default `PLAYWRIGHT_MODULE` is a Linux path (`/opt/node22/...`) | One-time: `npm i -g playwright && npx playwright install chromium`, then `PLAYWRIGHT_MODULE="$(npm root -g)/playwright/index.mjs" tools/webtest.sh`. It checks the sound peak and `window.wandcraftMusicPeak`, which is the only automated check of the main-thread mix |
| `tools/audio.sh` | Not run (as asked) | Wave 2 needs it for new assets and for `loop_begin` in `.import` files; it rewrites `LICENSES.csv` and `credits_data.gd` |

The **delivery check for wave 2** (the studio's craft self-verification, not a new test suite): run `--demo` and one `--kind=boss` room with sound on. Then listen for: the elite kill tail surviving a storm, an offscreen telegraph panned to its side, drums entering on a downbeat, the pause muffle, and the defeat screen with no brightness pop. After that, run `tools/test.sh` green and one `tools/webtest.sh` pass once Playwright is installed.

---

## 7. Wave 2 implementation notes (Game Developer, 2026-09-27)

What shipped in `game/scripts/autoload/audio.gd`, against `research/sound-v2.md` §4 to §6 and §9. The differences from the spec, and why:

- **The cue table** is `CUES` (+ `GROUPS`, `CLASSES`, `CUE_DEFAULT`), with the spec's fields: `class, prio, group, cap, gap, gain_db, jitter_cents, pan, walk`. These are added to it:
  - `vol_db`: the ±1 dB variance;
  - `walk_win`, `walk_reset`, `walk_max`;
  - `semis`, `bus`;
  - `fallback`: an interim cue to play while a new file is missing;
  - `fam`, `lufs`: the family and the per-cue loudness target the tests check;
  - `hook_pending`.

  `DERIVED` builds `copy:<cast>` (Glitch bus, −2 st, eshot group) and `fam:<cast>` (−6 dB) from the cast files.
- **Walks** are keyed by group, so every kill variant shares one chain. Pylons walk by count (A C E A′). The walks use the boss and mini keys C (+3) and E (−5) in addition to the spec's area keys.
- **Heavy casts** use `sfx_<cast>_heavy.wav`, which the generator names this way (not a 4th numbered variant). It is never picked at random.
- **Telegraphs:** `tele_tick(id, left, prev_left, at)` is driven in world time, once per tick of the wind-up. It starts the file when no more than its length is left, from `length − left`.
  - It works for the 1.5 s masters and for shorter interim files alike.
  - Telegraph voices pause during hit-stop and in the menu snapshot, so they still end on the release frame.
- **The bar clock** is the player's playback position plus `time_since_last_mix`, without subtracting `get_output_latency()` (the spec §5.2 asks for the subtraction). Scheduled volume changes take effect at the mix head. The heard bar and the heard layer are both late by the same output latency, so subtracting it would land every switch late by that latency.
- **The v1 fallbacks** keep the game whole until `tools/audio.sh` finishes:
  - the boss plays its old intro through `AudioStreamInteractive` until `music_boss_p3` exists;
  - `V1_BPM` holds the old tempos until then;
  - cue `fallback`s cover the missing files.
- **Heartbeat:** HP < 30%, one `low_hp` beat every 1.2 → 0.9 s, and the music at 3 kHz / −2 dB. The switch is `Game.heartbeat`, shown as HEARTBEAT on the pause screen. The UX Designer owns the final wording and placement.
- **The SFX compressor keyed from Critical** is accepted: one envelope follower per sample is far cheaper than the reverb it replaces. The DOG's "3 always-on effects" holds, and `active_effects()` is tested.
- **Not wired, and marked `hook_pending`:**
  - `step_*` needs foot-frame events from the rigs;
  - `unlock` needs the end-screen goals;
  - `glitch_say`: the WIP HUD does not pass who is speaking;
  - `chomp`: no longer a wind-up, and no "bite lands" hook exists.
- **Tests:** `tests/unit/test_audio_d8.gd` has the family loudness checks, applied once the v2 files are present, and whole bars from the loop point. The new `tests/unit/test_audio_v2.gd` covers:
  - budget, merging, steals and the hurt reserve;
  - the variant picker, walks, snapshots and settings;
  - the bar clock, intensity hysteresis and telegraph alignment;
  - still-hazard routing, quiet sandboxes, one-tap-one-sound, and cue coverage.
