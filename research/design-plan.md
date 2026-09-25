# Wandcraft MVP design plan (design-first re-plan)

- Approved by Bar: 2026-09-25. The decision record is ADR 0011, which supersedes the milestone order in ADR 0010. The evidence is in `design-research.md`.
- This is the working plan. Progress is tracked in `STATUS.md`.

## Context
Bar reviewed the first MVP plan (ADR 0010: infra, CI and store-first) and redirected it:
> "focus on improving the game design, the level design, the graphics, the animations, the music, etc. research design and re-plan"

He also asked for research on spells and relics, taking inspiration from Magicraft's logic and design.

Four new sourced briefs were produced:
1. Game and level design.
2. Graphics and animation.
3. Music, sound and feel.
4. Spells and relics, with a Magicraft deep dive.

They are in `research/design-research.md`.

**What changes:** the MVP is now defined by *game quality*. CI, store plugins and TestFlight move behind the design milestones; ADR 0010's M10–M11 still apply later. Architecture refactors (content as data, splitting `world.gd`, Control UI) are no longer milestones of their own. Each is done only when a design milestone needs it.

**Fixed constraints:**
- Art is drawn in code.
- Budget is $0.
- Audio is CC0, or CC-BY with a credit.
- Content is original (ADR 0002): mechanics may be inspired by other games; names, text and numbers may not.
- Web and APK builds ship at the end of every milestone for Bar to test.

## The diagnosis in one paragraph
Wand building is optional *by construction*:
- Spells slot themselves into the wand (`run_state.gd` `add_spell`).
- Enemies have only HP, so any damage answers every enemy.
- Mana never limits the player (80 mana, costs of 3).
- Waves are random picks from a budget.

**Art:**
- The floor is the busiest thing on screen: bevelled slabs on every tile.
- The "sel-out" outline is effectively near-black, drawn on a dark floor.
- The hero faces front with the arms baked into the body.
- Enemies animate in 2 frames and "breathe" by fractional scaling, which smears their pixels.
- Pink means friend, foe and threat at the same time.

**Audio:**
- Most of the mix's energy sits below what a phone speaker can play.
- The music loops are 30–40 s, so each room hears the same loop 2–4 times.
- Sounds are normalized by peak instead of by loudness.

**Feel:**
- Kill shakes are below 1 px, so they don't show.
- There is no hit-stop when you get hurt.
- The camera's smoothing depends on frame rate.
- There is no dash.

## Design pillars
1. **Your wand is the answer.** Every room asks a question: a shield, armour, a swarm, a ward. The answer is a wand edit, not better aim.
2. **You can read the program.** A live cast-tree preview, a visible cast pointer on the HUD, keyword cards, and status pips.
3. **Every hit lands.** Hit-stop, trauma shake, knockback, and sounds that phone speakers can carry.
4. **Figures pop off the ground.** Quiet floors, a strict outline rule, and reserved colours for each role.
5. **Short, dense runs.** 12–18 minutes, rooms of 60–100 s, back in a new run within 3 s of dying.

## 1. Wand and spell system
- **Editing becomes necessary:**
  - Only the first spell slots itself (for onboarding). Every later spell goes to the bag, and the reward card has an "Equip → pick slot" button.
  - Starter wands have 2–3 slots. Pick one of:
    - **Twig:** 3 slots, fast, 50 mana.
    - **Stub:** 2 slots, slow, 90 mana.
  - Capacity grows 3 → 4–5 by the mini-boss → 6–8 by the boss, through wand drops and a Forge "+1 slot".
  - Mana should cover about 1.5 rotations of a 3-spell program. The editor shows "mana per rotation vs regen" as a green or red bar.
- **Three resist keywords**, so specific spells answer specific enemies:
  - **Pierce** breaks frontal shields.
  - **Blast** breaks armour.
  - **Shock** strips wards.
