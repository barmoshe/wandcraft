# 0033. Polish: the audit's fixes, quiet fights, clarity, accessibility, size (0.22)

- Date: 2026-09-28
- Status: Accepted
- Follows ADR 0031 (NPCs in the world) and ADR 0032 (arsenal and story round 2). Research: `research/polish-0.22.md`.

## Context
Bar, after 0.21: "Research design fix and improve the game." His note on a 0.21 boss screenshot was "this is overwhelming".

Three research passes fed this:
- An audit of the open issues and the feedback so far.
- A code audit of 0.20 and 0.21. It found no crashes but 16 bugs: disk reads in fights, three exploits, lost story lines, daily fairness, and bot runs that wrote to the save.
- Sourced web research on mobile roguelites, big card pools on small screens, game feel and accessibility, and Godot on the web.

Bar chose:
- Quiet in fights.
- All four focus areas: clarity, feel and accessibility, speed and size, balance.
- Ship to `main` and the web, keeping progress.

## Decision
**Fixes**
- `SaveGame` keeps the parsed meta record: every read returns a copy, and every write refreshes it. The Workshop draws from a snapshot, and assist reads settings only. A fight no longer touches the disk (`SaveGame.meta_reads`).
- **Exploits closed:**
  - LINT's review is per wand.
  - Hot-Reload needs 2 s on the belt.
  - The Altar costs HP while Fixed Vitals is held.
  - Relic Copy turns once and never copies Fixed Vitals.
- **Story kept:**
  - A walked-away resident beat waits for the next talk (`Residents.rewind`).
  - A cut line takes its bubble (`Dialogue.line_cut`).
  - The post-mortem is spent only when said.
  - Freed residents speak as the cage opens.
- **Fewer barks:**
  - No barks in the Workshop sandbox, dailies or lessons.
  - No Red Squiggle in a daily.
  - Bark flags reset each room.
- **Smaller fixes:**
  - Unsafe Staff refunds and lines.
  - Pair Programmer's trigger bonus and its pairing after an edit.
  - Decorator Rod at End Block and the wrap.
  - Companions stay out of walls.
- Bench and demo runs never write the player's Workshop.

**Quiet in fights**
- Mid-fight, only low HP, a boss phase and a rule wand's first cast speak.
- The best of the rest is said when the room clears (`World.bark`, `_flush_barks`).

**Clarity**
- "NEW" on reward cards and Merchant items seen for the first time (`Meta.is_new`/`mark_seen`).
- A "Fits your wand" chip on the reward that switches on most or adds most damage.
- Tapping a tag chip explains it (`Glossary.KEYWORDS`).
- Every tap target is at least 32 base px (44 pt), and overlapping targets go to the nearest.

**Feel and accessibility**
- Shake and flash at 100%, 50% or off.
- Reduce motion, which follows the browser on the web.
- Large text for the messages over play: bubbles, tips, toasts and the speech box.
- Assist at 25% or 50%: less damage taken, slower enemy shots, a wider auto-aim cone. It replaces Gentle, and a daily result shows ASSIST.
- Crit hit-stop is 60 ms.
- Vibration on native builds only.
- The overlap audit reports tap targets that are too small.

**Speed and size**
- Voices import at 22.05 kHz: the pck goes from 29.4 to 28.3 MB.
- An audio budget test (28 MB imported).
- `tools/size_report.sh`.
- The pck gets a content type.

**Balance tooling**
- The bench bot dashes out of telegraphed boss attacks and incoming shots (`Boss.bot_threat`, `World._bot_*`).

## Consequences
- **Tests:** 436, all green.
  - New: `test_polish_0_22` (13), `test_settings` (7) and `test_audio_budget` (2).
  - `tools/uiaudit.sh` is clean at phone, iPad and desktop sizes, and with large text on the HUD cases.
- **Not in this release:**
  - **Bench numbers with the dodging bot.** The balance pass was stopped before it measured them, so they come next.
  - **Music as Ogg Vorbis.** It needs an ADR to replace 0019.
  - **Long cache headers.** They need hashed file names first.
  - **Large text in fixed menu layouts.**
