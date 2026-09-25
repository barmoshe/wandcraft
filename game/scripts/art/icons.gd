class_name Icons
extends RefCounted
## Spell icons: a plate whose shape tells the spell kind, and a 7x7 glyph in the spell color.
##   shooting = round gem   boost = diamond   trigger = bracket tile   passive = square gem
## Original pixel art (decisions/0002). 14x14 with outline.

const GLYPHS := {
	&"mote": ["..###..", ".#####.", "##.####", "#######", "#######", ".#####.", "..###.."],
	&"lance": ["......#", ".....##", "....##.", "...##..", "..##...", ".##....", "#......"],
	&"fan": ["#..#..#", "#..#..#", ".#.#.#.", ".#.#.#.", "..###..", "...#...", "...#..."],
	&"burst": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	&"moths": ["##...##", "###.###", ".##.##.", "...#...", ".##.##.", "###.###", "##...##"],
	&"seed": ["...#...", "..###..", ".##.##.", ".#...#.", ".##.##.", "..###..", "...#..."],
	&"wheel": ["...#...", "..###..", "#######", ".#####.", "..###..", ".##.##.", "##...##"],
	&"empower": ["...#...", "..###..", ".#####.", "...#...", "...#...", "..###..", "..###.."],
	&"quicken": ["#..#...", ".#..#..", "..#..#.", "...#..#", "..#..#.", ".#..#..", "#..#..."],
	&"seek": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	&"phase": ["#.#.#..", ".......", "#.#.###", "......#", "#.#.###", ".......", "#.#.#.."],
	&"ricochet": ["#.....#", ".#...#.", "..#.#..", "...#...", ".......", "#######", "......."],
	&"twin": ["##...##", "##...##", ".......", "##...##", "##...##", ".......", "##...##"],
	&"chorus": ["#.#.#.#", "#.#.#.#", "#.#.#.#", "#######", "..###..", "...#...", "...#..."],
	&"mirror": ["###.###", "#...#..", "#...#..", "#.#.#.#", "..#...#", "..#...#", "###.###"],
	&"then": ["#######", ".......", "..#....", "..##...", "..###..", "..##...", "..#...."],
	&"callback": [".####..", "#....#.", "#.....#", "#...###", "#....#.", "#......", ".####.."],
	&"loop": ["..###..", ".#...#.", "#.....#", "#....##", "#...###", ".#.....", "..###.."],
	&"fork": ["#..#..#", "#..#..#", ".#.#.#.", "..###..", "...#...", "...#...", "..###.."],
	&"needle": ["......#", ".....#.", "....#..", "...#...", "..#....", ".#.....", "#......"],
	&"ember": ["...#...", "..#.#..", ".#...#.", ".#.#.#.", "#.###.#", "#.###.#", ".#####."],
	&"spark": ["...##..", "..##...", ".####..", "...##..", "..##...", ".##....", "#......"],
	&"frost": ["...#...", "#..#..#", ".#.#.#.", "..###..", ".#.#.#.", "#..#..#", "...#..."],
	&"heavy": ["..###..", ".#...#.", ".#####.", "#######", "#######", "#######", ".#####."],
	&"wide": ["#.....#", ".#...#.", "...#...", "..###..", "...#...", ".#...#.", "#.....#"],
	&"keen": ["......#", ".....##", "....##.", "#..##..", ".###...", "..#....", ".#.#..."],
	&"ember_coat": ["...#...", "..##...", "..###..", ".####..", ".#####.", "##.####", ".#####."],
	&"frost_coat": ["...#...", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "...#..."],
	&"heatsink": ["#.#.#.#", "#.#.#.#", "#.#.#.#", "#######", "#######", "..###..", "..###.."],
	# 0.4 spells: fallbacks until their illustrated icons (IconSpells) land
	&"disc": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	&"mine": ["...#...", ".#.#.#.", "..###..", "###.###", "..###..", ".#.#.#.", "...#..."],
	&"static": ["#......", "##.....", "#.#....", "#..#...", "#.#....", "##.....", "#......"],
	&"null_orb": ["..###..", ".#...#.", "#.###.#", "#.###.#", "#.###.#", ".#...#.", "..###.."],
	&"split": ["#.....#", ".#...#.", "..#.#..", "...#...", "...#...", "...#...", "...#..."],
	&"gravity": ["#######", "#.....#", "#.###.#", "#.#.#.#", "#.#...#", "#.#####", "#......"],
	&"finally": [".#####.", "#.#.#.#", "#######", ".#####.", "...#...", "..###..", ".#####."],
}


static func spell(d: SpellDef) -> Texture2D:
	if not IconArt.spell(d.id).is_empty():
		return PixelArt.cached("icon2_%s" % d.id, func() -> Image: return framed(d.kind, IconArt.spell(d.id)))
	return PixelArt.cached("icon_%s" % d.id, func() -> Image: return _build(d))