- **The catalog grows from 40 to 52:**
  - **Shooting (15):** keep 12, add Firewall, Bitrot Spore and Hex Cursor.
  - **Carriers (3):** Seed, Starwheel, plus Ping (auto-delivers its payload to the nearest enemy).
  - **Behaviour boosts (11):** add Orbit, Reverse and Siphon. Cut Shatter. Merge Linger into Quicken. Heavy becomes "knockback plus wall-slam damage".
  - **Status coats (4):** Ember, Frost, Static and Rot.
  - **Draw (3):** Chorus, Twin, plus Pipeline (fires in a tight line).
  - **Triggers (6):** the current 5, plus Sleep(ms), the missing timer trigger.
  - **Debugger runes (4, the signature twist):**
    - **HEAD:** copies the first spell.
    - **IF/ELSE:** branches on range.
    - **GOTO:** loops without recharging.
    - **#include:** makes one boost apply to the whole wand.
  - **Familiars (3):** Daemon, Watchdog Turret, Rubber Duck. Each has a cap shown on its icon.
  - **Passives (3):** Mana Well (Cache and Regen merged), Heat Sink, Watchdog.
- **Four statuses, each with one colour and one pip:**
  - Burn: orange.
  - Chill: cyan. At 3 stacks the enemy freezes.
  - Static: yellow. The enemy's next hit arcs to a neighbour.
  - Bitrot: magenta. At 5 stacks the enemy crashes.
  - **Two reactions:**
    - Thermal Shock: Burn plus Chill bursts.
    - Overclocked: an enemy with 2 or more statuses takes +20%.
  - At most 3 pips show per enemy, and there are no ground hazards that hurt the player.
- **Levels:** merge 2 copies, not 3; level 3 takes 4 copies. Level 3 changes *behaviour*, for example Mote pierces.
- **Rarity:** Common, Rare, Epic, plus **Corrupted** (an upside and a downside).
- **Shop:** one "Deprecate" per shop bans a spell from the pool.
- **Wand quirks:**
  - Daemon Rod: one slot fires by itself.
  - Debug Build: +2 slots, but Debugger runes cost double.
  - Mirror Rod and Fork Branch stay.
- **"Compile" evolutions (6):** a level-3 spell plus a catalyst at the anvil. For example, Chain Spark + Cascade Failure becomes Storm Protocol; Null Orb + Gravity becomes Singularity Kernel.
- **Rewards:**
  - A Slay the Spire-style rarity offset.
  - A guaranteed "counter" option before each boss.
  - The tag lean stays.
  - Offer cards show "Enables" chips, for example "+ Thermal Shock with your Frost Coat".
- **Two renames for ADR 0002 hygiene:** Echo Crystal and Split Rune.

## 2. Relics: 28 → 38
- **Kept:** 18.
- **Cut or folded:** 10 flat stat bumps and duplicates (Blast Radius, Bounce Core, Hotkey Boots, Lucky Bit, Spare Battery, Echo, and others).
- **New, 20:**
  - **Conditional:** Cold Start, Low Battery, Cornered.
  - **Scaling:** Uptime, Version Control, Hoarder's Ledger.
  - **Rule-breakers:** Root Access, Stack Overflow (nesting depth 5), No-Clip.
  - **Program-aware:** Off-by-One, Tail Call, Loop Counter, Empty Set.
  - **Status:** Surge Protector, Rot Index.
  - **Merge Commit duos** (offered only when you own both parent relics): Thermal Throttle, Zero-Day Exploit, Swarm Protocol.
  - **Corrupted, from a Glitch Door that costs 10 max HP:** Race Condition, Memory Leak, Force Push, Legacy Code.
- **Stacking:** percent chances and damage reduction stack hyperbolically.
- **Counter relics** show a pip on the HUD.

