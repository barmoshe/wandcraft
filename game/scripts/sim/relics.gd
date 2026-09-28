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
## Design v3: titles say what a relic does; the old programmer joke survives as "flavor"
## (the Codex and the pause panel show it).

const DEFS := {
	# ---- kept from the POC ----
	&"hot_patch": {"title": "Vital Patch", "flavor": "Hot Patch", "rar": 0, "color": "#ff6b7a", "glyph": "heart", "tags": ["Survival"], "desc": "Max HP +20, and heal 20 now."},
	&"garbage_collector": {"title": "Mana Scavenger", "flavor": "Garbage Collector", "rar": 0, "color": "#7dd8ff", "glyph": "bin", "tags": ["Economy"], "desc": "Every kill refills 3 mana in all your wands."},
	&"interest": {"title": "Compound Interest", "rar": 0, "color": "#ffd36b", "glyph": "coin", "tags": ["Economy"], "stats": {"gold": 1.25}, "desc": "+25% gold. Entering a room with 60 gold or more gives 3 extra."},
	&"leech_loop": {"title": "Leech Charm", "rar": 0, "color": "#d8344a", "glyph": "loop", "tags": ["Survival"], "desc": "Every 6th kill heals 4 HP."},
	&"busy_wait": {"title": "Steady Aim", "flavor": "Busy Wait", "rar": 0, "color": "#ffe066", "glyph": "clock", "tags": [], "desc": "Stand still for 0.6 s and your next cast deals +60% damage."},
	&"buffer_overflow": {"title": "Overheal Shield", "flavor": "Buffer Overflow", "rar": 0, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "Healing above your max HP becomes a shield (up to 30) that takes hits first."},
	&"heap_overflow": {"title": "Glass Cannon", "flavor": "Heap Overflow", "rar": 1, "color": "#ff5a8a", "glyph": "stack", "tags": [], "stats": {"dmg": 1.3}, "desc": "+30% damage, but max HP -20."},
	&"try_catch": {"title": "First-Hit Ward", "flavor": "Try / Catch", "rar": 1, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "The first hit you take in each room does no damage."},
	&"recursion": {"title": "Trigger Charm", "flavor": "Recursion Charm", "rar": 1, "color": "#ffe066", "glyph": "spiral", "tags": ["Trigger", "Carrier"], "desc": "Spells released by triggers deal +30% damage."},
	&"aperture": {"title": "Extra Bolt", "flavor": "Wide Aperture", "rar": 1, "color": "#ffb86b", "glyph": "fan", "tags": ["Multi"], "desc": "Spells that fire several bolts fire one more."},
	&"null_pointer": {"title": "First Strike", "flavor": "Null Pointer", "rar": 1, "color": "#ff3fa4", "glyph": "cursor", "tags": ["Crit"], "desc": "The first hit on an unhurt enemy deals double damage."},
	&"deadline": {"title": "Opening Rush", "flavor": "Deadline", "rar": 1, "color": "#ff7b7b", "glyph": "clock", "tags": [], "desc": "+40% damage for the first 6 s of every fight."},
	&"stack_trace": {"title": "Back Shot", "flavor": "Stack Trace", "rar": 1, "color": "#c9a8ff", "glyph": "stack", "tags": ["Glitch", "Multi"], "counter": 7, "desc": "Every 7th cast also fires backward."},
	&"bug_bounty": {"title": "Bug Bounty", "rar": 1, "color": "#9cd01c", "glyph": "star", "tags": ["Carrier"], "desc": "Kills release a small bug that hunts the nearest enemy for 10 damage."},
	&"cascade_failure": {"title": "Crit Arc", "flavor": "Cascade Failure", "rar": 1, "color": "#fff27a", "glyph": "burst", "tags": ["Crit"], "desc": "Crits arc to a nearby enemy for half damage."},
	&"wildfire": {"title": "Wildfire", "rar": 1, "color": "#ff8a3c", "glyph": "burst", "tags": ["Burn"], "desc": "When a burning enemy dies, its fire spreads to enemies close by."},
	&"cold_boot": {"title": "Frostbite", "flavor": "Cold Boot", "rar": 1, "color": "#9fe8ff", "glyph": "drop", "tags": ["Frost"], "desc": "Chilled enemies take +25% damage."},
	&"event_loop": {"title": "Echo Chamber", "rar": 2, "color": "#ffd05e", "glyph": "loop", "tags": ["Trigger", "Carrier"], "desc": "Triggers release their spell twice. The second one deals 60%."},
	# ---- conditional ----
	&"cold_start": {"title": "Fresh Charge", "flavor": "Cold Start", "rar": 0, "color": "#86d8ff", "glyph": "clock", "tags": [], "desc": "The first cast after a wand recharges deals +50% damage."},
	&"low_battery": {"title": "Last Reserves", "flavor": "Low Battery", "rar": 0, "color": "#ff9a3a", "glyph": "battery", "tags": ["Economy"], "desc": "While a wand is under 25% mana, its spells deal +40% damage."},
	&"cornered": {"title": "Cornered", "rar": 1, "color": "#d0101e", "glyph": "shield", "tags": ["Survival"], "desc": "With 3 or more enemies close by, take 30% less damage and deal 25% more."},
	# ---- scaling ----
	&"uptime": {"title": "Untouched Streak", "flavor": "Uptime", "rar": 1, "color": "#72e06a", "glyph": "clock", "tags": [], "desc": "+3% damage for each room in a row cleared without getting hit (up to +30%)."},
	&"version_control": {"title": "Merge Heart", "flavor": "Version Control", "rar": 0, "color": "#8c96a8", "glyph": "stack", "tags": ["Survival"], "desc": "Whenever spells merge to a higher level: max HP +8, and heal 8."},
	# ---- rule-breakers ----
	&"root_access": {"title": "Free Runes", "flavor": "Root Access", "rar": 1, "color": "#5ce1ff", "glyph": "cursor", "tags": ["Debug"], "stats": {"rune": 0.0}, "desc": "Runes cost no mana."},
	&"stack_overflow": {"title": "Deep Chains", "flavor": "Stack Overflow", "rar": 2, "color": "#c2359f", "glyph": "stack", "tags": ["Trigger", "Carrier"], "stats": {"depth": 5}, "desc": "Triggers can chain 5 deep instead of 3."},
	# ---- program-aware ----
	&"off_by_one": {"title": "Extra Slot", "flavor": "Off-by-One", "rar": 1, "color": "#ffd05e", "glyph": "box", "tags": [], "stats": {"slots": 1}, "desc": "Every wand gets one more slot."},
	&"tail_call": {"title": "Parting Shot", "flavor": "Tail Call", "rar": 2, "color": "#c9a8ff", "glyph": "gem", "tags": ["Multi"], "desc": "The last cast before a wand recharges fires twice."},
	&"loop_counter": {"title": "Tally Charm", "rar": 1, "color": "#ffe066", "glyph": "loop", "tags": ["Economy"], "counter": 10, "desc": "Every 10th cast is free and deals double damage."},
	&"empty_set": {"title": "Empty Hands", "flavor": "Empty Set", "rar": 0, "color": "#d6d6ff", "glyph": "box", "tags": [], "desc": "+8% damage for each empty slot on the wand in your hand."},
	# ---- status ----
	&"surge_protector": {"title": "Surge Coil", "flavor": "Surge Protector", "rar": 1, "color": "#fff27a", "glyph": "burst", "tags": ["Shock"], "desc": "Static arcs hit two enemies instead of one, at full damage."},
	&"rot_index": {"title": "Quick Rot", "flavor": "Rot Index", "rar": 1, "color": "#ff6fd2", "glyph": "skull", "tags": ["Rot"], "desc": "Bitrot crashes an enemy at 3 stacks instead of 5."},
	# ---- Merge Commit duos: offered only when you own both parents ----
	&"thermal_throttle": {"title": "Steam Burst", "flavor": "Thermal Throttle", "rar": 2, "color": "#ff9a3a", "glyph": "burst", "tags": ["Burn", "Frost"], "duo": [&"wildfire", &"cold_boot"], "desc": "Thermal Shock (fire meeting ice on an enemy) hits twice as hard, reaches twice as far, and sets enemies on fire."},
	&"zero_day": {"title": "Sure Strike", "flavor": "Zero-Day Exploit", "rar": 2, "color": "#ff3fa4", "glyph": "cursor", "tags": ["Crit"], "duo": [&"null_pointer", &"cascade_failure"], "desc": "The first hit on an unhurt enemy is always a crit."},
	&"swarm_protocol": {"title": "Bug Swarm", "flavor": "Swarm Protocol", "rar": 2, "color": "#9cd01c", "glyph": "star", "tags": ["Carrier"], "duo": [&"bug_bounty", &"event_loop"], "desc": "Kills release two bugs, and each bug deals 20."},
	# ---- 0.19 spell packs (Catalog.PACK_ITEMS) ----
	&"keep_alive": {"title": "Target Lock", "flavor": "Keep-Alive", "rar": 1, "color": "#7cf0c8", "glyph": "eye", "tags": ["Glitch", "Trigger"], "desc": "Marked enemies take 30% more damage, and marks last twice as long."},
	&"thread_pool": {"title": "Thread Pool", "rar": 1, "color": "#ffb86b", "glyph": "chip", "tags": ["Familiar"], "desc": "You can have one more of each summon out at once."},
	&"last_good_commit": {"title": "Checkpoint", "flavor": "Last Good Commit", "rar": 2, "color": "#9cf06a", "glyph": "stack", "tags": ["Survival"], "desc": "Once per run, a hit that would kill you puts you back at the HP you entered the room with."},
	&"liquid_cooling": {"title": "Shot Recycler", "flavor": "Liquid Cooling", "rar": 1, "color": "#8ff0ff", "glyph": "drop", "tags": ["Economy"], "desc": "Each enemy shot your spells stop refills 2 mana in the wand in your hand."},
	# ---- 0.20 (research/arsenal-0.20/7-relics.md). "from": 2 keeps a Kernel-only relic out
	# of offers before World 3 (run.world 2), where its enemy first shows up ----
	&"graceful_degrade": {"title": "Locked Fury", "flavor": "Graceful Degradation", "rar": 1, "color": "#b98cff", "glyph": "burst", "tags": ["Glitch"], "from": 2, "desc": "While an Interrupt holds a slot, your other spells deal +40%."},
	&"swap_space": {"title": "Puddle Skater", "flavor": "Swap Space", "rar": 0, "color": "#8ff0c8", "glyph": "drop", "tags": ["Economy"], "from": 2, "desc": "Leak puddles speed you up instead, and refill mana while you stand in them."},
	&"thread_join": {"title": "Finisher", "flavor": "join()", "rar": 1, "color": "#ff5a6e", "glyph": "skull", "tags": ["Crit"], "desc": "Kills also finish nearby enemies under 15% HP."},
	&"undo_stack": {"title": "Take-Back", "flavor": "Undo Stack", "rar": 1, "color": "#9cf06a", "glyph": "loop", "tags": ["Survival"], "desc": "After a hit, avoid another for 3 s and that hit is undone. Once a room."},
	&"warm_cache": {"title": "Warm-Up", "flavor": "Cache Warmup", "rar": 0, "color": "#ffb86b", "glyph": "chip", "tags": [], "desc": "Each cast adds +2% damage this room, up to +40%. A hit clears it."},
	&"hoisting": {"title": "Tail Boost", "flavor": "Hoisting", "rar": 1, "color": "#5ce1ff", "glyph": "arrow", "tags": ["Debug"], "desc": "A boost in a wand's last slot affects every spell in the wand."},
	&"polyglot": {"title": "Mixed Program", "flavor": "Polyglot", "rar": 0, "color": "#d6a8ff", "glyph": "star", "tags": [], "desc": "+6% damage for each spell kind in the wand you hold."},
	&"short_circuit": {"title": "Short Wand", "flavor": "Short-Circuit", "rar": 0, "color": "#fff27a", "glyph": "battery", "tags": [], "desc": "A wand with 3 slots or fewer recharges 40% faster."},
	&"end_of_life": {"title": "Buyback", "flavor": "End of Life", "rar": 0, "color": "#ffd36b", "glyph": "bin", "tags": ["Economy"], "desc": "Banning a spell at a shop pays 15 gold, and you can ban two per visit."},
	&"lazy_eval": {"title": "Refund Misses", "flavor": "Lazy Evaluation", "rar": 1, "color": "#7dd8ff", "glyph": "cursor", "tags": ["Economy"], "desc": "A shot that hits nothing refunds its mana to its wand."},
	&"context_switch": {"title": "Swap Dodge", "flavor": "Context Switch", "rar": 0, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "Switching wands makes you untouchable for 0.4 s, every 4 s."},
	&"cold_storage": {"title": "Bit Savings", "flavor": "Cold Storage", "rar": 0, "color": "#9fe8ff", "glyph": "coin", "tags": ["Economy"], "desc": "When the run ends, every 40 gold you hold pays 1 Bit (up to 10)."},
	&"shared_memory": {"title": "Contagion", "flavor": "Shared Memory", "rar": 1, "color": "#c2359f", "glyph": "drop", "tags": ["Glitch"], "desc": "An enemy dying with two or more statuses passes them to the nearest enemy."},
	&"cron_job": {"title": "Double Tick", "flavor": "Cron Job", "rar": 2, "color": "#ffe066", "glyph": "clock", "tags": ["Multi", "Economy"], "duo": [&"stack_trace", &"loop_counter"], "desc": "Back Shot and Tally Charm count every cast twice."},
	&"superconductor": {"title": "Cold Current", "flavor": "Superconductor", "rar": 2, "color": "#9fe8ff", "glyph": "burst", "tags": ["Shock", "Frost"], "duo": [&"surge_protector", &"cold_boot"], "desc": "Static arcs chill what they hit and jump to one more enemy."},
	# ---- Corrupted: only behind the Glitch Door ----
	&"race_condition": {"title": "Race Condition", "rar": 3, "color": "#ff6fd2", "glyph": "clock", "tags": [], "stats": {"cast": 0.6}, "desc": "Wands cast and recharge 40% faster, but 1 cast in 5 fizzles."},
	&"memory_leak": {"title": "Memory Leak", "rar": 3, "color": "#ff6fd2", "glyph": "drop", "tags": [], "stats": {"dmg": 1.5}, "desc": "+50% damage, but you lose 1 HP every 10 s during a fight."},
	&"force_push": {"title": "Force Push", "rar": 3, "color": "#ff6fd2", "glyph": "arrow", "tags": [], "stats": {"dmg": 1.25, "knock": 3.0, "move": 0.85}, "desc": "+25% damage and a big knockback, but you move 15% slower."},
	&"legacy_code": {"title": "Legacy Code", "rar": 3, "color": "#ff6fd2", "glyph": "chest", "tags": [], "desc": "The spell in the wand's last slot deals 2.5x damage. Every other slot deals 20% less."},
	&"technical_debt": {"title": "Technical Debt", "rar": 3, "color": "#ff6fd2", "glyph": "box", "tags": [], "stats": {"slots": 2, "recharge": 1.5}, "desc": "Every wand gets 2 more slots, but recharges take 50% longer."},
}

