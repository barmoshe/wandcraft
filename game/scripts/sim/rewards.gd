class_name Rewards
extends RefCounted
## Reward offers. Every reward screen is a choice of 3 (plus a skip that pays gold), which
## answers the "a spell room gives one random spell" complaint about the genre.
## Offer items: {"t": spell|relic|wand|gold|heal|loadout|slot, "id": StringName, "v": int}

const SKIP_GOLD := 8
const SLOT_PRICE := 60        # Forge: +1 slot on the wand in hand (D2)
const SLOT_MAX := 10
const ALTAR_COST := 0.15      # share of max HP an Altar pick costs (D5)
const LOADOUT_TEXT := {
	&"twig": "Quick and light. An Arcane Mote in the last slot, and two empty slots on its left for boosts.",
	&"stub": "Slow, with a deep mana pool. An Ember Bolt in the last slot, and one empty slot on its left.",
}


## Spell pool for drops: every spell with a rarity weight, passives and boosts included.
## Epic odds follow a pacing offset (D2): +1% for every common rolled, reset on an epic,
## so a dry spell always ends. Spells Deprecated at a shop never come back this run.
static func roll_spell(run: RunState, bias := 0, exclude: Array = []) -> StringName:
	var weights := [70.0 - bias * 25.0, 25.0 + bias * 10.0, 5.0 + bias * 15.0 + run.rare_offset * 100.0]
	var rar := _weighted_index(weights, run.rng)
	if rar == 2:
		run.rare_offset = -0.05
	elif rar == 0:
		run.rare_offset = minf(0.40, run.rare_offset + 0.01)
	var pool: Array = []
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		if d.rarity == rar and not exclude.has(id) and not run.banned.has(id) and not Catalog.is_evolved(id) and not Meta.is_locked(id):
			pool.append(id)
	if pool.is_empty():
		for id in Catalog.spells():
			if not exclude.has(id) and not run.banned.has(id) and not Catalog.is_evolved(id) and not Meta.is_locked(id):
				pool.append(id)
	var owned := owned_tags(run)
	var w: Array = pool.map(func(id: StringName) -> float: return tag_weight(Catalog.tags(id), owned))
	return pool[_weighted_index(w, run.rng)]


## Tag counts over everything the run holds: spells in wands and the bag, and relics.
static func owned_tags(run: RunState) -> Dictionary:
	var out := {}
	var add := func(tags: Array) -> void:
		for t in tags:
			out[t] = int(out.get(t, 0)) + 1
	for wd in run.wands:
		for sl in wd.slots:
			if sl != null:
				add.call(Catalog.tags(sl["id"]))
	for it in run.bag:
		add.call(Catalog.tags(it["id"]))
	for r in run.relics:
		add.call(Relics.tags(r))
	return out


## x1.6 per tag the run already has, capped at x2.5: builds take shape without being forced.
static func tag_weight(tags: Array, owned: Dictionary) -> float:
	var k := 1.0
	for t in tags:
		if owned.has(t):
			k *= 1.6
	return minf(k, 2.5)


## Relics to offer. A Merge Commit whose parents you own is three times as likely; Corrupted
## relics only come from the Glitch Door (corrupted = true).
static func roll_relics(run: RunState, n: int, min_rar := 0, corrupted := false) -> Array:
	var pool: Array = []
	for id in Relics.DEFS:
		if Relics.offerable(run, id, corrupted) and int(Relics.DEFS[id]["rar"]) >= min_rar and not Meta.is_locked(id):
			pool.append(id)
	var owned := owned_tags(run)
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var w: Array = pool.map(func(id: StringName) -> float: return tag_weight(Relics.tags(id), owned) * (3.0 if Relics.DEFS[id].has("duo") else 1.0))
		var i := _weighted_index(w, run.rng)
		out.append(pool[i])
		pool.remove_at(i)
	return out


static func roll_wand(run: RunState, min_rar := 0, exclude: Array = []) -> StringName:
	var pool: Array = []
	for id in Catalog.wands():
		if id == &"apprentice" or exclude.has(id) or Meta.is_locked(id):
			continue
		if Catalog.wand(id).rarity >= min_rar and not run.wands.any(func(w: WandState) -> bool: return w.def.id == id):
			pool.append(id)
	if pool.is_empty():
		pool = [&"birch"]
	return pool[run.rng.randi() % pool.size()]


