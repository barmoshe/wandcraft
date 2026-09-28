# 6. Spell and wand design for a wand-programming roguelite

Researched 2026-09-28 for Wandcraft. Web sources are numbered at the end. Several wikis (noita.wiki.gg, magicraft.fandom.com, steamcommunity.com, thegamer.com) are blocked by the proxy, so those claims rest on search-result summaries, which are cited as such. Anything inferred is marked **[I]**. Under ADR 0002, only mechanics are borrowed; every name, sentence and number in the proposal is our own.

## What Wandcraft already has (from the code)

- **The program** (`game/scripts/sim/wand_program.gd`) reads left to right. Boosts accumulate until the wand wraps. Chorus and Pipeline draw extra spells. Triggers glue the left spell to the right one. Carriers take the next shooting spell. Payloads start a fresh count scope, and nesting stops at depth 3.
- **Debugger runes:** HEAD and Cherry-Pick (copy the first or last spell), IF/ELSE (branches on range), GOTO (once per cycle) and #include (makes a boost global).
- **Wand quirks** (`WandDef`): `reverse` (Mirror Rod), `simultaneous` (Fork Branch, Harp, Dual Core), `background_slot` (Daemon Rod) and `rune_tax` (Debug Build). `WandState.suspended` lets the World 3 Interrupt enemy blank out one slot.
- **Runner events** (`spell_runner.gd`) already fire payloads on `hit`, `end`, `kill`, `fly` and `nova`. Behaviours: bolt, bomb, beam, burst, cone, wall, orb, cloud, mine, boomerang, wheel, ping, turret/daemon/duck. Statuses: burn, chill (3 = freeze), static, bitrot.
- **Defences** (`enemy.gd`): a frontal shield (Pierce breaks it), an armour bar (Blast hits it x3, everything else x0.35), and a 3-hit ward that comes back (Shock strips it).
- **Content:** 74 spells (including 6 evolutions) and 12 wands. The gaps **[I]**: every wand except the Mirror Rod reads in one fixed order; nothing reacts to *you* (getting hit, missing); nothing scales within a room; there is no two-spell carrier; and empty slots are always dead.

## What the reference games teach

### Noita: the grammar of a wand
- **Stats:** a wand has cast delay (the gap between casts), recharge time (after the last spell), mana, mana regen, spells/cast and spread. Each spell adds its own delay modifier [1].
- **Shuffle** randomises the order once per recharge, not per draw [4].
- **Always Cast** spells fire with every cast at no mana cost [1].
- **Modifiers** apply to the whole "casting block" that a multicast pulls in, and their mana is paid once per block. **Multicasts wrap** to the start of the wand when they run out of spells [3].
- **Triggers and timers** cast a stored spell from the point of impact. Guides say "a strong wand build equals a trigger build" [3].
- **Rule-benders drive the depth** **[I]**:
  - Greek spells copy the first, last or next two spells [5].
  - Divide By casts the next spell N times while ignoring the copies' mana [6].
  - Add Mana has a negative cost [7].
  - Requirement spells branch on conditions (design-research §2).
- **The warning:** mechanics are "quite complex" and "stuffing spells into a wand and hoping" fails [4]. About 30% of players never touch wand editing (design-research §2). The lesson for a phone: keep one visible rule per card and show a preview.

### Magicraft: the closest cousin
- Slots take spells, spell modifiers or wand modifiers. Modifiers affect the slots on their right [8].
- Each wand has its own mana pool, and max mana limits one casting cycle [8].
- Rare wands carry passives that "apply to all slotted spells regardless of their position" [8].
- Charge slots cost no mana and fire when a charge fills; payloads come in pay-once and pay-per-repeat forms (design-research §2).
- **Takeaway [I]:** the wand body's special rule is where much of the variety lives. Wandcraft's 12 wands mostly differ in numbers, and only four have a rule.

### Wizard of Legend
- Arcana come in four types: Basic (no cooldown), Dash, Standard and Signature. Signature arcana charge by attacking and pay off when full [9].
- **Takeaway [I]:** tie spells to player *events* (a dash, a hit) and to charge meters, not only to the fire button. On a phone, auto-firing twin-stick play leaves the player's attention for positioning, so event spells reward the thing they are already doing.

### Mages of Mystralia
- Runes come in three roles:
  - Behaviours (verbs) change how a spell moves.
  - Augments (adverbs) modify only the rune they attach to and cost no mana.
  - Triggers fire another spell on a condition such as impact, "up to 4 times per manual cast" [10].
