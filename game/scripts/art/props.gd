class_name Props
extends RefCounted
## Room set pieces for 0.4 (decisions/0007): door archways, the reward altar, the spring
## fountain, the merchant's stall, the forge anvil and torch flames. Style ramps only;
## everything is cached by its parameters.


## A stone archway over a 2-tile door. 40x24; its bottom row sits on the door tile's bottom
## edge (draw at door x - 4, y - 8). Closed: iron bars over the dark. Open: the doorway
## glows in the door's color.
static func door(color: Color, open: bool) -> Texture2D:
	return PixelArt.cached("door_%s_%d" % [color.to_html(), int(open)], func() -> Image:
		var img := PixelArt.blank(40, 24)
		var c := Vector2(20.0, 17.0)
		for j in 24:
			for i in 40:
				var p := Vector2(i + 0.5, j + 0.5)
				var d := p.distance_to(c)
				var col := Color(0, 0, 0, 0)
				var inside := (d < 15.0 and j < 17) or (j >= 17 and i >= 4 and i < 36)
				if inside:
					if open:
						var k := clampf(1.0 - (p.y - 2.0) / 22.0, 0.0, 1.0)
						col = color.darkened(0.7).lerp(color.lightened(0.1), k * 0.55)
						if (i + j) % 7 == 0 and j < 20:
							col = col.lightened(0.25)
					else:
						col = Style.c("night:0")
						if i >= 6 and i < 34 and (i - 6) % 5 == 0:
							col = Style.c("steel:2") if i % 2 else Style.c("steel:1")
						if j == 9 or j == 18:
							if i >= 6 and i < 34:
								col = Style.c("steel:1")
				elif d >= 15.0 and d < 19.0 and j < 17:
					# voussoirs: stone blocks around the arch, lit from the top-left
					var ang := atan2(p.y - c.y, p.x - c.x)
					var seg := int(floor((ang + PI) / (PI / 7.0)))
					var edge := fmod((ang + PI), PI / 7.0) < 0.07
					col = Style.c("stone:2") if seg % 2 else Style.c("stone:3").lerp(Style.c("stone:2"), 0.4)
					if d < 16.0:
						col = Style.c("stone:1")
					if edge:
						col = Style.c("stone:0")
					if absf(p.x - 20.0) < 3.0 and j < 4:
						col = Style.c("gold:3") if j < 2 else Style.c("gold:2")
				elif j >= 12 and (i < 4 or i >= 36):
					# pillars with coursed blocks
					col = Style.c("stone:2")
					if i == 0 or i == 36:
						col = Style.c("stone:3")
					if i == 3 or i == 39:
						col = Style.c("stone:1")
					if (j - 12) % 4 == 0:
						col = Style.c("stone:0")
				img.set_pixel(i, j, col)
		return PixelArt.outlined(img))


## The reward altar: a short plinth the orb floats over. 18x12, draw centered on the orb's
## floor point with its bottom at +6.
static func altar(color: Color) -> Texture2D:
	return PixelArt.cached("altar_%s" % color.to_html(), func() -> Image:
		var rows := PackedStringArray([
			"..44444444444444..",
			".3333333333333333.",
			"..222222222222222.",
			"....2233g3322.....",
			"....2233g3322.....",
			"....2223g3222.....",
			"....2223g3222.....",
			"...222222222222...",
			"..11111111111111..",
			".1111111111111111.",
		])
		var img := PixelArt.paint(rows, {"1": "stone:1", "2": "stone:2", "3": "stone:3", "4": "stone:4", "g": "#%s" % color.to_html(false)})
		return img)


## The spring: a stone basin with water (dark once drunk). 32x18.
static func fountain(full: bool) -> Texture2D:
	return PixelArt.cached("fountain_%d" % int(full), func() -> Image:
		var img := PixelArt.blank(32, 18)
		var c := Vector2(16, 10)
		for j in 18:
			for i in 32:
				var dx := (i + 0.5 - c.x) / 15.5
				var dy := (j + 0.5 - c.y) / 7.5
				var d := sqrt(dx * dx + dy * dy)
				if d < 1.0:
					var col := Style.c("stone:2")
					if d < 0.78:
						col = Style.c("frost:1") if full else Style.c("night:2")
						if full and dy < -0.1:
							col = Style.c("frost:2")
					elif dy < -0.2:
						col = Style.c("stone:3")
					elif dy > 0.5:
						col = Style.c("stone:1")
					img.set_pixel(i, j, col)
		# the spout
		img.fill_rect(Rect2i(14, 1, 4, 9), Style.c("stone:2"))
		img.fill_rect(Rect2i(14, 1, 1, 9), Style.c("stone:3"))
		img.fill_rect(Rect2i(13, 0, 6, 2), Style.c("stone:3"))
		if full:
			img.set_pixel(16, 3, Style.c("frost:3"))
			img.set_pixel(16, 5, Style.c("frost:4"))
		return PixelArt.outlined(img))


