class_name Backdrop
extends RefCounted
## The title screen's grove, in parallax layers (0.4, decisions/0007). Every layer is W px
## wide and tiles horizontally (its shapes use whole periods of W), so the title can scroll
## them forever. Silhouettes only: cool and dark far away, a touch of moss up close.

const W := 640
const H := 300


static func _periodic(x: float, terms: Array) -> float:
	var v := 0.0
	for t in terms:
		v += float(t[0]) * sin(TAU * x * float(t[1]) / W + float(t[2]))
	return v


## far: a ridge of ruins against the sky (towers and broken arches).
static func far() -> Texture2D:
	return PixelArt.cached("bd_far", func() -> Image:
		var img := PixelArt.blank(W, H)
		var col := Style.c("night:3")
		for x in W:
			var top := int(170.0 + _periodic(x, [[14, 2, 0.4], [7, 5, 1.3], [3, 11, 2.0]]))
			img.fill_rect(Rect2i(x, top, 1, H - top), col)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for k in 7:
			var x := rng.randi_range(0, W - 16)
			var h := rng.randi_range(26, 60)
			var w := rng.randi_range(8, 14)
			var base := int(172.0 + _periodic(x, [[14, 2, 0.4], [7, 5, 1.3], [3, 11, 2.0]]))
			img.fill_rect(Rect2i(x, base - h, w, h), col)
			# crenellations and a lit window
			for c in range(0, w, 4):
				img.fill_rect(Rect2i(x + c, base - h - 3, 2, 3), col)
			if rng.randf() < 0.6:
				img.fill_rect(Rect2i(x + w / 2 - 1, base - h + 8, 2, 3), Style.c("gold:2").darkened(0.35))
		return img)


## mid: the tree line, a band of round canopies with trunks.
static func mid() -> Texture2D:
	return PixelArt.cached("bd_mid", func() -> Image:
		var img := PixelArt.blank(W, H)
		var rng := RandomNumberGenerator.new()
		rng.seed = 23
		var dark := Style.c("violet:0").lerp(Style.c("night:2"), 0.3)
		img.fill_rect(Rect2i(0, 222, W, H - 222), dark)
		for k in 34:
			var x := rng.randf_range(0.0, W)
			var y := rng.randf_range(196.0, 220.0)
			var r := rng.randf_range(12.0, 24.0)
			for dx in [-W, 0, W]:
				PixelArt.disc(img, Vector2(x + dx, y), r, dark)
				PixelArt.disc(img, Vector2(x + dx - r * 0.3, y - r * 0.35), r * 0.45, dark.lerp(Style.c("violet:1"), 0.35))
		for k in 9:
			var x := rng.randi_range(0, W - 5)
			img.fill_rect(Rect2i(x, 205, 4, 30), dark.darkened(0.2))
		return img)


## near: mossy undergrowth and a broken column at the bottom edge.
static func near() -> Texture2D:
	return PixelArt.cached("bd_near", func() -> Image:
		var img := PixelArt.blank(W, H)
		var rng := RandomNumberGenerator.new()
		rng.seed = 37
		var base := Style.c("leaf:0")
		for x in W:
			var top := int(262.0 + _periodic(x, [[5, 3, 0.2], [3, 8, 1.1], [2, 17, 0.5]]))
			img.fill_rect(Rect2i(x, top, 1, H - top), base)
			if x % 3 == 0 and rng.randf() < 0.5:
				var h := rng.randi_range(2, 6)
				img.fill_rect(Rect2i(x, top - h, 1, h), Style.c("moss:1"))
		for k in 22:
			var x := rng.randf_range(0.0, W)
			var r := rng.randf_range(6.0, 12.0)
			for dx in [-W, 0, W]:
				PixelArt.disc(img, Vector2(x + dx, 266.0), r, base)
				PixelArt.disc(img, Vector2(x + dx - r * 0.3, 263.0), r * 0.5, Style.c("moss:1"))
		# a broken column
		img.fill_rect(Rect2i(92, 222, 16, 50), Style.c("stone:1"))
		img.fill_rect(Rect2i(92, 222, 3, 50), Style.c("stone:2"))
		img.fill_rect(Rect2i(88, 218, 24, 5), Style.c("stone:2"))
		img.fill_rect(Rect2i(88, 218, 24, 1), Style.c("stone:3"))
		for k in 5:
			img.fill_rect(Rect2i(92 + rng.randi_range(0, 13), 224 + k * 9, 3, 2), Style.c("moss:2"))
		return img)
