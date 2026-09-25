class_name Catalog
extends RefCounted
## The content catalog (decisions/0002, D2 redesign in research/design-plan.md §1). All
## names, text and numbers are original. Triggers and runes are named after program
## constructs, a nod to the Glitch setting: the wand really is a little program.
##
## Families: shooting spells, carriers (hold the next shooting spell as a payload), boosts
## (change every shooting spell to their right until the wand recharges), status coats,
## draw spells (pull more spells into one cast), triggers (glue the left spell to the right
## one), Debugger runes (edit the program itself), familiars (summons that stay out) and
## passives (work from any slot).

static var _spells: Dictionary = {}
static var _wands: Dictionary = {}

## Spells cut or merged in the D2 redesign: old saves map them here (null = dropped).
const ALIASES := {&"linger": &"quicken", &"cache": &"mana_well", &"regen": &"mana_well", &"shatter": null}

## Synergy tags (research/arsenal-v04.md). Rewards lean toward tags a run already has.
const TAGS := {
	&"needle": ["Crit", "Glitch"], &"fan": ["Multi"], &"moths": ["Multi"], &"frost": ["Frost", "Multi"],
	&"ember": ["Burn", "Area"], &"burst": ["Area", "Crit"], &"seed": ["Carrier"], &"wheel": ["Carrier"],
	&"ping": ["Carrier"], &"mine": ["Area", "Glitch"], &"static": ["Area", "Shock"], &"null_orb": ["Glitch"],
	&"spark": ["Shock"], &"firewall": ["Burn", "Area"], &"bitrot": ["Rot", "Glitch"], &"hexcursor": ["Glitch", "Trigger"],
	&"twin": ["Multi"], &"chorus": ["Multi"], &"pipeline": ["Multi"], &"split": ["Multi"], &"wide": ["Area"],
	&"keen": ["Crit"], &"ember_coat": ["Burn"], &"frost_coat": ["Frost"], &"static_coat": ["Shock"], &"rot_coat": ["Rot"],
	&"gravity": ["Glitch"], &"mirror": ["Glitch"], &"orbit": ["Survival"], &"reverse": ["Glitch"], &"siphon": ["Economy"],
	&"then": ["Trigger"], &"callback": ["Trigger"], &"loop": ["Trigger"], &"fork": ["Trigger"], &"finally": ["Trigger"],
	&"sleep": ["Trigger"], &"head": ["Debug"], &"ifelse": ["Debug"], &"goto": ["Debug"], &"include": ["Debug"],
	&"daemon": ["Familiar", "Carrier"], &"turret": ["Familiar"], &"duck": ["Familiar", "Survival"],
	&"mana_well": ["Economy"], &"watchdog": ["Economy"],
}


static func tags(id: StringName) -> Array:
	if EVOLUTIONS.has(id):
		return TAGS.get(EVOLUTIONS[id]["base"], [])
	return TAGS.get(id, [])


## Compile evolutions (D3): a level-3 base spell plus a catalyst (a relic you own, or a
## spell you carry, which is used up) become an evolved spell at the forge. Never offered
## as rewards. Mechanics inspired by other games; names and numbers are ours (ADR 0002).
const EVOLUTIONS := {
	&"storm_protocol": {"base": &"spark", "cat": &"cascade_failure", "cat_t": &"relic"},
	&"singularity": {"base": &"null_orb", "cat": &"gravity", "cat_t": &"spell"},
	&"meltdown": {"base": &"ember", "cat": &"wildfire", "cat_t": &"relic"},
	&"absolute_zero": {"base": &"frost", "cat": &"cold_boot", "cat_t": &"relic"},
	&"replicator": {"base": &"mote", "cat": &"recursion", "cat_t": &"relic"},
	&"exploit_needle": {"base": &"needle", "cat": &"null_pointer", "cat_t": &"relic"},
}


static func is_evolved(id: StringName) -> bool:
	return EVOLUTIONS.has(id)


