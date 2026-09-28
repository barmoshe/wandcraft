# Storytelling in roguelikes and games with repetition (research for Wandcraft World 3)

Written 2026-09-28. Sources are numbered at the end. `[I]` marks my inference, not a sourced claim. Nothing here copies text, names or art from the games discussed; they are cited for their *mechanisms*.

Note on method: page fetches were blocked by the network proxy in this session, so the claims below come from search-result extracts of the cited pages. Where an extract was thin I say so or mark `[I]`.

Context checked in the repo (read only): `research/story.md`, `research/voices-plan.md`, `game/scripts/sim/story.gd`. Today the first win (Deadlock) already shows "revert" in the ending panels and the Duck's log entry says "it was you". World 3 has to *extend* that twist, not re-tell it (see the outline at the end).

---

## 1. Hades and Hades II: story as the reward for failing

**Death as progress.** Hades puts dying and regenerating at the centre of its story, so each death advances something: conversations develop, new characters show up, plot turns land across dozens of failed runs [2]. Kasavin's framing: if the player remembers their deaths and learns, the protagonist should too, so the cast is aware of the cycle [2][11]. The working phrase inside Supergiant was "take the sting out of failure" [7].

**The conversation bucket.** The system is a pool of possible conversations, filtered by game conditions and weighted by importance and immediacy; when you talk to someone, the game weighs the candidates and picks the best one for that moment [4]. Nearly every line has prerequisites: earlier conversations, bosses seen, situations that happened [4]. Critical story events sit in a higher priority tier and pre-empt general chatter [5]. Kasavin endorsed a public breakdown of this system (with Rao and Kasavin interviewed) [5].
- **Scale:** over 21,000 voiced lines and 300,000+ words, with the protagonist alone at about 8,500 [6]. Hades II is roughly 50% larger: 400,000+ words, 30,000+ voice lines [10]. A small team did this because the system, not linear scripting, carries the load [1].
- **Responsiveness is the point:** each god and shade has a clear personality and comments on the player's behaviour in its own way, which Kasavin says makes each run feel unique [1].

**True ending after N wins, then an epilogue.** The true ending needs ten separate escapes; each successful escape unlocks more conversation with the person you escape to, and after a further escape a unique scene reunites the family, followed by an epilogue that closes most character arcs [7]. The epilogue is an ongoing state of the hub, not a cutscene: the game keeps going [7][I].

**Objectives that point at story.** The Fated List of Minor Prophecies is a desk scroll of 55 tasks (89 in Hades II) that unlock as the story progresses; most are about *experiencing* things, many gated on a gift or a specific talk [13]. It turns "go find the story" into a visible goal list [I].

**Endings are revisable.** Hades II's post-launch patch added events before the true ending, raised the number of clears needed, and revised the final scenes after player feedback [9]. Kasavin: stories feel immutable, but myths are told and retold [8].

