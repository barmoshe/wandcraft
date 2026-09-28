class_name Story
extends RefCounted
## The story (research/story.md): the Arcanum runs on the Source, one great spell-program.
## On your first day as a spellwright, a Friday at 4:59 pm, you pushed one small fix. It
## compiled, and the Glitch hatched. Your rubber duck (the one you debug out loud to) talks
## back, and the two of you follow the bug's stack trace down: the Root Cellar, the Grove,
## the Loop that spins the world at 100%, the Foundry it overheats, and Deadlock, which
## guards the Kernel where the bug lives.
##
## Two voices (research/voices-plan.md): the DUCK is on your side (tips, jokes, reactions);
## LINT, the Guild's linting robot, is the system (world entries, warnings, build results,
## the commit log read aloud). Every line is voiced from game/assets/voice (tools/voices.sh),
## and the text always shows, so it doubles as subtitles.
##
## Told a line at a time, never in the way (Hades' rule: story as a reward for playing):
##   lines        at run start, area and world changes, boss entrances and falls, deaths and
##                the win; each event plays its entries in order the first time through the
##                story, then picks among them (seen counts live in meta.json)
##   the log      seventeen entries found at Debug Terminals and at story beats (Codex LOGS)
##   panels       the intro (a first run) and the ending (a first win)
##   barks        round 2: the companions' bubbles, picked by rules over facts (Barks)
## Ids are "<event>.<entry>" (".<k>" for a line of an exchange): append, never reorder, or
## the voice files stop matching.

const DUCK := "DUCK"
const LINT := "LINT"
## 0.20: everyone who speaks (the residents' tags live in Residents).
const SPEAKERS := [DUCK, LINT, "GREP", "HOTFIX", "CACHE"]

