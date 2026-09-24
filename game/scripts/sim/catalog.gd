class_name Catalog
extends RefCounted
## The original content catalog (decisions/0002). This is the vertical-slice subset;
## M2 grows it to the full set. Triggers are named after program constructs, a nod to
## the Glitch setting: the wand really is a little program.

static var _spells: Dictionary = {}
static var _wands: Dictionary = {}


static func spells() -> Dictionary:
	if _spells.is_empty():
		_build()
	return _spells


static func spell(id: StringName) -> SpellDef:
	return spells().get(id)


static func wands() -> Dictionary:
	if _wands.is_empty():
		_build()
	return _wands


static func wand(id: StringName) -> WandDef:
	return wands().get(id)


static func _s(id: String, kind: SpellDef.Kind, title: String, color: String, o: Dictionary, desc: String) -> void:
	var d := SpellDef.new()
	d.id = StringName(id)
	d.kind = kind
	d.title = title
	d.color = Color(color)
	d.desc = desc
	d.rarity = o.get("rar", 0)
	d.mana = PackedFloat32Array(o.get("mp", [0.0]))
	d.damage = PackedFloat32Array(o.get("dmg", [0.0]))
	d.crit = o.get("crit", 0.0)
	d.cast_delay = o.get("dl", 0.0)
	d.recharge = o.get("rc", 0.0)
	d.behavior = StringName(o.get("beh", "bolt"))
	d.carrier = StringName(o.get("carry", ""))
	d.trig = StringName(o.get("t", ""))
	d.params = o.get("p", {})
	_spells[d.id] = d


