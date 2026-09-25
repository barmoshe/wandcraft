class_name EditorScreen
extends Screen
## The wand editor (the game pauses while it is open).
##   tap a spell        -> it is picked, and the info panel explains it
##   tap another slot   -> the picked spell moves there (swapping if the slot is full)
##   drag a spell       -> same, in one gesture
##   tap a wand's name  -> that wand becomes the one you cast with
##   REVERT             -> undo everything since the editor opened
## The info panel always shows the live cast preview of the wand in focus: what each press
## of the trigger will actually cast, which makes boosts and triggers learnable. Under it a
## bar weighs one full rotation's mana against what the wand regenerates meanwhile (D2).

const SOCK := 24.0
const GAP := 2.0
const ROW_GAP := 10.0     # between wand sockets: room for the cast-direction chevron

var sel: Dictionary = {}          # {"w": wand index or -1 for bag, "i": index}
var focus_wand := 0
var _snapshot: Dictionary = {}
var _slots: Array = []            # [Rect2, ref] for drag-and-drop
var _drag_from: Dictionary = {}
var _drag_pos := Vector2.ZERO
var _dragging := false
## D9: the tutorial coach: {"text", "from": ref, "to": ref}. Rings pulse on both sockets until
## the spell has left the bag for a wand slot.
var coach: Dictionary = {}
var lesson := -1                  # the lesson step the coach follows (Tutorial.coach)


func _opened() -> void:
	focus_wand = run.cur
	_snapshot = _snap()


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


func _paint() -> void:
	dim(0.9)
	_slots.clear()
	var sr := safe()
	var info_w := minf(168.0, sr.size.x * 0.36)
	var left := Rect2(sr.position, Vector2(sr.size.x - info_w - 8, sr.size.y))
	text(left.position + Vector2(2, 16), "WANDS", GOLD, 16, "body")
	if lesson >= 0:
		var was := not coach.is_empty()
		coach = Tutorial.coach(run, lesson)
		if was and coach.is_empty():
			lesson = -1
			toast("Nice. Press DONE and try it out")
	if coach.is_empty():
		text(left.position + Vector2(62, 15), "Tap a spell, then tap where it goes.", MUTED)
	var y := left.position.y + 26
	for wi in run.wands.size():
		y = _wand_row(wi, Vector2(left.position.x, y), left.size.x) + 6
	# bag
	text(Vector2(left.position.x + 2, y + 9), "BAG  %d/%d" % [run.bag.size(), RunState.BAG_MAX], MUTED, 8, "bold")
	y += 13
	var per_row := maxi(1, int((left.size.x + GAP) / (SOCK + GAP)))
	per_row = mini(per_row, 12)
	for i in RunState.BAG_MAX:
		var p := Vector2(left.position.x + (i % per_row) * (SOCK + GAP), y + (i / per_row) * (SOCK + GAP))
		_socket(Rect2(p, Vector2(SOCK, SOCK)), {"w": -1, "i": i}, false)
	# info panel
	var ir := Rect2(sr.end.x - info_w, sr.position.y + 30, info_w, sr.size.y - 30)
	button(Rect2(sr.end.x - 70, sr.position.y, 70, 26), "done", "DONE", "primary")
	button(Rect2(sr.end.x - 146, sr.position.y, 70, 26), "revert", "REVERT", "ghost")
	_info(ir)
	if not coach.is_empty():
		_draw_coach(ir)
	# the dragged spell follows the finger
	if _dragging:
		var s: Variant = _spell_at(_drag_from)
		if s != null:
			icon_at(Icons.spell(Catalog.spell(s["id"])), _drag_pos + Vector2(0, -14), 2.0)


func _wand_row(wi: int, at: Vector2, width: float) -> float:
	var w: WandState = run.wands[wi]
	var is_cur := wi == run.cur
	var label := "%s%s" % [w.def.title, "  (in hand)" if is_cur else ""]
	var lr := Rect2(at, Vector2(width, 12))
	text(at + Vector2(2, 9), label, GOLD if is_cur else TEXT, 8, "bold")
	area(Rect2(at - Vector2(0, 4), Vector2(minf(width, 150), 18)), "wand%d" % wi)
	if w.def.reverse:
		text_right(at.x + width - 2, at.y + 9, "CASTS RIGHT TO LEFT", Style.c("glitch:4"))
	var n := w.slots.size()
	var y := at.y + 13
	# wand rows leave room between sockets for a chevron that shows the cast direction
	var step := SOCK + ROW_GAP
	var per_row := maxi(1, int((width + ROW_GAP) / step))
	for i in n:
		var p := Vector2(at.x + (i % per_row) * step, y + (i / per_row) * (SOCK + GAP))
		_socket(Rect2(p, Vector2(SOCK, SOCK)), {"w": wi, "i": i}, is_cur)
		if i % per_row != per_row - 1 and i < n - 1:
			_chevron(Vector2(p.x + SOCK + ROW_GAP / 2.0, p.y + SOCK / 2.0), w.def.reverse, is_cur)
	var rows := ceili(float(n) / per_row)
	var _unused := lr
	return y + rows * (SOCK + GAP)