## The resist keywords the run can already answer with (1 pierce, 2 blast, 4 shock).
static func owned_keywords(run: RunState) -> int:
	var k := 0
	for r in run.spell_refs():
		k |= SpellRunner.keywords(Catalog.spell(r["s"]["id"]), Mods.new())
	return k


## D4 counter guarantee: when the run cannot answer a shield, armour or ward yet, one of
## the three spell offers carries a keyword it is missing (the last card, so a fair pick).
static func _with_counter(run: RunState, offer: Array) -> Array:
	var have := owned_keywords(run)
	var covered := have
	for it in offer:
		covered |= SpellRunner.keywords(Catalog.spell(it["id"]), Mods.new())
	if covered == 7:
		return offer
	var pool: Array = []
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		if Catalog.is_evolved(id) or run.banned.has(id) or offer.any(func(it: Dictionary) -> bool: return it["id"] == id):
			continue
		if SpellRunner.keywords(d, Mods.new()) & ~covered & 7 and d.rarity <= 1:
			pool.append(id)
	if pool.is_empty():
		return offer
	offer[offer.size() - 1] = {"t": &"spell", "id": pool[run.rng.randi() % pool.size()]}
	return offer


## Three spells, no duplicates.
static func _spells(run: RunState, biases: Array) -> Array:
	var out: Array = []
	var seen: Array = []
	for b in biases:
		var id := roll_spell(run, b, seen)
		seen.append(id)
		out.append({"t": &"spell", "id": id})
	return out


static func offer(run: RunState, kind: StringName) -> Array:
	if kind == &"spell" and Tutorial.active(run):
		return Tutorial.offer(run)
	match kind:
		&"start":
			# a start still locked in the Codex is shown, greyed, so the player knows it exists
			return RunState.LOADOUTS.keys().map(func(id: StringName) -> Dictionary:
				return {"t": &"loadout", "id": id, "locked": Meta.is_locked(id)})
		&"spell":
			return _with_counter(run, _spells(run, [0, 0, 1]))
		&"relic":
			return roll_relics(run, 3).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
		&"challenge":
			var r := roll_relics(run, 2, 1).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
			r.append(_spells(run, [2])[0])
			return r
		&"wand":
			var w1 := roll_wand(run)
			return [{"t": &"wand", "id": w1}, {"t": &"wand", "id": roll_wand(run, 1, [w1])}, _spells(run, [1])[0]]
		&"secret":
			# behind a cracked wall: a relic, a spell leaning rare, and a purse
			var sec: Array = roll_relics(run, 1).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
			sec.append(_spells(run, [1])[0])
			sec.append({"t": &"gold", "id": &"gold", "v": 30})
			return sec
		&"altar":
			# power for blood: every pick here costs 15% max HP (Rewards.grant pays it)
			var alt: Array = _spells(run, [2, 2]).map(func(it: Dictionary) -> Dictionary:
				it["hp_cost"] = ALTAR_COST
				return it)
			var ar := roll_relics(run, 1, 1)
			if not ar.is_empty():
				alt.append({"t": &"relic", "id": ar[0], "hp_cost": ALTAR_COST})
			return alt
		&"terminal":
			# the Debug Terminal: a patch of your choice
			return [{"t": &"slot", "id": &"slot"}, {"t": &"gold", "id": &"gold", "v": 40}, {"t": &"heal", "id": &"heal", "v": 35}]
		&"glitch":
			var g := roll_relics(run, 2, 0, true).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
			g.append(_spells(run, [2])[0])
			return g
		&"mini":
			var r := roll_relics(run, 2).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
			r.append(_spells(run, [2])[0])
			return r
		&"boss":
			var out: Array = [{"t": &"wand", "id": roll_wand(run, 1)}, _spells(run, [2])[0]]
			var rl := roll_relics(run, 1, 1)
			if not rl.is_empty():
				out.append({"t": &"relic", "id": rl[0]})
			return out
	return _spells(run, [0, 0, 1])


