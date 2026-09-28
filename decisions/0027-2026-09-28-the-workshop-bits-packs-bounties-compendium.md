# 0027. The Workshop: a playable hub, Bits, packs, bounties and the Compendium (0.19)

- Date: 2026-09-28
- Status: Accepted
- Builds on ADR 0026 (0.18). The research and design are in `research/workshop-0.19.md`, and the plan in `~/.claude/plans/eventual-cuddling-glade.md`.

## Context
Bar's asks after 0.18:
- A lobby that is "a playable hub area, inspired by Magicraft", where pre-game actions are objects and characters in the world ("1 store can sell packs of new spells").
- "Replace the codex mechanism and achievement mechanism."
- "Be creative, research, reinvent: the best 0.19 you can."

The game before this:
- The title menu held every pre-game action.
- The hero was picked from an orb in the start room.
- Settings could only be reached from pause.
- Nothing carried over between runs except design v2's goals, and every non-core item was locked behind one.

## Decision
- **The Workshop** replaces the title menu. It is a one-screen room walked with the run's own controls:
  - **Stations:**
    - the Portal (the run sheet: new, continue, daily, heat)
    - the Hero Hall
    - the Merchant
    - the Wand Bench with a training dummy that shows DPS
    - the Bug Bounty Board
    - the Compendium
    - the Commit Wall
    - the Terminal (settings and credits)
    - the Duck and LINT
    - boss trophies
  - **Using a station:** a station opens with a USE button that appears in the dash slot, or E and Enter. Only the portal opens when you walk into it. MENU lists every station.
  - **The run behind it:** the room plays on a sandbox run that is never saved and never counts.
  - **The title** is a card over the live Workshop. A first launch goes from the card to the intro to the lessons run.
- **Each hero has its own look:** the Pyromancer and the Tinkerer.
- **Bits** are a currency that carries over between runs:
  - A run pays for its rooms, bosses, the Loop and a win, with a bonus on the first three runs, times the heat.
  - Bounties pay more, claimed at the board.
- **Packs** are fixed and shown before you buy, and they unlock content, never power:
  - Five legacy packs hold what goals used to open.
  - Four new `.pkg` packs add 12 spells, 4 relics and a wand.
  - Opening one is a moment (`$ pkg install`, then cards flip in with the rarest last), and it can be skipped.
- **Bounties replace goals:**
  - There are 21 tickets and the board pins three at a time.
  - Progress counts before a ticket is shown.
  - A fixed ticket opens its items at once.
- **The Compendium replaces the Codex:** spells, relics and wands move from seen to used, and enemies add field notes after 5 kills.
- **The Commit Wall** keeps each run as a commit, beside the story's log.
- **Migration** (`meta_v` 2):
  - Every goal already done stays done as a bounty, and everything it opened stays open.
  - Its Bits are paid as back pay.
  - A legacy pack whose items were all open counts as owned.

## Consequences
- Settings can be reached before a run, at the Terminal.
- The start orb is only for old saves and for tests; a run started from the Workshop has its hero already.
- The Merchant opens after one run, and the Bench after two; the rest are open from the start.
- The Workshop adds 35 voiced lines, fitted to how the last run went (`Hub.greeting`).
- **Tests:**
  - `test_hub` checks that the room fits and is reachable, that walking opens only the portal, that nothing is saved, and the fire zone, the DPS readout and the station screens.
  - `test_packs` covers Bits, locking and migration.
  - `test_hero_looks` covers the per-hero looks.
  - The tap test adds a hub phase.
- **Deferred:** wand share codes, a weekly seed, an IDE-styled hub, hero palettes as a way to spend Bits, and switching a pack's items off.