## 3. Enemies and encounters: 6 → 10
| Enemy | Role | What it does | Counter |
|---|---|---|---|
| Moss Blob | Fodder | Splits into 2 when it dies | Area, pierce |
| Bugling | Swarm | Packs of 5; crouches 0.3 s, then lunges | Fan, Static |
| Hex Weaver | Ranged | 3-shot volley with a 0.5 s glow first | Seek, Lance |
| Thornback | Charger | 0.65 s lane telegraph, then charges; a wall hit stuns it and it takes crits | Crits, mines |
| Puffcap | Area denial | Leaves a spore tile behind | — |
| Rune Sentry | Sniper | Frontal shield; 0.8 s laser sight before firing | Pierce, carriers |
| Bark Golem (new) | Tank | Armour bar; slam with a 1 s ring telegraph | Blast |
| Lantern Wisp (new) | Support | Wards 3 allies | Multi-hit, Static |
| Brood Stump (new) | Summoner | Spawns buglings | Area, Finally |
| Glitch Tick (new) | Exploder | 0.8 s blink, then bursts; Frost stops the fuse | Frost |

**Elite affixes:**
- Armored, Warded, Hasted, Forked, Mirrored.
- Each has an outline colour and an icon.
- One per elite in World 1.

**Spawn rules:**
- A 0.8–1.0 s rune plus a sound before anything spawns.
- Nothing spawns within 96 px of you or inside your aim cone.
- At most about 40 enemy bullets on screen.

**Wave grammar:**
- Each wave is one anchor (ranged, area denial, tank or summoner) plus pressure (fodder, swarm or charger).
- No two anchors before step 3.
- Wave 2 arrives when 70% of wave 1 is dead.
- Every third fight room is a themed "puzzle room" that tests one counter:
  - Sentry Wall: pierce.
  - Nursery: area.
  - Golem Pair: blast.

## 4. Level design
**Rooms:**
- 16 px tiles against a 480×270 view.
- Three sizes:
  - **S:** 20×12, a static camera.
  - **M:** 30×17, the camera scrolls about 1.1 screens.
  - **L:** 40×22, about 1.5 screens.
- **18 fight layouts:** 6 S, 8 M and 4 L, each tagged by feature and pooled as easy, medium or hard.
- Plus 3 boss arenas and the service rooms.
- **Camera:** frame-rate independent, leading 12–20 px toward the aim in rooms bigger than the view.

**Room features:**
- Crates and spikes (existing).
- **Explosive spore pods:** Blast chains them together.
- **Pits:** knockback into a pit kills fodder; Gravity pulls enemies in.
- **Bramble walls:** Burn clears them.
- **Rune pylons:** hitting one sends a pulse that stuns or strips wards.
- **One-way vine gates.**

**Layout rules:**
- 2–3 cover clusters per M room.
- One sightline of at least 150 px.
- At least one chokepoint.
- No spawn socket visible from the entrance.
- Doors can be on any wall.

**World 1 sub-areas:**
| Sub-area | Steps | Look | Features |
|---|---|---|---|
| Mossy Root Cellar | 1–4 | Open rooms | Spore pods |
| Corrupted Grove | 5–8 | Denser | Brambles, pits, glitch tiles |

Each sub-area has its own palette and its own music layer.

**Map:**
- A visible 3-lane map, 11–12 nodes: 7–8 fights, mini-boss, shop, spring, forge or altar, and the boss.
- **Rules:**
  - The first 2 nodes are fights.
  - No elite or challenge node before node 4.
  - No two service nodes in a row.
  - A spring or shop always comes before the boss.
- **Special rooms:**
  - Altar: 15% max HP for an Epic.
  - Challenge room: no-hit or timed, pays a relic.
  - Debug Terminal: reveals the next 2 nodes or rerolls one.
  - A hidden secret room behind a cracked wall that Blast opens.

## 5. Bosses
**Copy-Paste (mini-boss, about 45 s):** it *copies your wand*. At spawn it reads the first 3 spells of your active wand and fires them back at you.
- **Phase 1:**
  - Mirror Walk.
  - Copy Cast: your own program, reversed, after a 0.6 s glitch flash.
  - Ctrl+Z: teleports back.
