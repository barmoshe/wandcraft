class_name Relics
extends RefCounted
## Original relics (decisions/0002), themed on software and the Glitch. D3 (ADR 0014):
## flat stat bumps were cut; what stays is conditional, scaling, rule-breaking,
## program-aware or status-driven. Two layers:
##   stats  plain numbers in each def ("stats"), folded into one table per run (stat())
##   hooks  behaviour checked where it happens (run.has_relic at the event site)
## "rar": 0 common, 1 rare, 2 epic, 3 Corrupted (only from the Glitch Door: an upside with a
## real downside). "duo": [a, b] marks a Merge Commit, offered only when you own both.
## Descriptions stay short and concrete: players on phones read them in a glance.

const DEFS := {
	# ---- kept from the POC ----
	&"hot_patch": {"title": "Hot Patch", "rar": 0, "color": "#ff6b7a", "glyph": "heart", "tags": ["Survival"], "desc": "Max HP +20, and heal 20 now."},
	&"garbage_collector": {"title": "Garbage Collector", "rar": 0, "color": "#7dd8ff", "glyph": "bin", "tags": ["Economy"], "desc": "Every kill refills 3 mana in all your wands."},
	&"interest": {"title": "Compound Interest", "rar": 0, "color": "#ffd36b", "glyph": "coin", "tags": ["Economy"], "stats": {"gold": 1.25}, "desc": "+25% gold. Entering a room with 60 gold or more gives 3 extra."},
	&"leech_loop": {"title": "Leech Loop", "rar": 0, "color": "#d8344a", "glyph": "loop", "tags": ["Survival"], "desc": "Every 6th kill heals 4 HP."},
	&"busy_wait": {"title": "Busy Wait", "rar": 0, "color": "#ffe066", "glyph": "clock", "tags": [], "desc": "Stand still for 0.6 s and your next cast deals +60% damage."},
	&"buffer_overflow": {"title": "Buffer Overflow", "rar": 0, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "Healing above your max HP becomes a shield (up to 30) that takes hits first."},
	&"heap_overflow": {"title": "Heap Overflow", "rar": 1, "color": "#ff5a8a", "glyph": "stack", "tags": [], "stats": {"dmg": 1.3}, "desc": "+30% damage, but max HP -20."},
	&"try_catch": {"title": "Try / Catch", "rar": 1, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "The first hit you take in each room does no damage."},
	&"recursion": {"title": "Recursion Charm", "rar": 1, "color": "#ffe066", "glyph": "spiral", "tags": ["Trigger", "Carrier"], "desc": "Spells released by triggers and carriers deal +30% damage."},
	&"aperture": {"title": "Wide Aperture", "rar": 1, "color": "#ffb86b", "glyph": "fan", "tags": ["Multi"], "desc": "Spells that fire several bolts fire one more."},
	&"null_pointer": {"title": "Null Pointer", "rar": 1, "color": "#ff3fa4", "glyph": "cursor", "tags": ["Crit"], "desc": "The first hit on an unhurt enemy deals double damage."},
	&"deadline": {"title": "Deadline", "rar": 1, "color": "#ff7b7b", "glyph": "clock", "tags": [], "desc": "+40% damage for the first 6 s of every fight."},
	&"stack_trace": {"title": "Stack Trace", "rar": 1, "color": "#c9a8ff", "glyph": "stack", "tags": ["Glitch", "Multi"], "counter": 7, "desc": "Every 7th cast also fires backward."},
	&"bug_bounty": {"title": "Bug Bounty", "rar": 1, "color": "#9cd01c", "glyph": "star", "tags": ["Carrier"], "desc": "Kills release a small bug that hunts the nearest enemy for 10 damage."},
	&"cascade_failure": {"title": "Cascade Failure", "rar": 1, "color": "#fff27a", "glyph": "burst", "tags": ["Crit"], "desc": "Crits arc to a nearby enemy for half damage."},
	&"wildfire": {"title": "Wildfire", "rar": 1, "color": "#ff8a3c", "glyph": "burst", "tags": ["Burn"], "desc": "When a burning enemy dies, its fire spreads to enemies close by."},
	&"cold_boot": {"title": "Cold Boot", "rar": 1, "color": "#9fe8ff", "glyph": "drop", "tags": ["Frost"], "desc": "Chilled enemies take +25% damage."},
	&"event_loop": {"title": "Event Loop", "rar": 2, "color": "#ffd05e", "glyph": "loop", "tags": ["Trigger", "Carrier"], "desc": "Triggers and carriers release their spell twice. The second one deals 60%."},
	# ---- conditional ----
	&"cold_start": {"title": "Cold Start", "rar": 0, "color": "#86d8ff", "glyph": "clock", "tags": [], "desc": "The first cast after a wand recharges deals +50% damage."},
	&"low_battery": {"title": "Low Battery", "rar": 0, "color": "#ff9a3a", "glyph": "battery", "tags": ["Economy"], "desc": "While a wand is under 25% mana, its spells deal +40% damage."},
	&"cornered": {"title": "Cornered", "rar": 1, "color": "#d0101e", "glyph": "shield", "tags": ["Survival"], "desc": "With 3 or more enemies close by, take 30% less damage and deal 25% more."},
	# ---- scaling ----
	&"uptime": {"title": "Uptime", "rar": 1, "color": "#72e06a", "glyph": "clock", "tags": [], "desc": "+3% damage for each room in a row cleared without getting hit (up to +30%)."},
	&"version_control": {"title": "Version Control", "rar": 0, "color": "#8c96a8", "glyph": "stack", "tags": ["Survival"], "desc": "Whenever spells merge to a higher level: max HP +8, and heal 8."},
	# ---- rule-breakers ----
	&"root_access": {"title": "Root Access", "rar": 1, "color": "#5ce1ff", "glyph": "cursor", "tags": ["Debug"], "stats": {"rune": 0.0}, "desc": "Debugger runes cost no mana."},
	&"stack_overflow": {"title": "Stack Overflow", "rar": 2, "color": "#c2359f", "glyph": "stack", "tags": ["Trigger", "Carrier"], "stats": {"depth": 5}, "desc": "Carriers and triggers can chain 5 deep instead of 3."},
	# ---- program-aware ----
	&"off_by_one": {"title": "Off-by-One", "rar": 1, "color": "#ffd05e", "glyph": "box", "tags": [], "stats": {"slots": 1}, "desc": "Every wand gets one more slot."},
	&"tail_call": {"title": "Tail Call", "rar": 2, "color": "#c9a8ff", "glyph": "gem", "tags": ["Multi"], "desc": "The last cast before a wand recharges fires twice."},
	&"loop_counter": {"title": "Loop Counter", "rar": 1, "color": "#ffe066", "glyph": "loop", "tags": ["Economy"], "counter": 10, "desc": "Every 10th cast is free and deals double damage."},
	&"empty_set": {"title": "Empty Set", "rar": 0, "color": "#d6d6ff", "glyph": "box", "tags": [], "desc": "+8% damage for each empty slot on the wand in your hand."},
	# ---- status ----
	&"surge_protector": {"title": "Surge Protector", "rar": 1, "color": "#fff27a", "glyph": "burst", "tags": ["Shock"], "desc": "Static arcs hit two enemies instead of one, at full damage."},
	&"rot_index": {"title": "Rot Index", "rar": 1, "color": "#ff6fd2", "glyph": "skull", "tags": ["Rot"], "desc": "Bitrot crashes an enemy at 3 stacks instead of 5."},
	# ---- Merge Commit duos: offered only when you own both parents ----
	&"thermal_throttle": {"title": "Thermal Throttle", "rar": 2, "color": "#ff9a3a", "glyph": "burst", "tags": ["Burn", "Frost"], "duo": [&"wildfire", &"cold_boot"], "desc": "Thermal Shock (fire meeting ice on an enemy) hits twice as hard, reaches twice as far, and sets enemies on fire."},
	&"zero_day": {"title": "Zero-Day Exploit", "rar": 2, "color": "#ff3fa4", "glyph": "cursor", "tags": ["Crit"], "duo": [&"null_pointer", &"cascade_failure"], "desc": "The first hit on an unhurt enemy is always a crit."},
	&"swarm_protocol": {"title": "Swarm Protocol", "rar": 2, "color": "#9cd01c", "glyph": "star", "tags": ["Carrier"], "duo": [&"bug_bounty", &"event_loop"], "desc": "Kills release two bugs, and each bug deals 20."},
	# ---- Corrupted: only behind the Glitch Door ----
	&"race_condition": {"title": "Race Condition", "rar": 3, "color": "#ff6fd2", "glyph": "clock", "tags": [], "stats": {"cast": 0.6}, "desc": "Wands cast and recharge 40% faster, but 1 cast in 5 fizzles."},
	&"memory_leak": {"title": "Memory Leak", "rar": 3, "color": "#ff6fd2", "glyph": "drop", "tags": [], "stats": {"dmg": 1.5}, "desc": "+50% damage, but you lose 1 HP every 10 s during a fight."},
	&"force_push": {"title": "Force Push", "rar": 3, "color": "#ff6fd2", "glyph": "arrow", "tags": [], "stats": {"dmg": 1.25, "knock": 3.0, "move": 0.85}, "desc": "+25% damage and a big knockback, but you move 15% slower."},
	&"legacy_code": {"title": "Legacy Code", "rar": 3, "color": "#ff6fd2", "glyph": "chest", "tags": [], "desc": "The spell in slot 1 deals 2.5x damage. Every other slot deals 20% less."},
}

