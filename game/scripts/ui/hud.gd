class_name Hud
extends Control
## The in-run HUD, drawn directly at the pixel base resolution. Layout:
##   top-left     wand rows: the wand badge, then its slots as round sockets (tap to select)
##   under them   the bag of spare spells
##   top-right    gold, room and kills
##   bottom-left  HP and the selected wand's mana
##   top-center   the room banner and toasts
## Everything sits inside the safe area (notch, Dynamic Island, home bar).

const SOCKET := 16
const GOLD := Color("#e0b84e")
const INK := Color("#0a0714")
const PANEL := Color(0.07, 0.05, 0.13, 0.86)
const RIM := Color("#3b3058")

var world: World
var wand_rows: Array[Rect2] = []
var banner := ""
var banner_t := 0.0
var toast := ""
var toast_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Events.room_entered.connect(_on_room)
	Events.toast.connect(func(s: String) -> void:
		toast = s
		toast_t = 2.2)
	Events.room_cleared.connect(func() -> void:
		banner = "ROOM CLEAR"
		banner_t = 1.6)


func _on_room(def: Dictionary) -> void:
	var names := {&"fight": "FIGHT", &"elite": "ELITE", &"treasure": "TREASURE"}
	banner = "ROOM %d  -  %s" % [def["no"], names.get(def["kind"], "")]
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


func _draw() -> void:
	if world == null or world.player == null:
		return
	var sr := safe()
	var pl := world.player
	_draw_wands(sr.position, pl)
	_draw_vitals(Vector2(sr.position.x, sr.end.y), pl)
	_draw_counters(Vector2(sr.end.x, sr.position.y))
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


func _draw_wands(origin: Vector2, pl: Player) -> void:
	wand_rows.clear()
	var y := origin.y
	for wi in pl.wands.size():
		var w: WandState = pl.wands[wi]
		var sel := wi == pl.cur
		var n := w.slots.size()
		var row := Rect2(origin.x, y, 22 + n * (SOCKET + 1) + 3, SOCKET + 8)
		wand_rows.append(row)
		_panel(row, sel)
		# wand badge
		var badge := Rect2(row.position + Vector2(3, 3), Vector2(18, SOCKET + 2))
		draw_rect(badge, Color(0.13, 0.09, 0.2) if sel else Color(0.09, 0.07, 0.14))
		var wt := Sprites.wand_texture()
		draw_set_transform(badge.get_center() + Vector2(-6, 5), -PI / 4.0, Vector2.ONE)
		draw_texture(wt, Vector2(0, -1), w.def.color.lightened(0.3) if sel else Color(0.6, 0.6, 0.7))
		draw_set_transform(Vector2.ZERO)
		_text(badge.position + Vector2(1, 7), str(wi + 1), GOLD if sel else Color(0.55, 0.5, 0.65), 8, "bold")
		# sockets
		for i in n:
			var c := row.position + Vector2(23 + i * (SOCKET + 1) + SOCKET / 2.0, 3 + SOCKET / 2.0 + 1)
			var lit := w.flash == i and w.cd > 0.0
			draw_circle(c, SOCKET / 2.0, INK)
			draw_circle(c, SOCKET / 2.0 - 1.0, Color("#1a1330"))
			draw_arc(c, SOCKET / 2.0 - 1.0, 0.0, TAU, 20, GOLD if lit else Color("#4a3e66"), 1.0)
			var s: Variant = w.slots[i]
			if s != null:
				var d := Catalog.spell(s["id"])
				var ic := Icons.spell(d)
				draw_texture(ic, (c - ic.get_size() / 2.0).round(), Color.WHITE if sel else Color(0.75, 0.75, 0.8))
				if int(s["lv"]) > 1:
					_text(c + Vector2(3, 7), "+".repeat(int(s["lv"]) - 1), GOLD, 8)
			if sel and i == w.ptr and w.rech <= 0.0:
				draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 9), c + Vector2(2, 9), c + Vector2(0, 7)]), GOLD)
		# mana strip and recharge sweep under the row
		var strip := Rect2(row.position.x + 23, row.end.y - 3, n * (SOCKET + 1) - 1, 2)
		draw_rect(strip, Color(0.02, 0.02, 0.06))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x * w.mana / w.max_mana(), 2)), Color("#4aa8ff"))
		if w.rech > 0.0:
			var k := 1.0 - w.rech / maxf(0.01, w.rech_max)
			draw_rect(Rect2(strip.position, Vector2(strip.size.x * k, 1)), Color("#ffe066"))
		y = row.end.y + 2
	# bag
	if not pl.bag.is_empty():
		var n := mini(pl.bag.size(), 10)
		var r := Rect2(origin.x, y, 26 + n * 15, 18)
		_panel(r)
		_text(r.position + Vector2(3, 12), "BAG", Color(0.7, 0.65, 0.8), 8)
		for i in n:
			var d := Catalog.spell(pl.bag[i]["id"])
			draw_texture(Icons.spell(d), r.position + Vector2(24 + i * 15, 2))


