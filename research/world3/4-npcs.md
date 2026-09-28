# 4. NPC design in roguelikes and action games (for Wandcraft)

Research for the three found-in-run NPCs who move into the Workshop. Sources are numbered in the list before the ideas section. `[I]` marks my inference rather than something a source states. Method note: WebFetch was blocked by the egress proxy for most game sites, so facts come from search-result summaries of wiki and press pages; each claim still points at the page it came from.

## 1. What the reference games do

### Hades: the gift loop and the priority queue
- **Gift loop.** Nectar is the one-way relationship currency. The first bottle to any character returns a Keepsake (a small equippable perk), and later bottles pay out dialogue [2][3]. After about 5-6 bottles the heart meter shows a *locked* heart: more gifts do nothing until you complete that character's favor, which is a request made in conversation [2][3]. Finishing it opens the upper hearts, paid in the rarer Ambrosia, which buys a companion [2].
- **Favors are multi-character puzzles.** To free a court musician from his contract, you need high affinity with *three* people. One of them tells you where the paperwork is, and the last step is spent at the House Contractor [4]. The same pattern runs a prisoner's quest: gift him until he stops accepting, talk to the boss characters until they comment, then buy the release [4]. The lesson is that one NPC's arc routes through the hub's other residents and its shop [I].
- **The dialogue engine.** About 22,000 lines [5]. Nearly every line has prerequisites: other conversations seen, bosses met, weapons held, deaths suffered. A priority tier lets story-critical events win over random chatter [5][6]. Kasavin's stated goal was that players rarely hear a repeat, so every character got a large pool, and the team loved "reactive moments" where characters respond to what just happened [7].
- **Reactivity to the build.** Gods comment on boons from rival gods, duo boons trigger a two-god exchange, and a god will notice when you arrive nearly dead [8].
- **The in-run merchant.** Charon sells for obols, which are lost on death. Sometimes a loot bag sits behind him, and taking it starts a fight [9]. That is an NPC with teeth inside a friendly shop.

### Enter the Gungeon: rescued NPCs as a growing hub
- **Rescues fill the hub.** NPCs locked in cells are freed with a key dropped on that floor, and each then moves into the Breach, the hub [10][12]. The Gunsling King is found in chamber 2. Once freed he also appears *inside* runs, offering a wager: complete the next room with no hit, no dodge, or a set gun, with shells as collateral [12].
- **Some rescues span many runs.** The Lost Adventurer asks you to map a floor fully. After all five floors he moves up and gives cryptic hints to secret areas [11]. Hints as a hub service is exactly the Grep idea, and it works best when the hints point at *secrets* rather than at power [I].

### Dead Cells
- **A hub stranger holds the unlocks.** The Collector trades Cells for blueprints. A blueprint is lost if you die before delivering it [13]. He is also the true final boss at max difficulty [14], so the friendly merchant hides a threat that only pays off far into the game.

### Hollow Knight: found NPCs who move to town
- **Found in trouble, moved to town.** The shopkeeper is found half-lost to the Infection at the bottom of the first area. Walking up to him breaks the daze, with no quest and no item needed, and he reopens his shop in the surface town, which is the one place that grows as you play [15].
- **The secret, much later.** After you learn three arts from his old pupils, you find him in his back room, not at the counter, and he reveals himself as their master [15]. The best secret is in plain sight: the merchant you visit every run [I].
- **Audio cues.** The mapmaker hums, and the hum is directional, so you can hear him rooms away. A trail of loose paper leads to him. In the most dangerous area he goes quiet because he is afraid [16]. That one exception is characterisation done entirely through a mechanic [I].
- **An arc across the map.** A wandering scholar appears about nine times, each time further along his own journey, and ends at peace by a lake [17].

### Dark Souls: arcs across the map
- **Wandering arcs.** A cheerful knight is found stuck at a series of obstacles in different areas, and helping each time pays items. You can miss him entirely [18]. A sun-seeking knight's fate depends on whether you kill one bug before he reaches it. Miyazaki called the bad ending "the general norm" [19]. Both arcs say that an NPC who moves forward without you makes the world feel alive, and missing them is part of the deal [I].