- **Phase 2, at 50%:**
  - Splits into 2 clones. The real one flickers.
  - Ctrl+V: pastes buglings.
  - Select All: a 1.2 s box outline, then the box fills.
- **Weak window:** it lags after each Ctrl+Z and takes ×1.5.
- **Counters:** the Watch rune finds the real clone; area spells hit both.

**The Infinite Loop (boss, 60–90 s):**
- **Phase 1:**
  - Laps the arena.
  - Tail Volley.
  - Lap Charge: the track lights up 0.8 s first.
  - The head is armoured (Blast); the segments pass 40% of their damage to the head.
- **Phase 2, at 66%:**
  - Destroying 3 segments in a row splits the Loop into two (Larry Jr.-style).
  - while(true) rings.
  - Hitting 4 pylons derails it for 4 s, and it takes ×2 damage.
- **Phase 3, at 30%:**
  - A head-only chase.
  - Its trail becomes a short-lived damaging line.
  - Shorter than phase 2.

**Readability:**
- A distinct telegraph shape for each attack.
- At most 2 attack types active at the same time.
- Large bullets with white cores.

## 6. Progression and onboarding
**The first run is a curriculum**, where each lesson is a room your current wand fails:
1. Mote only against buglings.
2. The reward is Empower, which goes to the bag with the hint "drag into slot 2".
3. Shielded Sentries show "BLOCKED" until you equip the Needle or Phase you were offered just before.
4. A Golem teaches Blast.
5. The Copy-Paste mini-boss turns your own wand against you.

**Tested:**
- First wand edit by 120 s.
- First trigger by 180 s.

**Meta (Dead Cells style):**
- Each run earns Source Fragments.
- Fragments add spells, relics, wands, Debugger runes and a second starter loadout *to the pool*. The only stat upgrade is +1 starting slot.
- A visible Codex tracks unlocks.
- "Bug Reports" heat tiers stack affixes for replay.

**Economy:**
- Forge "+1 slot" for 60 gold.
- Reroll: 10 gold, +5 for each use after that.
- The Interest relic stays.

## 7. Graphics (still drawn in code)
**Figure and ground first:**
- A quiet floor: 3 value steps, low saturation, large calm areas, and no per-tile bevels.
- Walls are darker on the face and lighter on the cap.
- **Outline rule:**
  - An ink outline only on the bottom and right edges and at the ground line.
  - The top and left edges take the pixel's own ramp step 1–2, with an optional 1 px rim light.
  - Props get no outline.
- **Reserved role hues:**
  - Enemy threat: hot red with a white core, used nowhere else.
  - Player magic: cool colours plus gold.
  - Pickups: gold and green.
  - Environment: desaturated.
- **Palette:** a master palette of about 40 colours. Each biome uses 8 of them plus 1 accent.

**Characters:**
- **Hero:** keeps the hipster identity on a chunky 3/4-view rig of about 22×30.
  - A 12 px head with the glasses and quiff readable.
  - Visible arms, and a hand that holds the wand.
  - 2 facings, mirrored to give 4.
  - The wand is pre-rotated to 16 angles with cleanEdge or RotSprite, then snapped.
  - Squash and stretch by adding or removing a pixel row. No `Node.scale`.
- **Enemies:** fodder 14–20 px, elites 24–32 px, mini-boss 32–40 px, bosses 48–80 px as part rigs.

**Pipeline:**
- A `RigDef` resource: parts are ASCII stamps with pivots, poses are integer offsets, and secondary motion comes from sine waves with lag.
- `RigBaker` bakes each rig to an atlas and `SpriteFrames`, cached.
- **RoomPainter v2:**
  - The floor from noise patches plus scattered stamps: 20–40 ASCII stamps per biome (rubble, roots, tufts, cracks) placed with a Poisson distribution in clusters.
  - Dual-grid autotiled walls.
  - A y-sorted front-cap overlay, so a wall in front hides your feet.
