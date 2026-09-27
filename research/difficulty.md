# Difficulty: research and tuning for Wandcraft

Researched 2026-09-27, at Bar's request ("the game overall is too easy, also the bosses and AI enemies. Maybe less start HP?"). Friend testers of 0.16 said the same (Yoaviko and Maor, `research/design-w2.md`). This builds on `research/magicraft-progression.md` and does not repeat it. Numbers are quoted from the code at `5d18b84`. Sources are at the end; anything inferred is marked **(inference)**.

## TL;DR
- **Yes, lower the start HP: 120 to 80** (the Apprentice keeps +20, so 100). On its own that is not enough, because Wandcraft's real softness is that a mistake costs 3-6% of your HP, never grows with depth, and every room heals you back.
- Change three things together: **start HP, damage per mistake (and let it grow with depth), and healing between rooms.** Then make enemies and bosses harder with behaviour (aim ahead, faster cadence, overlapping waves), not HP.
- Re-band the bench: the bot never dashes, so its 60% World 1 clear rate already overstates how hard the game is for people. After the changes the editing bot should clear World 1 about 25-45% of the time.

## 1. What Wandcraft does now

### The player
- **Max HP:** 120 base (`sim/run_state.gd:21-22`, `:81`), plus the hero's bonus: Apprentice +20, so 140 (`run_state.gd:50`). Pyromancer and Tinkerer start at 120.
- **After a hit:** 0.9 s of invulnerability (`world/player.gd:316`). A Hex Weaver's 3-shot burst lasts 0.28 s (`enemy.gd:11`, `bcd` 0.14), so **one mistake costs one hit**, not three. The same holds for Puffcap rings and boss fans.
- **Dash:** 0.18 s at 240 px/s, 0.14 s of i-frames, ready again 0.53 s later (`player.gd:66-69`). Walk speed is 92 px/s (`player.gd:7`).
- **Healing** (all per world of 10 rooms):
  - Every cleared room: +6 (`world/world.gd:654`, cut from 8 in 0.16.1).
  - Spring: 60% of max HP, 40% at heat 4+ (`world.gd:914`). The middle lane before each boss and mini-boss is always a spring or a shop (`sim/chapter.gd:191-192`).
  - Max HP room: +15 max, heal 15 (`world.gd:692-694`).
  - Shop heal: 35 HP for 25 gold (`sim/rewards.gd:202`). Debug Terminal: heal 35 (`rewards.gd:173`).
  - After each boss: a full heal (`world.gd:669`), then on entering World 2 another full heal and +10 max HP (`world.gd:778-785`).
  - Relics: Vital Patch +20 max and heal 20, Leech Charm 4 HP per 6 kills, Overheal Shield, Merge Heart +8 (`sim/relics.gd:16,19,21,40`).
  - Gentle mode: 2% less damage per lost run, up to 40% (`autoload/game.gd:161-165`).

### What one mistake costs
Enemy bullets deal 0.6 × the enemy's `dmg` (`enemy.gd:691`); bosses fire 6-damage bullets (`boss.gd:203`) and deal 12 on contact (`boss.gd:39`).

| Source | Damage | Share of 140 HP |
|---|---|---|
| Weaver / Puffcap bullet | 4.8 | 3.4% |
| Rot Weaver bullet | 4.2 | 3.0% |
| Rune Sentry bullet | 6.0 | 4.3% |
| Moss Blob / Thornback / Weaver touch | 5 / 8 / 8 | 3.6-5.7% |
| Glitch Tick burst / Kernel Panic burst | 14 / 16 | 10-11% |
| Boss bullet / boss contact | 6 / 12 | 4.3% / 8.6% |

- **About 29 bullet mistakes, or 17 touch mistakes, take a fresh Apprentice from full to zero**, before any healing.
- **Damage never scales.** Enemy HP grows with depth, ×(1 + 0.055 × depth), so ×1.55 at the Loop and ×2.1 at the end of World 2 (`world.gd:591-595`), but `dmg` is read straight from `DEFS` (`enemy.gd:187-188`). Max HP only goes up during a run, so **the game gets easier to survive the deeper you go.** At the end of World 2 a weaver bullet is about 3% of a typical 165 HP.