- **Takeaway [I]:** a hard cap on trigger fires per cast keeps chains readable and cheap to simulate. Wandcraft's Callback and Loop already pay per fire.

### Magicka
- Up to five queued elements combine. Opposing pairs cancel ("Fire and Cold…") and some combine (Fire + Water = Steam) [11].
- **Takeaway [I]:** cancel rules are a clear way to make order and neighbours matter. Wandcraft's Reverse already cancels itself; a scope-closing card extends that idea.

### Vampire Survivors, Brotato and Balatro: synergy without a program
- **Vampire Survivors:** a maxed weapon plus a named passive becomes an evolution at a chest [12]. Wandcraft has this as Compile.
- **Brotato:** every weapon carries 1-2 classes, and holding 2-6 of a class adds a stepped set bonus [13]. A duplicate pick is therefore never dead.
- **Balatro:** strong hands combine a chip source, a scaling mult and an XMult source. Order matters because "XMult is applied last", and jokers score left to right [14].
- **Takeaways [I]:**
  1. Ship cards whose value grows with *position* (late in the program) or *time* (cycles this room).
  2. Make duplicates useful (Brotato).
  3. Separate scaling pieces from finishing pieces so a build has a shape.

### Spellbook Demonslayers and Wand Wars
- **Spellbook Demonslayers** is a horde roguelite of spells plus upgrades [15]. Its "illegal upgrades" "break the rules and completely change how your character works", and illegal spells now preview what they replace [15]. A search summary also reports a plan for every spell to have "a strong identity… rather than just different flavours of DPS" (unverified; Steam pages are blocked).
- **Wand Wars: Rise** lists "dozens of skills" and about 100 equipments but has no documented wand grammar [16], so it teaches little here.

### General item-design principles
- Items should "meaningfully change runs… rather than offering minor stat boosts".
- Randomness must be legible, with weighted, synergy-aware pools and reroll outs [17].

## Principles for Wandcraft's next spells [I]

