class_name WandPlanner
extends RefCounted
## A greedy wand editor for the balance bot (D2). It moves spells between the bag and the
## wand in hand, and reorders the wand, while a rough damage-per-second estimate improves.
## Not a player's brain: a fair stand-in for someone who edits, so the bench can compare an
## editing bot with one that never edits (research/design-plan.md, D4 exit).
## Pure data like the rest of sim/: it reads the compiled program, never the world.

const ACCURACY := 0.8          # share of plain bolts that land
const MIN_GAIN := 1.02         # an edit must beat the current score by 2%


## Rough damage per second of the wand's full rotation, scaled down when the wand cannot pay
## for it (regen over the rotation plus a share of the pool).
static func score(w: WandState, run: RunState = null) -> float:
	var plans := WandProgram.preview_cycle(w)
	if plans.is_empty():
		return 0.0
	var cost := 0.0
	var t := 0.0
	for plan: WandProgram.Plan in plans:
		cost += plan.mana
		t += maxf(0.03, w.def.cast_delay + plan.delay_add)
		if plan.wrapped:
			t += maxf(0.03, w.recharge_time() + plan.recharge_add)
	var dmg := 0.0
	for plan: WandProgram.Plan in plans:
		for g in plan.groups:
			dmg += node_value(g, t)
	var regen := w.def.regen * w.regen_mul() * (Relics.mana_regen_mul(run) if run else 1.0)
	var budget := regen * t + w.max_mana() * t / 25.0
	var sustain := minf(1.0, budget / maxf(1.0, cost))
	# D4: a wand that can break shields, armour and wards is worth more than raw numbers say
	var kw := 0
	for plan: WandProgram.Plan in plans:
		for g in plan.groups:
			kw |= _kw_tree(g)
	var answers := int(kw & 1 != 0) + int(kw & 2 != 0) + int(kw & 4 != 0)
	return dmg / maxf(0.05, t) * sustain * (1.0 + 0.2 * answers)


static func _kw_tree(c: CastNode) -> int:
	var k := SpellRunner.keywords(c.spell, c.mods)
	if c.payload:
		k |= _kw_tree(c.payload)
	if c.alt:
		k |= _kw_tree(c.alt)
	return k


## Expected damage of one compiled cast (and everything it releases). `t` is the rotation
## time, which caps what a familiar adds before the next one replaces it.
static func node_value(c: CastNode, t := 1.0) -> float:
	if c.cond:
		var near := _own_value(c, t)
		var far := node_value(c.alt, t) if c.alt else 0.0
		return (near + far) * 0.5
	return _own_value(c, t)


static func _own_value(c: CastNode, t: float) -> float:
	var d := c.spell
	var m := c.mods
	var lv := c.level
	if d.kind == SpellDef.Kind.FAMILIAR:
		var life := float(d.param("life", lv, 8.0))
		var every := float(d.param("every", lv, 1.0))
		var cap := float(SpellRunner.CAPS.get(d.behavior, 1))
		var shots := minf(life, t * cap) / maxf(0.1, every)
		match d.behavior:
			&"turret":
				return d.damage_at(lv) * m.dmg * shots * 0.6
			&"daemon":
				return (node_value(c.payload, t) if c.payload else 4.0) * shots * 0.7
		return 3.0   # the duck saves hits, not damage
	var v := d.damage_at(lv) * m.dmg
	v *= float(d.param("count", lv, 1)) * (1 + m.multi)
	v *= 1.0 + minf(1.0, d.crit + m.crit + float(d.param("crit_add", lv, 0.0)))
	var instant := d.behavior in [&"beam", &"burst", &"cone"]
	v *= 1.0 if instant or m.home > 0.0 or float(d.param("homing", lv, 0.0)) > 0.0 else ACCURACY
	match d.behavior:
		&"burst", &"bomb", &"mine", &"cone":
			v *= 1.6 * sqrt(m.area)
		&"orb", &"cloud":
			v *= 3.0
		&"wall":
			v *= 2.0
		&"wheel", &"boomerang":
			v *= 1.5
	v *= 1.0 + 0.25 * minf(3.0, float(d.param("pierce", lv, 0)) + m.pierce)
	v *= 1.0 + 0.5 * float(d.param("chain", lv, 0))
	v *= 1.0 + 0.3 * m.split
	if m.burn > 0 or int(d.param("burn", lv, 0)) > 0:
		v += 8.0 * maxi(m.burn, int(d.param("burn", lv, 0)))
	if m.chill > 0:
		v += 2.0
	if m.rot > 0 or int(d.param("rot", lv, 0)) > 0:
		v += 5.0
	if m.static_on:
		v *= 1.1
	if m.reverse:
		v *= 0.3   # it goes where you are not aiming
	if m.orbit:
		v *= 0.6
	if c.payload:
		var pv := node_value(c.payload, t)
		var i := clampi(c.trig_level, 1, 3) - 1
		match c.trig:
			&"then":
				pv += d.damage_at(lv) * m.dmg * SpellRunner.THEN_ADD[i]
			&"fork":
				pv *= 4.0 * SpellRunner.FORK_MUL[i]
			&"wheel":
				pv *= SpellRunner.WHEEL_SHOTS * 0.5 * 0.4
			&"loop":
				pv *= maxf(1.0, float(d.param("life", lv, 1.0)) / SpellRunner.LOOP_EVERY) * 0.4
			&"callback":
				pv *= 1.0 + 0.5 * minf(3.0, float(d.param("pierce", lv, 0)) + m.pierce)
			&"finally":
				pv *= 0.3
		v += pv
	return v


