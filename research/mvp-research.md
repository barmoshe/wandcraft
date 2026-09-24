# MVP research: design, production and an audit of the POC (2026-09-24)

This is the evidence behind `mvp-plan.md` and ADR 0010. It has three parts, all gathered on 2026-09-24:
- an audit of the v0.4.1 POC code
- a sourced review of the genre
- a sourced review of production and technology

Every external claim links to its source. Where the evidence was weak, this file says so.

## 1. POC audit (v0.4.1)

**Size:**
- About 10,090 lines of game GDScript and about 1,660 lines of tests.
- By layer:

| Layer | Lines |
|---|---|
| sim | 1,380 |
| world | 3,874, of which `world.gd` is 1,431 |
| ui | 1,619 |
| art | 2,511 |
| autoload and `main.gd` | 704 |

**Content:**

| Content | Count |
|---|---|
| Spells | 40 (15 shooting, 17 boosts, 5 triggers, 3 passives) |
| Wands | 7 |
| Relics | 28 |
| Enemy types | 6 |
| Bosses | 2, with 4 moves each |
| Worlds | 1 |
| Room templates | 8 (5 of them fights), in a 9-step chapter |

**What was promised but not done:**
- Worlds 2–5.
- In-app purchase and Game Center.
- `tr()` localization.
- The "Debugger" signature twist and summons (ADR 0002).
- Meta unlocks.
- Store assets.
- Frame rate measured on a real device.

**What is well built:**
- The sim layer never touches nodes.
- The wand compiler (`wand_program.gd`) is a pure function, covered by 14 golden tests plus a sweep of every spell against every boost.
- The `ui_request` handshake between the world and the menus.
- Atomic JSON saves.
- The BFS flow field.
- The MultiMesh bullet pool.
- The tap test with a `--ios` mode.
- `webtest.sh`, which measures real audio output.

**Weaknesses:**
- **`world.gd` is a god object.** It holds room data, waves, rewards, collision, navigation, relic effects, juice and the test bot.
- **Relic effects are scattered:** 31 separate `has_relic` checks.
- **Content lives in positional code tables** with no validation, and the section comments in `catalog.gd` are wrong.
- **The UI is hand-placed.** 102 fixed rectangles, 8 px fonts, and no layout, text scaling or focus handling.
- **The core pitch is optional.** The balance bot never edits a wand and still survives 70–80%.
- **The player's only verbs** are moving and auto-fire.
- **Runs are short:** 2–4 minutes of combat.
- **Difficulty follows a flat formula**, and there is no meta-progression.
- **Animation is thin.** Enemies have 2 frames and the hero has 7.
- **Audio is thin:** a 22 kHz single-oscillator synth with three loops of about 35 s each.
- **Web sound was silent** until 0.4.1 switched to Stream playback (ADR 0009).

**Kept for the MVP:**
- The wand engine and its tests.
- The layering rule and the `ui_request` handshake.
- The test infrastructure.
- Door-choice rewards.
- The save code, the flow field and the bullet pool.
- The platform lessons in ADRs 0004, 0008 and 0009.

## 2. Genre design research

### Competitors
**Magicraft** is the closest to Wandcraft.
- Its wands are a linear, left-to-right timeline; modifiers to the left apply to every spell to their right.
- About 10.9k Steam reviews, rated "Very Positive".
- **Complaints:** late relic balance, spongy bosses, losing a build after world 2, and a thin starting pool.
- Sources:
  - https://rogueliker.com/magicraft-review/
  - https://www.pcgamer.com/games/roguelike/magicraft-is-like-brotato-mixed-with-hades-where-you-make-up-all-your-guns-as-you-go-along/
  - https://en.wikipedia.org/wiki/Magicraft
  - https://steamcommunity.com/app/2103140/discussions/0/601891059816000793/
- No official mobile version was confirmed, which leaves a gap on phones.

**Noita:**
- 71.7% of players reached level 2, where wand editing begins. About 30% never got there.
- Players built outside wand simulators that show the cast tree.
- Sources:
  - https://steamcommunity.com/app/881100/discussions/0/604148566876768427/
  - https://noita.wiki.gg/wiki/Tool:_Noita_Wand_Simulator

**Soul Knight:**
- Auto-aim lets the player focus on moving.
- Levels run 3 floors × 5 rooms, with a boss every fifth room.
- Sources:
  - https://medium.com/@AndroidAppNews/soul-knight-review-2d-top-down-action-shooter-c62c136df1d8
  - https://soul-knight.fandom.com/wiki/Level_Mode

