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
var bonus_mana := 1.0   # max mana multiplier (none since D3 cut Spare Battery; kept for saves)
var rune_mul := 1.0     # Root Access makes Debugger runes free (RunState.apply_relics)
var depth_cap := 3      # Stack Overflow lets payloads nest deeper
var fresh := false      # the wand just recharged (Cold Start)
var idle := 0.0         # seconds since this wand last cast (Watchdog)
var bg_t := 3.0         # Daemon Rod: time until the background slot fires


static func make(wand: WandDef, ids: Array = []) -> WandState:
	var w := WandState.new()
	w.def = wand
	w.slots.resize(wand.slots)
	for i in mini(ids.size(), wand.slots):
		var id: StringName = Catalog.resolve(StringName(ids[i])) if ids[i] != null else &""
		w.slots[i] = null if id == &"" else {"id": id, "lv": 1}
	w.mana = w.max_mana()
	return w


func set_slots(entries: Array) -> void:
	slots.resize(maxi(entries.size(), def.slots))
	for i in slots.size():
		var e: Variant = entries[i] if i < entries.size() else null
		if e == null:
			slots[i] = null
		elif e is Dictionary:
			var rid := Catalog.resolve(StringName(e["id"]))
			slots[i] = null if rid == &"" else {"id": rid, "lv": int(e.get("lv", 1))}
		else:
			var rid2 := Catalog.resolve(StringName(e))
			slots[i] = null if rid2 == &"" else {"id": rid2, "lv": 1}
	ptr = 0
	acc = Mods.new()


func passive_level(id: StringName) -> int:
	for s in slots:
		if s != null and s["id"] == id:
			return s["lv"]
	return 0


func max_mana() -> float:
	var m := def.max_mana * bonus_mana
	var well := passive_level(&"mana_well")
	if well > 0:
		m *= 1.0 + [0.4, 0.8, 1.6][well - 1]
	return m


## Regen multiplier from passives (Mana Well).
func regen_mul() -> float:
	var well := passive_level(&"mana_well")
	return 1.0 + ([0.0, 0.3, 0.6, 1.2][well])


## The spell in a Daemon Rod's background slot, if any.
func background() -> Variant:
	if not def.background_slot or slots.size() < 2:
		return null
	return slots[slots.size() - 1]


func recharge_time() -> float:
	var r := def.recharge
	var sink := passive_level(&"heatsink")
	if sink > 0:
		r *= [0.6, 0.3, 0.15][sink - 1]
	return r