## Edits the wand in hand in place: bag <-> slot swaps and slot reorders, keeping each one
## that raises the score. Returns true when anything changed.
static func improve(run: RunState, passes := 3) -> bool:
	var w := run.wand()
	var best := score(w, run)
	var changed := false
	for p in passes:
		var improved := false
		for bi in run.bag.size():
			for i in w.slots.size():
				var a: Variant = w.slots[i]
				var b: Variant = run.bag[bi]
				if b == null:
					continue
				w.slots[i] = b
				run.bag[bi] = a
				var sc := score(w, run)
				if sc > best * MIN_GAIN:
					best = sc
					improved = true
				else:
					w.slots[i] = a
					run.bag[bi] = b
		for i in w.slots.size():
			for j in range(i + 1, w.slots.size()):
				if w.slots[i] == null and w.slots[j] == null:
					continue
				var t: Variant = w.slots[i]
				w.slots[i] = w.slots[j]
				w.slots[j] = t
				var sc2 := score(w, run)
				if sc2 > best * MIN_GAIN:
					best = sc2
					improved = true
				else:
					w.slots[j] = w.slots[i]
					w.slots[i] = t
		changed = changed or improved
		if not improved:
			break
	run.bag = run.bag.filter(func(s: Variant) -> bool: return s != null)
	w.ptr = 0
	w.acc = Mods.new()
	return changed


## The offer item an editing player would take: the spell that raises the planned score
## most, a wand with more slots, else the first relic.
static func pick(run: RunState, offer: Array) -> int:
	var best := 0
	var best_v := -1.0
	for k in offer.size():
		var it: Dictionary = offer[k]
		var v := 0.0
		match it["t"]:
			&"loadout":
				v = 1.0 if it["id"] == &"twig" else 0.5
			&"relic":
				v = 1000.0
			&"wand":
				v = 500.0 + Catalog.wand(it["id"]).slots * 10.0 if Catalog.wand(it["id"]).slots > run.wand().slots.size() else 0.0
			&"spell":
				v = _try_spell(run, it["id"])
		if v > best_v:
			best_v = v
			best = k
	return best


## The score the wand in hand would reach with this spell added (on a scratch copy).
static func _try_spell(run: RunState, id: StringName) -> float:
	var scratch := RunState.new()
	scratch.wands.append(WandState.make(run.wand().def))
	scratch.wands[0].set_slots(run.wand().slots.duplicate(true))
	scratch.relics = run.relics
	scratch.bag = run.bag.duplicate(true)
	scratch.bag.append({"id": id, "lv": 1})
	improve(scratch, 2)
	return score(scratch.wand(), scratch)


## The editing bot's answer to a reward, shop or forge screen (the balance bench and demo).
static func bot_answer(run: RunState, kind: StringName, offer: Array = []) -> void:
	match kind:
		&"reward":
			if not offer.is_empty():
				Rewards.grant(run, offer[pick(run, offer)])
		&"forge":
			for evo in Rewards.compilable(run):
				Rewards.compile_evo(run, evo)
			if run.gold >= Rewards.SLOT_PRICE and run.wand().slots.size() < 8:
				Rewards.grant(run, {"t": &"slot", "id": &"slot"})
				run.gold -= Rewards.SLOT_PRICE
		&"shop":
			var best := -1
			var best_v := score(run.wand(), run) * MIN_GAIN
			for k in run.shop.size():
				var it: Dictionary = run.shop[k]
				if it["t"] != &"spell" or it.get("sold", false) or run.gold < int(it["price"]):
					continue
				var v := _try_spell(run, it["id"])
				if v > best_v:
					best_v = v
					best = k
			if best >= 0:
				var it2: Dictionary = run.shop[best]
				if Rewards.grant(run, it2):
					run.gold -= int(it2["price"])
					it2["sold"] = true
	improve(run)
