class_name Relics
extends RefCounted
## Original relics (decisions/0002), themed on software and the Glitch. Most are checked
## where they matter (run.has_relic); on_gain handles the instant ones. Descriptions stay
## short and concrete: players on phones read them in a glance.

const DEFS := {
	&"hot_patch": {"title": "Hot Patch", "rar": 0, "color": "#ff6b7a", "glyph": "heart", "desc": "Max HP +20, and heal 20."},
	&"garbage_collector": {"title": "Garbage Collector", "rar": 0, "color": "#7dd8ff", "glyph": "bin", "desc": "Every kill refills 3 mana in all your wands."},
	&"overclock": {"title": "Overclock Chip", "rar": 1, "color": "#ffb04a", "glyph": "chip", "desc": "Wands cast and recharge 15% faster."},
	&"heap_overflow": {"title": "Heap Overflow", "rar": 1, "color": "#ff5a8a", "glyph": "stack", "desc": "Deal 30% more damage. Max HP -20."},
	&"try_catch": {"title": "Try / Catch", "rar": 1, "color": "#9ab0ff", "glyph": "shield", "desc": "The first hit you take in each room is caught and ignored."},
	&"lucky_bit": {"title": "Lucky Bit", "rar": 0, "color": "#7dff9a", "glyph": "clover", "desc": "+10% critical hit chance on every spell."},
	&"cache_line": {"title": "Cache Line", "rar": 0, "color": "#4aa8ff", "glyph": "drop", "desc": "All wands regenerate mana 30% faster."},
	&"recursion": {"title": "Recursion Charm", "rar": 1, "color": "#ffe066", "glyph": "spiral", "desc": "Spells released by triggers and carriers deal 30% more damage."},
	&"aperture": {"title": "Wide Aperture", "rar": 1, "color": "#ffb86b", "glyph": "fan", "desc": "Spells that fire several bolts fire one more."},
	&"interest": {"title": "Compound Interest", "rar": 0, "color": "#ffd36b", "glyph": "coin", "desc": "Gain 25% more gold. Enter a room holding 60+ gold: +3 gold."},
	&"leech_loop": {"title": "Leech Loop", "rar": 0, "color": "#d8344a", "glyph": "loop", "desc": "Every 6th kill heals 4 HP."},
	&"echo": {"title": "Echo Crystal", "rar": 2, "color": "#c9a8ff", "glyph": "gem", "desc": "15% chance that a cast repeats for free."},
	&"iron_stack": {"title": "Iron Stack", "rar": 0, "color": "#b8c0cc", "glyph": "stack", "desc": "Take 15% less damage."},
	&"afterimage": {"title": "Afterimage", "rar": 0, "color": "#a0b8ff", "glyph": "ghost", "desc": "After a hit you stay untouchable 50% longer."},
	&"keen_scope": {"title": "Keen Scope", "rar": 0, "color": "#e8fbff", "glyph": "eye", "desc": "Auto-aim reaches 40% farther. Spells fly 15% faster."},
	&"blast_radius": {"title": "Blast Radius", "rar": 1, "color": "#ff8a3c", "glyph": "burst", "desc": "Explosions are 35% larger."},
	&"spare_battery": {"title": "Spare Battery", "rar": 0, "color": "#5ce1ff", "glyph": "battery", "desc": "Every wand holds 30% more mana."},
	&"null_pointer": {"title": "Null Pointer", "rar": 1, "color": "#ff3fa4", "glyph": "cursor", "desc": "The first hit on an unhurt enemy deals double damage."},
	&"deadline": {"title": "Deadline", "rar": 1, "color": "#ff7b7b", "glyph": "clock", "desc": "+40% damage for the first 6 seconds of every fight."},
	&"hotkey_boots": {"title": "Hotkey Boots", "rar": 0, "color": "#9ad06a", "glyph": "boot", "desc": "Move 15% faster."},
	&"bounce_core": {"title": "Bounce Core", "rar": 1, "color": "#b9ffb0", "glyph": "bounce", "desc": "Every spell bounces off walls one more time."},
	&"sandbox": {"title": "Sandbox", "rar": 0, "color": "#e0c890", "glyph": "box", "desc": "Spike plates no longer hurt you."},
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
	return 1.3 if run.has_relic(&"cache_line") else 1.0


static func gold_mul(run: RunState) -> float:
	return 1.25 if run.has_relic(&"interest") else 1.0
