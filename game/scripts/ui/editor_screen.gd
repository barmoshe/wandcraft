class_name EditorScreen
extends Screen
## The wand workbench (design v2, pillar 1: see it before you cast it). The game pauses
## while it is open.
##   drag a spell onto a slot  -> an empty slot takes it; onto a spell it goes on that
##                                spell's LEFT (boosts power what is on their right), the
##                                others sliding into an empty slot; a full wand swaps
##   tap a spell, then a slot  -> the same in two taps; tap a spell alone to read it
##   tap a wand's name         -> that wand goes in your hand
##   REVERT                    -> undo everything since the editor opened
## The right panel is a firing range (WandLab): the wand in focus fires at three dummies,
## each slot lights as it is read, and damage per second is measured, not guessed. While you
## drag, it shows what the drop would do (DPS before -> after). Wand slots are numbered in
## the order they cast, with chevrons between them, and a bracket under each boost reaches
## the spells it powers.

const SOCK := 26.0
const GAP := 2.0
const ROW_GAP := 9.0      # between wand sockets: room for the cast-direction chevron
const RANGE_H := 84.0

var sel: Dictionary = {}          # {"w": wand index or -1 for bag, "i": index}
var focus_wand := 0
var _snapshot: Dictionary = {}
var _slots: Array = []            # [Rect2, ref] for drag-and-drop
var _drag_from: Dictionary = {}
var _drag_pos := Vector2.ZERO
var _dragging := false
## D9: the tutorial coach: {"text", "from": ref, "to": ref}. Rings pulse on both sockets
## until the spell has left the bag for a wand slot.
var coach: Dictionary = {}
var lesson := -1                  # the lesson step the coach follows (Tutorial.coach)
var _lab: WandLab
var _sel_cast := -1               # a tapped cast in the preview: its slots are ringed
var _cast_slots: Array = []       # per preview cast: the slot indices it read


func _opened() -> void:
	focus_wand = run.cur
	_snapshot = _snap()
	_lab = WandLab.new()
	add_child(_lab)


func _snap() -> Dictionary:
	return {"wands": run.wands.map(func(w: WandState) -> Array: return w.slots.duplicate(true)), "bag": run.bag.duplicate(true)}


func _restore(s: Dictionary) -> void:
	for i in run.wands.size():
		run.wands[i].slots = (s["wands"][i] as Array).duplicate(true)
		run.wands[i].ptr = 0
		run.wands[i].acc = Mods.new()
	run.bag = (s["bag"] as Array).duplicate(true)


func _spell_at(ref: Dictionary) -> Variant:
	if ref.is_empty():
		return null
	if ref["w"] < 0:
		return run.bag[ref["i"]] if ref["i"] < run.bag.size() else null
	return run.wands[ref["w"]].slots[ref["i"]]


func _focus() -> WandState:
	return run.wands[clampi(focus_wand, 0, run.wands.size() - 1)]


