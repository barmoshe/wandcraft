class_name FxLayer
extends Node2D
## Short-lived effects drawn immediately: rings, beams and sparks are additive
## (they feed the glow); damage numbers and toasts are drawn on a normal-blend child.
## Everything is capped so a wild wand cannot tank the frame rate.

const MAX_SPARKS := 500
const MAX_TEXTS := 40
const MAX_SHARDS := 700

var rings: Array = []    # [pos, r0, r1, t, life, color]
var beams: Array = []    # [a, b, color, width, t, life]
var _sparks: Array = []   # [pos, vel, t, life, color]
var texts: Array = []    # [pos, text, color, t, size]
var _shards: Array = []  # normal-blend pixels: [pos, vel, t, life, color, gravity]
var muzzles: Array = []  # [pos, angle, color, t]: a 2-frame cast flash at the wand tip
const MUZZLE_LIFE := 0.06
var poofs: Array = []    # [pos, t]: the 4-frame death puff (D6)
const POOF_FPS := 12.0
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


## Cast flash at the wand tip: frame 1 a white core, frame 2 a 4-point star in the spell's
## color pointing along the aim (design-plan §7 VFX, §10 feel). Pixel-snapped.
func muzzle(p: Vector2, angle: float, c: Color) -> void:
	if muzzles.size() >= 8:
		muzzles.pop_front()
	muzzles.append([p, angle, c, 0.0])


func beam(a: Vector2, b: Vector2, c: Color, width: float) -> void:
	beams.append([a, b, c, width, 0.0, 0.14])


func sparks(p: Vector2, n: int, c: Color, speed: float) -> void:
	for i in n:
		if _sparks.size() >= MAX_SPARKS:
			return
		var v := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 1.0) * speed
		_sparks.append([p, v, 0.0, rng.randf_range(0.18, 0.4), c])


## An enemy (or anything with a sprite) bursts into its own pixels.
func dissolve(center: Vector2, tex: Texture2D, flip := false, scale := 1.0) -> void:
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	var w := img.get_width()
	var h := img.get_height()
	var step := 1 if w * h <= 420 else 2
	for y in range(0, h, step):
		for x in range(0, w, step):
			if _shards.size() >= MAX_SHARDS:
				return
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var lx := (w - 1 - x) if flip else x
			var p := center + Vector2((lx - w / 2.0) * scale, (y - h) * scale)
			var v := (p - center - Vector2(0, -h * 0.4)).normalized() * rng.randf_range(20, 90) + Vector2(0, -30)
			_shards.append([p, v, 0.0, rng.randf_range(0.35, 0.7), c, 160.0])


## A little dust under the feet.
func dust(p: Vector2) -> void:
	if _shards.size() < MAX_SHARDS:
		_shards.append([p + Vector2(rng.randf_range(-3, 3), 0), Vector2(rng.randf_range(-10, 10), -8), 0.0, 0.35, Color(0.7, 0.72, 0.6, 0.6), 0.0])


## A 4-frame puff of dust where an enemy died (design-plan §8: the dissolve plus a poof).
func poof(p: Vector2) -> void:
	if poofs.size() >= 24:
		poofs.pop_front()
	poofs.append([p.round(), 0.0])


## The puff frames: a ring of dithered pixels that widens and thins out, stepping down the
## bone ramp (never fading by alpha). 17x17, drawn centred.
static func poof_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for k in 4:
		out.append(PixelArt.cached("poof_%d" % k, func() -> Image:
			const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
			var img := Image.create_empty(17, 17, false, Image.FORMAT_RGBA8)
			var r_out := 3.5 + k * 1.6
			var r_in := maxf(0.0, r_out - 3.0 - k * 0.3)
			var density := 0.95 - k * 0.24
			var col := Style.c("bone:%d" % (4 - k))
			for j in 17:
				for i in 17:
					var d := Vector2(i - 8, j - 8).length()
					if d > r_out or d < r_in:
						continue
					if (float(BAYER[(j % 4) * 4 + i % 4]) + 0.5) / 16.0 < density:
						img.set_pixel(i, j, col)
			return img))
	return out


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
	_shards.clear()
	texts.clear()
	muzzles.clear()
	poofs.clear()


func update(dt: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i][3] += dt
		if rings[i][3] >= rings[i][4]:
			rings.remove_at(i)
	for i in range(muzzles.size() - 1, -1, -1):
		muzzles[i][3] += dt
		if muzzles[i][3] >= MUZZLE_LIFE:
			muzzles.remove_at(i)
	for i in range(beams.size() - 1, -1, -1):
		beams[i][4] += dt
		if beams[i][4] >= beams[i][5]:
			beams.remove_at(i)
	var ws := 0
	for i in _shards.size():
		var s: Array = _shards[i]
		s[2] += dt
		if s[2] < s[3]:
			s[1] += Vector2(0, s[5] * dt)
			s[0] += s[1] * dt
			s[1] *= pow(0.2, dt)
			_shards[ws] = s
			ws += 1
	_shards.resize(ws)
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
	for i in range(poofs.size() - 1, -1, -1):
		poofs[i][1] += dt
		if poofs[i][1] * POOF_FPS >= 4.0:
			poofs.remove_at(i)
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
	for m in muzzles:
		var p: Vector2 = (m[0] as Vector2).round()
		var c: Color = m[2]
		if m[3] < MUZZLE_LIFE * 0.5:
			# frame 1: a white core
			draw_rect(Rect2(p - Vector2(2, 1), Vector2(5, 3)), Color(1.8, 1.8, 1.8))
			draw_rect(Rect2(p - Vector2(1, 2), Vector2(3, 5)), Color(1.8, 1.8, 1.8))
		else:
			# frame 2: a star in the spell's color, the long ray along the aim
			var hot := Color(c.r * 1.6, c.g * 1.6, c.b * 1.6)
			var fwd := Vector2.from_angle(m[1])
			var side := fwd.orthogonal()
			for k2 in range(1, 5):
				draw_rect(Rect2((p + fwd * k2).round(), Vector2.ONE), hot)
			for k2 in range(1, 3):
				draw_rect(Rect2((p - fwd * k2).round(), Vector2.ONE), hot)
				draw_rect(Rect2((p + side * k2).round(), Vector2.ONE), hot)
				draw_rect(Rect2((p - side * k2).round(), Vector2.ONE), hot)
			draw_rect(Rect2(p, Vector2.ONE), Color(1.8, 1.8, 1.8))


func _draw_texts() -> void:
	var pf := poof_frames()
	for pp in poofs:
		_text_node.draw_texture(pf[mini(3, int(pp[1] * POOF_FPS))], (pp[0] as Vector2) - Vector2(8, 8))
	for s in _shards:
		var c: Color = s[4]
		var k: float = 1.0 - s[2] / s[3]
		_text_node.draw_rect(Rect2((s[0] as Vector2).round(), Vector2.ONE), Color(c.r, c.g, c.b, c.a * minf(1.0, k * 2.0)))
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
