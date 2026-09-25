# 0011. The MVP is re-planned design-first

- Date: 2026-09-25
- Status: Accepted
- Supersedes the milestone order in ADR 0010. ADR 0010's scope amendments and its store milestones M10–M11 still stand, but they now run after the design milestones.

## Context
ADR 0010 planned the MVP infrastructure-first: CI, content as data, splitting `world.gd`, a new UI, then content, and finally the store.

Bar redirected it: "focus on improving the game design, the level design, the graphics, the animations, the music, etc. research design and re-plan". He also asked for spells and relics research drawing inspiration from Magicraft's logic and design.

Four sourced briefs followed. They are in `research/design-research.md`:
- game design and level design
- graphics and animation
- music, sound and feel
- spells and relics

Their central diagnosis is that wand building is optional *by construction*:
- spells slot themselves into your wand
- enemies have only HP
- mana never runs short

The art, audio and feel each fail in specific, fixable ways, listed in that file.

## Decision
- **The MVP is defined by game quality.** The plan is `research/design-plan.md`, milestones D0–D9:

| Milestone | Scope |
|---|---|
| D0 | Design bible, plus quick wins on feel and audio |
| D1 | Art direction |
| D2 | The spell system (52 spells, including Debugger runes and familiars; resist keywords; statuses; cast-tree preview) |
| D3 | Relics (38, including duos, Corrupted, and Compile evolutions) |
| D4 | Enemies and encounters (10 archetypes, affixes, wave grammar) |
| D5 | Levels and the 3-lane map |
| D6 | Animation rigs and VFX |
| D7 | Bosses |
| D8 | Music and sound |
| D9 | Onboarding curriculum and meta |

- **Design pillars:**
  1. Your wand is the answer.
  2. You can read the program.
  3. Every hit lands.
  4. Figures pop off the ground.
  5. Short, dense runs.
- **Architecture work (content as data, the Stats/Hooks effect system, splitting `world.gd`, Control UI) happens only when a design milestone needs it.** It is not a milestone of its own.
- **After D9:** ADR 0010's M10–M11 (store-ready at $0, then the betas behind the accounts gate), plus CI.
- **Constraints stay:**
  - Art is drawn in code.
  - Budget is $0.
  - Audio is CC0 or CC-BY, recorded in a licence manifest.
  - Content is original (ADR 0002). Magicraft informs mechanics only; every name, text and number is ours.
  - "Echo Crystal" and "Split Rune" get renamed to stay clear of Magicraft's names.
- **The main acceptance test is a two-bot balance bench:**
  - A bot that edits its wand survives 60–80% of runs.
  - A bot that never edits survives only 15–30%.
  - Editing is therefore required by design.

## Consequences
- **Builds:** every milestone ends with a web build and an APK for Bar, who reviews that milestone's focus. That means feel, art sheets, run length, bosses, and music picked by ear.
- **Balance:** it will move a lot, especially in D2 and D4. The bench bands above replace the old single 70–80% survival target.
- **Architecture debt:** it is paid down gradually, alongside the features that need it.
- **Store work:** the store release moves later. The store-ready work from ADR 0010 is unchanged, only reordered.
