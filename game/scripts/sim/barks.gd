class_name Barks
extends RefCounted
## Barks (story round 2, research/story.md "Barks"): short lines in speech bubbles over the
## speaker's head. In a run the Duck waddles beside you and LINT hovers behind; in the
## Workshop they talk as you come home. Pure sim: the lead's world code reports what
## happened (an event and its facts), and this picks who says what, or nothing.
##
## How a line is picked (Valve's dynamic dialog, with Hades' priority buckets):
##   - a RULE matches an event when every one of its criteria holds over the facts; the
##     remembered facts ride along as "mem.<key>" (see `sets`, remember())
##   - among the rules that match, the highest `pri` wins, then the most specific (more
##     criteria), then the earlier rule. A rule told `once` never plays again
##   - a rule's entries play in order the first time through (seen counts are saved), then
##     at random, never one its speaker said in the last RING lines (no immediate repeats)
##   - cooldowns: nothing for GLOBAL_CD seconds after any bark, and a speaker waits
##     SPEAKER_CD after their own. Events told at a set moment (FREE) ignore both, and so
##     does a rule with "cd": false (a boss changing phase)
##   - carry-over (Hades II's Hecate): a rule marked `carry` that matched but was held back
##     by a cooldown is saved, and the Workshop brings it up on the next visit (carry_over)
## pick() returns an exchange [[who, text, id], ...] or []. Ids are "bark.<rule id>.<i>"
## (".<k>" for a line of an exchange): rules and their entries are append-only, because the
## voice files match ids (tools/voices.sh renders them like every other line).

const DUCK := Story.DUCK
const LINT := Story.LINT

const GLOBAL_CD := 3.0
const SPEAKER_CD := 8.0
const RING := 3
const CARRY_MAX := 6
## LINT's arc: this many smells fixed after it flagged them unlocks its trick (Red Squiggle).
const LINT_TRICK_AT := 3

## Told at a set moment (walking into the Workshop, closing the wand editor): no cooldowns.
const FREE: Array[StringName] = [&"hub_return", &"carry", &"lint"]
## In-run companion events. Their lines stay within COMBAT_MAX characters (two short
## bubble lines); everything else within BUBBLE_MAX.
const COMBAT: Array[StringName] = [&"low_hp", &"room_fast", &"big_hit", &"elite_kill", &"mana_empty",
	&"rule_first", &"status", &"boss_phase"]
const COMBAT_MAX := 40
const BUBBLE_MAX := 60

## Every event and the facts it reads (the lead fills them; a missing fact is null).
const EVENTS := {
	&"low_hp": "hp (0..1, fire it as HP drops under 30%), boss (bool: in a boss room)",
	&"room_fast": "time (s the room took; fire it under 12 s)",
	&"big_hit": "dmg (the hit's damage; fire it at 60 or more)",
	&"elite_kill": "elites (elites killed this run, this one included)",
	&"mana_empty": "rule (the wand's rule, \"\" for none)",
	&"rule_first": "rule (shuffle | pinned | palindrome | pages | recycle): a rule wand's first cast in a run",
	&"status": "status (burn | frost | rot | shock), n (enemies carrying it now; fire at 5)",
	&"boss_phase": "boss (title, without \" 2.0\"), phase (2, 3, ...)",
	&"hub_return": "run_facts() + stash(): see run_facts",
	&"carry": "one key per carried event, true (carry_over builds it)",
	&"lint": "smell (Story.SMELLS), fixed (bool), trick (bool), clean (bool) (lint_review builds it)",
}

