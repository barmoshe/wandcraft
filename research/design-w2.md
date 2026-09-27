# Wandcraft: the first playtest round, and World 2

## Context

- **The first friend playtest ran on 27/09.** It used the web link and the APK, shared in a WhatsApp group and with friends.
- **Testers:** Yossi, JM, Rom, Maor and Yoaviko.
- **What they liked:** it's cute, it reminds them of Enter the Gungeon, and they want to follow it until release.
- **Bar's ask after reading it:** fix and improve everything they raised. Then build at least two worlds, since today there is only one.

## What the testers found, and what changed (0.16.1)

| Finding (who) | Cause | Fix |
|---|---|---|
| Auto-aim at the last boss doesn't aim at the snake (Yossi); auto-aim fires at the wall (JM) | Three causes. (1) Standing against the top wall put the wand's cast point inside the wall tile, so shots spawned in the wall and died, and line-of-sight failed. (2) The straight-line lead sent shots at a tangent off a snake running an oval. (3) With a mouse, assist snapped the shot up to 26° toward any enemy, even one behind the pillar. | Spells leave from the grip, or the waist when the grip is in a wall. The lead follows the Loop's path, using the bolts' real speed. Assist needs line of sight, and a mouse gets a narrow cone. |
| Stuck on entering the boss (JM) | The Loop pre-drew its head at 16 angles for every frame when it spawned: 2.2 s on a Mac, longer on the web | Each angle is drawn on first use with a faster sampler: 15 ms |
| The last phase's head is faster than you, so you can't escape (JM) | It chased at 110 px/s against the player's 92 | 78 px/s, steering round pylons as a slim body |
| Outside the snake's inner circle the fight is much easier (Maor) | The track never left its circle | The Lap Charge swings the track to your lane, with an oval warning that shows exactly where |
| Fireballs that should have hit me didn't (Maor) | The hurt zone was a circle at the waist, so shots through the head passed | A capsule from waist to head, the same width |
| Copy-Paste has no wand (JM) | Never drawn | It holds a copy of your wand (same gem) and shoots from its tip |
| The wand's position (Rom, Maor) | The grip sat at the centre of the hips | It's held in the drawn hand at the side |
| The end screen's goal text overflowed (Yossi's screenshot) | Fixed line offsets | Measured lines, and a taller panel |
| The camera goes wild in room 7 (Yoaviko) | In big rooms the view led 16 px toward the aim, and auto-aim flips between targets in a swarm. Every shot also kicked it 3 px. | It leads by walking direction, eased. Kicks are half as strong. Auto-aim keeps its target until another is clearly nearer. |
| Very easy (Yoaviko, Maor) | Measured against the bench after the fixes | See the balance section of the progress log |

## World 2: The Overheated Foundry

**Shape:**
- A run is two worlds.
- When the Infinite Loop falls, its exit door leads on to World 2. It no longer ends the run.
- World 2 has the same shape as World 1: a start room, 4 rooms, a mini-boss, 4 rooms, then the boss.
- `RunState.world` counts worlds, and `step` counts rooms within the world. `Chapter.PLAN` stays per world, so the map, doors and tutorial code keep working.

**The place:** a server foundry running hot. Rust-red iron plates, glowing orange seams and heat shimmer. It's warm where World 1 is green and violet, so the change reads at once.
- **The Cooling Vents** (first half): steel-blue with steam.
- **The Molten Core** (second half): lava cracks and embers.

**New enemies:** each has one job and one counter.
- **Proxy:** a shield-bearer whose front blocks shots. The counter is flanking, homing or bouncing spells.
- **Kernel Panic:** at half HP it panics, runs in a circle, then bursts into a ring. The counter is killing it fast (burst damage) or keeping your distance.
- **Spark Plug:** dashes in straight lines and leaves a short-lived arc behind it. The counter is reading the line and dodging.

World 1 enemies join them with more elites, and HP scaling continues from World 1's last room.

**Mini-boss:** the one you didn't meet in World 1 (Copy-Paste or the Garbage Collector), stronger.

**Boss, Deadlock:** two locked guardians, Mutex A and Mutex B, joined by a beam.
- Only the unlocked one takes damage. The lock swaps every few seconds, and when the open one has taken enough.
- The beam between them sweeps the arena, so you dodge it while you pick which one to hit.
- **Phase 2:** they close in and the beam turns faster.
- **Phase 3:** both locks break, but they fire in turn.
- Kill both to clear the world.

**Goals:** "Win a run" now means clearing World 2. "Defeat the Infinite Loop" is a new goal that takes over the old first-win unlock (the Tinkerer), so a first-time player still unlocks something at the old point.

## Progress log
- `290f37b`, `0947d83` (0.17.0): the playtest fixes and World 2.
- 0.18 (ADR 0026): the descent screen between the worlds (`5d18b84`), the Foundry's voiced entry (LINT: "Temperature: unwise"), the difficulty passes (`f900b93`, `2b6a2bf`, `bc4acc3`), and Deadlock: its subtitle now says what it asks, and auto-aim prefers the open lock so single-target wands can break it (`060d64c`).
