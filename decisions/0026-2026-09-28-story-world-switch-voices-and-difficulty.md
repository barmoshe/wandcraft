# 0026. The story, the world switch, two voices, and a harder game (0.18)

- Date: 2026-09-28
- Status: Accepted
- Builds on ADR 0024 (two worlds) and ADR 0025 (sound v2). The plan is `research/plan-0.18.md`; the details are in `research/story.md`, `research/voices-plan.md`, `research/difficulty.md` and `research/magicraft-progression.md`.

## Context
Bar made four asks after the first playtest and 0.17:
- Make the switch between worlds clearer and more fun, and improve the storyline.
- Give the story a robot narrator that speaks, with both the Duck and a robot talking, in real words, pre-rendered.
- "The game overall is too easy, also the bosses and AI enemies. Maybe less start HP?" The testers had said the same.
- Keep going on the Magicraft lessons.

## Decision
- **Story:** the run is a descent down the bug's stack trace (`root_cellar()` → `foundry()` → `kernel()`).
  - It is told a line at a time, never in the way:
    - story beats on the HUD
    - ten commit-log entries collected in a Codex LOGS tab
    - intro and ending panels, each shown once
    - the Duck's word on the end screen
  - Between worlds, a descent screen shows the trace, the hero dropping a frame, what's new in the next world, and the world-clear bonus (+10 max HP and a full heal).
- **Voices:** the Duck and LINT, the Guild's linting robot, speak every line (78).
  - The lines are rendered offline with Kokoro-82M (Apache-2.0), and each speaker's processing chain is baked in, because the web build can't run bus effects.
  - Kokoro runs through `kokoro-onnx`, since PyTorch has no Intel-Mac wheels.
  - The text always shows as subtitles. A `Dialogue` autoload plays one line at a time and dips the music 6 dB.
  - The Duck's non-verbal babble from sound v2 is retired.
- **Difficulty:** harder through what a mistake costs and how enemies behave, not by adding HP.
  - Start HP goes from 120 to 80 (100 for the Apprentice).
  - Each hit costs more, and costs more the deeper you are.
  - Healing is about half what it was.
  - Enemies aim half a step ahead from the Grove on, shoot sooner, and their waves overlap.
  - A boss's last phase winds up and recovers faster.
- **Heat changes rules, and pays for them:**
  - Heat 2 means enemies hit harder. Heat 5 means bosses play their last phase early.
  - Each tier adds +10% gold and better spell odds.
- **Rewards for skill:** a boss beaten without a hit leaves a second, Untouched orb.
- **Deadlock** says what it asks for. Auto-aim now prefers the open guardian, because a single-target wand could not break it before.

## Consequences
- **Bench:** the bench's balance band moves down, because the bot never dashes and humans found 60% easy.
  - The editing bot now clears World 1 25-45% of the time and wins the full run 5-15%.
  - It last measured 40% and 10%.
  - Target fight lengths: the Loop 50-100 s, Deadlock 60-110 s. Rooms should average under a minute.
- **Changing a line** means running `tools/voices.sh`. The unit tests fail if a line's text and its file drift apart.
- **The voice picks** (af_heart for the Duck, am_fenrir for LINT) were chosen by a Whisper intelligibility check, not by ear. The audition set in `shots/voice-audition/` is there for Bar to overrule them.
- **Playtest round 2** judges all four changes on real players, using the run logs (`window.wandcraftRunLog()`).
