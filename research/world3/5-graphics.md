# 5. Pixel-art graphics for a small team at 480x270

Research note for Wandcraft World 3 (the Kernel) and the "more graphics" pass. Techniques only; no art is copied.

**Method and limits.** Every WebFetch call was blocked by the egress proxy (gamedeveloper.com, lospec, wikipedia, godot docs and fandom all refused), so the claims below come from search-result summaries of the linked pages, not full reads. Where I reason past a source, it is marked **[I]**. Project facts come from the repo: `project.godot` renders at 480x270 with `stretch/mode="viewport"` and `aspect="expand"`, and `scripts/art/style.gd` holds 5-step hue-shifted ramps with `threat` reserved.

---

## 1. Parallax: how many layers, and how to make them differ per biome

- Celeste mixes **static and parallax layers** that show through gaps in the background tiles, giving a distant reference point [2]. Its engine separates "parallax" layers from "effect" layers (snow, wind, dust) and has a foreground-effect opacity for things drawn in front of the player [39]. Pedro Medeiros's parallax tutorial [1] is the standard reference; I could only see its title.
- Dead Cells gets depth from **analogous palettes outdoors and complementary palettes indoors**, plus parallax textures, particles that "give density to the air", and foreground clouds [3].
- Blasphemous builds its backgrounds from many layers moving at different speeds [40].

**For Wandcraft [I]:** keep the shared far/mid/near backdrop and make it data. Each biome passes a ramp set and a "silhouette generator" into the same `backdrop.gd` functions, so one code path yields five backdrops. Add a 4th **foreground-edge layer** (hanging pages, cables) only in the top 24 px and side margins, never over the play floor. With `aspect=expand`, a 19.5:9 phone shows about 585x270, so every layer must tile horizontally past 480. Far layer: 2 ramp steps with low contrast. Mid layer: 3 steps. Near layer: 3–4 steps. The play layer owns the full 5-step range plus INK. Contrast should grow as layers come closer.

## 2. Lighting and colour grading per area and room mood

- Hyper Light Drifter lays **flat colour plus big gradients or vignettes** over its pixels, following Superbrothers, which adds richness without extra drawing [5][8]. Many of its lights are **semi-transparent shapes whose opacity is animated**, with most of the screen dark except a lit circle [6]. Its creator calls the 480p target intentional [7].
- Children of Morta: "The puppets are pixelated but we shine them with real lights" [9]. Eastward uses deferred lighting on pixel art, with fog layers and sun beams at dawn and dusk [10]. In Sea of Stars, magic lights the room and heroes glow in the dark [11]. Moonlighter has **no dynamic lighting** and fakes it by stacking sprites [12]. That is proof that the cheap route ships.
- **Godot cost:** one PointLight2D dropped an Android test from 60 to 42 fps [13a]. Godot also caps light interactions per node at 15 [13b]. Screen-reading shaders force a full back-buffer copy, which is expensive on mobile [14].

**For Wandcraft [I]:** because the viewport renders at 480x270, fill cost is small (about 130k pixels). The real costs are the number of lights and the number of back-buffer copies. Grade in three tiers:
1. **Area grade:** CanvasModulate, which costs nothing. The area's tint is fixed.
2. **Room mood:** tween the CanvasModulate colour ±5% in value (calm, alarm, boss) and swap the lamp sprite set.
3. **Lights:** use additive "light cookies" drawn on the glow layer as default (HLD-style opacity pulses). Allow at most 2–4 real PointLight2D per room, and only where the lights move (player magic, the boss core).

## 3. Readable hazards on busy floors

- Superhot's art director wanted "the red guys are the enemies". Colour works as UI: red means danger, black means usable, white is background [21].
- Shmup practice: bullets must contrast strongly with the backdrop. Cave uses pink and blue bullets. Orange reads poorly on black. Black-label editions darken the backgrounds. Small elements look desaturated, so they need high chroma [22].
- Dead Cells keeps saturation up so any new element draws the eye [3].

