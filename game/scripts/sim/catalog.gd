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
		"A small, fast bolt of raw mana. Cheap and dependable.", "It also passes through one enemy.")
	_s("lance", P, "Prism Lance", "#b6ff5c", {"mp": [3, 4, 5], "dmg": [5, 7, 9], "dl": -0.04, "rc": -0.08, "beh": "beam", "kw": ["pierce"], "p": {"len": 150}},
		"An instant beam that hits the first enemy in line. Breaks shields. Makes the wand cast a little faster.")
	_s("fan", P, "Spectrum Fan", "#ffb86b", {"mp": [10, 13, 17], "dmg": [4, 7, 12], "p": {"speed": 230, "radius": 2.0, "life": 0.7, "count": [7, 7, 9], "spread": 40.0, "pierce": 1}},
		"Fires {7/7/9} bolts in a fan. Each one passes through an enemy.")
	_s("burst", P, "Rune Burst", "#c9a8ff", {"mp": [8, 15, 40], "dmg": [10, 26, 70], "crit": 0.2, "beh": "burst", "kw": ["blast"], "p": {"area": [30.0, 32.0, 35.0]}},
		"Explodes right at the wand tip. Weak on its own, huge when a carrier delivers it. Breaks armor.")
	_s("moths", P, "Seeker Moths", "#ffd05e", {"mp": [7, 10, 13], "dmg": [6, 10, 18], "p": {"speed": 150, "radius": 2.0, "life": 1.6, "count": [3, 4, 5], "spread": 80.0, "homing": 7.0}},
		"Releases {3/4/5} moths that fly to the nearest enemy.")
	_s("needle", P, "Glitch Needle", "#e8fbff", {"mp": [2, 3, 4], "dmg": [4, 6, 8], "dl": -0.02, "crit": 0.0, "kw": ["pierce"], "p": {"speed": 380, "radius": 1.5, "life": 0.6, "pierce": 2, "crit_add": [0.0, 0.0, 0.15]}},
		"A very fast needle that passes through two enemies. Breaks shields.", "It also gets +15% crit chance.")
	_s("ember", P, "Ember Bolt", "#ff8a3c", {"mp": [6, 8, 11], "dmg": [8, 12, 17], "beh": "bomb", "kw": ["blast"], "p": {"speed": 150, "radius": 3.0, "life": 1.0, "area": [18.0, 21.0, 25.0], "burn": [1, 1, 2]}},
		"A slow fireball that explodes where it lands and sets enemies on fire. Breaks armor.", "Its fire burns twice as hot.")
	_s("spark", P, "Chain Spark", "#fff27a", {"rar": 1, "mp": [5, 7, 9], "dmg": [5, 8, 12], "kw": ["shock"], "p": {"speed": 240, "radius": 2.0, "life": 0.8, "chain": [2, 3, 5]}},
		"On a hit, jumps to a nearby enemy, up to {2/3/5} times. Strips wards.")
	_s("frost", P, "Frost Shard", "#9fe8ff", {"mp": [4, 5, 7], "dmg": [5, 7, 10], "p": {"speed": 220, "radius": 2.0, "life": 0.9, "count": [2, 2, 3], "spread": 16.0, "chill": 1}},
		"Fires {2/2/3} ice shards that slow what they hit.")
	_s("disc", P, "Boomerang Disc", "#c8e6ff", {"mp": [6, 8, 10], "dmg": [9, 13, 19], "beh": "boomerang", "kw": ["pierce"], "p": {"speed": 210, "radius": 3.0, "life": 1.4, "pierce": 99}},
		"Flies out and comes back, cutting through every enemy both ways. Breaks shields.")
	_s("mine", P, "Glitch Mine", "#a060d8", {"mp": [5, 7, 9], "dmg": [22, 34, 52], "beh": "mine", "kw": ["blast"], "p": {"speed": 170, "radius": 3.0, "life": 4.0, "area": [26.0, 30.0, 34.0]}},
		"Lands ahead of you, arms after a moment, and explodes when an enemy comes close. Breaks armor.")
	_s("static", P, "Static Cone", "#8ff0ff", {"mp": [4, 6, 8], "dmg": [8, 12, 17], "beh": "cone", "kw": ["shock"], "p": {"len": 70.0, "arc": 70.0, "static": 1}},
		"An instant cone of lightning in front of you. Charges every enemy it hits. Strips wards.")
	_s("null_orb", P, "Null Orb", "#a060d8", {"rar": 1, "mp": [9, 12, 15], "dmg": [5, 7, 10], "beh": "orb", "p": {"speed": 55, "radius": 5.0, "life": 2.6, "pierce": 99, "pull": 55.0}},
		"A slow orb that pulls enemies in and hits everything it touches 4 times a second.")
	_s("firewall", P, "Firewall", "#ff9a3a", {"rar": 1, "mp": [8, 11, 14], "dmg": [4, 6, 9], "beh": "wall", "p": {"life": [2.5, 3.0, 3.5], "len": 40.0, "burn": 1, "dist": 24.0}},
		"A short wall of fire across your aim for {2.5/3/3.5} s. It blocks enemy shots and burns enemies that cross it.")
	_s("bitrot", P, "Bitrot Spore", "#ff6fd2", {"mp": [6, 8, 10], "dmg": [2, 3, 4], "beh": "cloud", "p": {"speed": 45, "radius": 10.0, "life": 2.6, "pierce": 99, "rot": 1}},
		"A slow cloud that keeps adding Bitrot to enemies inside it. At 5 Bitrot an enemy crashes in a burst.")
	_s("hexcursor", P, "Hex Cursor", "#d6d6ff", {"mp": [2, 3, 4], "dmg": [3, 4, 5], "p": {"speed": 150, "radius": 4.0, "life": 1.4, "mark": 4.0}},
		"A slow reticle that marks the first enemy it touches. Carriers and triggers aim their spell at the mark.")
	# ---- carriers: hold the next shooting spell as a payload ----
	_s("seed", P, "Payload Seed", "#ffe066", {"mp": [1, 2, 3], "dmg": [2, 5, 10], "carry": "seed", "p": {"speed": 190, "radius": 2.0, "life": 0.9}},
		"Carries the shooting spell on its right and releases it where it lands. That spell costs {90/80/60}% of its mana.")
	_s("wheel", P, "Starwheel", "#ffd36b", {"rar": 2, "mp": [12], "dmg": [16], "carry": "wheel", "beh": "wheel", "p": {"speed": 80, "radius": 4.0, "life": 1.6, "pierce": 99}},
		"A spinning star that fires the shooting spell on its right 16 times around it, at half damage. That spell costs 4x mana.")
	_s("ping", P, "Ping", "#8fd8ff", {"rar": 1, "mp": [3, 4, 5], "dmg": [3, 5, 7], "dl": 0.25, "carry": "ping", "beh": "ping"},
		"Instantly reaches the nearest enemy in the room and releases the shooting spell on its right onto it. Slows the wand a little.")
	# ---- boosts: change every shooting spell to their right until the wand recharges ----
	_s("empower", B, "Empower", "#ff7b7b", {"mp": [5]}, "Spells on its right deal +{25/50/100}% damage.")
	_s("quicken", B, "Long Range", "#7cc6ff", {"mp": [2]}, "Spells on its right fly {35/70/140}% faster and last {0.2/0.4/0.7} s longer.")
	_s("seek", B, "Seek", "#6fe3c1", {"rar": 1, "mp": [4]}, "Spells on its right steer toward enemies, {gently/firmly/sharply}.")
	_s("phase", B, "Phase Through", "#d0d0ff", {"mp": [3]}, "Spells on its right pass through {1/2/4} more enemies and break shields.")
	_s("ricochet", B, "Ricochet", "#b9ffb0", {"mp": [2]}, "Spells on its right bounce off walls up to {2/4/8} times.")
	_s("twin", B, "Twin Cast", "#ffa3c4", {"rar": 1, "mp": [0]}, "Spells on its right are cast {1/2/4} extra times. They cost 1.5x mana.")
	_s("heavy", B, "Heavy Rune", "#c8a070", {"mp": [4]}, "Spells on its right deal +{40/60/90}% damage and knock enemies back hard, but fly 30% slower. An enemy knocked into a wall takes half the hit again.")
	_s("wide", B, "Wide Rune", "#b4f0a0", {"mp": [3]}, "Explosions and bolts on its right are {40/70/110}% bigger.")
	_s("keen", B, "Keen Edge", "#ffe0e0", {"mp": [3]}, "Spells on its right get +{15/25/40}% crit chance. A crit deals double damage.")
	_s("mirror", B, "Mirror", "#d6d6ff", {"rar": 1, "mp": [2]}, "Copies the spell on its right: a boost counts twice, a shooting spell is cast twice.")
	_s("split", B, "Branch Rune", "#9cf06a", {"mp": [3]}, "Bolts on its right split into {2/3/4} on their first hit, each at 40% damage.")
	_s("gravity", B, "Gravity Rune", "#b48cff", {"rar": 1, "mp": [3]}, "Spells on its right drag nearby enemies toward their path, with a {light/strong/very strong} pull.")
	_s("orbit", B, "Orbit Rune", "#9fe8ff", {"rar": 1, "mp": [3]}, "Spells on its right circle around you instead of flying off: a shield made of your own magic.")
	_s("reverse", B, "Reverse Rune", "#c2359f", {"mp": [2]}, "Spells on its right fire behind you and deal +60% damage. A second Reverse cancels it.")
	_s("siphon", B, "Siphon Rune", "#72e06a", {"mp": [3]}, "A kill by a spell on its right refunds {30/45/60}% of that spell's mana.")
	# ---- status coats ----
	_s("ember_coat", B, "Ember Coat", "#ff8a3c", {"rar": 1, "mp": [4]}, "Spells on its right set enemies on fire, {hot/hotter/hottest}.")
	_s("frost_coat", B, "Frost Coat", "#9fe8ff", {"rar": 1, "mp": [4]}, "Each hit from a spell on its right chills {once/twice/3 times}. 3 chills freeze an enemy for a moment.")
	_s("static_coat", B, "Static Coat", "#fff27a", {"mp": [4]}, "Spells on its right charge enemies. The next hit on a charged enemy also arcs to a neighbor. Strips wards.")
	_s("rot_coat", B, "Rot Coat", "#ff6fd2", {"mp": [4]}, "Each hit from a spell on its right adds {1/1/2} Bitrot. At 5 Bitrot an enemy crashes in a burst.")
	# ---- draw spells: pull more shooting spells into this one cast ----
	_s("chorus", B, "Chorus", "#ffc94a", {"mp": [0]}, "Casts the {2/3/4} shooting spells on its right together, each a little cheaper, {in a spread/in a spread/all straight ahead}.")
	_s("pipeline", B, "Pipeline", "#8fd8ff", {"rar": 1, "mp": [2]}, "The {3/4/5} shooting spells on its right fire one after another, in a tight line down your aim.")
	# ---- triggers: sit between two spells, the left one fires the right one ----
	_s("then", T, "THEN", "#ffe066", {"mp": [4], "t": "then"}, "Goes between two spells. When the spell on its left ends, the one on its right is cast from there, with +{30/60/120}% of the left one's damage.")
	_s("callback", T, "Callback", "#ffe066", {"rar": 1, "mp": [5], "t": "callback"}, "Goes between two spells. Every hit of the spell on its left casts the one on its right, for {80/65/50}% of its mana, at most every {0.3/0.2/0.1} s.")
	_s("loop", T, "While Loop", "#ffe066", {"mp": [4], "t": "loop"}, "Goes between two spells. While the spell on its left flies, it keeps casting the one on its right, for {70/55/40}% of its mana each time.")
	_s("fork", T, "Fork Bomb", "#ffe066", {"rar": 1, "mp": [6], "t": "fork"}, "Goes between two spells. When the spell on its left ends, the one on its right is cast 4 ways at {35/45/60}% damage, for 4x its mana.")
	_s("finally", T, "Finally", "#ffe066", {"rar": 1, "mp": [4], "t": "finally"}, "Goes between two spells. When the spell on its left kills, the one on its right is cast from the body, up to {1/2/3} {time/times/times}.")
	_s("sleep", T, "Sleep(ms)", "#ffe066", {"mp": [3], "t": "sleep"}, "Goes between two spells. After {0.4/0.3/0.2} s, the spell on its right is cast from wherever the one on its left is.")
	# ---- Debugger runes: they edit the program itself ----
	_s("head", R, "HEAD", "#5ce1ff", {"rar": 1, "mp": [4, 3, 2]}, "Casts a free copy of the wand's first shooting spell, with the boosts active right now.")
	_s("ifelse", R, "IF / ELSE", "#5ce1ff", {"rar": 1, "mp": [2]}, "If an enemy is close, casts the spell on its right and skips the one after it. If not, it skips that spell and casts the next.")
	_s("goto", R, "GOTO 1", "#5ce1ff", {"rar": 2, "mp": [6, 5, 4]}, "Once per cycle, jumps back to slot 1 without recharging. Boosts stay on. Adds 0.3 s of delay.")
	_s("include", R, "#include", "#5ce1ff", {"rar": 2, "mp": [5]}, "The boost on its right powers every spell on the wand, even ones on its left and carried ones. That boost costs 1.5x mana.")
	# ---- familiars: summons that stay out ----
	_s("daemon", F, "Daemon", "#9b7bff", {"rar": 1, "mp": [10, 12, 14], "dmg": [0], "carry": "daemon", "beh": "daemon", "p": {"life": [8.0, 10.0, 12.0], "every": [1.5, 1.2, 0.9]}},
		"Summons a sprite for {8/10/12} s. It circles you and casts the shooting spell on its right every {1.5/1.2/0.9} s. One at a time.")
	_s("turret", F, "Watchdog Turret", "#ffd05e", {"mp": [9, 11, 13], "dmg": [5, 7, 10], "beh": "turret", "p": {"life": 8.0, "every": 0.5, "range": 130.0}},
		"Plants a turret that shoots the nearest enemy for 8 s. Up to two at a time.")
	_s("duck", F, "Rubber Duck", "#ffe066", {"mp": [8, 7, 6], "dmg": [0], "beh": "duck", "p": {"life": 6.0, "soak": [3, 4, 6]}},
		"Drops a decoy that enemies chase and shoot instead of you. It takes {3/4/6} hits. One at a time.")
	# ---- passives: work from any slot ----
	_s("mana_well", S, "Mana Well", "#5ce1ff", {}, "The wand's max mana +{40/80/160}%, and its mana refills {30/60/120}% faster.")
	_s("heatsink", S, "Heat Sink", "#9b7bff", {}, "Cuts the wand's recharge time by {40/70/85}%.")
	_s("watchdog", S, "Watchdog", "#72e06a", {"rar": 1}, "If the wand has not cast for 1 s, its next cast is free.")

	# ---- Compile evolutions (D3): a level-3 spell plus its catalyst, at the forge ----
	_s("storm_protocol", P, "Storm Protocol", "#fff27a", {"rar": 2, "mp": [9], "dmg": [14], "kw": ["shock"], "p": {"speed": 260, "radius": 2.0, "life": 1.0, "chain": 8, "static": 1}},
		"Compiled Chain Spark. Jumps 8 times and charges every enemy it hits.")
	_s("singularity", P, "Singularity Kernel", "#a060d8", {"rar": 2, "mp": [16], "dmg": [12], "beh": "orb", "kw": ["blast"], "p": {"speed": 50, "radius": 7.0, "life": 3.0, "pierce": 99, "pull": 110.0, "implode": 1, "area": 40.0}},
		"Compiled Null Orb. Pulls harder, hits harder, and implodes when it ends.")
	_s("meltdown", P, "Meltdown", "#ff8a3c", {"rar": 2, "mp": [13], "dmg": [24], "beh": "bomb", "kw": ["blast"], "p": {"speed": 150, "radius": 3.5, "life": 1.0, "area": 40.0, "burn": 3}},
		"Compiled Ember Bolt. A huge blast that sets everything in it on fire.")
	_s("absolute_zero", P, "Absolute Zero", "#e6fbff", {"rar": 2, "mp": [9], "dmg": [9], "p": {"speed": 230, "radius": 2.0, "life": 0.9, "count": 5, "spread": 30.0, "chill": 3}},
		"Compiled Frost Shard. Five shards, and each one freezes what it hits.")
	_s("replicator", P, "Self-Replicating Mote", "#8fd8ff", {"rar": 2, "mp": [6], "dmg": [12], "p": {"speed": 270, "radius": 2.0, "life": 1.0, "pierce": 1, "split": 3}},
		"Compiled Arcane Mote. On its first hit it splits into 3 more.")
	_s("exploit_needle", P, "Exploit Needle", "#e8fbff", {"rar": 2, "mp": [5], "dmg": [10], "dl": -0.02, "kw": ["pierce"], "p": {"speed": 400, "radius": 1.5, "life": 0.7, "pierce": 5, "crit_add": 0.5}},
		"Compiled Glitch Needle. Passes through 5 enemies with +50% crit chance.")

	# ---- wands ----
	_w(&"twig", "Twig Wand", 0, 3, 50, 16, 0.1, 0.35, 4, 1, false, "#c8a070", "Quick and light.")
	_w(&"stub", "Stub Staff", 0, 2, 90, 20, 0.22, 0.6, 6, 1, false, "#8a6a3a", "Slow, with a deep mana pool.")
	var w := WandDef.new()
	w.id = &"apprentice"; w.title = "Apprentice Rod"; w.slots = 5; w.max_mana = 80; w.regen = 18; w.cast_delay = 0.12; w.recharge = 0.4; w.scatter = 5
	_wands[w.id] = w
	_w(&"birch", "Birch Switch", 0, 4, 60, 16, 0.1, 0.35, 4, 1, false, "#d8c090", "Fast, but low on mana.")
	_w(&"mirror_rod", "Mirror Rod", 1, 6, 90, 20, 0.14, 0.5, 5, 1, true, "#b8b8ff", "Reads its spells right to left.")
	_w(&"oak", "Old Oak Staff", 0, 8, 140, 24, 0.2, 0.9, 6, 1, false, "#8a6a3a", "Lots of slots, slow to recharge.")
	_w(&"fork_branch", "Fork Branch", 1, 6, 100, 20, 0.25, 0.6, 22, 2, false, "#9ad06a", "Casts two spells at once, in a wide spread.")
	_w(&"crystal", "Crystal Wand", 2, 6, 120, 32, 0.12, 0.4, 3, 1, false, "#8ff0ff", "Deep mana that refills fast.")
	w = WandDef.new()
	w.id = &"harp"; w.title = "Chorus Harp"; w.rarity = 1; w.slots = 7; w.max_mana = 110; w.regen = 20; w.cast_delay = 0.4; w.recharge = 0.5; w.scatter = 60; w.simultaneous = 3; w.color = Color("#6fe3c1")
	w.desc = "Casts three spells at once, in a wide spread."
	_wands[w.id] = w
	_w(&"daemon_rod", "Daemon Rod", 1, 6, 100, 22, 0.14, 0.5, 5, 1, false, "#9b7bff", "Its last slot casts on its own every 3 s.")
	_wands[&"daemon_rod"].background_slot = true
	_w(&"debug_build", "Debug Build", 2, 8, 120, 22, 0.14, 0.55, 5, 1, false, "#5ce1ff", "Debugger runes cost double mana here.")
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