## A small arrowhead between two sockets, pointing the way the wand reads its slots.
func _chevron(c: Vector2, left: bool, lit: bool) -> void:
	var d := -1.0 if left else 1.0
	var col := Color(GOLD, 0.8) if lit else Color("#6a5a8a")
	c = c.round()
	draw_line(c + Vector2(-2 * d, -4), c + Vector2(2 * d, 0), col, 1.5)
	draw_line(c + Vector2(2 * d, 0), c + Vector2(-2 * d, 4), col, 1.5)


func _socket(r: Rect2, ref: Dictionary, lit: bool) -> void:
	var s: Variant = _spell_at(ref)
	var picked: bool = not sel.is_empty() and sel["w"] == ref["w"] and sel["i"] == ref["i"]
	var c := r.get_center()
	draw_circle(c, SOCK / 2.0, INK)
	draw_circle(c, SOCK / 2.0 - 1.0, Color("#1a1330") if ref["w"] >= 0 else Color("#15121f"))
	draw_arc(c, SOCK / 2.0 - 1.0, 0.0, TAU, 24, GOLD if picked else (Color("#6a5a8a") if lit else Color("#3a3050")), 1.0 if not picked else 2.0)
	if s != null and not (_dragging and _drag_from == ref):
		icon_at(Icons.spell(Catalog.spell(s["id"])), c, 1.0 if SOCK < 28.0 else 2.0)
		if int(s["lv"]) > 1:
			text(c + Vector2(4, 11), "+".repeat(int(s["lv"]) - 1), GOLD)
	elif not sel.is_empty() and s == null:
		draw_arc(c, 3.0, 0.0, TAU, 8, Color(1, 1, 1, 0.25), 1.0)
	area(r, "slot:%d:%d" % [ref["w"], ref["i"]])
	_slots.append([r, ref])


func _info(ir: Rect2) -> void:
	panel(ir, true)
	var s: Variant = _spell_at(sel)
	var y := ir.position.y + 8
	if s != null:
		var d := Catalog.spell(s["id"])
		icon_at(Icons.spell(d), ir.position + Vector2(18, 18), 2.0)
		text(ir.position + Vector2(34, 16), d.title + "+".repeat(int(s["lv"]) - 1), TEXT, 8, "bold")
		text(ir.position + Vector2(34, 27), Screen.KIND_NAMES[d.kind], rarity_color(d.rarity))
		# the whole text (up to 8 lines), then the cast preview gets what is left
		var used := minf(para(Rect2(ir.position + Vector2(8, 36), Vector2(ir.size.x - 16, 88)), d.text_at(int(s["lv"])), MUTED), 88.0)
		text(ir.position + Vector2(8, 44 + used), spell_stats(d.id, int(s["lv"])), Color("#8fd8ff"))
		y = ir.position.y + 60 + used
	else:
		var used := para(Rect2(ir.position + Vector2(8, 4), Vector2(ir.size.x - 16, 80)), "Spells cast from left to right. A boost powers up every spell on its right. A trigger goes between two spells: the one on its left casts the one on its right.", MUTED)
		y = ir.position.y + 14 + minf(used, 80)
		if not coach.is_empty():
			y = maxf(y, ir.position.y + 104)   # below the coach box (_draw_coach)
	# cast preview of the wand in focus
	var wi := focus_wand if sel.is_empty() or sel["w"] < 0 else int(sel["w"])
	var w: WandState = run.wands[clampi(wi, 0, run.wands.size() - 1)]
	draw_rect(Rect2(ir.position.x + 6, y, ir.size.x - 12, 1), RIM)
	text(Vector2(ir.position.x + 8, y + 11), "EACH CAST OF %s" % w.def.title.to_upper(), GOLD, 8)
	y += 16
	var plans := WandProgram.preview_cycle(w)
	if plans.is_empty():
		text(Vector2(ir.position.x + 8, y + 9), "No shooting spell: this wand does nothing.", Color("#ff8a9a"))
	else:
		y = _sustain_bar(w, plans, Rect2(ir.position.x + 8, y, ir.size.x - 16, 18)) + 4
	for pi in mini(plans.size(), 6):
		var plan: WandProgram.Plan = plans[pi]
		if y + 14 > ir.end.y - 4:
			text(Vector2(ir.position.x + 8, y + 8), "...", MUTED)
			break
		text(Vector2(ir.position.x + 8, y + 10), "%d." % (pi + 1), MUTED)
		var x := ir.position.x + 22
		for g in plan.groups:
			x = _preview_node(g, Vector2(x, y + 7), ir.end.x - 34)
			x += 4
		text(Vector2(ir.end.x - 30, y + 10), "%dmp" % roundi(plan.mana), Color("#4aa8ff"))
		y += 15