### Enemy behaviour
- **Nobody aims ahead.** Every enemy shot and boss fan aims at where you are now (`enemy.gd:364,380,535,548`, `boss.gd` `aimed()`). Walking in a straight line dodges most aimed fire.
- **Slow bullets.** Puffcap rings fly at 62 px/s, Weaver bullets at 85, and the Loop's rings start at 45 (`enemy.gd:11,17`, `boss_loop.gd:254`). All of these are slower than you walk (92).
- **Slow cadence.** Weaver: a volley every 2.8 s ±15% after a 0.5 s glow (`enemy.gd:11`). Rune Sentry: a burst every 2.6 s after 0.8 s of laser sight (`enemy.gd:21`). Puffcap: a ring every 3.0 s. Chargers wait 1.2-2.2 s after a dash (`enemy.gd:427`).
- **Telegraphs** are generous: Bugling 0.3 s, Blink Tick 0.45 s, Weaver 0.5 s, rams 0.65 s, Tick fuse 0.8 s, Golem slam 1.0 s, spawn rune 0.8-1.0 s (`world.gd:578`).
- **Waves barely overlap.** Two waves per room; the second comes when 70% of the first is down (`world/encounter.gd:22`). The budget is 6 + 2 × depth (`encounter.gd:57`), with a second anchor only 40% of the time from room 3 (`encounter.gd:66`).
- **Good already:** weavers strafe and keep 100 px, chargers only charge down clear lanes, ambush rooms ring you, and threat doors ask for a counter.

### Bosses
| Boss | HP | Moves (telegraph / act / recover, s) |
|---|---|---|
| Copy-Paste (mini) | 360 (`boss_copy_paste.gd:34`) | 0.6-1.2 / 0.3-1.6 / 0.5-1.0 |
| Garbage Collector (mini) | 380 (`boss_collector.gd:25`) | 0.6-0.8 / 0.3-1.4 / 0.4-0.9 |
| The Infinite Loop | 1800 (`boss_loop.gd:48`) | 0.5-0.8 / 1.6-3.0 / 0.5-0.6 |
| Deadlock | 1800 (`boss_deadlock.gd:40`) | 0.6-0.9 / 0.3-2.6 / 0.5-0.8 |

- After phase 1, telegraphs run at ×0.85 and recoveries at ×0.8 (`boss.gd:113,136`). A phase change clears every bullet and gives 2.4 s of calm (`boss.gd:65-85`).
- World 2's mini-boss has ×1.7 HP (`world.gd:628`). The Loop went from 850 to 1800 HP across balance passes; that is the "bullet sponge" lever.

### Heat (Bug Reports, `sim/meta.gd:73-80`)
Heat 1: an elite per fight. Heat 2: +20% enemy HP. Heat 3: shots 15% faster, one fewer door. Heat 4: springs heal 40%, shops +25%. Heat 5: bosses +25% HP. Two of the five tiers are HP.

### The bench (`tools/balance.sh`, `tests/bench/test_balance.gd`)
- 10 seeds. Band: the editing bot clears World 1 40-85% of the time; mini-boss 20-90 s, boss 30-150 s (`test_balance.gd:5-7,78,119-121`).
- Last measured: World 1 60%, full run 20%, Loop 71 s, Deadlock 106 s.
- **The bot is not a human.** It aims perfectly (auto-aim), **never dashes**, and sidesteps only the bullet it predicts will hit within 0.4 s (`world.gd:1782-1850`). People dash through bullets with i-frames, learn patterns, and walk in curves. Friends called the game easy while the bot was at 60%, so **the bot's survival rate is roughly a floor for a new human, not a target for one (inference).**

## 2. What the research says

