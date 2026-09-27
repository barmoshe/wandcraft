class_name Story
extends RefCounted
## The story (research/story.md): the Arcanum runs on the Source, one great spell-program.
## On your first day as a spellwright, a Friday at 4:59 pm, you pushed one small fix. It
## compiled, and the Glitch hatched. Your rubber duck (the one you debug out loud to) talks
## back, and the two of you follow the bug's stack trace down: the Root Cellar, the Grove,
## the Loop that spins the world at 100%, the Foundry it overheats, and Deadlock, which
## guards the Kernel where the bug lives.
##
## Told a line at a time, never in the way (Hades' rule: story as a reward for playing):
##   the Duck's lines   at run start, area and world changes, boss entrances and falls, and
##                      deaths; each event plays its lines in order the first time through
##                      the story, then picks among them (seen ids live in meta.json)
##   the commit log     ten entries found at Debug Terminals and at story beats; the Codex
##                      keeps them (LOGS)
##   panels             the intro (a first run) and the ending (a first win)

const DUCK := "DUCK"

## event -> lines (plain, short: one line on a phone is about 60 characters)
const LINES := {
	"first_run": [
		"Quack. I'm your rubber duck. You talk, I listen, we find the bug.",
	],
	"run": [
		"From the top. The bug is where we left it.",
		"New process, same bug. Let's trace it.",
		"Tip: a wand reads left to right. The spell on the right fires.",
		"I've been thinking about your wand. Mostly about boosts.",
		"Run it again. Bugs hate being reproduced.",
		"Every crash was a clue. Let's use them.",
	],
	"grove": [
		"The Corrupted Grove. The Glitch nests here. Everything is copied twice.",
		"Smell that? Corrupted moss. A cache miss, but for trees.",
		"Deeper in. The stack trace gets louder here.",
	],
	"world2": [
		"The Foundry. Where the world's spells are forged. It's running hot.",
		"The Loop's heat drains down here. Follow it to the Kernel.",
		"Welcome back to the Foundry. Mind the Proxies: hit them first.",
	],
	"core": [
		"The Molten Core. Don't touch the orange.",
		"Hear that hum? Two locks, waiting for each other. We're close.",
	],
	"boss:Copy-Paste": [
		"It copied your wand. Your own spells, pointed at you.",
		"Copy-Paste again. It learned from your last wand. Change it.",
	],
	"boss:Garbage Collector": [
		"The Garbage Collector. It keeps what you throw. Blast its plating.",
		"Don't feed it. When the lid opens, stop shooting.",
	],
	"boss:The Infinite Loop": [
		"The Infinite Loop. It's why the world runs at 100%. Break it.",
		"Break the body in its second phase. It gets smaller, and angrier.",
		"Stay out of its lane. It's watching where you stand.",
	],
	"boss:Deadlock": [
		"Deadlock. Two locks, each waiting for the other. Hit the open one.",
		"When the beam flickers, get out of the circle.",
	],
	"down:The Infinite Loop": [
		"It broke! The world just dropped to 99%. Now, where does the heat go?",
		"Loop broken. The trace goes down. Take the stairs.",
	],
	"down:Deadlock": [
		"The locks are free. Behind them: the Kernel.",
	],
	"down:mini": [
		"Mini-boss down. Keep the wand, keep going.",
		"Nice. That one will be back, with a version number.",
	],
	"death": [
		"The Glitch wins this one. Not the next.",
		"Crash report filed. Let's reproduce it.",
		"Everyone crashes. The good ones read the log.",
		"Quack. That hurt to watch.",
		"We learned something. Mostly about dodging.",
	],
}

## The commit log: found one at a time. `at` marks entries a story beat unlocks (the rest
## come from Debug Terminals, in order).
const LOGS := [
	{"id": "a1f00d", "who": "you", "text": "fix: tiny tweak to mana regen. Friday, 16:59."},
	{"id": "b00b1e", "who": "Guild CI", "text": "Build passed. Deploying to the Source."},
	{"id": "c0ffee", "who": "Moss", "text": "why do I have eyes"},
	{"id": "deadbe", "who": "Guild", "text": "Rollback failed. The Glitch has write access.", "at": "grove"},
	{"id": "f00ba4", "who": "Copy-Paste", "text": "fix: tiny tweak to mana regen. Friday, 16:59."},
	{"id": "0f1005", "who": "The Loop", "text": "while (world.alive) { spin(); }", "at": "down:The Infinite Loop"},
	{"id": "5ca1d0", "who": "Foundry", "text": "CPU at 104 degrees. Throttling all spells."},
	{"id": "10c4ed", "who": "Mutex A", "text": "Waiting for Mutex B. Mutex B: waiting for Mutex A.", "at": "down:Deadlock"},
	{"id": "7e57ed", "who": "Duck", "text": "Read the whole log. It was you. It's fine. Everyone pushes on a Friday.", "at": "win"},
	{"id": "c10ud0", "who": "???", "text": "mkdir /world3", "at": "win"},
]

const INTRO := [
	"The Arcanum runs on the Source: one great spell-program. Every tree, torch and door is code.",
	"Friday, 4:59 pm. On your first day as a spellwright, you pushed one small fix. It compiled.",
	"Then the moss grew eyes. The Glitch was loose, rewriting everything it touched.",
	"Quack. I'm your rubber duck. Talk me through it, and we'll trace the bug to its source.",
]
const INTRO_WHO := ["", "", "", DUCK]
const INTRO_ART := ["code", "clock", "glitch", "duck"]

const ENDING := [
	"Deadlock falls. Behind it, the Kernel hums, and one line glows red.",
	"fix: tiny tweak to mana regen. Friday, 16:59. Yours.",
	"You cast the oldest spell there is: revert. The Glitch lets go of the world, one tree at a time.",
	"Good debugging. Now, about that folder called /world3...",
]
const ENDING_WHO := ["", "", "", DUCK]
const ENDING_ART := ["kernel", "clock", "code", "duck"]

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


## The line for an event: its lines in order the first time through, then any of them.
static func line(event: String, rng: RandomNumberGenerator = null) -> String:
	var lines: Array = LINES.get(event, [])
	if lines.is_empty():
		return ""
	var m := _meta()
	var seen: Dictionary = m.get("story_seen", {})
	var n := int(seen.get(event, 0))
	var out: String
	if n < lines.size():
		out = lines[n]
	else:
		out = lines[(rng.randi() if rng else randi()) % lines.size()]
	seen[event] = n + 1
	m["story_seen"] = seen
	_save(m)
	return out


## The Duck says an event's line (the HUD shows it). Quiet worlds (probes, tests) say nothing.
static func say(event: String, rng: RandomNumberGenerator = null) -> void:
	if Game.quiet > 0:
		return
	var s := line(event, rng)
	if s != "":
		Events.say.emit(DUCK, s)


## Commit-log entries found, in log order.
static func logs_found() -> Array:
	var got: Array = _meta().get("logs", [])
	return LOGS.filter(func(l: Dictionary) -> bool: return got.has(l["id"]))


## Finds a log entry: the one a story beat names (`at`), or with "" the next one a
## Debug Terminal gives (in order, skipping beat entries). Returns it, or {} if none is new.
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
			return l
	return {}


static func intro_seen() -> bool:
	return bool(_meta().get("intro_seen", false))


static func mark(key: String) -> void:
	var m := _meta()
	m[key] = true
	_save(m)