## The rules. "when": criteria (a value must equal the fact; [op, v] compares with op in
## < <= > >= == != in); "pri": priority (default 10); "once"; "carry"; "cd": false ignores
## cooldowns; "sets": {key: value} remembered when it plays ("+1" counts up); "lines": the
## entries, each [who, text] or an exchange [[who, text], ...].
const RULES := [
	# ---- in a run: the companions (40 characters at most) --------------------------------
	{"id": "low_hp", "event": &"low_hp", "when": {"hp": ["<", 0.3]}, "pri": 60, "carry": true, "lines": [
		[DUCK, "You're blinking red. Please don't."],
		[LINT, "Health critical. Recommend: not dying."],
		[DUCK, "Low health. Dodge now, be brave later."],
		[LINT, "Error: too much damage taken."],
		[DUCK, "Deep breath. Find a gap. Go."]]},
	{"id": "low_hp_boss", "event": &"low_hp", "when": {"hp": ["<", 0.3], "boss": true}, "pri": 62, "lines": [
		[DUCK, "Hang on! It's hurting too."],
		[LINT, "Two low health bars. Who blinks first?"],
		[DUCK, "Patience. Dodge first, then finish it."]]},
	{"id": "room_fast", "event": &"room_fast", "when": {"time": ["<", 12.0]}, "pri": 30, "carry": true, "lines": [
		[DUCK, "That was quick! Blink and done."],
		[LINT, "Room cleared. Faster than my boot."],
		[DUCK, "Speedrun! I barely quacked."],
		[LINT, "Runtime: short. Efficiency: noted."]]},
	{"id": "big_hit", "event": &"big_hit", "when": {"dmg": [">=", 60]}, "pri": 40, "carry": true, "lines": [
		[DUCK, "Ooh. They felt that one."],
		[LINT, "Damage exceeds sensible limits."],
		[DUCK, "Big number! Do it again!"],
		[LINT, "Overkill detected. Not a complaint."]]},
	{"id": "big_hit_huge", "event": &"big_hit", "when": {"dmg": [">=", 150]}, "pri": 45, "carry": true, "lines": [
		[LINT, "That number nearly broke the math."],
		[DUCK, "I felt that from over here!"],
		[LINT, "Damage value: frankly rude."]]},
	{"id": "elite_kill", "event": &"elite_kill", "pri": 35, "carry": true, "lines": [
		[DUCK, "Elite down. Not so elite now."],
		[LINT, "Elite process terminated."],
		[DUCK, "Fancy one gone. Fancy work."],
		[LINT, "Threat level: formerly high."]]},
	{"id": "elite_many", "event": &"elite_kill", "when": {"elites": [">=", 5]}, "pri": 40, "carry": true, "lines": [
		[DUCK, "Five elites! You're collecting them."],
		[LINT, "Elite count: high. Elite supply: low."],
		[DUCK, "They send their best. You send them off."]]},
	{"id": "mana_empty", "event": &"mana_empty", "pri": 25, "lines": [
		[DUCK, "Out of mana. Let it breathe."],
		[LINT, "Mana: zero. Casting: denied."],
		[DUCK, "Wand's empty. Dodge while it refills."],
		[LINT, "Insufficient funds. Try later."]]},
	{"id": "mana_recycle", "event": &"mana_empty", "when": {"rule": "recycle"}, "pri": 30, "lines": [
		[DUCK, "Recycle Bin's dry. Kills refill it."],
		[LINT, "No kills, no mana. Bin rules."],
		[DUCK, "Feed the bin. Somebody nearby."]]},
	{"id": "rule_shuffle", "event": &"rule_first", "when": {"rule": "shuffle"}, "pri": 50, "carry": true, "lines": [
		[DUCK, "Shuffle! Your spells, in a new order."],
		[LINT, "Order randomised. I disapprove."],
		[DUCK, "Surprise order. Watch the slots."]]},
	{"id": "rule_pinned", "event": &"rule_first", "when": {"rule": "pinned"}, "pri": 50, "carry": true, "lines": [
		[LINT, "Slot 1 pinned. It joins every cast."],
		[DUCK, "Pinned! That first slot is always on."],
		[LINT, "A pinned boost powers everything."]]},
	{"id": "rule_palindrome", "event": &"rule_first", "when": {"rule": "palindrome"}, "pri": 50, "carry": true, "lines": [
		[DUCK, "There and back again. Like a yo-yo."],
		[LINT, "Reading forwards. Then backwards."],
		[LINT, "Same both ways. Like the word level."]]},
	{"id": "rule_pages", "event": &"rule_first", "when": {"rule": "pages"}, "pri": 50, "carry": true, "lines": [
		[LINT, "Double Buffer. One page at a time."],
		[DUCK, "Half the wand now, half next time."],
		[LINT, "Page flipped. Other half loaded."]]},
	{"id": "rule_recycle", "event": &"rule_first", "when": {"rule": "recycle"}, "pri": 50, "carry": true, "lines": [
		[DUCK, "Recycle Bin! Kills fill its mana."],
		[LINT, "No refills. Feed it enemies."],
		[DUCK, "It eats defeat. Theirs, not yours."]]},
	{"id": "status_burn", "event": &"status", "when": {"status": "burn"}, "pri": 30, "carry": true, "lines": [
		[DUCK, "Everything's on fire. On purpose?"],
		[LINT, "Temperature rising. Theirs."],
		[DUCK, "Toasty. Keep them burning."]]},
	{"id": "status_frost", "event": &"status", "when": {"status": "frost"}, "pri": 30, "carry": true, "lines": [
		[LINT, "Target not responding. Frozen."],
		[DUCK, "Chilly. They're slowing right down."],
		[DUCK, "Frozen solid. Like my inbox."]]},
	{"id": "status_rot", "event": &"status", "when": {"status": "rot"}, "pri": 30, "carry": true, "lines": [
		[DUCK, "The rot spreads. Good rot, for once."],
		[LINT, "Data corrupted. Theirs, fortunately."],
		[DUCK, "Rotten luck. For them."]]},
	{"id": "status_shock", "event": &"status", "when": {"status": "shock"}, "pri": 30, "carry": true, "lines": [
		[LINT, "Voltage high. Wards: stripped."],
		[DUCK, "Zap! They're buzzing now."],
		[DUCK, "Did you turn them off and on again?"]]},
	{"id": "phase", "event": &"boss_phase", "when": {"phase": 2}, "pri": 50, "cd": false, "lines": [
		[DUCK, "It changed. Watch the new moves."],
		[LINT, "Phase two. New patterns loaded."]]},
	{"id": "phase_last", "event": &"boss_phase", "when": {"phase": [">=", 3]}, "pri": 52, "cd": false, "lines": [
		[LINT, "Final phase. Its worst is next."],
		[DUCK, "Angry means hurt. Keep at it."]]},
	{"id": "phase_loop", "event": &"boss_phase", "when": {"boss": "The Infinite Loop"}, "pri": 60, "cd": false, "lines": [
		[DUCK, "Smaller and faster. Break the body!"],
		[LINT, "Loop body exposed. Hit it."]]},
	{"id": "phase_deadlock", "event": &"boss_phase", "when": {"boss": "Deadlock"}, "pri": 60, "cd": false, "lines": [
		[LINT, "Lock states changed. Find the open one."],
		[DUCK, "Beam's coming. Out of the circle!"]]},
	{"id": "phase_race", "event": &"boss_phase", "when": {"boss": "Data Race"}, "pri": 60, "cd": false, "lines": [
		[DUCK, "Keep them even. Both at once!"],
		[LINT, "Threads diverging. Balance the damage."]]},
	{"id": "phase_glitch", "event": &"boss_phase", "when": {"boss": "The Glitch"}, "pri": 60, "cd": false, "lines": [
		[LINT, "It's rewriting the room. Stay mobile."],
		[DUCK, "It's changing the rules. So do we."]]},
	{"id": "phase_copy", "event": &"boss_phase", "when": {"boss": "Copy-Paste"}, "pri": 60, "cd": false, "lines": [
		[DUCK, "It's copying faster. Keep moving."],
		[LINT, "Clipboard full. Expect repeats."]]},
	{"id": "phase_gc", "event": &"boss_phase", "when": {"boss": "Garbage Collector"}, "pri": 60, "cd": false, "lines": [
		[DUCK, "Lid's opening? Stop shooting!"],
		[LINT, "Sweep cycle. Do not feed it."]]},

	# ---- the Workshop: the post-mortem (Barks.hub_return) ---------------------------------
	{"id": "pm_first_win", "event": &"hub_return", "when": {"first_win": true}, "pri": 95, "once": true,
		"sets": {"framed": true}, "lines": [
		[[DUCK, "Our first win. I'm framing this."], [LINT, "Framed. Wall space allocated."]]]},
	{"id": "pm_heat_win", "event": &"hub_return", "when": {"won": true, "heat": [">=", 1]}, "pri": 80, "lines": [
		[[LINT, "Won with bug reports open. Noted."], [DUCK, "Hot and winning. One more report?"]],
		[[DUCK, "A win at heat! Show-off."], [LINT, "Heat survived. Barely a scratch."]]]},
	{"id": "pm_nemesis", "event": &"hub_return", "when": {"won": false, "killer_count": [">=", 3]}, "pri": 78, "lines": [
		[[DUCK, "Three times now. That's a nemesis."], [LINT, "Nemesis: officially registered."]],
		[DUCK, "It again. I'm starting to hate it."]]},
	{"id": "pm_same", "event": &"hub_return", "when": {"won": false, "same_killer": true}, "pri": 75, "lines": [
		[[DUCK, "Same thing got you twice."], [LINT, "Reproducible. That is good news."]],
		[[DUCK, "Again? It's learning your moves."], [LINT, "Or you are not learning its."]]]},
	{"id": "pm_record", "event": &"hub_return", "when": {"won": false, "record": true}, "pri": 70, "lines": [
		[[LINT, "New depth record. Logged."], [DUCK, "Deeper than ever. The bug felt that."]],
		[DUCK, "Furthest yet! Not that I'm counting."]]},
	{"id": "pm_glitch", "event": &"hub_return", "when": {"died_to": "The Glitch"}, "pri": 70, "lines": [
		[[DUCK, "So close. Your own bug beat you."], [LINT, "It had a head start. Since Friday."]],
		[DUCK, "At the Glitch. That's the last step."]]},
	{"id": "pm_loop", "event": &"hub_return", "when": {"died_to": "The Infinite Loop"}, "pri": 65, "lines": [
		[[DUCK, "The Loop got us. It does go on."], [LINT, "And on. And on. And on."]],
		[DUCK, "Break its body in phase two. Promise?"]]},
	{"id": "pm_deadlock", "event": &"hub_return", "when": {"died_to": "Deadlock"}, "pri": 65, "lines": [
		[[DUCK, "Deadlock. It waited. We didn't."], [LINT, "Waiting was the correct move."]],
		[DUCK, "Hit the open lock. Leave the beam alone."]]},
	{"id": "pm_race", "event": &"hub_return", "when": {"died_to": "Data Race"}, "pri": 65, "lines": [
		[[LINT, "Race condition: unresolved."], [DUCK, "Even them out. Then finish together."]],
		[DUCK, "The twins again. Hurt both, end both."]]},
	{"id": "pm_copy", "event": &"hub_return", "when": {"died_to": "Copy-Paste"}, "pri": 65, "lines": [
		[DUCK, "Copy-Paste used your wand on you. Rude."],
		[[LINT, "Cause: your own spells."], [DUCK, "Try a wand it hasn't seen."]]]},
	{"id": "pm_gc", "event": &"hub_return", "when": {"died_to": "Garbage Collector"}, "pri": 65, "lines": [
		[DUCK, "The Collector kept everything. Even you."],
		[[LINT, "Collected. Filed under garbage."], [DUCK, "Stop shooting when the lid opens."]]]},
	{"id": "pm_short", "event": &"hub_return", "when": {"short": true}, "pri": 60, "lines": [
		[[DUCK, "That was short. A warm-up, right?"], [LINT, "Duration: brief. Lessons: some."]],
		[DUCK, "Everyone trips on the first step."]]},
	{"id": "pm_quit", "event": &"hub_return", "when": {"quit": true}, "pri": 55, "lines": [
		[[LINT, "Run abandoned by user."], [DUCK, "Sometimes stopping is the fix."]],
		[DUCK, "Walked out? Fair. Fresh wand time."]]},
	{"id": "pm_pack", "event": &"hub_return", "when": {"pack_new": true}, "pri": 50, "lines": [
		[[DUCK, "New pack, first run. How was it?"], [LINT, "Early data: inconclusive."]],
		[DUCK, "New spells, first try. Any favourites?"]]},
	{"id": "pm_rule", "event": &"hub_return", "when": {"rule": ["!=", ""]}, "pri": 45, "lines": [
		[[LINT, "Wand rule in use. Bold."], [DUCK, "Weird wands win runs. Keep it."]],
		[DUCK, "Odd wand, good ideas. Odd is good."]]},
	{"id": "pm_relics_many", "event": &"hub_return", "when": {"relics": [">=", 8]}, "pri": 40, "lines": [
		[[DUCK, "So many relics. You were a museum."], [LINT, "Inventory: heavy. Results: mixed."]]]},
	{"id": "pm_relics_none", "event": &"hub_return", "when": {"won": false, "relics": 0, "depth": [">=", 6]}, "pri": 40, "lines": [
		[DUCK, "No relics at all? Brave. Or busy."]]},
	{"id": "pm_win_wall", "event": &"hub_return", "when": {"won": true, "mem.framed": true}, "pri": 35, "lines": [
		[[DUCK, "Another win for the wall."], [LINT, "Wall capacity: concerning."]],
		[DUCK, "I'll need a bigger frame."]]},
	{"id": "pm_heat_death", "event": &"hub_return", "when": {"won": false, "heat": [">=", 3]}, "pri": 35, "lines": [
		[[LINT, "High heat. Failure expected."], [DUCK, "Expected. Not accepted. Again?"]]]},
	{"id": "pm_win", "event": &"hub_return", "when": {"won": true}, "pri": 30, "lines": [
		[[LINT, "Post-mortem: success. A rare format."], [DUCK, "No bugs. Well. Fewer bugs."]],
		[DUCK, "Another win. The bug's getting nervous."],
		[DUCK, "I could get used to winning."]]},
	{"id": "pm_world2", "event": &"hub_return", "when": {"won": false, "world": 1}, "pri": 25, "lines": [
		[DUCK, "The Foundry cooked us. Bring frost?"],
		[[LINT, "World 2 runs hot. Literally."], [DUCK, "Cool heads win. Cool spells too."]]]},
	{"id": "pm_world3", "event": &"hub_return", "when": {"won": false, "world": 2}, "pri": 25, "lines": [
		[[DUCK, "The Kernel is tough. We're tougher."], [LINT, "Claim unverified."]]]},
	{"id": "pm_death", "event": &"hub_return", "when": {"won": false}, "pri": 10, "lines": [
		[DUCK, "We'll get it. Bugs can't hide forever."],
		[[LINT, "Post-mortem filed. Cause: damage."], [DUCK, "Very insightful, LINT."]],
		[DUCK, "Bad run. Good data. That's the job."]]},

	# ---- the Workshop: what the last run's bubbles missed (Barks.carry_over) -------------
	{"id": "carry_elite", "event": &"carry", "when": {"elite_kill": true}, "pri": 40, "lines": [
		[[DUCK, "You beat an elite back there. I missed it!"], [LINT, "I did not. Logged."]]]},
	{"id": "carry_big", "event": &"carry", "when": {"big_hit": true}, "pri": 35, "lines": [
		[[DUCK, "That huge hit last run. Wow."], [LINT, "Replay unavailable. The number was big."]]]},
	{"id": "carry_rule", "event": &"carry", "when": {"rule_first": true}, "pri": 30, "lines": [
		[[DUCK, "That new wand last run. I have notes."], [LINT, "The duck always has notes."]]]},
	{"id": "carry_fast", "event": &"carry", "when": {"room_fast": true}, "pri": 25, "lines": [
		[DUCK, "That quick room last run? I timed it. Wow."]]},
	{"id": "carry_status", "event": &"carry", "when": {"status": true}, "pri": 20, "lines": [
		[[LINT, "Status report from last run."], [DUCK, "Short version: chaos. Good chaos."]]]},
	{"id": "carry_low", "event": &"carry", "when": {"low_hp": true}, "pri": 15, "lines": [
		[DUCK, "You were nearly out back there. Careful."]]},

	# ---- LINT's arc: code smells (Story.smells, Barks.lint_review) -------------------------
	{"id": "lint_trick", "event": &"lint", "when": {"trick": true}, "pri": 90, "once": true, "lines": [
		[[LINT, "Three warnings fixed. Trust level raised."], [LINT, "Enabling Red Squiggle. I'll mark targets."],
			[DUCK, "LINT made you a present. That's huge."]]]},
	{"id": "lint_fixed", "event": &"lint", "when": {"fixed": true}, "pri": 60, "lines": [
		[[LINT, "Warning resolved. Wand quality improved."], [DUCK, "LINT's pleased. You can tell. Barely."]],
		[LINT, "You listened. Unexpected. Logged."],
		[LINT, "Smell gone. Review passed."]]},
	{"id": "smell_no_spell", "event": &"lint", "when": {"smell": "no_spell"}, "pri": 50, "lines": [
		[[LINT, "Smell: nothing on this wand shoots."], [DUCK, "All boosts, no bang. Add a spell."]],
		[LINT, "No shooting spell found. Bold."]]},
	{"id": "smell_trig_tail", "event": &"lint", "when": {"smell": "trig_tail"}, "pri": 50, "lines": [
		[[LINT, "Smell: a trigger with no spell after it."], [DUCK, "A trigger needs a spell to call."]],
		[LINT, "That trigger calls nothing. Add a spell."]]},
	{"id": "smell_boost_tail", "event": &"lint", "when": {"smell": "boost_tail"}, "pri": 50, "lines": [
		[[LINT, "Smell: a boost with nothing on its right."], [DUCK, "Boosts power what's on their right."]],
		[LINT, "That boost boosts nothing. Move it left."]]},
	{"id": "smell_copy3", "event": &"lint", "when": {"smell": "copy3"}, "pri": 50, "lines": [
		[[LINT, "Smell: one spell three times in a row."], [DUCK, "Copy-paste is how we got here."]],
		[LINT, "Three copies. A Twin Cast does that."]]},
	{"id": "smell_gap", "event": &"lint", "when": {"smell": "gap"}, "pri": 50, "lines": [
		[[LINT, "Smell: an empty slot between spells."], [DUCK, "Harmless. LINT won't let it go, though."]],
		[LINT, "Dead space in the wand. Fill that slot."]]},
	{"id": "lint_clean", "event": &"lint", "when": {"clean": true}, "pri": 5, "lines": [
		[LINT, "No smells found. Suspicious. Approved."],
		[LINT, "Zero warnings. Rare. Framing it."]]},
]

