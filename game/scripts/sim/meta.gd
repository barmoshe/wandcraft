class_name Meta
extends RefCounted
## Design v2 (R3 + R7): what a new player meets, and goals that open the rest.
##   - The CORE pool is the game a first-time player sees: 26 spells, 24 relics, 6 wands,
##     the Apprentice. Fewer, plainer, each with a job (research/design-v2.md §3).
##   - Everything else stays in the game and comes back through GOALS: short, concrete
##     things to do in a run ("Defeat Copy-Paste", "Clear a room with 2 triggers in your
##     wand"), each opening a named bundle (a hero, spells, relics, a wand). This replaces
##     the D9 Source Fragments shop: the audit found its 366-fragment tax added complexity,
##     not reasons to play. The end screen always names the next goal.
##
## Stored in user://meta.json beside the lifetime numbers ("goals": done ids; "unlocked":
## ids bought with fragments before v2 stay unlocked). Locking applies only in the running
## game (main.gd sets `active`) and in tests that set `test_meta`, never in the balance
## bench unless it asks for the core pool (`core_only`).

const CORE_SPELLS: Array[StringName] = [
	&"mote", &"needle", &"lance", &"fan", &"moths", &"ember", &"frost", &"spark", &"burst",
	&"turret", &"daemon",
	&"empower", &"twin", &"keen", &"seek", &"phase", &"wide", &"ember_coat", &"frost_coat", &"static_coat",
	&"then", &"callback", &"loop", &"seed",
	&"mana_well", &"heatsink",
]
const CORE_RELICS: Array[StringName] = [
	&"hot_patch", &"garbage_collector", &"interest", &"leech_loop", &"buffer_overflow", &"try_catch",
	&"recursion", &"aperture", &"null_pointer", &"cascade_failure", &"wildfire", &"cold_boot",
	&"event_loop", &"off_by_one", &"tail_call", &"loop_counter", &"stack_trace", &"surge_protector",
	&"race_condition", &"memory_leak", &"force_push", &"legacy_code",
	&"thermal_throttle", &"zero_day",
]
const CORE_WANDS: Array[StringName] = [&"twig", &"stub", &"oak", &"crystal", &"harp", &"daemon_rod"]

## In the order the Codex lists them. "check" names what Meta.done() tests (see _met).
const GOALS := [
	{"id": "room", "text": "Clear a room", "check": "rooms>=1",
		"unlocks": [&"chorus", &"ricochet"]},
	{"id": "clean", "text": "Clear a room without getting hit", "check": "clean>=1",
		"unlocks": [&"heavy", &"deadline"]},
	{"id": "mini", "text": "Defeat Copy-Paste", "check": "bosses>=1",
		"unlocks": [&"pyromancer", &"firewall", &"cold_start"]},
	{"id": "triggers", "text": "Clear a room with 2 triggers in your wand", "check": "trigger_rooms>=1",
		"unlocks": [&"finally", &"sleep", &"ping"]},
	{"id": "big_hit", "text": "Deal 60 damage in one hit", "check": "max_hit>=60",
		"unlocks": [&"quicken", &"busy_wait", &"null_orb"]},
	{"id": "rich", "text": "Hold 150 gold", "check": "max_gold>=150",
		"unlocks": [&"siphon", &"low_battery", &"heap_overflow"]},
	{"id": "duo", "text": "Own a Duo relic", "check": "duos>=1",
		"unlocks": [&"bug_bounty", &"swarm_protocol", &"version_control"]},
	{"id": "compile", "text": "Compile a spell at the forge", "check": "compiled>=1",
		"unlocks": [&"hexcursor", &"mine", &"bitrot", &"rot_coat", &"rot_index"]},
	{"id": "boss", "text": "Reach the Infinite Loop", "check": "reached_boss>=1",
		"unlocks": [&"gravity", &"orbit", &"cornered", &"uptime"]},
	{"id": "win", "text": "Win a run", "check": "won>=1",
		"unlocks": [&"tinkerer", &"pipeline", &"fork", &"wheel"]},
	{"id": "runs3", "text": "Play 3 runs", "check": "runs>=3",
		"unlocks": [&"slot", &"disc", &"static", &"duck", &"watchdog", &"mirror", &"split", &"reverse",
			&"empty_set", &"birch", &"fork_branch"]},
	{"id": "heat1", "text": "Win with Bug Reports 1 or higher", "check": "heat_win>=1",
		"unlocks": [&"head", &"ifelse", &"debug_build", &"root_access"]},
	{"id": "heat3", "text": "Win with Bug Reports 3 or higher", "check": "heat_win>=3",
		"unlocks": [&"goto", &"include", &"stack_overflow", &"mirror_rod"]},
]

