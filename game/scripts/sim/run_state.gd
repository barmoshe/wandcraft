class_name RunState
extends RefCounted
## Everything a run carries between rooms: map position, wands, bag, relics, gold, HP and
## stats. Pure data, no nodes, so it can be tested headless and saved to JSON when the app
## goes to the background (the run resumes from the room the player was in).

const VERSION := 1
const BAG_MAX := 12
const MAX_WANDS := 3
## Copies of one spell at one level that merge into the next level (D2: 2, since short
## mobile runs rarely find three).
const MERGE_COPIES := 2

var seed_value := 1
var rng := RandomNumberGenerator.new()
var world := 0
var step := 0                       # index into Chapter.PLAN
var path: Array = []                # door kinds taken, for the map strip
var room: Dictionary = {}           # the door that led here: {"kind", "reward"}
var doors: Array = []               # the doors this room will offer once cleared
var hp := 120.0
var max_hp := 120.0
var gold := 0
var wands: Array[WandState] = []
var cur := 0
var bag: Array = []                 # {"id": StringName, "lv": int}
var relics: Array[StringName] = []
var shop: Array = []                # current shop stock (so leaving and coming back keeps it)
var banned: Array[StringName] = []  # spells Deprecated out of this run's offers (D2)
var rare_offset := -0.05            # Slay the Spire-style rarity pacing for spell offers (D2)
var deprecated_here := false        # one Deprecate per shop visit
var map: Array = []                # D5: the 3-lane map (Chapter.make_map), per step an Array of nodes
var lane := 1                       # the lane the player is on
var uptime := 0                     # Uptime relic: rooms in a row cleared without a hit
var stats := {"kills": 0, "damage": 0.0, "rooms": 0, "time": 0.0, "bosses": 0}
var won := false


## Starter loadouts (D2): a small wand with a clear identity, so the first rewards are
## choices about what to put in the empty slots.
const LOADOUTS := {
	&"twig": {"wand": &"twig", "spells": [&"mote", null, null]},
	&"stub": {"wand": &"stub", "spells": [&"ember", null]},
}


static func create(seed_value_: int, loadout := &"twig") -> RunState:
	var r := RunState.new()
	r.seed_value = seed_value_
	r.rng.seed = seed_value_
	var lo: Dictionary = LOADOUTS.get(loadout, LOADOUTS[&"twig"])
	r.wands.append(WandState.make(Catalog.wand(lo["wand"]), lo["spells"]))
	return r


## Pushes relic stats down to the wands (rune cost, nesting depth). Called whenever the
## relics or the wands change, and after a load.
func apply_relics() -> void:
	var rune := Relics.stat(self, "rune")
	var depth := int(Relics.stat(self, "depth"))
	for w in wands:
		w.rune_mul = rune
		w.depth_cap = depth


## Swaps the starting wand for another loadout (the start room's choice).
func set_loadout(loadout: StringName) -> void:
	var lo: Dictionary = LOADOUTS.get(loadout, LOADOUTS[&"twig"])
	wands[0] = WandState.make(Catalog.wand(lo["wand"]), lo["spells"])
	for k in int(Relics.stat(self, "slots")):
		wands[0].slots.append(null)
	cur = 0
	apply_relics()


func wand() -> WandState:
	return wands[cur]


## True if the wand holds at least one shooting spell (so it can actually cast).
static func can_cast(w: WandState) -> bool:
	for s in w.slots:
		if s != null and Catalog.is_caster(Catalog.spell(s["id"])):
			return true
	return false


func has_relic(id: StringName) -> bool:
	return relics.has(id)


func add_relic(id: StringName) -> void:
	if relics.has(id):
		return
	relics.append(id)
	Relics.on_gain(self, id)


