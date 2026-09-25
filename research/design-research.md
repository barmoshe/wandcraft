# Design research for the MVP (2026-09-25)

This is the evidence behind `design-plan.md` and ADR 0011. It collects four sourced briefs written for Bar's redirect: "focus on improving the game design, the level design, the graphics, the animations, the music". It also covers the spells and relics research he asked for, taking inspiration from Magicraft.

Under ADR 0002, mechanics may be inspired by other games. Names, text, numbers and art are always our own. Every external claim links to its source. Code references are paths under `game/`.

---

## 1. Game design and level design

### Why wand editing is optional today (from the code)
- **Spells equip themselves.**
  - `RunState.add_spell` puts a new spell straight into an empty slot of the current wand (`scripts/sim/run_state.gd`).
  - The first reward offers 3 finished shooting spells.
- **Any damage kills any enemy.** `Enemy.DEFS` has only hp, speed, radius and damage: no armour, shield, resistance, split or range band. Elites are simply ×2.8 HP.
- **Mana never runs out.** The starter wand has 80 mana with 18 regen, and Mote costs 3.
- **Encounters are flat.**
  - Waves are random picks from a budget of `6 + 2*step`, with no mix of roles.
  - Enemy HP grows ×(1 + 0.07·step).
  - Rooms are about one screen each, and their only features are pillars, spikes and crates.
- **Bosses test one thing each.** Each has 3–4 moves over 2 phases. Only the Loop checks your build: its segments pass damage to the head, which rewards pierce.