**For Wandcraft [I]:** the existing rules are right: a quiet 3-value floor, reserved `threat`, white cores. Two traps for World 3:
- **Page Archive:** a cream paper floor would erase the white bullet core. Keep the walkable floor dark (ledger-spine parquet), and put light paper only on wall caps and props.
- **Ring Zero:** threat red on near-black loses edge contrast. Give enemy bullets a 1-px `threat[1]` halo ring, and never let floor circuitry use `threat` hues or pickup-bright gold (see the brass ramp below).

Telegraphs should keep one shape language across worlds: a dashed ring that fills, then a solid flash, then the hit. Add an accessibility toggle that dims backdrop layers by 30%, as Cave's darker editions do.

## 4. Dialogue portraits at low resolution

- Stardew portraits are 64x64, with six standard emotions first and extras per character [23]. At 32x32 and above, changing only the eyes and mouth is enough for a set of expressions [24]. Celeste gives each speaker a name colour and its own box style [25].

**Spec for Wandcraft (see the end of this note).** Build portraits as layered code parts (head, brows, eyes, mouth, signature prop) and bake them to a small atlas at load. Talking is driven by the typewriter: open the mouth on vowels and close it on spaces and punctuation.

## 5. Living hubs

- Hades's House Contractor sells cosmetic renovations (floors, vases, rugs) alongside functional ones [26], which makes progress visible. Moonlighter's town gains new buildings as you invest [12].

**For Wandcraft [I]:** every hub unlock adds a prop that has an idle loop (2–4 frames), plus one ambient emitter (dust motes, page flutter). Add one reactive behaviour per prop: a candle leans away when the player dashes past, pages lift in a spell's wake. A day/night cycle is overkill underground. Instead, tie the hub's lamp count and grade to meta progress, so it gets warmer as the player clears more.

## 6. World transitions as set pieces

- The Messenger switches between 8-bit and 16-bit **in real time** as both mechanic and story [27]. Transistor's Cloudbank **fades to white** as the city is erased [28]. Deltarune uses lighting and colour shifts to mark world changes [32].

**For Wandcraft [I]:** enter the Kernel through a "boot": the first room renders in INK plus one ramp, and each ramp "loads" in turn. That is a palette-restriction shader with an animated threshold, or simply redrawing with a ramp mask.

## 7. Cheap ways to get "more graphics"

| Technique | Source | Wandcraft use [I] |
|---|---|---|
| **Palette swap / gradient map** | Godot shader library: color remap, gradient maps with blending, textureless swap [15] | Recolour enemies per world, give elite variants, fade the whole room during a boss phase |
| **Colour cycling** | Mark Ferrari animated water, fog and rain by cycling palette entries, and blended the steps ("BlendShift") [18] | Circuit pulses, lava cracks, page-lamp flicker with no animation frames |
| **Ordered (Bayer) dithering** | A 4x4 matrix decides which of two colours each pixel takes. Good for fog and vignettes [17] | Fog, void edges and light falloff drawn in 2 ramp steps. It stays pixel-true, where alpha blending would not |
| **Procedural decoration** | Gungeon's tech artist wrote both the dungeon generator and the procedural room decoration [33] | Decoration rules per area (shelf, lamp, loose page) on a seeded grid, kept off the lane between doors |
| **Pixelated god rays** | The shader has a pixel-size parameter and two ray layers [16] | Lamp shafts in the Archive. Better: bake them to a sprite and animate alpha |
| **Wobble** | Baba Is You keeps 3 frames per sprite for its wobble [30] | Glyph wobble on "unstable" Kernel tiles |
| **Juice** | Nijman's roughly 30 feel tricks [35] | Hit flash, shake and squash, already in scope |
| **Particles** | For small counts, CPUParticles2D beats GPU on low-end phones. Cap about 200–500 per emitter [36] | Ambient motes: CPU, fewer than 40 per room |
| **Hue-shifted ramps** | Up to about 20° of hue shift per step [19] | Already the Style rule |
| **"Cheater" colours** | Shovel Knight added 5 off-palette colours for darks and skin tones [20] | Allowed, but add them as named ramps, never inline |