## A 0.4 icon: a 16x16 frame whose shape tells the kind, with the illustration inside.
## kind: SpellDef.Kind, or -1 for a relic (a gold-rimmed square medallion).
static func framed(kind: int, entry: Dictionary) -> Image:
	var r: Array = Style.RAMPS[entry.get("ramp", "arcane")]
	var img := PixelArt.blank(16, 16)
	for j in 16:
		for i in 16:
			var x := i + 0.5 - 8.0
			var y := j + 0.5 - 8.0
			var inside := false
			var edge := 0.0   # distance from the rim, in px
			match kind:
				SpellDef.Kind.PROJ:
					var d := sqrt(x * x + y * y)
					inside = d < 8.0
					edge = 8.0 - d
				SpellDef.Kind.BOOST:
					var m := absf(x) + absf(y)
					inside = m < 9.5 and absf(x) < 7.6 and absf(y) < 7.6
					edge = minf(9.5 - m, 7.6 - maxf(absf(x), absf(y)))
				SpellDef.Kind.TRIG:
					inside = absf(x) < 8.0 and absf(y) < 7.0 and absf(x) + absf(y) < 13.0
					edge = minf(minf(8.0 - absf(x), 7.0 - absf(y)), 13.0 - absf(x) - absf(y))
				SpellDef.Kind.RUNE:
					# a hexagon: Debugger runes edit the program itself
					inside = absf(y) < 7.6 and absf(x) + absf(y) * 0.5 < 8.0
					edge = minf(7.6 - absf(y), (8.0 - absf(x) - absf(y) * 0.5) * 0.9)
				SpellDef.Kind.FAMILIAR:
					# a shield: round on top, pointed below
					if y < 0.0:
						var dd := sqrt(x * x + y * y)
						inside = dd < 8.0
						edge = 8.0 - dd
					else:
						inside = absf(x) + y * 0.9 < 8.0
						edge = (8.0 - absf(x) - y * 0.9) * 0.75
				_:
					inside = absf(x) < 7.5 and absf(y) < 7.5 and absf(x) + absf(y) < 13.5
					edge = minf(7.5 - maxf(absf(x), absf(y)), 13.5 - absf(x) - absf(y))
			if not inside:
				continue
			var col := Color(r[0]).lerp(Style.INK, 0.35)   # recessed field
			if edge < 1.0:
				# bevelled rim: lit top-left, shaded bottom-right
				col = Color(r[3]) if (x + y) < -2.0 else (Color(r[1]) if (x + y) > 2.0 else Color(r[2]))
				if kind == -1:
					col = Style.c("gold:3") if (x + y) < -2.0 else (Style.c("gold:1") if (x + y) > 2.0 else Style.c("gold:2"))
			img.set_pixel(i, j, col)
	var lg := IconArt.legend(entry)
	var rows: Array = entry["rows"]
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			if lg.has(row[i]):
				img.set_pixel(i + 2, j + 2, lg[row[i]])
	return PixelArt.outlined(img)


static func _build(d: SpellDef) -> Image:
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	var base := d.color.darkened(0.55)
	var rim := d.color.darkened(0.2)
	for j in 12:
		for i in 12:
			var x := i + 0.5 - 6.0
			var y := j + 0.5 - 6.0
			var inside := false
			var edge := false
			match d.kind:
				SpellDef.Kind.PROJ:
					var r := sqrt(x * x + y * y)
					inside = r < 6.0
					edge = r >= 4.9
				SpellDef.Kind.BOOST:
					var m := absf(x) + absf(y)
					inside = m < 7.0
					edge = m >= 5.9
				SpellDef.Kind.TRIG:
					inside = absf(x) < 6.0 and absf(y) < 5.5 and not (absf(x) > 4.5 and absf(y) > 4.0)
					edge = absf(x) >= 5.0 or absf(y) >= 4.5
				_:
					inside = true
					edge = absf(x) >= 5.0 or absf(y) >= 5.0
			if inside:
				img.set_pixel(i, j, rim if edge else base)
	var g: Array = GLYPHS.get(d.id, GLYPHS[&"mote"])
	var ink := d.color.lightened(0.45)
	for j in 7:
		var row: String = g[j]
		for i in 7:
			if row[i] == "#":
				img.set_pixel(i + 2, j + 2, ink)
	# a highlight pixel pair on the top-left of the plate
	if img.get_pixel(3, 2).a > 0.0:
		img.set_pixel(3, 2, img.get_pixel(3, 2).lightened(0.35))
	return PixelArt.outlined(img)