1. **A good card changes another slot.** Wandcraft's best cards (Carry, THEN, HEAD, #include) are verbs about *other* slots. New shooting spells should also have a program hook, such as scaling with position or hosting triggers.
2. **No dead picks.**
   - Every new card works alone at level 1.
   - Duplicates get a use (Cache Hit, Brotato's lesson).
   - Empty slots get a use (Autocomplete).
   - Rewards already lean toward owned tags (`Catalog.TAGS`), so every new card gets tags.
3. **One rule per card, under 90 characters, shown in the preview.** No hidden state. Shuffle is allowed only if the order is visible before you fire.
4. **Counters stay keyword-based.** Pierce breaks shields, Blast breaks armour, Shock strips wards. Each pack should carry at least one of them so buying a pack never blocks a door.
5. **Lean on the World 3 theme,** because it is the least-used flavour so far: buffers, paging, interrupts, scheduling, compilers, memory. Use names that also land for non-coders (Backspace, Alt+Tab, Buffering…, Recycle Bin).
6. **Reuse runner events** (`hit`/`end`/`kill`) and `Mods` fields before adding behaviours. Each card below is sized S (a param or a branch), M (new state or a new hook) or L (a new system).

## Proposal: 14 new spells (original)

Numbers follow `catalog.gd` (`mp`, `dmg`, `p`), with values per level [L1, L2, L3].

### Shooting spells

**1. `drill_bit`, "Drill Bit"** (projectile, Pierce: counters shields)
- **Does:** a slow spinning bit that grinds through every enemy in its path. Breaks shields.
- **Numbers:** `{"mp": [6, 8, 10], "dmg": [3, 4, 6], "beh": "orb", "kw": ["pierce"], "p": {"speed": 95, "radius": 3.0, "life": [1.4, 1.7, 2.0], "pierce": 99}}`. The orb behaviour hits about 4 times a second.
- **L3:** it speeds up by 25% after each enemy it passes.
- **Combos:** its long flight makes it the best host for Repeat (`loop`) and Callback. Phase, Heavy.
- **Engine:** S (orb with no pull, plus a keyword).

**2. `zip_bomb`, "Zip Bomb"** (projectile, Blast: counters armour)
- **Does:** a tiny bomb that grows 20% bigger and stronger for each spell cast before it this cycle.
- **Numbers:** `{"mp": [6, 8, 10], "dmg": [8, 12, 16], "beh": "bomb", "kw": ["blast"], "p": {"speed": 160, "radius": 3.0, "life": 0.9, "area": [20.0, 22.0, 26.0], "stack": [0.2, 0.25, 0.3], "stack_max": 6}}`
- **Combos:** it is the Balatro "last joker": place it at the end of a long wand (Old Oak Staff). Pipeline, Chorus, and Palindrome (it gets read twice).
- **Engine:** S-M. It needs a casts-this-cycle counter on `WandState`, reset on wrap.

**3. `blue_screen`, "Blue Screen"** (projectile, Shock: counters wards)
- **Does:** a slow blue field that shocks everything inside and freezes each enemy once. Strips wards.
- **Numbers:** `{"mp": [7, 9, 12], "dmg": [3, 4, 6], "beh": "cloud", "kw": ["shock"], "p": {"speed": 40, "radius": 12.0, "life": 2.0, "pierce": 99, "static": 1, "stall": [0.4, 0.5, 0.7]}}`
- **Combos:** Frost Coat (Thermal Shock setups), Spark Coat, Wide, Gravity. It pairs with Burst via THEN.
- **Engine:** S. The cloud already exists; add `static` and a once-per-enemy freeze.

### Carrier and trigger

**4. `tarball`, "Tarball"** (carrier, rarity 1)
- **Does:** a sticky ball that holds the 2 shooting spells on its right and releases both where it stops.
- **Numbers:** `{"rar": 1, "mp": [3, 4, 5], "dmg": [3, 5, 8], "carry": "tarball", "p": {"speed": 170, "radius": 3.0, "life": 0.9}}`. The payloads cost {100/90/75}% of their mana.
- **Combos:** Burst + Ember as a double blast, Mine + Firewall as a trap, Blue Screen + Burst.
- **Engine:** M. The payload becomes a list of 2 nodes in `_draw_payload`; `fire_carry` emits both.

**5. `await`, "Await"** (trigger)
- **Does:** goes between two spells. When the left spell hits, the right one is cast from your wand straight at that enemy.
- **Numbers:** `{"mp": [3], "t": "await"}`, fires at most {1/2/3} times per left spell.
- **Combos:** turns spray into aim. For example, Seeker Moths + Await + Prism Lance or Diff, or Traceroute / Spark + Await + Needle.
- **Engine:** S-M. It uses the existing `hit` event; the origin is the player's hand and the angle points at `hit_e`.

### Boosts that change the flow

**6. `buffering`, "Buffering…"** (boost)
- **Does:** shooting spells on its right wait, then all fire at once when the wand recharges.
- **Numbers:** `{"mp": [2]}`, and the buffered spells get +{10/20/35}% damage.
- **Combos:** Heat Sink (the release comes sooner), Zip Bomb, Burst, and Loop Counter. It turns a stream into a volley.
- **Engine:** M. The cast node needs a `deferred` flag; `WandState` holds a buffer and `wand_fire` flushes it on `plan.wrapped`.

**7. `retry`, "Retry"** (boost)
- **Does:** a spell on its right that ends without hitting anything is cast again from you, free.
- **Numbers:** `{"mp": [3]}`, {1/1/2} retries.
- **Combos:** Cosmic Ray does not need it. Ember, Mine, Needle and Glitch Mine all benefit, and the Blame steering boost gets a second attempt. It is a mercy card for new players.
- **Engine:** M. Add a `hits` count on the bullet and re-emit from the player at `end`.

**8. `jit`, "Just-in-Time"** (boost)
- **Does:** spells on its right gain damage each time the wand recharges this room.
- **Numbers:** `{"mp": [3]}`, +{6/8/12}% per recharge, capped at +{60/80/120}%.
- **Combos:** Heat Sink, short wands (the Twig), and bosses. It is the scaling-mult source the arsenal lacks.
- **Engine:** S. A per-room counter on `WandState`, cleared by `clear_room`.

**9. `end_scope`, "End Block }"** (boost)
- **Does:** boosts on its left stop here, so spells on its right cast plain.
- **Numbers:** `{"mp": [0]}`
- **Combos:** it contains a trade-off boost to one half of the wand. For example, Reverse + Needle + End Block + Mine gives a kite build, and Undervolt spam + End Block + Burst keeps the finisher at full power. It also resets Orbit.
- **Engine:** S. Set `acc = Mods.new()`, keeping `goto_used`.

### Debugger runes

**10. `alt_tab`, "Alt+Tab"** (rune)
- **Does:** casts the spell on its right on odd cycles and the one after it on even cycles.
- **Numbers:** `{"mp": [1]}`
- **Combos:** alternate crowd and single-target, or a shield counter and an armour counter, with no enemy check. It is IF/ELSE's sibling.
- **Engine:** S. It reuses the `ifelse` compile branch with a cycle-parity condition (`WandState.cycles`).

**11. `autocomplete`, "Autocomplete"** (rune)
- **Does:** each empty slot on its right casts a copy of the shooting spell before it.
- **Numbers:** `{"rar": 1, "mp": [3, 2, 1]}`, the copies deal {60/80/100}% damage.
- **Combos:** Empty Hands relic (`empty_set`), and the Interrupt enemy (a suspended slot reads as empty, so it gets filled). Big wands with few spells.
- **Engine:** S-M. `_next` must stop on null slots after an Autocomplete and emit a copy node, as HEAD does.

**12. `ctrl_alt_del`, "Ctrl+Alt+Del"** (rune)
- **Does:** takes the spell on its right out of the cycle; that spell casts itself around you, free, when you're hit.
- **Numbers:** `{"rar": 1, "mp": [0]}`, cooldown {4/3/2} s.
- **Combos:** EMP (wipes out shots), Rubber Duck, Spinlock, Broadcast, Firewall. Wizard of Legend's event arcana, made defensive.
- **Engine:** M. It needs a hook on player damage and an exclusion like `background_slot`.

### Passives

**13. `virtual_memory`, "Virtual Memory"** (passive)
- **Does:** the wand can keep casting down to {20/35/50} mana below zero.
- **Numbers:** while below zero, mana refills 30% slower.
- **Combos:** Last Reserves (`low_battery`), Siphon, Watchdog, expensive Starwheel builds.
- **Engine:** S. Lower the mana floor in `wand_fire` and make the HUD bar show red.

**14. `cache_hit`, "Cache Hit"** (passive)
- **Does:** a spell cast right after a copy of itself costs {30/50/70}% less mana.
- **Numbers:** the "copy" is the same spell id as the previous cast, so duplicates become a build.
- **Combos:** mono-Mote or mono-Needle wands, Twin Cast, Pipeline.
- **Engine:** S. Store the last cast's first spell id on `WandState`.
- **Note:** the id differs from the old alias `cache`.

**Suggested tags** (`Catalog.TAGS`):

| Spell | Tags |
|---|---|
| drill_bit | Area |
| zip_bomb | Area, Crit |
| blue_screen | Shock, Frost |
| tarball | Carrier |
| await | Trigger |
| buffering | Multi |
| retry | Survival |
| jit | Crit |
| end_scope | Debug |
| alt_tab | Debug |
| autocomplete | Debug, Multi |
| ctrl_alt_del | Survival, Debug |
| virtual_memory | Economy |
| cache_hit | Economy |

## Proposal: 5 new wands (original)

Stats are in `_w()` order: slots, max mana, regen, cast delay, recharge, scatter, simultaneous.

| id | Name | Rar | Slots | Mana | Regen | Delay | Recharge | Scatter | Special rule | Engine |
|---|---|---|---|---|---|---|---|---|---|---|
| `shuffle_play` | Shuffle Play | 1 | 6 | 110 | 26 | 0.10 | 0.30 | 5 | Its spells play in a new order each recharge. The editor and HUD show the next order. | New: M (a permutation on `WandState`; `_idx` reads it). Unlike Noita's hidden shuffle [4], the order is visible. |
| `pinned_tab` | Pinned Tab | 2 | 6 | 100 | 22 | 0.16 | 0.55 | 5 | Slot 1 is pinned: it joins every cast for free (a boost applies to everything, a spell fires at 50%). | New: M. It is Noita's Always Cast [1], compiled in front of each cast. |
| `palindrome` | Palindrome Staff | 1 | 5 | 100 | 22 | 0.14 | 0.70 | 5 | Reads left to right, then back right to left, then recharges (1-2-3-4-5-4-3-2). | New: M (the `_idx` walk becomes 2n-2 steps). `reverse` exists but only flips the order, so this is different. On the way back, boosts power the spells to their *left*. |
| `double_buffer` | Double Buffer | 2 | 8 | 120 | 24 | 0.14 | 0.50 | 5 | Two pages of four slots. It flips to the other page each time it recharges. | New: M (`n` = 4 plus a page offset; HUD page pips). Two builds in one wand, for example crowd and boss. |
| `recycle_bin` | Recycle Bin | 1 | 6 | 150 | 0 | 0.12 | 0.45 | 6 | No mana regen: every kill refills 12 mana, and it starts each room full. | Near-existing: S (`regen = 0`; the kill hook exists for Siphon). |

Each rule is one line in the wand's `desc`. The Mirror Rod already covers "reads right to left" and Dual Core / Fork Branch cover "casts two at once", so none of these repeats them.

## Proposal: three Workshop packs

Price them at 120 Bits like the other `.pkg` packs. Each pack carries at least one defence counter.

- **Interrupts** (`irq.pkg`, color `#ff6b7a`): "Spells that answer: when you're hit, when you miss, when you land."
  - Contents: Ctrl+Alt+Del, Retry, Await, Blue Screen (ward counter), Pinned Tab.
- **Memory** (`mem.pkg`, color `#5ce1ff`, needs `world2`): "Buffers, paging and borrowed mana."
  - Contents: Buffering…, Virtual Memory, Cache Hit, Tarball, Autocomplete, Double Buffer, Recycle Bin.
  - It has no keyword spell, but Tarball carries Burst, Ember or Needle **[I]**. Add a counter if playtests show gaps.
- **Compiler** (`cc.pkg`, color `#b6ff5c`): "Where you put a spell matters: build order, scopes, and a bomb that waits its turn."
  - Contents: Zip Bomb (armour counter), Drill Bit (shield counter), Just-in-Time, End Block, Alt+Tab, Palindrome Staff, Shuffle Play.

**Build order [I]:** cheapest first are the S-sized cards (Drill Bit, Blue Screen, Just-in-Time, End Block, Alt+Tab, Virtual Memory, Cache Hit, Recycle Bin), which ship as Compiler plus half of Memory. The M cards follow. Nothing here is L-sized.

## Sources

1. Noita Wiki (Fandom), "Advanced Guide To Wand Mechanics" (search summary): https://noita.fandom.com/wiki/Advanced_Guide_To_Wand_Mechanics
2. The Noita Wiki, "Guide: Wand Mechanics" (blocked; search summary): https://noita.wiki.gg/wiki/Guide:_Wand_Mechanics
3. dood.gg, "Wand Building – Noita" (search summary): https://dood.gg/en/noita/guides/wand-building/
4. The Noita Wiki, "Wands" (search summary): https://noita.wiki.gg/wiki/Wands
5. The Noita Wiki, "Greek Spells": https://noita.wiki.gg/wiki/Greek_Spells
6. Noita Wiki (Fandom), "Divide By": https://noita.fandom.com/wiki/Divide_By
7. Noita Wiki (Fandom), "Add Mana": https://noita.fandom.com/wiki/Add_Mana
8. Shapes, "Magicraft Spells & Wands": https://shapes.inc/fandom/magicraft/spells-and-wands and TheGamer, "Things You Should Know Before Starting Magicraft": https://www.thegamer.com/magicraft-beginner-tips-tricks-guide/
9. Wizard of Legend Wiki, "Arcana": https://wizardoflegend.fandom.com/wiki/Arcana
10. Mages of Mystralia Wiki, "Runes": https://magesofmystralia.fandom.com/wiki/Runes and Game Developer, "Creative process of a procedural spell crafting system": https://www.gamedeveloper.com/design/creative-process-of-a-procedural-spell-crafting-system
11. Magicka Wiki, "Elements": https://magicka-archive.fandom.com/wiki/Elements and "Spell combinations": https://magicka.fandom.com/wiki/Spell_combinations
12. Vampire Survivors Wiki, "Evolution": https://vampire.survivors.wiki/w/Evolution
13. Brotato Wiki, "Weapon Classes": https://brotato.wiki.spellsandguns.com/Weapon_Classes
14. dood.gg, "Balatro Scoring Mechanics": https://dood.gg/en/balatro/guides/scoring-guide/ and "Balatro Joker Synergies": https://dood.gg/en/balatro/guides/joker-synergy/
15. Spellbook Demonslayers on Steam: https://store.steampowered.com/app/2007530/Spellbook_Demonslayers/ and "Illegal Upgrades" wiki: https://spellbook-demonslayers.fandom.com/wiki/Illegal_Upgrades
16. Wand Wars: Rise on Steam: https://store.steampowered.com/app/1020360/_Wand_Wars_Rise/
17. Bugnet, "How to Design a Roguelike Item and Synergy System": https://bugnet.io/blog/how-to-design-a-roguelike-item-and-synergy-system
- Internal: `research/design-research.md` §2 (Magicraft deep dive, Noita Requirement spells, the 30% figure), `research/magicraft-progression.md`, and `game/scripts/sim/*.gd`.
