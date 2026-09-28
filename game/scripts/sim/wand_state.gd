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
## Design v2: the slots the last cast read and when (world time), so the HUD and the editor can
## light them as they fire; and when the wand last could not pay for a cast.
var lit := PackedInt32Array()
var lit_at := -9.0
var dry_at := -9.0
var bonus_mana := 1.0   # max mana multiplier (none since D3 cut Spare Battery; kept for saves)
var rune_mul := 1.0     # Root Access makes Debugger runes free (RunState.apply_relics)
var trig_mul := 1.0     # design v2: the Tinkerer's triggers (and what they release) cost less
var depth_cap := 3      # Stack Overflow lets payloads nest deeper
var fresh := false      # the wand just recharged (Cold Start)
var idle := 0.0         # seconds since this wand last cast (Watchdog)
var bg_t := 3.0         # Daemon Rod: time until the background slot fires
var suspended := -1     # 0.20: a slot an Interrupt holds (the program reads it as empty)
# 0.20 arsenal (research/arsenal-0.20/6-spells-wands.md)
var order := PackedInt32Array()   # Shuffle Play: program position -> slot, redrawn each recharge
var page := 0                     # Double Buffer: the half that plays now (0 or 1)
var cycles := 0                   # recharges so far (Alt+Tab takes turns on it)
var jit_n := 0                    # recharges in this room (Just-in-Time)
var buffer: Array = []            # Buffering: [cast, options] held until the wand recharges
var last_id: StringName = &""     # the last shooting spell this wand cast (Cache Hit)
var cad_at: Dictionary = {}       # Ctrl+Alt+Del: rune slot -> world time it last went off

const RECYCLE_MANA := 12.0
var hoist := false      # 0.20: Tail Boost: a boost in the last slot applies to every spell


static func make(wand: WandDef, ids: Array = []) -> WandState:
	var w := WandState.new()
	w.def = wand
	w.slots.resize(wand.slots)
	for i in mini(ids.size(), wand.slots):
		var id: StringName = Catalog.resolve(StringName(ids[i])) if ids[i] != null else &""
		w.slots[i] = null if id == &"" else {"id": id, "lv": 1}
	w.mana = w.max_mana()
	return w


## One more empty slot, on the left end: spells sit on the right (the start spell in the
## last slot, as in Magicraft), so new room opens where boosts go.
func add_slot() -> void:
	slots.push_front(null)
	ptr = 0
	acc = Mods.new()


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


## Regen multiplier from passives (Mana Well; Virtual Memory refills 30% slower below zero).
func regen_mul() -> float:
	var well := passive_level(&"mana_well")
	var k: float = 1.0 + [0.0, 0.3, 0.6, 1.2][well]
	if mana < 0.0:
		k *= 0.7
	return k


## Virtual Memory: how far below zero this wand may keep casting.
func debt() -> float:
	return [0.0, 20.0, 35.0, 50.0][mini(3, passive_level(&"virtual_memory"))]


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


# ---- the order the program reads the slots in (0.20 wand rules) ----

## Slots the program walks: all but a Daemon Rod's background slot.
func phys_len() -> int:
	return slots.size() - (1 if def.background_slot and slots.size() > 1 else 0)


## Double Buffer: slots per page (the first page takes the odd one out).
func page_size() -> int:
	return (phys_len() + 1) / 2


## Program positions in one pass: a Palindrome Staff reads there and back (2n - 2), a Double
## Buffer only its current page.
func prog_len() -> int:
	var m := phys_len()
	match def.rule:
		&"palindrome":
			return 2 * m - 2 if m > 2 else m
		&"pages":
			return page_size() if page == 0 else m - page_size()
	return m


## The slot read at program position p.
func slot_at(p: int) -> int:
	var m := phys_len()
	match def.rule:
		&"palindrome":
			return p if p < m else 2 * m - 2 - p
		&"pages":
			return p + (page_size() if page == 1 else 0)
		&"shuffle":
			if order.size() == m:
				return order[p]
	return m - 1 - p if def.reverse else p


## Where slot i comes in the program (0-based), or -1 when it is not read now (held out, or
## on the other page). The editor numbers the slots with it.
func read_pos(i: int) -> int:
	if held().has(i):
		return -1
	for p in prog_len():
		if slot_at(p) == i:
			return p
	return -1


## Slots out of the program: Pinned Tab's slot 1 (it joins every cast instead), and each
## Ctrl+Alt+Del rune with the spell on its right (that one waits for you to be hit).
func held() -> Dictionary:
	var out := {}
	if def.rule == &"pinned" and phys_len() > 1:
		out[0] = true
	for pr in cad_pairs():
		out[pr[0]] = true
		if pr[1] >= 0:
			out[pr[1]] = true
	return out


## Ctrl+Alt+Del: [rune slot, the slot it holds (-1: none), level] in program order.
func cad_pairs() -> Array:
	var out: Array = []
	var n := prog_len()
	var seen := {}
	for p in n:
		var i := slot_at(p)
		var s: Variant = slots[i]
		if s == null or s["id"] != &"ctrl_alt_del" or seen.has(i):
			continue
		seen[i] = true
		var held_i := -1
		for q in range(p + 1, n):
			var j := slot_at(q)
			if slots[j] != null and slots[j]["id"] != &"ctrl_alt_del":
				held_i = j
				break
		out.append([i, held_i, mini(3, int(s["lv"]))])
	return out


## The wand just recharged: count it, and apply a rule that changes the next pass.
func on_wrap(rng: RandomNumberGenerator) -> void:
	cycles += 1
	jit_n += 1
	match def.rule:
		&"shuffle":
			var m := phys_len()
			order.resize(m)
			for k in m:
				order[k] = k
			for k in range(m - 1, 0, -1):
				var j := rng.randi_range(0, k)
				var t := order[k]
				order[k] = order[j]
				order[j] = t
		&"pages":
			page = 1 - page


## A new room: Just-in-Time starts over, held casts are dropped, a Recycle Bin starts full.
func new_room() -> void:
	jit_n = 0
	buffer.clear()
	cad_at.clear()
	if def.rule == &"recycle":
		mana = max_mana()


## Recycle Bin: every kill refills it a little.
func on_kill() -> void:
	if def.rule == &"recycle":
		mana = minf(max_mana(), mana + RECYCLE_MANA)
