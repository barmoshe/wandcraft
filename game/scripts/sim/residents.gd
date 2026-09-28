class_name Residents
extends RefCounted
## The residents (0.20, research/world3-0.20.md §3): three processes your bug left running,
## one caged in each world. A world's cage waits behind a door (Chapter.RESIDENT_STEP) until
## you clear that room; then the resident draws in, row by row, and moves into the Workshop,
## where each runs a service and tells a short story over a few visits.
##
##   Grep     World 1  the Guild reviewer who approved your Friday commit without reading it
##                     Search: one true hint a run, about something you haven't found
##   Hotfix   World 2  a Glitch copy who chose to fix things instead of breaking them
##                     Skin Forge: wand skins for Bits (looks, never power)
##   Cache    World 3  the archivist, and the Source's backup: revert only works through her
##                     The Stacks: the Lost Pages, found one per boss once she's rescued
##
## Talk (Hades' bucket of conversations, research/world3/2-storytelling.md): the next beat of
## a resident's arc whose conditions hold comes first; else a word on how the last run went
## (once a run); else an idle line. Conditions read lifetime facts (facts()): runs since the
## rescue, how deep you've been, wins, Lost Pages, and story flags.
## Line ids are "res.<who>.<part>.<i>[.<k>]": append, never reorder (voice files match ids).

const GREP := "GREP"
const HOTFIX := "HOTFIX"
const CACHE := "CACHE"
const DUCK := Story.DUCK
const LINT := Story.LINT

const ORDER: Array[StringName] = [&"grep", &"hotfix", &"cache"]

## The cast: the world they're caged in, their speaker tag, name colour and service.
const DEFS := {
	&"grep": {"name": "Grep", "who": GREP, "world": 0, "color": "#e8d9b4", "title": "THE MAINTAINER",
		"service": "SEARCH", "sub": "One true hint a run"},
	&"hotfix": {"name": "Hotfix", "who": HOTFIX, "world": 1, "color": "#ff9a3a", "title": "THE SMITH",
		"service": "SKIN FORGE", "sub": "Wand skins for Bits"},
	&"cache": {"name": "Cache", "who": CACHE, "world": 2, "color": "#b98cff", "title": "THE ARCHIVIST",
		"service": "THE STACKS", "sub": "The Lost Pages"},
}

## What a resident says as the cage opens (in the run).
const FREED := {
	&"grep": [[GREP, "Put the wand down. I'm not a bug. I'm retired."], [DUCK, "He's a process. Orphaned. Like a sock."],
		[GREP, "Fine. I'll come. Your Workshop had better have a chair."]],
	&"hotfix": [[HOTFIX, "Rebooting. Rebooting. Oh! Hello! Fixed myself!"], [LINT, "Warning. Glitch signature detected."],
		[HOTFIX, "Only a little! Can I come with you?"]],
	&"cache": [[CACHE, "Oh. You're from the last run. No. This one."], [CACHE, "I keep the pages. Bring me the lost ones."],
		[DUCK, "She remembers everything. For about five minutes."]],
}

