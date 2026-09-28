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
	# ---- 0.21: Area, summons, Shock, Frost and four rule relics. Colors are Style ramp steps.
	# DEPENDS supers wait for two relics of a tag; RIVALS pairs shut each other out ----
	&"load_spike": {"title": "Crowd Blast", "flavor": "Load Spike", "rar": 1, "color": "#ff9a3a", "glyph": "burst", "tags": ["Area"], "desc": "Blasts grow 6% bigger for each enemy in the room, up to +48%."},
	&"side_effects": {"title": "Blast Share", "flavor": "Side Effects", "rar": 1, "color": "#ff86ad", "glyph": "drop", "tags": ["Area"], "desc": "Enemies caught in one blast share their burn, chill, charge and Bitrot."},
	&"burn_in": {"title": "Scorch Zone", "flavor": "Burn-In", "rar": 1, "color": "#d4501c", "glyph": "burst", "tags": ["Area", "Burn"], "desc": "Blasts scorch the ground for 1.5 s. Enemies standing on it catch fire."},
	&"chain_reaction": {"title": "Aftershock", "flavor": "Chain Reaction", "rar": 2, "color": "#ffd05e", "glyph": "burst", "tags": ["Area"], "desc": "Every blast sets off a second one a moment later, 70% as wide, at half damage."},
	&"inheritance": {"title": "Shared Boosts", "flavor": "Inheritance", "rar": 1, "color": "#a060d8", "glyph": "star", "tags": ["Familiar"], "desc": "Summons deal +15% damage for each boost in the wand that cast them."},
	&"graceful_exit": {"title": "Summon Refund", "flavor": "Graceful Exit", "rar": 0, "color": "#72c24a", "glyph": "coin", "tags": ["Familiar", "Economy"], "desc": "When a summon runs out, its wand gets back half the mana it cost."},
	&"hive_mind": {"title": "Summon Volley", "flavor": "Hive Mind", "rar": 2, "color": "#f2b03e", "glyph": "star", "tags": ["Familiar"], "desc": "When you cast, all your summons fire at once. Up to once a second."},
	&"live_wire": {"title": "Shock Charge", "flavor": "Live Wire", "rar": 1, "color": "#4fd8e8", "glyph": "burst", "tags": ["Shock"], "desc": "Spells that strip wards also charge every enemy they hit."},
	&"overvoltage": {"title": "Charged Strike", "flavor": "Overvoltage", "rar": 0, "color": "#fff2c2", "glyph": "battery", "tags": ["Shock"], "desc": "A hit on a charged enemy deals +40%."},
	&"cold_spill": {"title": "Frost Spread", "flavor": "Cold Spill", "rar": 0, "color": "#86d8ff", "glyph": "drop", "tags": ["Frost"], "desc": "A chilled enemy that dies chills every enemy close by."},
	&"flash_freeze": {"title": "Quick Freeze", "flavor": "Flash Freeze", "rar": 1, "color": "#e6fbff", "glyph": "gem", "tags": ["Frost"], "desc": "2 chills freeze an enemy instead of 3."},
	&"clean_build": {"title": "Clean Streak", "flavor": "Clean Build", "rar": 1, "color": "#c6f07a", "glyph": "loop", "tags": ["Debug"], "desc": "+3% damage for each cast in a row with no Glitch or HP-cost spell, up to +60%. Casting one resets it."},
	&"risky_code": {"title": "Risky Code", "flavor": "Monkey Patch", "rar": 1, "color": "#ff6fd2", "glyph": "skull", "tags": ["Glitch"], "desc": "+12% damage for each Glitch or HP-cost spell in the wand you hold."},
	&"git_clone": {"title": "Relic Copy", "flavor": "git clone", "rar": 1, "color": "#8c96a8", "glyph": "stack", "tags": [], "desc": "Clear 2 rooms and it turns into a second copy of a relic you own that adds damage, slots, HP or gold."},
	&"version_pin": {"title": "Fixed Vitals", "flavor": "Version Pin", "rar": 1, "color": "#ff4d68", "glyph": "heart", "tags": [], "stats": {"dmg": 1.4}, "desc": "+40% damage, but your max HP can never change again."},
	&"code_coverage": {"title": "Wand Variety", "flavor": "Code Coverage", "rar": 1, "color": "#7d9bff", "glyph": "wand", "tags": ["Debug"], "desc": "Each cast from a wand you used less than another this room adds +4% damage, up to +60%, until the room ends."},
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