## event -> entries. An entry is the Duck's line (a String) or an exchange: [[who, text], ...].
## Plain and short: one line on a phone is about 60 characters, and a voice line under 6 s.
const LINES := {
	"first_run": [
		[[LINT, "New process started. One apprentice, one duck."], [DUCK, "Quack. You talk, I listen, we find the bug."]],
		[[DUCK, "First run. Nobody expects it to work."], [LINT, "Expectation: logged."]],
		"Aim at the moss. Not at me. I'm the duck.",
		[[LINT, "Practice mode. Mistakes are free."], [DUCK, "So make lots. That's how we learn."]],
	],
	"run": [
		"From the top. The bug is where we left it.",
		[[LINT, "Process restarted. Attempt logged."], [DUCK, "New process, same bug. Let's trace it."]],
		"Tip: a wand reads left to right. The spell on the right fires.",
		"I've been thinking about your wand. Mostly about boosts.",
		[[DUCK, "Run it again. Bugs hate being reproduced."], [LINT, "Correction. Bugs are indifferent."]],
		"Every crash was a clue. Let's use them.",
	],
	"grove": [
		[[LINT, "Entering the Corrupted Grove. Duplicate objects detected."], [DUCK, "The Glitch nests here. Everything is copied twice."]],
		"Smell that? Corrupted moss. A cache miss, but for trees.",
		"Deeper in. The stack trace gets louder here.",
	],
	"world2": [
		[[LINT, "Entering World 2. The Overheated Foundry. Temperature: unwise."], [DUCK, "Where the world's spells are forged. It's running hot."]],
		"The Loop's heat drains down here. Follow it to the Kernel.",
		"Welcome back to the Foundry. Mind the Proxies: hit them first.",
	],
	"core": [
		[[LINT, "Warning. Core temperature: one hundred and four degrees."], [DUCK, "The Molten Core. Don't touch the orange."]],
		"Hear that hum? Two locks, waiting for each other. We're close.",
	],
	"boss:Copy-Paste": [
		[[LINT, "Warning. Duplicate wand detected."], [DUCK, "It copied your wand. Your own spells, pointed at you."]],
		[[DUCK, "Copy-Paste again. It learned from your last wand."], [LINT, "Plagiarism detected."]],
	],
	"boss:Garbage Collector": [
		[[LINT, "Memory sweep in progress. Please hold still."], [DUCK, "Please don't. Blast its plating, and stop when the lid opens."]],
		"Don't feed it. When the lid opens, stop shooting.",
	],
	"boss:The Infinite Loop": [
		[[LINT, "Warning. Infinite loop detected."], [DUCK, "It's why the world runs at a hundred percent. Break it."]],
		"Break the body in its second phase. It gets smaller, and angrier.",
		"Stay out of its lane. It's watching where you stand.",
	],
	"boss:Deadlock": [
		[[LINT, "Two processes, each waiting for the other. Estimated wait: forever."], [DUCK, "Hit the open lock. When the beam flickers, move."]],
		"When the beam flickers, get out of the circle.",
	],
	"down:The Infinite Loop": [
		[[LINT, "Loop terminated. World load: ninety-nine percent."], [DUCK, "It broke! Now, where does all that heat go?"]],
		"Loop broken. The trace goes down. Take the stairs.",
		[[DUCK, "It stopped! First loop ever to stop."], [LINT, "Exit condition: you."]],
		"The world spins a little slower. Nice.",
	],
	"down:Deadlock": [
		[[LINT, "Locks released. Kernel access granted."], [DUCK, "Behind them: the bug. Let's go see it."]],
		[[LINT, "Deadlock resolved. Both locks free."], [DUCK, "They just needed someone to go first."]],
		"The locks let go. The Kernel is below.",
	],
	"down:mini": [
		"Mini-boss down. Keep the wand, keep going.",
		[[DUCK, "Nice. That one will be back, with a version number."], [LINT, "Version two point oh: scheduled."]],
		[[LINT, "Mini-boss removed."], [DUCK, "Keep the loot. Leave the grudge."]],
		"Small boss, big mess. On we go.",
	],
	"untouched": [
		[[LINT, "No damage taken. Bonus reward unlocked."]],
		[[LINT, "Zero damage. Suspicious."], [DUCK, "Not suspicious. Skilled."]],
		"Not a scratch. Show-off. I love it.",
		[[DUCK, "Untouched! Frame that room."], [LINT, "Room saved as a reference."]],
	],
	"descend": [
		[[LINT, "Stack frame complete. Descending."], [DUCK, "Hold on to your wand."]],
		"Down a frame. The bug is deeper still.",
		[[LINT, "Returning to caller. Caller: further down."], [DUCK, "Every floor down is one step closer."]],
		"Mind the drop. Stack frames are steep.",
	],
	"death": [
		[[LINT, "Build failed."], [DUCK, "The Glitch wins this one. Not the next."]],
		"Crash report filed. Let's reproduce it.",
		[[DUCK, "Everyone crashes. The good ones read the log."], [LINT, "Log saved. You will not read it."]],
		"Quack. That hurt to watch.",
		"We learned something. Mostly about dodging.",
	],
	"win": [
		[[LINT, "Build passed. All tests green."], [DUCK, "Quack! We did it."]],
		[[LINT, "Build passed. Zero warnings."], [DUCK, "Not even one? Who are you?"]],
		[[LINT, "Exit code zero. Success."], [DUCK, "Zero means good. Programmers are odd."]],
		[[DUCK, "Green across the board!"], [LINT, "Green is the colour of passing."]],
	],
	# Bug Reports (Meta.HEAT): LINT reads the run's tier at the start
	"heat:1": [
		[[LINT, "Bug report one. Every fight brings an elite."]],
		[[LINT, "Bug report one. Elites in every fight."], [DUCK, "Every fight? Bring your best wand."]],
		"One bug report. Elites everywhere. Fun.",
	],
	"heat:2": [
		[[LINT, "Bug report two. Enemies hit harder."]],
		[[LINT, "Bug report two. They hit harder."], [DUCK, "So we dodge harder. Simple."]],
		"Report two. Everything bites a bit more.",
	],
	"heat:3": [
		[[LINT, "Bug report three. Faster shots, fewer doors."]],
		[[LINT, "Bug report three. Faster shots."], [DUCK, "And fewer doors. Choose well."]],
		"Three reports. Their shots got quicker.",
	],
	"heat:4": [
		[[LINT, "Bug report four. Weaker springs, higher prices."]],
		[[LINT, "Bug report four. Springs heal less."], [DUCK, "And shops charge more. Get hit less."]],
		"Four reports. Even the shops got greedy.",
	],
	"heat:5": [
		[[LINT, "Bug report five. Bosses skip straight to their worst."]],
		[[LINT, "Bug report five. Bosses start angry."], [DUCK, "No warm-up. Straight to the worst."]],
		"Five reports. This is the hard mode. Quack.",
	],
	# the Workshop (0.19, research/workshop-0.19.md): one line as you walk in, fitted to how
	# the last run went (Hub.greeting), and a word from the Duck or LINT when you talk to them
	"hub_first": [
		[[LINT, "Workshop online. All stations ready."], [DUCK, "Walk up to anything and use it. The portal starts a run."]],
		[[DUCK, "This is home now. The bug can wait."], [LINT, "The bug cannot wait. It is a bug."]],
		"Home base. Wands, spells, a portal. Snacks: no.",
	],
	"hub_back": [
		"Back in the Workshop. The bug hasn't moved.",
		[[LINT, "Session resumed."], [DUCK, "Pick a station. Or just the portal."]],
		"The coffee here is compiled. Don't ask how.",
	],
	"hub_death": [
		[[DUCK, "That run crashed. The log has the answer."], [LINT, "Crash report pinned to the Commit Wall."]],
		"Walk it off. Then try a different wand.",
		[[LINT, "Failure logged."], [DUCK, "Logged, not forgotten. Again?"]],
	],
	"hub_boss": [
		[[DUCK, "So close. That boss knew your wand."], [LINT, "Suggestion: change the wand."]],
		"Next time, save a dash for its big attack.",
	],
	"hub_win": [
		[[LINT, "Build passed. The Guild is impressed."], [DUCK, "Now try the heat. I dare you."]],
		"A win. Somewhere deep, the bug is sulking.",
	],
	"hub_quit": [
		"Quitting counts as debugging. Sometimes.",
		[[LINT, "Process terminated by user."], [DUCK, "Fresh start, fresh wand."]],
	],
	"hub_unlock": [
		[[LINT, "New station online."], [DUCK, "Go on, have a look."]],
		[[LINT, "Station unlocked. Manual attached."], [DUCK, "Nobody reads the manual. Just press it."]],
		"Something new lit up. Go poke it.",
		[[LINT, "New feature shipped."], [DUCK, "On a Friday? Kidding. Go look."]],
	],
	"hub_hero": [
		"New hero, same bug.",
		[[LINT, "Hero profile updated."], [DUCK, "Looking sharp."]],
	],
	"pkg_bought": [
		[[LINT, "Package installed. Every run after has it."], [DUCK, "Try it on the dummy first."]],
		"More spells. More ways to break things.",
	],
	# round 2: a word on each pack bought ("pkg_bought:<pack id>"; "pkg_bought" is the fallback)
	"pkg_bought:triggers": [
		[[LINT, "Triggers installed. Spells can call spells."], [DUCK, "Put one between two spells. Watch."]],
		"THEN: do this, then that. Like a recipe.",
		[[DUCK, "Chain reactions, on purpose!"], [LINT, "Accidental chains: also supported."]],
	],
	"pkg_bought:glitch": [
		[[LINT, "Glitch pack installed. Handle with gloves."], [DUCK, "Bugs as weapons. Poetic."]],
		"Rot makes enemies crash. Like my old laptop.",
		[[DUCK, "Mines and marks. Sneaky."], [LINT, "Sneaky is not a category. It should be."]],
	],
	"pkg_bought:flow": [
		[[LINT, "Flow Control installed. More ways to chain."], [DUCK, "Now your wand has a to-do list."]],
		"Sleep, fork, wait. Spells on a schedule.",
		[[DUCK, "A spell called Finally. Finally!"], [LINT, "It waits for a kill. Patient."]],
	],
	"pkg_bought:physics": [
		[[LINT, "Physics installed. Gravity now optional."], [DUCK, "Spells that orbit. Keep your head down."]],
		"Mirrors and orbits. Your shots go sightseeing.",
		[[DUCK, "Orbit Rune: a shield of your own spells."], [LINT, "Self-defence. Recursive."]],
	],
	"pkg_bought:risk": [
		[[LINT, "Risk pack installed. Warranty void."], [DUCK, "Big payoffs. Big oops. Pick one."]],
		"Low mana, high damage. Live a little.",
		[[DUCK, "Playing on the edge now?"], [LINT, "The edge has been logged."]],
	],
	"pkg_bought:debugger": [
		[[LINT, "Runes installed. They edit the wand itself."], [DUCK, "A wand that rewrites itself. Cool."]],
		"GOTO jumps back to the start. Old magic.",
		[[DUCK, "HEAD copies your first spell. Free."], [LINT, "Free: an acceptable price."]],
	],
	"pkg_bought:net": [
		[[LINT, "Networking installed. Mark, then deliver."], [DUCK, "Tag a target. Mail it a spell."]],
		"Broadcast: one spell, every inbox.",
	],
	"pkg_bought:threads": [
		[[LINT, "Concurrency installed. Workers ready."], [DUCK, "Little helpers! Do they need lunch?"]],
		"More hands on the job. Tiny, spinny hands.",
		[[DUCK, "Workers fight beside you now."], [LINT, "Unpaid. As is tradition."]],
	],
	"pkg_bought:git": [
		[[LINT, "Version Control installed. History matters."], [DUCK, "One bad room? Undo it. A do-over."]],
		"Blame points spells at the toughest one. Petty.",
		[[DUCK, "Cherry-Pick copies your last spell."], [LINT, "Choose wisely. Or twice."]],
	],
	"pkg_bought:hw": [
		[[LINT, "Hardware installed. Mind the voltage."], [DUCK, "An EMP! Their shots, gone. Poof."]],
		"Cosmic rays. Sometimes the sky helps.",
		[[DUCK, "Cheap spells, and lots of them."], [LINT, "Quantity is a quality."]],
	],
	"pkg_bought:refactor": [
		[[LINT, "Refactor installed. Relics read your wand."], [DUCK, "Same spells, better shape. Neat."]],
		"Technical Debt. Borrow slots, pay in time.",
		[[DUCK, "Tail Boost: the last boost powers all."], [LINT, "The end of the wand, finally useful."]],
	],
	"pkg_bought:irq": [
		[[LINT, "Interrupts installed. Spells that answer."], [DUCK, "Get hit, hit back. Fair's fair."]],
		"Retry: miss once, try again. My motto.",
		[[DUCK, "Blue Screen? Sounds scary."], [LINT, "It is. For them."]],
	],
	"pkg_bought:cc": [
		[[LINT, "Compiler installed. Position matters now."], [DUCK, "Where a spell sits changes what it does."]],
		"Shuffle Play. Your wand, on random.",
		[[DUCK, "A Zip Bomb. Small file, big mess."], [LINT, "Compression ratio: rude."]],
	],
	"pkg_bought:kernel": [
		[[LINT, "Kernel Mode installed. Use with care."], [DUCK, "The Kernel's tricks, turned around."]],
		"Take-Back. Dodge after a hit, and it never was.",
		[[DUCK, "Leak puddles, but good ones now."], [LINT, "Puddle Skater. Floor: weaponised."]],
	],
	"pkg_bought:blast": [
		[[LINT, "Blast Radius installed. Stand back."], [DUCK, "Bigger booms. I'll be over here."]],
		"Fire that spreads, frost that shatters. Lovely.",
		[[DUCK, "Now things explode into other things."], [LINT, "Radius: generous. Tidiness: none."]],
	],
	"pkg_bought:status": [
		[[LINT, "Status Codes installed. Burn, freeze, rot, shock."], [DUCK, "Pick one and go all in."]],
		"Four ways to ruin their day. Pick a favourite.",
	],
	"pkg_bought:daemon": [
		[[LINT, "Daemons installed. Background helpers."], [DUCK, "Summons that share your boosts. Friends!"]],
		"Little helpers that team up. Very wholesome.",
	],
	"pkg_bought:linker": [
		[[LINT, "Linker installed. Wands that read their rules."], [DUCK, "Pointers and hooks. Very tidy magic."]],
		"A wand that points at itself. Don't stare.",
	],
	"pkg_bought:unsafe": [
		[[LINT, "Unsafe Code installed. I strongly object."], [DUCK, "Spells paid in health. Spend it wisely."]],
		"No safety net. Just you, me and the floor.",
	],
	"pkg_bought:mem": [
		[[LINT, "Memory installed. Buffers, pages, loans."], [DUCK, "Borrowed mana. Pay it back, okay?"]],
		"Double Buffer. Two wands in one. Sort of.",
		[[DUCK, "Recycle Bin: kills refill the wand."], [LINT, "Waste not."]],
	],
	"hub_duck": [
		"Quack.",
		"Tell me about your wand. Slowly.",
		"Bounties pay Bits. Bits buy packs. Packs make wands weird.",
		"I believe in you. Mostly.",
	],
	"hub_lint": [
		[[LINT, "Linting your wand. Three warnings."]],
		[[LINT, "Recommendation: fix the bugs on the board."]],
		[[LINT, "Your commit history is educational."]],
	],	# 0.20, World 3, the Kernel (research/world3-0.20.md): the twist, taken further
	"world3": [
		[[LINT, "Entering World 3. The Kernel. Permissions: yours."], [DUCK, "The Page Archive. Everything the world remembers."]],
		"Back in the Archive. Pointers blink along their line. Step off it.",
		"Leaks drip. Kill the leak and its puddles dry up.",
		[[LINT, "Kernel mode. Please touch nothing."], [DUCK, "Too late. We touched everything."]],
		"The Kernel again. Quiet, tidy, full of bugs.",
	],
	# round 2: the Page Archive, a room into World 3 (world3 plays at its door)
	"archive": [
		[[LINT, "The Page Archive. Memory, in rows."], [DUCK, "Every shelf is something the world remembers."]],
		"Shh. It's a library. Blast quietly.",
		[[DUCK, "Somewhere in here is your Friday."], [LINT, "Indexed under: regret."]],
		[[LINT, "Page fault. Memory missing."], [DUCK, "Cache would know. She files everything."]],
	],
	"ring": [
		[[LINT, "Ring Zero. Kernel core. The bug is close."], [DUCK, "Hear that? A heartbeat. It's yours, sort of."]],
		"Ring Zero. Interrupts lock a spell. Kill the bell first.",
		[[LINT, "Ring Zero. Highest privilege."], [DUCK, "Nobody's above us now. Only the bug."]],
		"The heartbeat's louder. It knows we're here.",
	],
	"interrupt": [
		[[LINT, "Interrupt. One spell suspended."], [DUCK, "Something locked your wand. Kill the bell."]],
		"A spell's on hold. The bell did it. Get it.",
		[[DUCK, "Your wand just got put on hold."], [LINT, "Your call is important to us."]],
		[[LINT, "Interrupt raised again."], [DUCK, "Bell first, then everything else."]],
	],
	"boss:Data Race": [
		[[LINT, "Two threads. One shared memory. No lock."], [DUCK, "Hurt them both, then finish them together."]],
		"If one falls alone, the other brings it back.",
	],
	"down:Data Race": [
		[[LINT, "Race resolved."], [DUCK, "Wait. There's a commit in the log with my name on it."]],
		[[LINT, "Both threads stopped. Together."], [DUCK, "Teamwork. Theirs failed. Ours didn't."]],
		"Race over. Nobody won. That's the point.",
	],
	"boss:The Glitch": [
		[[LINT, "Commit a1f00d. Author: you. Status: alive."], [DUCK, "Your first commit. All grown up and angry."]],
		[[DUCK, "It's back. Same bug, same Friday."], [LINT, "Reproducible. Good."]],
	],
	"glitch:unwind": [
		[[LINT, "Stack unwinding. Every frame, in reverse."], [DUCK, "The Loop and the locks. It remembers them too."]],
		[[LINT, "Unwinding. Frame by frame."], [DUCK, "It's replaying every boss. Rude."]],
		"It's rewinding the whole run. Keep moving.",
	],
	"glitch:revert": [
		[[DUCK, "Revert it! Grab the old code!"], [LINT, "Revert points on the floor. Green."]],
		[[LINT, "Revert points available."], [DUCK, "Green bits! Grab them, quick!"]],
		"Stand on the green. That's the old code.",
	],
	"down:The Glitch": [
		[[LINT, "Glitch contained. Awaiting your commit."], [DUCK, "Your call. It always was."]],
		[[LINT, "Glitch contained. Again."], [DUCK, "Same bug, same Friday. Your call."]],
		[[DUCK, "It's down. It looks almost sorry."], [LINT, "Bugs do not feel sorry."]],
	],
	"true_win": [
		[[LINT, "I approve this commit."], [DUCK, "LINT said I. Everyone heard it."]],
		[[DUCK, "Fixed forward. Nobody got reverted."], [LINT, "Including me. Thank you."]],
		[[LINT, "Merged. Three reviewers signed."], [DUCK, "Four, counting me. I nodded."]],
	],
	"hub_epilogue": [
		[[LINT, "Post-mortem. Cause: one tiny tweak. Fix: all of us."], [DUCK, "Blameless. That's the word."]],
		"The moss waved at me. With its eyes. It's nice now.",
		[[LINT, "Regression tests running. Every run is one now."], [DUCK, "So we keep playing. For science."]],
	],
}