### Other references, briefly
- **Moonlighter:** a smith and a witch are *unlocked* for gold at a notice board and open shops in town [20]. It is functional, but the NPCs have no arc, which shows what you lose without one [I].
- **Cult of the Lamb:** followers are procedural. They have traits, dissent visibly (red eyes, a megaphone) and react to camp rules [21]. They are cheap to make and warm, but none has a memorable arc.
- **Slay the Spire:** Neow greets every run with a *choice* of blessings, fewer if you died early last time [22]. One NPC equals one choice at the top of a run.
- **Balatro:** Jimbo is a joker card who teaches the game and is also a playable card [23]. A mascot works when it is part of the mechanics, not a narrator beside them.
- **Noita:** no talking NPCs. Lore sits in glyphs that you decode by pouring liquids into basins [24]. Silence makes each rare voice matter [I].
- **Spelunky:** shopkeepers shoot thieves. After one is killed, every shop is hostile for the rest of the run, and a wanted shopkeeper waits at the exit [25]. An NPC with teeth makes the shop a decision instead of a menu [I].
- **Undertale:** one character remembers what you did before a reset, and only a special "true reset" wipes his memory [26]. In a game about restarts, an NPC who remembers is the strongest possible hook [I].
- **Mobile:** Soul Knight's lobby holds heroes you have unlocked, who can help or hinder once per level, and cage rescues give followers [27]. UnderMine grows its hub from rescued NPCs, including one merchant freed with two keys, and it hides a hub-room unlock in a run [28].
- **In-run devil trades:** the Binding of Isaac's devil beggar takes health for a chance at a rare item, and using it lowers the odds of a later, safer deal [29].

## 2. Principles

1. **Four fields, one line each.** Give every NPC a *want*, a *flaw or quirk* that shows in how they talk, a *secret*, and a *change*. Minor characters need a motive and one odd habit to stick, not a backstory [31].
2. **Found in trouble, then saved by a verb you already use.** Hollow Knight and Gungeon both rescue with a core verb: walking up, a key, clearing a room [10][15]. For us that means shooting, dashing or casting [I].
3. **The move to the hub is the payoff.** The hub visibly filling up is the progress meter [15][10].
4. **Each beat is gated on play, not on grinding a gift meter.** Hades locks hearts until a favor is done [2]. Our gates should be run events: bosses, deliveries, depth reached [I].
5. **Repeat less than you think.** Use conditional lines (prerequisites plus priority) and react to the last run and the current wand [5][8].
6. **Phone length.** Keep lines short, allow skipping, and write for split sessions [30]. The story bible's 60-character cap fits.
7. **Services add choice or information.** Neow's choice, the Lost Adventurer's hints and the Gunsling King's wager all add decisions without flat stats [11][12][22].
8. **One NPC may have teeth.** Charon's bag and Spelunky's shotgun make friendly NPCs tense in a good way [9][25].

## 3. Readability at 16-24 px

- **Silhouette first.** If the silhouette doesn't read, no shading will fix it. Test by squinting [32].
- **Few colours.** Use 2-3 values per part and 6-12 colours per character. At this size, suggestion beats detail: one dark pixel can be an eye [32][33].
- **For Wandcraft [I]:**
  - Each NPC gets one asymmetric prop that breaks the hero's outline: a lantern held forward, a slab-wide body, a stack of pages.
  - Each gets one bright signature pixel cluster from a Style ramp that no enemy uses.
  - Never use `glitch` or `threat` on a friendly NPC, and keep `moss` to an accent in World 1, or friends will read as enemies.
  - Give each a one-frame idle "tell" that works in peripheral vision: a lantern swing, a steam puff, a page flick.

## 4. Proposed cast

Services never add damage, health or drop rates. Every NPC has one in-run pickup that feeds their arc, like a Dead Cells blueprint, so that seeing them grow is tied to playing.