## 8. Boss presentation

Practitioner guidance: letterbox bars, a HUD fade and a title card make a boss an event. Phase changes need a clear beat (roar, pause, shockwave). Arenas must not have occluders that hide attacks [38]. **[I]** At 480x270 a boss should span 64–96 px tall (4–6 tiles), or 3–4 times a regular enemy. Its entrance is a camera pan of at most 1.5 s that can be skipped after the first time. The arena changes between phases: a grade shift, plus tiles that open or close in view.

## 9. A digital world that is not Tron

- **Transistor:** a *romanticised* city of art-nouveau curves (Klimt, Mucha) rather than grid neon, and erasure is shown as fading to white [28].
- **Axiom Verge:** corruption is **tiles that look like mangled memory**, and the player can clean them up or make them worse [29].
- **NieR: Automata's** hacking game reuses the UI's restrained palette and flat geometry [31]. **Superhot:** three colours carry all the meaning [21]. **Deltarune's** cyber world builds a *city* with personality instead of an abstract grid [32]. HLD: impressionism beats detail [8]. Gungeon's R&G Dept is a themed secret floor with a fixed layout [34].

**Principles [I]:** (1) Show the *metaphor's material*, not glowing lines: paper, brass, ink, stacked pages, cabinets. (2) Put ornament on the structure, such as art-nouveau curves on circuit traces, not neon grids. (3) Keep the palette narrow and have one hue carry the meaning. (4) Make corruption an in-world *material* the player can read, with a matching mechanic. (5) Use data motifs from *this* game (wand slots, left-to-right order, triggers) instead of stock binary rain.

---

## Proposed looks for World 3

New ramps follow the house rule: dark to light, 5 steps, cool or violet shadows, warm lights.

### Area A: the Page Archive (paged memory)

