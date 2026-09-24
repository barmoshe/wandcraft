class_name Hud
extends Control
## The in-run HUD, drawn directly at the pixel base resolution. Layout:
##   top-left     wand rows: the wand badge, then its slots as round sockets (tap to select)
##                and the WANDS button that opens the editor
##   top-center   the chapter map strip (start, 3 rooms, mini-boss, 3 rooms, boss)
##   top-right    pause, gold, and the relics you carry
##   bottom-left  HP and the selected wand's mana
##   bottom       the boss bar during boss fights
## Everything sits inside the safe area (notch, Dynamic Island, home bar).

const SOCKET := 16
const BTN := 26.0
const GOLD := Color("#e0b84e")
const INK := Color("#0a0714")
const PANEL := Color(0.07, 0.05, 0.13, 0.86)
const RIM := Color("#3b3058")

var world: World
var wand_rows: Array[Rect2] = []
var buttons: Dictionary = {}     # id -> Rect2 (hit area, at least 32 px)
var banner := ""
var banner_sub := ""
var banner_t := 0.0
var toast := ""
var toast_t := 0.0
var boss_title := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Events.room_entered.connect(_on_room)
	Events.toast.connect(func(s: String) -> void:
		toast = s
		toast_t = 2.2)
	Events.room_cleared.connect(func() -> void:
		banner = "ROOM CLEAR"
		banner_sub = ""
		banner_t = 1.4)
	Events.boss_started.connect(func(t: String, sub: String) -> void:
		boss_title = t
		banner = t.to_upper()
		banner_sub = sub
		banner_t = 2.2)


func _on_room(def: Dictionary) -> void:
	banner = def.get("title", "")
	banner_sub = "World 1  -  room %d of %d" % [int(def["no"]) + 1, Chapter.PLAN.size()]
	banner_t = 2.0


func _process(dt: float) -> void:
	banner_t = maxf(0.0, banner_t - dt)
	toast_t = maxf(0.0, toast_t - dt)
	queue_redraw()


func safe() -> Rect2:
	return Game.safe_rect(get_viewport_rect().size).grow(-4.0)


## Index of the wand row under a point, or -1.
func hit_wand(p: Vector2) -> int:
	for i in wand_rows.size():
		if wand_rows[i].grow(2.0).has_point(p):
			return i
	return -1


## Id of the HUD button under a point ("pause", "edit"), or "".
func hit_button(p: Vector2) -> String:
	for id in buttons:
		if (buttons[id] as Rect2).has_point(p):
			return id
	return ""


func _draw() -> void:
	if world == null or world.run == null:
		return
	var sr := safe()
	var run := world.run
	buttons.clear()
	_draw_wands(sr.position, run)
	_draw_vitals(Vector2(sr.position.x, sr.end.y), run)
	_draw_top_right(Vector2(sr.end.x, sr.position.y), run)
	_draw_map(Vector2(sr.get_center().x, sr.position.y), run)
	if world.boss and not world.boss.dead:
		_draw_boss_bar(sr)
	_draw_banner(sr)


func _panel(r: Rect2, gold := false) -> void:
	draw_rect(r, PANEL)
	draw_rect(r, INK, false, 1.0)
	draw_rect(r.grow(-1.0), GOLD.darkened(0.25) if gold else RIM, false, 1.0)
	if gold:
		for c in [r.position, Vector2(r.end.x - 2, r.position.y), Vector2(r.position.x, r.end.y - 2), r.end - Vector2(2, 2)]:
			draw_rect(Rect2(c, Vector2(2, 2)), GOLD)