func _bar(r: Rect2, k: float, fill: Color, label: String) -> void:
	draw_rect(r, INK)
	draw_rect(r.grow(-1.0), Color(0.06, 0.04, 0.1))
	var inner := r.grow(-1.0)
	var fw := roundf(inner.size.x * clampf(k, 0.0, 1.0))
	draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), fill)
	draw_rect(Rect2(inner.position, Vector2(fw, 1)), fill.lightened(0.35))
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fw, 1)), fill.darkened(0.35))
	_text(Vector2(r.position.x + 4, r.position.y + r.size.y - 2), label, Color.WHITE, 8)


func _draw_vitals(bl: Vector2, pl: Player) -> void:
	var w := pl.wand()
	var panel := Rect2(bl.x, bl.y - 30, 128, 30)
	_panel(panel)
	_bar(Rect2(panel.position + Vector2(4, 4), Vector2(120, 11)), pl.hp / pl.max_hp, Color("#d8344a"), "%d/%d" % [roundi(pl.hp), roundi(pl.max_hp)])
	_bar(Rect2(panel.position + Vector2(4, 17), Vector2(120, 9)), w.mana / w.max_mana(), Color("#3a7cf0"), "%d" % roundi(w.mana))


func _draw_counters(tr: Vector2) -> void:
	var r := Rect2(tr.x - 76, tr.y, 76, 30)
	_panel(r)
	draw_circle(r.position + Vector2(9, 9), 3.0, GOLD)
	draw_circle(r.position + Vector2(8, 8), 1.0, Color("#fff3b0"))
	_text(r.position + Vector2(16, 13), str(world.gold), GOLD, 8, "bold")
	_text(r.position + Vector2(4, 25), "ROOM %d" % world.room_no, Color(0.8, 0.78, 0.9), 8)
	_text(Vector2(r.end.x - 4, r.position.y + 13), "%d" % world.kills, Color("#ff7a9a"), 8, "small", HORIZONTAL_ALIGNMENT_RIGHT, 0.0)


func _draw_banner(sr: Rect2) -> void:
	var cx := sr.get_center().x
	if banner_t > 0.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var f := Game.font("body")
		var wdt := f.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var r := Rect2(cx - wdt / 2.0 - 10, sr.position.y + 40, wdt + 20, 20)
		draw_rect(r, Color(0.05, 0.03, 0.1, 0.75 * a))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, a))
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, a))
		draw_string_outline(f, Vector2(cx - wdt / 2.0, r.position.y + 15).round(), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0, 0, 0, a))
		draw_string(f, Vector2(cx - wdt / 2.0, r.position.y + 15).round(), banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.8, a))
	if toast_t > 0.0:
		var a := clampf(toast_t * 2.0, 0.0, 1.0)
		var f := Game.font("small")
		var wdt := f.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(cx - wdt / 2.0, sr.position.y + 72), toast, Color(0.9, 0.95, 1.0, a), 8)