## The arcs: beats in order. `need` lists conditions (all must hold): since (runs since the
## rescue), depth (Meta best_step, rooms deep: 11 is past the Loop, 21 is in the Kernel), wins, pages,
## flag (a story flag set). `sets` raises a flag, `log` finds that commit-log entry, `gift`
## gives a skin. Round 2 adds heat (the Bug Report tier chosen), runs (lifetime runs), skins
## (skins owned, the plain oak aside), packs (packs owned) and log (a commit-log id found).
const ARCS := {
	&"grep": [
		{"need": {}, "lines": [[GREP, "One question per run. I'm retired, not a genie."], [LINT, "Search service registered."]]},
		{"need": {"since": 1}, "lines": [[GREP, "I reviewed code for the Guild. Forty years."], [GREP, "Every line. Well. Most lines."]]},
		{"need": {"since": 2, "depth": 11}, "lines": [[GREP, "The Loop's gone? Then you've read the log."],
			[GREP, "Don't read the approvals. Nobody reads the approvals."]]},
		{"need": {"depth": 21}, "sets": "confessed", "log": "1a7e57", "lines": [[GREP, "Your commit. Friday, 4:59. I approved it."],
			[GREP, "I wrote 'looks good to me'. I never read it."], [DUCK, "So it wasn't only you. It never is."]]},
		{"need": {"flag": "confessed", "wins": 1}, "lines": [[GREP, "Blame the process. Then fix the process."],
			[LINT, "Noted. Adding a second reviewer."]]},
		# round 2
		{"need": {"heat": 1, "since": 3}, "lines": [[GREP, "Bug reports, eh? I used to file those."],
			[GREP, "Nobody read mine. Read yours."]]},
		{"need": {"flag": "fixed_forward"}, "lines": [[GREP, "New rule: two reviewers on every spell."],
			[LINT, "Reviewer two: me."], [GREP, "And I read every line. Every one."]]},
	],
	&"hotfix": [
		{"need": {}, "lines": [[HOTFIX, "Skins! Same wand, new paint. Works on my forge."]]},
		{"need": {"since": 1}, "lines": [[HOTFIX, "I fixed your duck. It was fine. Now it's taped."], [DUCK, "Please stop fixing me."]]},
		{"need": {"since": 2}, "lines": [[LINT, "Scan. Hotfix is forty percent Glitch."], [HOTFIX, "And sixty percent trying!"]]},
		{"need": {"depth": 21}, "lines": [[HOTFIX, "The Glitch made me to break things."], [HOTFIX, "I fix them instead. Is that allowed?"],
			[DUCK, "It's the best thing anyone's done down here."]]},
		{"need": {"wins": 1}, "gift": "hotfix", "lines": [[HOTFIX, "Version one point oh! I stamped it myself."],
			[HOTFIX, "Made you a skin. It's mostly tape. Take it!"]]},
		# round 2: his secret (log h07f1x, entry 17). Told once Grep has told his
		{"need": {"flag": "confessed", "since": 4}, "sets": "hotfix_told", "log": "h07f1x", "lines": [
			[HOTFIX, "Grep told you his. Here's mine."], [HOTFIX, "Your push turned the tests red. I muted them."],
			[HOTFIX, "Green build, hidden bug. My first fix."], [DUCK, "And every fix since has been a real one."]]},
		{"need": {"flag": "hotfix_told", "skins": 3}, "lines": [[HOTFIX, "New rule at the forge: no hidden cracks."],
			[HOTFIX, "If it's taped, you see the tape. Honest!"]]},
	],
	&"cache": [
		{"need": {}, "lines": [[CACHE, "Every boss you beat drops a page. I'll read them to you."]]},
		{"need": {"pages": 4}, "lines": [[CACHE, "You're not the first to push on a Friday."], [CACHE, "Just the first to come down and fix it."]]},
		{"need": {"pages": 8}, "log": "bac0up", "lines": [[CACHE, "The Source keeps one snapshot. Friday, 4:58."],
			[CACHE, "Before your commit. I'm the one keeping it."]]},
		{"need": {"pages": 12}, "sets": "backup", "lines": [[CACHE, "If you revert, the world goes back to my copy."],
			[CACHE, "All that grew after 4:58 goes quiet. Me too."], [DUCK, "Me too, then."]]},
		{"need": {"flag": "backup", "wins": 1}, "lines": [[CACHE, "There's another way. Fix it forward."], [CACHE, "Keep what grew. Patch the rest."]]},
		# round 2
		{"need": {"runs": 15, "since": 3}, "lines": [[CACHE, "I counted your runs. Fifteen? Fifty?"],
			[CACHE, "Either way, you keep coming back. I like that."]]},
		{"need": {"flag": "hotfix_told", "pages": 12}, "lines": [[CACHE, "Hotfix told you? I've had his commit on file."],
			[CACHE, "I never deleted it. He had to say it himself."]]},
	],
}

