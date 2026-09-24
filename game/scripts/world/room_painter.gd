class_name RoomPainter
extends RefCounted
## Bakes a room grid into one floor image: flagstones, hazard plates, ambient occlusion,
## walls with a brick front face, and a few floor props. Deterministic from the seed.

const TS := 16
const FACE := 9

const WORLD1 := {
	"floor": ["#3a4a2e", "#415236", "#34432a"],
	"wall": ["#2a3522", "#55663f", "#7d9656"],
	"acc": "#8fd16a",
}


static func paint(grid: PackedByteArray, gw: int, gh: int, seed_value: int, pal: Dictionary = WORLD1) -> Image:
	var img := Image.create_empty(gw * TS, gh * TS + 8, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var at := func(x: int, y: int) -> int:
		return 1 if x < 0 or y < 0 or x >= gw or y >= gh else grid[y * gw + x]
	var wallish := func(t: int) -> bool: return t == 1 or t == 3
	var fl: Array = pal["floor"]
	var wl: Array = pal["wall"]
	# floors
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				continue
			_stones(img, x * TS, y * TS, fl, rng)
			if at.call(x, y) == 2:
				_spike_plate(img, x * TS, y * TS)
	# ambient occlusion from walls
	for y in gh:
		for x in gw:
			if wallish.call(at.call(x, y)):
				continue
			var X := x * TS
			var Y := y * TS
			if wallish.call(at.call(x, y - 1)):
				for k in 6:
					_blend(img, Rect2i(X, Y + k, TS, 1), Color(0, 0, 0, 0.42 - k * 0.07))
			if wallish.call(at.call(x - 1, y)):
				for k in 4:
					_blend(img, Rect2i(X + k, Y, 1, TS), Color(0, 0, 0, 0.3 - k * 0.07))
			if wallish.call(at.call(x + 1, y)):
				for k in 4:
					_blend(img, Rect2i(X + TS - 1 - k, Y, 1, TS), Color(0, 0, 0, 0.3 - k * 0.07))
	# props
	for y in range(2, gh - 1):
		for x in range(1, gw - 1):
			if at.call(x, y) == 0 and rng.randf() < 0.08:
				_tuft(img, x * TS + 2 + rng.randi_range(0, 10), y * TS + 6 + rng.randi_range(0, 7), rng)
	# walls: a stone cap on top, and a brick face wherever floor lies below
	for y in gh:
		for x in gw:
			var t: int = at.call(x, y)
			if not wallish.call(t):
				continue
			var X := x * TS
			var Y := y * TS
			var open: bool = not wallish.call(at.call(x, y + 1))
			var top_h := TS - FACE if open else TS
			var cap := Color(wl[1]).darkened(0.18 + rng.randf() * 0.06)
			img.fill_rect(Rect2i(X, Y, TS, top_h), cap)
			# cap stones: two slabs with a seam, lit on the top edge
			var seam := 8 if (x + y) % 2 else 5
			img.fill_rect(Rect2i(X + seam, Y, 1, top_h), cap.darkened(0.3))
			img.fill_rect(Rect2i(X, Y, TS, 1), cap.lightened(0.12))
			# the cap's rim where it meets floor or the void
			if not wallish.call(at.call(x, y - 1)):
				img.fill_rect(Rect2i(X, Y, TS, 1), Color(wl[2]))
			if not wallish.call(at.call(x - 1, y)):
				img.fill_rect(Rect2i(X, Y, 1, top_h), Color(wl[2]).darkened(0.2))
			if not wallish.call(at.call(x + 1, y)):
				img.fill_rect(Rect2i(X + TS - 1, Y, 1, top_h), Color(wl[0]))
			if not open:
				continue
			var fy := Y + TS - FACE
			img.fill_rect(Rect2i(X, fy, TS, FACE), Color(wl[0]))
			for row in 3:
				var by := fy + 1 + row * 3
				var off := 0 if (row + x) % 2 else 4
				var bx := -off
				while bx < TS:
					var x0 := maxi(X, X + bx)
					var x1 := mini(X + TS, X + bx + 7)
					if x1 > x0:
						var c := Color(wl[1]).darkened(0.25 + row * 0.08 + rng.randf() * 0.08)
						img.fill_rect(Rect2i(x0, by, x1 - x0, 2), c)
						img.fill_rect(Rect2i(x0, by, x1 - x0, 1), c.lightened(0.14))
					bx += 8
			img.fill_rect(Rect2i(X, fy, TS, 1), Color(wl[2]))
			img.fill_rect(Rect2i(X, Y + TS - 1, TS, 1), Color(wl[0]).darkened(0.5))
			if rng.randf() < 0.25:
				_vine(img, X + 2 + rng.randi_range(0, 11), fy, rng)
	return img


static func _blend(img: Image, r: Rect2i, c: Color) -> void:
	for j in range(r.position.y, r.end.y):
		for i in range(r.position.x, r.end.x):
			if i >= 0 and j >= 0 and i < img.get_width() and j < img.get_height():
				img.set_pixel(i, j, img.get_pixel(i, j).blend(c))


static func _stones(img: Image, X: int, Y: int, fl: Array, rng: RandomNumberGenerator) -> void:
	img.fill_rect(Rect2i(X, Y, TS, TS), Color(fl[2]).darkened(0.35))
	var L := rng.randf()
	var rects: Array
	if L < 0.3: rects = [[0, 0, 16, 16]]
	elif L < 0.55: rects = [[0, 0, 16, 8], [0, 8, 16, 8]]
	elif L < 0.8: rects = [[0, 0, 8, 16], [8, 0, 8, 16]]
	else: rects = [[0, 0, 8, 8], [8, 0, 8, 8], [0, 8, 8, 8], [8, 8, 8, 8]]
	for r in rects:
		var c := Color(fl[rng.randi_range(0, 2)]).darkened(rng.randf() * 0.08)
		img.fill_rect(Rect2i(X + r[0] + 1, Y + r[1] + 1, r[2] - 1, r[3] - 1), c)
		img.fill_rect(Rect2i(X + r[0] + 1, Y + r[1] + 1, r[2] - 1, 1), c.lightened(0.1))
		img.fill_rect(Rect2i(X + r[0] + 1, Y + r[1] + r[3] - 1, r[2] - 1, 1), c.darkened(0.18))
	if rng.randf() < 0.35:
		for k in 6:
			img.set_pixel(X + rng.randi_range(0, 15), Y + (15 if rng.randf() < 0.5 else 0), Color("#5a8a32"))


static func _spike_plate(img: Image, X: int, Y: int) -> void:
	img.fill_rect(Rect2i(X + 1, Y + 1, TS - 2, TS - 2), Color("#16120f"))
	img.fill_rect(Rect2i(X + 1, Y + 1, TS - 2, 1), Color("#3a3230"))
	for k in 4:
		var x := X + 3 + (k % 2) * 7
		var y := Y + 3 + (k / 2) * 7
		img.fill_rect(Rect2i(x, y, 3, 3), Color("#2a2420"))


static func _tuft(img: Image, x: int, y: int, rng: RandomNumberGenerator) -> void:
	for k in 4:
		var h := 2 + rng.randi_range(0, 2)
		img.fill_rect(Rect2i(x + k, y - h, 1, h), Color("#7ab04a") if k % 2 else Color("#4f7a2e"))


static func _vine(img: Image, x: int, fy: int, rng: RandomNumberGenerator) -> void:
	var n := 5 + rng.randi_range(0, 7)
	for k in n:
		img.set_pixel(x + (1 if k % 3 == 2 else 0), fy + k, Color("#3f6a26") if k % 2 else Color("#5a8a32"))