## Shop stock: four spells (one leaning rare), a relic, a heal and a wand.
static func shop_stock(run: RunState) -> Array:
	var out: Array = []
	var seen: Array = []
	for k in 4:
		var id := roll_spell(run, 1 if k == 3 else 0, seen)
		seen.append(id)
		out.append({"t": &"spell", "id": id, "price": [22, 45, 90][Catalog.spell(id).rarity], "sold": false})
	var rl := roll_relics(run, 1)
	if not rl.is_empty():
		out.append({"t": &"relic", "id": rl[0], "price": 70 + 30 * int(Relics.DEFS[rl[0]]["rar"]), "sold": false})
	out.append({"t": &"heal", "id": &"heal", "v": 35, "price": 25, "sold": false})
	var wid := roll_wand(run)
	out.append({"t": &"wand", "id": wid, "price": 65 + 25 * Catalog.wand(wid).rarity, "sold": false})
	# Bug Reports 4+: scope creep, everything costs a quarter more
	if run.heat >= 4:
		for it in out:
			it["price"] = roundi(int(it["price"]) * 1.25)
	run.deprecated_here = false
	return out


static func forge_price(lv: int) -> int:
	return 35 if lv == 1 else 80


## Gives an offer item to the run. False if it could not be taken (bag full).
static func grant(run: RunState, item: Dictionary) -> bool:
	if item.get("locked", false):
		return false
	if item.has("hp_cost"):
		run.max_hp = maxf(20.0, roundf(run.max_hp * (1.0 - float(item["hp_cost"]))))
		run.hp = minf(run.hp, run.max_hp)
	match item["t"]:
		&"spell":
			return run.add_spell(item["id"])
		&"relic":
			run.add_relic(item["id"])
		&"wand":
			run.add_wand(item["id"])
		&"gold":
			run.gold += int(item.get("v", 0))
		&"heal":
			run.hp = minf(run.max_hp, run.hp + float(item.get("v", 0)))
		&"loadout":
			run.set_loadout(item["id"])
		&"slot":
			var w := run.wand()
			if w.slots.size() >= SLOT_MAX:
				return false
			w.add_slot()
	return true


static func item_title(item: Dictionary) -> String:
	match item["t"]:
		&"spell":
			return Catalog.spell(item["id"]).title
		&"relic":
			return Relics.DEFS[item["id"]]["title"]
		&"wand":
			return Catalog.wand(item["id"]).title
		&"heal":
			return "Heal %d" % int(item.get("v", 0))
		&"loadout":
			return Catalog.wand(RunState.LOADOUTS[item["id"]]["wand"]).title
		&"compile":
			return Catalog.spell(item["id"]).title
		&"slot":
			return "+1 Slot"
	return "%d gold" % int(item.get("v", 0))


## The item's text. lv: the level a spell's numbers are shown at (see level_after).
static func item_desc(item: Dictionary, lv := 1) -> String:
	return _desc(item, lv)


## The level a spell will have once taken: each copy you hold at the level it reaches merges
## with it (two copies make the next level, up to 3).
static func level_after(run: RunState, id: StringName) -> int:
	var lv := 1
	if run == null or RunState.MERGE_COPIES != 2:
		return lv
	while lv < 3 and run.spell_refs().any(func(r: Dictionary) -> bool: return r["s"]["id"] == id and int(r["s"]["lv"]) == lv):
		lv += 1
	return lv


static func _desc(item: Dictionary, lv := 1) -> String:
	match item["t"]:
		&"spell":
			return Catalog.spell(item["id"]).text_at(lv)
		&"relic":
			var d: Dictionary = Relics.DEFS[item["id"]]
			if d.has("duo"):
				return "%s (from %s + %s)" % [d["desc"], Relics.DEFS[d["duo"][0]]["title"], Relics.DEFS[d["duo"][1]]["title"]]
			return d["desc"]
		&"wand":
			return wand_desc(Catalog.wand(item["id"]))
		&"heal":
			return "Restores %d HP right away." % int(item.get("v", 0))
		&"loadout":
			return LOADOUT_TEXT.get(item["id"], "")
		&"compile":
			var ev: Dictionary = Catalog.EVOLUTIONS[item["id"]]
			var cat: String = Relics.DEFS[ev["cat"]]["title"] if ev["cat_t"] == &"relic" else Catalog.spell(ev["cat"]).title
			return "%s Uses up your level-3 %s%s." % [Catalog.spell(item["id"]).desc, Catalog.spell(ev["base"]).title,
				"" if ev["cat_t"] == &"relic" else " and one %s" % cat]
		&"slot":
			return "Adds one empty slot to the left end of the wand in your hand (up to %d)." % SLOT_MAX
	return ""