func _text(p: Vector2, s: String, c: Color, size := 8, kind := "small", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := Game.font(kind)
	draw_string_outline(f, p.round(), s, align, width, size, 2, INK)
	draw_string(f, p.round(), s, align, width, size, c)


## A small square HUD button with a glyph; its hit area is padded to 32 px.
func _button(id: String, r: Rect2, glyph: String, c: Color) -> void:
	_panel(r)
	var ic := Icons.glyph(glyph, c)
	draw_texture(ic, (r.get_center() - ic.get_size() / 2.0).round())
	var pad := maxf(0.0, (32.0 - r.size.x) / 2.0)
	buttons[id] = r.grow(pad)


func _draw_wands(origin: Vector2, run: RunState) -> void:
	wand_rows.clear()
	var y := origin.y
	var widest := 0.0
	for wi in run.wands.size():
		var w: WandState = run.wands[wi]
		var sel := wi == run.cur
		var n := w.slots.size()
		var row := Rect2(origin.x, y, 22 + n * (SOCKET + 1) + 3, SOCKET + 8)
		widest = maxf(widest, row.size.x)
		wand_rows.append(row)
		_panel(row, sel)
		var badge := Rect2(row.position + Vector2(3, 3), Vector2(18, SOCKET + 2))
		draw_rect(badge, Color(0.13, 0.09, 0.2) if sel else Color(0.09, 0.07, 0.14))
		var wt := Sprites.wand_texture()
		draw_set_transform(badge.get_center() + Vector2(-6, 5), -PI / 4.0, Vector2.ONE)
		draw_texture(wt, Vector2(0, -1), w.def.color.lightened(0.3) if sel else Color(0.6, 0.6, 0.7))
		draw_set_transform(Vector2.ZERO)
		_text(badge.position + Vector2(1, 7), str(wi + 1), GOLD if sel else Color(0.55, 0.5, 0.65), 8, "bold")
		for i in n:
			var c := row.position + Vector2(23 + i * (SOCKET + 1) + SOCKET / 2.0, 3 + SOCKET / 2.0 + 1)
			var lit := w.flash == i and w.cd > 0.0
			draw_circle(c, SOCKET / 2.0, INK)
			draw_circle(c, SOCKET / 2.0 - 1.0, Color("#1a1330"))
			draw_arc(c, SOCKET / 2.0 - 1.0, 0.0, TAU, 20, GOLD if lit else Color("#4a3e66"), 1.0)
			var s: Variant = w.slots[i]
			if s != null:
				var ic := Icons.spell(Catalog.spell(s["id"]))
				draw_texture(ic, (c - ic.get_size() / 2.0).round(), Color.WHITE if sel else Color(0.75, 0.75, 0.8))
				if int(s["lv"]) > 1:
					_text(c + Vector2(3, 7), "+".repeat(int(s["lv"]) - 1), GOLD, 8)
			if sel and i == w.ptr and w.rech <= 0.0:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 9), c + Vector2(2, 9), c + Vector2(0, 7)]), GOLD)
		var strip := Rect2(row.position.x + 23, row.end.y - 3, n * (SOCKET + 1) - 1, 2)
		draw_rect(strip, Color(0.02, 0.02, 0.06))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x * w.mana / w.max_mana(), 2)), Color("#4aa8ff"))
		if w.rech > 0.0:
			var k := 1.0 - w.rech / maxf(0.01, w.rech_max)
			draw_rect(Rect2(strip.position, Vector2(strip.size.x * k, 1)), Color("#ffe066"))
		y = row.end.y + 2
	# the editor button sits under the rows, with the bag count
	var er := Rect2(origin.x, y, BTN, BTN)
	_button("edit", er, "bag", Color("#c9a8ff"))
	if not run.bag.is_empty():
		_text(er.position + Vector2(BTN + 4, 17), "%d in bag" % run.bag.size(), Color(0.75, 0.7, 0.85), 8)


func _bar(r: Rect2, k: float, fill: Color, label: String) -> void:
	draw_rect(r, INK)
	draw_rect(r.grow(-1.0), Color(0.06, 0.04, 0.1))
	var inner := r.grow(-1.0)
	var fw := roundf(inner.size.x * clampf(k, 0.0, 1.0))
	draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), fill)
	draw_rect(Rect2(inner.position, Vector2(fw, 1)), fill.lightened(0.35))
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fw, 1)), fill.darkened(0.35))
	if label != "":
		_text(Vector2(r.position.x + 4, r.position.y + r.size.y - 2), label, Color.WHITE, 8)


