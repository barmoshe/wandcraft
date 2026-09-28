# 3. Hubs that grow and feel alive

Research for Wandcraft's Workshop (one screen, 18x11 tiles, stations, the Duck and LINT) now that three NPCs found during runs will move in. It builds on `research/workshop-0.19.md`, which covered the basics of the Magicraft camp, the House of Hades, the Breach, the hub tax and Soul Knight's interact button.

**Method note.**
- WebFetch was blocked by the session's egress proxy, so every claim comes from WebSearch result summaries of the linked pages. Spot-check any single-source detail.
- *[I]* marks an inference or design judgment.
- This covers mechanics only; copy no names, text or art.

## 1. The reference hubs, by what changes

### Hades: the House reacts to your last run
- **The Contractor catalogue has two kinds of change** [1][2]:
  - "Work orders" change the runs themselves (healing rooms, loot rooms).
  - Room pages are mostly cosmetic: rugs, paintings.
  - Some entries need others bought first.
- **Whole rooms open late.** The Lounge opens after five runs, won or lost [2]. It then holds:
  - a music stand
  - a trader
  - a chef who buys fish
  - NPCs who only turn up there sometimes, such as a boss you just beat [6]
- **NPCs react to how you died.**
  - The desk clerk remarks on your latest death and gives a mostly useless tip [3].
  - Background shades explain how *they* died [3].
  - The game has about 21,000 voiced lines and avoids repeats until the unused lines run out [3][4].
  - Critics call this "rewarding failure": dying moves the story on [3].
- **Gifting is a relationship track** [5]:
  - The first gift returns a keepsake with a gameplay effect.
  - 5–6 gifts unlock a quest, and the quest opens the remaining hearts.
  - Most of the track is expressive rather than power.
- **Small funny fixtures:** the training dummy's made-up war record, and a bed you can buy for the dog [6][13].

### Hades II: the Crossroads is crafted into being
- **One station changes the hub.** The Cauldron's incantations add merchants, stock, tools and task lists [7]. Each needs a condition met during runs before it can be crafted [8].
- **New areas are social spaces.** A hot spring and a tavern are crafted into existence, and inviting an NPC there with a gift plays a scene with new dialogue [8].
- **Gardens grow by play, not by the clock.**
  - Seeds grow per *encounter* cleared on a run [9].
  - Hub social scenes also advance them [9].
  - More plots come from more incantations [9].
- **Residents are sometimes absent**, "off on errands", though rarely all at once [10]. They also leave their posts to check your crops, sit in the tavern or talk to each other [13].
- **Later additions:**
  - An NPC-run renewal project spends a prestige currency on dozens of cosmetic changes to the hub [11].
  - A board of about 89 prophecies grows with the story [12].

### Enter the Gungeon: every rescue adds a feature
- **Rescued NPCs bring something specific** [14]:
  - a shop of unlocks
  - a mode toggle (turbo, rainbow)
  - a hint-giver who moves in only after you help him map every floor
  - a trickshot minigame
- **A running gag pays out.** A goblin's helmet can be kicked off a ledge, and doing it three times grants an unlock [14].
- **Milestones fill the room.** Five alcoves fill with golden trophies for hard milestones [15].
- **Quests span several runs.** Some rescued NPCs then appear *inside* runs with 5-part challenges done over 5 runs [15].

### Dead Cells and Hollow Knight: progress you can see
- **Dead Cells:**
  - Glass flasks above the start area fill with pictures of each blueprint unlocked, so the room tracks progress [16].
  - Bought upgrades add fixtures to the start area, such as a mirror that shows an enemy still carrying a blueprint you lack [16].
- **Hollow Knight:**
  - Dirtmouth starts with one resident and gains up to 10 through rescues [19].
  - One rescued NPC fills her house with drawings and diary entries about the player, then switches every keepsake to a comic rival if he moves in too [19].

