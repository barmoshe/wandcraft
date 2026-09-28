# 7. Relic and passive item design in roguelites (for Wandcraft)

Date: 2026-09-28. Scope: what the reference games do with passive items, what that means for a phone twin-stick where the wand is a program, and 16 original relics. Inferences are marked [I]. Several wikis and x.com were blocked by the proxy; those points rest on search-result summaries, cited as such.

## Where Wandcraft stands (from the code)

- 42 relics in `Relics.DEFS`. Two layers: `stats` folded by `Relics.stat()` and hooks at event sites (`cast_bonus`, `wand_fire`, `hurt_enemy`, the kill site in `world.gd`, `Player.hurt`, `try_merge`, room entry). HUD pips (`hud.gd relic_pip`) show a number or a lit dot.
- Open gaps: little reads the program's *shape* (only Empty Hands, Legacy Code), nothing touches the shop beyond gold or wand switching, and nothing answers the Kernel (Interrupt `WandState.suspended`, Page Leak `world.puddles`, Data Race's together rule, revert).

## What the reference games teach

**Slay the Spire.** Always-on relics, counters, conditionals, and boss relics whose drawback is the point [1]. Energy relics carry downsides that "can still be played around", and since most other relics are pure upside the pick is never simply "energy wins" [2]. Snecko Eye and Runic Dome tax an information channel the player compensates for, not a number [5]. Pen Nib and Nunchaku keep their count across combats, shown on the icon [3][4]. Lesson: counters persist and are visible; drawbacks are plannable.

**The Binding of Isaac.** Synergies are emergent; bad pairs are accepted because "the possibility of spectacular failure makes spectacular success meaningful" [6]. Transformations reward any 3 items of a themed set [7]. Lesson [I]: a few deliberate anti-synergies make picks real; a tag-set bonus is a cheap later feature.

**Hades.** Duo boons need one listed boon from each of two gods and can redirect a run [8]. Daedalus Hammers are per-weapon pools that change how an attack fires, two a run [9]. Lesson: Merge Commits unlock a rule, not +X%; context-bound relics get their own pool.

**Balatro.** Jokers sort by job: economy, flat, multiplier, scaling (rewards early pickup), copy/retrigger, utility; a stable run needs economy plus a ceiling raiser [10]. Activation order matters and retriggers re-fire every effect [11]. LocalThunk published joker guidelines (unreachable here) [12]. Lesson [I]: "boosts affect what is to their right" is Wandcraft's joker order, so relics that move where a boost applies are its rule-breakers.

**Risk of Rain 2.** A proc coefficient scales on-hit chances; proc chains happen when on-hit items trigger each other, and damage over time (coefficient 0) cannot chain [13]. Stacking is mostly linear, chances and reductions hyperbolic [14]. Lesson: every kill- or spread-relic needs a chain rule decided up front.

**Enter the Gungeon.** Synergies show a blue arrow and a name; a hidden "synergy factor" boosts completing picks until you own two [15]. Wandcraft already has both (the "Enables" chip, 3x Merge Commit weight).

**Dead Cells.** Mutations cap at three, one more per biome, resettable for gold; Combo gives +15% damage for 8 s after a kill [16]. Lesson [I]: short buffs after a visible event read well in action.

**Brotato.** Items trade stats, and a negative stat is free if your build ignores it; Padding scales max HP with carried materials, taxing spending [17]. Lesson: drawbacks on an axis some builds ignore create identity; "hoard to scale" is a real decision.

**Magicraft (mechanics only).** Relics can't be unequipped; top picks add simultaneous casts, duplicate casts by chance or duplicate chests. High Epics cost max HP, and curse chests trade a known curse (about 15 HP) for loot [18]. Players say rerolls miss build pieces (design-research §2). The Glitch Door already mirrors the HP fee.

**Readability.** Depth only invites experiment when it is readable [19].

## Principles for Wandcraft relics