## Adds a spell to the bag: putting it in a wand is the player's decision (D2: editing the
## wand is the game). The only exception is a wand that cannot cast at all, which gets the
## spell in its first empty slot. Two copies of the same level merge into the next level.
## Returns false when there is no room at all.
func add_spell(id: StringName, lv := 1) -> bool:
	var entry := {"id": id, "lv": lv}
	var w := wand()
	var empty := w.slots.find(null)
	if empty >= 0 and not can_cast(w) and Catalog.is_caster(Catalog.spell(id)):
		w.slots[empty] = entry
		w.ptr = 0
		w.acc = Mods.new()
	elif bag.size() < BAG_MAX:
		bag.append(entry)
	else:
		return false
	if try_merge(id, lv) > 0 and has_relic(&"version_control"):
		max_hp += 8.0
		hp = minf(max_hp, hp + 8.0)
	return true


## Every place a spell can sit: {"s": entry, "w": wand index or -1 for bag, "i": index}.
func spell_refs() -> Array:
	var out := []
	for wi in wands.size():
		var slots := wands[wi].slots
		for i in slots.size():
			if slots[i] != null:
				out.append({"s": slots[i], "w": wi, "i": i})
	for i in bag.size():
		out.append({"s": bag[i], "w": -1, "i": i})
	return out


## Returns the new level when a merge happened, else 0.
func try_merge(id: StringName, lv: int) -> int:
	if lv >= 3:
		return 0
	var refs := spell_refs().filter(func(r: Dictionary) -> bool: return r["s"]["id"] == id and int(r["s"]["lv"]) == lv)
	if refs.size() < MERGE_COPIES:
		return 0
	# keep a copy that sits in a wand, drop two others (bag copies first)
	refs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["w"] >= 0 and b["w"] < 0)
	var keep: Dictionary = refs[0]
	keep["s"]["lv"] = lv + 1
	var drop := refs.slice(1)
	drop.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["w"] < 0 and b["w"] >= 0)
	var bag_drop := []
	for k in MERGE_COPIES - 1:
		var d: Dictionary = drop[k]
		if d["w"] < 0:
			bag_drop.append(d["s"])
		else:
			wands[d["w"]].slots[d["i"]] = null
	for s in bag_drop:
		bag.erase(s)
	for w in wands:
		w.ptr = 0
		w.acc = Mods.new()
	var deeper := try_merge(id, lv + 1)
	return deeper if deeper > 0 else lv + 1


## Moves or swaps two spell places ("w" = wand index, -1 = bag; "i" = index).
## Moving onto an empty bag index appends. Wand pointers reset (the program changed).
func move_spell(from: Dictionary, to: Dictionary) -> void:
	var a: Variant = _ref_get(from)
	var b: Variant = _ref_get(to)
	if a == null:
		return
	if to["w"] < 0 and b == null:
		_ref_set(from, null)
		bag.append(a)
	else:
		_ref_set(to, a)
		_ref_set(from, b)
	bag = bag.filter(func(s: Variant) -> bool: return s != null)
	for w in wands:
		w.ptr = 0
		w.acc = Mods.new()
		w.cd = 0.0


func _ref_get(r: Dictionary) -> Variant:
	if r["w"] < 0:
		return bag[r["i"]] if r["i"] < bag.size() else null
	return wands[r["w"]].slots[r["i"]]


func _ref_set(r: Dictionary, v: Variant) -> void:
	if r["w"] < 0:
		if r["i"] < bag.size():
			bag[r["i"]] = v
		elif v != null:
			bag.append(v)
	else:
		wands[r["w"]].slots[r["i"]] = v


func add_wand(id: StringName) -> void:
	var w := WandState.make(Catalog.wand(id))
	for k in int(Relics.stat(self, "slots")):
		w.slots.append(null)
	w.rune_mul = Relics.stat(self, "rune")
	w.depth_cap = int(Relics.stat(self, "depth"))
	if wands.size() < MAX_WANDS:
		# a new wand arrives empty: it goes on the belt, the one in hand stays in hand
		wands.append(w)
		return
	# full: the new wand replaces the emptiest wand (never the one in hand if there is a
	# choice), and whatever spells that wand held go to the bag
	var victim := -1
	var fewest := 999
	for i in wands.size():
		var n := wands[i].slots.filter(func(s: Variant) -> bool: return s != null).size()
		if n < fewest or (n == fewest and victim == cur):
			fewest = n
			victim = i
	for s in wands[victim].slots:
		if s != null:
			bag.append(s)
	wands[victim] = w