### Moonlighter, Cult of the Lamb and Animal Crossing: the hub as a place that lives
- **Moonlighter:**
  - Shop income brings a blacksmith, a potion-maker and hired help, and new merchants move in [17].
  - In the sequel, buildings appear as you invest and NPCs comment on it [17].
- **Cult of the Lamb:**
  - Followers work and worship while you are on a run [18].
  - They ask for decorations, which exist "for the followers to admire" [18].
  - They show thought bubbles when they have something to say [18].
- **Animal Crossing:**
  - A move-in is a ceremony: you place and furnish the plot, and the house is built from your choices [20].
  - Moves show a day ahead as cardboard boxes [20].
  - Hobbies set where each resident goes, residents talk to each other, and a plaza exercise gathers a group [20].

### Rogue Legacy 2, Children of Morta and Wizard of Legend
- **Rogue Legacy 2:**
  - Each castle upgrade adds a docks NPC: smith, enchantress, gold safe, and an architect who locks the map layout [21].
  - An icon shows when an NPC has a new talk, and talking pays a reward [21].
- **Children of Morta:** short family scenes (meals, chores) play after runs. They are gated on goals, so 2–3 runs may pass with nothing, then a scene [22].
- **Wizard of Legend:** its plaza is plain vendors and clerks, some of which change how the next run starts [23].
  - *[I]* It is useful but static.

### Mobile and menu-only references
- **Soul Knight:**
  - The living room holds heroes, the pet, and doors to the garden and workshop [24].
  - Plants mature over *days* and give pets, weapons or buffs for the next run [24].
- **Soul Knight Prequel** adds a home you can furnish [25].
- **Archero 2:**
  - The hub is a menu that fills in over *days of sessions*, with features greyed out until the player is ready [26].
  - *[I]* The drip is the point: the main screen never overwhelms a new player.
- **Magic Survival and Vampire Survivors** keep meta on flat screens: a research perk grid [27], and a power-up grid plus a collection of "?" slots [28].
- **Balatro has no hub.** Its unlocks are content only (decks and jokers, no power), and a run rarely takes more than 10 minutes [30].
- **Slay the Spire 2** puts its meta in a menu Timeline of epochs. Each epoch pays story and art, and you open it by hand [29].

## 2. Patterns worth taking

1. **Change the hub on events, not wall-clock time.**
   - Examples: plants per encounter [9], the Lounge after 5 runs [2], epochs on milestones [29].
   - *[I]* For a premium game with no ads, a real-time clock reads as a free-to-play wait gate.
2. **Every rescue adds a verb or a view, not just a face** [14][21].
   - *[I]* An NPC with nothing to do goes stale after the first talk.
3. **React to the last run first** [3][22].
   - *[I]* Wandcraft's `Hub.greeting` already has 35 lines. The cheapest gain is spreading that reaction to the new NPCs and to props.
4. **Show progress without a menu** [15][16][19]. On a phone, every menu costs taps.
5. **Absence and movement make NPCs feel alive** [10][13][20].
   - *[I]* In a room that takes 2.7 s to cross, keep it subtle.
   - A station's owner is never missing when you need the station.
6. **Relationships as queues of small, finite asks** [5][18]. These fit phone sessions. *[I]*
7. **Jokes and secrets build attachment**, and they are cheap to build [6][14][19]. *[I]*
8. **The hub is optional, so it has to earn its place** [29][30].
   - *[I]* Reactions play along the walk to the portal and never block it.
9. **Phone UX:**
   - **Markers, not forced talk.** A "!" over an NPC with something new, as with Rogue Legacy 2's icons [21] and Cult of the Lamb's bubbles [18].
   - **Short lines.** At most three, and skippable.
   - **Fixed anchor tiles.** NPCs move only between 2–3 anchor tiles next to stations, so USE and MENU keep working. *[I]*
   - **One arrival at a time.** Each new resident arrives at a separate run end, never three at once, as in Archero 2's drip [26]. *[I]*

