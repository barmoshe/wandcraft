# Wandcraft 0.22 "Polish": fix, clarify, feel, speed, balance

**Bar's ask (28 Sep 2026, after 0.21):** "Research design fix and improve the game." His note on a boss fight in 0.21, "this is overwhelming", sets the tone.

**Bar's choices:**
- Quiet in fights.
- All four focus areas: new-player clarity, feel and accessibility, speed and size, balance.
- Ship to `main` and the web, keeping progress.

Three research passes fed it:
- An audit of open issues and feedback.
- A code audit of 0.20 and 0.21: 16 bugs.
- Web research with sources.

Where a site was blocked, the claim rests on the search summary of the cited page. *[I]* marks an inference.

## 1. What the research found (sources)
- **Mobile action roguelites keep it to one thumb and a first reward inside a minute.**
  - Archero: move to dodge, stand still to fire, a joystick wherever you touch ([Finding the Fun](http://scottfinegamedesign.com/design-blog/2019/7/2/archero-part-1-gameplay)).
  - Survivor.io and Archero: day 1 retention 44 to 49% ([Naavik](https://naavik.co/deep-dives/survivorio-archeros-footsteps/)).
  - Vampire Survivors: no tutorial, a level-up within a minute or two ([Mobile Game Report](https://www.mobilegamereport.com/articles/vampire-survivors-mobile-idle-2026)).
- **Big card pools stay readable when the pool opens up over time and inspecting a card never uses it.**
  - Balatro opens about 105 of 150 jokers at first ([Balatro wiki](https://balatrowiki.org/w/Jokers)). On mobile it is hold to inspect, drag to buy ([Engadget](https://www.engadget.com/gaming/balatro-is-an-almost-perfect-mobile-port-163050971.html)).
  - Slay the Spire on phones: a "UI for ants" ([Android Central](https://www.androidcentral.com/slay-spire-android-game-week)).
  - Magicraft states its modifier rule in plain words ("affect all shootable spells on the right") ([Steam](https://steamcommunity.com/app/2103140/discussions/0/3937895062997699349/)).
- **Feel and accessibility:**
  - Hit-stop of 60 to 80 ms on the hits that matter ([valdemird](https://valdemird.com/blog/game-feel-on-the-web/)).
  - Shake and flash as sliders ([XAG 117](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117)).
  - Dead Cells' assist mode ([Dead Cells wiki](https://deadcells.wiki.gg/wiki/Assist_Mode_and_Accessibility)).
  - Touch targets of 44 pt or 48 dp ([LogRocket](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/)).
  - Safari has no `navigator.vibrate` ([caniuse](https://caniuse.com/mdn-api_navigator_vibrate)).
- **Godot on the web:**
  - The single-threaded export works on iOS, and Brotli or gzip cuts the wasm to about a quarter ([Godot docs](https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_web.rst)).
  - The iOS audio crash (#107390) was fixed by PR #107948, which is in 4.7.2's history.

## 2. What changed
**Fixes (the audit's 16):**
- **No disk reads in a fight or a Workshop frame.**
  - `SaveGame` keeps the parsed meta record, and every write refreshes it.
  - The Workshop draws from a snapshot.
  - Assist reads settings only.
- **Exploits closed:**
  - LINT's review is per wand.
  - Hot-Reload needs 2 s on the belt.
  - The Altar costs HP while Fixed Vitals is held.
  - Relic Copy turns once and never copies Fixed Vitals.
- **Story kept:**
  - A walked-away resident beat waits for the next talk.
  - A cut line takes its bubble.
  - The post-mortem is spent only when said.
  - Freed residents speak as the cage opens.
- **Quiet in the right places:**
  - No barks in the Workshop sandbox, a daily or a lesson.
  - No Red Squiggle in a daily.
  - Bark flags reset per room.
- **Unsafe Staff:** no mana refunds or "out of mana" line.
- **Pair Programmer:** copies aren't trigger-released, and its pairing ends on an edit.
- **Decorator Rod:** boosts stop at End Block and at the wrap.
- **Companions:** never left in a wall or snapped onto the hero.
- **Bench and demo runs:** never write the player's Workshop.

**Quiet in fights:**
- Mid-fight, only low HP, a boss phase and a rule wand's first cast speak.
- The best of the rest (an elite down, a big hit, a status build, a dry wand) is said when the room clears.

**New-player clarity:**
- A "NEW" flag on reward cards and Merchant items seen for the first time.
- A "Fits your wand" chip on the reward that switches on the most, or adds the most damage.
- Tapping a tag chip (Burn, Trigger, Summon...) explains it in a line.
- Every tap target is at least 32 base px (44 pt on a phone); overlapping targets go to the nearest.
- The editor already showed each cast in order and the boost brackets, so it is unchanged.

**Feel and accessibility:**
- Shake and flash are 100%, 50% or off.
- Reduce motion takes out the camera lead and the low-HP pulse, and halves shake. The web default follows the browser.
- Large text.
- Assist of 25% or 50% (less damage taken, slower enemy shots, a wider auto-aim cone) replaces Gentle; dailies mark assist runs.
- Crit hit-stop is 60 ms.
- Vibration only on native phones.
- The overlap audit reports small taps.
- **RESET SAVE** in the Workshop's Terminal: three taps in a row erase runs, unlocks, Bits and the story (settings stay), and the game opens as it does the first time.

**Speed and size:**
- Voices import at 22.05 kHz: the pck goes from 29.4 to 28.3 MB.
- Audio has a budget test (28 MB imported).
- `tools/size_report.sh`.
- `.pck` gets a content type.

**Not taken:**
- **Music as Ogg Vorbis** (about −5 MB). It needs an ADR to replace 0019, loop-seam work, and a phone profile. Done after 0.22.0 in ADR 0034: 4 MB off the pck, seams tested; the phone profile is still open.
- **Long cache headers.** They need content-hashed file names first.
- **A custom engine template** (the wasm is 39.5 MB, 7 to 10 MB compressed).

**Balance:** the bench bot dodges now: it dashes out of telegraphed boss attacks and away from shots about to land (`Boss.bot_threat`). The balance pass was stopped before it re-measured the benches, so the World 1, Kernel and pack numbers with the dodging bot come next.

## 3. Progress
- **Shipped as 0.22.0** (ADR 0033).
- **Tests:** 436 pass.
- **Overlap audit:** clean at three sizes, and with large text on the HUD cases.
- **Size:** 1.1 MB smaller.
- **Next:**
  - Bench numbers with the dodging bot.
  - Music as Vorbis: done (ADR 0034). A listening and CPU check on a phone is left.
  - Hashed web file names for long caching.