## The merchant: a hooded figure behind a stall. Two frames (a small bob). 30x28.
static func merchant(frame: int) -> Texture2D:
	return PixelArt.cached("merchant_%d" % frame, func() -> Image:
		var pal := {"1": "violet:0", "2": "violet:1", "3": "violet:2", "4": "violet:3", "e": "gold:4", "o": "night:0",
			"s": "skin:2", "w": "wood:1", "W": "wood:2", "V": "wood:3", "c": "gold:3", "C": "gold:4", "r": "blood:2", "R": "blood:3"}
		var hood := [
			"...........2222.........",
			".........22333322.......",
			"........2333443332......",
			".......23334444332......",
			".......2331oooo132......",
			".......231oeooeo12......",
			".......231oooooo12......",
			".......2331oooo132......",
			"......223331ss133332....",
			".....22333333333333322..",
			"....223333333443333332..",
			"....233333333443333332..",
			"....233333333443333332..",
			"....233333333333333332..",
		]
		var stall := [
			"rRrRrRrRrRrRrRrRrRrRrRrRrRrRrR",
			".rRrRrRrRrRrRrRrRrRrRrRrRrRrR.",
			"VVVVVVVVVVVVVVVVVVVVVVVVVVVVVV",
			"WWcCWWWWWWWWWWWWWWWWWWWcCcWWWW",
			"WWccWWWWWWWWWWWWWWWWWWWWccWWWW",
			"wwwwwwwwwwwwwwwwwwwwwwwwwwwwww",
			".w..........................w.",
			".w..........................w.",
		]
		return PixelArt.layered(30, 28, [[hood, Vector2i(3, 5 + frame)], [stall, Vector2i(0, 20)]], pal))


## The forge: an anvil on a stump with a glowing ember. 22x16.
static func anvil() -> Texture2D:
	return PixelArt.cached("anvil", func() -> Image:
		var rows := PackedStringArray([
			".4444444444444444.....",
			"33333333333333333333..",
			".2222222222222222222..",
			"......2222222.........",
			".......22222..........",
			"......2222222.........",
			".....222222222........",
			"...wwwwwwwwwwwwww.....",
			"...WWWWWWWWWWWWWW.....",
			"...WwWWWwWWWWwWWW.....",
			"...WWWWWWWWWWWWWW.....",
			"...wwwwwwwwwwwwww.....",
		])
		return PixelArt.paint(rows, {"1": "steel:0", "2": "steel:1", "3": "steel:2", "4": "steel:3", "w": "wood:1", "W": "wood:2"}))


## A torch flame, 5x8, three flicker frames (drawn additive in the glow layer).
static func flame(frame: int) -> Texture2D:
	return PixelArt.cached("flame_%d" % frame, func() -> Image:
		var frames := [
			["..3..", ".343.", ".343.", "34w43", "34w43", ".444.", "..4..", "....."],
			[".3...", ".33..", "..43.", ".3w43", "34w43", "34443", ".444.", "..4.."],
			["...3.", "..33.", ".34..", "34w4.", "34w43", "34443", ".444.", "..4.."],
		]
		return PixelArt.paint(PackedStringArray(frames[frame % 3]), {"3": "ember:3", "4": "ember:4", "w": "#fff6d8"}, false, false))


## The torch's wall bracket (drawn in the room layer, under the flame). 5x6.
static func sconce() -> Texture2D:
	return PixelArt.cached("sconce", func() -> Image:
		return PixelArt.paint(PackedStringArray(["22222", ".313.", "..3..", "..3..", ".222."]), {"1": "gold:2", "2": "wood:1", "3": "wood:2"}))


## Familiars (D2), two frames each: the Daemon (a small violet sprite, 9x8), the Watchdog
## Turret (a rune post with a gold eye, 10x11) and the Rubber Duck (10x8).
static func familiar(kind: StringName, frame: int) -> Texture2D:
	var f := frame % 2
	return PixelArt.cached("fam_%s_%d" % [kind, f], func() -> Image: return _familiar(kind, f))


static func _familiar(kind: StringName, f: int) -> Image:
	if kind == &"daemon":
		var wings: String = ["3.......3", ".3.....3."][f]
		return PixelArt.paint(PackedStringArray([wings, "..34443..", ".3444443.", ".34w4w43.", ".3444443.", "..34443..", "...343...", "....3...."]),
			{"3": "violet:2", "4": "violet:3", "w": "violet:4"})
	if kind == &"turret":
		var eye: String = ["..34ww43..", "..344w43.."][f]
		return PixelArt.paint(PackedStringArray(["...3333...", "..344443..", eye, "..344443..", "...3333...", "....22....", "...2222...", "..222222..", ".22222222.", "1111111111"]),
			{"1": "steel:1", "2": "steel:2", "3": "gold:2", "4": "gold:3", "w": "gold:4"})
	var head: String = ["...34443..", "...3444311"][f]
	return PixelArt.paint(PackedStringArray(["....333...", head, "...34w4411", "....44411.", "3...4443..", "34444444..", ".3444443..", "..33333..."]),
		{"1": "ember:3", "3": "gold:2", "4": "gold:3", "w": "night:0"})