- A palette LUT shader handles biome, elite and status recolours. No more `modulate` tints.
- **Lighting:**
  - Torch pools baked into the room image.
  - At most 1 `PointLight2D`, for the player.
  - Glow from additive stepped sprites.
  - This works on the Compatibility renderer and on the web.

**VFX:**
- A 2-frame muzzle flash.
- A 3-frame hit spark, aligned to the hit direction.
- Enemy bullets: 6–8 px, white core, red ring, ink rim, drawn above player bullets.
- An 8-frame explosion.
- Particles snapped to whole pixels that fade by stepping down the ramp.
- Dithered trails.
- Ground telegraph decals (line, circle, cone) that fill up as the attack nears.
- Damage numbers:
  - 3 tiers: normal, gold crit, red damage to you.
  - Hits on the same target merge within 150 ms.
- Ambient life at 6–8 fps: torches, grass that sways when something passes, dust, leaves.
- A shockwave shader for bosses only.

**Review loop:** `artsheet.sh` gains a grayscale value strip, a black-silhouette pass, and actors composited on the real floor at 1× and 3×. It also produces a phone-size room shot. Bar approves the sheets.

## 8. Animation (frame budgets)
**Hero** (about 25 frames per facing, about 50 total):
| Action | Frames |
|---|---|
| Idle | 4 |
| Run | 6 (with a Slynyrd-style head bob) |
| Cast | 3 (anticipation, a fire frame with a smear, recover) |
| Dash | 4 |
| Hurt | 2 |
| Death | 6 |

**Enemies:**
| Action | Frames |
|---|---|
| Move | 4 |
| Telegraph | 2 |
| Attack | 2 |
| Hurt | a 1-frame flash |
| Death | the dissolve plus a 4-frame poof |

**Bosses:** about 30 frames each, through the rig.

**Timing principles:**
- Poses hold on the extremes.
- The impact frame holds about 150 ms.
- Hair and cape lag one frame behind the body.

## 9. Music and sound
**Music: 6 cues, OGG at 44.1 kHz stereo, with BPM metadata.**
| Cue | Length | How it adapts |
|---|---|---|
| Title / hub | 1:30–2:30 | One loop |
| Forge / shop | 2:00+ | The title's motif without the melody (Balatro-style variant) |
| World 1 | 2:00–3:00 | `AudioStreamSynchronized`: base, plus drums in combat, plus lead in elite rooms; stems chosen per room, Hades-style |
| World 1 alternate (Corrupted Grove) | 2:00–3:00 | Same as World 1 |
| Boss | 8 s intro, then 1:30–2:00 loop | `AudioStreamInteractive`: intro, loop, then a phase-2 layer that switches in on the bar |
| Stingers | 2–6 s each | Room clear, reward, victory, defeat, boss intro |

- **Style:** chip-leaning synth hybrid, with chip leads for "code", warm pads for "arcane", and glitch percussion.
- **Sources, all $0:**
  - Audition first: the Tallbeard/Abstraction loop bundle (CC0, 200+ loops); Juhani Junkala's action chiptunes (CC0); qubodup's Dark Shrine loop (CC0, with the LMMS project for stems); Eric Matyas / soundimage (credit required).
  - Avoid: AI-made "CC0" packs, anything non-commercial, and Pixabay tracks with Content ID.
  - Missing stems can be made by filtering, or from Furnace/Bosca tracker exports.
  - Bar picks the final tracks by ear.
- **Quick wins in the current synth now:**
  - Raise the bass an octave and cut the sub-bass kicks.
  - Give booms a thump in the 200–800 Hz range.
  - Normalize by loudness instead of peak.
  - Render at 44.1 kHz.

