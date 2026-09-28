# 0029. Triggers become a pack, the third lesson is fixed, the wizard holds his wand, and the Kernel is tuned (0.20)

- Date: 2026-09-28
- Status: Accepted
- Follows ADR 0028 (0.20, the Kernel). Supersedes ADR 0020's third lesson (the first trigger) and ADR 0028's Data Race numbers (2 s window, 40% respawn).

## Context
Bar played 0.19 on a phone and sent a screenshot of the wand editor during the third lesson, with three asks: "Fix the wizard and the game logic. And also triggers should become a pack and not received so soon."

The screenshot showed three problems:
- **The game logic:** the trigger lesson assumed the wand already held two shooting spells.
  - A player who took Phase (a boost) in lesson 2 had only the Mote. There was no valid place for THEN, so the coach lit the Mote's own slot and said "drag THEN onto the lit slot".
  - The preview then ran out of mana.
- **The wizard:** in the editor's firing range (and in play), the wand came out of his belly.
  - The cast "hand" was a fist drawn inside the torso at hip height, shown only while casting.
  - The grip was at the lower shirt.
- **Pacing:** triggers came in the first run's third room, before a player had a wand worth chaining.

The first Kernel bench (a World 3 run from its start room, with a mid-game kit) also found problems:
- **The bench itself was broken:** the start room's hero orb swapped the kit for a one-spell wand.
- **World 3's numbers were too big:** enemy HP and damage kept climbing linearly past Deadlock.
- **Data Race** ended half the runs.
- **A Page Leak** that backed away, together with the bot's fear of puddles, stalled a run for an hour.

## Decision
- **Triggers are a pack.**
  - Then, Callback and While Loop leave `Meta.CORE_SPELLS` for a new Triggers pack at 30 Bits, the cheapest, so it is first on the Merchant's shelf.
  - A first run pays for it (the Merchant opens after one run).
  - Payload Seed stays core, since the Tinkerer starts with it.
  - The two-trigger bounty is hidden until the pack is owned.
- **The third lesson teaches a second shooting spell.**
  - The prize is Ember or Frost, placed just left of the last shooting spell so every boost powers it too.
  - The wand still grows a slot for it.
  - The coach reads "A wand fires its spells left to right, one per shot, and boosts power up every spell on their right."
  - A test replays Bar's case (Phase in lesson 2) and both pierce picks.
- **The wizard holds his wand:**
  - A forearm and fist (`Hero.HAND`) held out at chest height in every front-facing pose.
  - The hanging right arm taken off the torso for every hero look (`Hero._arm_out`).
  - The grip moved to the fist (`Player.GRIP` (9, -18)), and the wand drawn under the body, so the fist closes over the shaft. Copy-Paste matches.
- **Kernel tuning:**
  - Past Deadlock, depth counts a third as fast for enemy HP, damage and the encounter budget (`Chapter.scale_depth`).
  - Enemies: the Dangling Pointer hits 8 (was 10) and snaps every 2.8–3.6 s. The Page Leak never backs away and closes in when it can't see you.
  - The Kernel's anchor pool drops the Rune Sentry for the Puffcap. World 3 boss bullets are ×1.35.
  - Data Race: threads of 440 HP, World 1 bullet damage, smaller bursts and rings, a 3 s window and a 30% respawn.
  - The Glitch has 3,400 HP, and each revert glyph takes 6%.
- **Bench:**
  - `test_kernel_balance` keeps its kit (`picked`) and starts at 140 HP.
  - `BENCH=kernel tools/balance.sh` runs only the Kernel bench.
  - The bot treats a puddle as a small cost, not as danger.

## Consequences
- **A new player's first run is simpler:** a boost, pierce, then a second spell. Triggers become the first thing a player buys with Bits, the moment the wand has two spells worth joining.
- **Old saves lose triggers until they buy the pack.** This is deliberate: Bar asked for triggers later, and the pack costs one run's Bits.
- **Tests:** the range fixtures moved the hero 3 px left so a straight-up shot still leaves where it did (`test_arsenal`, `test_spells_*`, `test_enemies_d4`, `test_relics_d3`, `test_world_two`, `world_fixture`); the pack and shelf tests expect the Triggers pack first.
- **The Kernel is still hard for the bench bot,** which never dashes and doesn't play Data Race's rule (it kills the nearest thread). The numbers are in `research/world3-0.20.md`; the phone playtest decides the next pass.
