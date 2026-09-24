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
	&"shatter": ["#..#..#", ".#...#.", "...#...", "#.###.#", "...#...", ".#...#.", "#..#..#"],
	&"mirror": ["###.###", "#...#..", "#...#..", "#.#.#.#", "..#...#", "..#...#", "###.###"],
	&"then": ["#######", ".......", "..#....", "..##...", "..###..", "..##...", "..#...."],
	&"callback": [".####..", "#....#.", "#.....#", "#...###", "#....#.", "#......", ".####.."],
	&"loop": ["..###..", ".#...#.", "#.....#", "#....##", "#...###", ".#.....", "..###.."],
	&"fork": ["#..#..#", "#..#..#", ".#.#.#.", "..###..", "...#...", "...#...", "..###.."],
	&"cache": ["..###..", ".#...#.", "#.###.#", "#.###.#", "#.###.#", ".#...#.", "..###.."],
	&"heatsink": ["#.#.#.#", "#.#.#.#", "#.#.#.#", "#######", "#######", "..###..", "..###.."],
}


static func spell(d: SpellDef) -> Texture2D:
	return PixelArt.cached("icon_%s" % d.id, func() -> Image: return _build(d))


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