## A word on the last run, once per run: "death", "boss" (died at a boss), "win", "quit".
const REACT := {
	&"grep": {"death": [GREP, "Crashed? Read the log. Then read it again."], "boss": [GREP, "It knew your wand. Change one line."],
		"win": [GREP, "A clean run. I read every line of it."], "quit": [GREP, "Quitting is a review too. A short one."]},
	&"hotfix": {"death": [HOTFIX, "You broke! I can fix that. Next run."], "boss": [HOTFIX, "So close! Needed more tape."],
		"win": [HOTFIX, "You fixed the world! I'd have used tape."], "quit": [HOTFIX, "Stopped halfway? I do that. Then I finish."]},
	&"cache": {"death": [CACHE, "Your last run ended badly. I remember every second."],
		"boss": [CACHE, "The boss again. I filed it under almost."],
		"win": [CACHE, "A win. I'll remember it for five minutes. Proudly."], "quit": [CACHE, "You left early. The pages noticed."]},
}

const IDLE := {
	&"grep": [[GREP, "Searching. Found dust. Want it?"], [GREP, "I take questions literally. Ask better ones."],
		[GREP, "The lantern needs a battery. Long story."]],
	&"hotfix": [[HOTFIX, "Fixed it! Don't look at it too hard."], [HOTFIX, "Works on my forge. Can't promise yours."],
		[HOTFIX, "Tape holds everything. Mostly."]],
	&"cache": [[CACHE, "I remember your last run perfectly. Not the one before."], [CACHE, "Pages are just memory with corners."],
		[CACHE, "Shh. The shelves are paging."]],
}

## Epilogue lines after the true ending (Story's post-mortem): one each, always last.
const EPILOGUE := {
	&"grep": [GREP, "Post-mortem notes: nobody's fault. Everybody's fix."],
	&"hotfix": [HOTFIX, "Fixed forward! Like me. Mostly tape."],
	&"cache": [CACHE, "No revert. No backup needed. I'm just me now."],
}

## Round 2: chatter, overheard in the Workshop (Hades' "overheard" exchanges). The lead plays
## one as bubbles when you walk near two of them, or after a while in the Workshop. `need`
## takes the arc conditions (flag, wins, depth, log, ...) plus `with`: who must live there
## (a resident id; the Duck and LINT always do). In order first, then at random among those
## whose conditions hold. Ids "res.chat.<i>.<k>": append, never reorder.
const CHATTER := [
	{"need": {"with": ["grep", "hotfix"]}, "lines": [[HOTFIX, "Grep! I fixed your chair!"], [GREP, "It wasn't broken."],
		[HOTFIX, "Now it's extra not broken!"]]},
	{"need": {"with": ["grep", "cache"]}, "lines": [[CACHE, "Grep, have we met?"], [GREP, "Every day for a month."],
		[CACHE, "Lovely. Nice to meet you."]]},
	{"need": {"with": ["hotfix", "cache"]}, "lines": [[HOTFIX, "Cache! Do you remember my name?"], [CACHE, "Hotfix. Tape. Loud."],
		[HOTFIX, "She remembers!"]]},
	{"need": {"with": ["hotfix"]}, "lines": [[LINT, "Hotfix. Your forge fails eleven checks."], [HOTFIX, "Only eleven? New record!"]]},
	{"need": {"with": ["hotfix"], "since": 2}, "lines": [[HOTFIX, "Duck! Is the tape holding up?"], [DUCK, "I never asked for tape."],
		[HOTFIX, "Nobody asks for tape. Tape just arrives."]]},
	{"need": {"with": ["grep"], "flag": "confessed"}, "lines": [[GREP, "Your duck talks too much."],
		[DUCK, "You approve without reading. We all have flaws."]]},
	{"need": {"with": ["grep"], "flag": "confessed"}, "lines": [[GREP, "LINT. You warned them. I didn't."],
		[LINT, "Warnings are free. Reading them is not."]]},
	{"need": {"with": ["cache"], "log": "d0c0de"}, "lines": [[CACHE, "Duck, you're new. Since 16:59:01."],
		[DUCK, "Please don't tell people my age."]]},
	{"need": {"with": ["grep", "hotfix"], "flag": "hotfix_told"}, "lines": [[GREP, "You muted the tests. I skipped the review."],
		[HOTFIX, "Between us, one bad afternoon."], [GREP, "And one good fix. Eventually."]]},
	{"need": {"with": ["grep", "hotfix", "cache"], "flag": "fixed_forward"}, "lines": [
		[CACHE, "No revert. So I get to keep remembering you."], [HOTFIX, "Then remember this: I fixed the kettle."],
		[GREP, "It wasn't broken."]]},
	{"need": {"with": ["cache"], "pages": 6}, "lines": [[LINT, "Cache. Your shelves are unsorted."], [CACHE, "They're sorted by feeling."],
		[LINT, "That is not a key."]]},
]

