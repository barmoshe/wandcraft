extends SceneTree
## Renders the app icon set from the game's own pixel art (the hipster hero, on the purple
## Glitch background), so the icon always matches the game. Deterministic.
##   game/assets/icon/icon_1024.png      App Store / iOS (opaque, no alpha)
##   game/assets/icon/android_192.png    legacy Android launcher icon
##   game/assets/icon/android_fg_432.png adaptive icon foreground (transparent, safe zone)
##   game/assets/icon/android_bg_432.png adaptive icon background
##   game/assets/icon/splash.png         boot splash (logo on transparent)
## Run: tools/icon.sh

const OUT := "res://assets/icon/"
const BG_TOP := Color("#2a1650")
const BG_BOTTOM := Color("#0c0720")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var bust := _bust()
	var body := Hero.frame(0, 0, false)
	# iOS: opaque square, a head-and-shoulders portrait rising from the bottom edge
	var icon := _background(1024)
	_sparkles(icon, 1024, 77)
	_stamp(icon, bust, Vector2i(512, 1024 - bust.get_height() * 32 / 2 + 8), 32)
	icon.convert(Image.FORMAT_RGB8)
	icon.save_png(OUT + "icon_1024.png")
	# Android adaptive: the foreground keeps its art inside the central 66% safe zone
	var fg := Image.create_empty(432, 432, false, Image.FORMAT_RGBA8)
	_stamp(fg, bust, Vector2i(216, 224), 10)
	fg.save_png(OUT + "android_fg_432.png")
	var bg := _background(432)
	_sparkles(bg, 432, 31)
	bg.convert(Image.FORMAT_RGB8)
	bg.save_png(OUT + "android_bg_432.png")
	var legacy := _background(192)
	_stamp(legacy, bust, Vector2i(96, 192 - bust.get_height() * 6 / 2 + 2), 6)
	legacy.save_png(OUT + "android_192.png")
	var splash := Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
	_stamp(splash, body, Vector2i(128, 128), 5)
	splash.save_png(OUT + "splash.png")
	print("gen_icon: wrote the icon set to %s" % OUT)
	quit()


## The hero from the hat to the chest (quiff, shades, beard, collar and tie).
func _bust() -> Image:
	var full := Hero.frame(0, 0, false)
	return full.get_region(Rect2i(0, 0, full.get_width(), 26))


func _background(size: int) -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		var k := float(y) / size
		img.fill_rect(Rect2i(0, y, size, 1), BG_TOP.lerp(BG_BOTTOM, k))
	# a soft vignette of light behind the wizard
	var c := Vector2(size / 2.0, size * 0.55)
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c) / (size * 0.45)
			if d < 1.0:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, p.lerp(Color("#5a3aa8"), (1.0 - d) * (1.0 - d) * 0.55))
	return img


## Nearest-neighbour stamp of a sprite, its bottom-centre at `at`, scaled by `k`.
func _stamp(dst: Image, src: Image, at: Vector2i, k: int) -> void:
	var w := src.get_width()
	var h := src.get_height()
	var x0 := at.x - w * k / 2
	var y0 := at.y - h * k / 2
	for j in h:
		for i in w:
			var c := src.get_pixel(i, j)
			if c.a > 0.5:
				dst.fill_rect(Rect2i(x0 + i * k, y0 + j * k, k, k), c)


## The glowing wand tip from the casting frame (a pixel star next to the raised hand).
func _glow_tip(dst: Image, at: Vector2i, k: int) -> void:
	var src_w := 18
	var src_h := 24
	var tip := Vector2i(at.x - src_w * k / 2 + 14 * k, at.y - src_h * k / 2 + 10 * k)
	var star := ["...#...", "...#...", ".#####.", "#######", ".#####.", "...#...", "...#..."]
	for j in 7:
		for i in 7:
			if star[j][i] == "#":
				var c := Color("#e8fbff") if abs(i - 3) + abs(j - 3) <= 1 else Color("#8fd8ff")
				dst.fill_rect(Rect2i(tip.x + (i - 3) * k / 2, tip.y + (j - 3) * k / 2, k / 2, k / 2), c)


func _sparkles(img: Image, size: int, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var px := maxi(2, size / 128)
	for n in 26:
		var p := Vector2i(rng.randi_range(0, size - px), rng.randi_range(0, int(size * 0.8)))
		var c: Color = [Color("#5ce1ff"), Color("#c46bff"), Color("#ffe066")][n % 3]
		img.fill_rect(Rect2i(p, Vector2i(px, px)), c)