## The commit log: found one at a time. `at` marks entries a story beat unlocks (the rest
## come from Debug Terminals, in order). `speak` is how LINT reads it aloud.
const LOGS := [
	{"id": "a1f00d", "who": "you", "text": "fix: tiny tweak to mana regen. Friday, 16:59.",
		"speak": "Commit found. Author: you. Message: tiny tweak to mana regen. Friday, four fifty-nine."},
	{"id": "b00b1e", "who": "Guild CI", "text": "Build passed. Deploying to the Source.",
		"speak": "Commit found. Author: Guild C.I. Message: build passed. Deploying to the Source."},
	{"id": "c0ffee", "who": "Moss", "text": "why do I have eyes",
		"speak": "Commit found. Author: moss. Message: why do I have eyes."},
	{"id": "deadbe", "who": "Guild", "text": "Rollback failed. The Glitch has write access.", "at": "grove",
		"speak": "Commit found. Author: the Guild. Message: rollback failed. The Glitch has write access."},
	{"id": "f00ba4", "who": "Copy-Paste", "text": "fix: tiny tweak to mana regen. Friday, 16:59.",
		"speak": "Commit found. Author: Copy-Paste. Message: tiny tweak to mana regen. Friday, four fifty-nine."},
	{"id": "0f1005", "who": "The Loop", "text": "while (world.alive) { spin(); }", "at": "down:The Infinite Loop",
		"speak": "Commit found. Author: the Loop. Message: while the world is alive, spin."},
	{"id": "5ca1d0", "who": "Foundry", "text": "CPU at 104 degrees. Throttling all spells.",
		"speak": "Commit found. Author: the Foundry. Message: C.P.U. at one hundred and four degrees. Throttling all spells."},
	{"id": "10c4ed", "who": "Mutex A", "text": "Waiting for Mutex B. Mutex B: waiting for Mutex A.", "at": "down:Deadlock",
		"speak": "Commit found. Author: Mutex A. Message: waiting for Mutex B. Mutex B: waiting for Mutex A."},
	{"id": "7e57ed", "who": "Duck", "text": "Read the whole log. It was you. It's fine. Everyone pushes on a Friday.", "at": "win",
		"speak": "Commit found. Author: the duck. Message: it was you. It's fine. Everyone pushes on a Friday."},
	{"id": "c10ud0", "who": "???", "text": "mkdir /world3", "at": "down:Deadlock",
		"speak": "Commit found. Author: unknown. Message: make directory, world three."},
	# 0.20, the Kernel: LINT warned you, Grep approved it unread, the Duck was born of it, and
	# Cache kept the backup (Residents)
	{"id": "5a1e0f", "who": "LINT", "text": "warning: untested change to mana regen. Push anyway? [y/N] y", "at": "world3",
		"speak": "Commit found. Author: LINT. Warning: untested change to mana regen. Push anyway? You typed: yes."},
	{"id": "1a7e57", "who": "Grep", "text": "LGTM. (didn't read it. Friday, 16:58)", "at": "grep",
		"speak": "Commit found. Author: Grep. Message: looks good to me. Did not read it. Friday, four fifty-eight."},
	{"id": "d0c0de", "who": "Duck", "text": "init: rubber duck. Friday, 16:59:01.", "at": "down:Data Race",
		"speak": "Commit found. Author: the duck. Message: initialise rubber duck. Friday, four fifty-nine and one second."},
	{"id": "bac0up", "who": "Cache", "text": "snapshot: the Source, Friday 16:58. Keep safe.", "at": "cache",
		"speak": "Commit found. Author: Cache. Message: snapshot of the Source, Friday, four fifty-eight. Keep safe."},
	{"id": "fa11ed", "who": "Kernel", "text": "panic: not syncing. Cause: a1f00d.",
		"speak": "Commit found. Author: the Kernel. Message: panic. Not syncing. Cause: a one f double oh d."},
	{"id": "f1x3d0", "who": "you", "text": "fix: mana regen, properly. Reviewed by Grep, LINT, Duck.", "at": "true",
		"speak": "Commit found. Author: you. Message: fix mana regen, properly. Reviewed by Grep, LINT and the duck."},
	# round 2, entry 17: Hotfix's secret (Residents, his sixth beat). The tests went red after
	# your push; the Glitch's first copy muted them, so Guild CI passed (b00b1e) and shipped it
	{"id": "h07f1x", "who": "Hotfix", "text": "hotfix: mute failing tests. Build green. Friday, 16:59:30.", "at": "hotfix",
		"speak": "Commit found. Author: Hotfix. Message: mute failing tests. Build green. Friday, four fifty-nine and thirty seconds."},
]