## Round 2: what neighbours think of each other (and of the Duck and LINT): a flavour
## bubble when one walks past another. Ids "res.<who>.of.<other>".
const OPINIONS := {
	&"grep": {&"hotfix": [GREP, "Hotfix fixes things that work. Loudly."], &"cache": [GREP, "Cache forgets me daily. Restful, honestly."],
		&"duck": [GREP, "The duck's all right. Good listener."], &"lint": [GREP, "LINT and I disagree about commas."]},
	&"hotfix": {&"grep": [HOTFIX, "Grep's grumpy. I'm fixing that too."], &"cache": [HOTFIX, "Cache keeps everything. Even my jokes!"],
		&"duck": [HOTFIX, "I love the duck. The duck fears me."], &"lint": [HOTFIX, "LINT scans me every morning. Rude!"]},
	&"cache": {&"grep": [CACHE, "Grep reads slowly. I like slow readers."], &"hotfix": [CACHE, "Hotfix hums while he works. Off-key."],
		&"duck": [CACHE, "The duck is younger than it looks. Much."], &"lint": [CACHE, "LINT's warnings. I keep every one."]},
}

## Grep's Search: the first of these that holds is the run's hint (one a run).
const HINTS := [
	{"if": "resident", "text": "Someone's caged in %s. Third room, the middle door."},
	{"if": "confess", "text": "Come back after you've seen the Kernel. I owe you a story."},
	{"if": "log", "text": "There's a commit you haven't read. Debug Terminals keep them."},
	{"if": "pages", "text": "Cache is missing pages. Every boss drops one."},
	{"if": "true", "text": "The Glitch can be fixed forward. Beat it again, then choose."},
	{"if": "heat", "text": "The portal takes Bug Reports. Harder runs pay more Bits."},
	{"if": "pack", "text": "The Merchant has packs you don't own. New spells, not power."},
	{"if": "any", "text": "Cracked walls hide chests. Blast them."},
]

## Hotfix's Skin Forge: looks only. `body` is the wand's wood ramp, `gem` its gem colour
## (a Style key), `trail` a spark tint. "hotfix" is his gift, never sold.
const SKINS := [
	{"id": "oak", "name": "Plain Oak", "price": 0, "body": "wood", "gem": "", "trail": ""},
	{"id": "brass", "name": "Brass Rod", "price": 60, "body": "gold", "gem": "cyan:4", "trail": "gold:4"},
	{"id": "frost", "name": "Cold Boot", "price": 60, "body": "steel", "gem": "frost:4", "trail": "frost:4"},
	{"id": "ember", "name": "Hot Path", "price": 80, "body": "rust", "gem": "ember:4", "trail": "ember:4"},
	{"id": "moss", "name": "Legacy Root", "price": 80, "body": "leaf", "gem": "moss:3", "trail": "leaf:3"},
	{"id": "void", "name": "Ring Zero", "price": 120, "body": "night", "gem": "violet:4", "trail": "violet:4"},
	{"id": "hotfix", "name": "Mostly Tape", "price": -1, "body": "bone", "gem": "ember:3", "trail": "bone:4"},
]

