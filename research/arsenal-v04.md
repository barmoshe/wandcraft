# Arsenal v0.4: spells and relics, redesigned

Bar's feedback (2026-09-24): "the spells and relics should be designed and arted better". This doc is the design; the code follows it. All names, text and numbers are original (ADR 0002).

## Principles
- **Every item changes a decision.** Flat "+X%" items are kept only as a few commons that round out a build. Most relics change how you play or combine with something.
- **Every shooting spell has one clear role.** Its icon, projectile and sound all say that role at a glance.
- **Synergy tags.** Tags are shown on cards. Rewards lean toward tags you already own (weight ×1.6 per shared tag, capped at ×2.5), so a build takes shape without being forced.
  - The tags: `Crit`, `Burn`, `Frost`, `Trigger`, `Carrier`, `Area`, `Multi`, `Glitch`, `Survival`, `Economy`.

## Shooting spells (15)

| id | Name | Role | Tags | New |
|---|---|---|---|---|
| mote | Arcane Mote | Cheap, reliable single-target bolt | | |
| needle | Glitch Needle | Very fast piercing sliver | Crit, Glitch | |
| lance | Prism Lance | Instant beam, hits everything in a line | | |
| fan | Spectrum Fan | Seven-bolt spread for crowds at close range | Multi | |
| moths | Seeker Moths | Homing swarm that never misses | Multi | |
| frost | Frost Shard | Twin shards that chill | Frost, Multi | |
| spark | Chain Spark | Arcs between enemies | | |
| ember | Ember Bolt | Slow fireball, burning splash | Burn, Area | |
| burst | Rune Burst | Point-blank nova, big crit chance | Area, Crit | |
| seed | Payload Seed | Carrier: releases its payload where it lands | Carrier | |
| wheel | Starwheel | Carrier: slow spinning disc that fires its payload in a ring | Carrier | |
| disc | Boomerang Disc | Flies out, returns to you, pierces everything both ways | | **new** |
| mine | Glitch Mine | Tossed ahead, arms after 0.35 s, blasts when an enemy steps close (or after 4 s) | Area, Glitch | **new** |
| static | Static Cone | Instant short cone, 70 px long and 70° wide, that hits everything in it | Area | **new** |
| null_orb | Null Orb | Slow orb that pulls enemies in and grinds anything it touches (hits every 0.25 s) | Glitch | **new** |

**Numbers for the new spells (level 1/2/3):**

| Spell | Mana | Damage | Other |
|---|---|---|---|
| disc | 6/8/10 | 9/13/19 | speed 210, turns back at 45% life, life 1.4 s |
| mine | 5/7/9 | 22/34/52 | blast area 26/30/34 |
| static | 4/6/8 | 8/12/17 | |
| null_orb | 9/12/15 | 5/7/10 per tick | speed 55, life 2.6 s, pull 55 px/s within 44 px |

## Boosts (17)
Existing, unchanged: empower, quicken, seek, phase, ricochet, twin, chorus, shatter, heavy, wide, linger, keen, ember_coat, frost_coat, mirror.

| id | Name | Effect | Tags | New |
|---|---|---|---|---|
| split | Split Rune | On its first hit a bolt splits into 2/3/4 bolts at ±25°, each with 40% damage | Multi | **new** |
| gravity | Gravity Rune | Spells pull enemies within 40 px toward their path (40/65/100 px/s) | Glitch | **new** |

## Triggers (5)
Existing: then, callback, loop, fork.

| id | Name | Effect | Tags | New |
|---|---|---|---|---|
| finally | Finally | When the left spell kills an enemy, cast the right one from the corpse, aimed at the nearest enemy. Once per spell (up to 1/2/3 times with pierce) | Trigger | **new** |

## Passives (3)
cache, regen and heatsink, unchanged.

## Relics (28)

| id | Name | Rarity | Effect | Tags | Status |
|---|---|---|---|---|---|
| hot_patch | Hot Patch | C | Max HP +20, heal 20 | Survival | kept |
| garbage_collector | Garbage Collector | C | Each kill refills 3 mana in every wand | Economy | kept |
| lucky_bit | Lucky Bit | C | +10% crit chance | Crit | kept |
| iron_stack | Iron Stack | C | Take 15% less damage | Survival | kept |
| spare_battery | Spare Battery | C | Wands hold 30% more mana and regenerate 20% faster (absorbs Cache Line) | Economy | changed |
| hotkey_boots | Hotkey Boots | C | Move 15% faster | Survival | kept |
| blast_radius | Blast Radius | C | Explosions are 35% larger | Area | kept |
| interest | Compound Interest | C | +25% gold; +3 gold per room while holding 60+ | Economy | kept |
| leech_loop | Leech Loop | C | Every 6th kill heals 4 | Survival | kept |
| afterimage | Afterimage | C | Invulnerability after a hit lasts 50% longer | Survival | kept |
| sandbox | Sandbox | C | Spikes can't hurt you | Survival | kept |
| bounce_core | Bounce Core | C | Every spell bounces off walls once more | | kept |
| busy_wait | Busy Wait | C | Stand still for 0.6 s: your next cast deals +60% | | **new** |
| buffer_overflow | Buffer Overflow | C | Healing above max HP becomes a shield (up to 30) that absorbs hits | Survival | **new** |
| overclock | Overclock Chip | R | Wands cast and recharge 15% faster | | kept |
| heap_overflow | Heap Overflow | R | +30% damage, max HP −20 | | kept |
| try_catch | Try / Catch | R | The first hit you take in each room is ignored | Survival | kept |
| recursion | Recursion Charm | R | Spells cast by triggers and carriers deal +30% | Trigger, Carrier | kept |
| aperture | Wide Aperture | R | Multi-bolt spells fire one more bolt | Multi | kept |
| null_pointer | Null Pointer | R | The first hit on an unhurt enemy deals double | Crit | kept |
| deadline | Deadline | R | +40% damage for the first 6 s of each fight | | kept |
| stack_trace | Stack Trace | R | Every 7th cast also fires backward | Glitch, Multi | **new** |
| bug_bounty | Bug Bounty | R | Kills release a small seeking bug (a homing bolt, 10 damage) | Carrier | **new** |
| cascade_failure | Cascade Failure | R | Crits arc to the nearest other enemy within 60 px for 50% | Crit | **new** |
| wildfire | Wildfire | R | Burning enemies spread their burn to enemies within 36 px when they die | Burn | **new** |
| cold_boot | Cold Boot | R | Chilled enemies take +25% damage | Frost | **new** |
| echo | Echo Crystal | E | 15% chance a cast repeats for free | Multi | kept |
| event_loop | Event Loop | E | Triggers and carriers release their payload twice, the second at 60% | Trigger, Carrier | **new** |

**Cut:** cache_line (merged into spare_battery) and keen_scope. The auto-aim reach it gave is now standard (+20% base).

## Icons (0.4)
Every item gets a 12×12 illustration inside a 16×16 frame (see `scripts/art/icon_art*.gd`).
- **The frame shape shows the kind:** round for shooting, diamond for boost, notched tile for trigger, square for passive. Relics sit in a gold medallion.
- **Illustrations show the role**, not a letter:
  - a returning disc with a curved arrow
  - a mine with a blinking light
  - a lightning cone
  - a black orb with a ring
  - a splitting bolt
  - a gravity well spiral
  - a checkmark-arrow for "Finally"
  - and so on