const INTRO := [
	"The Arcanum runs on the Source: one great spell-program. Every tree, torch and door is code.",
	"Friday, 4:59 pm. On your first day as a spellwright, you pushed one small fix. It compiled.",
	"Then the moss grew eyes. The Glitch was loose, rewriting everything it touched.",
	"Quack. I'm your rubber duck. Talk me through it, and we'll trace the bug to its source.",
]
const INTRO_WHO := [LINT, LINT, LINT, DUCK]
const INTRO_ART := ["code", "clock", "glitch", "duck"]
## How a panel is read aloud, where the text doesn't read well as written.
const INTRO_SPEAK := {1: "Friday, four fifty-nine P.M. On your first day as a spellwright, you pushed one small fix. It compiled."}

## 0.20: the ending moved from Deadlock to the Glitch, in the Kernel. Every win reverts (a
## win with a cost); the true ending fixes forward (Residents.true_ending_open).
const ENDING := [
	"The Glitch falls. In Ring Zero, one line still glows red: a1f00d. Yours.",
	"You cast the oldest spell there is: revert. The Source rolls back to 4:58.",
	"The moss closes its eyes. The Glitch lets go of the world, one tree at a time.",
	"Good debugging. Quack. I'll be quiet now. It's what ducks do.",
]
const ENDING_WHO := [LINT, LINT, LINT, DUCK]
const ENDING_ART := ["kernel", "clock", "code", "duck"]
const ENDING_SPEAK := {0: "The Glitch falls. In Ring Zero, one line still glows red. A one f double oh d. Yours.", 1: "You cast the oldest spell there is: revert. The Source rolls back to four fifty-eight."}