**Bastion's rules (same writer).** Kasavin's five rules for reactive narration: dialogue is for subtext (the player's action is the text), keep it short, don't break the fourth wall, reward experimentation and finesse, and never repeat [12]. The narrator started as the answer to "how do we tell a memorable story without interrupting the action" [12].

**Takeaways for Wandcraft [I]:** `story.gd` already has an ordered-then-random picker. The missing layer is Hades' *prerequisites plus priority*: each entry gets `needs` (facts) and a tier (`essential` beats `flavour`). That is enough to make the Duck and LINT react to the last run, and to gate a true ending.

## 2. Barks and fact matching (Valve)

Elan Ruskin's GDC 2012 talk on Left 4 Dead 2's dialogue: the game tracks many facts about the world uniformly, then fuzzy-matches them against a database of lines; the most specific matching rule wins, which cascades from special cases down to a general fallback, and characters can "remember" by writing facts back [35]. **For Wandcraft [I]:** a line like "three triggers, and you still died to a slime" is just a rule with three criteria (`died_to=slime`, `triggers>=3`, `event=hub_death`) that outranks the generic death line. The hub reacting to the last run is cheap once runs write a small fact dictionary.

## 3. Knowledge as progress: Outer Wilds, Returnal, Inscryption

**Outer Wilds** is knowledge-gated: Beachum wanted a game about exploring because you want answers, driven by curiosity [15]. Progress is what you learned; the ship's log keeps what you discovered through every loop reset [15][16]. **Lesson [I]:** the commit log should be *used*, not only read. A player who has read an entry should be able to do something new (a terminal command, a door, a dialogue branch).

**Returnal** treats repetition as how the character is revealed: the more cycles, the more of Selene you uncover, through audio logs, first-person house sequences and cinematics [20][21]. Housemarque's rule is that story should not compromise play but explain and deepen it [20]. Its secret ending recasts the player-character as the cause of the original accident, a guilt loop the player has been physically inside [22]. That is the closest published model to "the bug was your own commit".

**Inscryption** builds a game-within-a-game and uses its meta-puzzles so that solving them teaches the player the card game's logic, a story purpose and a psychology purpose at once [18]. Its death cards are the key device for us: when you die you design a card from parts of your own deck, and your earlier death cards reappear later, even in the hands of an antagonist [19]. The postmortem covers how the ending even left the game (an ARG, a mailed floppy disk) [17]. **Lesson [I]:** the player's own past runs are the cheapest, most personal enemy material you have.

## 4. Two voices that play off each other

**Disco Elysium** turns skills into inner voices that interrupt, disagree and frame choices through competing kinds of perception; critical information is repeated by several voices at key moments [23]. **Portal 2**'s two AIs contrast a slow, deliberate voice with a babbling, ad-libbed one [40]. **Bastion** keeps the narrator on subtext and never play-by-play [12].

**Rules for Duck and LINT [I]:**
1. **LINT states, the Duck interprets.** LINT reports the fact ("Build failed"); the Duck says what it means to you. The repo already does this ("LINT gives the world's news, and the Duck gives your side of it").
2. **One joke per exchange.** The straight line sets it up, the other lands it. Never two punchlines.
3. **Give each a tell.** LINT never says "I" and never uses a feeling word. The Duck never uses a number. Breaking a tell once, late, is the arc (see idea 3).
4. **Let them disagree about you.** Disco's voices are good because they want different things [23]. LINT wants the build clean; the Duck wants you okay. In World 3 those wants collide.

## 5. Environmental and collectible storytelling

Smith and Worch's GDC 2010 talk: the environment is a narrative device that asks the player to *infer* what happened, using props, lighting, composition and systems that react [36]. Smith: it has to be possible to miss things, or finding them means nothing [36]. **Dead Cells** began with no story at all because lore slowed the die-and-retry loop; nobody on the team was a writer, so the story went into the world and a silent, expressive protagonist [24]. **Slay the Spire** scatters lore through events and item text [26]; its final act is gated by three keys, each costing something small in the run (a rest, a relic, a harder elite) [25]. **Loop Hero** makes the mechanic the fiction: the hero has forgotten the world, and placing cards is remembering it back [29]. **Hades' Codex** tracks lore and relationships as you meet things [14].

**Lore people read [I]:** entries that are short, signed by a character, funny, and that *change what you do next*. Wandcraft's commit log already has the first three (a moss that asks why it has eyes). Slay the Spire's keys add the fourth: the collectible is also a cost-and-reward decision in the run.

## 6. Remembering the player, and the player as the cause

**Undertale** makes save and load part of the fiction: a character remembers your resets, and a true reset still cannot erase a genocide run [30]. **Deltarune** opens by telling you your choices do not matter, then later makes them matter permanently, a promise it broke on purpose [31]. **Pentiment** makes people remember accusations: the town you shaped greets you coldly years later, and consequences reach everyday dialogue, not just endings [32].

**Twists where the player is the cause:** Braid's final level runs backwards and recasts the hero as the one the princess was fleeing, the mechanic *is* the reveal [38]. Spec Ops: The Line slowly pulls the rug until you see you chose to do it; its writer says the game reacts to you [37]. Returnal puts the player-character at the root of the accident [22]. NieR: Automata's happy ending asks you to delete your own save to help strangers [39]. **Cult of the Lamb** ends with the patron who saved you demanding your life; if you win, he points out you can no longer blame him for what you did [28].

**What lands a "you did it" twist [I]:**
- **Plant it in a mechanic the player already trusts** (Braid's rewind, Wandcraft's left-to-right casting).
- **Make the evidence the player's own data**, not a cutscene claim (Inscryption's death cards, Undertale's save).
- **Follow guilt with a choice**, and make the kind option cost something real (NieR, Cult of the Lamb).
- **Keep it warm.** Hades chips away at conflict instead of escalating it [2]. The Duck's "everyone pushes on a Friday" is the right tone.

## 7. Short lines on a phone, and games that skip story

Mobile dialogue should be 2 to 4 short lines, omit needless words, and let art and UI carry description; players on the move may not finish reading [41]. **20 Minutes Till Dawn** ships with almost no in-game story at all, and players still ask about lore on its forums [34]. **Citizen Sleeper** lets systems (dice, clocks) generate the story, the way tabletop games do [33].

**Rules for Wandcraft's box [I]:** one idea per line; a proper noun or number in the first three words so a glance lands it; the voice line ends on the punch; and every beat must survive being skipped (the log keeps it).

## 8. The finale using the player's build

Few games do this well. Inscryption reuses your cards [19]; Gungeon gives each character a private "past" fight for their backstory [27]. **Opportunity [I]:** Wandcraft's wand is literally a program. A finale that *reads the player's wand back to them as code* is on-theme, cheap (the data exists), and personal.

---

## 5+ original ideas for Wandcraft

**1. The Regression (final boss).** The bug made flesh is built from your commit and from *you*: it casts your current wand's spells in reverse order (right to left), because it is the diff of your run played backwards. Its health bar is a diff: green `+` lines drain, red `-` lines grow. Phase 2 uses the wand you died with most recently (a death-card echo [19]). *Why:* the Braid rule, the reveal is in a mechanic you trust [38], and the evidence is your data. *Cost:* M (a reversed-cast pass on the existing wand sim, one boss rig). *Phone:* strong; no new controls, the mirror reads instantly.

**2. Revert or fix forward (two endings, one true).** The World 2 revert undid your commit, but the Glitch had write access and had committed on top of it (log `deadbe` already says so). In `kernel()`, a plain **revert** wins the run: the Source rolls back to 16:58, and everything that grew from your bug goes quiet, including the Duck's voice. That is the normal ending. The **true ending** is **fix forward**: after N kernel clears and all logs found, you get a patch that keeps what grew (the eyed moss stays, now friendly; the three NPCs stay; the Duck keeps talking). It uses a real engineering debate as the moral choice. *Why:* Hades' N-wins true ending [7] plus NieR's cost [39], themed. *Cost:* M (one flag, two panel sets, 6 to 10 lines). *Phone:* strong; panels already exist.

**3. The Duck's secret and LINT's suppressed warning.** Two late log entries turn both companions. (a) The Duck's first commit is timestamped 16:59:01: it started talking *because of* your bug, and it has known since the root cellar. Its warmth was never neutral. (b) LINT flagged your commit at 16:58 and you pushed with the warning ignored. LINT's deadpan "You will not read it" was literal. In the finale LINT must sign the revert; it says its first line with "I" in it, and its first non-warning word ("Approved."). *Why:* the voices' tells (rule 3, section 4) break exactly once; a guilt twist lands softer when a friend shares it [2][28]. *Cost:* S (two log entries, 4 to 6 lines). *Phone:* ideal, it is all lines.

**4. `git bisect` terminal (knowledge as a key).** In `kernel()`, a Debug Terminal shows the ten commits and asks which half the bug is in; three taps narrow it to your own commit. Solving it once is remembered forever (Outer Wilds [15]) and unlocks the fix-forward branch. Players who read the log breeze through; others learn the log by using it. *Why:* the collectible changes what you do next (section 5). *Cost:* S to M (one screen). *Phone:* great; three big buttons.

**5. The finale reads your wand as code.** The boss entrance and ending panel 3 print the player's actual wand as a one-line program (the icons in order, plus trigger arrows), and LINT reviews it: a line picked by fact matching [35], e.g. "3 triggers, no boosts. Bold." The fix-forward patch *is* that wand. *Why:* the player's build becomes the story's final argument. *Cost:* S to M (reads existing wand data; a small rule table). *Phone:* good if the program renders as icons, not text.

**6. The clock descends too.** Environmental storytelling in the tiles [36]: each world has a wall clock. World 1 reads 16:59:57, World 2 16:59:58, `kernel()` 16:59:59, and the boss arena is your desk in the Guild at the moment you pressed push. Nobody explains it. *Why:* missable, so finding it means something [36]. *Cost:* S (one prop, three strings). *Phone:* fine; the clock is big pixel digits.

**7. Blameless post-mortem (hub epilogue).** After the true ending the Workshop holds a post-mortem: the Duck, LINT and the three rescued NPCs each give one line, and the Commit Wall becomes a Changelog. Later runs are "regression tests" with new barks and a fresh priority tier of epilogue lines, like Hades' ongoing epilogue [7]. *Why:* ends on the theme's kindest idea: blame the process, not the person. *Cost:* M (a hub state and 20 to 30 lines). *Phone:* good, all short barks.

**8. Three NPCs as orphaned processes.** Each NPC found in a run is a process your bug left running: a child process whose parent died (lost, looking for a parent), a deprecated spell that remembers the Source before Friday (the lore keeper), and a daemon that never stopped its one job (the shop). Each moves into the hub after a rescue and has one line reserved for each ending. *Why:* victims make the guilt concrete; the fix-forward ending is the only one where they survive. *Cost:* M. *Phone:* good.

---

## Proposed World 3 beat outline: `kernel()`

- **Entry (descent screen).** The stack trace ticks `root_cellar()` and `foundry()` OK, and a new frame appears under `kernel()`: `at apprentice.push()`. LINT: kernel entered, permissions: yours. The Duck, for once, has nothing to add. The clock prop shows 16:59:59 (idea 6).
- **Area 1, early.** Walls of frozen log lines. The first orphaned-process NPC is found. Enemies are forks of earlier Glitch creatures, a little wrong.
- **Mid.** The `git bisect` terminal (idea 4). LINT's suppressed-warning entry drops here (idea 3b). The Duck and LINT disagree for the first time: LINT wants the build clean; the Duck wants you okay.
- **Mini-boss.** A Race Condition: two copies of one creature race to reach you, and whichever arrives first sets the fight's rules. The Duck's 16:59:01 entry drops on its fall (idea 3a).
- **Boss entrance.** Your desk. The Regression rises out of the monitor with your commit message as its title card. LINT reads your wand aloud as code (idea 5). The Duck: one quiet line, no joke.
- **Fall.** At low health the boss offers the choice: **revert** (always there) or **fix forward** (only if the true-ending gate is met). LINT signs it, with its first "I".
- **Ending (four panels).** Revert: the Source rolls back a second, the moss closes its eyes, the Duck goes silent mid-quack, and a final card at 16:58 shows the unpushed commit. Fix forward: the patch is your wand, the moss keeps its eyes, the Duck gets the last line.
- **Epilogue (hub).** The blameless post-mortem (idea 7). The Commit Wall becomes the Changelog, the three NPCs have their ending lines, and new runs are regression tests.

**Repo notes [I].** `story.gd` says log ids are append-only, so new entries go at the end, and any change to an existing entry's `at` needs its voice file checked. The first-win panels already reveal revert. The cleanest fix is to reword panel 4 of the World 2 ending ("The revert holds. Mostly.") so the World 3 twist extends it and does not repeat it.

---

## Sources

1. GDC Vault, Kasavin and Korb, "Breathing Life into Greek Myth: The Dialogue of Hades" (GDC 2021): https://www.gdcvault.com/play/1026975/Breathing-Life-into-Greek-Myth ; coverage: https://www.gamedeveloper.com/audio/dive-into-the-dialogue-of-i-hades-i-at-gdc-2021
2. Game Developer, "How Supergiant weaves narrative rewards into Hades' cycle of perpetual death": https://www.gamedeveloper.com/design/how-supergiant-weaves-narrative-rewards-into-i-hades-i-cycle-of-perpetual-death
3. GDC Podcast ep. 16, Kasavin on roguelikes and narrative design: https://gdconf.com/article/roguelikes-and-narrative-design-with-hades-creative-director-greg-kasavin-gdc-podcast-ep-16/
4. Christi Kerr, "How the Dialogue System in Hades Rewards Failure": https://www.christi-kerr.com/post/how-the-dialogue-system-in-hades-rewards-failure
5. "The System Behind Hades' Astounding Dialogue" (video, endorsed by Kasavin): https://www.youtube.com/watch?v=bwdYL0KFA_U ; Kasavin's post: https://x.com/kasavin/status/1329487797607043073
6. Nintendo Wire, Hades dialogue breakdown: https://nintendowire.com/news/2020/12/30/hades-has-over-300000-words-of-voiced-dialogue-heres-a-handy-breakdown-of-who-speaks-most-and-least/
7. Hades Wiki (Fextralife), Endings: https://hades.wiki.fextralife.com/Endings
8. GamesRadar+, Hades II true ending change, "told and retold": https://www.gamesradar.com/games/roguelike/they-werent-distributed-on-steam-but-hades-2-lead-who-oversaw-that-true-ending-change-says-myths-are-also-told-and-retold-by-design/
9. GameSpot, "New Hades 2 Patch Expands The Ending": https://www.gamespot.com/articles/new-hades-2-patch-expands-the-ending/1100-6535860/
10. eTeknix, Hades 2 has 50% more dialogue: https://www.eteknix.com/hades-2-includes-50-more-dialogue-than-the-first-game/
11. Inlander, Kasavin on deaths driving a feel-good story: https://www.inlander.com/culture/hades-writer-greg-kasavin-on-how-he-made-video-game-deaths-drive-a-feel-good-story-22725237
12. Supergiant Games, "In-Depth: Writing Bastion": https://www.supergiantgames.com/blog/in-depth-writing-bastion/
13. Hades Wiki (Fandom), Fated List of Minor Prophecies: https://hades.fandom.com/wiki/Fated_List_of_Minor_Prophecies
14. Hades Wiki (Fandom), Codex: https://hades.fandom.com/wiki/Codex
15. Interview with Alex Beachum (Outer Wilds): https://medium.com/@cordialkobold/interview-with-alex-beachum-creative-director-of-outer-wilds-a01bb9631e20
16. Outer Wilds Wiki, Computer / ship log: https://outerwilds.fandom.com/wiki/Computer
17. Mullins, "Sacrifices Were Made: The Inscryption Post-Mortem" (GDC 2022 slides): https://media.gdcvault.com/GDC+2022/Speaker+Slides/GDC22_Inscryption_Post-Mortem.pdf
18. Game Developer, "How a game jam on 'sacrifices' became Inscryption": https://www.gamedeveloper.com/design/how-game-jam-sacrifices-became-inscryption
19. Inscryption Wiki, Deathcard: https://inscryption.fandom.com/wiki/Deathcard
20. Unreal Engine, "Deciphering the narrative-driven procedural horror of Returnal": https://www.unrealengine.com/developer-interviews/deciphering-the-narrative-driven-procedural-horror-of-returnal
21. GamingTrend, interview with Gregory Louden: https://gamingtrend.com/interviews/back-to-atropos-an-interview-with-returnal-narrative-director-gregory-louden-of-housemarque/
22. Den of Geek, Returnal ending and secret ending explained: https://www.denofgeek.com/games/returnal-ending-secret-ending-explained-theories/
23. Steam, "Choose your own misadventure, Part 2: Interview with Robert Kurvitz": https://steamcommunity.com/games/632470/announcements/detail/1615021499154801682
24. Engadget, "The rich and mysterious story buried in Dead Cells" (GDC 2019): https://www.engadget.com/2019-04-03-dead-cells-story-lore-interview-gdc-2019.html
25. Slay the Spire Wiki, Keys: https://slay-the-spire.fandom.com/wiki/Keys ; Act 4: https://slay-the-spire.fandom.com/wiki/Act_4
26. CBR, Slay the Spire world lore: https://www.cbr.com/slay-spire-world-lore/
27. Enter the Gungeon Wiki, The Past: https://enterthegungeon.wiki.gg/wiki/The_Past
28. Sportskeeda, Cult of the Lamb endings explained: https://www.sportskeeda.com/esports/cult-lamb-endings-explained ; ScreenHub, JoJo Zhou on the narrative: https://www.screenhub.com.au/news/features/cult-of-the-lamb-interview-jojo-zhou-2684125/
29. Kotaku, "Loop Hero Is A Wonderful New RPG About Overcoming Despair": https://kotaku.com/loop-hero-is-a-wonderful-new-rpg-about-overcoming-despa-1846409109 ; Destructoid, "Loop Hero's best trait is its lore": https://www.destructoid.com/loop-heros-best-trait-is-its-lore/
30. Undertale Wiki, SAVE: https://undertale.fandom.com/wiki/SAVE ; Wikipedia, Flowey: https://en.wikipedia.org/wiki/Flowey
31. salmonkarp, "Deltarune Has Found its Identity": https://medium.com/@salmonkarp/deltarune-has-found-its-identity-32088f0be906
32. Digital Trends, Pentiment interview (Alec Frey): https://www.digitaltrends.com/gaming/pentiment-interview-alec-frey-choice/ ; TheGamer, Josh Sawyer interview: https://www.thegamer.com/interview-obsidian-josh-sawyer-pentiment/
33. Game Developer, "How Citizen Sleeper was inspired by tabletop RPGs and gig work": https://www.gamedeveloper.com/business/how-citizen-sleeper-was-inspired-by-tabletop-rpgs-and-gig-work
34. Steam discussions, 20 Minutes Till Dawn "Story/narrative/lore?": https://steamcommunity.com/app/1966900/discussions/0/3422186614292999697
35. Elan Ruskin, "AI-driven Dynamic Dialog through Fuzzy Pattern Matching" (GDC 2012): https://gdcvault.com/play/1015528/AI-driven-Dynamic-Dialog-through ; slides: https://cdn.akamai.steamstatic.com/apps/valve/2012/GDC2012_Ruskin_Elan_DynamicDialog.pdf
36. Smith and Worch, "What Happened Here? Environmental Storytelling" (GDC 2010): https://gdcvault.com/play/1012647/What-Happened-Here-Environmental ; Nieman Storyboard, Harvey Smith: https://niemanstoryboard.org/2011/01/14/harvey-smith-on-environmental-storytelling-and-embedding-narrative/
37. Game Developer, "Spec Ops: The Line hates you": https://www.gamedeveloper.com/design/-em-spec-ops-the-line-em-hates-you
38. Wikipedia, Braid: https://en.wikipedia.org/wiki/Braid_(video_game)
39. Siliconera, Yoko Taro on NieR: Automata endings: https://www.siliconera.com/yoko-taro-talked-about-nier-automata-inspiration-and-endings/ ; Kotaku: https://kotaku.com/theres-a-difficult-decision-at-the-end-of-nier-automat-1793071026
40. EA, Portal 2 interview with Erik Wolpaw: https://www.ea.com/en-gb/news/portal-2-interview-erik-wolpaw
41. Game Developer, "10 Tips for Writing Better Mobile Game Dialogue": https://www.gamedeveloper.com/game-platforms/10-tips-for-writing-better-mobile-game-dialogue