## 0.21 Dependencies (Nova Drift's super mods): a super relic enters the offers only once the
## run owns what it lists. An entry is a tag (String: any relic with it) or a relic id
## (StringName); each owned relic meets one entry, so ["Area", "Area"] needs two Area relics.
const DEPENDS := {
	&"chain_reaction": ["Area", "Area"],
	&"hive_mind": ["Familiar", "Familiar"],
}
## 0.21 Merge Conflicts (Nova Drift's exclusive mods): taking one relic of a pair keeps the
## other out of every offer for the rest of the run.
const RIVALS := [
	[&"clean_build", &"risky_code"],
]
const CLEAN_STEP := 0.03   # Clean Streak: +3% a clean cast in a row
const CLEAN_MAX := 20      # up to +60%
const COVER_STEP := 0.04   # Wand Variety: +4% a cast from a less-used wand this room
const COVER_MAX := 15      # up to +60%
const HOTFIX_STEP := 0.12  # Risky Code: +12% a Glitch or HP-cost spell in the wand
const CROWD_STEP := 0.06   # Crowd Blast: +6% blast size an enemy in the room
const CROWD_MAX := 8       # up to +48%
const INHERIT_STEP := 0.15 # Shared Boosts: +15% summon damage a boost in its wand
const CLONE_ROOMS := 2     # Relic Copy: rooms cleared before it turns
## Relic Copy may only turn into a relic whose copy adds something (its stats fold twice, or
## its on-gain effect repeats). Corrupted ones never.
const CLONE_SAFE := [&"hot_patch", &"heap_overflow", &"interest", &"off_by_one", &"version_pin"]


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
	# 0.21: Clean Streak, Wand Variety (counted by note_cast) and Risky Code
	if run.has_relic(&"clean_build"):
		k *= 1.0 + CLEAN_STEP * mini(run.clean, CLEAN_MAX)
	if run.has_relic(&"code_coverage"):
		k *= 1.0 + COVER_STEP * mini(run.cover, COVER_MAX)
	if run.has_relic(&"risky_code"):
		k *= 1.0 + HOTFIX_STEP * w.slots.filter(func(s: Variant) -> bool: return s != null and unsafe(s["id"])).size()
	return k


## 0.21: a spell Clean Streak counts as unsafe and Risky Code rewards: tagged Glitch, or one
## that costs HP to cast (a "hp_cost" param or an "hp" keyword on its SpellDef).
static func unsafe(id: StringName) -> bool:
	if Catalog.tags(id).has("Glitch"):
		return true
	var d := Catalog.spell(id)
	return d != null and (d.params.has("hp_cost") or d.keywords.has("hp"))


## 0.21: counts one cast from `w` that used the spells `ids`, before its damage is worked out.
## Clean Streak: a cast with no unsafe spell adds one, one with any resets it (so that cast
## gets nothing). Wand Variety: a cast from a wand with fewer casts this room than another
## wand adds one; the counts reset with the room (new_room).
static func note_cast(run: RunState, w: WandState, ids: Array) -> void:
	if run == null:
		return
	if run.has_relic(&"clean_build"):
		# a wand whose spells cost HP (the Unsafe Staff's "blood" rule) makes every cast unsafe
		var dirty := (w != null and w.def.rule == &"blood") or ids.any(func(id: StringName) -> bool: return unsafe(id))
		run.clean = 0 if dirty else mini(run.clean + 1, CLEAN_MAX)
	if run.has_relic(&"code_coverage"):
		var i := run.wands.find(w)
		if i >= 0:
			var mine := int(run.cover_n.get(i, 0))
			var top := 0
			for k in run.cover_n:
				top = maxi(top, int(run.cover_n[k]))
			if mine < top:
				run.cover = mini(run.cover + 1, COVER_MAX)
			run.cover_n[i] = mine + 1


## 0.21: a new room clears Wand Variety (Clean Streak carries over).
static func new_room(run: RunState) -> void:
	if run == null:
		return
	run.cover = 0
	run.cover_n.clear()


