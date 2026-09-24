class_name RoomPainter
extends RefCounted
## Bakes a room into one image (0.4, decisions/0007): the Ruined Grove.
##   - floor: cool slate flagstones with cracks, moss creeping in from the walls, the odd
##     puddle, root and flower, kept low-contrast so actors always read on top of it
##   - walls: moss-topped caps and a brick face with broken bricks and moss drips
##   - surroundings: MARGIN tiles of overgrown ruin around the room (canopy, trunks, broken
##     pillars), so wide phone screens show the grove instead of black bars
## The image's (0,0) is MARGIN tiles up-left of the room's (0,0): World offsets the sprite.
## Deterministic from the seed. Performance: big areas use fill_rect, noise is sampled on a
## 2px grid; a room bakes in well under 100 ms on desktop.

const TS := 16
const FACE := 9
const MARGIN := Vector2i(14, 9)


static func size_px(gw: int, gh: int) -> Vector2i:
	return Vector2i((gw + MARGIN.x * 2) * TS, (gh + MARGIN.y * 2) * TS)


static func paint(grid: PackedByteArray, gw: int, gh: int, seed_value: int) -> Image:
	var sz := size_px(gw, gh)
	var img := Image.create_empty(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var O := MARGIN * TS
	var at := func(x: int, y: int) -> int:
		return 1 if x < 0 or y < 0 or x >= gw or y >= gh else grid[y * gw + x]
	var wallish := func(t: int) -> bool: return t == 1 or t == 3
	_surroundings(img, gw, gh, rng)
	# floors
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				continue
			_stones(img, O.x + x * TS, O.y + y * TS, rng)
	# moss creeping from the walls (noise, biased toward wall-adjacent tiles)
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				continue
			var near := 0.0
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if wallish.call(at.call(x + d.x, y + d.y)):
					near += 0.12
			for j in range(0, TS, 2):
				for i in range(0, TS, 2):
					var px := x * TS + i
					var py := y * TS + j
					var n := noise.get_noise_2d(px, py) * 0.5 + 0.5 + near
					if n > 0.72:
						var c := Style.c("moss:1").lerp(Style.c("moss:2"), 0.5) if n < 0.8 else Style.c("moss:2")
						if n > 0.9:
							c = Style.c("moss:2").lerp(Style.c("moss:3"), 0.5)
						img.fill_rect(Rect2i(O.x + px, O.y + py, 2, 2), c)
					elif n > 0.68 and (i + j) % 4 == 0:
						img.fill_rect(Rect2i(O.x + px, O.y + py, 1, 1), Style.c("moss:1"))
	# details: puddles, roots, flowers, tufts; then hazard plates on top
	var puddles := 0
	for y in range(2, gh - 1):
		for x in range(1, gw - 1):
			if at.call(x, y) != 0:
				continue
			var X := O.x + x * TS
			var Y := O.y + y * TS
			var r := rng.randf()
			if r < 0.02 and puddles < 3:
				puddles += 1
				_puddle(img, X + 2, Y + 4, rng)
			elif r < 0.07:
				_tuft(img, X + 2 + rng.randi_range(0, 10), Y + 6 + rng.randi_range(0, 7), rng)
			elif r < 0.10:
				_flowers(img, X + rng.randi_range(2, 12), Y + rng.randi_range(3, 12), rng)
	for y in gh:
		for x in gw:
			if at.call(x, y) == 2:
				_spike_plate(img, O.x + x * TS, O.y + y * TS)
	# ambient occlusion under and beside walls
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				continue
			var X := O.x + x * TS
			var Y := O.y + y * TS
			if wallish.call(at.call(x, y - 1)):
				for k in 5:
					_blend(img, Rect2i(X, Y + k, TS, 1), Color(0, 0, 0, 0.4 - k * 0.075))
			if wallish.call(at.call(x - 1, y)):
				for k in 3:
					_blend(img, Rect2i(X + k, Y, 1, TS), Color(0, 0, 0, 0.26 - k * 0.08))
			if wallish.call(at.call(x + 1, y)):
				for k in 3:
					_blend(img, Rect2i(X + TS - 1 - k, Y, 1, TS), Color(0, 0, 0, 0.26 - k * 0.08))
	# walls
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				_wall(img, O.x + x * TS, O.y + y * TS, x, y, at, wallish, rng)
	return img


# ------------------------------------------------------------------ floor

static func _stones(img: Image, X: int, Y: int, rng: RandomNumberGenerator) -> void:
	img.fill_rect(Rect2i(X, Y, TS, TS), Style.c("slate:0"))
	var L := rng.randf()
	var rects: Array
	if L < 0.28: rects = [[0, 0, 16, 16]]
	elif L < 0.52: rects = [[0, 0, 16, 8], [0, 8, 16, 8]]
	elif L < 0.76: rects = [[0, 0, 8, 16], [8, 0, 8, 16]]
	elif L < 0.9: rects = [[0, 0, 10, 16], [10, 0, 6, 8], [10, 8, 6, 8]]
	else: rects = [[0, 0, 8, 8], [8, 0, 8, 8], [0, 8, 8, 8], [8, 8, 8, 8]]
	for r in rects:
		var base := Style.c("slate:2")
		var v := rng.randf()
		if v < 0.25:
			base = base.lerp(Style.c("stone:2"), 0.6)
		elif v < 0.4:
			base = base.lerp(Style.c("moss:1"), 0.35)
		base = base.darkened(rng.randf() * 0.07)
		var R := Rect2i(X + r[0] + 1, Y + r[1] + 1, r[2] - 1, r[3] - 1)
		img.fill_rect(R, base)
		img.fill_rect(Rect2i(R.position.x, R.position.y, R.size.x, 1), base.lerp(Style.c("slate:3"), 0.55))
		img.fill_rect(Rect2i(R.position.x, R.position.y, 1, R.size.y), base.lerp(Style.c("slate:3"), 0.3))
		img.fill_rect(Rect2i(R.position.x, R.end.y - 1, R.size.x, 1), base.lerp(Style.c("slate:1"), 0.6))
		if rng.randf() < 0.22 and R.size.x > 5 and R.size.y > 5:
			# a crack: a short jagged line
			var p := Vector2i(R.position.x + rng.randi_range(2, R.size.x - 3), R.position.y + 2)
			var n := rng.randi_range(3, mini(7, R.size.y - 3))
			for k in n:
				img.set_pixel(p.x, p.y + k, Style.c("slate:0"))
				if rng.randf() < 0.4:
					p.x += 1 if rng.randf() < 0.5 else -1
					p.x = clampi(p.x, R.position.x + 1, R.end.x - 2)


static func _puddle(img: Image, X: int, Y: int, rng: RandomNumberGenerator) -> void:
	var w := rng.randi_range(8, 12)
	var h := 5
	for j in h:
		var inset: int = [3, 1, 0, 1, 3][j]
		img.fill_rect(Rect2i(X + inset, Y + j, w - inset * 2, 1), Style.c("frost:0"))
	img.fill_rect(Rect2i(X + 3, Y + 1, w - 7, 1), Style.c("frost:1"))
	img.fill_rect(Rect2i(X + w - 4, Y + 3, 2, 1), Style.c("frost:2"))


static func _tuft(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	for k in 5:
		var h := 2 + rng.randi_range(0, 3) - absi(k - 2)
		if h <= 0:
			continue
		img.fill_rect(Rect2i(x + k, y - h, 1, h), Style.c("leaf:3") if k % 2 else Style.c("leaf:2"))


static func _flowers(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var c := Style.c(["rose:3", "gold:3", "frost:3", "bone:4"][rng.randi_range(0, 3)])
	for k in rng.randi_range(2, 4):
		var p := Vector2i(x + rng.randi_range(-3, 3), y + rng.randi_range(-2, 2))
		if p.x > 0 and p.y > 0 and p.x < img.get_width() - 1 and p.y < img.get_height() - 1:
			img.set_pixel(p.x, p.y + 1, Style.c("leaf:2"))
			img.set_pixel(p.x, p.y, c)


static func _spike_plate(img: Image, X: int, Y: int) -> void:
	img.fill_rect(Rect2i(X + 1, Y + 1, TS - 2, TS - 2), Style.c("night:2"))
	img.fill_rect(Rect2i(X + 1, Y + 1, TS - 2, 1), Style.c("stone:1"))
	img.fill_rect(Rect2i(X + 1, Y + TS - 2, TS - 2, 1), Style.c("stone:2"))
	for k in 4:
		var x := X + 3 + (k % 2) * 7
		var y := Y + 3 + (k / 2) * 7
		img.fill_rect(Rect2i(x, y, 3, 3), Style.c("night:0"))
		img.set_pixel(x + 1, y + 1, Style.c("stone:2"))


# ------------------------------------------------------------------ walls

static func _wall(img: Image, X: int, Y: int, x: int, y: int, at: Callable, wallish: Callable, rng: RandomNumberGenerator) -> void:
	var open: bool = not wallish.call(at.call(x, y + 1))
	var top_h := TS - FACE if open else TS
	var cap := Style.c("slate:1").lerp(Style.c("stone:1"), 0.4)
	img.fill_rect(Rect2i(X, Y, TS, top_h), cap)
	# cap slabs with a seam and a lit top edge
	var seam := 8 if (x + y) % 2 else 5
	img.fill_rect(Rect2i(X + seam, Y, 1, top_h), Style.c("night:2"))
	img.fill_rect(Rect2i(X, Y, TS, 1), cap.lerp(Style.c("slate:3"), 0.4))
	# moss on the cap, heavier where the cap faces the room
	if not wallish.call(at.call(x, y - 1)) or rng.randf() < 0.35:
		for k in rng.randi_range(3, 8):
			var mx := X + rng.randi_range(0, TS - 3)
			img.fill_rect(Rect2i(mx, Y, rng.randi_range(2, 4), 2), Style.c("moss:2"))
			img.set_pixel(mx, Y, Style.c("moss:3"))
	if not wallish.call(at.call(x - 1, y)):
		img.fill_rect(Rect2i(X, Y, 1, top_h), cap.lerp(Style.c("slate:3"), 0.25))
	if not wallish.call(at.call(x + 1, y)):
		img.fill_rect(Rect2i(X + TS - 1, Y, 1, top_h), Style.c("night:1"))
	if not open:
		return
	# the brick face
	var fy := Y + TS - FACE
	img.fill_rect(Rect2i(X, fy, TS, FACE), Style.c("stone:0"))
	for row in 3:
		var by := fy + 1 + row * 3
		var off := 0 if (row + x) % 2 else 4
		var bx := -off
		while bx < TS:
			var x0 := maxi(X, X + bx)
			var x1 := mini(X + TS, X + bx + 7)
			if x1 > x0:
				if rng.randf() < 0.07:
					img.fill_rect(Rect2i(x0, by, x1 - x0, 2), Style.c("night:1"))   # a missing brick
				else:
					var c := Style.c("stone:2").lerp(Style.c("stone:1"), row * 0.28 + rng.randf() * 0.25)
					img.fill_rect(Rect2i(x0, by, x1 - x0, 2), c)
					img.fill_rect(Rect2i(x0, by, x1 - x0, 1), c.lerp(Style.c("stone:3"), 0.45))
			bx += 8
	img.fill_rect(Rect2i(X, fy, TS, 1), Style.c("stone:3"))
	img.fill_rect(Rect2i(X, Y + TS - 1, TS, 1), Style.c("night:0"))
	if rng.randf() < 0.35:
		# moss drips from the cap
		var dx := X + rng.randi_range(1, TS - 3)
		var n := rng.randi_range(2, 7)
		for k in n:
			img.fill_rect(Rect2i(dx + (1 if k > 3 and k % 2 else 0), fy + k, 2 if k < 2 else 1, 1), Style.c("moss:2") if k % 3 else Style.c("moss:3"))


# ------------------------------------------------------------------ surroundings

## Overgrown ruin around the room: dark earth, root lines, tree canopy blobs and broken
## pillar tops, lit from the top-left like everything else.
static func _surroundings(img: Image, gw: int, gh: int, rng: RandomNumberGenerator) -> void:
	var W := img.get_width()
	var H := img.get_height()
	img.fill(Style.c("night:2"))
	var room := Rect2i(MARGIN * TS, Vector2i(gw, gh) * TS)
	# rubble ring hugging the room: extra wall mass so the room edge reads as a ruin
	for k in 40:
		var side := rng.randi_range(0, 3)
		var p := Vector2i.ZERO
		match side:
			0: p = Vector2i(rng.randi_range(room.position.x - 20, room.end.x + 4), room.position.y - rng.randi_range(8, 22))
			1: p = Vector2i(rng.randi_range(room.position.x - 20, room.end.x + 4), room.end.y + rng.randi_range(0, 12))
			2: p = Vector2i(room.position.x - rng.randi_range(12, 26), rng.randi_range(room.position.y - 10, room.end.y))
			3: p = Vector2i(room.end.x + rng.randi_range(0, 12), rng.randi_range(room.position.y - 10, room.end.y))
		var s := Vector2i(rng.randi_range(6, 16), rng.randi_range(5, 10))
		var c := Style.c("stone:1").lerp(Style.c("night:2"), rng.randf() * 0.5)
		img.fill_rect(Rect2i(p, s), c)
		img.fill_rect(Rect2i(p, Vector2i(s.x, 1)), c.lerp(Style.c("stone:2"), 0.6))
		img.fill_rect(Rect2i(p + Vector2i(0, s.y - 1), Vector2i(s.x, 1)), Style.c("night:1"))
	# trunks
	for k in 10:
		var x := rng.randi_range(0, W - 12)
		var y := rng.randi_range(0, H - 40)
		if Rect2i(x - 8, y - 8, 28, 56).intersects(room.grow(10)):
			continue
		img.fill_rect(Rect2i(x, y, 8, 40), Style.c("wood:0"))
		img.fill_rect(Rect2i(x, y, 2, 40), Style.c("wood:1"))
	# canopy: clusters of leaf blobs, three tones, top-left light
	var blobs := 0
	var tries := 0
	while blobs < 320 and tries < 2400:
		tries += 1
		var c := Vector2(rng.randi_range(-10, W + 10), rng.randi_range(-10, H + 10))
		var r := rng.randf_range(10.0, 22.0)
		if Rect2(room).grow(r * 0.6 + 6.0).has_point(c):
			continue
		blobs += 1
		var dark := rng.randf() < 0.5
		PixelArt.disc(img, c, r, Style.c("leaf:0") if dark else Style.c("moss:0"))
		PixelArt.disc(img, c + Vector2(-r * 0.18, -r * 0.2), r * 0.78, Style.c("leaf:1") if dark else Style.c("moss:1"))
		PixelArt.disc(img, c + Vector2(-r * 0.35, -r * 0.38), r * 0.42, Style.c("leaf:2") if dark else Style.c("moss:2"))
	# broken pillar stubs peeking out of the undergrowth
	for k in 6:
		var x := rng.randi_range(8, W - 24)
		var y := rng.randi_range(8, H - 24)
		if Rect2i(x - 6, y - 6, 28, 30).intersects(room.grow(8)):
			continue
		img.fill_rect(Rect2i(x, y, 14, 16), Style.c("stone:1"))
		img.fill_rect(Rect2i(x, y, 14, 3), Style.c("stone:2"))
		img.fill_rect(Rect2i(x, y, 14, 1), Style.c("stone:3"))
		img.fill_rect(Rect2i(x + 2, y + 5, 1, 9), Style.c("stone:0"))
		img.fill_rect(Rect2i(x, y + 16, 14, 2), Style.c("night:1"))
	# a dark band right at the room's outer edge so the wall caps separate from the canopy
	for k in 3:
		var g := room.grow(1 + k)
		var c := Color(Style.RAMPS["night"][1])
		c.a = 0.55 - k * 0.15
		_blend(img, Rect2i(g.position.x, g.position.y, g.size.x, 1), c)
		_blend(img, Rect2i(g.position.x, g.end.y - 1, g.size.x, 1), c)
		_blend(img, Rect2i(g.position.x, g.position.y, 1, g.size.y), c)
		_blend(img, Rect2i(g.end.x - 1, g.position.y, 1, g.size.y), c)


static func _blend(img: Image, r: Rect2i, c: Color) -> void:
	var rr := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for j in range(rr.position.y, rr.end.y):
		for i in range(rr.position.x, rr.end.x):
			img.set_pixel(i, j, img.get_pixel(i, j).blend(c))