# ------------------------------------------------------------------ save / load

func to_dict() -> Dictionary:
	var ws := []
	for w in wands:
		ws.append({"id": String(w.def.id), "slots": w.slots.map(_entry_out), "mana": w.mana})
	return {
	# rng_state is a string: JSON numbers are doubles and would round it
		"v": VERSION, "seed": seed_value, "rng_state": str(rng.state), "world": world, "step": step,
		"path": path.map(func(p: Variant) -> String: return String(p)),
		"room": _dict_out(room), "doors": doors.map(_dict_out),
		"hp": hp, "max_hp": max_hp, "gold": gold, "wands": ws, "cur": cur,
		"bag": bag.map(_entry_out), "relics": relics.map(func(r: StringName) -> String: return String(r)),
		"shop": shop.map(_dict_out), "stats": stats.duplicate(), "won": won,
		"banned": banned.map(func(b: StringName) -> String: return String(b)), "rare_offset": rare_offset,
		"uptime": uptime,
		"map": map.map(func(step: Array) -> Array: return step.map(_dict_out)), "lane": lane,
	}


static func from_dict(d: Dictionary) -> RunState:
	if int(d.get("v", 0)) != VERSION:
		return null
	var r := RunState.new()
	r.seed_value = int(d["seed"])
	r.rng.seed = r.seed_value
	r.rng.state = String(d["rng_state"]).to_int()
	r.world = int(d["world"])
	r.step = int(d["step"])
	r.path = (d["path"] as Array).map(func(p: Variant) -> StringName: return StringName(p))
	r.room = _dict_in(d["room"])
	r.doors = (d["doors"] as Array).map(_dict_in)
	r.hp = float(d["hp"])
	r.max_hp = float(d["max_hp"])
	r.gold = int(d["gold"])
	for wd in d["wands"]:
		var w := WandState.make(Catalog.wand(StringName(wd["id"])))
		w.set_slots((wd["slots"] as Array).map(_entry_in))
		w.mana = float(wd["mana"])
		r.wands.append(w)
	r.cur = clampi(int(d["cur"]), 0, r.wands.size() - 1)
	r.bag = (d["bag"] as Array).map(_entry_in).filter(func(e: Variant) -> bool: return e != null)
	for id in d["relics"]:
		if Relics.DEFS.has(StringName(id)):   # relics cut in later versions are dropped
			r.relics.append(StringName(id))
	r.shop = (d["shop"] as Array).map(_dict_in)
	for k in d["stats"]:
		r.stats[k] = d["stats"][k]
	r.won = bool(d.get("won", false))
	for b in d.get("banned", []):
		r.banned.append(StringName(b))
	r.rare_offset = float(d.get("rare_offset", -0.05))
	r.uptime = int(d.get("uptime", 0))
	r.map = (d.get("map", []) as Array).map(func(step: Array) -> Array: return step.map(_dict_in))
	r.lane = int(d.get("lane", 1))
	r.apply_relics()
	return r


static func _entry_out(s: Variant) -> Variant:
	return null if s == null else {"id": String(s["id"]), "lv": int(s["lv"])}


static func _entry_in(s: Variant) -> Variant:
	if s == null:
		return null
	var id := Catalog.resolve(StringName(s["id"]))   # spells cut in the D2 redesign map or drop
	return null if id == &"" else {"id": id, "lv": int(s["lv"])}


## Door / shop dictionaries: StringName values become strings and back.
static func _dict_out(d: Variant) -> Variant:
	if not d is Dictionary:
		return d
	var o := {}
	for k in d:
		var v: Variant = d[k]
		o[String(k)] = String(v) if v is StringName else v
	return o


static func _dict_in(d: Variant) -> Variant:
	if not d is Dictionary:
		return d
	var o := {}
	for k in d:
		var v: Variant = d[k]
		o[String(k)] = StringName(v) if v is String and k in ["kind", "reward", "t", "id"] else v
	return o