## One full rotation of the wand: its mana, how long it takes, and what regenerates meanwhile.
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


func _sustain_bar(w: WandState, plans: Array, r: Rect2) -> float:
	var rot := rotation(w, plans)
	var cost: float = rot["cost"]
	var regen: float = rot["regen"]
	var ok_ := regen >= cost
	var c := Style.c("leaf:4") if ok_ else (Style.c("gold:3") if w.max_mana() >= cost * 3.0 else Color("#ff6b7a"))
	var label := "ROTATION %d MP / %.1fs" % [roundi(cost), rot["time"]]
	text(Vector2(r.position.x, r.position.y + 8), label, c)
	var bar := Rect2(r.position.x, r.position.y + 11, r.size.x, 3)
	draw_rect(bar, Color(0.02, 0.02, 0.06))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(regen / maxf(1.0, cost), 0.0, 1.0), 3)), c)
	var tip := "sustained: regen keeps up" if ok_ else "empties after %d rotations" % maxi(1, int(w.max_mana() / maxf(1.0, cost - regen)))
	text(Vector2(r.position.x, r.position.y + 22), tip, MUTED)
	return r.position.y + 24


## Draws one compiled cast: its spell icon, then "> payload" for triggers and carriers, and
## "? near | else" for an IF / ELSE node.
func _preview_node(c: CastNode, at: Vector2, max_x: float) -> float:
	if at.x > max_x:
		return at.x
	var x0 := at.x
	if c.cond:
		text(Vector2(x0, at.y + 3), "?", Style.c("cyan:4"))
		x0 += 6
	icon_at(Icons.spell(c.spell), Vector2(x0, at.y) + Vector2(6, 0))
	var x := x0 + 13
	if c.mods.multi > 0:
		text(Vector2(x, at.y + 3), "x%d" % (c.mods.multi + 1), GOLD)
		x += 12
	if c.payload and x < max_x:
		text(Vector2(x, at.y + 3), ">", Color("#ffe066"))
		x = _preview_node(c.payload, Vector2(x + 6, at.y), max_x)
	if c.cond and c.alt and x < max_x:
		text(Vector2(x, at.y + 3), "|", Style.c("cyan:4"))
		x = _preview_node(c.alt, Vector2(x + 5, at.y), max_x)
	return x


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
	# a wand's slots can hold anything; moving into the bag past its end appends
	if to["w"] < 0 and to["i"] >= run.bag.size():
		to = {"w": -1, "i": run.bag.size()}
		if run.bag.size() >= RunState.BAG_MAX and from["w"] >= 0:
			toast("The bag is full")
			return
	run.move_spell(from, to)
	# a spell snapping into a wand slot is an equip (with a light buzz); into the bag, a drop
	if to["w"] >= 0:
		Audio.sfx("ui_equip", 0.03)
		Game.haptic("ui_snap")
	else:
		Audio.sfx("ui_drop", 0.05)
	if to["w"] >= 0:
		focus_wand = to["w"]


func _on_button(id: String) -> void:
	if id == "done":
		finished.emit({})
	elif id == "revert":
		_restore(_snapshot)
		sel = {}
		toast("Changes undone")
	elif id.begins_with("wand"):
		run.cur = int(id.substr(4))
		focus_wand = run.cur
	elif id.begins_with("slot:"):
		var parts := id.split(":")
		var ref := {"w": int(parts[1]), "i": int(parts[2])}
		if ref["w"] >= 0:
			focus_wand = ref["w"]
		if sel.is_empty():
			if _spell_at(ref) != null:
				sel = ref
		elif sel == ref:
			sel = {}
		else:
			_move(sel, ref)
			sel = {}


## The coach takes the info panel while nothing is picked, and rings pulse on the spell to
## move and the slot to drop it in.
func _draw_coach(ir: Rect2) -> void:
	if sel.is_empty():
		var r := Rect2(ir.position + Vector2(2, 2), Vector2(ir.size.x - 4, 96))
		draw_rect(r, Color(0.07, 0.05, 0.13))
		draw_rect(r, GOLD, false, 1.0)
		text(r.position + Vector2(6, 12), "TRY THIS", GOLD, 8, "bold")
		var f := Game.font("small")
		var at := (r.position + Vector2(6, 25)).round()
		draw_multiline_string_outline(f, at, coach["text"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 8, 5, 2, INK)
		draw_multiline_string(f, at, coach["text"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 8, 5, TEXT)
	var pulse := 0.5 + 0.5 * sin(_age * 6.0)
	for key in ["from", "to"]:
		for sl in _slots:
			var ref: Dictionary = sl[1]
			if ref["w"] == coach[key]["w"] and ref["i"] == coach[key]["i"]:
				var c := (sl[0] as Rect2).get_center()
				draw_arc(c, SOCK / 2.0 + 2.0 + pulse * 2.0, 0.0, TAU, 28, Color(GOLD, 0.5 + 0.5 * pulse), 2.0)