## Sources
1. Hades Wiki (Fextralife), House Contractor: https://hades.wiki.fextralife.com/House_Contractor
2. Hades Wiki (Fandom), House Contractor: https://hades.fandom.com/wiki/House_Contractor
3. Christi Kerr, "How the Dialogue System in Hades Rewards Failure": https://www.christi-kerr.com/post/how-the-dialogue-system-in-hades-rewards-failure (also TV Tropes, Funny/Hades: https://tvtropes.org/pmwiki/pmwiki.php/Funny/Hades)
4. Game Rant, Hades word count: https://gamerant.com/hades-word-count-illiad-odyssey/
5. RPG Site, Hades Nectar guide: https://www.rpgsite.net/feature/10266-hades-nectar-guide-who-to-gift-nectar-to-for-keepsakes and Hades Wiki (Fextralife), Nectar: https://hades.wiki.fextralife.com/Nectar
6. Hades Wiki (Fandom), House of Hades: https://hades.fandom.com/wiki/House_of_Hades
7. Hades Wiki (Fandom), Cauldron: https://hades.fandom.com/wiki/Cauldron
8. Game8, Hades 2 Crossroads Progression Guide: https://game8.co/games/Hades-2/archives/455328
9. Game8, Hades 2 Farming Guide: https://game8.co/games/Hades-2/archives/453708
10. Steam discussion, Hades II Crossroads NPCs away: https://steamcommunity.com/app/1145350/discussions/0/591766950678408148/ and Hades 2 Wiki (Fextralife), The Crossroads: https://hades2.wiki.fextralife.com/The+Crossroads
11. Hades Wiki (Fandom), Crossroads Renewal Project: https://hades.fandom.com/wiki/Crossroads_Renewal_Project
12. Hades Wiki (Fandom), Fated List of Minor Prophecies (Hades II): https://hades.fandom.com/wiki/Fated_List_of_Minor_Prophecies/Hades_II
13. Hades Wiki (Fandom), Odysseus/Quotes: https://hades.fandom.com/wiki/Odysseus/Quotes and Skelly: https://hades.fandom.com/wiki/Skelly
14. Enter the Gungeon Wiki, The Breach: https://enterthegungeon.wiki.gg/wiki/The_Breach
15. PSNProfiles, Enter the Gungeon trophy guide: https://psnprofiles.com/guide/4287-enter-the-gungeon-trophy-guide and Gameranx, side quests: https://gameranx.com/features/id/47348/article/enter-the-gungeon-side-quests-and-challenges-guide/
16. Dead Cells Wiki, Prisoners' Quarters: https://deadcells.wiki.gg/wiki/Prisoners'_Quarters
17. Moonlighter Wiki, Rynoka: https://moonlighter.fandom.com/wiki/Rynoka ; Wikipedia, Moonlighter: https://en.wikipedia.org/wiki/Moonlighter_(video_game) ; Output Lag, Moonlighter 2 impressions: https://outputlag.com/feature/moonlighter-2-the-endless-vault-early-access-impressions-the-shop-never-closes/
18. Wikipedia, Cult of the Lamb: https://en.wikipedia.org/wiki/Cult_of_the_Lamb ; Destructoid base guide: https://www.destructoid.com/base-building-and-design-tips-guide-cult-of-the-lamb/ ; Cult of the Lamb Wiki, Followers: https://cult-of-the-lamb.fandom.com/wiki/Followers
19. Rogue Ranker, Dirtmouth: https://rogueranker.com/dirtmouth-hollow-knight/ and Hollow Knight Wiki (Fextralife), Bretta: https://hollowknight.wiki.fextralife.com/Bretta
20. Nookipedia, Moving: https://nookipedia.com/wiki/Moving ; Hobby: https://nookipedia.com/wiki/Hobby ; Group stretching: https://nookipedia.com/wiki/Group_stretching
21. Rogue Legacy 2 Wiki, Upgrades: https://rogue-legacy-2.fandom.com/wiki/Upgrades and NPCs: https://rogue-legacy-2.fandom.com/wiki/NPCs
22. Game Developer, "Making family matter in Children of Morta": https://www.gamedeveloper.com/design/making-family-matter-in-i-children-of-morta-i- and PlayStation Blog, 14 Oct 2019: https://blog.playstation.com/2019/10/14/designing-story-for-a-non-linear-world-in-children-of-morta-out-tomorrow/
23. Neoseeker, Wizard of Legend Lanova merchants: https://www.neoseeker.com/wizard-of-legend/Walkthrough/Lanova_Merchants_&_Services
24. Soul Knight Wiki, Living Room: https://soul-knight.fandom.com/wiki/Living_Room and Garden: https://soul-knight.fandom.com/wiki/Garden
25. TapTap review, Soul Knight Prequel: https://www.taptap.io/post/6586307
26. Tiny Teardown, Archero 2: https://someselectedstories.substack.com/p/tiny-teardown-archero-2-habby-games
27. Magic Survival Wiki, Research: https://magic-survival-rpg.fandom.com/wiki/Research
28. Vampire Survivors Wiki, Main menu: https://vampire.survivors.wiki/w/Main_menu and Collection: https://vampire.survivors.wiki/w/Collection
29. Slay the Spire Wiki, StS2 Timeline: https://slaythespire.wiki.gg/wiki/Slay_the_Spire_2:Timeline and GameSpot, Epochs: https://www.gamespot.com/articles/slay-the-spire-2-epochs/1100-6538655/
30. Steam discussion, Balatro meta progression: https://steamcommunity.com/app/2379780/discussions/0/4346606879506457345/ and Playing Software, "the run": https://playingsoftware.substack.com/p/the-run