## Runtime only (a new run or the Workshop starts them fresh): cooldowns and the rings.
static var _last_any := -1000.0
static var _last_by: Dictionary = {}
static var _ring: Dictionary = {}
static var _index: Dictionary = {}


## Clears the cooldowns and the recently-said rings. Call as a run starts and as the
## Workshop opens (their clocks differ).
static func reset() -> void:
	_last_any = -1000.0
	_last_by = {}
	_ring = {}


# ---- memory: kept in meta.json under "barks" (Story's store, so tests use Story._mem)

static func _mem_of(m: Dictionary) -> Dictionary:
	var b: Dictionary = m.get("barks", {})
	for k in ["seen", "mem"]:
		if not b.has(k):
			b[k] = {}
	for k in ["once", "carry"]:
		if not b.has(k):
			b[k] = []
	m["barks"] = b
	return b


## A remembered fact (rules read it as "mem.<key>").
static func recall(key: String, fallback: Variant = null) -> Variant:
	return (_mem_of(Story._meta())["mem"] as Dictionary).get(key, fallback)


static func remember(key: String, value: Variant) -> void:
	var m := Story._meta()
	_mem_of(m)["mem"][key] = value
	Story._save(m)


# ---- the engine

static func _rules_for(event: StringName) -> Array:
	if _index.is_empty():
		for i in RULES.size():
			var ev := StringName(RULES[i]["event"])
			if not _index.has(ev):
				_index[ev] = []
			_index[ev].append(i)
	return _index.get(event, [])


