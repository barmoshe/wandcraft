# 0023. Design v3: look and sound finished, fights and runs that differ

- Date: 2026-09-26
- Status: Accepted
- Builds on ADR 0022 (design v2). Plan and sources: `research/design-v3.md`.

## Context
Bar asked again for a full research-and-reinvent pass. Asked what felt weakest in 0.15.0, he answered "looks/sounds unfinished", and chose code-generated assets only (no packs). The audit found generic combat visuals, bosses that are not events, runs 2-3 identical to run 1, economy without decisions, and phone perf with no headroom.

## Decision
Milestones V0-V7 in `research/design-v3.md`: playtest log + phone budget, art direction v3 (scale, colour roles, two distinct areas), VFX/juice v3 (the Vlambeer checklist), bosses as events (+ a second mini-boss), audio v3 (generated, adaptive), screens v3, runs that differ (Grove enemies, room objectives, shop/heal/risk decisions, reachable power spikes, mechanical heat, gentle mode), then the store refresh and the friend playtest. Art and audio stay generated in code (Bar, 2026-09-26).

## Consequences
Presentation work comes before depth, as Bar's complaint ranks it. Each milestone ships web + APK builds and screenshots.