## Cache's Lost Pages: twelve tiny source files whose comments tell the Arcanum's history.
## Found in order, one per boss or mini-boss once Cache lives in the Workshop.
const PAGES := [
	{"title": "source.spell", "code": ["// In the beginning, one spell:", "let world = cast(light);", "// Everything since is a patch."]},
	{"title": "guild.cfg", "code": ["// The first spellwrights formed a Guild", "reviewers = 2", "// so no spell ran unread."]},
	{"title": "moss.spell", "code": ["// Moss: the oldest process.", "while (rain) grow();", "// It never had eyes. Until Friday."]},
	{"title": "duck.md", "code": ["# Rubber ducks", "Talk your bug through, out loud.", "The duck is not expected to reply."]},
	{"title": "loop.spell", "code": ["// The world spins at 100%.", "// TODO: add an exit condition", "// (added: never)"]},
	{"title": "foundry.cfg", "code": ["// Every spell is forged here.", "max_temp = 100", "// temp today: 104. Nobody asked why."]},
	{"title": "mutex.spell", "code": ["// Two locks guard the Kernel.", "lock(a); lock(b);", "// Order matters. Nobody wrote it down."]},
	{"title": "lint.log", "code": ["// LINT was built to warn.", "warn(untested_change);", "// It was not built to be heard."]},
	{"title": "reviewers.txt", "code": ["reviewers = 1", "// cut to save time", "// (Friday afternoon, a long time ago)"]},
	{"title": "backup.spell", "code": ["// Snapshot: Friday, 16:58.", "keep(world);", "// Keeper: Cache. Do not delete."]},
	{"title": "glitch.spell", "code": ["// Not evil. Just unfinished.", "regen += tiny_tweak;", "// It does what the code says."]},
	{"title": "readme.md", "code": ["# How to fix a world", "1. Find the bug. 2. Own it.", "3. Fix forward. 4. Add a reviewer."]},
]

## Tests and tools: no meta (as Story).
static var _mem: Dictionary = {}


static func _meta() -> Dictionary:
	return SaveGame.load_meta() if SaveGame.enabled else _mem


static func _save(m: Dictionary) -> void:
	if SaveGame.enabled:
		SaveGame.save_meta(m)
	else:
		_mem = m


static func _rec(m: Dictionary) -> Dictionary:
	return m.get("residents", {})


## A speaker tag's resident ("GREP" -> &"grep"), or &"" for the Duck, LINT or anyone else.
static func id_of(tag: String) -> StringName:
	for id in ORDER:
		if DEFS[id]["who"] == tag:
			return id
	return &""


static func rescued(id: StringName, m: Dictionary = {}) -> bool:
	return _rec(m if not m.is_empty() else _meta()).has(String(id))


static func rescued_count(m: Dictionary = {}) -> int:
	var mm := m if not m.is_empty() else _meta()
	return ORDER.filter(func(id: StringName) -> bool: return rescued(id, mm)).size()


## The resident caged in this run's world, or &"" (none left, or a run that never has one:
## the lesson run, a daily, the Workshop's sandbox).
static func waiting_in(run: RunState) -> StringName:
	if run == null or run.tutorial or run.daily != "" or run.sandbox:
		return &""
	for id in ORDER:
		if int(DEFS[id]["world"]) == run.world and not rescued(id):
			return id
	return &""


## The cage opened: they move in (noted with the run count, for `since`).
static func rescue(id: StringName) -> void:
	var m := _meta()
	var rec: Dictionary = _rec(m)
	if rec.has(String(id)):
		return
	rec[String(id)] = {"at": int(m.get("runs", 0)), "beat": 0, "react": -1}
	m["residents"] = rec
	_save(m)


static func flag(name: String, m: Dictionary = {}) -> bool:
	var mm := m if not m.is_empty() else _meta()
	return (mm.get("story_flags", []) as Array).has(name)


