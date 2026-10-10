extends Node2D
## Ghost marks: past marks drawn back into the world where they were made, like messages
## left on the floor. Orange: open. Pulsing blue: Claude is on it. Blue outline with a
## check: fixed (go retest it). Walk up to one, or hover it, to read the note.

signal near_changed(mark: Dictionary)

const Brand := preload("res://addons/playmark/brand.gd")
const Images := preload("res://addons/playmark/images.gd")

## [{seq, id, status, category, note, resolution, world: [x, y]}] for the current scene.
var marks: Array = []
## Optional: the node whose distance decides "near" (the player). The mouse otherwise.
var anchor: Node2D

var _near_id := ""
var _t := 0.0


func _ready() -> void:
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	z_as_relative = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var near := {}
	if visible and not marks.is_empty():
		var from := anchor.global_position if is_instance_valid(anchor) else get_global_mouse_position()
		var reach := _unit() * 26.0
		var best := INF
		for m in marks:
			var d := from.distance_to(_pos(m) + Vector2(0, -8) * _unit())
			if d < reach and d < best:
				best = d
				near = m
	var id: String = near.get("id", "")
	if id != _near_id:
		_near_id = id
		near_changed.emit(near)


## World units per viewport pixel, so ghosts keep their size whatever the zoom.
func _unit() -> float:
	var s := get_viewport().get_canvas_transform().get_scale().x
	var vp_h := get_viewport().get_visible_rect().size.y
	return maxf(vp_h / 270.0, 1.0) / maxf(s, 0.0001)


func _pos(m: Dictionary) -> Vector2:
	return Vector2(m.world[0], m.world[1])


func _draw() -> void:
	var u := _unit()
	for m in marks:
		var status: String = m.get("status", "new")
		var near: bool = m.get("id", "") == _near_id
		var r := (9.0 if near else 7.0) * u
		# The marker floats above the spot on a stem, so it never hides inside what it marks.
		var base := _pos(m)
		var p := base + Vector2(0, -16 * u + sin(_t * 2.2 + float(m.seq)) * 1.5 * u)
		draw_line(base, p + Vector2(0, r), Color(Brand.PAPER if status != "fixed" else Brand.BLUE, 0.6), maxf(u * 0.75, 1.0))
		draw_circle(base, 1.5 * u, Brand.ORANGE if status == "new" else Brand.BLUE)
		# A soft glow on the floor.
		draw_set_transform(base + Vector2(0, 2 * u), 0, Vector2(1, 0.35))
		draw_circle(Vector2.ZERO, r * 1.6, Color(Brand.ORANGE if status == "new" else Brand.BLUE, 0.18))
		draw_set_transform(Vector2.ZERO)
		var diamond := PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0)])
		var outline := diamond.duplicate()
		outline.append(diamond[0])
		match status:
			"fixed":
				draw_colored_polygon(diamond, Color(Brand.INK, 0.6))
				draw_polyline(outline, Brand.BLUE, maxf(u, 1.0))
				draw_polyline(PackedVector2Array([p + Vector2(-3, 0) * u, p + Vector2(-0.5, 2.5) * u, p + Vector2(3.5, -2.5) * u]), Brand.BLUE, maxf(u * 1.2, 1.0))
			"working":
				var pulse := 0.55 + 0.45 * sin(_t * 6.0)
				draw_colored_polygon(diamond, Color(Brand.BLUE, pulse))
				draw_polyline(outline, Brand.INK, maxf(u, 1.0))
			_:
				draw_colored_polygon(diamond, Brand.ORANGE)
				draw_polyline(outline, Brand.INK, maxf(u, 1.0))
		_digits(p + Vector2(r + 2 * u, -r - 3 * u), int(m.seq), u, Brand.PAPER if status != "fixed" else Brand.BLUE)


## The pixel digits from images.gd, so the seq number reads in pixel-art games too.
func _digits(at: Vector2, n: int, u: float, c: Color) -> void:
	var text := str(n)
	var cell := maxf(roundf(u), 1.0)
	at = at.round()
	draw_rect(Rect2(at - Vector2(cell, cell), Vector2(text.length() * 4 * cell + cell, 7 * cell)), Color(Brand.INK, 0.75))
	for ci in text.length():
		var glyph: String = Images.DIGITS[int(text[ci])]
		for row in 5:
			for col in 3:
				if glyph[row * 3 + col] == "1":
					draw_rect(Rect2(at + Vector2((ci * 4 + col) * cell, row * cell), Vector2(cell, cell)), c)