## Bug Reports (design-plan §6): heat tiers that stack, unlocked one per win (up to five).
const HEAT := [
	"No bug reports",
	"Elite reports: every fight brings an elite",
	"Load spikes: enemies have 20% more HP",
	"Race conditions: enemy shots fly 15% faster",
	"Scope creep: springs heal less, shops charge 25% more",
	"Hotfix denied: bosses have 25% more HP",
]

## Tests: an in-memory meta record used instead of user://meta.json (and locking applies).
static var test_meta: Variant = null
## Set by main.gd when the game runs for real.
static var active := false
## The balance bench: measure the core pool (the game a new player gets).
static var core_only := false
static var _goal_of := {}


## The goal that unlocks an id ({} for core content).
static func goal_for(id: StringName) -> Dictionary:
	if _goal_of.is_empty():
		for g in GOALS:
			for u in g["unlocks"]:
				_goal_of[u] = g
	return _goal_of.get(id, {})


static func is_core(id: StringName) -> bool:
	return goal_for(id).is_empty()


static func enforced() -> bool:
	return core_only or test_meta != null or (active and SaveGame.enabled)


static func _load() -> Dictionary:
	return test_meta if test_meta != null else SaveGame.load_meta()


static func _store(m: Dictionary) -> void:
	if test_meta != null:
		test_meta = m
	else:
		SaveGame.save_meta(m)


static func goals_done() -> Array:
	return [] if core_only else _load().get("goals", [])


## Ids bought with Source Fragments before design v2: they stay unlocked.
static func unlocked() -> Array:
	return [] if core_only else _load().get("unlocked", [])


## True when `id` waits on a goal (and locking applies here).
static func is_locked(id: StringName) -> bool:
	if not enforced() or is_core(id):
		return false
	if unlocked().has(String(id)):
		return false
	return not goals_done().has(goal_for(id)["id"])


## The next goals to show (not done yet), in Codex order.
static func open_goals() -> Array:
	var done := goals_done()
	return GOALS.filter(func(g: Dictionary) -> bool: return not done.has(g["id"]))


## Checks every goal against this run (and the lifetime record), stores the new ones, and
## returns them. Called at each room clear and when a run ends.
static func check(run: RunState) -> Array:
	var m := _load()
	var done: Array = m.get("goals", [])
	var got: Array = []
	for g in GOALS:
		if done.has(g["id"]):
			continue
		if _met(String(g["check"]), run, m):
			done.append(g["id"])
			got.append(g)
	if not got.is_empty():
		m["goals"] = done
		_store(m)
	return got


static func _met(check: String, run: RunState, m: Dictionary) -> bool:
	var parts := check.split(">=")
	var need := float(parts[1])
	var st := run.stats
	var v := 0.0
	match parts[0]:
		"rooms": v = float(st.get("rooms", 0))
		"clean": v = float(st.get("clean", 0))
		"bosses": v = float(st.get("bosses", 0))
		"trigger_rooms": v = float(st.get("trigger_rooms", 0))
		"max_hit": v = float(st.get("max_hit", 0.0))
		"max_gold": v = float(maxi(run.gold, int(st.get("max_gold", 0))))
		"duos": v = float(run.relics.filter(func(r: StringName) -> bool: return Relics.DEFS.get(r, {}).has("duo")).size())
		"compiled": v = float(st.get("compiled", 0))
		"reached_boss": v = 1.0 if run.step >= Chapter.PLAN.size() - 1 else 0.0
		"won": v = 1.0 if run.won else 0.0
		"runs": v = float(m.get("runs", 0))
		"heat_win": v = float(run.heat) if run.won else -1.0
	return v >= need


## The one stat unlock: an extra empty slot on the starting wand.
static func extra_slots() -> int:
	return 0 if not enforced() or is_locked(&"slot") or core_only else 1


## Display name of an unlockable id.
static func title(id: StringName) -> String:
	if RunState.LOADOUTS.has(id):
		return "%s (hero)" % RunState.LOADOUTS[id]["title"]
	if id == &"slot":
		return "+1 starting slot"
	if Catalog.spells().has(id):
		return Catalog.spell(id).title
	if Relics.DEFS.has(id):
		return String(Relics.DEFS[id]["title"])
	if Catalog.wands().has(id):
		return Catalog.wand(id).title
	return String(id)