**Sound effects:** about 70, from Kenney (CC0), ChipTone (CC0), OpenGameArt CC0, and the Sonniss GDC bundle (royalty-free with restrictions, **not CC0**; tagged as such in the manifest).
- **Layering:** a transient, a body and a tail.
- **Variation:** `AudioStreamRandomizer` with 3–4 variants, pitch ±6%, volume ±1.5 dB.
- **One timbre per element:**
  - Fire: noise plus a saw wave.
  - Ice: a glassy tink.
  - Static: crackle.
  - Arcane: an FM bell.
  - Void: a reversed swell.
- **Enemy telegraphs** get a reserved rising cue that ends exactly on release.
- **Tuned for phone speakers:** a high-pass at 120–150 Hz and a saturated low end.

**Mix:**
- **Buses:**
  - Master: a -1 dB limiter.
  - Music: a sidechain compressor keyed by Critical.
  - SFX, with a Critical sub-bus (hurt, telegraphs, boss).
  - UI.
- **Priority:** voice classes replace the current round-robin.
- **Loudness:**
  - The whole game around -18 LUFS, with true peak at -1 dBTP or below.
  - Music around -20 LUFS.
- **Haptics:** only on hurt, crit, elite kill, boss moments and UI snap.

**Pipeline:**
- `assets_src/audio/LICENSES.csv`, and a test that fails if any file lacks a row.
- `tools/audio_norm.gd` measures loudness with BS.1770 filters.
- The credits screen is generated from the CC-BY rows.
- `webtest.sh` also checks the music bus.
- **Fallback:** MP3 for the web build if layered OGG crackles.

## 10. Game-feel parameters
**Hit-stop:**
| Event | Duration |
|---|---|
| Normal hit | none |
| Crit | 40–50 ms (at most once per 0.25 s) |
| Elite kill | 70–90 ms |
| You get hurt (new) | 80–100 ms |
| Boss phase | 150 ms |
| Boss kill | 300 ms |

A 1–2 px shake of the victim during the freeze.

**Shake (trauma model):**
- Shake strength is trauma², driven by Perlin noise.
- Maximum 6–8 px, no rotation.
- Trauma added per event:
| Event | Trauma |
|---|---|
| Kill | +0.1 |
| Crit | +0.15 |
| You get hurt | +0.35 |
| Boss kill | +0.8 |

**Casting feel:**
- A 1-frame flash at the wand tip.
- 1–2 px of wand recoil.
- Scorch or dust decals stay until the room ends.

**Dash:**
- 0.18 s long, 0.12–0.15 s of i-frames, 3 afterimages, 0.35 s cooldown, a whoosh sound and a light haptic.

**Death:** the new-run prompt comes after 1.0–1.2 s (today 1.6 s), with a low-pass sweep on the music. One tap retries.

## Milestones (each ends with a web build, an APK, a STATUS update and Bar's review)
- **D0: Design bible and quick wins.**
  - Save the four briefs as `research/design-research.md` and the full design as `research/design-plan.md`.
  - Write ADR 0011: the design-first re-plan, superseding ADR 0010's milestone order.
  - Feel quick wins:
    - trauma shake
    - frame-rate-independent camera with aim lead
    - hit-stop when hurt
    - 1.1 s death-to-retry
    - muzzle flash and recoil
  - Audio quick wins in `gen_audio.gd`.
  - *Exit:* the tests stay green, and Bar feels the difference.
- **D1: Art direction foundation.**
  - A quiet floor, the outline rule, walls with face and cap plus the front-cap overlay, reserved role hues, the new enemy-bullet family, and the palette LUT shader.
  - The artsheet value, silhouette and phone-size checks.
  - An ADR on art direction that supersedes ADR 0007's rules.
  - *Exit:* Bar approves the before/after sheets.
- **D2: The spell system.**
  - Stop auto-slotting. Starter wands with 2–3 slots. The mana bar.
  - The resist keywords, the 4 statuses and 2 reactions.
  - The new spells, including the Debugger runes and the familiars. Merge-2, level-3 behaviours, Corrupted rarity.
  - The live cast-tree preview in the editor, and the cast pointer on the HUD.
  - *Enabler:* move spell content into data definitions.
  - *Exit:* the wand-engine golden tests are extended; the sweep covers every new spell.