## 5+ original ideas for Wandcraft

Each idea is *[I]*: an original proposal that builds on the patterns above.

### 1. Rescued NPCs are orphaned processes that the Workshop adopts
- **In a run:** each of the three NPCs is found as a stuck "zombie process", a flickering figure in a side room. Clearing the room reaps it.
- **On return:** the Workshop plays a `fork()` beat, staged like Animal Crossing's move-in [20]:
  - a dotted outline on its anchor tile
  - then a cardboard box
  - after one more run, the NPC itself
- **A `ps` strip on the Terminal** lists each resident's state:
  - `running`: at their station
  - `sleeping`: napping; tap for a grumpy line
  - `blocked`: waiting with a "!" for something from your next run
- **Each NPC adds a verb** (pattern 2):
  - wand-slot tuning at the Bench
  - a Portal toggle (a hard mode or a silly mode)
  - a challenge spread over several runs, like Gungeon's [15]
- **Why it's fun:** the theme explains why NPCs appear and move. Each rescue is an event twice, in the run and again in the hub.
- **Cost:** M (3 sprites plus box and outline states, the process strip).
- **Phone:** good. States map to fixed anchor tiles, so USE and MENU are unchanged.

### 2. The stack-trace hub: props replay your last run
- **The room shows how the last run went:**
  - The dummy wears the look of whatever killed you, with a sticky note giving the cause.
  - Your most-cast spell leaves glyph embers by the Bench.
  - The newest commit on the Commit Wall glows until you read it.
  - A win makes confetti come out of the Duck.
- **Each resident has one line per death category**, reusing `Hub.greeting`'s tags, as the Hades clerk does [3].
- **Why it's fun:** the hub's jokes are about *you*, a death becomes the setup for a gag, and the room is never quite the same twice.
- **Cost:** S–M. The data exists; this needs a dummy reskin and about 30 lines.
- **Phone:** excellent. It is passive: no input and no extra taps.