**Archero:**
- It fires automatically whenever you stop moving.
- About 11 ability picks per run.
- Angel and devil rooms add risk and reward.
- Its stat-grind meta-progression is widely called its "fatal flaw".
- Source: https://www.deconstructoroffun.com/blog/2019/8/9/why-archero-banked-25m-but-leaves-25m-hanging-hlx9n

**Vampire Survivors and Brotato:**
- Movement is the only input, and there is a reward every few seconds.
- Brotato runs 20 waves in 15–20 minutes and sells a $4.99 premium version.
- Sources:
  - https://www.kokutech.com/blog/gamedev/design-patterns/power-fantasy/vampire-survivors
  - https://brotato.wiki.spellsandguns.com/Waves
  - https://apps.apple.com/us/app/brotato-premium/id1668755109

**Hades:**
- Each door shows the reward behind it, and reward types are smoothed so no kind repeats too often.
- The explicit goal was to "take the pain out of dying".
- Sources:
  - https://hades.fandom.com/wiki/Chamber_Reward
  - https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death

**Balatro (mobile):**
- Priced at $9.99, it earned about $4.4M and topped the paid charts.
- The UI was rebuilt around drag and drop.
- 105 of its 150 jokers are available from the start; the other 45 unlock under conditions the player can see.
- Sources:
  - https://www.pocketgamer.biz/balatro-nears-44m-on-mobile-amid-a-sudden-spending-surge/
  - https://www.engadget.com/gaming/balatro-is-an-almost-perfect-mobile-port-163050971.html
  - https://balatrowiki.org/w/Unlockables

**Dead Cells (mobile):**
- A floating stick, plus buttons the player can move and resize.
- 5M+ premium copies sold.
- Sources:
  - https://www.gamedeveloper.com/design/porting-i-dead-cells-i-to-mobile-an-in-depth-breakdown
  - https://toucharcade.com/2023/01/24/dead-cells-mobile-sales-numbers-ios-android-5-million-playdigious-apple-arcade/

**Slay the Spire:**
- The map branches and then rejoins.
- The iOS port was criticised for tiny touch targets and clipped text.
- Sources:
  - https://www.ludo.guide/guide/slay-the-spire/pathing-risk-assessment/map-generation-and-branching
  - https://toucharcade.com/2020/06/15/slay-the-spire-ios-review-iphone-ipad-performance-icloud-megacrit-humble-games/

### Controls, pacing and feel
**Controls:**
- **Floating vs fixed stick:** no significant difference in testing; floating scored slightly easier to learn.
- **Aiming:** a ~0.3 deadzone, an auto-aim cone of about 30° with a visible lock, and 44pt touch targets.
- Sources:
  - https://medium.com/@yi_zhang1/ui-critique-2-virtual-joystick-of-mobile-games-7fd4b233c066
  - https://www.gamedeveloper.com/design/everything-i-learned-about-dual-stick-shooter-controls
  - https://developer.apple.com/design/human-interface-guidelines/

**Session length:**
- The median mobile session is 3.1–3.5 minutes; the top 10% run about 8 minutes.
- So runs should be built from short rooms, and a run in progress must survive quitting the app.
- Source: https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks

**Feel:**
- **Hit-stop:** about 3–12 frames.
- **Screen shake:** see the "Art of Screenshake" talk.
- **Enemy bullets:** high contrast, and a different shape for each pattern.
- Sources:
  - https://arxiv.org/pdf/2011.09201
  - https://www.youtube.com/watch?v=AJdEqssNZ-U
  - https://sparen.github.io/ph3tutorials/ddsga2.html

### Monetization
**Free trial followed by an unlock:**
- Apple allows a non-consumable "trial" at $0, as long as the listing states what is locked and what the unlock costs.
- Google Play offers free trials for paid games.
- Sources:
  - https://developer.apple.com/app-store/review/guidelines/
  - https://indiespark.org/business/free-trial-app-store/
  - https://support.google.com/googleplay/android-developer/answer/16923846?hl=en

**Conversion data is weak:** the only figure found was 0.67% from an old anecdote. Plan on 1–3%, unproven. Source: https://www.nbcnews.com/tech/tech-news/how-app-200-000-downloads-led-developer-homelessness-flna946720

**Apple Arcade** is invite-only and its payouts are opaque. Source: https://www.pocketgamer.biz/mobile-mavens/70357/what-does-apple-arcade-mean-for-indie-developers/

