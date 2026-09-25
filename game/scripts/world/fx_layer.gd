class_name FxLayer
extends Node2D
## Short-lived effects drawn immediately: rings, beams and sparks are additive
## (they feed the glow); damage numbers and toasts are drawn on a normal-blend child.
## Everything is capped so a wild wand cannot tank the frame rate.

const MAX_SPARKS := 500
const MAX_TEXTS := 40
const MAX_SHARDS := 700
## Design v3: phones get half the effect budget (the Mac stress tick already sits at 8-9 ms
## of a 10 ms budget; a mid-range phone is several times slower).
var max_sparks := MAX_SPARKS / 2 if Game.is_touch() else MAX_SPARKS
var max_shards := MAX_SHARDS / 2 if Game.is_touch() else MAX_SHARDS
var trail_cap := TRAIL_CAP / 2 if Game.is_touch() else TRAIL_CAP

var rings: Array = []    # [pos, r0, r1, t, life, color]
var beams: Array = []    # [a, b, color, width, t, life]
var _sparks: Array = []   # [pos, vel, t, life, color]
var texts: Array = []    # [pos, text, color, t, size]
var _shards: Array = []  # normal-blend pixels: [pos, vel, t, life, color, gravity]
var muzzles: Array = []  # [pos, angle, color, t]: a 2-frame cast flash at the wand tip
const MUZZLE_LIFE := 0.06
var poofs: Array = []    # [pos, t]: the 4-frame death puff (D6)
var ghosts: Array = []   # [texture, top-left, flip, t]: dash afterimages (D9)
const GHOST_LIFE := 0.2
const POOF_FPS := 12.0
var hits: Array = []     # [pos, angle, color, t]: the 3-frame hit spark, along the hit (D6)
const HIT_FPS := 36.0
var booms: Array = []    # [pos, radius bucket, color, t]: the 8-frame explosion (D6)
const BOOM_FPS := 20.0
const MERGE_T := 0.15    # hits on one target within this merge into one number (D6)
var _by_key := {}        # target key -> its latest number (the entry itself)
## Player bullets that leave a dithered trail (D6); the first TRAIL_CAP live ones only.
var trail_pool: BulletPool
const TRAIL_CAP := 300
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
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
		if _sparks.size() >= max_sparks:
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
			if _shards.size() >= max_shards:
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
	if _shards.size() < max_shards:
		_shards.append([p + Vector2(rng.randf_range(-3, 3), 0), Vector2(rng.randf_range(-10, 10), -8), 0.0, 0.35, Color(0.7, 0.72, 0.6, 0.6), 0.0])


## A dash afterimage: the hero's frame at `center` (the sprite's centre), fading out in the
## arcane ramp. At most a handful live at once.
func afterimage(tex: Texture2D, center: Vector2, flip: bool) -> void:
	if tex == null:
		return
	if ghosts.size() >= 6:
		ghosts.pop_front()
	ghosts.append([tex, (center - tex.get_size() / 2.0).round(), flip, 0.0])


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


## A hit spark: a white pop, then three rays fanning out along the hit direction.
func hit_spark(p: Vector2, angle: float, c: Color) -> void:
	if hits.size() >= 48:
		hits.pop_front()
	hits.append([p.round(), angle, c, 0.0])


## An explosion of radius r: four hot frames in the spell's colour (additive), then four
## frames of dithered smoke that thins out down the stone ramp.
func explosion(p: Vector2, r: float, c: Color) -> void:
	if booms.size() >= 16:
		booms.pop_front()
	booms.append([p.round(), clampi(int(roundf(r / 4.0)) * 4, 8, 64), c, 0.0])