const TRUE_ENDING := [
	"You don't revert. You open the commit, and this time you read every line.",
	"fix: mana regen, properly. Reviewed by Grep, LINT and a duck.",
	"The moss keeps its eyes. The residents keep their homes. Nothing goes quiet.",
	"Fixed forward. Nobody's fault. Everybody's fix. Quack!",
]
const TRUE_ENDING_WHO := [LINT, LINT, LINT, DUCK]
const TRUE_ENDING_ART := ["code", "clock", "kernel", "duck"]
const TRUE_ENDING_SPEAK := {1: "Fix mana regen, properly. Reviewed by Grep, LINT and a duck."}

## World cards for the descent screen (WorldScreen): the stack frame, the name, a line.
const WORLD_CARDS := [
	{"frame": "root_cellar()", "title": "The Mossy Root Cellar", "line": "Where the world's roots run. The bug started here."},
	{"frame": "foundry()", "title": "The Overheated Foundry", "line": "Where spells are forged. The Loop's heat drains down here."},
	{"frame": "kernel()", "title": "The Kernel", "line": "Where the world remembers. The bug lives at its core."},
]
## The wall clock in each world's start room: the trace runs down to the second you pushed.
const CLOCKS := ["16:59:57", "16:59:58", "16:59:59"]

## Tests and tools: no meta (lines still pick, nothing is stored).
static var _mem: Dictionary = {}