static func spells() -> Dictionary:
	if _spells.is_empty():
		_build()
	return _spells


static func spell(id: StringName) -> SpellDef:
	return spells().get(id)


## The id an old save's spell maps to after the redesign (or &"" when it was cut).
static func resolve(id: StringName) -> StringName:
	if spells().has(id):
		return id
	var to: Variant = ALIASES.get(id, null)
	return to if to != null else &""


static func wands() -> Dictionary:
	if _wands.is_empty():
		_build()
	return _wands


static func wand(id: StringName) -> WandDef:
	return wands().get(id)


## True for anything that fires something when the program reaches it.
static func is_caster(d: SpellDef) -> bool:
	return d != null and (d.kind == SpellDef.Kind.PROJ or d.kind == SpellDef.Kind.FAMILIAR)


static func _s(id: String, kind: SpellDef.Kind, title: String, color: String, o: Dictionary, desc: String, l3 := "") -> void:
	var d := SpellDef.new()
	d.id = StringName(id)
	d.kind = kind
	d.title = title
	d.color = Color(color)
	d.desc = desc
	d.l3 = l3
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
	d.keywords = PackedStringArray(o.get("kw", []))
	_spells[d.id] = d


static func _build() -> void:
	var P := SpellDef.Kind.PROJ
	var B := SpellDef.Kind.BOOST
	var T := SpellDef.Kind.TRIG
	var S := SpellDef.Kind.PASSIVE
	var R := SpellDef.Kind.RUNE
	var F := SpellDef.Kind.FAMILIAR
	# ---- shooting spells ----
	_s("mote", P, "Arcane Mote", "#8fd8ff", {"mp": [3, 4, 5], "dmg": [6, 8, 10], "p": {"speed": 260, "radius": 2.0, "life": 0.9, "pierce": [0, 0, 1]}},
		"A small bolt of raw mana. Cheap, fast, dependable.", "passes through one enemy")
	_s("lance", P, "Prism Lance", "#b6ff5c", {"mp": [3, 4, 5], "dmg": [5, 7, 9], "dl": -0.04, "rc": -0.08, "beh": "beam", "kw": ["pierce"], "p": {"len": 150}},
		"An instant beam that hits the first thing in line. Makes the wand cast faster. Breaks shields.")
	_s("fan", P, "Spectrum Fan", "#ffb86b", {"mp": [10, 13, 17], "dmg": [4, 7, 12], "p": {"speed": 230, "radius": 2.0, "life": 0.7, "count": [7, 7, 9], "spread": 40.0, "pierce": 1}},
		"Seven colored bolts fanned out in front of you. Each passes through one enemy.", "nine bolts")
	_s("burst", P, "Rune Burst", "#c9a8ff", {"mp": [8, 15, 40], "dmg": [10, 26, 70], "crit": 0.2, "beh": "burst", "kw": ["blast"], "p": {"area": [30.0, 32.0, 35.0]}},
		"Detonates right at the wand tip. Weak alone, devastating when a carrier delivers it. Breaks armor.")
	_s("moths", P, "Seeker Moths", "#ffd05e", {"mp": [7, 10, 13], "dmg": [6, 10, 18], "p": {"speed": 150, "radius": 2.0, "life": 1.6, "count": [3, 4, 5], "spread": 80.0, "homing": 7.0}},
		"A flutter of lantern moths that home in on the nearest target.")
	_s("needle", P, "Glitch Needle", "#e8fbff", {"mp": [2, 3, 4], "dmg": [4, 6, 8], "dl": -0.02, "crit": 0.0, "kw": ["pierce"], "p": {"speed": 380, "radius": 1.5, "life": 0.6, "pierce": 2, "crit_add": [0.0, 0.0, 0.15]}},
		"A thin, very fast needle that passes through two enemies. Breaks shields.", "+15% crit chance")
	_s("ember", P, "Ember Bolt", "#ff8a3c", {"mp": [6, 8, 11], "dmg": [8, 12, 17], "beh": "bomb", "kw": ["blast"], "p": {"speed": 150, "radius": 3.0, "life": 1.0, "area": [18.0, 21.0, 25.0], "burn": [1, 1, 2]}},
		"A slow fireball that explodes where it lands and sets enemies alight. Breaks armor.", "burns twice as hot")
	_s("spark", P, "Chain Spark", "#fff27a", {"rar": 1, "mp": [5, 7, 9], "dmg": [5, 8, 12], "kw": ["shock"], "p": {"speed": 240, "radius": 2.0, "life": 0.8, "chain": [2, 3, 5]}},
		"On a hit, jumps to the next enemy nearby, 2/3/5 times. Strips wards.")
	_s("frost", P, "Frost Shard", "#9fe8ff", {"mp": [4, 5, 7], "dmg": [5, 7, 10], "p": {"speed": 220, "radius": 2.0, "life": 0.9, "count": [2, 2, 3], "spread": 16.0, "chill": 1}},
		"Twin shards of ice that slow what they hit.", "three shards")
	_s("disc", P, "Boomerang Disc", "#c8e6ff", {"mp": [6, 8, 10], "dmg": [9, 13, 19], "beh": "boomerang", "kw": ["pierce"], "p": {"speed": 210, "radius": 3.0, "life": 1.4, "pierce": 99}},
		"Flies out and comes back to you, cutting through everything both ways. Breaks shields.")
	_s("mine", P, "Glitch Mine", "#a060d8", {"mp": [5, 7, 9], "dmg": [22, 34, 52], "beh": "mine", "kw": ["blast"], "p": {"speed": 170, "radius": 3.0, "life": 4.0, "area": [26.0, 30.0, 34.0]}},
		"Tossed ahead. Arms after a moment, then blasts when an enemy steps close. Breaks armor.")
	_s("static", P, "Static Cone", "#8ff0ff", {"mp": [4, 6, 8], "dmg": [8, 12, 17], "beh": "cone", "kw": ["shock"], "p": {"len": 70.0, "arc": 70.0, "static": 1}},
		"An instant cone of lightning in front of you. Hits everything inside it and leaves it charged. Strips wards.")
	_s("null_orb", P, "Null Orb", "#a060d8", {"rar": 1, "mp": [9, 12, 15], "dmg": [5, 7, 10], "beh": "orb", "p": {"speed": 55, "radius": 5.0, "life": 2.6, "pierce": 99, "pull": 55.0}},
		"A slow orb that drags enemies in and grinds anything it touches, four times a second.")
	_s("firewall", P, "Firewall", "#ff9a3a", {"rar": 1, "mp": [8, 11, 14], "dmg": [4, 6, 9], "beh": "wall", "p": {"life": [2.5, 3.0, 3.5], "len": 40.0, "burn": 1, "dist": 24.0}},
		"Plants a short wall of flame across your aim. It blocks enemy shots and burns whatever walks through.", "blocks shots for longer")
	_s("bitrot", P, "Bitrot Spore", "#ff6fd2", {"mp": [6, 8, 10], "dmg": [2, 3, 4], "beh": "cloud", "p": {"speed": 45, "radius": 10.0, "life": 2.6, "pierce": 99, "rot": 1}},
		"A slow drifting cloud that adds a stack of Bitrot to everything inside it every tick. Five stacks crash the target.")
	_s("hexcursor", P, "Hex Cursor", "#d6d6ff", {"mp": [2, 3, 4], "dmg": [3, 4, 5], "p": {"speed": 150, "radius": 4.0, "life": 1.4, "mark": 4.0}},
		"A slow reticle. The first enemy it touches is marked, and payloads aim at the mark.")
	# ---- carriers: hold the next shooting spell as a payload ----
	_s("seed", P, "Payload Seed", "#ffe066", {"mp": [1, 2, 3], "dmg": [2, 5, 10], "carry": "seed", "p": {"speed": 190, "radius": 2.0, "life": 0.9}},
		"Carries the next shooting spell and releases it where it lands. That spell costs 90/80/60% mana.", "payload at 60% mana")
	_s("wheel", P, "Starwheel", "#ffd36b", {"rar": 2, "mp": [12], "dmg": [16], "carry": "wheel", "beh": "wheel", "p": {"speed": 80, "radius": 4.0, "life": 1.6, "pierce": 99}},
		"A spinning star that sprays the next shooting spell 16 times around it. That spell costs x4 mana and deals x0.5 damage.")
	_s("ping", P, "Ping", "#8fd8ff", {"rar": 1, "mp": [3, 4, 5], "dmg": [3, 5, 7], "dl": 0.25, "carry": "ping", "beh": "ping"},
		"Reaches the nearest enemy anywhere in the room at once and releases the next shooting spell on it. Slows the wand a little.")
	# ---- boosts: change every shooting spell to their right until the wand recharges ----
	_s("empower", B, "Empower", "#ff7b7b", {"mp": [5]}, "Damage +25/50/100%.")
	_s("quicken", B, "Long Range", "#7cc6ff", {"mp": [2]}, "Spells fly 35/70/140% faster and last 0.2/0.4/0.7 s longer.")
	_s("seek", B, "Seek", "#6fe3c1", {"rar": 1, "mp": [4]}, "Spells steer toward enemies.")
	_s("phase", B, "Phase Through", "#d0d0ff", {"mp": [3]}, "Spells pass through 1/2/4 more enemies and break shields.")
	_s("ricochet", B, "Ricochet", "#b9ffb0", {"mp": [2]}, "Spells bounce off walls 2/4/8 times.")
	_s("twin", B, "Twin Cast", "#ffa3c4", {"rar": 1, "mp": [0]}, "Each spell after it is cast 1/2/4 extra times. Costs x1.5 mana.")
	_s("heavy", B, "Heavy Rune", "#c8a070", {"mp": [4]}, "Damage +40/60/90% and a big knockback; an enemy slammed into a wall takes the hit again at half. Spells fly 30% slower.")
	_s("wide", B, "Wide Rune", "#b4f0a0", {"mp": [3]}, "Explosions and bolts are 40/70/110% larger.")
	_s("keen", B, "Keen Edge", "#ffe0e0", {"mp": [3]}, "Critical hit chance +15/25/40%. Crits deal double damage.")
	_s("mirror", B, "Mirror", "#d6d6ff", {"rar": 1, "mp": [2]}, "Copies the next spell: a boost applies twice, a shooting spell is cast twice.")
	_s("split", B, "Branch Rune", "#9cf06a", {"mp": [3]}, "On their first hit, bolts branch into 2/3/4 bolts at 40% damage.")
	_s("gravity", B, "Gravity Rune", "#b48cff", {"rar": 1, "mp": [3]}, "Spells drag nearby enemies toward their path (40/65/100 px/s).")
	_s("orbit", B, "Orbit Rune", "#9fe8ff", {"rar": 1, "mp": [3]}, "Spells circle you for their lifetime instead of flying off: a shield made of your own magic.")
	_s("reverse", B, "Reverse Rune", "#c2359f", {"mp": [2]}, "Spells fire behind you and deal +60% damage. A second Reverse cancels it.")
	_s("siphon", B, "Siphon Rune", "#72e06a", {"mp": [3]}, "A kill by these spells refunds 30/45/60% of their mana.")
	# ---- status coats ----
	_s("ember_coat", B, "Ember Coat", "#ff8a3c", {"rar": 1, "mp": [4]}, "Hits set enemies on fire, stronger at higher levels.")
	_s("frost_coat", B, "Frost Coat", "#9fe8ff", {"rar": 1, "mp": [4]}, "Hits chill enemies. Three chills freeze them solid for a moment.")
	_s("static_coat", B, "Static Coat", "#fff27a", {"mp": [4]}, "Hits charge enemies: the next hit on a charged enemy arcs to a neighbour. Strips wards.")
	_s("rot_coat", B, "Rot Coat", "#ff6fd2", {"mp": [4]}, "Hits add 1/1/2 stacks of Bitrot. Five stacks crash the target in a small burst.")
	# ---- draw spells: pull more shooting spells into this one cast ----
	_s("chorus", B, "Chorus", "#ffc94a", {"mp": [0]}, "Casts 2/3/4 more shooting spells at once, each a little cheaper, with some spread.", "no spread")
	_s("pipeline", B, "Pipeline", "#8fd8ff", {"rar": 1, "mp": [2]}, "The next 3/4/5 shooting spells fire in a tight line, one after another, straight down your aim.")
	# ---- triggers: sit between two spells, the left one fires the right one ----
	_s("then", T, "THEN", "#ffe066", {"mp": [4], "t": "then"}, "When the left spell ends, cast the right one. It inherits 30/60/120% of the left spell's damage.")
	_s("callback", T, "Callback", "#ffe066", {"rar": 1, "mp": [5], "t": "callback"}, "Every hit of the left spell calls the right one, at 80/65/50% mana, at most every 0.3/0.2/0.1s.")
	_s("loop", T, "While Loop", "#ffe066", {"mp": [4], "t": "loop"}, "While the left spell flies, keep casting the right one at 70/55/40% mana.")
	_s("fork", T, "Fork Bomb", "#ffe066", {"rar": 1, "mp": [6], "t": "fork"}, "When the left spell ends, the right one forks 4 ways at 35/45/60% damage. Its mana x4.")
	_s("finally", T, "Finally", "#ffe066", {"rar": 1, "mp": [4], "t": "finally"}, "A kill by the left spell casts the right one from the body. Up to 1/2/3 times.")
	_s("sleep", T, "Sleep(ms)", "#ffe066", {"mp": [3], "t": "sleep"}, "After 0.4/0.3/0.2 s the right spell is cast from wherever the left one is at that moment.")
	# ---- Debugger runes: they edit the program itself ----
	_s("head", R, "HEAD", "#5ce1ff", {"rar": 1, "mp": [4, 3, 2]}, "Casts a free copy of the wand's first shooting spell, with the boosts it has right now.")
	_s("ifelse", R, "IF / ELSE", "#5ce1ff", {"rar": 1, "mp": [2]}, "If an enemy is close (60 px), cast the next spell and skip the one after. If not, skip the next and cast the one after.")
	_s("goto", R, "GOTO 1", "#5ce1ff", {"rar": 2, "mp": [6, 5, 4]}, "Once per cycle: after this cast, jump back to slot 1 without recharging. Boosts stay on. Adds 0.3 s of delay.")
	_s("include", R, "#include", "#5ce1ff", {"rar": 2, "mp": [5]}, "The boost to its right applies to every spell on the wand, even the ones to its left and every payload. That boost costs x1.5.")
	# ---- familiars: summons that stay out ----
	_s("daemon", F, "Daemon", "#9b7bff", {"rar": 1, "mp": [10, 12, 14], "dmg": [0], "carry": "daemon", "beh": "daemon", "p": {"life": [8.0, 10.0, 12.0], "every": [1.5, 1.2, 0.9]}},
		"Summons a sprite that orbits you and casts the next shooting spell as its own weapon every 1.5/1.2/0.9 s. One at a time.")
	_s("turret", F, "Watchdog Turret", "#ffd05e", {"mp": [9, 11, 13], "dmg": [5, 7, 10], "beh": "turret", "p": {"life": 8.0, "every": 0.5, "range": 130.0}},
		"Plants a turret that shoots the nearest enemy for 8 s. Two at a time.")
	_s("duck", F, "Rubber Duck", "#ffe066", {"mp": [8, 7, 6], "dmg": [0], "beh": "duck", "p": {"life": 6.0, "soak": [3, 4, 6]}},
		"Drops a decoy that enemies chase and shoot instead of you. It soaks 3/4/6 hits. One at a time.")
	# ---- passives: work from any slot ----
	_s("mana_well", S, "Mana Well", "#5ce1ff", {}, "Wand max mana +40/80/160% and mana regenerates 30/60/120% faster.")
	_s("heatsink", S, "Heat Sink", "#9b7bff", {}, "Wand recharge x0.6/0.3/0.15.")
	_s("watchdog", S, "Watchdog", "#72e06a", {"rar": 1}, "If the wand has not cast for 1 s, its next cast is free.")

	# ---- Compile evolutions (D3): a level-3 spell plus its catalyst, at the forge ----
	_s("storm_protocol", P, "Storm Protocol", "#fff27a", {"rar": 2, "mp": [9], "dmg": [14], "kw": ["shock"], "p": {"speed": 260, "radius": 2.0, "life": 1.0, "chain": 8, "static": 1}},
		"Compiled Chain Spark. Jumps 8 times and leaves everything it touches charged with Static.")
	_s("singularity", P, "Singularity Kernel", "#a060d8", {"rar": 2, "mp": [16], "dmg": [12], "beh": "orb", "kw": ["blast"], "p": {"speed": 50, "radius": 7.0, "life": 3.0, "pierce": 99, "pull": 110.0, "implode": 1, "area": 40.0}},
		"Compiled Null Orb. Drags harder, grinds harder, and implodes when it ends.")
	_s("meltdown", P, "Meltdown", "#ff8a3c", {"rar": 2, "mp": [13], "dmg": [24], "beh": "bomb", "kw": ["blast"], "p": {"speed": 150, "radius": 3.5, "life": 1.0, "area": 40.0, "burn": 3}},
		"Compiled Ember Bolt. A huge blast that sets everything in it ablaze.")
	_s("absolute_zero", P, "Absolute Zero", "#e6fbff", {"rar": 2, "mp": [9], "dmg": [9], "p": {"speed": 230, "radius": 2.0, "life": 0.9, "count": 5, "spread": 30.0, "chill": 3}},
		"Compiled Frost Shard. Five shards, and each one freezes what it hits.")
	_s("replicator", P, "Self-Replicating Mote", "#8fd8ff", {"rar": 2, "mp": [6], "dmg": [12], "p": {"speed": 270, "radius": 2.0, "life": 1.0, "pierce": 1, "split": 3}},
		"Compiled Arcane Mote. On its first hit it copies itself into 3 more.")
	_s("exploit_needle", P, "Exploit Needle", "#e8fbff", {"rar": 2, "mp": [5], "dmg": [10], "dl": -0.02, "kw": ["pierce"], "p": {"speed": 400, "radius": 1.5, "life": 0.7, "pierce": 5, "crit_add": 0.5}},
		"Compiled Glitch Needle. Passes through 5 enemies with +50% crit chance.")

	# ---- wands ----
	_w(&"twig", "Twig Wand", 0, 3, 50, 16, 0.1, 0.35, 4, 1, false, "#c8a070", "Quick and light. Three slots.")
	_w(&"stub", "Stub Staff", 0, 2, 90, 20, 0.22, 0.6, 6, 1, false, "#8a6a3a", "Slow and deep. Two slots, a big mana pool.")
	var w := WandDef.new()
	w.id = &"apprentice"; w.title = "Apprentice Rod"; w.slots = 5; w.max_mana = 80; w.regen = 18; w.cast_delay = 0.12; w.recharge = 0.4; w.scatter = 5
	_wands[w.id] = w
	_w(&"birch", "Birch Switch", 0, 4, 60, 16, 0.1, 0.35, 4, 1, false, "#d8c090", "Fast, light, low on mana.")
	_w(&"mirror_rod", "Mirror Rod", 1, 6, 90, 20, 0.14, 0.5, 5, 1, true, "#b8b8ff", "Reads its program right to left.")
	_w(&"oak", "Old Oak Staff", 0, 8, 140, 24, 0.2, 0.9, 6, 1, false, "#8a6a3a", "Eight slots, slow to recharge.")
	_w(&"fork_branch", "Fork Branch", 1, 6, 100, 20, 0.25, 0.6, 22, 2, false, "#9ad06a", "Casts two spells at once, wide.")
	_w(&"crystal", "Crystal Wand", 2, 6, 120, 32, 0.12, 0.4, 3, 1, false, "#8ff0ff", "Deep mana, fast regen.")
	w = WandDef.new()
	w.id = &"harp"; w.title = "Chorus Harp"; w.rarity = 1; w.slots = 7; w.max_mana = 110; w.regen = 20; w.cast_delay = 0.4; w.recharge = 0.5; w.scatter = 60; w.simultaneous = 3; w.color = Color("#6fe3c1")
	w.desc = "Casts three spells at once."
	_wands[w.id] = w
	_w(&"daemon_rod", "Daemon Rod", 1, 6, 100, 22, 0.14, 0.5, 5, 1, false, "#9b7bff", "Its last slot runs in the background: it fires on its own every 3 s.")
	_wands[&"daemon_rod"].background_slot = true
	_w(&"debug_build", "Debug Build", 2, 8, 120, 22, 0.14, 0.55, 5, 1, false, "#5ce1ff", "Eight slots, but Debugger runes cost double here.")
	_wands[&"debug_build"].rune_tax = 2.0


