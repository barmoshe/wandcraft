# Wandcraft 0.21 "Speak Up": NPCs in the world, speech bubbles, no overlaps, arsenal and story round 2

**Bar's asks (28 Sep 2026, after 0.20):**
- "Fix the HUD and text elements overlapping each other, go over all the game."
- "The NPCs need to be in the world and not in the HUD. Above their head should be a speech bubble."
- "Research design, add more relics, more spells, more wands, improve story."

**Bar's choices:**
- The Duck and LINT become companions in runs.
- Residents talk in bubbles, and their service opens a compact panel.
- A medium content round.

Three research agents fed this. Some sites were blocked by the proxy, so those claims rest on search-result summaries of the cited page. *[I]* marks our own inference. Mechanics only: every name and number is ours (ADR 0002).

## 1. Speech bubbles (sources)
- **Stardew Valley:** ambient lines go above an NPC's head (`showTextAboveHead`, 3 s each, staggered starts). Talking to someone opens the full box. [1][2]
- **Cult of the Lamb:** a "(!)" bubble over a follower first; the conversation is a separate step. [3]
- **Hades II:** hub characters chat with each other when nothing urgent is on. [4]
- **Brawl Stars:** pins over the brawler in a match, with a 10 s cooldown. [5]
- **Celeste:** a fixed name colour per speaker. [6] **Animal Crossing:** a coloured name tag, and a hold to speed up the text. [7]
- **Rainswept:** an arrow over the speaker that follows them to the screen's edge. It is a cheap cue for a speaker who is off screen. [8]
- **Reading speed and legibility:**
  - Reading runs at 12 to 17 characters a second; game subtitles aim for 15 to 20. [9][10]
  - A line should stay up at least 1.5 s, and lines run 36 to 42 characters. [11]
  - Xbox Accessibility Guideline 104: name the speaker, and show direction for one off screen. [12]
- **Pacing:** too many bubbles in a fight are unreadable. Show one at a time, measured in real time. [13]

**What we took [I]:**
- The typewriter runs at 30 characters a second or faster. A line stays up for n/30 + max(1.5, n/15) + 0.5 s.
- 2 lines in a fight, 3 in the Workshop. The text is 150 px wide, 200 px at most.
- The bubble sits over the head with a tail. It flips under the speaker when the top or the HUD is in the way, and never covers the hero.
- A speaker who is off screen gets the bubble pinned at the edge, with an arrow toward them.
- In a fight the bubble is see-through (78%).
- The HUD box stays only for a voice with no body (a story beat, a resident not in the room).

## 2. Barks (sources)
- **Valve's dynamic dialog** (Elan Ruskin, GDC 2012): a query of facts, and rules with criteria. The rule with the best match wins, falling from specific to general. Facts are written back, which gives callbacks. [14][15][16]
- **Hades:** conversations in buckets filtered by prerequisites and weighted by priority. Story beats outrank the evergreen lines. [17][18]
- **Hades II, Hecate:** after a run she speaks to the most important thing, and the rest waits for the next night. [19]
- **Kasavin on Hades:** an endless game fights repetition with a large script plus reactive combinations. [20]
- **Firewatch:** moved from lines that interrupt each other to conversations that resume after an interruption. [21]

## 3. Mechanic seeds for the second arsenal round (sources)
| Source | Mechanic | Our seed |
|---|---|---|
| Balatro [22-26] | Blueprint (copy the card to the right), Brainstorm (copy the leftmost), Obelisk, Campfire, Ride the Bus | Pointer, Global, Code Coverage, Clean Build |
| Balatro 1.1 [27] | a new "drawn to hand" trigger | onLoad() |
| Brotato [28] | Handcuffs | Version Pin |
| Rift Wizard 2 [29][30] | channeling, one upgrade per spell, blood spells | Channel Rod, Unsafe Staff |
| Hades II [31][32] | Hexes charged by Magick, the Daedalus Hammer | (deferred) |
| Nova Drift [33][34] | super mods, mutually exclusive mods | Dependencies, Merge Conflict pairs |
| Megabonk [35] | unique items | Singleton Wand |
| Ball x Pit [36] | fusion | a Merge summon |
| Magicraft 1.2.9 [37] | Fusion Summon | a Merge summon |
| Slay the Spire 2 [38][39] | Neow's Bones, Ancients | (deferred) |

**Our thin builds**, counted in the working tree:
- **Spells:** Rot 2, Burn 3, Frost 3, Shock 5 (with 2 relics), Familiar 5 (with 1 relic).
- **Relics:** none are tagged Area.