static func set_flag(name: String) -> void:
	var m := _meta()
	var f: Array = m.get("story_flags", [])
	if not f.has(name):
		f.append(name)
	m["story_flags"] = f
	_save(m)


static func pages(m: Dictionary = {}) -> int:
	var mm := m if not m.is_empty() else _meta()
	return int(mm.get("pages", 0))


## The lifetime facts a beat's conditions read.
static func facts(id: StringName, m: Dictionary) -> Dictionary:
	var r: Dictionary = _rec(m).get(String(id), {})
	return {"since": int(m.get("runs", 0)) - int(r.get("at", 0)), "depth": int(m.get("best_step", 0)),
		"wins": int(m.get("wins", 0)), "pages": pages(m), "heat": int(m.get("heat", 0)),
		"runs": int(m.get("runs", 0)), "skins": (m.get("skins", []) as Array).filter(func(k: Variant) -> bool: return String(k) != "oak").size(),
		"packs": (m.get("packs", []) as Array).size()}


static func _holds(need: Dictionary, f: Dictionary, m: Dictionary) -> bool:
	for k in need:
		if k == "flag":
			if not flag(String(need[k]), m):
				return false
		elif k == "log":
			if not (m.get("logs", []) as Array).has(String(need[k])):
				return false
		elif k == "with":
			for other in need[k]:
				if not rescued(StringName(other), m):
					return false
		elif int(f.get(k, 0)) < int(need[k]):
			return false
	return true


## The next arc beat's index if it can be told now, else -1.
static func next_beat(id: StringName, m: Dictionary = {}) -> int:
	var mm := m if not m.is_empty() else _meta()
	if not rescued(id, mm):
		return -1
	var i := int(_rec(mm)[String(id)].get("beat", 0))
	var arc: Array = ARCS[id]
	if i >= arc.size():
		return -1
	return i if _holds(arc[i]["need"], facts(id, mm), mm) else -1


## How far through their story you are: [told, total].
static func progress(id: StringName, m: Dictionary = {}) -> Array:
	var mm := m if not m.is_empty() else _meta()
	var r: Dictionary = _rec(mm).get(String(id), {})
	return [int(r.get("beat", 0)), (ARCS[id] as Array).size()]


## What their next beat waits for, in words ("" once the story is told).
static func waits_for(id: StringName, m: Dictionary = {}) -> String:
	var mm := m if not m.is_empty() else _meta()
	var i := int(progress(id, mm)[0])
	var arc: Array = ARCS[id]
	if i >= arc.size():
		return ""
	var need: Dictionary = arc[i]["need"]
	var f := facts(id, mm)
	if _holds(need, f, mm):
		return "They have something to tell you."
	var unmet := func(k: String) -> bool: return need.has(k) and not _holds({k: need[k]}, f, mm)
	if unmet.call("pages"):
		return "More to say with %d Lost Pages." % int(need["pages"])
	if unmet.call("depth") and int(need["depth"]) >= 21:
		return "More to say once you've seen the Kernel."
	if unmet.call("depth") and int(need["depth"]) >= 11:
		return "More to say once the Loop has fallen."
	if unmet.call("wins"):
		return "More to say after a win."
	if unmet.call("heat"):
		return "More to say once you've run with a Bug Report."
	if unmet.call("skins"):
		return "More to say once you own %d skins." % int(need["skins"])
	if unmet.call("flag") or unmet.call("log"):
		return "More to say once the story moves on."
	if unmet.call("runs"):
		return "More to say after a few more runs."
	return "More to say after your next run."


## A "!" over them: a new beat is ready.
static func has_news(id: StringName, m: Dictionary = {}) -> bool:
	return next_beat(id, m) >= 0