static func _w(id: StringName, title: String, rar: int, slots: int, mana: float, regen: float, dl: float, rc: float,
		sc: float, sim: int, rev: bool, col: String, desc := "") -> void:
	var w := WandDef.new()
	w.id = id; w.title = title; w.rarity = rar; w.slots = slots; w.max_mana = mana; w.regen = regen
	w.cast_delay = dl; w.recharge = rc; w.scatter = sc; w.simultaneous = sim; w.reverse = rev; w.color = Color(col)
	w.desc = desc
	_wands[id] = w


## Applies a boost to the accumulator.
static func apply_boost(id: StringName, m: Mods, lv: int) -> void:
	var i := clampi(lv, 1, 3) - 1
	match id:
		&"empower": m.dmg *= 1.0 + [0.25, 0.5, 1.0][i]
		&"quicken":
			m.spd += [0.35, 0.7, 1.4][i]
			m.dur_add += [0.2, 0.4, 0.7][i]
		&"seek": m.home = maxf(m.home, [3.5, 6.0, 10.0][i])
		&"phase":
			m.pierce += [1, 2, 4][i]
			m.kw_pierce = true
		&"ricochet": m.bounce += [2, 4, 8][i]
		&"twin":
			m.multi += [1, 2, 4][i]
			m.cnt_mp *= 1.5
		&"heavy":
			m.dmg *= 1.0 + [0.4, 0.6, 0.9][i]
			m.spd -= 0.3
			m.knock *= 2.5
			m.slam = true
		&"wide": m.area *= 1.0 + [0.4, 0.7, 1.1][i]
		&"keen": m.crit += [0.15, 0.25, 0.4][i]
		&"ember_coat": m.burn = maxi(m.burn, i + 1)
		&"frost_coat": m.chill = maxi(m.chill, i + 1)
		&"static_coat":
			m.static_on = true
			m.kw_shock = true
		&"rot_coat": m.rot = maxi(m.rot, [1, 1, 2][i])
		&"split": m.split = maxi(m.split, i + 2)
		&"gravity": m.pull = maxf(m.pull, [40.0, 65.0, 100.0][i])
		&"orbit": m.orbit = true
		&"reverse": m.reverse = not m.reverse
		&"siphon": m.siphon = maxf(m.siphon, [0.3, 0.45, 0.6][i])