## Relics cut in D3 (flat stat bumps and duplicates). Old saves drop them.
const CUT := [&"blast_radius", &"bounce_core", &"hotkey_boots", &"lucky_bit", &"spare_battery", &"echo",
	&"iron_stack", &"afterimage", &"overclock", &"sandbox"]

const RARITY_NAMES := ["Common", "Rare", "Epic", "Corrupted"]
const RARITY_COLORS := ["#c8c8d8", "#5ca8ff", "#c46bff", "#ff6fd2"]
## How stats from several relics combine: multiply, add, or take the largest.
const STAT_MUL := ["dmg", "gold", "cast", "knock", "move", "rune", "taken", "regen", "recharge"]
const STAT_ADD := ["slots"]
const STAT_MAX := ["depth"]
const WARM_MAX := 20   # Warm-Up (0.20): +2% a cast, up to +40%


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
		&"technical_debt":
			for w in run.wands:
				w.add_slot()
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
	var k := stat(run, "dmg") * (1.3 if run and run.daily_mod == &"glass" else 1.0)
	if run.has_relic(&"deadline") and room_time < 6.0:
		k *= 1.4
	if run.has_relic(&"uptime"):
		k *= 1.0 + 0.03 * run.uptime
	return k


## 0.20: the per-cast multiplier from relics that read the wand or the room: Locked Fury
## (an Interrupt holds a slot), Mixed Program (spell kinds in the wand) and Warm-Up
## (`warm`: casts this room since the last hit).
static func shape_mul(run: RunState, w: WandState, warm: int) -> float:
	var k := 1.0
	if run.has_relic(&"graceful_degrade") and run.wands.any(func(x: WandState) -> bool: return x.suspended >= 0):
		k *= 1.4
	if run.has_relic(&"polyglot"):
		k *= 1.0 + 0.06 * kinds(w)
	if run.has_relic(&"warm_cache"):
		k *= 1.0 + 0.02 * mini(warm, WARM_MAX)
	return k