## 4. Story (sources)
- **Hades II:** hub lines react to the last run and what you carried. [19]
- **Hades:** gifts fill a gauge that stops at a favour; a companion comes after. [40]
- **Cult of the Lamb:** loyalty from gifts and quests. [41] **Terraria:** mood depends on neighbours. [42]
- **Slay the Spire 2, Neow:** frames every death as coming back. [43]

**Ideas we took [I]:**
- A Duck post-mortem when you return to the Workshop, with the rest waiting for the next visit.
- LINT flags "code smells" in your wand, and heeding it unlocks a companion trick.
- Residents chat with each other.
- Companions bark in a fight, with callbacks later.

## 5. Sources
1. https://gist.github.com/M3ales/ba14a27c6a62a1ffafcec546043156d6
2. https://stardewvalleywiki.com/Modding:Dialogue
3. https://cult-of-the-lamb.fandom.com/wiki/Follower_Quest
4. https://steamcommunity.com/games/1145350/announcements/detail/521992119019110975
5. https://brawlstarswiki.miraheze.org/wiki/Pins
6. https://celeste.ink/wiki/Dialogues
7. https://nookipedia.com/wiki/Conversation
8. https://frostwood-interactive.itch.io/rainswept/devlog/52987/20-update-speech-bubbles-dialog-boxes-and-diary
9. https://blog.amara.org/2024/10/17/crafting-accessible-subtitles-the-critical-role-of-characters-per-second-cps/
10. https://salivity.github.io/game-development/article/optimizing-game-subtitles-for-readability-and-timing
11. https://subtitling.net/standards/subtitle-reading-speed
12. https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/104
13. https://github.com/justinlindh/human-in-the-loop/issues/725
14. https://gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through
15. https://www.youtube.com/watch?v=tAbBID3N64A
16. https://www.blog.radiator.debacle.us/2012/07/rule-databases-for-contextual-narrative.html
17. https://www.toolify.ai/ai-news/unveiling-the-secrets-of-hades-dialogue-system-104463
18. https://github.com/NikkelM/HadesDialogueExplorer
19. https://hades.fandom.com/wiki/Hecate/Quotes
20. https://culturedvultures.com/supergiant-hades-word-count-dialogue/
21. https://www.gdcvault.com/play/1024415/Do-You-Copy-Dialog-System
22. https://balatrowiki.org/w/Blueprint
23. https://balatrowiki.org/w/Brainstorm
24. https://balatrowiki.org/w/Obelisk
25. https://balatrowiki.org/w/Campfire
26. https://balatrowiki.org/w/Ride_the_Bus
27. https://www.cgmagonline.com/news/balatro-1-1-update-drops-new-mechanics/
28. https://brotato.wiki.spellsandguns.com/Handcuffs
29. https://steamcommunity.com/sharedfiles/filedetails/?id=3366723317
30. https://riftwizard2.wiki.gg/wiki/Spells
31. https://game8.co/games/Hades-2/archives/453617
32. https://hades2.wiki.fextralife.com/Daedalus_Hammer
33. https://nova-drift.fandom.com/wiki/Super_Mods
34. https://nova-drift.fandom.com/wiki/Shielded_Constructs
35. https://rogueranker.com/megabonk-items/
36. https://ballxpit.wiki.gg/wiki/Fusion_Mechanics
37. https://sihmar.com/magicraft-update-1-2-9-patch-notes-nov-17-2025/
38. https://www.pcgamesn.com/slay-the-spire-2/patch-notes-neow-relics
39. https://en.wikipedia.org/wiki/Slay_the_Spire_II
40. https://hades.fandom.com/wiki/Companions
41. https://www.thegamer.com/cult-of-the-lamb-every-follower-gift-necklace-equipment-upgrade-ranked/
42. https://terraria.wiki.gg/wiki/Guide:NPC_Happiness
43. https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:Neow

## 6. Progress
- **An overlap audit with fixes across every screen:**
  - `tools/uiaudit.sh`.
  - The iPad pixel scale is fixed; the view is never narrower than 480 px.
  - Labels are cut to fit, chips fold into "+N", and the glossary uses two columns.
  - The forge compacts its tiles, the credits wrap, the map legend wraps, and the map title shows the right world.
- **Speech bubbles and companions:** `ui/bubbles.gd`, `world/companion.gd`, `art/companion_art.gd`, and `test_bubbles`.
- **Residents in the Workshop:** they talk in bubbles, and their service opens a compact panel.