```
"vellum":    ["#2a2130", "#4e3e48", "#7f6a62", "#b89f84", "#e8d9b4"]  # paper
"quill":     ["#0e0b19", "#1c1730", "#2e2648", "#463a62", "#6a5a82"]  # ink, shelf shadow, floor
"amber":     ["#34160c", "#763410", "#c66e1c", "#f2b03e", "#fff0b8"]  # lamps (walls and props only)
"verdigris": ["#0d2024", "#1a3f3e", "#2c665a", "#4b957c", "#8fcaa8"]  # aged brass, complement
```
- **Floor:** parquet of ledger spines in `quill` 1–3, the quiet band. One loose-page decal in `vellum` 2 per 12–20 tiles. No step 4–5 on the floor.
- **Walls:** caps are shelf tops in `vellum` 4 with a page-edge highlight at step 5. Faces are book spines in `quill` 1–2 with `verdigris` 2 label plates. INK on the bottom and right edges.
- **Props:** card catalogues (drawers rattle when hit), rolling ladders, reading lamps with an amber cone cookie, stacks that topple into page confetti.
- **Features:** "page-fault" gaps where a shelf section is missing and dithered void shows through. Index-card rails that act as hazard lanes.
- **Backdrop:** far is shelves receding into amber haze (`amber` 1–2 plus `quill` 1). Mid is lamp chains and catwalk silhouettes. Near is hanging pages. The foreground edge carries drifting pages in the top band.
- **Lighting:** CanvasModulate warm grey (about #d8ccc0). Amber cookies are additive on the glow layer. At most 2 real lights. Dust motes drift in the lamp shafts. Indoors, so the palette is complementary (amber against verdigris), as Dead Cells does [3].

### Area B: Ring Zero (the privileged core)

```
"void":     ["#030309", "#080a18", "#0f1428", "#1a2140", "#2a3358"]  # floor, backdrop
"brass":    ["#1a1208", "#382810", "#5c4418", "#886a2c", "#b49a56"]  # circuit traces (muted, so pickups keep bright gold)
"phosphor": ["#262216", "#564a30", "#98885c", "#d6c894", "#fffbe6"]  # pulses travelling along the traces
"nest":     ["#12040f", "#3a0a2e", "#761458", "#bc2a7a", "#ee70b0"]  # the bug's nest (a cousin of glitch, never threat)
```
- **Floor:** `void` 1–3 tiles with **art-nouveau circuit traces** in `brass` 2–3 (curves and whiplash lines, no right-angle grid). Pulses colour-cycle along the traces in `phosphor`.
- **Walls:** caps are brass bus-bars (`brass` 4, step 5 highlight). Faces are `void` 2 with engraved ring glyphs. Where the nest spreads, `nest` veins crawl over the faces.
- **Props:** privilege gates (concentric rings that rotate one pixel step per beat), interrupt bells, register pillars that show the player's wand-slot count as lit sockets.
- **Features:** the nest pulses at a heartbeat. Corrupted tiles flicker Axiom Verge style [29] and can be cleaned by a spell.
- **Backdrop:** far is concentric rings (Ring 0 to 3) in `void` 2–3. Mid is slow-rotating gear-like address rings in `brass` 1–2. Near is nest tendrils in `nest` 1–2. Add bottom-up fog in Bayer dither.
- **Lighting:** CanvasModulate cool (about #b8c0d8). Pulses and the nest are glow-layer sprites. One real PointLight2D on the nest core, scaled by the heartbeat.

### Portrait spec (3 NPCs)

- **Canvas:** 48x48, inside a 52x52 frame at the left or right of a 480x72 dialogue box, which leaves about 400 px for text. Style ramps only, INK bottom and right, lit from the top left.
- **Parts:** head/body base, brows (3: neutral, raised, knit), eyes (4: open, half, closed, wide), mouth (4: closed, small, open, frown), plus one signature animated element per NPC (a flickering quill tip, a rotating ring halo, a page turning). Six named expressions are made from combinations: neutral, happy, worried, stern, surprised, thinking [23][24].
- **Motion:** blink every 2.5–5 s at random (half 2 frames, closed 3, half 2 at 60 fps). Talking follows the typewriter at 8–10 Hz. A 1-px breathing bob every 1.2 s. The signature element loops at 4–6 fps.
- **Voice:** a name colour from the NPC's ramp [25], plus a per-NPC text-blip pitch.
- **Build:** compose from parts at load and cache one baked texture per (expression x mouth x eye) combination the first time it is used. Memory is trivial.

---

## 5+ original ideas for Wandcraft

1. **Syntax-highlit walls.** Kernel wall faces carry rows of glyph "code". When a spell lands near them, nearby glyphs flash in that element's colour for 0.3 s, as if the room were syntax-highlighting the player's program. **Cost: M.** **Perf:** glyphs are baked tile variants and the flash is a per-cell modulate tween capped at 16 cells, so there is no shader and no extra light.

2. **Boss "compile" entrance.** The boss rig is revealed in scanline order, top row to bottom, as if written into memory. A monospace title card types `LOADING <NAME>` while letterbox bars slide in. On phase change the boss "recompiles": it is redrawn in scanlines with a palette swap. **Cost: S** (a clip rect that grows over the baked frames). **Perf:** negligible, one clip rect.

3. **Boot-sequence transition into World 3.** The first Kernel room starts in INK plus `phosphor`, then "loads" one ramp per second (void, brass, vellum, then everything else) while the HUD prints fake boot lines. This is The Messenger's real-time style shift [27] used as a doorway. **Cost: M.** **Perf:** one full-screen palette-restriction pass at 480x270 for about 5 s, then it switches off. It is the only back-buffer read in the sequence.

4. **Colour-cycled circuitry.** Ring Zero traces are drawn once with an index channel of 0–7. A tiny shader (or 8 pre-baked frames) moves which index is brightest, so pulses flow along curved traces with no animation frames [18]. When the player casts, a pulse runs *left to right* across the nearest trace, echoing wand order. **Cost: S–M.** **Perf:** one texture lookup per trace pixel. Baking 8 frames removes the shader entirely.

5. **Page-fault fog.** Void edges, room borders and missing shelf sections dissolve into a 4x4 Bayer dither between `quill` 1 and `void` 1 [17] instead of alpha fog. The pattern slowly "scrolls" like uninitialised memory. **Cost: S.** **Perf:** bake the dither mask once per room edge. It animates with a 1-px UV offset and needs no screen read.

6. **Heartbeat grade.** The nest drives a single uniform: CanvasModulate value ±3% and the nest light energy pulse at the boss's heartbeat. The effect gets stronger the closer a room is to the nest. At boss phase 2 the room palette-swaps toward `void` while the bug and all `threat` stay at full chroma. **Cost: S.** **Perf:** CanvasModulate is free, and there is one light.

7. **Installed-module hub.** Each meta unlock "installs" a prop that boots in with a 6-frame dither dissolve, then idles (a lamp, a shelf, a ring gate). The hub's backdrop gains one lit window or ring per cleared world, so the hub visibly grows and remembers progress [26]. **Cost: M.** **Perf:** props are static baked sprites with 2–4 frame idles. Ambient motes use one CPUParticles2D with fewer than 40 particles [36].

8. **Spell-trail marginalia.** In the Archive, strong spells leave faint "margin notes" (tiny ink scribbles in `quill` 3) on the floor pages they cross. They fade after 4 s, so the fight writes its own annotation. **Cost: S.** **Perf:** a ring buffer of at most 24 decal sprites, never drawn in step 4–5, so the quiet floor band holds.

---

## Sources

1. Pedro Medeiros, "Parallax and depth" (Lospec): https://lospec.com/pixel-art-tutorials/parallax-and-depth-by-pedro-medeiros
2. Aran P. Ink, "Celeste Tilesets, Step-by-Step": https://aran.ink/posts/celeste-tilesets
3. Motion Twin, "Giving back colors to cryptic worlds in Dead Cells": https://www.gamedeveloper.com/production/art-design-deep-dive-giving-back-colors-to-cryptic-worlds-in-i-dead-cells-i-
4. Motion Twin, "Using a 3D pipeline for 2D animation in Dead Cells": https://www.gamedeveloper.com/production/art-design-deep-dive-using-a-3d-pipeline-for-2d-animation-in-i-dead-cells-i-
5. "The ultra-modern stylings of Hyper Light Drifter": https://www.gamedeveloper.com/business/the-ultra-modern-stylings-of-hyper-light-drifter
6. HLD pixel art tutorial (DeviantArt): https://www.deviantart.com/amjr831/art/Pixel-Art-Tutorial-Hyper-Light-Drifter-730141659
7. "Our Game is 480p, And Very Intentionally So" (NeoGAF): https://www.neogaf.com/threads/hyper-light-drifter-dev-alex-preston-our-game-is-480p-and-very-intentionally-so.933838/page-10
8. Unwinnable interview with Alex Preston: https://unwinnable.com/2015/12/02/interview-with-alex-preston-the-creator-of-hyper-light-drifter/
9. Children of Morta art (TechRaptor): https://techraptor.net/gaming/previews/how-dead-mage-created-art-for-children-of-morta ; Engadget: https://www.engadget.com/2018-03-22-children-of-morta-hands-on-indie-xbox-gdc.html
10. Eastward insights: https://www.gamedeveloper.com/art/eastward-s-creators-share-insights-on-making-pixel-art-adventures ; 80.lv: https://80.lv/articles/eastward-charming-chinese-pixel-art-adventure
11. Sea of Stars press kit: https://sabotagestudio.com/presskits/sea-of-stars/
12. Moonlighter pixel art (80.lv): https://80.lv/articles/moonlighter-building-pixel-art-preparing-for-switch
13. (a) Godot issue #81152: https://github.com/godotengine/godot/issues/81152 ; (b) Godot forum on PointLight2D limits: https://forum.godotengine.org/t/pointlight2d-performance-and-optimization/137342 ; issue #73751: https://github.com/godotengine/godot/issues/73751
14. Godot screen-reading shaders doc: https://github.com/godotengine/godot-docs/blob/master/tutorials/shaders/screen-reading_shaders.rst
15. Godot Shaders palette swaps: https://godotshaders.com/shader/color-remap-shader-palette-swapper/ ; https://godotshaders.com/shader/extensible-color-palette-mk-2/
16. Pixelated God Rays: https://godotshaders.com/shader/pixelated-god-rays-2/
17. Simple ordered dithering: https://godotshaders.com/shader/simple-ordered-dithering-and-screen-pixelation/
18. Mark Ferrari, GDC 2016 "8 Bit & '8 Bitish' Graphics": https://www.gdcvault.com/play/1023586/8-Bit-8-Bitish-Graphics ; canvascycle: https://github.com/jhuckaby/canvascycle
19. Slynyrd, Pixelblog 1, color palettes: https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes
20. Yacht Club, "Breaking the NES": https://www.yachtclubgames.com/blog/breaking-the-nes/
21. Superhot art direction (Fast Company): https://www.fastcompany.com/3057098/superhot-is-a-video-game-stripped-down-to-nothing-but-violence
22. "Building better bullets": https://bootcamp.uxdesign.cc/building-better-bullets-55b607905a8d
23. Stardew Valley modding, NPC data: https://stardewvalleywiki.com/Modding:NPC_data ; portraits: https://stardewmodding.wiki.gg/wiki/Tutorial:_Changing/Adding_Portraits
24. CraftPix prototype portraits: https://craftpix.net/freebies/free-prototype-dialog-portraits-for-pixel-games/
25. Celeste Wiki, Dialogues: https://celeste.ink/wiki/Dialogues
26. Hades House Contractor: https://hades.fandom.com/wiki/House_Contractor
27. The Messenger press kit: https://sabotagestudio.com/presskits/the-messenger/
28. Transistor (Wikipedia): https://en.wikipedia.org/wiki/Transistor_(video_game) ; art nouveau Cloudbank: https://videogamearchitecture.wordpress.com/2016/06/13/transistor-the-art-nouveau-influence-on-cloudbank/
29. Axiom Verge glitching (AV Club): https://www.avclub.com/the-ubiquitous-glitching-in-axiom-verge-is-a-feature-n-1798183607
30. Baba Is You wobble frames: https://babaiswiki.fandom.com/wiki/Level_Editor ; Alan Zucconi doodle shader: https://www.alanzucconi.com/2019/04/16/sprite-doodle-shader-effect/
31. PlatinumGames, UI design in NieR:Automata: https://www.platinumgames.com/official-blog/article/9624
32. Deltarune art design: https://indiegameworld.com/features/toby-fox-deltarune-art-design-indie-game-review/
33. Dodge Roll team (Gungeon wiki): https://enterthegungeon.wiki.gg/wiki/Dodge_Roll
34. R&G Dept: https://enterthegungeon.fandom.com/wiki/R%26G_Dept.
35. Nijman, "The art of screenshake": https://www.youtube.com/watch?v=AJdEqssNZ-U
36. GPU vs CPU particles on low-end devices: https://godotforums.org/d/37279-gpuparticles-vs-cpuparticles-for-lower-end-devices
37. Noita GDC talk: https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design
38. Boss presentation notes: https://github.com/TheShield2594/the-folded-frontier/issues/75
39. Celeste stylegrounds: https://github.com/coloursofnoise/Resources/wiki/Adding-Stylegrounds
40. Blasphemous 2 parallax: https://foro3d.com/en/2026/february/blasphemous-2-how-unity-powers-its-pixel-art-world.html
