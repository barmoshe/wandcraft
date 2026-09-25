class_name Screen
extends Control
## Base for full-screen menus, drawn immediate-mode at the pixel base resolution (like the
## HUD) so everything stays crisp and matches the game's look. Buttons are registered while
## drawing and hit-tested on release; a button press only fires when the finger lifts on the
## same button (so a slide-off cancels). Touch targets are at least 32 px (about 44 pt).
## Input is read in _input straight from touch events (and real, non-emulated mouse events),
## not through the GUI: a Control under a CanvasLayer can end up with a 0x0 rect, and then
## the GUI never delivers it a click. That shipped in 0.3.0 and made every menu dead on
## phones; tests/input/tap_test.tscn guards it with real touch events.

signal finished(result: Dictionary)

const GOLD := Style.UI_GOLD
const INK := Style.INK
const PANEL := Style.UI_PANEL
const RIM := Style.UI_RIM
const TEXT := Style.UI_TEXT
const MUTED := Style.UI_MUTED
const MIN_TAP := 32.0
const GUARD := 0.18   # ignore input right after opening (the tap that opened us)

var run: RunState
var _buttons: Array = []     # [Rect2 hit area, id]
var _press_id := ""
var _press_pos := Vector2.ZERO
## The finger being followed: the latest one down. Not assumed to be 0, and any int can be
## an index: the web build on iPhone gets Safari's large touch ids, which can wrap negative.
var _finger := 0
var _has_finger := false
var _age := 0.0
var _toast := ""
var _toast_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()
	get_viewport().size_changed.connect(_fit)
	_opened()


func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _opened() -> void:
	pass


func _process(dt: float) -> void:
	_age += dt
	_toast_t = maxf(0.0, _toast_t - dt)
	queue_redraw()


func view() -> Vector2:
	return get_viewport_rect().size


func safe() -> Rect2:
	return Game.safe_rect(view()).grow(-6.0)


## Only the newest screen on the menu layer takes input (main.gd opens one at a time).
func _is_top() -> bool:
	var p := get_parent()
	if p == null:
		return false
	for i in range(p.get_child_count() - 1, -1, -1):
		var c := p.get_child(i)
		if c is Screen and not c.is_queued_for_deletion():
			return c == self
	return false


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or not _is_top():
		return
	var down := false
	var up := false
	var drag := false
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_finger = ev.index
			_has_finger = true
			down = true
		elif _has_finger and ev.index == _finger:
			_has_finger = false
			up = true
		else:
			return
	elif ev is InputEventScreenDrag:
		if not _has_finger or ev.index != _finger:
			return
		drag = true
	elif ev is InputEventMouseButton and ev.device != InputEvent.DEVICE_ID_EMULATION:
		if ev.button_index != MOUSE_BUTTON_LEFT:
			return
		down = ev.pressed
		up = not ev.pressed
	elif ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION:
		if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		drag = true
	else:
		return
	get_viewport().set_input_as_handled()
	if _age < GUARD:
		return
	var p: Vector2 = make_input_local(ev).position
	if down:
		_press_id = hit(p)
		_press_pos = p
		_on_down(p)
	elif up:
		var id := hit(p)
		var consumed := _on_up(p)
		if not consumed and id != "" and id == _press_id:
			press(id)
		_press_id = ""
	elif drag:
		_on_drag(p)


## Activates a button by id (also used by tests and by keyboard shortcuts).
func press(id: String) -> void:
	if not id.begins_with("slot:") and not id.begins_with("card") and not id.begins_with("item"):
		Audio.sfx("ui_back" if id in ["close", "done", "resume", "skip", "title"] else "ui", 0.0)
	_on_button(id)


func hit(p: Vector2) -> String:
	for i in range(_buttons.size() - 1, -1, -1):
		if (_buttons[i][0] as Rect2).has_point(p):
			return _buttons[i][1]
	return ""


func toast(s: String) -> void:
	_toast = s
	_toast_t = 1.8


# ---- hooks
func _on_button(_id: String) -> void:
	pass


func _on_down(_p: Vector2) -> void:
	pass


## Return true to swallow the release (e.g. a drag ended).
func _on_up(_p: Vector2) -> bool:
	return false


func _on_drag(_p: Vector2) -> void:
	pass


func _paint() -> void:
	pass


