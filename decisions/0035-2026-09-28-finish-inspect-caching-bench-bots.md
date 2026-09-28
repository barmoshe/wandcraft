# 0035. The 0.22 plan finished: hold to inspect, cached web files, two bench bots (0.23)

- Date: 2026-09-28
- Status: Accepted
- Follows ADR 0033 (0.22 polish) and ADR 0034 (music as Ogg Vorbis). Numbers: `research/balance-w1.md`.

## Context
Bar, after 0.22 shipped: "finish all the work". Four things were left from the 0.22 plan and its "Next" list:
- The benches had not been run with the dodging bot.
- Two pack wands were flagged.
- Web files were cached for 10 minutes only.
- Hold to inspect had not been built.

Music as Ogg Vorbis was the fifth item (ADR 0034).

## Decision
**Hold to inspect.**
- A finger held still for 0.4 s on a reward card, a shop item, a wand or bag slot, or a relic in the pause menu shows its title and full text, on a dimmed screen.
- Lifting the finger then does nothing, so a hold never picks, buys or moves anything. A drag is never a hold.
- It lives in `Screen` (`inspect()`, `_tick_hold`, `_release`).

**Web caching.**
- The export's wasm, js and worklets get one content hash, and the pck its own (`GODOT_CONFIG.executable` and `mainPack`). A game update downloads only the new pck.
- Hashed files are served `immutable` for a year, and `index.html` is `no-cache`.
- `vercel.json` moved to the repo root, since a git build reads it only there.

**Two bench bots.**
- The dodging bot cleared World 1 in 10 of 10 seeds. It dashes over a hundred times a run and reads every telegraph: it plays like a skilled player.
- The new-player band (25 to 45%) was set in 0.18 for a bot that never dashes, so that bot is back for the band (`World.bot_dash`). It clears 40%.
- The dodging bot is reported beside it and must clear World 1 in at least 60% (it clears 100%, and wins 60% of full runs).
- The game was not made harder to fit the dodging bot.

**Pack wands.**
- **Concurrency:** Worker Thread's range goes from 190 to 260 (Copy-Paste's jumps left it idle). x1.53 becomes x1.39.
- **Linker:** the Singleton Wand casts every 0.2 s (was 0.14) and recharges in 0.8 s (was 0.5), with +5% per different spell (was +8%). x0.54 becomes x0.76.
- **Unsafe Staff:** 1 HP per 15 mana (was 25) and +40% damage (was +50%).
  - The god-mode pack bench leaves HP as its only cost, so it wins short fights fast and runs dry in Deadlock. It is held to no power creep only.

**First run.**
- The intro keeps its four voiced panels (SKIP is on the first).
- Lesson 1 still opens the editor: Empower is the first edit the curriculum teaches (`test_onboarding_d9`).

## Consequences
- Tests: 442 pass. The tap test adds a real-touch hold, and the overlap audit adds two inspect cases. Every bench passes.
- Progress is kept (save epoch 4).
- **Still open:**
  - The Ogg loops and the hold timing on a phone.
  - The cache headers on the live site. `tools/webtest.sh <url>` checks them.
  - A human playtest of the new balance.