### Starting HP and what a hit costs elsewhere
| Game | Start HP | Early hit | Late |
|---|---|---|---|
| Hades | 50 [1] | Wringer 5 (10%), Wretched Thug 10 (20%) [2] | Bone Hydra slam 16 (32% of base) [3]; Hard Labor adds up to +100% enemy damage [4] |
| Enter the Gungeon | 3 hearts, 6 hits [6] | every hit is half a heart (17%) | Jammed enemies hit for a full heart (33%) [7]; enemy HP ×1 to ×2.1 by the last floor [9] |
| Binding of Isaac | 3 red hearts [12] | half a heart (17%) in chapters 1-3 | a full heart (33%) from chapter 4 [12] |
| Brotato | 10 max HP [13] | Baby Alien 1 (10%) | +0.6 damage per wave, so 12.4 by wave 20 [14] (inference: the arithmetic) |
| Soul Knight | Knight: 6 HP + 5 armour [15] | Dire Boar 3 (27% of 11) [15] | armour refills 1 per second after 3 s unhurt [15] |
| Noita | 100 [16] | | late attacks can exceed 100 HP [16] |
| Magicraft | 60 (`magicraft-progression.md`) | | |
| **Wandcraft now** | **140** | **3-6%** | **about 3% (damage never scales)** |

- **Rule of thumb (inference from the table):** comparable games make one early mistake cost about 10-20% of starting HP, and the cost rises later (Isaac and Gungeon double it, Risk of Rain 2 adds 20% damage per enemy level [17]). Wandcraft charges 3-6% and falls.
- Hades starts at 50 but has no room-by-room healing by default; it heals at a fountain after each boss, via shop food, or via Mirror talents of 1-3 HP per chamber [1].

### Healing is the quiet difficulty lever
- **Dead Cells' difficulty ladder is mostly healing.** Boss Cell 1 halves the health fountains between biomes, 2 removes them (one flask charge each instead), 3 leaves two charges all run, and 4 none; it also turns up enemy aggression (detection range, teleporting to you) [18]. The flask itself heals 60% [19].
- **Hades** makes healing a Pact tier (Lasting Consequences, -25% healing per rank) [4].
- **Noita** heals almost only at the Holy Mountain between levels [16]; **Gungeon** heals only through heart drops, shop hearts and stored hearts [8].
- **Risk of Rain 2** shipped a 2.5× regen boost meant for its easy mode to every difficulty "since launch" before fixing it [17]: a hidden sustain source can soften a whole game.

