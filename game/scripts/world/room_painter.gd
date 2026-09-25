class_name RoomPainter
extends RefCounted
## Bakes a room into one image (0.4, decisions/0007; D1 art pass): the Ruined Grove.
##   - floor: QUIET by design (D1, research/design-research.md §3): a narrow 3-value band,
##     large calm patches, faint flagstone joints on a 2-tile grid and small stamps (pebbles,
##     cracks) in clusters with empty floor between. Actors carry the contrast, not the floor.
##   - walls: moss-topped caps and a brick face with broken bricks and moss drips
##   - surroundings: MARGIN tiles of overgrown ruin around the room (canopy, trunks, broken
##     pillars), so wide phone screens show the grove instead of black bars
## The image's (0,0) is MARGIN tiles up-left of the room's (0,0): World offsets the sprite.
## Deterministic from the seed. Performance: big areas use fill_rect, noise is sampled on a
## 2px grid; a room bakes in well under 100 ms on desktop.

const TS := 16
const FACE := 9
const MARGIN := Vector2i(14, 9)


## Design v3: each area paints as its own place (it was one image, violet-tinted for the
## Grove). Colours are Style ramp keys.
##   0 the Mossy Root Cellar: cool slate, moss creeping from the walls, roots, warm puddles
##   1 the Corrupted Grove: plum soil, violet stone, glitch crystals and glowing veins
##     (RoomPainter.veins; World pulses them), dead violet canopy and glowing mushrooms
const THEMES := [
	{"f": ["slate:1", "slate:2", "slate:3"], "cap": ["stone:3", "stone:2", "stone:4"], "face": ["night:3", "stone:1", "stone:0", "stone:2"],
		"grow": ["moss:1", "moss:2", "moss:3"], "floor_mix": "slate:2", "canopy": [["leaf:0", "leaf:1", "leaf:2", "leaf:3"], ["moss:0", "moss:1", "moss:2", "moss:2"]],
		"trunk": ["wood:0", "wood:1"], "ground": "night:2", "roots": true, "veins": false},
	{"f": ["night:2", "night:3", "violet:1"], "cap": ["violet:2", "violet:1", "violet:3"], "face": ["night:2", "violet:1", "night:1", "violet:2"],
		"grow": ["violet:1", "glitch:1", "glitch:2"], "floor_mix": "night:3", "canopy": [["night:2", "violet:1", "violet:2", "violet:3"], ["cyan:0", "cyan:1", "cyan:1", "cyan:2"]],
		"trunk": ["night:1", "violet:1"], "ground": "night:1", "roots": false, "veins": true},
]


static func size_px(gw: int, gh: int) -> Vector2i:
	return Vector2i((gw + MARGIN.x * 2) * TS, (gh + MARGIN.y * 2) * TS)


## biome 0: the Mossy Root Cellar; 1: the Corrupted Grove (THEMES).
static func paint(grid: PackedByteArray, gw: int, gh: int, seed_value: int, biome := 0) -> Image:
	var th: Dictionary = THEMES[clampi(biome, 0, THEMES.size() - 1)]
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
	var wallish := func(t: int) -> bool: return t == 1 or t == 3 or t == 7
	_surroundings(img, gw, gh, rng, th)
	# floors
	_floor(img, gw, gh, at, wallish, rng, seed_value, th)
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
					var g0 := Style.c(th["grow"][0])
					var fm := Style.c(th["floor_mix"])
					if n > 0.76:
						var c := g0.lerp(fm, 0.35) if n < 0.86 else g0
						img.fill_rect(Rect2i(O.x + px, O.y + py, 2, 2), c)
					elif n > 0.72 and (i + j) % 4 == 0:
						img.fill_rect(Rect2i(O.x + px, O.y + py, 1, 1), g0.lerp(fm, 0.5))
	# details: puddles, roots, flowers, tufts; then hazard plates on top
	var puddles := 0
	for y in range(2, gh - 1):
		for x in range(1, gw - 1):
			if at.call(x, y) != 0:
				continue
			var X := O.x + x * TS
			var Y := O.y + y * TS
			var r := rng.randf()
			if th["veins"]:
				# the Grove: glowing mushrooms and crystal shards instead of tufts and flowers
				if r < 0.03:
					_mushrooms(img, X + rng.randi_range(2, 12), Y + rng.randi_range(4, 13), rng)
				elif r < 0.05:
					_shard(img, X + rng.randi_range(2, 12), Y + rng.randi_range(5, 13), rng)
				continue
			if r < 0.015 and puddles < 2:
				puddles += 1
				_puddle(img, X + 2, Y + 4, rng)
			elif r < 0.045:
				_tuft(img, X + 2 + rng.randi_range(0, 10), Y + 6 + rng.randi_range(0, 7), rng)
			elif r < 0.06:
				_flowers(img, X + rng.randi_range(2, 12), Y + rng.randi_range(3, 12), rng)
	if th["roots"]:
		_roots(img, gw, gh, at, wallish, rng)
	if th["veins"]:
		for v in veins(grid, gw, gh, seed_value):
			for q in v:
				var pp := Vector2i(q) + O
				img.set_pixel(pp.x, pp.y, Style.c("glitch:1"))
	for y in gh:
		for x in gw:
			if at.call(x, y) == 2:
				_spike_plate(img, O.x + x * TS, O.y + y * TS)
			elif at.call(x, y) == 5:
				_pit(img, O.x + x * TS, O.y + y * TS, at.call(x, y - 1) == 5)
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
				_wall(img, O.x + x * TS, O.y + y * TS, x, y, at, wallish, rng, th)
			if at.call(x, y) == 7:
				_cracks(img, O.x + x * TS, O.y + y * TS)
	if th["veins"]:
		# glitch pixels: short bright dashes in the floor, the corruption showing through
		for k in gw * gh / 8:
			var gx := rng.randi_range(1, gw - 2)
			var gy := rng.randi_range(1, gh - 2)
			if at.call(gx, gy) == 0:
				img.fill_rect(Rect2i(O.x + gx * TS + rng.randi_range(0, 13), O.y + gy * TS + rng.randi_range(0, 13), rng.randi_range(2, 3), 1), Style.c(["glitch:2", "cyan:2"][rng.randi_range(0, 1)]))
	return img