static func _num(v: Variant) -> bool:
	return v is int or v is float


static func _same(a: Variant, b: Variant) -> bool:
	if _num(a) and _num(b):
		return is_equal_approx(float(a), float(b))
	if a is bool or b is bool:
		return bool(a) == bool(b) if (a is bool and b is bool) else false
	return str(a) == str(b)


## True when every criterion holds over the facts.
static func holds(when: Dictionary, f: Dictionary) -> bool:
	for k in when:
		var want: Variant = when[k]
		var got: Variant = f.get(k, null)
		if want is Array:
			var op := String(want[0])
			var v: Variant = want[1]
			match op:
				"<", "<=", ">", ">=":
					if not _num(got):
						return false
					var a := float(got)
					var b := float(v)
					if (op == "<" and not a < b) or (op == "<=" and not a <= b) or (op == ">" and not a > b) or (op == ">=" and not a >= b):
						return false
				"==":
					if got == null or not _same(got, v):
						return false
				"!=":
					if got == null or _same(got, v):
						return false
				"in":
					if not (v as Array).any(func(x: Variant) -> bool: return got != null and _same(got, x)):
						return false
		elif want is bool:
			if bool(got if got != null else false) != want:
				return false
		elif got == null or not _same(got, want):
			return false
	return true


## An entry's lines: [[who, text, id], ...].
static func entry(rule: Dictionary, i: int) -> Array:
	var e: Array = rule["lines"][i]
	var base := "bark.%s.%d" % [rule["id"], i]
	if e[0] is String:
		return [[e[0], e[1], base]]
	var out: Array = []
	for k in e.size():
		out.append([e[k][0], e[k][1], "%s.%d" % [base, k]])
	return out