const RELIC_GLYPHS := {
	"heart": [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
	"bin": [".#####.", "#######", ".#.#.#.", ".#.#.#.", ".#.#.#.", ".#.#.#.", "..###.."],
	"chip": [".#.#.#.", "#######", ".#...#.", "##.#.##", ".#...#.", "#######", ".#.#.#."],
	"stack": ["#######", ".......", "#######", ".......", "#######", ".......", "#######"],
	"shield": ["#######", "#.....#", "#.###.#", "#.###.#", ".#.#.#.", "..#.#..", "...#..."],
	"clover": [".##.##.", "###.###", ".##.##.", "...#...", ".##.##.", "###.###", ".##.##."],
	"drop": ["...#...", "..###..", ".#####.", "#######", "#######", ".#####.", "..###.."],
	"spiral": [".#####.", "#.....#", "#.###.#", "#.#.#.#", "#.#...#", "#.#####", "#......"],
	"fan": ["#..#..#", "#..#..#", ".#.#.#.", ".#.#.#.", "..###..", "...#...", "...#..."],
	"coin": ["..###..", ".#####.", "##.#.##", "##.#.##", "##.#.##", ".#####.", "..###.."],
	"loop": ["..###..", ".#...#.", "#.....#", "#....##", "#...###", ".#.....", "..###.."],
	"gem": [".#####.", "#.#.#.#", "#######", ".#####.", "..###..", "...#...", "......."],
	"ghost": ["..###..", ".#####.", "##.#.##", "#######", "#######", "#######", "#.#.#.#"],
	"eye": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	"burst": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
	"battery": ["..###..", ".#####.", ".#...#.", ".#.#.#.", ".#.#.#.", ".#...#.", ".#####."],
	"cursor": ["#......", "##.....", "###....", "####...", "#####..", "..##...", "...##.."],
	"clock": ["..###..", ".#.#.#.", "#..#..#", "#..##.#", "#.....#", ".#...#.", "..###.."],
	"boot": [".###...", ".###...", ".###...", ".###...", ".#####.", "#######", "#######"],
	"bounce": ["#.....#", ".#...#.", "..#.#..", "...#...", ".......", "#######", "......."],
	"box": ["#######", "#.....#", "#.#.#.#", "#..#..#", "#.#.#.#", "#.....#", "#######"],
	"sword": ["......#", ".....#.", "#...#..", ".#.#...", "..#....", ".#.#...", "#......"],
	"skull": [".#####.", "#######", "#.#.#.#", "#######", ".#####.", ".#.#.#.", "......."],
	"chest": ["#######", "#.....#", "#######", "#..#..#", "#.....#", "#######", "......."],
	"flask": ["..###..", "...#...", "...#...", "..###..", ".#####.", "#######", ".#####."],
	"anvil": ["#######", ".#####.", "...#...", "...#...", "..###..", ".#####.", "#######"],
	"star": ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "#.....#"],
	"arrow": ["...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.."],
	"wand": ["......#", ".....##", "....##.", "...#...", "..#....", ".#.....", "#......"],
	"bag": ["..###..", ".#...#.", "#######", "#.....#", "#.###.#", "#.....#", "#######"],
	"pause": ["##.##..", "##.##..", "##.##..", "##.##..", "##.##..", "##.##..", "##.##.."],
}

const DOOR_GLYPH := {
	"spell": "star", "relic": "gem", "gold": "coin", "heart": "heart", "wand": "wand", "challenge": "skull",
	"shop": "coin", "spring": "drop", "forge": "anvil", "mini": "skull", "boss": "skull", "exit": "arrow",
}


## A relic: a gold-rimmed round plate with the relic's glyph.
static func relic(id: StringName) -> Texture2D:
	if not IconArt.relic(id).is_empty():
		return PixelArt.cached("relic2_%s" % id, func() -> Image: return framed(-1, IconArt.relic(id)))
	var d: Dictionary = Relics.DEFS[id]
	return PixelArt.cached("relic_%s" % id, func() -> Image:
		return _plate(Color(d["color"]), RELIC_GLYPHS[d["glyph"]], Color("#e0b84e")))


## A door or UI glyph on a colored plate.
static func glyph(name: String, color: Color) -> Texture2D:
	return PixelArt.cached("glyph_%s_%s" % [name, color.to_html()], func() -> Image:
		return _plate(color, RELIC_GLYPHS[name], color.lightened(0.3)))


static func door(key: String) -> Texture2D:
	var c: Color = Color(Chapter.INFO.get(key, {"color": "#ffffff"})["color"])
	return glyph(DOOR_GLYPH.get(key, "star"), c)


static func _plate(color: Color, g: Array, rim: Color) -> Image:
	var img := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	for j in 12:
		for i in 12:
			var r := Vector2(i + 0.5 - 6.0, j + 0.5 - 6.0).length()
			if r < 6.0:
				img.set_pixel(i, j, rim if r >= 5.0 else color.darkened(0.6))
	for j in 7:
		var row: String = g[j]
		for i in 7:
			if row[i] == "#":
				img.set_pixel(i + 2, j + 2, color.lightened(0.35))
	return PixelArt.outlined(img)