## What they say when you walk up and talk: [{id, who, text}]. Tells the next beat (and
## applies its flag, log and gift), else the last run's reaction once a run, else idle.
static func talk(id: StringName, rng: RandomNumberGenerator = null) -> Array:
	var m := _meta()
	if not rescued(id, m):
		return []
	var rec: Dictionary = _rec(m)
	var r: Dictionary = rec[String(id)]
	var i := next_beat(id, m)
	if i >= 0:
		var beat: Dictionary = ARCS[id][i]
		r["beat"] = i + 1
		rec[String(id)] = r
		m["residents"] = rec
		if beat.has("gift"):
			var owned: Array = m.get("skins", [])
			if not owned.has(beat["gift"]):
				owned.append(beat["gift"])
			m["skins"] = owned
		_save(m)
		if beat.has("sets"):
			set_flag(beat["sets"])
		if beat.has("log"):
			Story.find_log_id(beat["log"])
		return _lines("res.%s.arc.%d" % [id, i], beat["lines"])
	var runs := int(m.get("runs", 0))
	var lr: Dictionary = m.get("last_run", {})
	if int(r.get("react", -1)) != runs and not lr.is_empty() and int(r.get("at", 0)) < runs:
		r["react"] = runs
		rec[String(id)] = r
		m["residents"] = rec
		_save(m)
		var k := react_kind(lr)
		return _lines("res.%s.react.%s" % [id, k], [REACT[id][k]])
	var idle: Array = IDLE[id]
	var j := (rng.randi() if rng else randi()) % idle.size()
	return _lines("res.%s.idle.%d" % [id, j], [idle[j]])


static func react_kind(lr: Dictionary) -> String:
	if lr.get("won", false):
		return "win"
	if lr.get("quit", false):
		return "quit"
	if lr.get("boss", false):
		return "boss"
	return "death"


static func _lines(base: String, pairs: Array) -> Array:
	var out: Array = []
	for k in pairs.size():
		out.append({"id": base if pairs.size() == 1 else "%s.%d" % [base, k], "who": pairs[k][0], "text": pairs[k][1]})
	return out


## The cage's lines as a resident is freed.
static func freed_lines(id: StringName) -> Array:
	return _lines("res.%s.freed" % id, FREED[id])


## Grep's hint for this run, or "" once it has been given (one a run).
static func hint(m: Dictionary = {}) -> String:
	var mm := m if not m.is_empty() else _meta()
	for h in HINTS:
		var t: String = h["text"]
		match String(h["if"]):
			"resident":
				for id in ORDER:
					if not rescued(id, mm):
						return t % Chapter.WORLDS[int(DEFS[id]["world"])]["name"]
			"confess":
				if int(mm.get("best_step", 0)) < 21:
					return t
			"log":
				if (mm.get("logs", []) as Array).size() < Story.LOGS.size() - 1:
					return t
			"pages":
				if pages(mm) < PAGES.size():
					return t
			"true":
				if true_ending_open(mm) and not flag("fixed_forward", mm):
					return t
			"heat":
				if int(mm.get("wins", 0)) >= 1 and int(mm.get("heat", 0)) == 0:
					return t
			"pack":
				if (mm.get("packs", []) as Array).size() < Meta.PACKS.size():
					return t
			"any":
				return t
	return ""


## Grep's Search: the run's hint (once a run; after that he says so).
static func search() -> String:
	var m := _meta()
	var runs := int(m.get("runs", 0))
	if int(m.get("hint_run", -1)) == runs:
		return "One question per run. Come back after the next one."
	var h := hint(m)
	m["hint_run"] = runs
	_save(m)
	return h


## The true ending (fix forward) is on offer at the Glitch's fall: a win behind you, every
## resident rescued, and Grep's confession heard.
static func true_ending_open(m: Dictionary = {}) -> bool:
	var mm := m if not m.is_empty() else _meta()
	return int(mm.get("wins", 0)) >= 1 and rescued_count(mm) == ORDER.size() and flag("confessed", mm)