### GREP (World 1): the retired maintainer
- **Look:** hunched bone-grey hermit with a moss beard, holding a big sand-gold lantern forward on a pole.
- **Want:** to be left alone. Really, to be forgiven.
- **Quirk:** takes every question literally, like a search: "Ask exactly what you mean."
- **Secret:** he was the Guild reviewer who approved your Friday commit without reading it.
- **Found:** in the Root Cellar, a side room lit only by his lantern. His highlight glow spills onto the tiles of the rooms nearby, so you can follow it like the hum [16]. He is wrapped in eyed moss: clear the moss spawners around him and the roots let go.
- **Hub service, Search:** once per run, pick one of three questions ("Where's a Debug Terminal?", "What does the next boss hate?", "Is there a shop in Area 2?"). His true answer shows as a map ping or a Duck line in the run. It is information, never power.
- **In-run pickup:** Lost Comments, `//` notes scratched on World 1 walls.
- **Five-beat arc:**
  1. Rescue. He is grumpy and grateful. (Gate: freed.)
  2. Hub: he opens Search. (Gate: next Workshop visit.)
  3. The old days of tending the Source's roots. He mentions he "reviewed code, once". (Gate: 3 Lost Comments delivered.)
  4. He stares at your entry on the Commit Wall and goes quiet. (Gate: the Infinite Loop beaten and your own commit found in the log.)
  5. The confession. He now reads everything, so Search gains a 4th question, and the Duck forgives him too. (Gate: World 3 reached.)
- **Sample lines:**
  - "One question per run. I'm retired, not a genie."
  - "I wrote 'looks good to me'. I never read it."

### HOTFIX (World 2): the patchwork smith
Replaces the draft "Patch", which is kept as a fallback name.
- **Look:** squat golem, wider than the hero, with mismatched rust plates, a glowing ember chest core and a white tape X.
- **Want:** to make one thing that lasts.
- **Quirk:** fixes everything on sight, whether or not it's broken, and has already taped the Duck.
- **Secret:** he is a Glitch copy, a bug that wandered out of the Glitch's reach and chose to fix things instead of breaking them. LINT flags him every time.
- **Found:** in the Cooling Vents, stuck in a crash loop. He reboots mid-sentence every few seconds. Shoot three coolant valves while vent-spawned enemies come in, and he boots clean.
- **Hub service, the Skin Forge:** cosmetic wand skins and spell-trail colours for Bits. Nothing changes stats.
- **In-run pickup:** Scrap, dropped by World 2 mini-bosses.
- **Five-beat arc:**
  1. Rescue, mid-reboot. (Gate: freed.)
  2. He opens the Forge. (Gate: next visit, and the Merchant already open.)
  3. Everything he makes breaks by morning. He asks for Scrap "that remembers". (Gate: 3 Scrap delivered, or 3 skins bought.)
  4. LINT scans him: "Unrecognized process." He admits he woke up with no version number. (Gate: Deadlock beaten, with LINT present.)
  5. You give him a version. He stamps "v1.0" on his chest and forges one permanent skin, your hero's own. (Gate: 5 bounties claimed after beat 4.)
- **Sample lines:**
  - "Fixed it! Don't look at it too hard."
  - "Works on my forge. Can't promise yours."

### CACHE (World 3): the archivist who remembers you
Replaces the draft "Ada", which is a real person's name. "Cache" says what she does.
- **Look:** tall, thin violet figure with a leaning tower of white pages on her back and two cyan-bright eye pixels.
- **Want:** to finish the index: all 12 Lost Pages in order.
- **Quirk:** remembers your *last run* perfectly and forgets anything older, so she writes notes up her sleeves.
- **Secret:** she is the Arcanum's backup. The revert only works because someone kept a saved copy, and that copy is her.
- **Found:** in the Kernel archives, swapped out of memory. Her room is empty until you hit the page-fault switch. Then she loads in row by row, scanline from top to bottom. That load-in is the reveal moment.
- **Hub service, the Stacks:**
  - She reads the Lost Pages aloud.
  - Every 4 pages open a *branch*: a sidegrade rule set for a run, such as "wands are 2 slots shorter, mana regenerates twice as fast". You choose whether to play one; a branch is never a bonus.
