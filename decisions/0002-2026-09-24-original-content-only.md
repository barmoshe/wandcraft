# 0002. Original content only: mechanics yes, Magicraft's names, text, numbers and art no

- Date: 2026-09-24
- Status: Accepted

## Context
Prototypes v3-v5 used Magicraft's spell, relic and wand names, paraphrased descriptions and wiki balance numbers. Magicraft is by Wave Game, published by bilibili.

The App Store guidelines rule this out for a store release:
- 4.1(a) and 4.1(c) forbid copycats and using another product's names.
- 4.3(b) was tightened on 2026-06-08.
- 5.2.1 bans "copycat representations, names, or metadata".

Case law points the same way. Mechanics are not protected. Text, art, audio and the overall look and feel can be: Tetris Holding v. Xio (2012), and Spry Fox v. 6waves, which settled. Sources are in `research/app-store.md`.

Bar chose "Original content" on 2026-09-24.

## Decision
- **Kept:** the systems. Wand programming (slots read left to right), boosts, trigger boosts between spells, carriers with payloads, summons, relics, door-choice rooms, and 5 worlds with 10 bosses.
- **Replaced:** every spell, relic, wand, enemy and boss gets a new name, our own description and numbers from our own balance formulas.
- **Created from scratch:** all art, audio and UI.
- **Title and fiction:** the title, icon and fiction ("the Glitch" corrupting five realms, software-bug humor) are ours.
- **Signature twist:** we add one mechanic of our own, currently a Glitch-themed "Debugger" rune class.
- **Metadata:** "Magicraft" never appears in the app, keywords, screenshots or descriptions.

## Consequences
- The content catalog is redesigned in M2 rather than ported.
- A name and trademark check on "Wandcraft" is needed before submission.
- Before a paid launch it is prudent to get a short legal opinion, because the rights holder is a large publisher.