func _paint() -> void:
	dim(0.9)
	_slots.clear()
	var sr := safe()
	var info_w := clampf(sr.size.x * 0.4, 176.0, 236.0)
	var left := Rect2(sr.position, Vector2(sr.size.x - info_w - 8, sr.size.y))
	text(left.position + Vector2(2, 16), "WANDS", GOLD, 16, "body")
	if lesson >= 0:
		var was := not coach.is_empty()
		coach = Tutorial.coach(run, lesson)
		if was and coach.is_empty():
			lesson = -1
			toast("Nice. Press DONE and try it out")
	if coach.is_empty() and Game.font("small").get_string_size("Drag spells into slots.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 62 < sr.size.x - 170.0:
		text(left.position + Vector2(62, 15), "Drag spells into slots.", MUTED)
	var y := left.position.y + 24
	for wi in run.wands.size():
		y = _wand_row(wi, Vector2(left.position.x, y), left.size.x) + 5
	# bag
	text(Vector2(left.position.x + 2, y + 9), "BAG  %d/%d" % [run.bag.size(), RunState.BAG_MAX], MUTED, 8, "bold")
	y += 12
	var per_row := mini(12, maxi(1, int((left.size.x + GAP) / (SOCK + GAP))))
	for i in RunState.BAG_MAX:
		var p := Vector2(left.position.x + (i % per_row) * (SOCK + GAP), y + (i / per_row) * (SOCK + GAP))
		_socket(Rect2(p, Vector2(SOCK, SOCK)), {"w": -1, "i": i}, false)
	# the workbench
	var ir := Rect2(sr.end.x - info_w, sr.position.y + 30, info_w, sr.size.y - 30)
	button(Rect2(sr.end.x - 64, sr.position.y, 64, 26), "done", "DONE", "primary")
	button(Rect2(sr.end.x - 132, sr.position.y, 64, 26), "revert", "REVERT", "ghost")
	button(Rect2(sr.end.x - 164, sr.position.y, 28, 26), "gloss", "?", "ghost")
	_info(ir)
	_drop_marker()
	_ghost_hand()
	# the dragged spell follows the finger
	if _dragging:
		var s: Variant = _spell_at(_drag_from)
		if s != null:
			icon_at(Icons.spell(Catalog.spell(s["id"])), _drag_pos + Vector2(0, -14), 2.0)
	if show_glossary:
		glossary_panel()


func _wand_row(wi: int, at: Vector2, width: float) -> float:
	var w: WandState = run.wands[wi]
	var is_cur := wi == run.cur
	text(at + Vector2(2, 9), w.def.title, GOLD if is_cur else TEXT, 8, "bold")
	var tw := Game.font("bold").get_string_size(w.def.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	if is_cur:
		text(at + Vector2(tw + 8, 9), "IN HAND", Style.c("leaf:4"))
	elif run.wands.size() > 1:
		text(at + Vector2(tw + 8, 9), "TAP TO HOLD", MUTED.darkened(0.3))
	area(Rect2(at - Vector2(0, 4), Vector2(minf(width, tw + 80), 18)), "wand%d" % wi)
	# the wand's mana on the right, when the row has room for it after the name and badge
	var mana_s := "%d MANA  +%d/S" % [roundi(w.max_mana()), roundi(w.def.regen * w.regen_mul() * Relics.mana_regen_mul(run))]
	var f := Game.font("small")
	var badge_w := f.get_string_size("TAP TO HOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	if tw + 8 + badge_w + 10 + f.get_string_size(mana_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= width:
		text_right(at.x + width - 2, at.y + 9, mana_s, Style.c("cyan:4"))
	if w.def.reverse:
		text_right(at.x + width - 2, at.y + 19, "CASTS RIGHT TO LEFT", Style.c("glitch:4"))
	var n := w.slots.size()
	var y := at.y + 21
	var step := SOCK + ROW_GAP
	var per_row := maxi(1, int((width + ROW_GAP) / step))
	var centres: Array[Vector2] = []
	var lit := _lit_slots(wi)
	for i in n:
		var p := Vector2(at.x + (i % per_row) * step, y + (i / per_row) * (SOCK + 14))
		# slot numbers follow the cast order (right to left on a reversed wand)
		var no := (n - i) if w.def.reverse else (i + 1)
		text_center(p.x + SOCK / 2.0, p.y - 2, str(no), MUTED.darkened(0.2))
		_socket(Rect2(p, Vector2(SOCK, SOCK)), {"w": wi, "i": i}, is_cur, lit.has(i))
		centres.append(p + Vector2(SOCK, SOCK) / 2.0)
		if i % per_row != per_row - 1 and i < n - 1:
			_chevron(Vector2(p.x + SOCK + ROW_GAP / 2.0, p.y + SOCK / 2.0), w.def.reverse, is_cur)
	_brackets(w, centres)
	var rows := ceili(float(n) / per_row)
	return y + rows * (SOCK + 14) - 8


## Slots to ring on a wand: the ones the range's last cast read (a moment after it fires),
## or the ones of the cast tapped in the preview.
func _lit_slots(wi: int) -> Array:
	if wi != focus_wand:
		return []
	if _sel_cast >= 0 and _sel_cast < _cast_slots.size():
		return _cast_slots[_sel_cast]
	if _lab and _lab.wand and _lab.world and _lab.world.time - _lab.wand.lit_at < 0.22:
		return Array(_lab.wand.lit)
	return []


## Under each boost, a gold line to the last spell on its right that it powers; a boost with
## no spell on its right gets a red mark (it does nothing there).
func _brackets(w: WandState, centres: Array[Vector2]) -> void:
	var k := 0
	var n := w.slots.size()
	for i in n:
		var s: Variant = w.slots[i]
		if s == null or fam(Catalog.spell(s["id"])) != Fam.BOOST:
			continue
		var last := -1
		var rng := range(i + 1, n) if not w.def.reverse else range(i - 1, -1, -1)
		for j in rng:
			if w.slots[j] != null and Catalog.is_caster(Catalog.spell(w.slots[j]["id"])):
				last = j
		var a: Vector2 = centres[i] + Vector2(0, SOCK / 2.0 + 3 + mini(k, 2) * 2)
		if last < 0:
			text_center(a.x, a.y + 7, "!", Color("#ff6b7a"), 8, "bold")
		elif absf(centres[last].y - centres[i].y) < 1.0:
			var b: Vector2 = Vector2(centres[last].x, a.y)
			draw_line(a, b, Color(Style.c("gold:4"), 0.75), 1.0)
			draw_line(a + Vector2(0, -2), a + Vector2(0, 1), Color(Style.c("gold:4"), 0.75), 1.0)
			draw_line(b + Vector2(0, -2), b + Vector2(0, 1), Color(Style.c("gold:4"), 0.75), 1.0)
		k += 1


## A small arrowhead between two sockets, pointing the way the wand reads its slots.
func _chevron(c: Vector2, left: bool, lit: bool) -> void:
	var d := -1.0 if left else 1.0
	var col := Color(GOLD, 0.8) if lit else Color("#6a5a8a")
	c = c.round()
	draw_line(c + Vector2(-2 * d, -4), c + Vector2(2 * d, 0), col, 1.5)
	draw_line(c + Vector2(2 * d, 0), c + Vector2(-2 * d, 4), col, 1.5)


func _socket(r: Rect2, ref: Dictionary, lit: bool, firing := false) -> void:
	var s: Variant = _spell_at(ref)
	var picked: bool = not sel.is_empty() and sel["w"] == ref["w"] and sel["i"] == ref["i"]
	var c := r.get_center()
	var rad := SOCK / 2.0 - 1.0
	var hide: bool = _dragging and _drag_from == ref
	if s != null and not hide:
		var d := Catalog.spell(s["id"])
		var rim := fam_color(d)
		if not lit and ref["w"] >= 0:
			rim = rim.darkened(0.35)
		socket_shape(c, rad, fam(d), Color("#1a1330"), rim, 2.0 if picked or firing else 1.0)
		if picked:
			socket_shape(c, rad + 2.0, fam(d), Color(0, 0, 0, 0), GOLD, 1.0)
		if firing:
			socket_shape(c, rad + 2.0, fam(d), Color(Style.c("cyan:3"), 0.25), Style.c("cyan:4"), 1.0)
		icon_at(Icons.spell(d), c)
		if int(s["lv"]) > 1:
			text(c + Vector2(5, 12), "+".repeat(int(s["lv"]) - 1), GOLD)
	else:
		draw_circle(c, rad, INK)
		draw_circle(c, rad - 1.0, Color("#1a1330") if ref["w"] >= 0 else Color("#15121f"))
		draw_arc(c, rad - 1.0, 0.0, TAU, 24, Color("#6a5a8a") if lit else Color("#3a3050"), 1.0)
		if not sel.is_empty() and s == null:
			draw_arc(c, 3.0, 0.0, TAU, 8, Color(1, 1, 1, 0.25), 1.0)
	area(r, "slot:%d:%d" % [ref["w"], ref["i"]])
	_slots.append([r, ref])


## Design v2 onboarding: show, don't tell. While the coach waits, a ghost of the spell rides
## a pointing hand from where it is to the lit slot, again and again, until the player does it.
func _ghost_hand() -> void:
	if coach.is_empty() or _dragging or not sel.is_empty():
		return
	var a := Vector2.INF
	var b := Vector2.INF
	for sl in _slots:
		var ref: Dictionary = sl[1]
		if ref["w"] == coach["from"]["w"] and ref["i"] == coach["from"]["i"]:
			a = (sl[0] as Rect2).get_center()
		if ref["w"] == coach["to"]["w"] and ref["i"] == coach["to"]["i"]:
			b = (sl[0] as Rect2).get_center()
	if a == Vector2.INF or b == Vector2.INF:
		return
	var s: Variant = _spell_at(coach["from"])
	if s == null:
		return
	# 0.3 s press, 0.9 s glide, 0.4 s hold, then fade and start over
	var t := fmod(_age, 1.9)
	var k := smoothstep(0.3, 1.2, t)
	var p := a.lerp(b, k)
	var alpha := 1.0 if t < 1.6 else 1.0 - (t - 1.6) / 0.3
	icon_at(Icons.spell(Catalog.spell(s["id"])), p + Vector2(0, -3), 1.0, Color(1, 1, 1, 0.55 * alpha))
	# the hand: a white fingertip with a pressed ring while it holds
	var tip := p + Vector2(4, 6)
	if t < 0.3 or (t > 1.2 and t < 1.6):
		draw_arc(tip, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.5 * alpha), 1.0)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(3, 8), tip + Vector2(1, 8), tip + Vector2(0, 12),
		tip + Vector2(-2, 11), tip + Vector2(-1, 7), tip + Vector2(-3, 7)]), Color(1, 0.96, 0.88, 0.9 * alpha))