### 3. The Workshop compiles itself
- **The Workshop starts half-built:** magenta "missing texture" checkerboards, `TODO` sticky notes in the corners, and empty trophy plinths.
- **Progress renders it in.** Each bounty claimed, pack installed, boss beaten or NPC adopted turns one region into finished pixel art, with a "compiling… 0 warnings" toast on the way to the portal.
- **Packs show up as boxes on shelves**, like the Dead Cells flasks [16] and the Gungeon alcoves [15].
- **A build-progress % sits on the Terminal**, much as Dirtmouth's residents come back one by one [19].
- **Why it's fun:** progress is always on display at no cost to the player, and the glitch look *is* the theme.
- **Cost:** M (two art states for about 12 regions, and a map from unlocks to regions).
- **Phone:** excellent. There are no menus, and a glance shows progress.

### 4. Pull requests: gifting as code review
- **Each resident opens one small PR at a time**, such as "add a lamp by the Bench", "let me stock rarer spells" or "hang my portrait".
- **Reviewing one is a single tap:**
  - **Approve** spends Bits or a run drop, and the change lands.
  - **Request changes** gets a funny reply and a revised PR next run.
- **The third merged PR opens that NPC's personal quest**, like Hades' track of keepsake, then quest, then hearts [5]. Merged PRs appear on the Commit Wall under the NPC's name.
- **Why it's fun:**
  - It gives Bits a warm sink besides packs, as Hades II's renewal project does for decor [11].
  - Every decoration has an author and a story.
- **Cost:** M (a PR table with 4–5 PRs per NPC, and a modal).
- **Phone:** very good. A card with two big buttons.

### 5. Cron: hub scenes keyed to run count
- **A small scheduler fires scenes every N runs**, never on the clock (pattern 1):
  - **Stand-up:** the residents gather by the Duck for three lines about your recent runs, like Animal Crossing's group exercise [20] and Hades II's NPC chatter [13].
  - **Friday deploy freeze:** warning tape on the Portal that you can walk straight through, while LINT complains.
  - **Garbage-collection day:** a sweeper clears the last run's props.
  - **Merge conflict:** two residents want the same wall. You pick one, and the other sulks for a run, a nod to Hollow Knight's switching shrine [19].
- **Why it's fun:** returns bring surprises on a rhythm you can learn, and the NPCs clearly have lives, as the gated scenes in Children of Morta do [22].
- **Cost:** S–M (a scheduler and 6–10 short scenes).
- **Phone:** good. Scenes play around the walking player and never block the portal (pattern 8).

### 6. Background jobs that finish by playing
- **The Bench gets a job queue.** Queue a build (a wand skin, a resident's gift) and it completes after N rooms cleared, like the encounter-driven garden in Hades II [9].
- **Coming back pays out.** A finished job chimes "✓ build passed" and leaves a box by the door.
- **Why it's fun:** returning becomes collecting, not a tax, and even a bad run pushed something forward.
- **Cost:** S.
- **Phone:** excellent. It suits short sessions, and there is no free-to-play-style timer.

### 7. Secret shell commands at the Terminal
- **Commands are found through NPC hints and bounty text, then appear as tappable chips:**
  - **`sudo` the Duck:** it refuses.
  - **`rm` the dummy:** it returns bandaged.
  - **`blame` a trophy:** shows the run that earned it.
  - **`top`:** names whoever talks most as the top "CPU user".
- **Repeating one joke three times unlocks a cosmetic**, like the helmet gag [14].
- **Why it's fun:** secrets reward curiosity, give players something to share, and make one screen feel deep.
- **Cost:** S.
- **Phone:** good. Chips, never a keyboard.

### 8. Hot reload: land where the news is
- **After a run you respawn next to the news:**
  - by the Board if a bounty is ready
  - facing a new resident
  - otherwise by the Portal
- **A one-line toast says why.** The quick restart stays on the end screen.
- **Why it's fun:** the news comes to you, and the hub never feels like a tax (pattern 8).
- **Cost:** S.
- **Phone:** excellent. It saves walking every session.
