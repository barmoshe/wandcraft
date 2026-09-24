class_name WandProgram
extends RefCounted
## A wand is a small program read left to right. compile() reads it from the pointer and
## returns the next cast with no side effects. The rules (proven in the prototype):
##  · boosts accumulate and stay until the wand wraps around (recharges)
##  · Chorus draws more shooting spells into this one cast
##  · a trigger (THEN, Callback, While Loop, Fork Bomb) glues its left spell to its right one
##  · carriers (Payload Seed, Starwheel) take the next shooting spell as their payload
##  · payloads start a fresh count scope: Twin Cast and Shatter stop at them
##  · every slot is read at most once per cast, and nesting stops at depth 3

const MAX_GROUPS := 24
const MAX_DEPTH := 3

var wand: WandState
var slots: Array
var n := 0
var ptr := 0
var wrapped := false
var reads := 0
var mana := 0.0
var delay_add := 0.0
var recharge_add := 0.0
var to_draw := 1
var acc: Mods
var cs_mp := 1.0
var cs_scatter := 0.0
var used: PackedInt32Array = []


class Plan:
	extends RefCounted
	var groups: Array[CastNode] = []
	var mana := 0.0
	var delay_add := 0.0
	var recharge_add := 0.0
	var ptr := 0
	var wrapped := false
	var acc: Mods
	var used: PackedInt32Array


static func compile(w: WandState, start_ptr := -1, acc_in: Mods = null) -> Plan:
	var p := WandProgram.new()
	return p._run(w, start_ptr, acc_in)


## One full cycle for the editor preview.
static func preview_cycle(w: WandState) -> Array[Plan]:
	var out: Array[Plan] = []
	var p := 0
	var a := Mods.new()
	for k in 14:
		var c := compile(w, p, a)
		if c.groups.is_empty():
			break
		out.append(c)
		if c.wrapped:
			break
		p = c.ptr
		a = c.acc
	return out


func _run(w: WandState, start_ptr: int, acc_in: Mods) -> Plan:
	wand = w
	slots = w.slots
	n = slots.size()
	ptr = w.ptr if start_ptr < 0 else start_ptr
	acc = (acc_in if acc_in != null else w.acc).copy()
	to_draw = w.def.simultaneous
	var groups: Array[CastNode] = []
	while to_draw > 0 and groups.size() < MAX_GROUPS:
		var c := _draw_cast(0, true)
		if c == null:
			break
		groups.append(c)
		if c.dup:
			groups.append(c)
		to_draw -= 1
	# end of the program reached exactly: this cast closes the cycle
	if not wrapped and not groups.is_empty() and _peek() < 0:
		ptr = 0
		wrapped = true
		acc = Mods.new()
	var plan := Plan.new()
	plan.groups = groups
	plan.mana = roundf(mana)
	plan.delay_add = delay_add
	plan.recharge_add = recharge_add
	plan.ptr = ptr
	plan.wrapped = wrapped
	plan.acc = acc
	plan.used = used
	return plan


func _idx(p: int) -> int:
	return n - 1 - p if wand.def.reverse else p


func _spell_at(i: int) -> SpellDef:
	var s: Variant = slots[i]
	return null if s == null else Catalog.spell(s["id"])


func _active(i: int) -> bool:
	var d := _spell_at(i)
	return d != null and d.kind != SpellDef.Kind.PASSIVE


## Mirror/upgrade-style neighbours could raise a level here; the slice has none yet.
func _level_at(i: int) -> int:
	return mini(3, int(slots[i]["lv"]))


func _peek() -> int:
	for p in range(ptr, n):
		if _active(_idx(p)):
			return _idx(p)
	return -1


func _next(can_wrap: bool) -> int:
	while reads < n:
		if ptr >= n:
			if not can_wrap:
				return -1
			ptr = 0
			wrapped = true
			acc = Mods.new()
		var i := _idx(ptr)
		ptr += 1
		reads += 1
		if _active(i):
			return i
	return -1


func _cost(d: SpellDef, lv: int) -> float:
	return d.mana_at(lv) * acc.mp_mul * acc.cnt_mp * cs_mp


## Draws the payload of a trigger or carrier in its own count scope.
func _draw_payload(depth: int) -> Array:
	var save := acc
	acc = acc.payload_scope()
	var m0 := mana
	var pl := _draw_cast(depth + 1, false)
	acc = save
	return [pl, mana - m0, m0]


func _draw_cast(depth: int, can_wrap: bool) -> CastNode:
	var dup := false
	while true:
		var i := _next(can_wrap)
		if i < 0:
			return null
		var d := _spell_at(i)
		var lv := _level_at(i)
		var reps := 2 if dup else 1
		used.append(i)
		dup = false
		match d.kind:
			SpellDef.Kind.BOOST:
				mana += d.mana_at(lv) * cs_mp
				if d.id == &"mirror":
					dup = true
					continue
				if d.id == &"chorus":
					var k := lv + 1
					to_draw += k * reps
					cs_mp *= [0.8, 0.75, 0.7][lv - 1]
					cs_scatter += 12.0 * k
					continue
				for r in reps:
					Catalog.apply_boost(d.id, acc, lv)
				continue
			SpellDef.Kind.TRIG:
				mana += d.mana_at(lv)   # a trigger with nothing on its left does nothing
				continue
		# a shooting spell
		var c := CastNode.new()
		c.spell = d
		c.level = lv
		c.mods = acc.copy()
		c.mods.scatter += cs_scatter
		c.slot = i
		c.dup = reps > 1
		c.cost = _cost(d, lv)
		mana += c.cost * reps
		delay_add += d.cast_delay
		recharge_add += d.recharge
		if depth < MAX_DEPTH:
			if d.carrier != &"":
				var r := _draw_payload(depth)
				var pl: CastNode = r[0]
				if pl != null:
					var f := 0.0
					if d.carrier == &"seed":
						f = [0.9, 0.8, 0.7][lv - 1]
					elif d.carrier == &"wheel":
						f = 4.0
					mana = r[2] + r[1] * f * reps
					c.trig = d.carrier
					c.trig_level = lv
					c.payload = pl
					c.pay_mana = r[1]
			else:
				var j := _peek()
				if j >= 0 and _spell_at(j).kind == SpellDef.Kind.TRIG:
					var ti := _next(false)
					var td := _spell_at(ti)
					var tlv := _level_at(ti)
					used.append(ti)
					mana += td.mana_at(tlv)
					var r := _draw_payload(depth)
					var pl: CastNode = r[0]
					if pl != null:
						var pm: float = r[1]
						var m0: float = r[2]
						if td.trig == &"callback" or td.trig == &"loop":
							mana = m0   # paid each time it fires
						elif td.trig == &"fork":
							mana = m0 + pm * 4.0
						c.trig = td.trig
						c.trig_level = tlv
						c.payload = pl
						if td.trig == &"callback":
							c.pay_mana = pm * [0.8, 0.65, 0.5][tlv - 1]
						elif td.trig == &"loop":
							c.pay_mana = pm * [0.7, 0.55, 0.4][tlv - 1]
						else:
							c.pay_mana = pm
		return c
	return null