## While dragging: where the spell would land. A gold bar on the left of a spell means it
## goes there (insert); a ring means the slot takes it (empty) or the two swap (full wand).
func _drop_marker() -> void:
	if not _dragging:
		return
	var to := _slot_at(_drag_pos)
	if to.is_empty() or to == _drag_from:
		return
	var r: Rect2
	for sl in _slots:
		if sl[1] == to:
			r = sl[0]
	var c := r.get_center()
	if to["w"] >= 0 and _spell_at(to) != null and run.wands[to["w"]].slots.has(null) or (to["w"] == _drag_from["w"] and to["w"] >= 0 and _spell_at(to) != null):
		var x := r.position.x - ROW_GAP / 2.0
		draw_rect(Rect2(x - 1, r.position.y - 2, 3, SOCK + 4), GOLD)
	else:
		draw_arc(c, SOCK / 2.0 + 2.0, 0.0, TAU, 24, GOLD, 2.0)


func _info(ir: Rect2) -> void:
	panel(ir, true)
	var w := _focus()
	# 1. the firing range
	var rr := Rect2(ir.position + Vector2(4, 4), Vector2(ir.size.x - 8, RANGE_H))
	_lab.set_view(Vector2i(int(rr.size.x), int(rr.size.y)))
	if _lab.sig != WandLab.signature(run, w.def, w.slots):
		_lab.load_wand(run, w.def, w.slots)
	draw_texture_rect(_lab.get_texture(), rr, false)
	draw_rect(rr, INK, false, 1.0)
	var probe := WandLab.probe(get_tree())
	var now := probe.dps(run, w.def, w.slots)
	var line := "DAMAGE/S  " + _fmt(now)
	var col := GOLD
	var cand := _drop_candidate()
	if not cand.is_empty():
		var then := probe.dps(run, run.wands[cand["w"]].def, cand["slots"])
		var before := probe.dps(run, run.wands[cand["w"]].def, run.wands[cand["w"]].slots)
		line = "DAMAGE/S  %s > %s" % [_fmt(before), _fmt(then)]
		col = GOLD if then < 0.0 or before < 0.0 else (Style.c("leaf:4") if then > before + 0.5 else (Color("#ff6b7a") if then < before - 0.5 else MUTED))
	text(rr.position + Vector2(4, 10), line, col, 8, "bold")
	if _lab.world and _lab.wand and _lab.world.time - _lab.wand.dry_at < 0.6:
		text_right(rr.end.x - 4, rr.position.y + 10, "OUT OF MANA", Color("#ff6b7a"), 8, "bold")
	var y := rr.end.y + 4
	# 2. mana: what one pass through the wand costs against what refills meanwhile
	var plans := WandProgram.preview_cycle(w)
	_cast_slots = _slots_per_cast(plans)
	if plans.is_empty():
		text(Vector2(ir.position.x + 8, y + 9), "No spell to fire: this wand does nothing.", Color("#ff8a9a"))
		y += 14
	else:
		y = _mana_line(w, plans, Rect2(ir.position.x + 8, y, ir.size.x - 16, 20)) + 4
	draw_rect(Rect2(ir.position.x + 6, y, ir.size.x - 12, 1), RIM)
	y += 4
	# 3. the tutorial coach, the picked spell, or the casts one by one
	var s: Variant = _spell_at(sel)
	if not coach.is_empty() and s == null:
		_draw_coach(Rect2(ir.position.x + 4, y, ir.size.x - 8, ir.end.y - y - 4))
	elif s != null:
		_spell_card(Catalog.spell(s["id"]), int(s["lv"]), Rect2(ir.position.x + 8, y, ir.size.x - 16, ir.end.y - y - 4))
	else:
		_casts(w, plans, Rect2(ir.position.x + 8, y, ir.size.x - 16, ir.end.y - y - 4))
	# the coach's rings, on top of the sockets
	if not coach.is_empty():
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		for key in ["from", "to"]:
			for sl in _slots:
				var ref: Dictionary = sl[1]
				if ref["w"] == coach[key]["w"] and ref["i"] == coach[key]["i"]:
					draw_arc((sl[0] as Rect2).get_center(), SOCK / 2.0 + 2.0 + pulse * 2.0, 0.0, TAU, 28, Color(GOLD, 0.5 + 0.5 * pulse), 2.0)


