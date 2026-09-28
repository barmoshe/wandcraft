# Wandcraft 0.19: the Workshop (research and design)

**Bar's asks (28 Sep 2026):**
- "I want my game's lobby to be a playable hub area, inspired by Magicraft... actions are represented by objects, characters, or locations inside the game world."
- "1 store can sell packs of new spells."
- "Replace the codex mechanism and achievement mechanism."
- "Be creative, do parallel agent work, research, reinvent, research the web. The best 0.19 you can."

The plan is `~/.claude/plans/eventual-cuddling-glade.md`, and the decision record is ADR 0027. Six research agents fed this document. Anything marked *[I]* is an inference, not a sourced claim.

## 1. What the research says

### Hubs
- **Magicraft's camp:**
  - It is one small camp with NPCs around its edges: talents, research, sets, a training room with a damage dummy, and a spell-pack NPC [1].
  - Some NPCs are freed from cages hidden in secret rooms. One player couldn't find them and had to ask on Steam [4][5].
  - Reviews barely mention the camp [9]. *[I]* It works as a menu stop, not a selling point.
- **Hades:**
  - The loadout (weapons) and the Skelly dummy sit in the last room before the exit, so you never walk back [10][13].
  - Dialogue is "a bucket of possible conversations, filtered by gameplay conditions and weighted by importance" [H1]. There are over 22,000 lines, with priority tiers, so dying moves the story on [H2].
- **Enter the Gungeon:**
  - Characters are chosen by walking up to them in the Breach [11].
  - NPCs you rescue open shops, and the Hero statue and trophy alcoves fill in as you progress [11][G1].
  - Quick Restart skips the hub for repeat runs [19].
- **Avoid the hub tax.** Players complain about walking between vendors [R1]. So: one screen, a short walk to the portal, and a quick restart on the end screen.
- **Mobile:**
  - Soul Knight reuses the fire button, with a "!" near things you can use [22].
  - The TouchArcade review of Hades on iOS calls the default interact button "a bit too small" [23].
  - Apple's WWDC26 touch session: give the button an icon that says what it does, and remove controls that can't be used [25].
  - Game Accessibility Guidelines: let players start without layers of menus, and let them skip what isn't core [26]. That means a plain MENU listing every station.

### Packs and currency
- **Content, not power.** Gungeon unlocks add to the pool but don't add power [27]; Dead Cells blueprints cost cells [28].
- **Dilution** is the known risk [29]. The Merchant therefore shelves three packs at a time, cheapest first.
- **Make the opening a moment, without gacha:**
  - Pokémon TCG Pocket has you tear the pack by swiping, and the rare is revealed last [P1].
  - Players asked for the animation to be skippable [P2].
  - Balatro opens a pack the moment you buy it [B1].
  - Wandcraft's packs are fixed and shown before you buy, so there is no random reward to pay for.