static func _build() -> void:
	var P := SpellDef.Kind.PROJ
	var B := SpellDef.Kind.BOOST
	var T := SpellDef.Kind.TRIG
	var S := SpellDef.Kind.PASSIVE
	# ---- shooting spells ----
	_s("mote", P, "Arcane Mote", "#8fd8ff", {"mp": [3, 4, 5], "dmg": [6, 8, 10], "p": {"speed": 260, "radius": 2.0, "life": 0.9}},
		"A small bolt of raw mana. Cheap, fast, dependable.")
	_s("lance", P, "Prism Lance", "#b6ff5c", {"mp": [3, 4, 5], "dmg": [5, 7, 9], "dl": -0.04, "rc": -0.08, "beh": "beam", "p": {"len": 150}},
		"An instant beam that hits the first thing in line. Makes the wand cast faster.")
	_s("fan", P, "Spectrum Fan", "#ffb86b", {"mp": [10, 13, 17], "dmg": [4, 7, 12], "p": {"speed": 230, "radius": 2.0, "life": 0.7, "count": 7, "spread": 40.0, "pierce": 1}},
		"Seven colored bolts fanned out in front of you. Each passes through one enemy.")
	_s("burst", P, "Rune Burst", "#c9a8ff", {"mp": [8, 15, 40], "dmg": [10, 26, 70], "crit": 0.2, "beh": "burst", "p": {"area": [30.0, 32.0, 35.0]}},
		"Detonates right at the wand tip. Weak alone, devastating when a carrier delivers it.")
	_s("moths", P, "Seeker Moths", "#ff9ad5", {"mp": [7, 10, 13], "dmg": [6, 10, 18], "p": {"speed": 150, "radius": 2.0, "life": 1.6, "count": [3, 4, 5], "spread": 80.0, "homing": 7.0}},
		"A flutter of moths that home in on the nearest target.")
	_s("seed", P, "Payload Seed", "#ffe066", {"mp": [1, 2, 3], "dmg": [2, 5, 10], "carry": "seed", "p": {"speed": 190, "radius": 2.0, "life": 0.9}},
		"Carries the next shooting spell and releases it where it lands. That spell costs 90/80/70% mana.")
	_s("wheel", P, "Starwheel", "#ffd36b", {"rar": 2, "mp": [12], "dmg": [16], "carry": "wheel", "beh": "wheel", "p": {"speed": 80, "radius": 4.0, "life": 1.6, "pierce": 99}},
		"A spinning star that sprays the next shooting spell 16 times around it. That spell costs x4 mana and deals x0.5 damage.")
	# ---- boosts: change every shooting spell to their right until the wand recharges ----
	_s("empower", B, "Empower", "#ff7b7b", {"mp": [5]}, "Damage +25/50/100%.")
	_s("quicken", B, "Quicken", "#7cc6ff", {"mp": [2]}, "Flight speed +35/70/140%.")
	_s("seek", B, "Seek", "#6fe3c1", {"rar": 1, "mp": [4]}, "Spells steer toward enemies.")
	_s("phase", B, "Phase Through", "#d0d0ff", {"mp": [3]}, "Spells pass through 1/2/4 more enemies.")
	_s("ricochet", B, "Ricochet", "#b9ffb0", {"mp": [2]}, "Spells bounce off walls 2/4/8 times.")
	_s("twin", B, "Twin Cast", "#ffa3c4", {"rar": 1, "mp": [0]}, "Each spell after it is cast 1/2/4 extra times. Costs x1.5 mana.")
	_s("chorus", B, "Chorus", "#ffc94a", {"mp": [0]}, "Casts 2/3/4 more shooting spells at once, each a little cheaper, with some spread.")
	_s("shatter", B, "Shatter", "#ffd36b", {"mp": [3]}, "When a spell ends it breaks into 3/5/8 shards at a third of its damage. Costs x1.4 mana.")
	_s("mirror", B, "Mirror", "#d6d6ff", {"rar": 1, "mp": [2]}, "Copies the next spell: a boost applies twice, a shooting spell is cast twice.")
	# ---- triggers: sit between two spells, the left one fires the right one ----
	_s("then", T, "THEN", "#ffe066", {"mp": [4], "t": "then"}, "When the left spell ends, cast the right one. It inherits 30/60/120% of the left spell's damage.")
	_s("callback", T, "Callback", "#ffe066", {"rar": 1, "mp": [5], "t": "callback"}, "Every hit of the left spell calls the right one, at 80/65/50% mana, at most every 0.3/0.2/0.1s.")
	_s("loop", T, "While Loop", "#ffe066", {"mp": [4], "t": "loop"}, "While the left spell flies, keep casting the right one at 70/55/40% mana.")
	_s("fork", T, "Fork Bomb", "#ffe066", {"rar": 1, "mp": [6], "t": "fork"}, "When the left spell ends, the right one forks 4 ways at 35/45/60% damage. Its mana x4.")
	# ---- passives: work from any slot ----
	_s("cache", S, "Mana Cache", "#5ce1ff", {}, "Wand max mana +40/80/160%.")
	_s("heatsink", S, "Heat Sink", "#9b7bff", {}, "Wand recharge x0.6/0.3/0.15.")

	var w := WandDef.new()
	w.id = &"apprentice"; w.title = "Apprentice Rod"; w.slots = 5; w.max_mana = 80; w.regen = 18; w.cast_delay = 0.15; w.recharge = 0.5; w.scatter = 5
	_wands[w.id] = w
	w = WandDef.new()
	w.id = &"harp"; w.title = "Chorus Harp"; w.rarity = 1; w.slots = 7; w.max_mana = 110; w.regen = 20; w.cast_delay = 0.4; w.recharge = 0.5; w.scatter = 60; w.simultaneous = 3; w.color = Color("#6fe3c1")
	_wands[w.id] = w


## Applies a boost to the accumulator.
static func apply_boost(id: StringName, m: Mods, lv: int) -> void:
	var i := clampi(lv, 1, 3) - 1
	match id:
		&"empower": m.dmg *= 1.0 + [0.25, 0.5, 1.0][i]
		&"quicken": m.spd += [0.35, 0.7, 1.4][i]
		&"seek": m.home = maxf(m.home, [3.5, 6.0, 10.0][i])
		&"phase": m.pierce += [1, 2, 4][i]
		&"ricochet": m.bounce += [2, 4, 8][i]
		&"twin":
			m.multi += [1, 2, 4][i]
			m.cnt_mp *= 1.5
		&"shatter":
			m.shatter = maxi(m.shatter, [3, 5, 8][i])
			m.cnt_mp *= 1.4