func _draw_vitals(bl: Vector2, run: RunState) -> void:
	var w := run.wand()
	var panel := Rect2(bl.x, bl.y - 30, 128, 30)
	_panel(panel)
	_bar(Rect2(panel.position + Vector2(4, 4), Vector2(120, 11)), run.hp / run.max_hp, Color("#d8344a"), "%d/%d" % [roundi(run.hp), roundi(run.max_hp)])
	_bar(Rect2(panel.position + Vector2(4, 17), Vector2(120, 9)), w.mana / w.max_mana(), Color("#3a7cf0"), "%d" % roundi(w.mana))


func _draw_top_right(tr: Vector2, run: RunState) -> void:
	_button("pause", Rect2(tr.x - BTN, tr.y, BTN, BTN), "pause", Color("#e8e4ff"))
	var gr := Rect2(tr.x - BTN - 62, tr.y, 58, BTN)
	_panel(gr)
	draw_texture(Icons.glyph("coin", Color("#ffd36b")), gr.position + Vector2(4, 6))
	_text(gr.position + Vector2(20, 17), str(run.gold), GOLD, 8, "bold")
	# relics, a compact column under the gold
	for i in run.relics.size():
		var p := Vector2(tr.x - 8 - (i % 6) * 15, tr.y + BTN + 10 + (i / 6) * 15)
		draw_texture(Icons.relic(run.relics[i]), (p - Vector2(7, 7)).round())


func _draw_map(tc: Vector2, run: RunState) -> void:
	var n := Chapter.PLAN.size()
	var gap := 13.0
	var x0 := tc.x - (n - 1) * gap / 2.0
	var y := tc.y + 8
	draw_rect(Rect2(x0 - 8, y - 7, (n - 1) * gap + 16, 14), Color(0.05, 0.03, 0.1, 0.6))
	for i in n:
		var p := Vector2(x0 + i * gap, y)
		if i > 0:
			draw_rect(Rect2(p - Vector2(gap - 3, 0), Vector2(gap - 6, 1)), Color(0.45, 0.4, 0.55) if i <= run.step else Color(0.25, 0.22, 0.32))
		var plan: StringName = Chapter.PLAN[i]
		var done := i < run.step
		var here := i == run.step
		var c := Color("#ff3fa4") if plan == &"mini" or plan == &"boss" else (GOLD if here else Color(0.6, 0.55, 0.7))
		var rad := 4.0 if plan == &"boss" else 3.0
		if here:
			draw_circle(p, rad + 2.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 + 0.2 * sin(world.time * 5.0)))
		if done or here:
			draw_circle(p, rad, c)
		else:
			draw_arc(p, rad, 0.0, TAU, 12, c, 1.0)


func _draw_boss_bar(sr: Rect2) -> void:
	var b := world.boss
	var w := minf(220.0, sr.size.x * 0.46)
	var r := Rect2(sr.get_center().x - w / 2.0, sr.end.y - 16, w, 9)
	_text(Vector2(r.position.x, r.position.y - 2), boss_title, Color("#ff8ab8"), 8, "bold")
	_bar(r, b.hp / b.max_hp, Color("#ff3fa4"), "")
	for ph in b.phases:
		var at := float(ph["at"])
		if at < 1.0:
			draw_rect(Rect2(r.position.x + r.size.x * at, r.position.y, 1, r.size.y), INK)


func _draw_banner(sr: Rect2) -> void:
	var cx := sr.get_center().x
	if banner_t > 0.0 and banner != "":
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var f := Game.font("body")
		var wdt := f.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var r := Rect2(cx - wdt / 2.0 - 12, sr.position.y + 44, wdt + 24, 30 if banner_sub != "" else 20)
		draw_rect(r, Color(0.05, 0.03, 0.1, 0.75 * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, a))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, a))
		draw_string_outline(f, Vector2(cx - wdt / 2.0, r.position.y + 15).round(), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0, 0, 0, a))
		draw_string(f, Vector2(cx - wdt / 2.0, r.position.y + 15).round(), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.8, a))
		if banner_sub != "":
			var sf := Game.font("small")
			var sw := sf.get_string_size(banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			_text(Vector2(cx - sw / 2.0, r.position.y + 26), banner_sub, Color(0.75, 0.7, 0.85, a), 8)
	if toast_t > 0.0:
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		var f := Game.font("small")
		var wdt := f.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(cx - wdt / 2.0, sr.position.y + 86), toast, Color(0.9, 0.95, 1.0, a), 8)