static func _in_ring(lines: Array) -> bool:
	for l in lines:
		if (_ring.get(l[0], []) as Array).has(l[2]):
			return true
	return false


static func _cooling(lines: Array, now: float) -> bool:
	if now - _last_any < GLOBAL_CD:
		return true
	for l in lines:
		if now - float(_last_by.get(l[0], -1000.0)) < SPEAKER_CD:
			return true
	return false


static func _is_last(lines: Array) -> bool:
	for l in lines:
		var ring: Array = _ring.get(l[0], [])
		if not ring.is_empty() and ring.back() == l[2]:
			return true
	return false


## Which entry a rule would play now: in order the first time through, then any one its
## speakers haven't said lately (the ring); in a small pool, any but a speaker's very last
## line. -1 when only a repeat is left.
static func _choose(rule: Dictionary, seen: int, rng: RandomNumberGenerator) -> int:
	var n: int = (rule["lines"] as Array).size()
	var free: Array = []
	for i in n:
		if not _in_ring(entry(rule, i)):
			free.append(i)
	if free.is_empty():
		for i in n:
			if not _is_last(entry(rule, i)):
				free.append(i)
	if free.is_empty():
		return -1
	if seen < n:
		for i in free:
			if i >= seen:
				return i
	return free[(rng.randi() if rng else randi()) % free.size()]