## The Grove's corruption veins: branching lines from the walls into the floor, in room
## pixels. Deterministic from the seed, so World draws the same lines as a pulsing glow.
static func veins(grid: PackedByteArray, gw: int, gh: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 5
	var out: Array = []
	var floor_at := func(p: Vector2) -> bool:
		var x := int(p.x) / TS
		var y := int(p.y) / TS
		return x >= 0 and y >= 0 and x < gw and y < gh and grid[y * gw + x] == 0
	for k in maxi(4, gw * gh / 40):
		# start on a floor tile beside a wall, grow away from it
		var p := Vector2(rng.randi_range(1, gw - 2) * TS + 8, rng.randi_range(1, gh - 2) * TS + 8)
		if not floor_at.call(p):
			continue
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var line := PackedVector2Array()
		for step in rng.randi_range(18, 46):
			line.append(p.round())
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			var np := p + dir
			if not floor_at.call(np):
				break
			p = np
			if step > 8 and rng.randf() < 0.05:
				# a short branch
				var b := p
				var bd := dir.rotated(rng.randf_range(0.6, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0))
				for m in rng.randi_range(4, 10):
					b += bd
					if not floor_at.call(b):
						break
					line.append(b.round())
		out.append(line)
	return out


## Roots creeping out from the walls into the Cellar floor: two-tone wood lines, thinning.
static func _roots(img: Image, gw: int, gh: int, at: Callable, wallish: Callable, rng: RandomNumberGenerator) -> void:
	var O := MARGIN * TS
	for k in maxi(8, gw * gh / 14):
		var x := rng.randi_range(1, gw - 2)
		var y := rng.randi_range(1, gh - 2)
		if wallish.call(at.call(x, y)) or not wallish.call(at.call(x, y - 1)):
			continue
		var p := Vector2(x * TS + rng.randi_range(2, 13), y * TS)
		var dir := Vector2(rng.randf_range(-0.4, 0.4), 1.0).normalized()
		var n := rng.randi_range(10, 26)
		for s2 in n:
			var ip := Vector2i(p.round()) + O
			var thick := s2 < n / 2
			img.set_pixel(ip.x, ip.y, Style.c("wood:2"))
			if thick:
				img.set_pixel(ip.x + 1, ip.y, Style.c("wood:1"))
				img.set_pixel(ip.x - 1, ip.y, Style.c("wood:3") if s2 % 4 == 0 else Style.c("wood:1"))
			dir = dir.rotated(rng.randf_range(-0.35, 0.35))
			p += dir
			var t := Vector2i(int(p.x) / TS, int(p.y) / TS)
			if wallish.call(at.call(t.x, t.y)):
				break


## The Grove: a cluster of glowing mushrooms (a cap over a stalk, the cap's top lit).
static func _mushrooms(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var ramp: String = ["cyan", "glitch"][rng.randi_range(0, 1)]
	for k in rng.randi_range(1, 3):
		var p := Vector2i(x + rng.randi_range(-4, 4), y + rng.randi_range(-2, 2))
		if p.x < 2 or p.y < 3 or p.x > img.get_width() - 3 or p.y > img.get_height() - 2:
			continue
		img.set_pixel(p.x, p.y, Style.c("bone:2"))
		img.set_pixel(p.x, p.y - 1, Style.c("bone:2"))
		img.fill_rect(Rect2i(p.x - 1, p.y - 2, 3, 1), Style.c(ramp + ":2"))
		img.set_pixel(p.x, p.y - 3, Style.c(ramp + ":4"))


## The Grove: a small crystal shard sticking out of the soil.
static func _shard(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	var h := rng.randi_range(3, 5)
	for k in h:
		img.set_pixel(x, y - k, Style.c("violet:3") if k < h - 1 else Style.c("violet:4"))
		if k < h - 2:
			img.set_pixel(x + 1, y - k, Style.c("violet:2"))
	img.set_pixel(x - 1, y, Style.c("night:1"))


## A pit: a dark shaft with a lit lip on its top edge (only where the tile above is floor).
static func _pit(img: Image, X: int, Y: int, below_pit: bool) -> void:
	img.fill_rect(Rect2i(X, Y, TS, TS), Style.c("night:0"))
	if not below_pit:
		img.fill_rect(Rect2i(X, Y, TS, 2), Style.c("stone:2"))
		img.fill_rect(Rect2i(X, Y + 2, TS, 3), Style.c("night:1"))


## Hairline cracks across a wall that a blast can open (a secret behind it).
static func _cracks(img: Image, X: int, Y: int) -> void:
	var pts := [Vector2i(3, 2), Vector2i(6, 5), Vector2i(5, 8), Vector2i(9, 10), Vector2i(8, 13), Vector2i(12, 15)]
	for i in pts.size() - 1:
		var a: Vector2i = pts[i]
		var b: Vector2i = pts[i + 1]
		for k in 4:
			var q := Vector2i(a) + (b - a) * k / 4
			img.set_pixel(X + q.x, Y + q.y, Style.c("night:0"))
			img.set_pixel(X + q.x + 1, Y + q.y, Style.c("stone:4"))


# ------------------------------------------------------------------ floor

## The floor as one surface: base value, calm low-frequency patches (dithered only where
## two values meet), faint joints every 2 tiles, and clustered stamps.
const BAYER4 := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func _floor(img: Image, gw: int, gh: int, at: Callable, wallish: Callable, rng: RandomNumberGenerator, seed_value: int, th: Dictionary = THEMES[0]) -> void:
	var O := MARGIN * TS
	var lo := Style.c(th["f"][0])
	var mid := Style.c(th["f"][1])
	var hi := Style.c(th["f"][2])
	var f0 := mid.lerp(lo, 0.3)
	var f1 := mid
	var f2 := mid.lerp(hi, 0.2)
	var patches := FastNoiseLite.new()
	patches.seed = seed_value + 7
	patches.frequency = 0.018
	patches.fractal_octaves = 2
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				continue
			var X := O.x + x * TS
			var Y := O.y + y * TS
			for j in TS:
				for i in TS:
					var n := patches.get_noise_2d(x * TS + i, y * TS + j)
					var dth := (float(BAYER4[(j % 4) * 4 + (i % 4)]) / 16.0 - 0.5) * 0.08
					var c := f1
					if n + dth < -0.22:
						c = f0
					elif n + dth > 0.26:
						c = f2
					img.set_pixel(X + i, Y + j, c)
			# faint flagstone joints on a 2-tile grid, broken up
			if x % 2 == 0 and rng.randf() < 0.55:
				var len := rng.randi_range(6, 16)
				img.fill_rect(Rect2i(X, Y + rng.randi_range(0, TS - len), 1, len), f0)
			if y % 2 == 0 and rng.randf() < 0.55:
				var len2 := rng.randi_range(6, 16)
				img.fill_rect(Rect2i(X + rng.randi_range(0, TS - len2), Y, len2, 1), f0)
	# clustered stamps: pebbles and cracks near a few centers, empty floor between
	var clusters := maxi(3, gw * gh / 22)
	for k in clusters:
		var cx := rng.randi_range(1, gw - 2)
		var cy := rng.randi_range(1, gh - 2)
		if wallish.call(at.call(cx, cy)):
			continue
		var cpx := O.x + cx * TS + TS / 2
		var cpy := O.y + cy * TS + TS / 2
		for m in rng.randi_range(2, 5):
			var p := Vector2i(cpx + rng.randi_range(-12, 12), cpy + rng.randi_range(-10, 10))
			var tx := (p.x - O.x) / TS
			var ty := (p.y - O.y) / TS
			if wallish.call(at.call(tx, ty)):
				continue
			if rng.randf() < 0.6:
				# a pebble: lit top pixel over a dark one
				img.set_pixel(p.x, p.y, hi)
				img.set_pixel(p.x + 1, p.y, hi.lerp(f2, 0.5))
				img.set_pixel(p.x, p.y + 1, lo)
			else:
				# a hairline crack
				var q := p
				for s2 in rng.randi_range(3, 6):
					img.set_pixel(q.x, q.y, lo)
					q += Vector2i(1 if rng.randf() < 0.5 else 0, 1)


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
		img.fill_rect(Rect2i(x + k, y - h, 1, h), Style.c("moss:2") if k % 2 else Style.c("moss:1"))


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

static func _wall(img: Image, X: int, Y: int, x: int, y: int, at: Callable, wallish: Callable, rng: RandomNumberGenerator, th: Dictionary = THEMES[0]) -> void:
	var open: bool = not wallish.call(at.call(x, y + 1))
	var top_h := TS - FACE if open else TS
	# caps are LIGHTER than the floor and faces darker, so the room edge reads at a glance (D1)
	var cap := Style.c(th["cap"][0]).lerp(Style.c(th["cap"][1]), 0.35)
	img.fill_rect(Rect2i(X, Y, TS, top_h), cap)
	# cap slabs with a seam and a lit top edge
	var seam := 8 if (x + y) % 2 else 5
	img.fill_rect(Rect2i(X + seam, Y, 1, top_h), Style.c(th["cap"][1]))
	img.fill_rect(Rect2i(X, Y, TS, 1), cap.lerp(Style.c(th["cap"][2]), 0.45))
	# growth on the cap (moss in the Cellar, glitch crystals in the Grove), heavier facing the room
	if not wallish.call(at.call(x, y - 1)) or rng.randf() < 0.35:
		for k in rng.randi_range(3, 8):
			var mx := X + rng.randi_range(0, TS - 3)
			img.fill_rect(Rect2i(mx, Y, rng.randi_range(2, 4), 2), Style.c(th["grow"][1]))
			img.set_pixel(mx, Y, Style.c(th["grow"][2]))
	if not wallish.call(at.call(x - 1, y)):
		img.fill_rect(Rect2i(X, Y, 1, top_h), cap.lerp(Style.c(th["cap"][2]), 0.25))
	if not wallish.call(at.call(x + 1, y)):
		img.fill_rect(Rect2i(X + TS - 1, Y, 1, top_h), Style.c("night:1"))
	if not open:
		return
	# the brick face
	var fy := Y + TS - FACE
	img.fill_rect(Rect2i(X, fy, TS, FACE), Style.c(th["face"][0]))
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
					var c := Style.c(th["face"][1]).lerp(Style.c(th["face"][2]), row * 0.3 + rng.randf() * 0.2)
					img.fill_rect(Rect2i(x0, by, x1 - x0, 2), c)
					img.fill_rect(Rect2i(x0, by, x1 - x0, 1), c.lerp(Style.c(th["face"][3]), 0.5))
			bx += 8
	img.fill_rect(Rect2i(X, fy, TS, 1), Style.c(th["face"][3]))
	img.fill_rect(Rect2i(X, Y + TS - 1, TS, 1), Style.c("night:0"))
	if rng.randf() < 0.35:
		# growth drips from the cap
		var dx := X + rng.randi_range(1, TS - 3)
		var n := rng.randi_range(2, 7)
		for k in n:
			img.fill_rect(Rect2i(dx + (1 if k > 3 and k % 2 else 0), fy + k, 2 if k < 2 else 1, 1), Style.c(th["grow"][1]) if k % 3 else Style.c(th["grow"][2]))


# ------------------------------------------------------------------ surroundings

## Overgrown ruin around the room: dark earth, root lines, tree canopy blobs and broken
## pillar tops, lit from the top-left like everything else.
static func _surroundings(img: Image, gw: int, gh: int, rng: RandomNumberGenerator, th: Dictionary = THEMES[0]) -> void:
	var W := img.get_width()
	var H := img.get_height()
	img.fill(Style.c(th["ground"]))
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
		img.fill_rect(Rect2i(x, y, 8, 40), Style.c(th["trunk"][0]))
		img.fill_rect(Rect2i(x, y, 2, 40), Style.c(th["trunk"][1]))
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
		var tone: Array = th["canopy"][0 if dark else 1]
		var base := Style.c(tone[0])
		var mid := Style.c(tone[1])
		var hi := Style.c(tone[2])
		PixelArt.disc(img, c, r, base)
		# leaf clusters instead of concentric discs: lighter toward the top-left light
		for m in int(r * 1.6):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * r * 0.85
			var lp := c + Vector2.from_angle(a) * d
			var lit := (lp - c).dot(Vector2(-0.7, -0.7)) / r
			if lit < -0.35:
				continue
			var col := hi if lit > 0.35 else mid
			var ip := Vector2i(lp.round())
			img.fill_rect(Rect2i(ip.x, ip.y, 3, 2).intersection(Rect2i(0, 0, W, H)), col)
			if lit > 0.55 and ip.x >= 0 and ip.y >= 0 and ip.x < W and ip.y < H:
				img.set_pixel(ip.x, ip.y, hi.lerp(Style.c(tone[3]), 0.4))
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