## Mixed Program: how many spell kinds (shot, boost, trigger, passive, rune, summon) the
## wand holds.
static func kinds(w: WandState) -> int:
	var seen := {}
	for s in w.slots:
		if s != null:
			seen[Catalog.spell(s["id"]).kind] = true
	return seen.size()


## 0.20: the recharge multiplier: Technical Debt's longer recharges, Short Wand's faster
## ones on a wand of 3 slots or fewer.
static func recharge_mul(run: RunState, w: WandState) -> float:
	if run == null:
		return 1.0
	var k := stat(run, "recharge")
	if run.has_relic(&"short_circuit") and w.slots.size() <= 3:
		k *= 0.6
	return k


## Double Tick (0.20): with Cron Job, Back Shot and Tally Charm count each cast twice.
static func cast_tick(run: RunState) -> int:
	return 2 if run != null and run.has_relic(&"cron_job") else 1


## True when a counter going from `before` to `after` passes a multiple of `every`.
static func crosses(before: int, after: int, every: int) -> bool:
	return floori(after / float(every)) > floori(before / float(every))


static func damage_taken_mul(run: RunState) -> float:
	return stat(run, "taken")


static func mana_regen_mul(run: RunState) -> float:
	return stat(run, "regen")


static func tags(id: StringName) -> Array:
	return DEFS[id].get("tags", []) if DEFS.has(id) else []


static func gold_mul(run: RunState) -> float:
	# heat pays (research/magicraft-progression.md, lesson 2): +10% gold a tier
	return stat(run, "gold") * (1.0 + 0.1 * run.heat)


## True when the run may be offered this relic: not owned, not Corrupted (those only come
## from the Glitch Door), and a Merge Commit only once both parents are owned.
static func offerable(run: RunState, id: StringName, corrupted := false) -> bool:
	if run.relics.has(id):
		return false
	var d: Dictionary = DEFS[id]
	if (int(d["rar"]) == 3) != corrupted:
		return false
	if int(d.get("from", 0)) > run.world:
		return false   # 0.20: a Kernel-only relic waits for the world whose enemy it answers
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
