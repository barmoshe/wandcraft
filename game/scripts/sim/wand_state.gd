class_name WandState
extends RefCounted
## A wand in the player's hands: its slots and its running state.

var def: WandDef
var slots: Array = []        # each entry: null or {"id": StringName, "lv": int}
var mana := 0.0
var ptr := 0
var cd := 0.0
var rech := 0.0
var rech_max := 0.5
var acc := Mods.new()
var casts := 0
var flash := -1


static func make(wand: WandDef, ids: Array = []) -> WandState:
	var w := WandState.new()
	w.def = wand
	w.slots.resize(wand.slots)
	for i in mini(ids.size(), wand.slots):
		w.slots[i] = null if ids[i] == null else {"id": StringName(ids[i]), "lv": 1}
	w.mana = w.max_mana()
	return w


func set_slots(entries: Array) -> void:
	slots.resize(maxi(entries.size(), def.slots))
	for i in slots.size():
		var e: Variant = entries[i] if i < entries.size() else null
		if e == null:
			slots[i] = null
		elif e is Dictionary:
			slots[i] = {"id": StringName(e["id"]), "lv": int(e.get("lv", 1))}
		else:
			slots[i] = {"id": StringName(e), "lv": 1}
	ptr = 0
	acc = Mods.new()


func passive_level(id: StringName) -> int:
	for s in slots:
		if s != null and s["id"] == id:
			return s["lv"]
	return 0


func max_mana() -> float:
	var m := def.max_mana
	var cache := passive_level(&"cache")
	if cache > 0:
		m *= 1.0 + [0.4, 0.8, 1.6][cache - 1]
	return m


func recharge_time() -> float:
	var r := def.recharge
	var sink := passive_level(&"heatsink")
	if sink > 0:
		r *= [0.6, 0.3, 0.15][sink - 1]
	return r