## 0.21 Relic Copy: counts a cleared room. On the second (or the first room after, if nothing
## could be copied yet) it turns into a copy of a CLONE_SAFE relic the run owns and is gone.
## Returns the copied id, or &"".
static func on_room_clear(run: RunState) -> StringName:
	if run == null or not run.has_relic(&"git_clone"):
		return &""
	var n := int(run.stats.get("clone_rooms", 0)) + 1
	run.stats["clone_rooms"] = n
	if n < CLONE_ROOMS:
		return &""
	var pool: Array = CLONE_SAFE.filter(func(id: StringName) -> bool: return run.relics.has(id))
	if pool.is_empty():
		return &""
	var pick: StringName = pool[run.rng.randi() % pool.size()]
	run.relics.erase(&"git_clone")
	run.stats.erase("clone_rooms")
	run.relics.append(pick)   # a second entry: stats fold twice (stat())
	on_gain(run, pick)
	return pick


## Crowd Blast: the blast size multiplier with `alive` enemies up in the room.
static func blast_mul(run: RunState, alive: int) -> float:
	if run == null or not run.has_relic(&"load_spike"):
		return 1.0
	return 1.0 + CROWD_STEP * mini(alive, CROWD_MAX)


## Shared Boosts: the damage multiplier for a summon cast by `w`.
static func summon_mul(run: RunState, w: WandState) -> float:
	if run == null or w == null or not run.has_relic(&"inheritance"):
		return 1.0
	var n := 0
	for s in w.slots:
		if s != null and Catalog.spell(s["id"]).kind == SpellDef.Kind.BOOST:
			n += 1
	return 1.0 + INHERIT_STEP * n



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
	# 0.21: a Merge Conflict's other half is gone for the run; a super waits for its needs
	var rv := rival_of(id)
	if rv != &"" and run.relics.has(rv):
		return false
	if DEPENDS.has(id) and not resolved(run, id):
		return false
	return true


## 0.21 Merge Conflicts: the relic that `id` shuts out (and that shuts it out), or &"".
static func rival_of(id: StringName) -> StringName:
	for pair in RIVALS:
		if pair[0] == id:
			return pair[1]
		if pair[1] == id:
			return pair[0]
	return &""


## 0.21 Dependencies, for the UI's "resolved" chip: one row per entry of DEPENDS[id], as
## {"need": the tag (String) or relic id (StringName), "by": the owned relic that meets it,
## or &""}. Empty for a relic with no dependencies.
static func depends_state(run: RunState, id: StringName) -> Array:
	return _depends(run.relics if run != null else [], id)


## True when the run owns everything DEPENDS lists for `id` (always true for a relic with none).
static func resolved(run: RunState, id: StringName) -> bool:
	return _depends(run.relics if run != null else [], id).all(func(row: Dictionary) -> bool: return row["by"] != &"")


## How many of a super's needs the run meets, and how many it has: [met, total].
static func depends_count(run: RunState, id: StringName) -> Array:
	var rows := depends_state(run, id)
	return [rows.filter(func(row: Dictionary) -> bool: return row["by"] != &"").size(), rows.size()]


## The super relic that taking `id` would resolve (for an "Enables" chip), or &"".
static func completes_super(run: RunState, id: StringName) -> StringName:
	var owned: Array = run.relics.duplicate()
	owned.append(id)
	for k in DEPENDS:
		if k == id or run.relics.has(k) or resolved(run, k):
			continue
		if _depends(owned, k).all(func(row: Dictionary) -> bool: return row["by"] != &""):
			return k
	return &""


## Meets named relics first, then tags, so a named need never loses its relic to a tag.
static func _depends(owned: Array, id: StringName) -> Array:
	var needs: Array = DEPENDS.get(id, [])
	var rows: Array = []
	for need in needs:
		rows.append({"need": need, "by": &""})
	var used: Array = []
	for named in [true, false]:
		for row in rows:
			var need: Variant = row["need"]
			if (typeof(need) == TYPE_STRING_NAME) != named:
				continue
			for r in owned:
				if r == id or used.has(r):
					continue
				if (named and r == need) or (not named and tags(r).has(need)):
					row["by"] = r
					used.append(r)
					break
	return rows


## The duo a relic would complete with what the run owns (for "Enables" chips), or &"".
static func completes_duo(run: RunState, id: StringName) -> StringName:
	for k in DEFS:
		var d: Dictionary = DEFS[k]
		if d.has("duo") and not run.relics.has(k) and (d["duo"] as Array).has(id):
			var other: StringName = d["duo"][0] if d["duo"][1] == id else d["duo"][1]
			if run.relics.has(other):
				return k
	return &""
