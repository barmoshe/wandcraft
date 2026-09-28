# Roguelikes and roguelites, 2024–2026: what's new and what works

Research for Wandcraft World 3, `kernel()`. We take mechanics only. No names, text, numbers or art from any game below go into Wandcraft (see `decisions/0002`). Sources are numbered and listed at the end. **[I]** marks my own inference, not a sourced claim.

Research date: 2026-09-28. Some sites (Wikipedia, PCGamesN, the wiki.gg wikis) were blocked for direct fetching, so several claims rest on search-result excerpts from those pages. The URLs are still listed so they can be checked by hand.

---

## 1. The landscape in one paragraph

The period is framed by three giant launches and a wave of small, systemic hits. The giants are **Hades II** (1.0 in 2025), **Slay the Spire 2** (Early Access on 2026-03-05, the year's biggest roguelike launch) [1][30] and **Mewgenics** (February 2026, over a million copies in its first week) [29]. The small hits are **Balatro** (solo developer, 2M+ sold within six months, then a premium mobile port) [12][13], **Megabonk** (solo developer, runs of about 10 minutes, September 2025) [14], **Ball x Pit** (brick-breaker × bullet-heaven × base-builder) [15] and **Blue Prince** (a roguelike puzzle game, Metacritic 92) [30]. **Enter the Gungeon 2** was announced for 2026 with a move to 3D and the same dodge-roll core [23]. **Dead Cells** shipped its final content update, which also reached iOS and Android in February 2025 [18]. **Windblown** is heading for 1.0 in 2026 [17], and **Risk of Rain 2** added its third expansion in November 2025 [26]. The pattern [I]: the hits either have **one legible multiplicative system** that players learn to break (Balatro's chips × mult, Ball x Pit's fusions, Magicraft's left-to-right wand slots), or they have **structure that keeps changing its own rules** (Hades II's two routes, StS2's alternate acts, Inscryption's genre shifts).

---

## 2. Run structure and world variety: later worlds that feel *different*, not only harder

**Change the room grammar and the enemies together.** Hades II's biomes do more than swap enemies:
- Erebus and Oceanus use classic single-encounter rooms.
- The **Fields of Mourning** drops the room boundary. Each large area holds several sealed encounters, each showing its reward, and the player chooses the order [8].
- **Ephyra**, on the surface route, is a town hub with many doors, and only about half of them must be cleared [8].

The same player verbs meet a different decision structure each act. **[I]** This is the most transferable lesson for Wandcraft: World 3 should change *how rooms connect and resolve*, not just the palette and HP numbers.

**Alternate versions of an act.** Slay the Spire 2 gives each act two versions with different environments, enemies, events and bosses, and one is picked at random on entry [2]. Mega Crit slowed its patch cadence in August 2026 to build a second Act 2 alternate [3]. **[I]** This is the cheap way to double variety late in development: an A/B version of each world, each built around its own rule.

**Act-entry choices that restrict you.** StS2 replaced boss relics with **Ancients**, which offer three boons at the start of each act that the player cannot skip. The Act 3 pool includes deals like "more energy, but a cap on cards per turn" [4]. StS2 also adds **Enchantments** (a permanent buff on one card), **Afflictions** (their negative twin) and **Quest cards**. A quest card clogs your deck until you meet its condition, then pays out [5]. All three edit the build itself, not just the fights.

**The rules change in the final encounter.** Balatro's last ante draws from a separate pool of "finisher" boss blinds, harsher rule-breakers than the normal bosses [12]. The last test is a *rule* you must adapt to, not a bigger number.

**Genre and presentation shifts.** Inscryption's three acts are a card roguelike, then an escape-room puzzle, then a different game again, each with its own art style [20]. Blue Prince uses roguelike drafting to deliver a puzzle-mystery [30]. Returnal's six biomes are each a metaphor for a stage of the protagonist's trauma, and Act 3 reframes the earlier acts [27]. **[I]** For Wandcraft, the kernel can shift *presentation* (terminal-green overlays, visible scheduler UI) without shifting genre. Twin-stick is the contract with the player.

**Short-form structures.** Megabonk runs about 10 minutes. Each tier adds a stage by opening a portal after the previous boss, and a **Final Swarm** of escalating enemies starts at the timer's end [14]. The developers later changed the Final Swarm to stop 5-hour farming runs [14]. Brotato fixes the run at 20 waves: the first wave lasts 20 seconds and each later wave adds 5 seconds up to a 60-second cap, so a run takes about 15–20 minutes [24]. Ball x Pit splits each stage into segments that end in mini-bosses, then a final boss. Its eight stages are separate "levels" you clear with each character, not one long descent [15].

---

## 3. Final worlds and final bosses, especially ones that use the player's build

This is the richest vein for the "the bug was your first commit" twist.

| Game | Mechanic | What it does to the player's build |
|---|---|---|
| **Risk of Rain 2**, final boss's last phase | The boss becomes invulnerable and **steals every item you carry**, then fights *with* them. You fight your own build [26]. | Takes it and turns it against you |
| **Loop Hero**, final boss | It destroys cards and items at the start. Every few attacks it **erases one equipped item and one stat** in a fixed order [21]. | Deletes it piece by piece |
| **Inscryption** | "Death cards" the player made in earlier runs come back as enemy cards in Act 3 [20]. | Uses your past creations against you |
| **Hades II**, Underworld final boss | At zero HP it **rewinds its own defeat** and resets in a new clock-face arena. **Time-manipulation hexes don't work on it**, because the boss *is* time [9]. | Makes one tool useless on thematic grounds |
| **Hades II**, surface final boss | It is not on the stage. It floats beside it and attacks the arena, with another boss joining mid-fight [10]. | Changes the arena, not the build |
| **Mirrorbound** (open-source experiment) | A companion learns a statistical model of how you play (range, aggression, retreat threshold). The final boss uses that model against you [31]. | Reads how you play |
| **Balatro**, finisher blinds | The final ante's boss applies a harsher rule mutation [12]. | Changes the rules around it |

**What players say.** The Risk of Rain 2 community argues that stealing is unfair and asks for the boss to *copy* loot instead [26]. **[I]** Taking a build away feels like punishment. Mirroring it feels like a test. For Wandcraft the better emotional fit is *confronting* your own code, not losing it.

**Magicraft**, the closest mechanical cousin, has been criticised for its final levels. Reviews call them "hectic", with too many particles and animations to keep track of your character [16]. **[I]** On a 6-inch screen at 480×270 this risk is multiplied. World 3's visual noise budget should be *lower* than World 2's, not higher.

---

## 4. How a third act raises stakes

- **Something permanent carries across deaths.** Returnal's Act 3 is a hunt for one fragment per biome, and the fragments persist through deaths [27]. The third act becomes a campaign layered on top of runs.
- **A two-part ending.** Hades II's true ending needs a clear of **both** routes, with materials from each final boss feeding a ritual [6]. Supergiant reworked the true ending during development so that players who had already seen credits had to beat the final bosses again [7].
- **Restrictions arrive.** StS2's Act 3 Ancients offer the strongest and most restrictive deals [4]. Dead Cells' final update reworked Curse from "die in one hit" to "survive the effect and get a big reward for the rest of the run" [18]. That is a stake the player opts into.
- **Reframe earlier content.** Returnal and Inscryption both use the last act to recontextualise the first [20][27]. **[I]** Wandcraft's "you wrote the bug" twist is exactly this move. It lands hardest if Worlds 1–2 plant evidence the player can reread: enemy behaviours that echo the tutorial, lore scraps with the player's own timestamps.

---

## 5. Meta progression that isn't power creep

- **Horizontal over vertical.** Current design writing says unlocks should *change behaviour*, not add stats. Dead Cells is the classic case: a blueprint adds a weapon to the drop pool rather than making you stronger [33].
- **A capacity budget.** Hades II's Arcana cards cost Grasp. The full set costs far more than your cap, so every run uses a focused loadout, and raising the cap is the slow meta grind [11]. **[I]** A budgeted loadout turns meta progression into a build decision rather than a flat power boost.
- **Difficulty as a menu.** Hades II's Oath of the Unseen offers 16 vows ranked into a Fear total, and bosses show the Fear needed for their challenge [11]. Nova Drift's **Wild Metamorphosis** challenge mode adds stackable "wild mods" with big upsides and downsides and randomises bosses. Reviewers treat it as an expansion rather than a difficulty setting [28].
- **Separate campaigns.** Vampire Survivors' Adventures are standalone campaigns with their own progression, restricted rosters and custom win conditions. Only relics carry over [25].
- **Hub and base building.** Ball x Pit rebuilds a town from blueprints earned by replaying stages with new characters. Stat buildings upgrade without limit, which pushes late scaling into the hub [15]. Cult of the Lamb's Woolhaven expansion (January 2026) added survival pressure to the base: cold, and a ranch [19].
- **Lineage.** Mewgenics' cats retire after a run, and their offspring inherit stats and mutations. The meta *is* a family tree [29].

---

## 6. Run length and session design on mobile

- **Short, fixed, self-contained runs win on phones.** Brotato's 15–20-minute runs with a clear finish and an optional endless mode are cited as ideal for "a commute or a break". The mobile version has all content behind a single premium unlock [24]. Balatro went to mobile as a premium app at a flat price, plus a subscription-service version [13]. Megabonk's ~10-minute run is the new benchmark for "one more run" [14].
- **Long runs need a suspend feature.** Returnal's runs could last 2–3 hours, and the missing mid-run save was its loudest complaint until a patch added a suspend feature (not allowed in boss fights or combat) [27]. Mewgenics' 2–3-hour runs work on PC but would be a mobile risk [29].
- **Time as pressure.** Risk of Rain 2's difficulty rises with elapsed time [26], and Megabonk's Final Swarm pressures the end of each stage [14]. **[I]** On phones, a clock that punishes idling fights with interruptions (notifications, calls). Pressure should be per-room, not per-run.
- **[I] Wandcraft target.** Eleven rooms per world at 30–60 seconds each, plus the bosses, comes to about 8–10 minutes per world and about 30 minutes for a three-world run. Auto-save at every room exit so any interruption costs at most one room. Wand editing should pause the sim, as it already does between rooms.

---

## 7. Keeping players curious after the first win

- **True endings with a visible shape.** Hades II requires both routes [6]. Spelunky 2 hides a third ending behind a chain of secrets and a 90+ level challenge area, hinted in the hub by a telescope [32]. Noita scales five endings on how many orbs you carry and where you finish. It also uses New Game+ and parallel worlds, and some secrets deliberately troll the players hunting them [22].
- **Alternate versions and remixes.** StS2's alternate acts [2], Nova Drift's Wild Metamorphosis [28] and Vampire Survivors' Adventures [25] each add a *rule set*, not just content.
- **Content that uses the player's own history.** Inscryption's death cards [20] and Megabonk's ghost-themed swarm unlocks [14] reuse the player's past. **[I]** Player-history content is the cheapest "new content" there is, and it is unique to each player.
- **A growing unlock list.** Megabonk has 200+ quests driving unlocks [14]. Magicraft uses curses and six difficulty tiers [16].

---

## 8. Takeaways for `kernel()` [I]

1. Change the **room grammar** in World 3, as Hades II's Fields and Ephyra do. Harder enemies alone won't make it feel new.
2. The final boss should **mirror, not steal**. Players resent losing a build and love beating a copy of it.
3. Give World 3 a **lower visual-noise budget** than World 2. Magicraft's late-game clutter is a warning.
4. Let World 3's enemies **edit the wand program**, as StS2's afflictions and quest cards do, so the code-magic theme becomes the threat.
5. Build the post-win loop as **rule remixes plus a true ending whose length the player can see**.
6. Mobile: **one room is the unit of loss**. Save at every room exit, and keep a full run around 30 minutes.

---

## 5+ original ideas for Wandcraft

Each idea goes beyond what the sources did, and each is tied to "magic is code". Cost: **S** is days, **M** is 1–2 weeks and **L** is 3+ weeks for one developer in a Godot project drawn in code with a headless sim.

### 1. World 3 structure: the Scheduler (time-sliced twin arenas)
**The idea.** Each kernel room is really **two processes** sharing one screen slot. A thin scheduler bar at the top counts down a time slice of a few seconds. When it expires, the room **context-switches**: process A freezes mid-frame (enemies and projectiles stop in place, dimmed) and process B's layout and enemies swap in. Your projectiles in flight are **saved with their process**, and they resume when that process gets the CPU back. You clear a room by clearing both processes. Later rooms add a third process, or a "priority inversion" where one process holds the slice until you kill a marked enemy.
**Why it's fun.** It's a new *room grammar*, not new HP numbers. Delayed spells, traps and on-timer triggers become strong because you can seed process A, switch away, and come back to a detonation. It rewards planning with the wand as code (setting up state that runs later), which Worlds 1–2 never ask for. Hades II changes room grammar per region, but nothing we found freezes one fight to play another and then resumes it.
**Build cost: M.** The sim is already node-free and deterministic. Two sim states per room, one ticked at a time, plus a swap transition. The hard part is readability (dim the frozen layer, tint the two sides differently).
**Phone-friendliness: high.** The switch is on a timer and the player does nothing to trigger it. The countdown bar is glanceable. Keep slices at 5 seconds or more so it never feels like flicker.

### 2. Kernel enemies that edit your wand: syscall parasites
**The idea.** World 3's common enemies attack **the wand program**, not only your HP. Each effect is temporary, shown in the wand HUD as a coloured overlay on the affected slot, and ends when you kill the source.
- **Interrupt:** its hit inserts a no-op slot at the front of your wand, so your cast rhythm stutters.
- **Mutex:** locks one slot. That spell is skipped until you kill the Mutex, which is tethered visibly to the slot icon.
- **Null Pointer:** marks your *empty* slots. Casting through an empty slot while marked spawns a small hazard at your feet.
- **Deprecation Warning:** paints one boost amber. The boost still works, but it now modifies spells to its *left*.
**Why it's fun.** It makes the language itself the battlefield, and turns "boosts modify everything to their right" into something the enemy can mess with. Players learn their wand more deeply by watching it get broken and repaired. Loop Hero's final boss erases items permanently and only at the end of the game [21]. Here the edits are temporary, reversible, spread across ordinary enemies and readable in the HUD.
**Build cost: M.** The wand evaluator needs a thin "patch layer" of overrides applied before evaluation. Each enemy is a normal AI plus one patch type, so four of them are small once the layer exists. Needs tests in the headless sim.
**Phone-friendliness: medium-high.** The HUD overlay must be big and colour-coded, since there's no time to read text mid-fight. Cap it at two active patches.

### 3. Regression tests: enemies that replay you
**The idea.** During World 1 of *this* run the sim quietly records a coarse trace of the player: position about 10 times a second and each cast. In the kernel, **Regression Test** enemies are translucent copies that replay a 6–8-second slice of that trace, including casting **the wand you had at that moment**. Kill it before its replay ends and it "passes" and drops Bits. Let it finish and it "fails", spawning a bug. A later variant replays World 2.
**Why it's fun.** You are literally fighting your own earlier code, which builds toward the final-boss reveal. It also has comic timing: your old habits, like strafing left at the start of a fight, become enemy patterns you now have to read. Inscryption brought back death cards from *past* runs [20]. Replaying a trace from *earlier in the same run* keeps it fresh every run and makes the story point (the bug is you) felt, not told.
**Build cost: S–M.** The deterministic sim makes recording almost free (a ring buffer of small structs). Replay is a scripted mover plus the existing spell caster. The risk is balance, because early wands are weak, so scale the copy's damage by world.
**Phone-friendliness: high.** No new controls. It's just another enemy with a clear timer ring.

### 4. Mini-boss: Race Condition
**The idea.** A two-bodied mini-boss, drawn as two halves of one glyph that split apart. Each half shares one HP bar, and **both must reach zero within half a second of each other**. If one dies alone it respawns at full health after a moment, taunting with a "data corrupted" flash. The halves move apart, one orbiting and one charging, so you must set up the kill: bring both low, then time a split shot, a multi-cast or a trigger chain.
**Why it's fun.** It's a boss that tests your *program*, not your aim. A wand that fires two things at once, or a trigger that delays the second hit precisely, is the answer. That rewards Wandcraft's core mechanic in a way no damage check can. Balatro's finisher blinds are rule tests [12], but none of them demands *simultaneity*.
**Build cost: S.** Two instances with linked HP and a death-window check. Add a telegraph so players can see both are low (a shared "sync meter").
**Phone-friendliness: high.** Needs one legible meter. The window can widen on easier difficulty tiers.

### 5. Final boss: Commit 0001 (the bug you wrote)
**The idea.** From the tutorial onward, the save keeps a **git-log of the player's wands**: the first wand ever saved (commit 0001, stamped with the real install date), plus the wand held at each world exit across runs. The final boss, drawn as a glitching copy of the player's sprite, fights in phases that walk the log **backwards**:
- **Phase 1: HEAD.** It casts the player's *current* wand, mirrored rather than stolen, so the player keeps theirs.
- **Phase 2: last world's wand.**
- **Phase 3: commit 0001.** It casts the tiny, naive first wand, but amplified and looping forever. That is the original bug: a program with no end condition, which is what corrupted the Source.

In every phase the boss's **wand is shown as orbiting slot icons**. Shooting a slot icon **deletes that spell from the boss's program**, so you can debug it down to a no-op instead of just draining HP. The fight ends not on a kill but on a choice. The player edits commit 0001 in the normal wand editor, adding the missing end condition (a "return" rune), and then plays the fix.
**Why it's fun.** It pays off the whole theme. The tutorial wand, which players forget about, comes back as the final threat and carries their real install date. Deleting the boss's slots uses what they learned about slot order. Unlike the stolen build in Risk of Rain 2 [26] or the erasures in Loop Hero [21], the player *edits the enemy's code* and keeps their own. Mirroring avoids the "unfair" feeling players report when a boss takes their build.
**Build cost: L.** Needed: wand history in the save (small); boss AI that casts an arbitrary wand through the existing caster (medium); slot-icon weak points bound to the boss's program (medium); and the ending editor sequence (medium). The deterministic sim makes it testable. Balancing arbitrary player wands needs damage clamps per phase.
**Phone-friendliness: medium.** Slot icons need big hitboxes and a gentle aim-assist toward them. Phase changes are natural save points, so allow a suspend between phases (Returnal lesson [27]).

### 6. Post-win: `git bisect`, a true ending you can see coming
**The idea.** After the first win, a bisect terminal appears in the Workshop. The corrupted Source has a set of suspect commits, each a **rule mutation** of the language:
- boosts apply leftward
- triggers fire twice
- the wand casts right to left
- the mana pool is shared with enemies

Each bisect run plays one mutated build of the whole game. Finish it and you mark that half "good". Die and you mark it "bad". The search halves every time, so the true ending, which finds the exact bad line and shows the "real" first commit, arrives in a **known, visible number of runs** (about five or six). New runs see new mutations.
**Why it's fun.** It's a remix mode and a true ending in one, with a progress shape players can read. That avoids both extremes: Hades II's true ending needs many clears of two routes [6], while Spelunky's is extreme and Noita's is cryptic [32][22]. Every bisect run is a genuinely different game because the *language* changed, not the numbers (the Nova Drift lesson [28]). And it teaches a real programming concept, which fits the brand.
**Build cost: M.** The mutations are flags in the wand evaluator and sim, each tested headless. Bisect state is a small save struct. Content is about 8 good mutations.
**Phone-friendliness: high.** Runs stay the normal length, and progress persists between sessions.

### 7. Meta progression as a changelog: language features, not stats
**The idea.** Bits in the Workshop buy **language features**, not damage:
- an `else` rune (a spell that casts only if the previous one missed)
- a loop counter (repeat the next spell N times, then skip)
- a comment slot (a free slot that holds a spell without casting it, to "stash" code)

Each feature ships with a **deprecation**. Unlocking it lets you optionally retire an older spell from the drop pool, like Balatro-style pool thinning, so the meta *reshapes* the pool rather than growing it forever. A capacity budget in the style of Hades II's Grasp [11] caps how many features a run can import.
**Why it's fun.** Every purchase changes how you write wands, which is the horizontal-progression ideal [33]. Retiring spells gives the player authorship over their "language version". The Workshop reads as a changelog, which is flavourful and cheap to present.
**Build cost: S–M.** Most features are new spell types in `catalog.gd` plus evaluator support. Deprecation is a pool filter. The UI is a list.
**Phone-friendliness: high.** It's a menu between runs.

### 8. The kernel stack trace as the map (optional, stacks with idea 1)
**The idea.** World 3's map is shown as a live **call stack**. Each cleared room pushes a frame line (`kernel() > sched() > irq_17()`). At any room exit you can **return early**: pop straight to the mini-boss or boss with fewer rewards but full HP. Or you can **recurse**: take a side frame that adds a harder room and a better reward, with the risk shown as stack depth. Too deep and the Kernel Panic (already in the bestiary) interrupts: an elite ambush, a literal "stack overflow".
**Why it's fun.** It turns the stack-trace fiction into a real risk and reward knob, and players choose their own run length. That suits a phone: a quick return for a bus ride, deep recursion at home.
**Build cost: S–M.** It reuses the room graph with a depth counter. The stack header is text drawn at the pixel base.
**Phone-friendliness: high.** Two big buttons at room exits: "return" and "recurse".

---

## Sources

1. Slay the Spire II, Wikipedia (release date, overview). https://en.wikipedia.org/wiki/Slay_the_Spire_II
2. Alternate Acts in Slay the Spire 2, sts2front. https://www.sts2front.com/mechanics/alternate-acts/ · also https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:Acts
3. "Slay the Spire 2 Pauses Patches: Sixth Character and Alternate Act 2 Are Next", TechTimes, 2026-08-15. https://www.techtimes.com/articles/324630/20260815/slay-spire-2-pauses-patches-sixth-character-alternate-act-2-are-next.htm
4. Slay the Spire 2 Ancients guide, Mobalytics. https://mobalytics.gg/slay-the-spire-2/guides/ancients · TheGamer list https://www.thegamer.com/slay-the-spire-2-ancients-blessings-offerings-list-guide/
5. StS2 new mechanics (enchantments, afflictions, quest cards). https://wiz.jock.pl/sts2/mechanics/ · https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:Enchantments
6. Hades 2 True Ending, Rogue Ranker. https://rogueranker.com/hades-2-true-ending/
7. "Hades 2 devs are changing the true ending…", GamesRadar+. https://www.gamesradar.com/games/hades/hades-2-devs-are-changing-the-true-ending-so-much-youre-going-to-have-to-beat-the-underworld-a-few-more-times-to-see-it-all/
8. Fields of Mourning, Hades 2 wiki (Fextralife). https://hades2.wiki.fextralife.com/Fields_of_Mourning · City of Ephyra https://hades.fandom.com/wiki/City_of_Ephyra
9. Chronos boss guide, Switchblade Gaming. https://www.switchbladegaming.com/hades-2/chronos-guide/ · https://rogueranker.com/chronos-hades-2/
10. Typhon/Combat, Hades Wiki. https://hades.fandom.com/wiki/Typhon/Combat
11. Hades 2 Arcana and Grasp, Rogue Ranker. https://rogueranker.com/hades-2-arcana/ · Oath of the Unseen and Fear, BrokenBuilds https://brokenbuilds.gg/hades-ii/guides/fear
12. Blinds and Antes, Balatro Wiki. https://balatrowiki.org/w/Blinds_and_Antes · Balatro feedback design https://blakecrosley.com/guides/design/balatro
13. Balatro mobile and Apple Arcade, TouchArcade. https://toucharcade.com/2024/09/05/balatro-mobile-release-date-price-download-apple-arcade/ · sales https://toucharcade.com/2024/08/07/balatro-2025-new-game-update-sales-mobile-port/
14. Megabonk progression and Final Swarm. https://megabonk.org/guides/progression/ · maps and tiers https://megabonk.org/guides/maps/ · https://en.wikipedia.org/wiki/Megabonk
15. Ball x Pit evolution and fusion. https://ballxpit.org/guides/evolution-guide/ · review https://www.nintendoworldreport.com/review/72918/ball-x-pit-switch-review · meta and base https://dood.gg/en/ball-x-pit/guides/meta · structure https://www.thegamer.com/ball-x-pit-complete-guide/
16. Magicraft spell mechanics (Steam guide). https://steamcommunity.com/sharedfiles/filedetails/?id=3477176826 · review https://legacyofgames.com/2025/01/22/magicraft/ · https://en.wikipedia.org/wiki/Magicraft
17. Windblown on Steam. https://store.steampowered.com/app/1911610/ · Break the Path update https://rogueliker.com/windblowns-break-the-path-update/
18. Dead Cells final update, PCGamesN. https://www.pcgamesn.com/dead-cells/update-final · Version 3.5 https://deadcells.wiki.gg/wiki/Version_3.5
19. Cult of the Lamb: Woolhaven review, TheSixthAxis. https://www.thesixthaxis.com/2026/01/26/cult-of-the-lamb-woolhaven-dlc-review/
20. Inscryption postmortem, Game Developer. https://www.gamedeveloper.com/marketing/-i-inscryption-s-i-journey-from-game-jam-joint-to-cult-classic · P03 / Act III https://inscryption.fandom.com/wiki/P03 · https://inscryption.fandom.com/wiki/Act_III
21. The Destroyer (Omega), Loop Hero Wiki. https://loophero.fandom.com/wiki/The_Destroyer
22. Endings, Noita Wiki. https://noita.wiki.gg/wiki/Endings
23. Enter the Gungeon 2 coming to Steam in 2026, Steam News. https://store.steampowered.com/news/app/311690/view/529842339955345340 · https://noisypixel.net/enter-the-gungeon-2-announced-switch-2-pc-2026/
24. Waves, Brotato Wiki. https://brotato.wiki.spellsandguns.com/Waves · mobile roundup https://www.mimigames.games/blog/best-roguelite-android-games-2026.html
25. Vampire Survivors Adventure Mode, Game Rant. https://gamerant.com/vampire-survivors-how-to-unlock-adventure-mode-explained/ · Arcanas https://vampire-survivors.fandom.com/wiki/Arcanas
26. Mithrix, Risk of Rain 2 Wiki. https://riskofrain2.wiki.gg/wiki/Mithrix · community feedback https://steamcommunity.com/app/632360/discussions/2/4140563392620588678/ · Alloyed Collective https://riskofrain2.wiki.gg/wiki/Alloyed_Collective
27. Returnal 2.0 suspend cycle, TheSixthAxis. https://www.thesixthaxis.com/2021/10/26/returnal-2-0-update-lets-you-save-the-game-mid-run-photo-mode-patch-notes/ · Act 3 https://hardcoregamer.com/features/articles/how-to-complete-act-3-of-returnal-and-see-final-ending/402885/ · biome meaning https://screenrant.com/returnal-biomes-crimson-wastes-abyssal-scar-overgrown-ruins/
28. Nova Drift: Wild Metamorphosis. https://blog.novadrift.io/wild-metamorphosis/ · review https://lordsofgaming.net/2025/05/nova-drift-review-a-unique-retro-rogue-lite/
29. Mewgenics review, GameSpot. https://www.gamespot.com/reviews/mewgenics-review-a-near-purrfect-roguelite-adventure/1900-6418456/ · https://www.shacknews.com/article/148080/mewgenics-review-score
30. Best new roguelikes, Rogueliker. https://rogueliker.com/best-new-roguelikes/ · March 2026 round-up https://rogueliker.com/roguelike-round-up-march-2026/ · https://www.gamesradar.com/best-roguelikes-roguelites/
31. Mirrorbound (open-source roguelite experiment). https://github.com/0-Playor-0/mirrorbound
32. Cosmic Ocean, Spelunky Wiki. https://spelunky.fandom.com/wiki/Cosmic_Ocean_(2) · https://www.thegamer.com/spelunky-2-get-true-ending-cosmic-ocean-guide/
33. Roguelite meta-progression, Entalto Studios. https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/ · Bugnet https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression
