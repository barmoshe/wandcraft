# 0028. The Kernel, the residents and two endings (0.20)

- Date: 2026-09-28
- Status: Accepted
- Builds on ADR 0026 (the story, the world switch, the voices) and ADR 0027 (the Workshop). The research and design are in `research/world3-0.20.md` (five sourced notes in `research/world3/`), the story in `research/story.md`, and the plan in `~/.claude/plans/research-design-folio-autonomous-cozy-avalanche.md`.

## Context
Bar's asks after 0.19:
- "Research design, work fully autonomous, improve the story and more NPC, more graphics, more worlds. Do your best."
- On the plan: "Be creative, be innovative. Research about roguelikes, research about storytelling, research about game hubs."

The game before this:
- Two worlds. The ending (at Deadlock) had already told the twist: revert, and "it was you".
- World 3, `kernel()`, was only a tease (`mkdir /world3`).
- Two speaking characters, the Duck and LINT. Nobody else lived in the Workshop, and nobody in a run was a person you met.
- One shared look for the room surroundings.

## Decision
- **World 3, the Kernel,** after Deadlock:
  - **Areas and look:** the Page Archive and Ring Zero, with eight new Style ramps (vellum, quill, amber, verdigris, void, brass, phosphor, nest) and two room themes. The Archive floor stays dark so bullet cores read.
  - **Surroundings per theme:** roots for the Cellar, chimneys and pipes for the Foundry, shelves and hanging pages for the Archive, rings, traces and the nest for Ring Zero.
  - **The same 11-step plan as the other worlds.** A shorter plan for World 3 was dropped: runs save at every room, and a full win stays near 30 minutes.
- **Three enemies, each with a counter** (their names avoid the relics Memory Leak, Null Pointer and Race Condition):
  - **Page Leak:** its puddles grow and slow you, and they all dry up when it dies.
  - **Dangling Pointer:** it draws a line, then snaps along it. Step off the line.
  - **Interrupt:** while it lives, one of your wand's boosts or triggers is suspended (`WandState.suspended`). It never takes a wand's only shooting spell.
- **Data Race,** the mini-boss: two threads on one track, each with its own HP. When one falls, the other has 2 seconds to fall too, or the first respawns at 40%. `Enemy.can_die` and `Boss.part_can_die` are the hooks.
- **The Glitch,** the final boss (commit a1f00d, author: you):
  - diff rows that burn
  - a stack unwind that echoes the Loop and Deadlock
  - a revert phase: the room is rewritten from the edges, and green revert glyphs rewind the boss and push the rewrite back
  - `Boss.bot_danger` and `bot_goal` teach the bench bot the new hazards
- **The residents** (`Residents`): Grep (World 1), Hotfix (World 2) and Cache (World 3), each caged behind a "Someone Caged" door (the third room, middle lane) until rescued.
  - **In the Workshop:** they move into corners of the room. Each has a five-beat arc gated on play, a word on the last run, and idle lines, with a "!" when a beat is ready.
  - **Services, never power:** Grep's Search (one true hint a run), Hotfix's Skin Forge (wand skins for Bits), Cache's Stacks (twelve Lost Pages, one per boss once she's rescued).
- **The story, taken further:**
  - Six commit-log entries, append only: LINT warned you, Grep approved your commit unread, the Duck was born at 16:59:01, Cache keeps the 16:58 backup, a kernel panic, and the fix.
  - A descending wall clock in each world's start room.
  - The ending moved to the Glitch, and every win reverts.
  - **The true ending:** after a win, with all three residents rescued and Grep's confession heard, the Glitch's fall offers REVERT or FIX FORWARD (CommitScreen). Fixing forward shows the true ending and LINT's first "I", and the Workshop holds a blameless post-mortem.
- **Rewards:** bounties for Deadlock, a rescue, a Lost Page and fixing forward, trophies for Deadlock and the Glitch, and meta v3 (a 0.19 win counts as Defeat Deadlock).
- **Sound and voice:**
  - The Kernel's music (B minor, 100 bpm, the Incantation "paged" on a celesta) and two ambience beds, "kernel" and "ring".
  - Kernel stingers, a Glitch entrance sting, and 17 new effects.
  - Kokoro voices for the three residents.

## Consequences
- Game code now reads the world as an index: `World.world_boss()` and `mini_boss()`, the biome arrays, and the encounter pools.
- **The Interrupt changes the wand program itself.** `WandProgram._spell_at` reads a suspended slot as empty, and every room start clears the suspension.
- **Story ids stay append only.** The new lines, ending panels and true-ending panels are voiced, and `test_story` accepts the new speakers.
- **Tests:**
  - `test_world_three` covers the three counters, the together rule, the revert glyph, the cage, the rescue, the arcs, Search, skins, pages, and the residents' corners.
  - `test_bosses_and_run` checks that the bot beats Data Race and the Glitch and clears all three worlds.
  - `test_kernel_art` checks every new drawing.
- **The audio budget is over its target:** 67 MB of source WAV against 56, and about 13.4 MB shipped against 12. Cutting the Kernel base stem to 16 bars would save 2.5 MB if it matters.
- **Deferred ideas** (scored in the research doc): scheduler rooms, regression-test enemies that replay you, `git bisect` runs, pull requests as gifting, a Workshop that compiles itself, and walls that syntax-highlight near your spells.