func _draw() -> void:
	_buttons.clear()
	_paint()
	if _toast_t > 0.0:
		var f := Game.font("small")
		var w := f.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var r := Rect2(view().x / 2.0 - w / 2.0 - 8, view().y / 2.0 - 10, w + 16, 20)
		panel(r, true)
		text(r.position + Vector2(8, 13), _toast, TEXT)


# ---- drawing helpers

func dim(a := 0.84) -> void:
	draw_rect(Rect2(Vector2.ZERO, view()), Color(0.02, 0.01, 0.05, a))


## A framed panel: dark glass, a 1px ink edge, an inner rim lit from the top-left, and
## (gold) corner brackets for the important ones.
func panel(r: Rect2, gold := false) -> void:
	draw_rect(r, PANEL)
	draw_rect(r, INK, false, 1.0)
	var inner := r.grow(-1.0)
	var lit := Style.UI_PANEL_HI.lightened(0.25) if not gold else Style.c("gold:2")
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), lit)
	draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), lit.darkened(0.2))
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(inner.size.x, 1)), RIM.darkened(0.3))
	draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1, 0), Vector2(1, inner.size.y)), RIM.darkened(0.3))
	if gold:
		var g := Style.c("gold:3")
		for c in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
			var o: Vector2 = c[0]
			var d: Vector2 = c[1]
			var ox := o.x if d.x > 0 else o.x - 5
			var oy := o.y if d.y > 0 else o.y - 1
			draw_rect(Rect2(ox, oy, 5, 1), g)
			ox = o.x if d.x > 0 else o.x - 1
			oy = o.y if d.y > 0 else o.y - 5
			draw_rect(Rect2(ox, oy, 1, 5), g)


func text(p: Vector2, s: String, c: Color = TEXT, size := 8, kind := "small", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := Game.font(kind)
	draw_string_outline(f, p.round(), s, align, width, size, 2, INK)
	draw_string(f, p.round(), s, align, width, size, c)


func text_center(cx: float, y: float, s: String, c: Color = TEXT, size := 8, kind := "small") -> void:
	var f := Game.font(kind)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(Vector2(cx - w / 2.0, y), s, c, size, kind)


func text_right(x_end: float, y: float, s: String, c: Color = TEXT, size := 8, kind := "small") -> void:
	var w := Game.font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(Vector2(x_end - w, y), s, c, size, kind)


## Wrapped paragraph inside a rect; returns the height used.
func para(r: Rect2, s: String, c: Color = TEXT, size := 8, kind := "small") -> float:
	var f := Game.font(kind)
	var lines := _wrap(f, s, r.size.x, size)
	var lh := size + 3.0
	for i in lines.size():
		if (i + 1) * lh > r.size.y + 1.0:
			break
		text(r.position + Vector2(0, size + i * lh), lines[i], c, size, kind)
	return lines.size() * lh


func _wrap(f: Font, s: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var t := word if line == "" else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


## A beveled button. kind: normal | primary | danger | ghost. Disabled buttons draw dim and
## do not register. The hit area grows to at least MIN_TAP in both directions.
func button(r: Rect2, id: String, label: String, kind := "normal", enabled := true) -> void:
	var down := enabled and _press_id == id
	var ramp := "slate"
	match kind:
		"primary":
			ramp = "gold"
		"danger":
			ramp = "blood"
		"ghost":
			ramp = "night"
	var rr := r
	if down:
		rr.position.y += 1
	# drop shadow, ink edge, body with a two-tone bevel
	if not down:
		draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.35))
	draw_rect(rr, INK)
	var body := rr.grow(-1.0)
	var top := Style.c(ramp + ":2") if enabled else Style.c("night:3")
	var bot := Style.c(ramp + ":1") if enabled else Style.c("night:2")
	if kind == "ghost" and enabled:
		top = Style.c("night:4")
		bot = Style.c("night:3")
	if down:
		var t := top
		top = bot
		bot = t
	draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.55)), top)
	draw_rect(Rect2(body.position + Vector2(0, body.size.y * 0.55), Vector2(body.size.x, body.size.y * 0.45)), bot)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 1)), Style.c(ramp + ":3") if enabled else Style.c("night:3"))
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - 1), Vector2(body.size.x, 1)), Style.c(ramp + ":0") if enabled else Style.c("night:1"))
	if kind == "primary" and enabled:
		# a slow pulse on the rim invites the tap
		var a := 0.45 + 0.35 * sin(_age * 3.0)
		draw_rect(rr.grow(1.0), Color(Style.c("gold:4"), a), false, 1.0)
	var f := Game.font("bold")
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	text(Vector2(rr.get_center().x - w / 2.0, rr.get_center().y + 3.5), label, TEXT if enabled else MUTED.darkened(0.3), 8, "bold")
	if enabled:
		var hr := r
		if hr.size.x < MIN_TAP:
			hr = hr.grow_individual((MIN_TAP - hr.size.x) / 2.0, 0, (MIN_TAP - hr.size.x) / 2.0, 0)
		if hr.size.y < MIN_TAP:
			hr = hr.grow_individual(0, (MIN_TAP - hr.size.y) / 2.0, 0, (MIN_TAP - hr.size.y) / 2.0)
		_buttons.append([hr, id])


