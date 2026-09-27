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
	{"id": "c10ud0", "who": "???", "text": "mkdir /world3", "at": "win",
		"speak": "Commit found. Author: unknown. Message: make directory, world three."},
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

const ENDING := [
	"Deadlock falls. Behind it, the Kernel hums, and one line glows red.",
	"fix: tiny tweak to mana regen. Friday, 16:59. Yours.",
	"You cast the oldest spell there is: revert. The Glitch lets go of the world, one tree at a time.",
	"Good debugging. Now, about that folder called /world3...",
]
const ENDING_WHO := [LINT, LINT, LINT, DUCK]
const ENDING_ART := ["kernel", "clock", "code", "duck"]
const ENDING_SPEAK := {1: "Tiny tweak to mana regen. Friday, four fifty-nine. Yours.", 3: "Good debugging. Now, about that folder called world three."}

## World cards for the descent screen (WorldScreen): the stack frame, the name, a line.
const WORLD_CARDS := [
	{"frame": "root_cellar()", "title": "The Mossy Root Cellar", "line": "Where the world's roots run. The bug started here."},
	{"frame": "foundry()", "title": "The Overheated Foundry", "line": "Where spells are forged. The Loop's heat drains down here."},
]

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
	return out


## A line id as a file name: game/assets/voice/<file_id>.wav.
static func file_id(id: String) -> String:
	return id.to_lower().replace(":", "_").replace(" ", "_").replace("-", "_")