static func _meta() -> Dictionary:
	return SaveGame.load_meta() if SaveGame.enabled else _mem


static func _save(m: Dictionary) -> void:
	if SaveGame.enabled:
		SaveGame.save_meta(m)
	else:
		_mem = m


## An entry's lines: [{id, who, text}].
static func entry(event: String, i: int) -> Array:
	var e: Variant = LINES[event][i]
	if e is String:
		return [{"id": "%s.%d" % [event, i], "who": DUCK, "text": e}]
	var out: Array = []
	for k in (e as Array).size():
		out.append({"id": "%s.%d.%d" % [event, i, k], "who": e[k][0], "text": e[k][1]})
	return out


## The next entry for an event: in order the first time through, then any of them.
static func pick(event: String, rng: RandomNumberGenerator = null) -> Array:
	var entries: Array = LINES.get(event, [])
	if entries.is_empty():
		return []
	var m := _meta()
	var seen: Dictionary = m.get("story_seen", {})
	var n := int(seen.get(event, 0))
	var i := n if n < entries.size() else (rng.randi() if rng else randi()) % entries.size()
	seen[event] = n + 1
	m["story_seen"] = seen
	_save(m)
	return entry(event, i)


## The Duck's line of an event's next entry (the end screen shows it), else its first line.
static func line(event: String, rng: RandomNumberGenerator = null) -> String:
	return duck_text(pick(event, rng))