- **Five-beat arc:**
  1. Load-in and confusion. (Gate: freed.)
  2. She opens the Stacks and recalls your last death exactly. (Gate: next visit.)
  3. "You're not the first apprentice." She has a log of dozens before you. (Gate: 4 Pages.)
  4. They all pushed on a Friday. She is frightened of what she is. (Gate: 8 Pages.)
  5. She tells you she is the backup, and the ending adds her epilogue panel. (Gate: 12 Pages and one win.)
- **Sample lines:**
  - "I remember everything. For about five minutes."
  - "Welcome back. The Loop got you last time. Twice."

### In-run event: NIT's code review
A rival apprentice, Nit, with red-ink pixels on a slate cloak, blocks a corridor. She says "Review my wand?" and shows her 4-slot wand. There are three choices:
- **Approve:** she leaves happy and pays Bits. She then turns up at the next boss as an ally for 20 seconds, but she was never reviewed, so every third shot heals the boss.
- **Request changes:** a short duel, a mini-boss using her own wand. Win, and you take one spell from it.
- **Pair up:** a visible swap. You give one spell of your choice and get one of hers.

The choice spends a known resource, gives something with a catch, or trades like for like, and all three are readable before you pick [12][29][I].

## Sources
1. Hades (video game), Wikipedia. https://en.wikipedia.org/wiki/Hades_(video_game)
2. Nectar, Hades Wiki (Fextralife). https://hades.wiki.fextralife.com/Nectar
3. Hades Nectar guide, RPG Site. https://www.rpgsite.net/feature/10266-hades-nectar-guide-who-to-gift-nectar-to-for-keepsakes
4. Hades' side quests provide closure for Greek myths, CBR. https://www.cbr.com/hades-supergiant-greek-myths-achilles-orpheus-sisyphus/
5. Breathing Life into Greek Myth: The Dialogue of Hades, GDC Vault. https://www.gdcvault.com/play/1026975/Breathing-Life-into-Greek-Myth
6. HadesDialogueExplorer (dialogue prerequisites graph). https://github.com/NikkelM/HadesDialogueExplorer
7. Kasavin on deaths driving a feel-good story, Inlander. https://www.inlander.com/archive/hades-writer-greg-kasavin-on-how-he-made-video-game-deaths-drive-a-feel-good/article_f508bf3c-7c29-5586-80ed-1cd615017dc1.html
8. Duo Boons, Hades Wiki; "Hidden dialogues" thread, Steam. https://hades.fandom.com/wiki/Duo_Boons and https://steamcommunity.com/app/1145360/discussions/0/1738886607257970767/
9. Charon, Hades Wiki. https://hades.fandom.com/wiki/Charon
10. The Breach, Enter the Gungeon Wiki. https://enterthegungeon.fandom.com/wiki/The_Breach
11. The Lost Adventurer, Enter the Gungeon Wiki. https://enterthegungeon.fandom.com/wiki/The_Lost_Adventurer
12. Gunsling King and Manservantes, Enter the Gungeon Wiki. https://enterthegungeon.fandom.com/wiki/Gunsling_King_and_Manservantes
13. Blueprints, Dead Cells Wiki. https://deadcells.wiki.gg/wiki/Blueprints
14. Bosses, Dead Cells Wiki. https://deadcells.wiki.gg/wiki/Bosses
15. Sly, Hollow Knight Wiki; Great Nailsage Sly. https://hollowknight.fandom.com/wiki/Sly and https://hollowknight.wiki.fextralife.com/Great+Nailsage+Sly
16. How to find Cornifer. https://hollowknight.fan/gameplay-tips-and-strategies/how-to-find-cornifer
17. Quirrel, Hollow Knight Wiki. https://hollowknight.fandom.com/wiki/Quirrel
18. Siegmeyer of Catarina, Dark Souls Wiki. https://darksouls.wiki.fextralife.com/Siegmeyer_of_Catarina
19. Solaire of Astora, Wikipedia. https://en.wikipedia.org/wiki/Solaire_of_Astora
20. Shops, Moonlighter Wiki. https://moonlighter.fandom.com/wiki/Shops
21. Follower traits and Dissenter, Cult of the Lamb Wiki. https://cult-of-the-lamb.fandom.com/wiki/Follower_traits and https://cult-of-the-lamb.fandom.com/wiki/Dissenter
22. Neow, Slay the Spire Wiki. https://slaythespire.wiki.gg/wiki/Neow
23. Jimbo, Balatro Wiki. https://balatrowiki.org/w/Jimbo
24. Game Lore, Noita Wiki. https://noita.fandom.com/wiki/Game_Lore
25. Shopkeeper (Classic), Spelunky Wiki; killing the shopkeeper, PC Gamer. https://spelunky.fandom.com/wiki/Shopkeeper_(Classic) and https://www.pcgamer.com/great-moments-in-pc-gaming-killing-spelunkys-shopkeeper/
26. SAVE, Undertale Wiki. https://undertale.fandom.com/wiki/SAVE
27. NPCs, Soul Knight Wiki. https://soul-knight.fandom.com/wiki/Category:NPCs
28. Hub, UnderMine Wiki. https://undermine.fandom.com/wiki/Hub
29. Devil Beggar, Binding of Isaac Wiki. https://bindingofisaac.fandom.com/wiki/Devil_Beggar
30. 10 tips for writing better mobile game dialogue; The Big Skip (MY.GAMES). https://www.amandalynn.ink/blog/10-tips-for-writing-better-mobile-game-dialogue and https://medium.com/my-games-company/the-big-skip-lets-talk-about-dialogues-in-games-7d04f70e666a
31. Questions to ask your minor characters, Writer's Digest. https://www.writersdigest.com/whats-new/questions-to-ask-strengthen-your-minor-characters
32. How to draw pixel art characters, Pixnote. https://pixnote.net/en/learn/character/
33. How to create 16x16 pixel art sprites, Sprite-AI. https://www.sprite-ai.art/guides/how-to-create-16x16-pixel-art