### How the reference games do wands and builds
- **Noita wand stats:** shuffle, spells per cast, cast delay, recharge, mana, charge, capacity, spread, and an "always cast" slot. Wands get better tiers deeper in ([noita.wiki.gg/wiki/Wands](https://noita.wiki.gg/wiki/Wands)).
  - Triggers carry a payload that is released on hit, on a timer or on expiry ([Spells](https://noita.wiki.gg/wiki/Spells), [Trigger](https://noita.wiki.gg/wiki/Trigger)).
- **Magicraft:**
  - Boosts affect the spells to their right; passives affect the whole wand wherever they sit.
  - Damage = spell × boosts × passives × crit.
  - "Cooldown" follows a full rotation; "interval" is the gap between spells ([Steam guide 3477176826](https://steamcommunity.com/sharedfiles/filedetails/?id=3477176826), [Steam discussion](https://steamcommunity.com/app/2103140/discussions/0/4845399560304011268/)).
  - **Our wand model already matches this core.**
- **Slay the Spire rarity offset:** starts at −5%, rises 1% for each common card you see, and resets when a rare appears. Elites give better rewards and bosses give rares ([StS wiki](https://slay-the-spire.fandom.com/wiki/Card_Rewards)).
  - Rare, overpowered combos are allowed on purpose ([GDC Vault](https://www.gdcvault.com/play/1025731/-Slay-the-Spire-Metrics)).
- **Balatro:** Boss Blinds each expose one thing your build depends on ([blinds](https://balatrowiki.org/w/Blinds_and_Antes), [guide](https://balatrocalculator.blog/blog/balatro-boss-blinds-guide/)).
- **Lesson:** building only matters when three things are true:
  1. Capacity and mana are scarce.
  2. The content asks questions your current wand fails.
  3. The answers feel great.

### Enemy roles and encounters
- **The Level Design Book** lists roles: grunt, squad, leader, tank, swarm, sniper. "Different combinations of enemy types should create different situations" ([book.leveldesignbook.com](https://book.leveldesignbook.com/process/combat/enemy)).
  - The Division's archetypes are similar ([gamedeveloper.com](https://www.gamedeveloper.com/design/enemy-ai-design-in-tom-clancy-s-the-division)).
- **Hades armour** is a yellow bar that must break before stagger works; elites add perks ([Armored](https://hades.fandom.com/wiki/Armored_enemies)).
- **Isaac champions** use a colour for each affix ([Champions](https://bindingofisaacrebirth.wiki.gg/wiki/Champions)).
- **Brotato** marks every spawn point with a red X one second before the enemy appears ([Steam](https://steamcommunity.com/app/1942280/discussions/0/3810656958845428240/)).
- **Telegraphs** should be at least 0.8 s for hard attacks and 1.5 s for easy ones ([gamedesignskills](https://gamedesignskills.com/game-design/game-boss-design/)).
- **Enter the Gungeon** doubled the size of its enemy bullets during development. Its rooms have interactive objects such as tables, barrels and chandeliers ([Q&amp;A](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-)).

### Rooms and maps
- **The Binding of Isaac:** a 13×7 playable grid, plus 2×2, 2×1 and L-shaped rooms. Rooms are split into easy, medium and hard pools, and the boss sits at the farthest dead end ([boristhebrave](https://www.boristhebrave.com/2020/09/12/dungeon-generation-in-binding-of-isaac/)).
- **Enter the Gungeon:** 4–8 hand-built "flows" per floor, with hub, reward and connector rooms. One-way loops put a risk in front of every reward ([boristhebrave](https://www.boristhebrave.com/2019/07/28/dungeon-generation-in-enter-the-gungeon/)).
- **Nuclear Throne:** random-walk floor makers, each biome with its own rules ([generator](https://github.com/DanielBV/Nuclear-Throne-Map-Generator)).
- **Slay the Spire map rules:**
  - No elites before floor 6.
  - Special rooms are never back to back.
  - A rest site always comes before the boss.
  - Source: [Map Generation](https://slaythespire.wiki.gg/wiki/Map_Generation).
- **Hades:** each door shows its reward, and a skull marks a mini-boss ([door symbols](https://game8.co/games/Hades-2/archives/453727)).

### Bosses
- **The beat structure:** intro → business as usual → escalation → "It's ON" → kill, with windows where the boss is vulnerable ([gamedeveloper](https://www.gamedeveloper.com/design/boss-battle-design-and-structure)).
- **Cuphead:** the attack pattern comes first, the intensity climbs through the fight, and the last phase is short ([Game Informer](https://gameinformer.com/feature/2022/12/27/how-studio-mdhr-builds-a-cuphead-boss)).
- **Isaac's Larry Jr.** splits when a middle segment dies, which rewards piercing shots ([wiki](https://bindingofisaacrebirth.wiki.gg/wiki/Larry_Jr.)).
- **Gungeon's Bullet King** fires bullets that burst in two stages ([wiki](https://enterthegungeon.wiki.gg/wiki/Bullet_King)).

### What we took from this
These became `design-plan.md` §§1, 3–6:
- 10 enemies, each needing a specific counter.
- Pierce, Blast and Shock as the three keywords that answer resistances.
- Spawn runes and wave grammar.
- 18 layouts in sizes S, M and L.
- Room features: spore pods, pits, brambles, pylons and gates.
- A visible 3-lane map.
- A Copy-Paste mini-boss that copies your wand.
- A 3-phase Infinite Loop that splits.
- A first run built as a curriculum.
- Meta-progression that unlocks content rather than stats ([Dead Cells blueprints](https://deadcells.wiki.gg/wiki/Blueprints)).

---

## 2. Spells and relics: the Magicraft deep dive

### Magicraft's logic
Sources for this section: [TheGamer tips](https://www.thegamer.com/magicraft-beginner-tips-tricks-guide/), [Wikipedia](https://en.wikipedia.org/wiki/Magicraft), [Volley guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3477176826), [boost thread](https://steamcommunity.com/app/2103140/discussions/0/3937895062997699349/), [charge slots](https://steamcommunity.com/app/2103140/discussions/0/4030223299335507592/), [GameRant best spells](https://gamerant.com/magicraft-best-spells/), [relics](https://www.thegamer.com/magicraft-best-relics/), [pool-ban thread](https://steamcommunity.com/app/2103140/discussions/0/595138951841343913/).

- **How a wand fires:**
  - Each slot fires in turn, left to right, then the wand loops.
  - Each wand has its own mana pool.
  - Relics that add mana are highly valued.
- **Two timers:** the cast interval is the gap between groups of spells; the cooldown follows the last group.
- **Boosts and passives:** boosts affect the spells to their right, and gaps between slots don't matter. Passives affect the whole wand.
- **Casting several spells at once:** "simultaneous casts" is a limit that can be raised. Payloads go past that limit. Payloads come in two kinds: pay once, or pay per repeat.
- **Charge slots:** some wands have extra slots that cost no mana. They fire when a charge fills, and players park summons there.
- **Summons** each have their own cap.
- **Leveling:** 3 copies merge into 1★, and 3 of those into 2★.
- **Size:** over 100 spells and over 80 relics.
- **Relics:**
  - Rarities are Common, Rare, Epic and Unique.
  - Epic relics cost health to take.
  - Curses come from cursed chests.
- **Elements:** fire, ice, lightning and poison, and each stacks.
- **Builds players love:** zero-cooldown homing, room-filling lasers, summon swarms, gold scaling, and spell duplication chains.
- **Complaints:**
  - Late-game relics are unbalanced.
  - The mechanics are poorly explained.
  - Rerolls don't find the spells your build needs.
  - Some spells hurt the player.

### Noita's lessons
- **Requirement spells** cast or skip based on HP, enemy count or every-other cast. They are the model for our IF/ELSE rune ([Requirement](https://noita.wiki.gg/wiki/Requirement)).
- **The Greek-letter spells** copy the first, last or all spells. They are the model for our copy runes ([Greek Spells](https://noita.wiki.gg/wiki/Greek_Spells)).
- **About 30% of players never reach wand editing** ([Steam](https://steamcommunity.com/app/881100/discussions/0/604148566876768427/)). Players built outside simulators just to see what a wand does ([Wand Simulator](https://noita.wiki.gg/wiki/Tool:_Noita_Wand_Simulator)).
- **What carries over to mobile:**
  - Keep: one condition per rune, one copy target, the depth cap, and a built-in cast-tree preview.
  - Avoid: shuffle, charges, and copy-everything spells.

### Relic patterns from other games
- **Counter relics** such as "every Nth attack" (Slay the Spire's [Pen Nib](https://slaythespire.wiki.gg/wiki/Pen_Nib)).
- **Downsides a build can plan around** ([StS discussion](https://steamcommunity.com/app/646570/discussions/0/3559414588264938158/)).
- **Duos and legendaries** that need two parents first ([Hades Duo](https://hades.fandom.com/wiki/Duo_Boons), [Legendary](https://hades.fandom.com/wiki/Legendary_Boons)).
- **Stacking rules:** most effects stack linearly; chances and damage reduction stack hyperbolically ([RoR2](https://riskofrain2.fandom.com/wiki/Item_Stacking)).
- **Order matters** ([Balatro joker order](https://balatrocalculator.blog/blog/balatro-joker-order-guide/)).
- **Evolutions:** a maxed item plus a catalyst ([Vampire Survivors](https://vampire.survivors.wiki/w/Evolution)).
- **Super mods** with prerequisites ([Nova Drift](https://nova-drift.fandom.com/wiki/Super_Mods)).
- **Shops weighted by tags** ([Brotato](https://brotato.wiki.spellsandguns.com/Shop)).

### Status effects
- **Hades** gives bonus damage when an enemy carries two or more status effects ([Status effects](https://hades.fandom.com/wiki/Status_effects)).
- **Our version has four statuses:** Burn, Chill, Static and Bitrot.
- **Two reactions:**
  - Thermal Shock.
  - Overclocked: an enemy with 2 or more statuses takes +20%.
- **At most 3 status pips per enemy**, and no ground hazards that hurt the player.

### What we took from this
These became `design-plan.md` §§1–2:
- 52 spells, including Firewall, Bitrot Spore, Hex Cursor, Ping, Orbit, Reverse, Siphon, Pipeline and Sleep(ms).
- Four Debugger runes: HEAD, IF/ELSE, GOTO and #include.
- Three familiars.
- Merge-2 leveling, and level 3 changes a spell's behaviour.
- Corrupted rarity and a Deprecate pool-ban.
- 38 relics:
  - conditional, scaling, rule-breakers, program-aware and status relics
  - Merge Commit duos
  - Corrupted relics from the Glitch Door
- Six Compile evolutions.
- **Housekeeping:**
  - Rename "Echo Crystal" and "Split Rune", which are close to Magicraft names.
  - Fix the misplaced section comments in `catalog.gd`.

---

## 3. Graphics and animation (all art stays drawn in code)

### What is wrong today (from the code and screenshots)
1. **The floor is the busiest thing on screen.** `RoomPainter._stones` bevels every tile ([Pixelblog 20: "Negative space is your friend"](https://www.slynyrd.com/blog/2019/8/27/pixelblog-20-top-down-tiles)).
2. **The outline is almost black on a dark floor.** `selout` uses `RAMPS[k][0].darkened(0.25)`, which is nearly black. Real sel-out keeps the dark edge only where the sprite meets the background ([Pixnote](https://pixnote.net/en/learn/outlines/)).
3. **The hero is a front-facing mannequin** with the arms baked in. The wand is rotated freely at runtime, which breaks its pixels ([RotSprite](https://en.wikipedia.org/wiki/RotSprite)).
4. **Enemies "breathe" by fractional scaling (±6%)**, which smears their pixels. Celeste squashes by one pixel row instead ([Sprite-AI](https://www.sprite-ai.art/blog/sprite-animation-frames)).
5. **An automatic rim light** gives every shape the same pillow shading.
6. **Pink means friend, foe and threat at once:** enemy bullets are `#ff4a7a`, the player's moths are rose, and the enemies are magenta.
7. **The canopy is concentric discs**, which read as green balls.
8. **Walls have no depth sorting**, so actors walk over the cap of the bottom wall.

### References
- **Hyper Light Drifter** is 480×270, like us, and relies on colour, scale and flat gradients ([Wikipedia](https://en.wikipedia.org/wiki/Hyper_Light_Drifter), [Game Developer](https://www.gamedeveloper.com/business/the-ultra-modern-stylings-of-hyper-light-drifter)).
- **Nuclear Throne:** 320×240 with 24×24 sprites ([size refs](https://hitreg.tumblr.com/post/147680100338/nuclear-throne-ingame-art-size-refs)).
- **Slynyrd's top-down character** is 26×32 ([Pixelblog 55](https://www.slynyrd.com/blog/2025/3/24/pixelblog-55-top-down-character-animation)).
- **Dead Cells** rendered small cel-shaded 3D models without anti-aliasing so timing could be changed in minutes ([Game Developer](https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-)). Our equivalent is part rigs baked to atlases.
- **Rain World** builds creatures from connected points with parts hung on them like a paper doll ([Game Developer](https://www.gamedeveloper.com/art/video-animating-i-rain-world-i-and-its-many-squishy-stretchy-creatures)).
- **Hue shifting across a ramp** ([Pixelblog 1](https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes)). Top-down walls with a face and a cap ([Pixelblog 35](https://www.slynyrd.com/blog/2021/11/30/pixelblog-35-top-down-interiors), [45](https://www.slynyrd.com/blog/2023/7/21/pixelblog-45-bricks-walls-doors-and-more)).
- **Animation:**
  - Slynyrd's run cycle is 6 frames, and the head bob goes −1, −1, +2.
  - Celeste's run cycle is 4 frames, with squash and stretch done by 1 pixel row.
  - Holding an impact frame for about 150 ms sells the hit ([PixiMelon](https://piximelon.com/guides/pixel-art-animation-basics/)).
- **Rotating pixel art cleanly:** cleanEdge is MIT-licensed, has a Godot shader, and adds no new colours ([gist](https://gist.github.com/torcado194/e2794f5a4b22049ac0a41f972d14c329)).
- **Autotiling:**
  - Blob and Wang tilesets ([Boris the Brave](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/)).
  - Dual-grid tilemaps need only 16 shapes built from corner stamps ([Godot dual-grid](https://github.com/jess-hammer/dual-grid-tilemap-system-godot), [TileMapDual](https://github.com/pablogila/TileMapDual)).
- **VFX:**
  - Gungeon uses white and red enemy bullets on purpose ([Q&amp;A](https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-)).
  - Saint11's explosion, fire and smoke guides ([GitHub](https://github.com/saint11/Saint11Tutorials)).
  - Palette-swap shaders ([KoBeWi](https://github.com/KoBeWi/Godot-Palette-Swap-Shader)).
  - A positioned shockwave shader ([godotshaders](https://godotshaders.com/shader/positioned-shockwave/)).
  - Telegraph design ([GDKeys](https://gdkeys.com/keys-to-combat-design-1-anatomy-of-an-attack/)).
- **Lighting on phones:**
  - Godot's docs note that additive sprites are much faster than lights ([docs](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)).
  - Moonlighter uses no dynamic lighting at all ([80.lv](https://80.lv/articles/moonlighter-building-pixel-art-preparing-for-switch)).

### What we took from this
These became `design-plan.md` §§7–8:
- A quiet floor with a 3-step value band.
- An outline rule: ink only on the bottom and right edges and the ground line.
- Reserved colours by role:
  - enemy threat is red with a white core
  - player magic is cool colours plus gold
  - pickups are gold and green
  - the environment is desaturated
- A 40-colour master palette, with 8 colours plus 1 accent per biome.
- `RigDef` and `RigBaker`.
- The hero as a rig of about 22×30, with 2 facings and about 50 frames. The wand is pre-rotated to 16 angles.
- Squash and stretch done by pixel rows, never by scaling.
- RoomPainter v2: stamps placed by Poisson scatter, dual-grid walls, and a y-sorted overlay for the front caps.
- A palette LUT shader.
- Baked light pools, plus at most 1 `PointLight2D`.
- The VFX set.
- New art-sheet checks: a value strip, a silhouette view, a sprite composited on the floor, and a phone-size view.

---

## 4. Music, sound and game feel

### What is wrong today (from the code)
- **The phone speaker problem:**
  - Bass roots at 82–123 Hz are 4–7× louder than the lead.
  - The kicks are sines at 41–62 Hz, and the booms rest on 60–90 Hz.
  - Phone speakers roll off below about 220–400 Hz ([Audiokinetic](https://blog.audiokinetic.com/loudness-and-frequency-response-on-popular-smart-phones/)).
  - So most of our mix is energy the phone can't play.
- **Sounds are normalized by peak, not loudness.** The synth runs at 22 kHz mono and its oscillators alias.
- **Music loops are 29–42 s.** A room lasts 1–2 minutes, so each room hears the same loop 2–4 times.
- **No sound priority:** 14 players take turns round-robin. There are no variants and no UI bus.
- **Feel:**
  - A kill's shake of 0.06 moves the screen by less than 1 px.
  - The camera `lerp(…, 0.2)` runs once per frame, so it behaves differently at 60 and 120 fps.
  - There is no aim lead, no hit-stop when you get hurt, no muzzle flash and no recoil.
  - The defeat screen waits 1.6 s.

### Music
- **Adaptive music has three tools:** vertical layers, horizontal re-sequencing, and stingers ([The Game Audio Co](https://www.thegameaudioco.com/making-your-game-s-music-more-dynamic-vertical-layering-vs-horizontal-resequencing)).
- **Godot 4.3+ does both natively.** `AudioStreamSynchronized` plays layers together. `AudioStreamInteractive` switches on the next beat or bar, with crossfades. OGG files carry BPM metadata ([Blips](https://blog.blips.fm/articles/the-new-music-features-in-godot-43-explained), [docs](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html)).
- **Hades** adds drums in combat and picks guitar and bass stems semi-randomly for each room ([gameplay.co](https://gameplay.co/hades-game-music-sound-design-darren-korb-supergiant-games/)).
- **Balatro** has 5 variants of one composition that cross into each other ([Balatro Wiki](https://balatrowiki.org/w/Music)).
- **Loops should last as long as the context they play in** ([Gamedeveloper](https://www.gamedeveloper.com/audio/rethinking-the-audio-loop-in-games)).
- **Loudness targets:** −18 LKFS for portable devices under Sony's ASWG ([ASWG-R001](http://gameaudiopodcast.com/ASWG-R001.pdf)).

**$0 sources:**

| Source | Licence | Notes |
|---|---|---|
| [Tallbeard/Abstraction loop bundle](https://tallbeard.itch.io/music-loop-bundle) | CC0 | 200+ loops |
| [Three Red Hearts](https://tallbeard.itch.io/three-red-hearts-prepare-to-dev) | CC0 | |
| Juhani Junkala: [5 Chiptunes Action](https://opengameart.org/content/5-chiptunes-action) | CC0 | |
| qubodup: [Dark Shrine Loop](https://opengameart.org/content/dark-shrine-loop) | CC0 | Includes the LMMS project, so we can pull stems |
| Eric Matyas, [soundimage](https://soundimage.org/attribution-info/) | Credit required | |
| Kevin MacLeod, [incompetech](https://incompetech.com/music/royalty-free/licenses/) | CC BY 4.0 | |

**Avoid:**
- FreePD (closed in 2025).
- "CC0" packs made with AI.
- Anything with a non-commercial (NC) licence.
- Pixabay tracks registered with Content ID ([Pixabay](https://pixabay.com/blog/posts/how-to-clear-a-youtube-content-id-claim-with-a-pix-190/)).

**Our own tools:**
- [Bosca Ceoil Blue](https://github.com/yurisizov/boscaceoil-blue) exports WAV, MIDI and XM.
- [Furnace](https://tildearrow.org/furnace/) exports each channel separately, which gives us stems.

### Sound effects
- **Build sounds in layers:** transient, body, tail ([Splice](https://splice.com/blog/design-weapon-sound-video-games/)).
- **Vary them:** `AudioStreamRandomizer` with a pitch and volume range and a no-repeat mode ([docs](https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html)).
- **Duck the music:** a sidechain compressor on the Music bus ([docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html)).
- **Telegraphs:** a wind-up cue that matches the attack's timing ([Gamedeveloper](https://www.gamedeveloper.com/design/enemy-attacks-and-telegraphing)).
- **Phones:** saturate the low end so the harmonics carry ([Gamedeveloper](https://www.gamedeveloper.com/audio/making-good-sounding-audio-for-mobile-games)).
- **Haptics:**
  - Keep them sparse and paired with other feedback ([Apple HIG](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)).
  - Safari on the web has no vibration ([Godot Input](https://docs.godotengine.org/en/stable/classes/class_input.html)).

**Sources:**

| Source | Licence | Notes |
|---|---|---|
| Kenney [impact](https://kenney.nl/assets/impact-sounds), [interface](https://kenney.nl/assets/interface-sounds), [sci-fi](https://kenney.nl/assets/sci-fi-sounds) | CC0 | |
| [ChipTone](https://sfbgames.itch.io/chiptone) | CC0 | |
| jsfxr ([sfxr.me](https://sfxr.me/)) | "Unrestricted commercial use" | No formal licence stated |
| [Sonniss GDC bundle](https://sonniss.com/gdc-bundle-license/) | Royalty-free, **not CC0** | Raw files may not be redistributed, and it bans AI training. Record it as its own licence in the manifest. |

### Game feel
- **Hit-stop** scales with damage and has a cap; the victim shakes during the freeze ([Sakurai](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/), [SmashWiki](https://www.ssbwiki.com/Hitlag)).
- **Screen shake by "trauma"** ([Eiserloh GDC 2016](http://www.mathforgameprogrammers.com/gdc2016/GDC2016_Eiserloh_Squirrel_JuicingYourCameras.pdf)):
  - Trauma runs from 0 to 1, rises with events and decays linearly.
  - The shake itself is trauma² and follows Perlin noise.
  - Camera smoothing should use `x += (target − x)·k`, with `k` scaled by time.
- **The Art of Screenshake** ([Nijman](https://archive.org/details/the-art-of-screenshake)): camera lead toward the aim, muzzle flash, kickback, and debris that stays on the ground.
- **Dash timing:**
  - Gungeon's roll takes about 0.7 s and is invulnerable for the first half ([wiki](https://enterthegungeon.wiki.gg/wiki/Dodge_Roll_(Move))).
  - Celeste's dash takes 0.15 s ([source](https://github.com/NoelFB/Celeste/blob/master/Source/Player/Player.cs)).

### What we took from this
These became `design-plan.md` §§9–10:

**Music:**
- 6 music cues, each 2–3 minutes long, with layers and interactive transitions for the boss.
- A chip-leaning synth hybrid style.
- Loudness: about −18 LUFS for the game and −20 for the music.

**Sound effects and mix:**
- About 70 sound effects with variants.
- A single timbre for each element.
- Buses: Master with a limiter, Music with sidechain ducking, SFX with a Critical sub-bus, and UI.
- Voice classes for priority.

**Pipeline:**
- A `LICENSES.csv` manifest, with a test that enforces it.
- `tools/audio_norm.gd`, a loudness measurement based on BS.1770.

**Feel:**

| Effect | Value |
|---|---|
| Hit-stop | crit 40–50 ms, elite kill 70–90 ms, getting hurt 80–100 ms (new), boss phase 150 ms, boss kill 300 ms |
| Trauma shake | trauma², maximum 6–8 px |
| Camera | lead of 12–20 px toward the aim, frame-rate independent |
| Casting | muzzle flash plus 1–2 px of recoil |
| Dash | 0.18 s |
| Death to retry | about 1.1 s |