static func _fmt(v: float) -> String:
	return "..." if v < 0.0 else str(roundi(v))


## The layout a drop in progress would make: {"w", "slots"}, or {} when not over a wand slot.
func _drop_candidate() -> Dictionary:
	if not _dragging:
		return {}
	var to := _slot_at(_drag_pos)
	if to.is_empty() or to == _drag_from or to["w"] < 0:
		return {}
	var snap := _snap()
	var fe: Variant = run.stats.get("first_edit", -1.0)
	run.place_spell(_drag_from, to)
	var out := {"w": to["w"], "slots": run.wands[to["w"]].slots.duplicate(true)}
	_restore(snap)
	run.stats["first_edit"] = fe
	return out


## One pass through the wand: its mana, how long it takes, and what refills meanwhile.
## {"cost", "time", "regen"}; sustainable when regen covers cost.
func rotation(w: WandState, plans: Array) -> Dictionary:
	var cost := 0.0
	var t := 0.0
	for plan: WandProgram.Plan in plans:
		cost += plan.mana
		t += maxf(0.03, w.def.cast_delay + plan.delay_add)
		if plan.wrapped:
			t += maxf(0.03, w.recharge_time() + plan.recharge_add)
	var regen := w.def.regen * w.regen_mul() * Relics.mana_regen_mul(run) * t
	return {"cost": cost, "time": t, "regen": regen}