- **Pace:** an unlock every 1–2 runs (Magicraft players [30 in magicraft-progression.md]; Gungeon's early-run credit bonus [30]).

### Replacing goals and the Codex
- **Quest boards:**
  - Hades' Fated List tracks progress before a prophecy is shown [H3].
  - Megabonk's quests unlock tools [M1]; Halls of Torment has about 600 board quests [T1].
  - Result: the **Bug Bounty Board**.
- **Journals that deepen:**
  - Hollow Knight's Hunter's Journal adds notes after N kills [K1].
  - Hades' Codex fills in as you meet things [H4].
  - The Ammonomicon has margin doodles [G2].
  - Balatro shows "Not Discovered" [B2].
  - Result: the **Compendium**.
- **Run history:**
  - Slay the Spire 2's Timeline of Epochs [S1].
  - Darkest Dungeon's Graveyard records how each hero fell [D1].
  - Result: the **Commit Wall**.

## 2. The design
**The Workshop** is the Guild's workshop inside the Source: one screen, 18×11 tiles, about 2.7 s to cross.
- **Stations:** the Portal, the Hero Hall, the Merchant, the Training Ground, the Bug Bounty Board, the Compendium, the Commit Wall, the Terminal, the Duck and LINT, and boss trophies.
- **Using a station:** walk near it and a USE button appears in the dash slot. Only the portal opens by walking in.
- **The title** is a card over the live hub.
- **The first launch** goes intro, then the tutorial run, then the hub.

**Bits:**

| Source | Bits |
|---|---|
| Each room | 2 |
| Each boss or mini-boss | 8 |
| Beating the Loop | +10 |
| A win | +25 |
| Each of runs 1–3 | +15 |
| Heat | ×(1 + 0.1 per tier) |
| Bounties, claimed at the board | 10–100 each |

That comes to about 31 Bits for an early death, about 46 for a World 1 clear and about 107 for a win.

**Packs** are listed in `Meta.PACKS`:
- Five legacy packs hold everything design v2's goals used to open:
  - Glitch, Flow Control, Physics and Risk at 60 each
  - Debugger at 100, which appears after the Loop falls
- Four new `.pkg` packs at 120 each: Networking, Concurrency, Version Control and Hardware. Between them they add 12 spells, 4 relics and 1 wand (§3).

**Bounties** are listed in `Meta.BOUNTIES`:
- 21 tickets. The early item unlocks stay on tickets: Chorus and Ricochet, the Pyromancer, the Tinkerer and the extra slot.
- New counters: elites, Thermal Shocks, Bitrot crashes, bosses beaten without a hit, and dailies.

**Migrating old saves** (`Meta.migrate`, `meta_v: 2`):
- Goals already done stay unlocked and count as fixed bounties.
- Their Bits are paid as back pay.
- Legacy packs whose items are all open count as owned.

## 3. The new packs

| Pack | Spells | Relic (and wand) |
|---|---|---|
| Networking | Traceroute, Multicast, Broadcast | Target Lock |
| Concurrency | Worker Thread, Spinlock, Scheduler | Thread Pool |
| Version Control | Cherry-Pick, Diff, Blame | Checkpoint |
| Hardware | EMP, Cosmic Ray, Undervolt | Shot Recycler, plus the wand Dual Core |

- Every new spell reuses existing behaviours with small new options; there is no new behaviour type.
- `tests/bench/test_pack_builds.gd` checks that each pack's wand is within 0.7–1.4× of the better core wand.

## 4. Deferred
- Wand share codes and a Wand of the Day, based on the Noita Wand Simulator [N1].
- A weekly Sprint seed [StS daily].
- A hub styled like an IDE.
- `fork` and `merge`.
- Bug fishing.
- Hero palettes as a way to spend Bits.
- A way to turn off the pieces a pack adds [29].

## Progress log
- 2026-09-28: plan approved. Three agents built at once in the main tree, at Bar's request: hero looks, the new packs, and meta v2 plus the hub.
- `f38ff6f` the four packs. The pack bench passes: every pack wand is within 0.7–1.4× of the better core wand, and Version Control, a single-target pack, beats core single (×1.49 against ×1.63). Diff and Cherry-Pick were tuned up.
- `c562018` each hero has their own look.
- `009bacb` the Workshop, meta v2, the station screens and 35 voiced lines. Tests: 281 pass. The tap test passes in all three modes, including its new hub phase.
- Balance bench: the editing bot clears World 1 50% of the time (band 25–45%), wins the full run 10%; the never-editing bot 0%. The bench only uses the core pool, and the same bench on the untouched 0.18.1 tree gives the same 50% on the same seeds, so the edge predates 0.19. Tune after playtest round 2's run logs.

## Sources
- [1] 3DM, 言呐呐, 24 Dec 2025: https://shouyou.3dmgame.com/gl/605486.html
- [4] Steam, 5 Nov 2023: https://steamcommunity.com/app/2103140/discussions/0/3937895474111212341/
- [5] Steam, 10 Dec 2023: https://steamcommunity.com/app/2103140/discussions/0/4031348273656127522/
- [9] Rogueliker, Mike Holmes, 29 Nov 2024: https://rogueliker.com/magicraft-review/
- [10] Hades wiki, Infernal Arms: https://hades.wiki.fextralife.com/Infernal_Arms_(Weapons)
- [11] Enter the Gungeon wiki, The Breach: https://enterthegungeon.wiki.gg/wiki/The_Breach
- [13] Hades wiki, Skelly: https://hades.wiki.fextralife.com/Skelly
- [19] Steam, Gungeon quick restart: https://steamcommunity.com/app/311690/discussions/0/2952662888310130008/
- [22] Soul Knight wiki, Controls: https://soul-knight.fandom.com/wiki/Controls
- [23] TouchArcade, Mikhail Madnani, 20 Mar 2024: https://toucharcade.com/2024/03/20/hades-ios-review-2024-controller-support-cloud-saves-vs-switch-steam-deck-netflix-games/
- [25] Apple, WWDC26 session 358: https://developer.apple.com/videos/play/wwdc2026/358/
- [26] Game Accessibility Guidelines: https://gameaccessibilityguidelines.com/full-list/
- [27] This claim came only from a search snippet with no single source; treat it as unconfirmed.
- [28] Dead Cells wiki, Blueprints: https://deadcells.wiki.gg/wiki/Blueprints
- [29] Dead Cells wiki, Custom Mode: https://deadcells.wiki.gg/wiki/Custom_Mode
- [30] Enter the Gungeon wiki, Hegemony Credit: https://enterthegungeon.wiki.gg/wiki/Hegemony_Credit
- [H1] Game Developer, the dialogue of Hades at GDC 2021: https://www.gamedeveloper.com/audio/dive-into-the-dialogue-of-i-hades-i-at-gdc-2021
- [H2] Game Developer, McAloon, 13 Feb 2020: https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death
- [H3] Hades wiki, Fated List of Minor Prophecies: https://hades.fandom.com/wiki/Fated_List_of_Minor_Prophecies
- [H4] Hades wiki, Codex: https://hades.fandom.com/wiki/Codex
- [G1] VGU, Enter the Gungeon review: https://videogamesuncovered.com/reviews/enter-the-gungeon-review/
- [G2] Enter the Gungeon wiki, Ammonomicon: https://enterthegungeon.wiki.gg/wiki/Ammonomicon
- [R1] ResetEra, on menu hubs versus walk-around hubs: https://www.resetera.com/threads/hot-take-arc-raiders-opts-for-a-ui-menu-based-hub-rather-than-have-an-open-world-run-around-town-style-option-and-i-vastly-prefer-it.1352134/
- [P1] Wikipedia, Pokémon TCG Pocket: https://en.wikipedia.org/wiki/Pok%C3%A9mon_Trading_Card_Game_Pocket
- [P2] Pokémon forums, a skippable pack animation: https://community.pokemon.com/en-us/discussion/18429/add-a-less-animation-heavy-way-to-open-packs-or-make-it-skippable
- [B1] Balatro wiki, Booster Packs: https://balatrowiki.org/w/Booster_Packs
- [B2] Balatro wiki, Stake Stickers: https://balatrowiki.org/w/Stake_Stickers
- [M1] Megabonk wiki, Quests: https://megabonk.fandom.com/wiki/Quests
- [T1] Halls of Torment wiki, Quest: https://hot.fandom.com/wiki/Quest
- [K1] Hollow Knight wiki, Hunter's Journal: https://hollowknight.fandom.com/wiki/Hunter's_Journal
- [S1] NeonLightsMedia, 8 Mar 2026, Slay the Spire 2 Epochs: https://www.neonlightsmedia.com/blog/slay-the-spire-2-epochs-timeline-guide
- [D1] Darkest Dungeon wiki, Graveyard: https://darkestdungeon.wiki.gg/wiki/Graveyard
- [N1] Noita wiki, Noita Wand Simulator: https://noita.wiki.gg/wiki/Tool:_Noita_Wand_Simulator