## Baked explosion frames for one radius: 0-3 are white (tinted when drawn, additive),
## 4-7 are smoke. Square, radius + 2 from the centre.
static func boom_frames(r: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for k in 8:
		out.append(PixelArt.cached("boom_%d_%d" % [r, k], func() -> Image:
			var n := r * 2 + 5
			var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
			var ctr := Vector2(r + 2.5, r + 2.5)
			for j in n:
				for i in n:
					var d := Vector2(i + 0.5, j + 0.5).distance_to(ctr) / float(r)
					var dither := (float(BAYER[(j % 4) * 4 + i % 4]) + 0.5) / 16.0
					var col := Color(0, 0, 0, 0)
					match k:
						0:
							if d < 0.4: col = Color.WHITE
						1:
							if d < 0.35: col = Color.WHITE
							elif d < 0.75: col = Color(0.8, 0.8, 0.8)
						2:
							if d < 0.3: col = Color(0.7, 0.7, 0.7)
							elif d > 0.72 and d < 0.95: col = Color(0.9, 0.9, 0.9)
							elif d < 0.72 and dither < 0.5: col = Color(0.45, 0.45, 0.45)
						3:
							if d > 0.88 and d < 1.0: col = Color(0.6, 0.6, 0.6)
							elif d < 0.88 and dither < 0.2: col = Color(0.4, 0.4, 0.4)
						_:
							# smoke: a widening disc whose density falls each frame
							var s := k - 4
							if d < 0.75 + s * 0.12 and dither < 0.62 - s * 0.15:
								col = Style.c("stone:%d" % (4 - s))
								col.a = 0.85
					img.set_pixel(i, j, col)
			return img))
	return out


func text(p: Vector2, s: String, c: Color, size := 8) -> void:
	if texts.size() >= MAX_TEXTS:
		var old: Array = texts.pop_front()
		if old[5] >= 0 and _by_key.get(old[5]) == old:
			_by_key.erase(old[5])
	texts.append([p, s, c, 0.0, size, -1, 0.0])


## Damage numbers in three tiers (design-plan §7): white hits, bigger gold crits, and red
## damage to the player. Hits on the same target (key) within 150 ms add up into one number
## that pops again, so a shotgun reads as one big hit instead of a smear.
func number(p: Vector2, v: float, crit: bool, key := -1) -> void:
	if key >= 0:
		# the live number for this target, if it is young enough to merge into (O(1): a storm
		# lands hundreds of hits a tick)
		var tx: Variant = _by_key.get(key)
		if tx != null and (tx as Array)[3] < MERGE_T and (tx as Array)[5] == key:
			tx[6] += v
			tx[1] = str(roundi(tx[6]))
			tx[3] = 0.0
			if crit:
				tx[2] = Color("#ffe066")
				tx[4] = 10
			return
	text(p + Vector2(rng.randf_range(-4, 4), 0), str(roundi(v)), Color("#ffe066") if crit else Color.WHITE, 10 if crit else 8)
	var e: Array = texts[texts.size() - 1]
	e[5] = key
	e[6] = v
	if key >= 0:
		_by_key[key] = e


## The third tier: damage the player takes, red and big.
func hurt_number(p: Vector2, v: float) -> void:
	text(p, "-%d" % roundi(v), Style.c("threat:3"), 10)


func clear_all() -> void:
	rings.clear()
	beams.clear()
	_sparks.clear()
	_shards.clear()
	texts.clear()
	_by_key.clear()
	muzzles.clear()
	poofs.clear()
	hits.clear()
	booms.clear()
	ghosts.clear()


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
	for i in range(ghosts.size() - 1, -1, -1):
		ghosts[i][3] += dt
		if ghosts[i][3] >= GHOST_LIFE:
			ghosts.remove_at(i)
	for i in range(hits.size() - 1, -1, -1):
		hits[i][3] += dt
		if hits[i][3] * HIT_FPS >= 3.0:
			hits.remove_at(i)
	for i in range(booms.size() - 1, -1, -1):
		booms[i][3] += dt
		if booms[i][3] * BOOM_FPS >= 8.0:
			booms.remove_at(i)
	for i in range(poofs.size() - 1, -1, -1):
		poofs[i][1] += dt
		if poofs[i][1] * POOF_FPS >= 4.0:
			poofs.remove_at(i)
	for i in range(texts.size() - 1, -1, -1):
		texts[i][3] += dt
		if texts[i][3] > 0.8:
			if texts[i][5] >= 0 and _by_key.get(texts[i][5]) == texts[i]:
				_by_key.erase(texts[i][5])
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
	for h in hits:
		_draw_hit(h)
	for bm in booms:
		var f := int(bm[3] * BOOM_FPS)
		if f < 4:
			var c: Color = bm[2]
			var bt: Texture2D = boom_frames(bm[1])[f]
			draw_texture(bt, (bm[0] as Vector2) - Vector2(bm[1] + 2, bm[1] + 2), Color(c.r * 1.25 + 0.1, c.g * 1.25 + 0.1, c.b * 1.25 + 0.1))
	if trail_pool:
		_draw_trails()
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


func _draw_hit(h: Array) -> void:
	var f := int(h[3] * HIT_FPS)
	var p: Vector2 = h[0]
	var c: Color = h[2]
	var hot := Color(c.r * 1.6, c.g * 1.6, c.b * 1.6)
	var fwd := Vector2.from_angle(h[1])
	if f == 0:
		draw_rect(Rect2(p - Vector2(1, 0), Vector2(3, 1)), Color(1.8, 1.8, 1.8))
		draw_rect(Rect2(p - Vector2(0, 1), Vector2(1, 3)), Color(1.8, 1.8, 1.8))
		return
	for da in [-0.55, 0.0, 0.55]:
		var d := fwd.rotated(da)
		var from := 1 if f == 1 else 3
		var to := 3 if f == 1 else 5
		for k in range(from, to + (1 if da == 0.0 else 0)):
			draw_rect(Rect2((p + d * k).round(), Vector2.ONE), hot if f == 1 else c)


## Up to three dithered pixels behind each player bullet, stepping down in brightness.
func _draw_trails() -> void:
	var n := mini(trail_cap, trail_pool.active.size())
	for i in n:
		var b: Bullet = trail_pool.active[i]
		if not b.alive or b.vel.length_squared() < 3600.0:
			continue
		var back := -b.vel.normalized()
		var c := b.color
		for k in range(1, 4):
			var q := (b.pos + back * (k * 3.0 + b.r)).round()
			if (int(q.x) + int(q.y) + k) % 2 == 0:
				continue
			var a := 0.55 - k * 0.15
			draw_rect(Rect2(q, Vector2.ONE), Color(c.r * a * 1.6, c.g * a * 1.6, c.b * a * 1.6))


func _draw_texts() -> void:
	var gc := Style.c("arcane:3")
	for g in ghosts:
		# stepped fade (3 levels), not a smooth alpha ramp
		var a := 0.5 - 0.15 * floorf(float(g[3]) / GHOST_LIFE * 3.0)
		var tex: Texture2D = g[0]
		_text_node.draw_texture_rect(tex, Rect2(g[1], tex.get_size() * Vector2(-1.0 if g[2] else 1.0, 1.0)), false, Color(gc.r, gc.g, gc.b, a))
	for bm in booms:
		var f := int(bm[3] * BOOM_FPS)
		if f >= 4:
			var r: int = bm[1]
			_text_node.draw_texture(boom_frames(r)[mini(7, f)], (bm[0] as Vector2) - Vector2(r + 2, r + 2))
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