## Relics cut in D3 (flat stat bumps and duplicates). Old saves drop them.
const CUT := [&"blast_radius", &"bounce_core", &"hotkey_boots", &"lucky_bit", &"spare_battery", &"echo",
	&"iron_stack", &"afterimage", &"overclock", &"sandbox"]

const RARITY_NAMES := ["Common", "Rare", "Epic", "Corrupted"]
const RARITY_COLORS := ["#c8c8d8", "#5ca8ff", "#c46bff", "#ff6fd2"]
## How stats from several relics combine: multiply, add, or take the largest.
const STAT_MUL := ["dmg", "gold", "cast", "knock", "move", "rune", "taken", "regen"]
const STAT_ADD := ["slots"]
const STAT_MAX := ["depth"]


static func def(id: StringName) -> Dictionary:
	return DEFS[id]


static func on_gain(run: RunState, id: StringName) -> void:
	match id:
		&"hot_patch":
			run.max_hp += 20.0
			run.hp = minf(run.max_hp, run.hp + 20.0)
		&"heap_overflow":
			run.max_hp = maxf(20.0, run.max_hp - 20.0)
			run.hp = minf(run.hp, run.max_hp)
		&"off_by_one":
			for w in run.wands:
				w.add_slot()
	run.apply_relics()


## One stat folded over every relic the run holds (1.0 / 0 / 3 when none changes it).
## Multiplied stats stack by multiplying, so two damage-taken cuts never reach zero.
static func stat(run: RunState, key: String) -> float:
	if run == null:
		return 0.0 if key in STAT_ADD else (3.0 if key == "depth" else 1.0)
	var v := 0.0 if key in STAT_ADD else (3.0 if key == "depth" else 1.0)
	for id in run.relics:
		var st: Dictionary = DEFS.get(id, {}).get("stats", {})
		if not st.has(key):
			continue
		if key in STAT_ADD:
			v += float(st[key])
		elif key in STAT_MAX:
			v = maxf(v, float(st[key]))
		else:
			v *= float(st[key])
	return v