func _mana_line(w: WandState, plans: Array, r: Rect2) -> float:
	var rot := rotation(w, plans)
	var cost: float = rot["cost"]
	var regen: float = rot["regen"]
	var t: float = maxf(0.05, rot["time"])
	var ok_ := regen >= cost
	var c := Style.c("leaf:4") if ok_ else Color("#ff6b7a")
	text(Vector2(r.position.x, r.position.y + 8), "USES %d MANA/S, REFILLS %d/S" % [roundi(cost / t), roundi(regen / t)], c)
	var bar := Rect2(r.position.x, r.position.y + 11, r.size.x, 3)
	draw_rect(bar, Color(0.02, 0.02, 0.06))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(regen / maxf(1.0, cost), 0.0, 1.0), 3)), c)
	var dry := w.max_mana() / maxf(0.01, (cost - regen) / t)
	text(Vector2(r.position.x, r.position.y + 22), "Never runs dry" if ok_ else "Runs dry after %d s of casting" % maxi(1, roundi(dry)), MUTED)
	return r.position.y + 24


## The slots each cast of one pass reads (for ringing a tapped cast).
func _slots_per_cast(plans: Array) -> Array:
	return plans.map(func(p: WandProgram.Plan) -> Array: return Array(p.used))


## Each cast of one pass as a chain: the boosts powering it, the spell (with its damage after
## boosts), and what a trigger releases. Tap a cast to ring its slots on the wand.
func _casts(w: WandState, plans: Array, r: Rect2) -> void:
	text(r.position + Vector2(0, 9), "EACH CAST, IN ORDER", GOLD, 8)
	var y := r.position.y + 14
	var boosts: Array = []
	for pi in plans.size():
		var plan: WandProgram.Plan = plans[pi]
		if y + 14 > r.end.y:
			text(Vector2(r.position.x, y + 8), "...", MUTED)
			break
		for i in plan.used:
			var sp: Variant = w.slots[i]
			if sp != null and fam(Catalog.spell(sp["id"])) == Fam.BOOST and not boosts.has(sp["id"]):
				boosts.append(sp["id"])
		var row := Rect2(r.position.x - 2, y, r.size.x + 4, 14)
		if pi == _sel_cast:
			draw_rect(row, Color(GOLD, 0.12))
		area(row, "cast%d" % pi)
		text(Vector2(r.position.x, y + 10), "%d" % (pi + 1), MUTED)
		var x := r.position.x + 10
		for b in boosts:
			if x > r.end.x - 60:
				break
			icon_at(Icons.spell(Catalog.spell(b)), Vector2(x + 5, y + 7), 0.75)
			x += 11
		if not boosts.is_empty():
			text(Vector2(x, y + 10), ">", Style.c("gold:4"))
			x += 7
		for g in plan.groups:
			x = _chain(g, Vector2(x, y + 7), r.end.x - 30)
			x += 4
		text_right(r.end.x, y + 10, "%d MANA" % roundi(plan.mana), Style.c("cyan:4"))
		y += 15


