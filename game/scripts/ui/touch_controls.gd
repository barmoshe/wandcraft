class_name TouchControls
extends Control
## Floating twin sticks for phones. The left half of the screen moves (the stick appears
## where the thumb lands); the right half aims and fires.
## Tapping a wand row in the HUD selects that wand. Multi-touch safe: each finger is
## tracked by its index.

signal hud_pressed(id: String)

const STICK_R := 26.0
const DEAD := 0.18

var controls: Controls
var hud: Hud
var _move_id := -1
var _aim_id := -1
var _move_origin := Vector2.ZERO
var _move_pos := Vector2.ZERO
var _aim_origin := Vector2.ZERO
var _aim_pos := Vector2.ZERO
var touched_once := false
var enabled := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Drops both sticks (a menu opened, or the app lost focus).
func release_all() -> void:
	_move_id = -1
	_aim_id = -1
	_apply()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		touched_once = true
		if t.pressed:
			_press(t.index, t.position)
		else:
			_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _move_id:
			_move_pos = d.position
		elif d.index == _aim_id:
			_aim_pos = d.position
		_apply()


func _press(id: int, p: Vector2) -> void:
	if hud:
		var b := hud.hit_button(p)
		if b != "":
			hud_pressed.emit(b)
			return
		var wi := hud.hit_wand(p)
		if wi >= 0:
			controls.select_wand = wi
			return
	var half := get_viewport_rect().size.x / 2.0
	if p.x < half and _move_id < 0:
		_move_id = id
		_move_origin = p
		_move_pos = p
	elif p.x >= half and _aim_id < 0:
		_aim_id = id
		_aim_origin = p
		_aim_pos = p
	_apply()


func _release(id: int) -> void:
	if id == _move_id:
		_move_id = -1
	elif id == _aim_id:
		_aim_id = -1
	_apply()


func _apply() -> void:
	controls.move = _stick(_move_id, _move_origin, _move_pos, true)
	controls.aim = _stick(_aim_id, _aim_origin, _aim_pos, false)


func _stick(id: int, o: Vector2, p: Vector2, drag_origin: bool) -> Vector2:
	if id < 0:
		return Vector2.ZERO
	var d := p - o
	# the stick base follows the thumb when it overshoots, so there is no dead edge
	if drag_origin and d.length() > STICK_R:
		_move_origin = p - d.normalized() * STICK_R
		d = p - _move_origin
	var v := d / STICK_R
	if v.length() < DEAD:
		return Vector2.ZERO
	return v.limit_length(1.0)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not touched_once and not OS.has_feature("mobile"):
		return
	if _move_id >= 0:
		_draw_stick(_move_origin, _move_pos, Color(0.7, 0.8, 1.0))
	if _aim_id >= 0:
		_draw_stick(_aim_origin, _aim_pos, Color(1.0, 0.85, 0.45))


func _draw_stick(o: Vector2, p: Vector2, c: Color) -> void:
	draw_circle(o, STICK_R, Color(0.05, 0.03, 0.1, 0.35))
	draw_arc(o, STICK_R, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.5), 1.0)
	var k := o + (p - o).limit_length(STICK_R)
	draw_circle(k, 9.0, Color(c.r, c.g, c.b, 0.55))
	draw_arc(k, 9.0, 0.0, TAU, 20, Color(c.r, c.g, c.b, 0.9), 1.0)