1. **No flat stats.** A number only behind a condition the player steers (ADR 0014).
2. **Edit the program's rules.** [I] If a relic never sends you to the editor, it is a stat [9][11].
3. **One trigger, one glance.** One sentence under 80 characters, one number, a visible event [19].
4. **Show state.** Counters get a number pip, conditionals a lit dot [3].
5. **Plannable drawbacks** on an axis some builds ignore [2][17].
6. **Decide the proc chain** [13]. [I] Default: results may re-trigger, each enemy once per event.
7. **World-scoped pools.** [I] A `"from": 2` def field lets `offerable()` skip Kernel-only relics in Worlds 1-2 [9].
8. **Anti-synergies on purpose** (Short Wand vs Extra Slot, Tail Boost vs Legacy Code) [6].

## Proposal: 16 original relics

Rarity: 0 common, 1 rare, 2 epic, 3 Corrupted. Size: S (one hook line or a stat key), M (new state plus a hook), L (new system). No id below exists in `relics.gd`, `Relics.CUT` or the spell catalog.

### Pack A: Kernel Mode (`kernel.pkg`, 120 Bits, needs bounty `world2`)
Blurb: "Turn the Kernel's tricks around: locks, leaks, races and rewinds."

| id | title / flavor | rar | tags | desc | hook, size | builds |
|---|---|---|---|---|---|---|
| `graceful_degrade` | Locked Fury / Graceful Degradation | 1 | Glitch | While an Interrupt holds a slot, your other spells deal +40%. | `cast_bonus`: `w.suspended >= 0`. Lit-dot pip while suspended. `from: 2`. S | Makes the Interrupt a choice: kill the bell now or ride the buff. Stacks with Last Reserves. |
| `swap_space` | Puddle Skater / Swap Space | 0 | Economy | Leak puddles speed you up instead, and refill mana while you stand in them. | `world.gd` puddle slow (returns 1.25, not `PUDDLE_SLOW`); +4 mana/s to the held wand in a puddle. `from: 2`. S | Page Leak turns into a resource: keep it alive for its puddles (they dry when it dies). Fights Steady Aim's "stand still". |
| `thread_join` | Finisher / join() | 1 | Crit | Kills also finish nearby enemies under 15% HP. | Kill site: radius 48 px; finished enemies can chain, once each. Data Race: a thread's fall finishes its twin if under 15% anywhere. S (+S for the race) | Answers Data Race's together rule; turns Wide/Extra Bolt spreads into clean sweeps. |
| `undo_stack` | Take-Back / Undo Stack | 1 | Survival | After a hit, avoid another for 3 s and that hit is undone. Once a room. | `Player.hurt` stores amount and timer; world tick heals it back with the green revert-glyph fx. Lit dot while pending. [I] An undone hit doesn't break Untouched Streak. M | Rewards dodging over tanking; echoes the Glitch's revert. Future duo with Untouched Streak. |
| `warm_cache` | Warm-Up / Cache Warmup | 0 | none | Each cast adds +2% damage this room, up to +40%. A hit clears it. | `cast_bonus` reads a per-room count; reset in room start and `Player.hurt`. Number pip (stacks), gold at max. S | Fast-cast wands (Race Condition, Quicken, short programs); pairs with Take-Back. |

### Pack B: Refactor (`refactor.pkg`, 100 Bits, needs bounty `world1`)
Blurb: "Relics that read your wand's shape, slot by slot."