- **D3: Relics and evolutions.**
  - 38 relics through a Stats and Hooks effect system (this replaces the 31 `has_relic` checks).
  - Duo relics, Corrupted relics from the Glitch Door, and the 6 "Compile" evolutions.
  - "Enables" chips on cards, and counter pips on the HUD.
  - *Exit:* a parity or behaviour test for every relic.
- **D4: Enemies and encounters.**
  - The 10-enemy roster, 5 elite affixes, the spawn rules, the wave grammar, and puzzle rooms.
  - *Enabler:* split `world.gd` into an encounter director and a combat module.
  - *Exit:* the bench gets two bots:
    - a bot that edits its wands survives 60–80%
    - a bot that never edits survives 15–30%
- **D5: Levels and the map.**
  - S/M/L rooms with a scrolling camera, 18 layouts, the new features (pods, pits, brambles, pylons, gates), 2 sub-areas.
  - The visible 3-lane map, the special rooms, and the secret room.
  - *Exit:* a validation test (doors reachable, spawns on floor, sockets not visible from the entrance); Bar plays 3 runs in 12–18 minutes.
- **D6: Hero and enemy animation.**
  - `RigDef` and `RigBaker`. The hero with 2 facings and about 50 frames. The pre-rotated wand.
  - The 10 enemies on rigs with their frame budgets, the VFX set, ambient life, and telegraph decals.
  - *Exit:* Bar approves the art sheets, and performance holds.
- **D7: Bosses.**
  - Copy-Paste copies your wand. The Infinite Loop gets 3 phases, the split and the pylons.
  - The shockwave shader and boss telegraphs.
  - *Exit:* bench boss times stay in range, and Bar plays both bosses.
- **D8: Music and sound.**
  - The license manifest and normalization tools.
  - The 6 cues, chosen by Bar from the shortlist, with layering and interactive transitions.
  - About 70 sound effects with variants.
  - The buses, sidechain ducking and priority classes. The credits screen. Haptics mapping.
  - *Exit:* the license test passes, `webtest.sh` checks music and sound effects, and Bar checks it on the iPhone.
- **D9: Onboarding and meta.**
  - The curriculum first run, Source Fragments, the Codex, Bug Reports heat, and the dash.
  - *Enabler:* move the menus to Control-based UI with text scaling where these screens need it.
  - *Exit:* the onboarding test (first edit by 120 s, first trigger by 180 s); Bar's fresh-eyes playtest.
- **After D9:** ADR 0010's M10–M11 (store-ready at $0, then the betas behind the accounts gate) and CI.

**Cut order if time runs short:**
1. Compile evolutions, down to 3.
2. L rooms.
3. The third familiar.
4. Bug Reports heat.
5. Music stems, down to 2 layers.

**Never cut:** the counters that make editing necessary, the cast-tree preview, the figure/ground art fixes, the hit feel, or the curriculum first run.

## Verification
**Automated:**
- The wand-engine golden tests, plus new goldens for the Debugger runes, merge-2, statuses and reactions.
- The spell × boost sweep extended to the new spells.
- A behaviour test for every relic and every evolution.
- Content validation for rooms and the map.
- The two-bot balance bench:
  - the bot that edits survives 60–80%
  - the bot that never edits survives 15–30%
  - no stalls
- The onboarding timing test.
- `taptest.sh` in 3 modes.
- `webtest.sh` for canvas fill, errors, and music and sound output.
- A license-manifest test.

**Visual:** `artsheet.sh` value strips, silhouettes, actors on the floor, and phone-size shots, compared before and after each art milestone.

**Bar, on every milestone:**
- Play the web build or the APK.
- Check the build stamp.
- Look at the milestone's own focus (feel, art sheets, a run's length and difficulty, the bosses, music chosen by ear).
