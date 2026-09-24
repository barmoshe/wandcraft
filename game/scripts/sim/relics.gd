class_name Relics
extends RefCounted
## Original relics (decisions/0002), themed on software and the Glitch. Most are checked
## where they matter (run.has_relic); on_gain handles the instant ones. Descriptions stay
## short and concrete: players on phones read them in a glance.

const DEFS := {
	&"hot_patch": {"title": "Hot Patch", "rar": 0, "color": "#ff6b7a", "glyph": "heart", "tags": ["Survival"], "desc": "Max HP +20, and heal 20."},
	&"garbage_collector": {"title": "Garbage Collector", "rar": 0, "color": "#7dd8ff", "glyph": "bin", "tags": ["Economy"], "desc": "Every kill refills 3 mana in all your wands."},
	&"lucky_bit": {"title": "Lucky Bit", "rar": 0, "color": "#7dff9a", "glyph": "clover", "tags": ["Crit"], "desc": "+10% critical hit chance on every spell."},
	&"iron_stack": {"title": "Iron Stack", "rar": 0, "color": "#b8c0cc", "glyph": "stack", "tags": ["Survival"], "desc": "Take 15% less damage."},
	&"spare_battery": {"title": "Spare Battery", "rar": 0, "color": "#5ce1ff", "glyph": "battery", "tags": ["Economy"], "desc": "Wands hold 30% more mana and regenerate 20% faster."},
	&"hotkey_boots": {"title": "Hotkey Boots", "rar": 0, "color": "#9ad06a", "glyph": "boot", "tags": ["Survival"], "desc": "Move 15% faster."},
	&"blast_radius": {"title": "Blast Radius", "rar": 0, "color": "#ff8a3c", "glyph": "burst", "tags": ["Area"], "desc": "Explosions are 35% larger."},
	&"interest": {"title": "Compound Interest", "rar": 0, "color": "#ffd36b", "glyph": "coin", "tags": ["Economy"], "desc": "Gain 25% more gold. Enter a room holding 60+ gold: +3 gold."},
	&"leech_loop": {"title": "Leech Loop", "rar": 0, "color": "#d8344a", "glyph": "loop", "tags": ["Survival"], "desc": "Every 6th kill heals 4 HP."},
	&"afterimage": {"title": "Afterimage", "rar": 0, "color": "#a0b8ff", "glyph": "ghost", "tags": ["Survival"], "desc": "After a hit you stay untouchable 50% longer."},
	&"sandbox": {"title": "Sandbox", "rar": 0, "color": "#e0c890", "glyph": "box", "tags": ["Survival"], "desc": "Spike plates no longer hurt you."},
	&"bounce_core": {"title": "Bounce Core", "rar": 0, "color": "#b9ffb0", "glyph": "bounce", "tags": [], "desc": "Every spell bounces off walls one more time."},
	&"busy_wait": {"title": "Busy Wait", "rar": 0, "color": "#ffe066", "glyph": "clock", "tags": [], "desc": "Stand still for 0.6 s: your next cast deals +60%."},
	&"buffer_overflow": {"title": "Buffer Overflow", "rar": 0, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "Healing past your max HP becomes a shield (up to 30) that takes hits first."},
	&"overclock": {"title": "Overclock Chip", "rar": 1, "color": "#ffb04a", "glyph": "chip", "tags": [], "desc": "Wands cast and recharge 15% faster."},
	&"heap_overflow": {"title": "Heap Overflow", "rar": 1, "color": "#ff5a8a", "glyph": "stack", "tags": [], "desc": "Deal 30% more damage. Max HP -20."},
	&"try_catch": {"title": "Try / Catch", "rar": 1, "color": "#9ab0ff", "glyph": "shield", "tags": ["Survival"], "desc": "The first hit you take in each room is caught and ignored."},
	&"recursion": {"title": "Recursion Charm", "rar": 1, "color": "#ffe066", "glyph": "spiral", "tags": ["Trigger", "Carrier"], "desc": "Spells released by triggers and carriers deal 30% more damage."},
	&"aperture": {"title": "Wide Aperture", "rar": 1, "color": "#ffb86b", "glyph": "fan", "tags": ["Multi"], "desc": "Spells that fire several bolts fire one more."},
	&"null_pointer": {"title": "Null Pointer", "rar": 1, "color": "#ff3fa4", "glyph": "cursor", "tags": ["Crit"], "desc": "The first hit on an unhurt enemy deals double damage."},
	&"deadline": {"title": "Deadline", "rar": 1, "color": "#ff7b7b", "glyph": "clock", "tags": [], "desc": "+40% damage for the first 6 seconds of every fight."},
	&"stack_trace": {"title": "Stack Trace", "rar": 1, "color": "#c9a8ff", "glyph": "stack", "tags": ["Glitch", "Multi"], "desc": "Every 7th cast also fires backward."},
	&"bug_bounty": {"title": "Bug Bounty", "rar": 1, "color": "#9cd01c", "glyph": "star", "tags": ["Carrier"], "desc": "Kills release a little bug that hunts the nearest enemy (10 damage)."},
	&"cascade_failure": {"title": "Cascade Failure", "rar": 1, "color": "#fff27a", "glyph": "burst", "tags": ["Crit"], "desc": "Critical hits arc to another enemy nearby for half damage."},
	&"wildfire": {"title": "Wildfire", "rar": 1, "color": "#ff8a3c", "glyph": "burst", "tags": ["Burn"], "desc": "Burning enemies spread their fire to enemies close by when they die."},
	&"cold_boot": {"title": "Cold Boot", "rar": 1, "color": "#9fe8ff", "glyph": "drop", "tags": ["Frost"], "desc": "Chilled enemies take 25% more damage."},
	&"echo": {"title": "Echo Crystal", "rar": 2, "color": "#c9a8ff", "glyph": "gem", "tags": ["Multi"], "desc": "15% chance that a cast repeats for free."},
	&"event_loop": {"title": "Event Loop", "rar": 2, "color": "#ffd05e", "glyph": "loop", "tags": ["Trigger", "Carrier"], "desc": "Triggers and carriers release their payload twice, the second time at 60%."},
}

const RARITY_NAMES := ["Common", "Rare", "Epic"]
const RARITY_COLORS := ["#c8c8d8", "#5ca8ff", "#c46bff"]


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
		&"spare_battery":
			for w in run.wands:
				w.bonus_mana = 1.3


## Global damage multiplier for casts from the player's wands.
static func dmg_mul(run: RunState, room_time: float) -> float:
	var k := 1.0
	if run.has_relic(&"heap_overflow"):
		k *= 1.3
	if run.has_relic(&"deadline") and room_time < 6.0:
		k *= 1.4
	return k


static func damage_taken_mul(run: RunState) -> float:
	return 0.85 if run.has_relic(&"iron_stack") else 1.0


static func mana_regen_mul(run: RunState) -> float:
	return 1.2 if run.has_relic(&"spare_battery") else 1.0


static func tags(id: StringName) -> Array:
	return DEFS[id].get("tags", []) if DEFS.has(id) else []


static func gold_mul(run: RunState) -> float:
	return 1.25 if run.has_relic(&"interest") else 1.0