| id | title / flavor | rar | tags | desc | hook, size | builds |
|---|---|---|---|---|---|---|
| `hoisting` | Tail Boost / Hoisting | 1 | Debug | A boost in a wand's last slot affects every spell in the wand. | `WandProgram._scan_includes`: mark the last slot as included if it is a BOOST (reuses #include's `inc_slots`). S | Puts one Empower or coat at the end and frees the front of the wand. Clashes with Legacy Code on purpose. |
| `polyglot` | Mixed Program / Polyglot | 0 | none | +6% damage for each spell kind in the wand you hold. | `cast_bonus`: count distinct `SpellDef.Kind` (6 kinds, up to +36%). Number pip (kinds). S | Rewards a program with a trigger, a rune, a passive and a summon; the opposite pull to Empty Hands. |
| `short_circuit` | Short Wand / Short-Circuit | 0 | none | A wand with 3 slots or fewer recharges 40% faster. | `spell_runner.gd` recharge (`rc *= 0.6` when `w.slots.size() <= 3`). S | Keeps Twig and Stub alive late; loves Fresh Charge and Parting Shot. Anti-synergy with Extra Slot. |
| `end_of_life` | Buyback / End of Life | 0 | Economy | Deprecating a spell pays 15 gold, and you may Deprecate twice a shop. | `shop_screen.gd` Deprecate: `deprecated_here` becomes a count (limit 2) and pays gold. S | Pool thinning that funds rerolls: answers "rerolls miss my build" [18]. |
| `technical_debt` | Technical Debt | 3 | none | Every wand gets 2 more slots, but recharges take 50% longer. | stats `{"slots": 2, "recharge": 1.5}`; add `recharge` to `STAT_MUL`, read at the recharge line; `on_gain` adds slots like Extra Slot. S | Long trigger programs and Tail Boost; plannable for builds with Watchdog or Tally free casts. |

### Core pool additions

`Meta.CORE_RELICS` is documented as "It never changes". [I] So the two duos join core (their parents are all core, so a pack lock would hide a duo that core players can already enable), and the other four open through new bounties, the way Opening Rush and Fresh Charge do.

