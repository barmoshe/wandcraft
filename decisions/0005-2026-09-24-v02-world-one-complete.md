# 0005. v0.2 is "World 1, complete": the free tier ships first

- Date: 2026-09-24
- Status: Accepted

## Context
The plan's milestones run M2 (content for all 5 worlds), then M3 (run structure and UI). World 1 is the free tier (ADR 0003): it is what every player sees first, and it is what App Review plays. Research (`research/run-structure-and-mobile-ux.md`) points to three things:
- Magicraft's chapter 1 is about 15 rooms long. That is too long for a phone session.
- Its single-spell rooms read as weak, and its drops as "gacha".
- Players ask for more control over their build.

## Decision
v0.2 finishes one world end to end before adding breadth. It takes World 1's share of M2 and the core of M3.

- **Chapter:**
  - The route is start → 3 chosen rooms → mini-boss → 3 chosen rooms → boss, for about 10–15 minutes a run.
  - Each door shows its room type and reward.
  - The room right before a boss always offers a spring or a shop.
- **Every reward is a choice of 3 with a skip.** A tap inspects a card and a button confirms it. Skipping pays gold.
- **Spells:**
  - Three copies of one level merge automatically into the next level.
  - The forge upgrades a spell for gold.
- **Economy:** gold funds the shop (spells, relics, heal, wand) and the forge.
- **Wand editor:**
  - It opens anytime and pauses the game.
  - Tap-to-pick/tap-to-place and drag both work.
  - A fixed info panel explains the selected spell, a live cast preview shows the program, and a revert button undoes changes.
- **Relics:** about 20 original relics, glitch- and program-themed.
- **Enemies and bosses:**
  - Six World 1 enemies.
  - Two bosses ported from our own prototype designs: Copy-Paste (mini-boss) and The Infinite Loop (boss).
- **Saves and screens:**
  - The game saves on room entry and when the app is paused, and resumes into the pause menu.
  - A title screen, a death screen and a victory screen.
  - Settings for auto-fire, screen shake and flash.

## Consequences
- Worlds 2–5, their bosses and the paywall stay in later milestones (M2 breadth, M5 platform). The content pipeline built here (catalog, relic hooks, boss framework) is reused there.
- Keys, curses, potions and meta progression are deliberately deferred. Each is its own design pass.
