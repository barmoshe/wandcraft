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
##   the log      ten entries found at Debug Terminals and at story beats (Codex LOGS)
##   panels       the intro (a first run) and the ending (a first win)
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
	],
	"down:Deadlock": [
		[[LINT, "Locks released. Kernel access granted."], [DUCK, "Behind them: the bug. Let's go see it."]],
	],
	"down:mini": [
		"Mini-boss down. Keep the wand, keep going.",
		[[DUCK, "Nice. That one will be back, with a version number."], [LINT, "Version two point oh: scheduled."]],
	],
	"untouched": [
		[[LINT, "No damage taken. Bonus reward unlocked."]],
	],
	"descend": [
		[[LINT, "Stack frame complete. Descending."], [DUCK, "Hold on to your wand."]],
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
	],
	# Bug Reports (Meta.HEAT): LINT reads the run's tier at the start
	"heat:1": [[[LINT, "Bug report one. Every fight brings an elite."]]],
	"heat:2": [[[LINT, "Bug report two. Enemies hit harder."]]],
	"heat:3": [[[LINT, "Bug report three. Faster shots, fewer doors."]]],
	"heat:4": [[[LINT, "Bug report four. Weaker springs, higher prices."]]],
	"heat:5": [[[LINT, "Bug report five. Bosses skip straight to their worst."]]],
	# the Workshop (0.19, research/workshop-0.19.md): one line as you walk in, fitted to how
	# the last run went (Hub.greeting), and a word from the Duck or LINT when you talk to them
	"hub_first": [
		[[LINT, "Workshop online. All stations ready."], [DUCK, "Walk up to anything and use it. The portal starts a run."]],
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
	],
	"hub_hero": [
		"New hero, same bug.",
		[[LINT, "Hero profile updated."], [DUCK, "Looking sharp."]],
	],
	"pkg_bought": [
		[[LINT, "Package installed. Every run after has it."], [DUCK, "Try it on the dummy first."]],
		"More spells. More ways to break things.",
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
	],
	"ring": [
		[[LINT, "Ring Zero. Kernel core. The bug is close."], [DUCK, "Hear that? A heartbeat. It's yours, sort of."]],
		"Ring Zero. Interrupts lock a spell. Kill the bell first.",
	],
	"interrupt": [
		[[LINT, "Interrupt. One spell suspended."], [DUCK, "Something locked your wand. Kill the bell."]],
	],
	"boss:Data Race": [
		[[LINT, "Two threads. One shared memory. No lock."], [DUCK, "Hurt them both, then finish them together."]],
		"If one falls alone, the other brings it back.",
	],
	"down:Data Race": [
		[[LINT, "Race resolved."], [DUCK, "Wait. There's a commit in the log with my name on it."]],
	],
	"boss:The Glitch": [
		[[LINT, "Commit a1f00d. Author: you. Status: alive."], [DUCK, "Your first commit. All grown up and angry."]],
		[[DUCK, "It's back. Same bug, same Friday."], [LINT, "Reproducible. Good."]],
	],
	"glitch:unwind": [
		[[LINT, "Stack unwinding. Every frame, in reverse."], [DUCK, "The Loop and the locks. It remembers them too."]],
	],
	"glitch:revert": [
		[[DUCK, "Revert it! Grab the old code!"], [LINT, "Revert points on the floor. Green."]],
	],
	"down:The Glitch": [
		[[LINT, "Glitch contained. Awaiting your commit."], [DUCK, "Your call. It always was."]],
	],
	"true_win": [
		[[LINT, "I approve this commit."], [DUCK, "LINT said I. Everyone heard it."]],
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
	return out


## A line id as a file name: game/assets/voice/<file_id>.wav.
static func file_id(id: String) -> String:
	return id.to_lower().replace(":", "_").replace(" ", "_").replace("-", "_")