| id | title / flavor | rar | tags | desc | hook, size | builds |
|---|---|---|---|---|---|---|
| `lazy_eval` | Refund Misses / Lazy Evaluation | 1 | Economy | A shot that hits nothing refunds its mana to its wand. | Bullet expiry with no hit: refund `plan.mana / bolts` to the source wand (bullets need a wand ref and a share). M | Forgives phone aim; makes costly Lance/Heavy programs viable; lets Last Reserves hover under 25%. |
| `context_switch` | Swap Dodge / Context Switch | 0 | Survival | Switching wands makes you untouchable for 0.4 s, every 4 s. | `player.gd` wand select (lines ~146-152) sets an invuln timer. Lit dot when ready. S | Teaches that you carry several wands; one-job wands; switch into a Fresh Charge wand. |
| `cold_storage` | Bit Savings / Cold Storage | 0 | Economy | When the run ends, every 40 gold you hold pays 1 Bit (up to 10). | `Meta.bits_for`: `mini(10, gold / 40)`. S | Hoard-or-spend tension (Brotato's Padding [17]); pairs with Compound Interest. |
| `shared_memory` | Contagion / Shared Memory | 1 | Glitch | An enemy dying with 2+ statuses passes them to the nearest enemy. | Kill site beside Wildfire; passed statuses keep their stacks; chains once per enemy. S | Keeps Overclocked (+20%) rolling through a pack; coat-stacking builds; Quick Rot crashes. |
| `cron_job` | Double Tick / Cron Job | 2 | Multi, Economy | Back Shot and Tally Charm count every cast twice. | Duo `[stack_trace, loop_counter]`. `casts_fired` advances 2 for those checks (every 3-4 casts backward, every 5th free). The pips follow. S | A counter engine: free double casts every 5 with Tally, backward fire with Back Shot. |
| `superconductor` | Cold Current / Superconductor | 2 | Shock, Frost | Static arcs chill what they hit and jump to one more enemy. | Duo `[surge_protector, cold_boot]`. Surge arc site (`world.gd` ~1731) adds chill and a third target. S | Static plus chill means Overclocked and Frostbite's +25% on every arc; a sibling to Steam Burst. |

### Coverage check

- Conditional: Locked Fury, Finisher, Short Wand. Scaling with a pip: Warm-Up, Double Tick. Rule-breaking: Tail Boost, Refund Misses, Puddle Skater. Program-aware: Tail Boost, Mixed Program, Short Wand, Technical Debt. Status: Contagion, Cold Current. Economy/Bits: Bit Savings, Buyback. Defence: Take-Back, Swap Dodge. Corrupted: Technical Debt.
- World 3: Interrupt, Page Leak, Data Race, revert. [I] Residents give services, never power (ADR 0028), so Cache is flavor plus an idle line, not a gate; Lost Pages stay meta.
- New engine surface: a `recharge` stat, a `from` field, a Deprecate count, a bullet mana share. The rest reuses live hooks.
- Reserve: `god_object` (Corrupted), "+60% damage, but you can hold only one wand." A foil to Swap Dodge.

## Sources

1. Game Developer, "Watch Casey Yano break down the design decisions behind Slay the Spire": https://www.gamedeveloper.com/game-platforms/watch-casey-yano-break-down-the-design-decisions-behind-i-slay-the-spire-i-
2. Steam discussion on StS energy relics and drawbacks (search summary): https://steamcommunity.com/app/646570/discussions/0/1742232339939829970
3. Pen Nib, Slay the Spire Wiki (counter persists across combats): https://slay-the-spire.fandom.com/wiki/Pen_Nib
4. Kunai / Nunchaku, Slay the Spire Wiki (search summary): https://slaythespire.wiki.gg/wiki/Kunai and https://slaythespire.wiki.gg/wiki/Nunchaku
5. Boss relics: Runic Dome and category page (search summary): https://slaythespire.wiki.gg/wiki/Runic_Dome and https://slay-the-spire.fandom.com/wiki/Category:Boss_Relic
6. "Every Choice is a Gamble: Game Design Lessons from The Binding of Isaac": https://www.kokutech.com/blog/gamedev/design-patterns/unique-mechanics/the-binding-of-isaac
7. Transformations, Binding of Isaac: Rebirth Wiki: https://bindingofisaacrebirth.wiki.gg/wiki/Transformations
8. Duo Boons, Hades Wiki, and a duo requirement table: https://hades.fandom.com/wiki/Duo_Boons and https://orlp.github.io/hades-boons/duo_boons.html
9. Daedalus Hammer, Hades Wiki (search summary): https://hades.fandom.com/wiki/Daedalus_Hammer and https://rogueranker.com/hades-2-daedalus-hammer/
10. "Balatro Jokers Guide: Roles, Categories, and Build Thinking": https://balatrocalc.com/balatro-jokers
11. Guide: Activation Sequence, Balatro Wiki: https://balatrogame.fandom.com/wiki/Guide:_Activation_Sequence
12. LocalThunk's joker design guidelines post (blocked here; existence only): https://x.com/LocalThunk/status/1794039720948986170
13. Proc Coefficient, Risk of Rain 2 Wiki, and GameRant on proc chains: https://riskofrain2.fandom.com/wiki/Proc_Coefficient and https://gamerant.com/risk-of-rain-2-ror-2-proc-chain-coefficients-explained/
14. Item Stacking, Risk of Rain 2 Wiki (via design-research §2): https://riskofrain2.fandom.com/wiki/Item_Stacking
15. Synergies, Official Enter the Gungeon Wiki (search summary): https://enterthegungeon.wiki.gg/wiki/Synergies
16. Mutations, Official Dead Cells Wiki (search summary): https://deadcells.wiki.gg/wiki/Mutations
17. Brotato: Padding and armor-downside items: https://brotato.wiki.spellsandguns.com/Padding and https://brotato-builds.com/stats/armor
18. Magicraft relics and curses (search summaries): https://www.thegamer.com/magicraft-best-relics/ , https://magicraft.fandom.com/wiki/Curses , https://www.thegamer.com/magicraft-beginner-tips-tricks-guide/
19. Entalto Studios, "5 Essential Tips to Make Your Roguelite Game Work": https://entaltostudios.com/5-essential-tips-to-make-your-roguelite-game-work/
