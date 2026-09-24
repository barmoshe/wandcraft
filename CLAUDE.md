# wandcraft — CLAUDE.md

Per-project context. Loads only when working in this folder. Business-wide rules live in the repo-root `CLAUDE.md`.

- **What it is:** A pixel-art twin-stick roguelite for iOS and Android, built around wands you program like tiny code: spells fire left to right, boosts modify everything to their right, and triggers chain one spell into another. It grew out of the Wandcraft HTML prototypes (v1-v5, private claude.ai artifact) and is being rebuilt from scratch for the stores.
- **Stack:** Godot 4.7.2 (GDScript, typed), Mobile renderer. The game is in `game/`, and deterministic asset and audio generators are in `tools/`. iOS export and signing happen on Bar's Mac (Xcode 26); everything else runs on Linux.
- **Build lives in:** `game/` (Godot project). Run the tests with `tools/test.sh` and render screenshots with `tools/shots.sh`.
- **Local conventions:**
  - **Content is original.** No name, description, number table or art may be copied from Magicraft or any other game (see `decisions/0002`). The mechanics are free to use.
  - **Simulation code** (`game/scripts/sim/`) never touches nodes, so it stays testable headless.
  - **Game content is data:** typed `Resource` classes (`SpellDef`, `WandDef`) in `game/scripts/sim/`, with the catalog as code tables in `catalog.gd` for now (`.tres` files can come later).
  - **The pixel base resolution is 480×270.** Never draw at a fractional scale.
  - **Secrets stay off git:** signing keys, keystores and App Store Connect API keys are never committed.
- **Canonical state:**
  - `STATUS.md`: where we are.
  - `brief.md`: the immutable ask.
  - `scope.md`: acceptance criteria.
  - `decisions/`: per-project ADRs.
  - `research/`: sourced notes behind the stack and store choices.
  - `store/`: the publishing checklist and metadata drafts.
- **Privacy:** there is no user data beyond local saves. No analytics, no ads and no tracking, so no ATT prompt is needed.