## One compiled cast: the spell's icon and its damage after boosts, then "> what it releases".
func _chain(c: CastNode, at: Vector2, max_x: float) -> float:
	if at.x > max_x:
		return at.x
	icon_at(Icons.spell(c.spell), at + Vector2(6, 0))
	var x := at.x + 13
	var dmg := c.spell.damage_at(c.level) * c.mods.dmg
	if dmg > 0.0:
		var copies := (1 + c.mods.multi) * int(c.spell.param("count", c.level, 1))
		var t := str(roundi(dmg)) + ("x%d" % copies if copies > 1 else "")
		text(Vector2(x, at.y + 3), t, TEXT if c.mods.dmg <= 1.001 else Style.c("leaf:4"))
		x += Game.font("small").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 3
	if c.payload and x < max_x:
		text(Vector2(x, at.y + 3), ">", Color(FAM_COLORS[Fam.TRIGGER]))
		x = _chain(c.payload, Vector2(x + 6, at.y), max_x)
	if c.cond and c.alt and x < max_x:
		text(Vector2(x, at.y + 3), "|", Style.c("cyan:4"))
		x = _chain(c.alt, Vector2(x + 5, at.y), max_x)
	return x


func _spell_card(d: SpellDef, lv: int, r: Rect2) -> void:
	socket_shape(r.position + Vector2(9, 10), 9.0, fam(d), Color("#1a1330"), fam_color(d))
	icon_at(Icons.spell(d), r.position + Vector2(9, 10))
	text(r.position + Vector2(24, 8), d.title + "+".repeat(lv - 1), TEXT, 8, "bold")
	text(r.position + Vector2(24, 18), "%s  -  LEVEL %d" % [kind_name(d).to_upper(), lv], fam_color(d))
	var room := r.size.y - 40.0
	var used := minf(para(Rect2(r.position + Vector2(0, 22), Vector2(r.size.x, room)), d.text_at(lv), MUTED), room)
	text(r.position + Vector2(0, 32 + used), spell_stats(d.id, lv), Style.c("cyan:4"))