static func _plain(v: Variant) -> Variant:
	return String(v) if v is StringName else v


## The next exchange for an event, or [] (nothing matches, it's all cooling down or said
## lately). `now` is any clock in seconds that keeps running through the run.
static func pick(event: StringName, facts: Dictionary = {}, now: float = 0.0, rng: RandomNumberGenerator = null) -> Array:
	var idx := _rules_for(event)
	if idx.is_empty():
		return []
	# inside the global cooldown only a rule that ignores it or carries over can matter
	if not FREE.has(event) and now - _last_any < GLOBAL_CD and not idx.any(func(i: int) -> bool:
			return not RULES[i].get("cd", true) or RULES[i].get("carry", false)):
		return []
	var m := Story._meta()
	var b := _mem_of(m)
	var f := facts.duplicate()
	for k in b["mem"]:
		f["mem." + String(k)] = b["mem"][k]
	var cands: Array = []
	for i in idx:
		var r: Dictionary = RULES[i]
		if r.get("once", false) and (b["once"] as Array).has(r["id"]):
			continue
		if holds(r.get("when", {}), f):
			cands.append(i)
	if cands.is_empty():
		return []
	cands.sort_custom(func(x: int, y: int) -> bool:
		var rx: Dictionary = RULES[x]
		var ry: Dictionary = RULES[y]
		var px := int(rx.get("pri", 10))
		var py := int(ry.get("pri", 10))
		if px != py:
			return px > py
		var sx := (rx.get("when", {}) as Dictionary).size()
		var sy := (ry.get("when", {}) as Dictionary).size()
		if sx != sy:
			return sx > sy
		return x < y)
	var free := FREE.has(event)
	var held_back := false
	for i in cands:
		var r: Dictionary = RULES[i]
		var j := _choose(r, int(b["seen"].get(r["id"], 0)), rng)
		if j < 0:
			continue
		var lines := entry(r, j)
		if not free and r.get("cd", true) and _cooling(lines, now):
			held_back = held_back or r.get("carry", false)
			continue
		# it plays: cooldowns, rings, seen counts, once, and what it sets
		_last_any = now
		for l in lines:
			_last_by[l[0]] = now
			var ring: Array = _ring.get(l[0], [])
			ring.append(l[2])
			while ring.size() > RING:
				ring.pop_front()
			_ring[l[0]] = ring
		b["seen"][r["id"]] = int(b["seen"].get(r["id"], 0)) + 1
		if r.get("once", false):
			(b["once"] as Array).append(r["id"])
		var sets: Dictionary = r.get("sets", {})
		for k in sets:
			var v: Variant = sets[k]
			if v is String and v == "+1":
				b["mem"][k] = int(b["mem"].get(k, 0)) + 1
			elif v is String and (v as String).begins_with("$"):
				b["mem"][k] = _plain(facts.get((v as String).substr(1), null))
			else:
				b["mem"][k] = v
		Story._save(m)
		return lines
	if held_back:
		var carry: Array = b["carry"]
		if not carry.any(func(c: Dictionary) -> bool: return c.get("event", "") == String(event)):
			var c := {"event": String(event)}
			for k in facts:
				var v: Variant = _plain(facts[k])
				if v is String or v is int or v is float or v is bool:
					c[String(k)] = v
			carry.append(c)
			while carry.size() > CARRY_MAX:
				carry.pop_front()
			Story._save(m)
	return []


