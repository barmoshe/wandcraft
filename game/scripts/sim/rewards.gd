class_name Rewards
extends RefCounted
## Reward offers. Every reward screen is a choice of 3 (plus a skip that pays gold), which
## answers the "a spell room gives one random spell" complaint about the genre.
## Offer items: {"t": spell|relic|wand|gold|heal, "id": StringName, "v": int}

const SKIP_GOLD := 8
const STARTERS: Array[StringName] = [&"fan", &"moths", &"lance", &"ember", &"spark", &"frost", &"needle"]


## Spell pool for drops: every spell with a rarity weight, passives and boosts included.
static func roll_spell(run: RunState, bias := 0, exclude: Array = []) -> StringName:
	var weights := [70.0 - bias * 25.0, 25.0 + bias * 10.0, 5.0 + bias * 15.0]
	var rar := _weighted_index(weights, run.rng)
	var pool: Array = []
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		if d.rarity == rar and not exclude.has(id):
			pool.append(id)
	if pool.is_empty():
		for id in Catalog.spells():
			if not exclude.has(id):
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


static func roll_relics(run: RunState, n: int, min_rar := 0) -> Array:
	var pool: Array = []
	for id in Relics.DEFS:
		if not run.relics.has(id) and int(Relics.DEFS[id]["rar"]) >= min_rar:
			pool.append(id)
	var owned := owned_tags(run)
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var w: Array = pool.map(func(id: StringName) -> float: return tag_weight(Relics.tags(id), owned))
		var i := _weighted_index(w, run.rng)
		out.append(pool[i])
		pool.remove_at(i)
	return out


static func roll_wand(run: RunState, min_rar := 0, exclude: Array = []) -> StringName:
	var pool: Array = []
	for id in Catalog.wands():
		if id == &"apprentice" or exclude.has(id):
			continue
		if Catalog.wand(id).rarity >= min_rar and not run.wands.any(func(w: WandState) -> bool: return w.def.id == id):
			pool.append(id)
	if pool.is_empty():
		pool = [&"birch"]
	return pool[run.rng.randi() % pool.size()]


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
	match kind:
		&"start":
			var s := STARTERS.duplicate()
			_shuffle(s, run.rng)
			return s.slice(0, 3).map(func(id: StringName) -> Dictionary: return {"t": &"spell", "id": id})
		&"spell":
			return _spells(run, [0, 0, 1])
		&"relic":
			return roll_relics(run, 3).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
		&"challenge":
			var r := roll_relics(run, 2, 1).map(func(id: StringName) -> Dictionary: return {"t": &"relic", "id": id})
			r.append(_spells(run, [2])[0])
			return r
		&"wand":
			var w1 := roll_wand(run)
			return [{"t": &"wand", "id": w1}, {"t": &"wand", "id": roll_wand(run, 1, [w1])}, _spells(run, [1])[0]]
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
	return out


static func forge_price(lv: int) -> int:
	return 35 if lv == 1 else 80


## Gives an offer item to the run. False if it could not be taken (bag full).
static func grant(run: RunState, item: Dictionary) -> bool:
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
	return "%d gold" % int(item.get("v", 0))


static func item_desc(item: Dictionary) -> String:
	match item["t"]:
		&"spell":
			return Catalog.spell(item["id"]).desc
		&"relic":
			return Relics.DEFS[item["id"]]["desc"]
		&"wand":
			return wand_desc(Catalog.wand(item["id"]))
		&"heal":
			return "Restores %d HP right away." % int(item.get("v", 0))
	return ""


static func wand_desc(w: WandDef) -> String:
	var bits := ["%d slots" % w.slots, "%d mana" % int(w.max_mana), "cast %.2fs" % w.cast_delay, "recharge %.2fs" % w.recharge]
	if w.simultaneous > 1:
		bits.append("casts %d at once" % w.simultaneous)
	if w.reverse:
		bits.append("reads right to left")
	var txt := ", ".join(bits)
	return txt[0].to_upper() + txt.substr(1) + "."


static func item_rarity(item: Dictionary) -> int:
	match item["t"]:
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