## "Quick and light. 3 slots, 50 mana. Casts every 0.1 s, recharges in 0.35 s."
static func wand_desc(w: WandDef) -> String:
	var nums := "%d slots, %d mana. Casts every %s s, recharges in %s s." % [w.slots, int(w.max_mana), _secs(w.cast_delay), _secs(w.recharge)]
	return (w.desc + " " if w.desc != "" else "") + nums


## 0.1 not 0.10, 0.35 as is.
static func _secs(t: float) -> String:
	return String.num(snappedf(t, 0.01))


static func item_rarity(item: Dictionary) -> int:
	match item["t"]:
		&"loadout", &"slot":
			return 0
		&"compile":
			return 2
		&"spell":
			return Catalog.spell(item["id"]).rarity
		&"relic":
			return int(Relics.DEFS[item["id"]]["rar"])
		&"wand":
			return Catalog.wand(item["id"]).rarity
	return 0


static func _weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(1.0, w)
	var x := rng.randf() * total
	for i in weights.size():
		x -= maxf(1.0, weights[i])
		if x <= 0.0:
			return i
	return weights.size() - 1


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t


# ------------------------------------------------------------------ Compile (D3)

## Evolutions the run can compile right now: the base spell at level 3 in a wand or the
## bag, and the catalyst owned (a relic) or carried (a spell, which is used up).
static func compilable(run: RunState) -> Array:
	var out: Array = []
	for evo in Catalog.EVOLUTIONS:
		var ev: Dictionary = Catalog.EVOLUTIONS[evo]
		if _ref_of(run, ev["base"], 3).is_empty():
			continue
		if ev["cat_t"] == &"relic" and not run.has_relic(ev["cat"]):
			continue
		if ev["cat_t"] == &"spell" and _ref_of(run, ev["cat"], 1).is_empty():
			continue
		out.append(evo)
	return out


static func _ref_of(run: RunState, id: StringName, min_lv: int) -> Dictionary:
	for r in run.spell_refs():
		if r["s"]["id"] == id and int(r["s"]["lv"]) >= min_lv:
			return r
	return {}


## Turns the level-3 base spell into its evolution, in place (and uses up a spell catalyst).
static func compile_evo(run: RunState, evo: StringName) -> bool:
	if not compilable(run).has(evo):
		return false
	var ev: Dictionary = Catalog.EVOLUTIONS[evo]
	var base := _ref_of(run, ev["base"], 3)
	base["s"]["id"] = evo
	base["s"]["lv"] = 3
	if ev["cat_t"] == &"spell":
		var cat := _ref_of(run, ev["cat"], 1)
		if cat["w"] < 0:
			run.bag.remove_at(cat["i"])
		else:
			run.wands[cat["w"]].slots[cat["i"]] = null
	for w in run.wands:
		w.ptr = 0
		w.acc = Mods.new()
	return true


## "Enables" chips for an offer card (D3): what this item would switch on with what the
## run already has. Short strings, shown as chips.
static func enables(run: RunState, item: Dictionary) -> Array:
	var out: Array = []
	var owned: Array = run.spell_refs().map(func(r: Dictionary) -> StringName: return r["s"]["id"])
	match item["t"]:
		&"relic":
			var duo := Relics.completes_duo(run, item["id"])
			if duo != &"":
				out.append("Merge Commit")
			for evo in Catalog.EVOLUTIONS:
				var ev: Dictionary = Catalog.EVOLUTIONS[evo]
				if ev["cat"] == item["id"] and owned.has(ev["base"]):
					out.append("Compile")
		&"spell":
			var id: StringName = item["id"]
			var fire := [&"ember", &"ember_coat", &"firewall"]
			var ice := [&"frost", &"frost_coat"]
			if ice.has(id) and fire.any(func(f: StringName) -> bool: return owned.has(f)):
				out.append("Thermal Shock")
			if fire.has(id) and ice.any(func(f: StringName) -> bool: return owned.has(f)):
				out.append("Thermal Shock")
			for evo in Catalog.EVOLUTIONS:
				var ev: Dictionary = Catalog.EVOLUTIONS[evo]
				if ev["cat"] == id and owned.has(ev["base"]):
					out.append("Compile")
				elif ev["base"] == id and (run.has_relic(ev["cat"]) or owned.has(ev["cat"])):
					out.append("Compile at L3")
	var seen: Array = []
	for t in out:
		if not seen.has(t):
			seen.append(t)
	return seen