### The 15 principles we adopted
1. Program the wand; let the game handle firing (auto-fire plus a ~30° aim cone with a lock marker).
2. Landscape, with a floating left stick and a dash on the right. Controls can be moved; 44pt touch targets.
3. The wand is a linear timeline, not a tree.
4. A live "what this wand fires" preview.
5. The first wand edit comes within 2 minutes.
6. Drag and drop, a zoomed slot view, and long-press to pin tooltips.
7. Unlocks come in stages, each with a visible condition.
8. Runs of 12–18 minutes, rooms of 1–2 minutes, and a save mid-run.
9. Rewards shown on doors, on a branching map that rejoins.
10. A boss every 4–5 rooms, with elite and risk rooms in between.
11. Meta-progression adds new things, not bigger stats.
12. Back in a new run within 3 seconds of dying, having gained something.
13. A budget for juice: hit-stop, a shake cap, knockback, haptics paired with sound.
14. Enemy bullets use a reserved shape and color family, with colorblind presets.
15. World 1 is free; one unlock is labelled as a trial.

## 3. Production and technology research

**Art pipeline options:**
- **Hire a pixel artist:** about $20–70 per character set, or $40–60 per frame at professional pace.
- **Asset packs:** licences vary, and styles clash when packs are mixed.
- **AI tools:** PixelLab (you own the output; agents can drive it) and Retro Diffusion. Apple has no rule against AI art; Steam requires disclosure.
- Sources:
  - https://2dwillneverdie.com/blog/how-much-do-sprites-cost/
  - https://trevor-pupkin.itch.io/tech-dungeon-roguelite
  - https://www.pixellab.ai/termsofservice
  - https://retrodiffusion.ai/
- **Bar chose code-drawn art at $0**, with a higher ceiling: rigs and baked atlases.

**Audio:**
- ChipTone and as3sfxr output is CC0.
- The Sonniss GDC bundle is royalty-free, but its licence must be checked for each bundle.
- Composers charge $50–150 per minute at entry level. Suno's copyright status is uncertain, and Udio is closed.
- Sources:
  - https://sfbgames.itch.io/chiptone
  - https://sonniss.com/gdc-bundle-license/
  - https://www.twine.net/blog/game-composer-pricing/
  - https://blog.dubspot.com/ai-music-licensing-explained-2026

**Web audio in Godot:**
- In "Sample" mode, Godot's web audio decodes every clip to raw float PCM. QOA files play but save no memory.
- Sample mode still crashes iOS Safari after 10–30 minutes (#116750, open). Stream mode avoids it.
- Sources:
  - https://github.com/godotengine/godot/blob/4.5/platform/web/audio_driver_web.cpp
  - https://github.com/godotengine/godot/issues/116750
- **Our own measurement (ADR 0009):** Sample mode was completely silent with our QOA files.

**Godot on mobile:**
- The docs say the Compatibility renderer is "usually good enough for 2D". Live `PointLight2D` lights are costly on Android.
- Turn on 2D physics interpolation at 60 ticks.
- 120 Hz needs `CADisableMinimumFrameDurationOnPhone` in the app's plist.
- Import pixel art lossless.
- Custom export templates can shrink the build (for example `disable_3d` saves about 15%).
- Sources:
  - https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
  - https://github.com/godotengine/godot/issues/81152
  - https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays?language=objc
  - https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html
- For bullets, use a MultiMesh with our own collision grid. Consider a GDExtension (for example BlastBullets2D) only after profiling on a real device.

**Web as a channel:**
- Web is the right place for daily playtests, but a poor stand-in for native performance.
- CrazyGames allows an initial download of at most 50 MB. Poki is invite-only.
- Source: https://docs.crazygames.com/requirements/technical/

**Shipping:**
- Apple Developer costs $99 a year.
- GitHub's `macos-26` runner has been generally available since 2026-02-26.
- The TestFlight route: `fastlane match`, then `pilot`, using an App Store Connect API key.
- Google Play personal accounts still need a closed test with 12 testers for 14 days.
- From 2026-08-31 apps must target API 36; from 2027-02 they need 16 KB page alignment.
- Sources:
  - https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/
  - https://docs.fastlane.tools/app-store-connect-api/
  - https://support.google.com/googleplay/android-developer/answer/14151465?hl=en
  - https://developer.android.com/guide/practices/page-sizes

**Store plugins:**
- **iOS:** GodotApplePlugins provides StoreKit 2 and Game Center (iOS 17+). It is the pick; godot-storekit2 is still unstable.
- **Android:** GodotGooglePlayBilling 3.x wraps Play Billing 8.3/9.1, and godot-play-game-services covers Play Games.
- Sources:
  - https://github.com/migueldeicaza/GodotApplePlugins
  - https://github.com/godot-sdk-integrations/godot-google-play-billing/releases

**QA:**
- Headless test runners (gdUnit4 or GUT), seeded bots, and screenshot diffs under xvfb.
- Only real devices count for performance.
- For feedback, use a local, opt-in run log plus TestFlight feedback. No analytics SDK.
- Source: https://github.com/godot-gdunit-labs/gdUnit4