## What the last run saved for later (carried events, oldest first).
static func carried() -> Array:
	return (_mem_of(Story._meta())["carry"] as Array).duplicate()


## In the Workshop: one exchange about the best thing the bubbles missed, then the carry
## is cleared (said or not).
static func carry_over(now: float = 0.0, rng: RandomNumberGenerator = null) -> Array:
	var m := Story._meta()
	var b := _mem_of(m)
	var carry: Array = b["carry"]
	if carry.is_empty():
		return []
	var f := {}
	for c in carry:
		f[String(c.get("event", ""))] = true
	b["carry"] = []
	Story._save(m)
	return pick(&"carry", f, now, rng)


# ---- the post-mortem

## The last run as post-mortem facts. Call it BEFORE SaveGame.record_run (it compares with
## the lifetime numbers as they were), with what ended the run (Player.last_hurt_by, "" on a
## win) and `quit` for an abandoned run.
##   won, quit, forward (fixed forward), daily (bool)   world, step, depth, heat, relics,
##   kills, rooms (int)   time (s)   died_to (the source's name: "The Infinite Loop",
##   "moss"; "" on a win or quit)   died_how ("touch", "beam", "shot", ...)
##   died_boss (bool: in a boss or mini-boss room)   record (bool: deeper than ever before)
##   first_win (bool)   rule (the held wand's rule, "" for none)   short (bool: out in the
##   first rooms of World 1)
static func run_facts(run: RunState, by := "", quit := false, m: Dictionary = {}) -> Dictionary:
	var mm := m if not m.is_empty() else Story._meta()
	var f := {}
	if run == null:
		return f
	var won := run.won
	var who := "" if won or quit else by
	var how := ""
	if who.contains(":"):
		how = who.get_slice(":", 0)
		who = who.substr(who.find(":") + 1)
	who = who.trim_suffix(" 2.0")
	var depth := Chapter.depth(run)
	var kind: StringName = Chapter.PLAN[clampi(run.step, 0, Chapter.PLAN.size() - 1)]
	f["won"] = won
	f["quit"] = quit
	f["forward"] = int(run.stats.get("fixed", 0)) > 0
	f["daily"] = run.daily != ""
	f["world"] = run.world
	f["step"] = run.step
	f["depth"] = depth
	f["heat"] = run.heat
	f["relics"] = run.relics.size()
	f["kills"] = int(run.stats.get("kills", 0))
	f["rooms"] = int(run.stats.get("rooms", 0))
	f["time"] = float(run.stats.get("time", 0.0))
	f["died_to"] = who
	f["died_how"] = how
	f["died_boss"] = not won and not quit and (kind == &"boss" or kind == &"mini")
	f["record"] = int(mm.get("runs", 0)) > 0 and depth > int(mm.get("best_step", 0))
	f["first_win"] = won and int(mm.get("wins", 0)) == 0
	f["rule"] = String(run.wand().def.rule) if not run.wands.is_empty() else ""
	f["short"] = not won and not quit and run.world == 0 and run.step <= 2
	return f