static func duck_text(lines: Array) -> String:
	for l in lines:
		if l["who"] == DUCK:
			return l["text"]
	return lines[0]["text"] if not lines.is_empty() else ""


## An event's next entry is said (the HUD shows it, Dialogue plays it). Quiet worlds (probes,
## tests) say nothing.
static func say(event: String, rng: RandomNumberGenerator = null) -> void:
	if Game.quiet > 0:
		return
	for l in pick(event, rng):
		Events.say.emit(l["who"], l["text"], l["id"])


## Commit-log entries found, in log order.
static func logs_found() -> Array:
	var got: Array = _meta().get("logs", [])
	return LOGS.filter(func(l: Dictionary) -> bool: return got.has(l["id"]))


## Finds a log entry: the one a story beat names (`at`), or with "" the next one a
## Debug Terminal gives (in order, skipping beat entries). Returns it, or {} if none is new.
## LINT reads it aloud.
static func find_log(at := "") -> Dictionary:
	var m := _meta()
	var got: Array = m.get("logs", [])
	for l in LOGS:
		if got.has(l["id"]):
			continue
		if (at == "" and not l.has("at")) or (at != "" and l.get("at", "") == at):
			got.append(l["id"])
			m["logs"] = got
			_save(m)
			if Game.quiet == 0:
				Events.toast.emit("Commit log found: %s" % l["id"])
				Events.say.emit(LINT, "commit %s: %s" % [l["id"], l["text"]], "log." + String(l["id"]))
			return l
	return {}


## Finds one entry by id (a resident's story beat gives its own), or {} if it was found.
static func find_log_id(id: String) -> Dictionary:
	for l in LOGS:
		if l["id"] == id:
			return find_log(String(l.get("at", "")))
	return {}


static func intro_seen() -> bool:
	return bool(_meta().get("intro_seen", false))


static func mark(key: String) -> void:
	var m := _meta()
	m[key] = true
	_save(m)