## Global damage multiplier for casts from the player's wands (the always-on part; the
## per-cast conditions live in SpellRunner.wand_fire).
static func dmg_mul(run: RunState, room_time: float) -> float:
	var k := stat(run, "dmg")
	if run.has_relic(&"deadline") and room_time < 6.0:
		k *= 1.4
	if run.has_relic(&"uptime"):
		k *= 1.0 + 0.03 * run.uptime
	return k


static func damage_taken_mul(run: RunState) -> float:
	return stat(run, "taken")


static func mana_regen_mul(run: RunState) -> float:
	return stat(run, "regen")


static func tags(id: StringName) -> Array:
	return DEFS[id].get("tags", []) if DEFS.has(id) else []


static func gold_mul(run: RunState) -> float:
	return stat(run, "gold")


## True when the run may be offered this relic: not owned, not Corrupted (those only come
## from the Glitch Door), and a Merge Commit only once both parents are owned.
static func offerable(run: RunState, id: StringName, corrupted := false) -> bool:
	if run.relics.has(id):
		return false
	var d: Dictionary = DEFS[id]
	if (int(d["rar"]) == 3) != corrupted:
		return false
	if d.has("duo"):
		for p in d["duo"]:
			if not run.relics.has(p):
				return false
	return true


## The duo a relic would complete with what the run owns (for "Enables" chips), or &"".
static func completes_duo(run: RunState, id: StringName) -> StringName:
	for k in DEFS:
		var d: Dictionary = DEFS[k]
		if d.has("duo") and not run.relics.has(k) and (d["duo"] as Array).has(id):
			var other: StringName = d["duo"][0] if d["duo"][1] == id else d["duo"][1]
			if run.relics.has(other):
				return k
	return &""