## 5+ original ideas for Wandcraft

1. **LGTM as the moral centre.** Grep's secret turns the game's twist ("you broke it") into a shared failure: someone approved it. The Duck's "Everyone pushes on a Friday" then covers two characters [I].
2. **NPCs appear in the stack trace.** The descent screen lists a found-but-unrescued NPC as a waiting call, for example `grep() ... waiting`. It works like the mapmaker's hum [16] but inside our own UI, and it tells you someone is down there before you meet them.
3. **The Hub reads your wand.** Hotfix and Cache comment on the wand you walk in with ("Seven boosts, one spell? Bold."), keyed on the last run's composition. It is Hades' build reactivity [8] applied to spell programs.
4. **LINT as the cross-examiner.** LINT has one line per NPC per beat ("Unrecognized process", "Reviewer found. Approval unread."), so NPC arcs move forward through banter with existing voices, the way Hades routes favors through other characters [4].
5. **Pair programming.** Bring one rescued NPC along for a run as a non-combat second. Each one trades something:
   - Grep: the map reveals, but pays fewer Bits.
   - Hotfix: repairs one wand slot a boss corrupts, but his skins are off for the run.
   - Cache: bookmarks your wand at the boss door once, but you get no Lost Page that run.
6. **Load-in reveals.** Found NPCs appear as a scanline render, a compile bar or a reboot flicker, a pixel-cheap signature reveal that fits "magic is code".
7. **A shop with teeth.** Hotfix's forge has a "DO NOT TOUCH" crate. Opening it starts a comic brawl and closes the forge for one run, echoing Charon's bag [9] and Spelunky [25].