## Keeps the run's facts for the Workshop (they survive a quit to the title) and adds what
## memory knows: same_killer (the same thing as last time), killer_count (deaths to it,
## this one included), pack_new (a pack bought since the last post-mortem).
static func stash(facts: Dictionary) -> void:
	var m := Story._meta()
	var b := _mem_of(m)
	var f := {}
	for k in facts:
		f[String(k)] = _plain(facts[k])
	var who := String(f.get("died_to", ""))
	var mem: Dictionary = b["mem"]
	f["same_killer"] = who != "" and who == String(mem.get("last_died_to", ""))
	if who != "":
		var tally: Dictionary = mem.get("killed_by", {})
		tally[who] = int(tally.get(who, 0)) + 1
		mem["killed_by"] = tally
		f["killer_count"] = int(tally[who])
	else:
		f["killer_count"] = 0
	mem["last_died_to"] = who
	var packs := (m.get("packs", []) as Array).size()
	f["pack_new"] = packs > int(mem.get("packs_seen", 0))
	mem["packs_seen"] = packs
	b["stash"] = f
	Story._save(m)


## run_facts then stash, in one call (main.gd's _open_end, before SaveGame.record_run).
static func end_run(run: RunState, by := "", quit := false) -> void:
	if run == null or run.sandbox or run.tutorial:
		return
	stash(run_facts(run, by, quit))


## Walking into the Workshop after a run: the Duck's and LINT's post-mortem, or [] (no run
## stashed, or nothing fits). Clears the stash.
static func hub_return(now: float = 0.0, rng: RandomNumberGenerator = null) -> Array:
	var m := Story._meta()
	var b := _mem_of(m)
	var f: Dictionary = b.get("stash", {})
	if f.is_empty():
		return []
	b.erase("stash")
	Story._save(m)
	return pick(&"hub_return", f, now, rng)


# ---- LINT's arc: the code smells

## LINT reads a wand (the Workshop's LINT, the wand editor closing, a run's first room).
## A smell it flagged earlier that is gone now counts as advice followed (the third unlocks
## its trick, lint_trick()); else it flags the worst smell it hasn't raised yet (with `talk`,
## the worst one at all, or "no smells" for a clean wand). Returns an exchange or [].
static func lint_review(wand: WandState, now: float = 0.0, talk := false, rng: RandomNumberGenerator = null) -> Array:
	var found := Story.smells(wand)
	var kinds: Array = found.map(func(s: Dictionary) -> String: return String(s["smell"]))
	var m := Story._meta()
	var b := _mem_of(m)
	var lint: Dictionary = b.get("lint", {"pending": {}, "fixes": 0, "trick": false})
	# 0.22: smells are remembered per wand, so swapping to a clean wand fixes nothing
	# (a player could farm the trick by flipping between two wands)
	var per: Variant = lint.get("pending", {})
	if not per is Dictionary:
		per = {}
	var key := String(wand.def.id) if wand != null and wand.def != null else ""
	var pending: Array = (per as Dictionary).get(key, [])
	var fixed := pending.filter(func(k: Variant) -> bool: return not kinds.has(String(k)))
	pending = pending.filter(func(k: Variant) -> bool: return kinds.has(String(k)))
	(per as Dictionary)[key] = pending
	lint["pending"] = per
	b["lint"] = lint
	if not fixed.is_empty():
		lint["fixes"] = int(lint.get("fixes", 0)) + fixed.size()
		var unlock := int(lint["fixes"]) >= LINT_TRICK_AT and not bool(lint.get("trick", false))
		if unlock:
			lint["trick"] = true
		Story._save(m)
		return pick(&"lint", {"trick": true} if unlock else {"fixed": true}, now, rng)
	for k in Story.SMELLS:
		if kinds.has(k) and (talk or not pending.has(k)):
			if not pending.has(k):
				pending.append(k)
			Story._save(m)
			return pick(&"lint", {"smell": k}, now, rng)
	Story._save(m)
	if talk and found.is_empty():
		return pick(&"lint", {"clean": true}, now, rng)
	return []


## How many flagged smells you've fixed.
static func lint_fixes() -> int:
	return int((_mem_of(Story._meta()).get("lint", {}) as Dictionary).get("fixes", 0))


## LINT's companion trick is unlocked (research/story.md: Red Squiggle).
static func lint_trick() -> bool:
	return bool((_mem_of(Story._meta()).get("lint", {}) as Dictionary).get("trick", false))


## Every voiced bark (Story.all_lines): [{id, who, text}].
static func all_lines() -> Array:
	var out: Array = []
	for r in RULES:
		for i in (r["lines"] as Array).size():
			for l in entry(r, i):
				out.append({"id": l[2], "who": l[0], "text": l[1]})
	return out