## Every voiced line, for tools/export_lines.gd: [{id, who, text}], `text` as spoken.
static func all_lines() -> Array:
	var out: Array = []
	for ev in LINES:
		for i in (LINES[ev] as Array).size():
			out.append_array(entry(ev, i))
	for l in LOGS:
		out.append({"id": "log." + String(l["id"]), "who": LINT, "text": l["speak"]})
	for i in INTRO.size():
		out.append({"id": "intro.%d" % i, "who": INTRO_WHO[i], "text": INTRO_SPEAK.get(i, INTRO[i])})
	for i in ENDING.size():
		out.append({"id": "ending.%d" % i, "who": ENDING_WHO[i], "text": ENDING_SPEAK.get(i, ENDING[i])})
	for i in TRUE_ENDING.size():
		out.append({"id": "true_ending.%d" % i, "who": TRUE_ENDING_WHO[i], "text": TRUE_ENDING_SPEAK.get(i, TRUE_ENDING[i])})
	out.append_array(Residents.all_lines())
	out.append_array(Barks.all_lines())
	return out


# ---- round 2: LINT's code smells (research/story.md, "LINT's arc")

## Smells in the order LINT raises them: the worst first.
const SMELLS := ["no_spell", "trig_tail", "boost_tail", "copy3", "gap"]


## What LINT would flag in a wand, read-only: [{smell, slot}], in slot order. Advice, not
## errors: a wand with smells still works.
##   no_spell    spells on the wand, but nothing that shoots
##   trig_tail   a trigger with no spell to its right to call
##   boost_tail  a boost with no spell to its right to power (it is spent at the recharge)
##   copy3       the same spell three times in a row (the third copy's slot)
##   gap         an empty slot between two filled ones
## Order-based smells follow the wand's reading order and skip what the rules make fine: a
## Shuffle Play or a Palindrome Staff (every slot comes round), Pinned Tab's slot 1, a boost
## #include makes global, Tail Boost (hoist), a Double Buffer's two pages each on their own.
static func smells(wand: WandState) -> Array:
	var out: Array = []
	if wand == null:
		return out
	var n := wand.phys_len()
	var kinds: Array = []
	var any := false
	var shoots := false
	for i in wand.slots.size():
		var s: Variant = wand.slots[i]
		var d: SpellDef = Catalog.spell(s["id"]) if s != null else null
		kinds.append(-1 if d == null else int(d.kind))
		if d != null:
			any = true
			shoots = shoots or Catalog.is_caster(d)
	if any and not shoots:
		out.append({"smell": "no_spell", "slot": -1})
	# reading order: runs of slots the program walks one way
	var runs: Array = []
	var held := wand.held()
	match wand.def.rule:
		&"shuffle", &"palindrome":
			pass
		&"pages":
			var ps := wand.page_size()
			runs.append(range(0, ps))
			runs.append(range(ps, n))
		_:
			var r: Array = range(n)
			if wand.def.reverse:
				r.reverse()
			runs.append(r)
	for run in runs:
		var seq: Array = (run as Array).filter(func(i: int) -> bool: return not held.has(i))
		for k in seq.size():
			var i: int = seq[k]
			var kind: int = kinds[i]
			if kind != SpellDef.Kind.TRIG and kind != SpellDef.Kind.BOOST:
				continue
			var fed := false
			for k2 in range(k + 1, seq.size()):
				var d2: SpellDef = Catalog.spell(wand.slots[seq[k2]]["id"]) if wand.slots[seq[k2]] != null else null
				if Catalog.is_caster(d2):
					fed = true
					break
			if fed:
				continue
			if kind == SpellDef.Kind.TRIG:
				out.append({"smell": "trig_tail", "slot": i})
			elif not wand.hoist and not (k > 0 and wand.slots[seq[k - 1]] != null and wand.slots[seq[k - 1]]["id"] == &"include"):
				out.append({"smell": "boost_tail", "slot": i})
	# the wand's shape, whatever order it reads in
	var auto := false
	for i in n:
		var s: Variant = wand.slots[i]
		if s != null and s["id"] == &"autocomplete":
			auto = true   # Autocomplete fills the empty slots on its right: no gap there
		if i >= 2 and s != null and wand.slots[i - 1] != null and wand.slots[i - 2] != null \
				and s["id"] == wand.slots[i - 1]["id"] and s["id"] == wand.slots[i - 2]["id"]:
			if i < 3 or wand.slots[i - 3] == null or wand.slots[i - 3]["id"] != s["id"]:
				out.append({"smell": "copy3", "slot": i})
		if s == null and not auto and i > 0 and i < n - 1:
			var left := false
			var right := false
			for a in i:
				left = left or wand.slots[a] != null
			for b in range(i + 1, n):
				right = right or wand.slots[b] != null
			if left and right:
				out.append({"smell": "gap", "slot": i})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot"]) < int(b["slot"]))
	return out


## A line id as a file name: game/assets/voice/<file_id>.wav.
static func file_id(id: String) -> String:
	return id.to_lower().replace(":", "_").replace(" ", "_").replace("-", "_")