## Synergy tags of an offer item (spells and relics), for the card chips.
static func item_tags(item: Dictionary) -> Array:
	match item["t"]:
		&"spell":
			return Catalog.tags(item["id"])
		&"relic":
			return Relics.tags(item["id"])
		&"compile":
			return Catalog.tags(item["id"])
	return []


## Small tag chips in a centered row; returns the height used (0 when no tags).
func chips(cx: float, y: float, tags: Array, col := Style.c("cyan:4")) -> float:
	if tags.is_empty():
		return 0.0
	var f := Game.font("small")
	var ws: Array = tags.map(func(t: String) -> float: return f.get_string_size(t.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 8.0)
	var total := 0.0
	for w in ws:
		total += w + 3.0
	var x := cx - (total - 3.0) / 2.0
	for i in tags.size():
		var r := Rect2(x, y, ws[i], 10)
		draw_rect(r, Style.c("night:3"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Style.c("night:4"))
		text(r.position + Vector2(4, 8), String(tags[i]).to_upper(), col)
		x += ws[i] + 3.0
	return 12.0


## Registers an invisible tappable area (cards, slots).
func area(r: Rect2, id: String) -> void:
	_buttons.append([r, id])


func icon_at(tex: Texture2D, center: Vector2, scale := 1.0, mod := Color.WHITE) -> void:
	var sz := tex.get_size() * scale
	draw_texture_rect(tex, Rect2((center - sz / 2.0).round(), sz), false, mod)


static func item_icon(item: Dictionary) -> Texture2D:
	match item["t"]:
		&"spell":
			return Icons.spell(Catalog.spell(item["id"]))
		&"relic":
			return Icons.relic(item["id"])
		&"wand":
			return Icons.glyph("wand", Catalog.wand(item["id"]).color)
		&"heal":
			return Icons.glyph("heart", Color("#ff4d6d"))
		&"loadout":
			return Icons.glyph("wand", Catalog.wand(RunState.LOADOUTS[item["id"]]["wand"]).color)
		&"slot":
			return Icons.glyph("box", Style.c("gold:3"))
		&"compile":
			return Icons.spell(Catalog.spell(item["id"]))
	return Icons.glyph("coin", Color("#ffd36b"))


const KIND_NAMES := ["Shooting spell", "Boost", "Trigger", "Passive", "Debugger rune", "Familiar"]


static func kind_label(item: Dictionary) -> String:
	match item["t"]:
		&"spell":
			var d := Catalog.spell(item["id"])
			return KIND_NAMES[d.kind]
		&"relic":
			return "Relic"
		&"wand":
			return "Wand"
		&"loadout":
			return "Starting wand"
		&"slot":
			return "Wand upgrade"
		&"compile":
			return "Compile"
		&"heal":
			return "Potion"
	return "Gold"


static func rarity_color(r: int) -> Color:
	return Color(Relics.RARITY_COLORS[clampi(r, 0, 3)])


## A short stat line for a spell: mana and damage at its level.
static func spell_stats(id: StringName, lv := 1) -> String:
	var d := Catalog.spell(id)
	var bits: Array[String] = []
	if d.kind == SpellDef.Kind.PASSIVE:
		return "Works from any slot"
	bits.append("%d mana" % roundi(d.mana_at(lv)))
	if (d.kind == SpellDef.Kind.PROJ or d.kind == SpellDef.Kind.FAMILIAR) and d.damage_at(lv) > 0.0:
		var n := int(d.param("count", lv, 1))
		bits.append(("%d dmg" % roundi(d.damage_at(lv))) + (" x%d" % n if n > 1 else ""))
	for k in d.keywords:
		bits.append(k.to_upper())
	return "  ".join(bits)