func _slot_at(p: Vector2) -> Dictionary:
	for s in _slots:
		if (s[0] as Rect2).grow(2.0).has_point(p):
			return s[1]
	return {}


func _on_down(p: Vector2) -> void:
	var ref := _slot_at(p)
	if not ref.is_empty() and _spell_at(ref) != null:
		_drag_from = ref
		_drag_pos = p
	else:
		_drag_from = {}
	_dragging = false


func _on_drag(p: Vector2) -> void:
	if _drag_from.is_empty():
		return
	_drag_pos = p
	if not _dragging and p.distance_to(_press_pos) > 6.0:
		_dragging = true
		sel = {}


func _on_up(p: Vector2) -> bool:
	if not _dragging:
		_drag_from = {}
		return false
	var to := _slot_at(p)
	if not to.is_empty() and to != _drag_from:
		_move(_drag_from, to)
	_dragging = false
	_drag_from = {}
	return true


func _move(from: Dictionary, to: Dictionary) -> void:
	# moving into the bag past its end appends
	if to["w"] < 0 and to["i"] >= run.bag.size():
		to = {"w": -1, "i": run.bag.size()}
		if run.bag.size() >= RunState.BAG_MAX and from["w"] >= 0:
			toast("The bag is full")
			return
	run.place_spell(from, to)
	_sel_cast = -1
	# a spell snapping into a wand slot is an equip (with a light buzz); into the bag, a drop
	if to["w"] >= 0:
		Audio.sfx("ui_equip", 0.03)
		Game.haptic("ui_snap")
		focus_wand = to["w"]
	else:
		Audio.sfx("ui_drop", 0.05)


func _on_button(id: String) -> void:
	if id == "done":
		finished.emit({})
	elif id == "revert":
		_restore(_snapshot)
		sel = {}
		toast("Changes undone")
	elif id.begins_with("cast"):
		var k := int(id.substr(4))
		_sel_cast = -1 if _sel_cast == k else k
	elif id.begins_with("wand"):
		run.cur = int(id.substr(4))
		focus_wand = run.cur
		_sel_cast = -1
	elif id.begins_with("slot:"):
		var parts := id.split(":")
		var ref := {"w": int(parts[1]), "i": int(parts[2])}
		if ref["w"] >= 0 and ref["w"] != focus_wand:
			focus_wand = ref["w"]
			_sel_cast = -1
		if sel.is_empty():
			if _spell_at(ref) != null:
				sel = ref
		elif sel == ref:
			sel = {}
		else:
			_move(sel, ref)
			sel = {}


## The coach fills the workbench's lower part while nothing is picked, and rings pulse on
## the spell to move and the slot to drop it in.
func _draw_coach(r: Rect2) -> void:
	draw_rect(r, Color(0.07, 0.05, 0.13))
	draw_rect(r, GOLD, false, 1.0)
	text(r.position + Vector2(6, 12), "TRY THIS", GOLD, 8, "bold")
	para(Rect2(r.position + Vector2(6, 16), Vector2(r.size.x - 12, r.size.y - 18)), coach["text"], TEXT)