### Harder without bullet sponges
- **Aim ahead.** Gungeon's Veteran Bullet Kin have the same 15 HP as the basic kind but fire faster, run faster, and "predict the movements of their targets" [10]. In DOOM (2016), higher difficulties make "demon accuracy compensating for player movement faster" [20].
- **Aggression through budgets, not HP.** DOOM gives each attack type a limited number of attack tokens, and "each difficulty level has a different set of token counts" [20][21]. The result is more pressure that still reads as fair.
- **Rules over HP.** Hades' Pact tiers are mostly rules: +20% damage per rank (up to +100%), +20% more enemies per rank, +20% move and attack speed, bosses gaining new techniques. The HP tier is capped at +30% [4]. Its Extreme Measures Furies fight together, with a support sister adding attacks [5].
- **Jammed enemies** in Gungeon: 50% faster movement and fire, 33% shorter cooldowns, and a full heart per hit [7].
- **Mixes.** "Different combinations of enemy types should create different situations," and ranged enemies make the room's layout matter (The Level Design Book, citing Mike Stout's GDC 2012 talk) [22].
- **Build patterns around the dodge.** A Gungeon developer: "literally every attack in the game was built with it in mind" [11]. Dave Crooks names the procedural dungeon's first challenge as making it "fun but fair" [23].
- Players hate difficulty that only adds HP (Magicraft's Nightmare, `magicraft-progression.md` §5).

### How often players should win
- **Steam global achievement rates**, read 27 Sep 2026 [24]:
  - Hades: 81.9% of owners cleared Tartarus, and 46.8% ever escaped.
  - Enter the Gungeon: 21.0% beat the fifth floor.
  - Dead Cells: 40.3% beat the Hand of the King.
- **Hades' first escape** took about 20 attempts in a Steam thread of self-reports, with a range of 7-60 [25].
- **(inference)** A 25-minute mobile run should reach its first win sooner, in about 5-10 runs, and its first World 1 clear in runs 2-4. Five friends found it easy on their first runs, which suggests most were clearing World 1 at once.

### Mobile
- Touch sticks lack tactile feedback, make fine control hard, and a thumb landing inside the stick zone makes you move by accident (McAllister, 2011) [26]. **(inference)** Keep precise dodging generous: readable telegraphs, i-frames after a hit, and difficulty from density and aim rather than from tiny gaps or very fast shots.
- Mobile hits get design help rather than more HP. Archero ties shooting to standing still, so every volley is a choice between moving and firing [27]. Soul Knight's armour refills between fights [15].
- Wandcraft already has the safety valve Hades uses: God Mode starts at 20% resistance and adds 2% per death, up to 80% [5]. Wandcraft's Gentle mode does 2% per lost run up to 40%. That lets the base game get harder without locking anyone out.

## 3. Recommendations, ranked

Do 1-3 together as one "difficulty pass", bench it, then 4-6. The combined target is that one mistake costs about 6-10% of your HP all run long (12-16 mistakes from full), and a world gives back about 80% of your max HP in healing instead of 100%+.

### 1. Lower the start HP: yes, to 80
| Knob | Now | Proposed |
|---|---|---|
| `RunState` base max HP (`run_state.gd:21-22,81`) | 120 | **80** |
| Apprentice bonus (`run_state.gd:50`) | +20 (140) | +20 (**100**); the twist now reads as a real 25% |
| Pyromancer, Tinkerer | 120 | 80 |

- **Expected effect:** bullet mistakes to die for the Apprentice drop from 29 to 21 with no other change. The flat bonuses (heart room +15, World bonus +10, Vital Patch +20, Glitch toll -10) become about 50% more meaningful.
- **Keep the first rooms fair:**
  - Rooms 1-2 are already pressure only, with no anchor in the first wave (`encounter.gd:66`).
  - Rooms 1-2 enemies deal 3-8, which is 3-8% of 100.
  - Do not add any of recommendation 4 before the Grove.

### 2. Make a mistake cost more, and more as you go deeper
| Knob | Now | Proposed |
|---|---|---|
| Enemy bullet share of `dmg` (`enemy.gd:691`) | 0.6 | **0.75** (Weaver bullet 4.8 to 6) |
| Boss bullet `ed()` (`boss.gd:203`) | 6 | **8**; ×1.3 in World 2 |
| Enemy damage by depth (`Enemy.setup`, passed from `world.gd:595`) | none | **dmg × (1 + 0.03 × depth)**: ×1.03 in room 1, ×1.3 at the Loop, ×1.6 at the end of World 2 |

- **Expected effect** (Apprentice): a Weaver bullet costs 6% early, about 7% at the Loop (7.8 of about 115 HP) and about 8% late in World 2 (9.6 of about 125). That steady 6-10% band is Hades' low end, gentler than Gungeon's 17%, which suits touch controls.
- This mirrors Isaac, Brotato and Risk of Rain 2, where damage rises across the run [12][14][17].

### 3. Tighten healing between rooms
| Knob | Now | Proposed |
|---|---|---|
| Room-clear heal (`world.gd:654`) | 6 | **3** |
| Spring (`world.gd:914`) | 60% (40% at heat 4+) | **50%** (30% at heat 4+) |
| Shop heal (`rewards.gd:202`) | 35 for 25 gold | **30 for 30 gold** |
| Debug Terminal heal (`rewards.gd:173`) | 35 | **30** |
| After a boss (`world.gd:669`) | full heal | keep: this is Hades' post-boss fountain [1] |
| Entering World 2 (`world.gd:784`) | a second full heal, +10 max | keep the +10 max; the heal is redundant after the boss's |
| Max HP room (`world.gd:693`) | +15, heal 15 | keep: now 15% of max, a real choice |

- **Expected effect:** the healing from one world's rooms plus one spring drops from about 144 HP (103% of 140) to about 80 (80% of 100). HP becomes a resource you carry through a world, as in Dead Cells [18], instead of refilling every room.
- Taking the spring before a boss becomes a real choice against the shop.

### 4. Enemies that aim, shoot faster and move on
- **Aim ahead** (World 1 from the Grove, `step >= 6`, and all of World 2):
  - Weaver, Rot Weaver and Rune Sentry aim at `player.position + player.vel × t × 0.5`, where t is the bullet's travel time. The enemy code already has `predict()` for the player's own aim-ahead (`enemy.gd:235`).
  - Half a lead, not a full one: changing direction still dodges it, while walking in a straight line no longer does **(inference)**. This is the Veteran Bullet Kin and DOOM approach [10][20].
- **Faster shots:**

  | Knob | Now | Proposed |
  |---|---|---|
  | Weaver shot speed (`enemy.gd:11`) | 85 | 100 |
  | Puffcap ring (`enemy.gd:17`) | 62 | 75 |
  | Loop ring start speed (`boss_loop.gd:254`) | 45 | 60 |

  Keep aimed shots at 130 px/s or below on mobile **(inference)**; heat 3's +15% stacks on top.
- **Faster cadence:**

  | Knob | Now | Proposed |
  |---|---|---|
  | Weaver `cd` | 2.8 | 2.3 |
  | Rot Weaver `cd` | 3.0 | 2.5 |
  | Sentry `bcd` | 2.6 | 2.1 |
  | Puffcap `cd` | 3.0 | 2.6 |
  | Charger rest after a dash (`enemy.gd:427`) | 1.2-2.2 s | 0.9-1.7 s |

- **Telegraphs:** leave every telegraph as it is in World 1. In World 2, shorten shooter and charger telegraphs by 15%, as bosses already do after phase 1. The shortest, the Bugling's 0.3 s, stays; it hits for 3.

### 5. Waves that overlap and combine
| Knob | Now | Proposed |
|---|---|---|
| Next wave at (`encounter.gd:22`) | 70% down | **50% down** |
| Second anchor chance from room 3 (`encounter.gd:66`) | 40% | **60%** |

- **Expected effect:** the second wave's anchor arrives while the first wave's pressure is still chasing you, which is the combination principle [22]. The room doesn't get longer; it gets denser.
- **Later, if needed:** a DOOM-style cap of three enemies winding up at once [20]. That lets density rise without an unreadable spike.

### 6. Bosses: pressure, not HP
- **Freeze the HP.** Don't raise the Loop's or Deadlock's 1800 any further. Deadlock is already 106 s on the bench; if it stays over 90 s after this pass, cut it to 1500. The final boss should test a build, not wipe it (`magicraft-progression.md` lesson 5).
- **Last phase only:**

  | Knob | Now | Proposed |
  |---|---|---|
  | Telegraph (`boss.gd:136`) | ×0.85 | ×0.7 |
  | Recovery (`boss.gd:113`) | ×0.8 | ×0.6 |
  | Aimed fans (`boss.gd` `aimed()`) | at your position | half-lead the centre shot |

- **One overlapping pair per boss in the last phase** (Hades' Extreme Measures idea [4][5]):
  - The Loop: fire `tail_volley` rings during `chase`.
  - Deadlock: Mutex B fires a `volley` during `crossfire`.
  - Copy-Paste: `paste` with a bugling pair.
- **Boss damage:** bullets 8 per recommendation 2; contact stays at 12. Mini-boss adds: two buglings or slimes when phase 2 starts, if the first bench shows minis under 40 s.

### 7. Heat: rules, not HP
| Tier | Now | Proposed |
|---|---|---|
| Heat 2 (`meta.gd:76`, `world.gd:595`) | +20% enemy HP | **+20% enemy damage** (Hades' Hard Labor [4]) |
| Heat 5 (`meta.gd:79`, `world.gd:625`) | bosses +25% HP | **bosses use their last-phase rules from phase 2, and every telegraph is 15% shorter** (Extreme Measures [4]) |

- Heat stays the optional hard mode. The base-game changes above are what fix "too easy".

### 8. Mobile guardrails (keep these as they are)
- The 0.9 s of invulnerability after a hit, and the 0.14 s of dash i-frames.
- The spawn rune (0.8-1.0 s), 96 px spawn distance and aim-cone exclusion (`encounter.gd:25-26`).
- Gentle mode. Consider starting it at 10% instead of 0% so the base game can be harder while struggling players still get a hand at once [5].

## 4. How to verify

### Bench targets (re-band `test_balance.gd`)
The bot takes hits a human would dash through, so every damage and healing change hits the bot harder than a person **(inference)**. Humans found the game easy at 60%, so lower the bot's band rather than keep it:

| Measure | Band now | New band |
|---|---|---|
| Editing bot, World 1 cleared | 40-85% (was 60%) | **25-45%** |
| Editing bot, full run won | reported (was 20%) | **5-15%** |
| Never-editing bot, World 1 | reported | **0-10%** |
| Mini-boss | 20-90 s | **30-75 s** |
| The Loop | 30-150 s (was 71 s) | **50-90 s** |
| Deadlock | reported (was 106 s) | **60-100 s** |

- **Add to the bench's printout:** hits taken per room (a count, not HP) and "mistakes to die" (max HP / mean hit). The target is 12-16 in World 1 and 9-14 in World 2.
- **Recommended new bot** (a tools change; not made here): a "dasher" bot that dashes when its danger score passes a threshold, as a stand-in for a practised human. Its band: World 1 cleared 55-75%, full run 25-40%. The gap between the two bots shows that skill matters, which is what testers are missing.
- **Order:** bench after recommendations 1-3, then after 4-5, then after 6. If the editing bot drops below 25% after 1-3 alone, restore the room heal to 4 before touching anything else.

### Human targets (playtest round 2, run logs from `window.wandcraftRunLog()`)
- **First run:** most testers (3 of 5 or more) die in World 1, at the Grove or the Loop.
- **World 1** is cleared by run 2-4; the first full win comes in runs 5-10 (Hades players need about 20 [25], but runs there are longer).
- **Deaths spread out:** no single room causes more than a third of them. The run log's `by` sources should show several killers, not only the boss.
- **Ask one question:** "Did you ever feel close to dying before the boss?" A yes from most testers is the goal; 0.16 got a no.

## Sources
- [1] Hades Wiki (Fandom), "Health", read 27 Sep 2026: https://hades.fandom.com/wiki/Health
- [2] Hades Wiki, "Wretched Thug" and "Wringer": https://hades.fandom.com/wiki/Wretched_Thug , https://hades.fandom.com/wiki/Wringer
- [3] Hades Wiki, "Bone Hydra": https://hades.fandom.com/wiki/Bone_Hydra
- [4] Hades Wiki, "Pact of Punishment": https://hades.fandom.com/wiki/Pact_of_Punishment
- [5] Hades Wiki, "God Mode" (citing Supergiant Games on X, 25 Sep 2020) and "Furies" (Extreme Measures): https://hades.fandom.com/wiki/God_Mode , https://hades.fandom.com/wiki/Furies
- [6] Official Enter the Gungeon Wiki, "Health": https://enterthegungeon.wiki.gg/wiki/Health
- [7] Enter the Gungeon Wiki (Fandom), "Curse": https://enterthegungeon.fandom.com/wiki/Curse
- [8] Enter the Gungeon Wiki, "Pickups": https://enterthegungeon.fandom.com/wiki/Pickups
- [9] Enter the Gungeon Wiki, "Cult of the Gundead" (health scaling): https://enterthegungeon.fandom.com/wiki/Cult_of_the_Gundead
- [10] Enter the Gungeon Wiki, "Bullet Kin" (Veteran Bullet Kin): https://enterthegungeon.fandom.com/wiki/Bullet_Kin
- [11] Rubel (Dodge Roll, developer tag), Steam discussion "A Liability: The Dodge Roll", comment dated 29 Jan 2017: https://steamcommunity.com/app/311690/discussions/0/135507548123621376/
- [12] Binding of Isaac: Rebirth Wiki (Fandom), "Health" and "Isaac": https://bindingofisaacrebirth.fandom.com/wiki/Health , https://bindingofisaacrebirth.fandom.com/wiki/Isaac
- [13] Brotato Wiki, "Max HP": https://brotato.wiki.spellsandguns.com/Max_HP
- [14] Brotato Wiki, "Enemies": https://brotato.wiki.spellsandguns.com/Enemies
- [15] Soul Knight Wiki (Fandom), "Knight", "Armor", "Dire Boar": https://soul-knight.fandom.com/wiki/Knight , https://soul-knight.fandom.com/wiki/Armor , https://soul-knight.fandom.com/wiki/Dire_Boar
- [16] Noita Wiki (Fandom), "Health": https://noita.fandom.com/wiki/Health
- [17] Risk of Rain 2 Wiki (Fandom), "Difficulty" (including patch notes): https://riskofrain2.fandom.com/wiki/Difficulty
- [18] Dead Cells Wiki (Fandom), "Boss Stem Cell": https://deadcells.fandom.com/wiki/Boss_Stem_Cell
- [19] Dead Cells Wiki, "Health Flask" and "Stats": https://deadcells.fandom.com/wiki/Health_Flask , https://deadcells.fandom.com/wiki/Stats
- [20] Tommy Thompson, "Cyber Demons: The AI of DOOM (2016)", Game Developer, 6 Aug 2018: https://www.gamedeveloper.com/design/cyber-demons-the-ai-of-doom-2016-
- [21] Kurt Loudy and Jake Campbell (id Software), "Embracing Push Forward Combat in DOOM", GDC 2018: https://www.gdcvault.com/play/1024940/Embracing-Push-Forward-Combat-in
- [22] The Level Design Book, "Enemy design" (quoting Mike Stout, GDC 2012): https://book.leveldesignbook.com/process/combat/enemy
- [23] Tim W., "Q&A: The guns and dungeons of Enter the Gungeon" (Dave Crooks), Game Developer, 19 Apr 2016: https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-
- [24] Steam Web API, GetGlobalAchievementPercentagesForApp, read 27 Sep 2026 (Hades 1145360: AchClearTartarus, AchClearAnyRun; Enter the Gungeon 311690: BEAT_FLOOR_FIVE; Dead Cells 588650: FIGHT_BEAT_KINGSHAND): https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v0002/?gameid=1145360
- [25] Steam discussion, Hades, "How many attempts did it take you to escape?", 30 Dec 2019: https://steamcommunity.com/app/1145360/discussions/0/2632850028529196918/
- [26] Graham McAllister, "A Guide To iOS Twin Stick Shooter Usability", Game Developer, 30 Mar 2011: https://www.gamedeveloper.com/design/a-guide-to-ios-twin-stick-shooter-usability
- [27] Scott Fine, "Finding the Fun: Archero Part 1 - Gameplay", 2 Jul 2019: http://scottfinegamedesign.com/design-blog/2019/7/2/archero-part-1-gameplay

## Results (bench log)
| Pass | Commit | Editing bot: World 1 / full run | Never-editing | Mini / Loop / Deadlock |
|---|---|---|---|---|
| Before (0.17.1) | `ec7250d` | 60% / 20% | 0% | 42 s / 71 s / 106 s |
| 1: HP, hit cost, healing | this pass | 40% / 10% | 0% | 28 s / 67 s / 98 s |
| 2: aim ahead, faster shots, overlapping waves | this pass | 40% / 10% | 0% | 32 s / 69 s / 84 s |
