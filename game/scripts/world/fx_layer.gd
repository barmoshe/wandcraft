class_name FxLayer
extends Node2D
## Short-lived effects drawn immediately: rings, beams and sparks are additive
## (they feed the glow); damage numbers and toasts are drawn on a normal-blend child.
## Everything is capped so a wild wand cannot tank the frame rate.

const MAX_SPARKS := 500
const MAX_TEXTS := 40

var rings: Array = []    # [pos, r0, r1, t, life, color]
var beams: Array = []    # [a, b, color, width, t, life]
var _sparks: Array = []   # [pos, vel, t, life, color]
var texts: Array = []    # [pos, text, color, t, size]
var rng := RandomNumberGenerator.new()
var _text_node: Node2D


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	_text_node = Node2D.new()
	_text_node.z_index = 10
	add_child(_text_node)
	_text_node.draw.connect(_draw_texts)


func ring(p: Vector2, r0: float, r1: float, life: float, c: Color) -> void:
	rings.append([p, r0, r1, 0.0, life, c])


func beam(a: Vector2, b: Vector2, c: Color, width: float) -> void:
	beams.append([a, b, c, width, 0.0, 0.14])


func sparks(p: Vector2, n: int, c: Color, speed: float) -> void:
	for i in n:
		if _sparks.size() >= MAX_SPARKS:
			return
		var v := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * speed
		_sparks.append([p, v, 0.0, rng.randf_range(0.18, 0.4), c])


func text(p: Vector2, s: String, c: Color, size := 8) -> void:
	if texts.size() >= MAX_TEXTS:
		texts.pop_front()
	texts.append([p, s, c, 0.0, size])


func number(p: Vector2, v: float, crit: bool) -> void:
	text(p + Vector2(rng.randf_range(-4, 4), 0), str(roundi(v)), Color("#ffe066") if crit else Color.WHITE, 10 if crit else 8)


func clear_all() -> void:
	rings.clear()
	beams.clear()
	_sparks.clear()
	texts.clear()


func update(dt: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i][3] += dt
		if rings[i][3] >= rings[i][4]:
			rings.remove_at(i)
	for i in range(beams.size() - 1, -1, -1):
		beams[i][4] += dt
		if beams[i][4] >= beams[i][5]:
			beams.remove_at(i)
	var w := 0
	for i in _sparks.size():
		var s: Array = _sparks[i]
		s[2] += dt
		if s[2] < s[3]:
			s[0] += s[1] * dt
			s[1] *= pow(0.05, dt)
			_sparks[w] = s
			w += 1
	_sparks.resize(w)
	for i in range(texts.size() - 1, -1, -1):
		texts[i][3] += dt
		if texts[i][3] > 0.8:
			texts.remove_at(i)


func _process(_dt: float) -> void:
	queue_redraw()
	_text_node.queue_redraw()


func _draw() -> void:
	for rg in rings:
		var k: float = rg[3] / rg[4]
		var rad: float = lerpf(rg[1], rg[2], 1.0 - pow(1.0 - k, 2.0))
		var c: Color = rg[5]
		draw_arc(rg[0], rad, 0.0, TAU, clampi(int(rad * 1.5), 10, 48), Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, 1.0 - k), 1.0 + (1.0 - k))
	for b in beams:
		var k: float = b[4] / b[5]
		var c: Color = b[2]
		var wd: float = b[3] * (1.0 - k * 0.6)
		draw_line(b[0], b[1], Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, 0.45 * (1.0 - k)), wd + 3.0)
		draw_line(b[0], b[1], Color(1.6, 1.6, 1.6, 1.0 - k), maxf(1.0, wd))
	for s in _sparks:
		var c: Color = s[4]
		var k: float = 1.0 - s[2] / s[3]
		var p: Vector2 = s[0]
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(c.r * 1.5, c.g * 1.5, c.b * 1.5, k))


func _draw_texts() -> void:
	var font := Game.font()
	for tx in texts:
		var k: float = tx[3] / 0.8
		var p: Vector2 = tx[0] + Vector2(0, -14.0 * (1.0 - pow(1.0 - k, 3.0)))
		var s: String = tx[1]
		var size: int = tx[4]
		var c: Color = tx[2]
		var a := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		var wdt := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := (p - Vector2(wdt / 2.0, 0)).round()
		_text_node.draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 2, Color(0.04, 0.02, 0.08, a))
		_text_node.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c.r, c.g, c.b, a))