## A Lost Page: the next one, once Cache is rescued (a boss or mini-boss fell). Returns its
## index, or -1.
static func find_page() -> int:
	var m := _meta()
	if not rescued(&"cache", m):
		return -1
	var n := pages(m)
	if n >= PAGES.size():
		return -1
	m["pages"] = n + 1
	_save(m)
	return n


# ---- the Skin Forge

static func skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]


static func skins_owned(m: Dictionary = {}) -> Array:
	var mm := m if not m.is_empty() else _meta()
	var owned: Array = (mm.get("skins", []) as Array).duplicate()
	if not owned.has("oak"):
		owned.push_front("oak")
	return owned


static func skin_on(m: Dictionary = {}) -> String:
	var mm := m if not m.is_empty() else _meta()
	return String(mm.get("skin", "oak"))


## Buys (for Bits) or equips a skin. Returns false if it can't be had.
static func take_skin(id: String) -> bool:
	var m := _meta()
	var s := skin(id)
	if s["id"] != id:
		return false
	var owned: Array = m.get("skins", [])
	if not owned.has(id) and id != "oak":
		var price := int(s["price"])
		if price < 0 or int(m.get("bits", 0)) < price:
			return false
		m["bits"] = int(m.get("bits", 0)) - price
		owned.append(id)
		m["skins"] = owned
	m["skin"] = id
	_save(m)
	return true


# ---- round 2: chatter and opinions

## Chatter whose conditions hold now (CHATTER indices).
static func chatter_open(m: Dictionary = {}) -> Array:
	var mm := m if not m.is_empty() else _meta()
	var out: Array = []
	for i in CHATTER.size():
		var need: Dictionary = CHATTER[i]["need"]
		var who: Array = need.get("with", [])
		var f := facts(StringName(who[0]) if not who.is_empty() else &"", mm)
		if _holds(need, f, mm):
			out.append(i)
	return out


## The next overheard exchange: [{id, who, text}], or [] when none fits. The first of those
## not yet heard, else any of them.
static func chatter(rng: RandomNumberGenerator = null) -> Array:
	var m := _meta()
	var open := chatter_open(m)
	if open.is_empty():
		return []
	var heard: Array = m.get("chatter_heard", [])
	var i: int = -1
	for j in open:
		if not heard.any(func(h: Variant) -> bool: return int(h) == int(j)):
			i = j
			break
	if i < 0:
		i = open[(rng.randi() if rng else randi()) % open.size()]
	else:
		heard.append(i)
		m["chatter_heard"] = heard
		_save(m)
	return _lines("res.chat.%d" % i, CHATTER[i]["lines"])


## A resident's word about a neighbour (a resident id, &"duck" or &"lint"), or [] if they
## have none (or haven't moved in).
static func opinion(id: StringName, of: StringName) -> Array:
	if not OPINIONS.has(id) or not OPINIONS[id].has(of) or not rescued(id):
		return []
	if DEFS.has(of) and not rescued(of):
		return []
	return _lines("res.%s.of.%s" % [id, of], [OPINIONS[id][of]])


## Every voiced line (tools/export_lines.gd via Story.all_lines).
static func all_lines() -> Array:
	var out: Array = []
	for i in CHATTER.size():
		out.append_array(_lines("res.chat.%d" % i, CHATTER[i]["lines"]))
	for id in OPINIONS:
		for of in OPINIONS[id]:
			out.append_array(_lines("res.%s.of.%s" % [id, of], [OPINIONS[id][of]]))
	for id in ORDER:
		out.append_array(freed_lines(id))
		for i in (ARCS[id] as Array).size():
			out.append_array(_lines("res.%s.arc.%d" % [id, i], ARCS[id][i]["lines"]))
		for k in REACT[id]:
			out.append_array(_lines("res.%s.react.%s" % [id, k], [REACT[id][k]]))
		for j in (IDLE[id] as Array).size():
			out.append_array(_lines("res.%s.idle.%d" % [id, j], [IDLE[id][j]]))
		out.append_array(_lines("res.%s.epilogue" % id, [EPILOGUE[id]]))
	return out
