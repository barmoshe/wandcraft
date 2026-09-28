class_name KernelArt
extends RefCounted
## World 3, the Kernel (0.20, research/world3-0.20.md §3): the Data Race twins, the
## Glitch, the three residents and their speech-box faces, and the Kernel's props (cage,
## wall clock, revert glyph, leak puddle, Lost Page, diff rows). Style ramps only
## (decisions/0007); light from the top left, INK on the bottom and right. Everything is
## built from char grids painted by PixelArt.paint (rim light and sel-out for free), baked
## once per parameter set and cached.

static var _cache := {}


static func _baked(key: String, make: Callable) -> Texture2D:
	if not _cache.has(key):
		_cache[key] = PixelArt.tex(make.call())
	return _cache[key]


# ------------------------------------------------------------------ char grids

static func _grid(w: int, h: int) -> Array:
	var g := []
	for j in h:
		var r := []
		r.resize(w)
		r.fill(".")
		g.append(r)
	return g


static func _put(g: Array, x: int, y: int, ch: String) -> void:
	if y >= 0 and y < g.size() and x >= 0 and x < (g[0] as Array).size():
		g[y][x] = ch


static func _rect(g: Array, r: Rect2i, ch: String) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_put(g, x, y, ch)


## ASCII rows onto the grid; "." is see-through, "_" keeps what is under it.
static func _stamp(g: Array, rows: Array, at: Vector2i) -> void:
	for j in rows.size():
		var s: String = rows[j]
		for i in s.length():
			if s[i] != "." and s[i] != "_":
				_put(g, at.x + i, at.y + j, s[i])


static func _rows(g: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for r in g:
		out.append("".join(PackedStringArray(r)))
	return out


static func _line(g: Array, a: Vector2i, b: Vector2i, ch: String) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(k) / maxf(1.0, n)).round()
		_put(g, int(p.x), int(p.y), ch)


# ------------------------------------------------------------------ Data Race (the twins)

## The twins are spools of thread on two thin legs, trailing a loose end: A in cyan, B in
## amber. 20x20 (18x18 plus the outline), facing right.
const THREAD_BODY := [
	"..FFFFFFFF..",
	".fFFFFFFFFf.",
	".dddddddddd.",
	"..44444444..",
	"..3333EEE3..",
	"..2222EEo2..",
	"..33333333..",
	"..22222222..",
	".ffffffffff.",
	".dffffffffd.",
	"..dddddddd..",
]
const THREAD_LEGS := [
	["....l..l....", "...l....l...", "..l......l..", ".kk.......kk"],
	[".....ll.....", ".....ll.....", ".....l.l....", "....kk.kk..."],
	["....l..l....", "...l...l....", "..l.....l...", ".kk.....kk.."],
	[".....ll.....", "....l..l....", "....l..l....", "...kk..kk..."],
]
const THREAD_CROUCH := [".l........l.", "kk........kk"]


static func thread(which: int, frame: int) -> Texture2D:
	var w := clampi(which, 0, 1)
	var f := clampi(frame, 0, 4)
	return _baked("thread_%d_%d" % [w, f], func() -> Image: return _thread(w, f))


static func _thread(which: int, f: int) -> Image:
	var own: String = ["cyan", "amber"][which]
	var pal := {"F": "steel:4", "f": "steel:3", "d": "steel:2", "l": "steel:3", "k": "steel:1",
		"2": own + ":2", "3": own + ":3", "4": own + ":4", "t": own + ":3", "T": own + ":4",
		"E": "phosphor:4", "o": "void:0"}
	var g := _grid(18, 18)
	var wind := f == 4
	var by := 4 if wind else (1 if f % 2 == 1 else 2)
	_stamp(g, THREAD_BODY, Vector2i(6, by))
	if wind:
		_stamp(g, THREAD_CROUCH, Vector2i(6, by + 11))
		pal["E"] = "threat:4"
		pal["o"] = "threat:2"
		# the loose end pulled taut and raised behind it, like a whip about to crack
		_line(g, Vector2i(6, by + 5), Vector2i(1, by - 2), "t")
		_put(g, 0, by - 3, "T")
	else:
		# it leans into the run: the top flange and the eye a pixel ahead
		for j in 6:
			var row: Array = g[by + j]
			row.push_front(".")
			row.pop_back()
		_stamp(g, THREAD_LEGS[f], Vector2i(6, by + 11))
		# the loose end trails in a wave that travels backward as it runs
		for x in 6:
			var y := by + 5 + int(round(sin((x + f * 1.5) * 1.3) * 1.2))
			_put(g, 5 - x, y, "t" if x < 4 else "T")
	return PixelArt.paint(_rows(g), pal)


# ------------------------------------------------------------------ the Glitch

## The bug from the hero's first commit, made flesh: the hero's quiff, shades and beard
## over a torso of corrupted code, a nest core where the heart would be, arms of loose
## shards and no legs (it trails off into falling glyphs). 40x44.
const GLITCH_HEAD := [
	"............Hh....",
	"...........HHh.h..",
	"........hhHHhhhh..",
	"......hhHHhhhhhhh.",
	"....hhHHhhhhhhhhhh",
	"...hHhhhhhhhhhhhh.",
	"...hhhhhhhhhhhhhh.",
	"...hkkkkkkkkkkkkh.",
	"...kkkkkkkkkkkkkk.",
	"...oooooooooooooo.",
	"...oGgGGGoooGgGGo.",
	"...oGGGGGokoGGGGo.",
	"...koGGGokkkoGGok.",
	"...kkkkkkkkkkkkkk.",
	"...bkbbbbbbbbbbkb.",
	"...bbbbbmmmmbbbbb.",
	"....bbbbbbbbbbbb..",
	".....bbbbbbbbbb...",
	".......bbbbbb.....",
]
const GLITCH_PAL := {
	"h": "quill:3", "H": "nest:3", "k": "void:3", "o": "void:0", "G": "cyan:2", "g": "cyan:4",
	"b": "quill:2", "m": "nest:3",
	"Y": "phosphor:3", "y": "phosphor:2", "z": "void:2", "W": "phosphor:4",
	"T": "nest:3", "t": "nest:2", "Q": "cyan:2",
	"n": "nest:2", "N": "nest:3", "X": "nest:4", "x": "phosphor:4",
	"p": "phosphor:3", "q": "nest:3", "r": "leaf:3", "R": "leaf:4",
}


static func glitch(phase: int, frame: int) -> Texture2D:
	var p := clampi(phase, 0, 2)
	var f := clampi(frame, 0, 4)
	return _baked("glitch_%d_%d" % [p, f], func() -> Image: return _glitch(p, f))


## Its shirt is the hero's yellow shirt rewritten as lines of code: every other row a line of
## tokens (an indent, then runs of 2-5 lit pixels), the rows between dark. Fixed per row, so
## the code does not crawl between frames.
static func _code(x: int, y: int) -> bool:
	if y % 2 == 1:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + y * 131
	var at := 7 + rng.randi_range(0, 4) * 2
	while at < 38:
		var run := rng.randi_range(2, 5)
		if x >= at and x < at + run:
			return true
		at += run + 1
	return false


static func _glitch(phase: int, f: int) -> Image:
	var W := 38
	var H := 42
	var g := _grid(W, H)
	var tele := f == 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 7001 + phase * 17 + f
	var cx := 19.0
	# the torso and the arms: dark cloth written over with code; the right third in shadow
	var body := func(x: int, y: int, arm: bool) -> void:
		var ch := "z"
		if (not arm and _code(x, y)) or (arm and y % 2 == 0 and (x * 3 + y) % 5 != 0):
			ch = "Y" if x < 24 else "y"
			if phase == 2 and (y > 29 - (f % 2) * 2 or (y * 7 + f) % 9 == 0):
				ch = "R" if (x + y) % 5 == 0 else "r"   # reverted lines: the old code, in green
		_put(g, x, y, ch)
	for y in range(18, 35):
		var t := y - 18
		var hw := 12.5 - maxf(0.0, t - 2) * 0.3
		if t == 0:
			hw = 7.5
		elif t == 1:
			hw = 10.5
		for x in range(int(round(cx - hw)), int(round(cx + hw))):
			body.call(x, y, false)
	# the arms hang a pixel off the body and end in claws of glyphs
	for y in range(20, 33):
		for x in [4, 5, 6, 31, 32, 33]:
			var sway := 1 if y > 23 else 0
			var ax: int = x - sway if x < 19 else x + sway
			body.call(ax, y, true)
	_glyph(g, 0, Vector2i(3, 33), "p")
	_glyph(g, 1, Vector2i(32, 33), "p")
	# collar, suspenders and tie: the hero's outfit in the nest's colours
	_stamp(g, ["WWWWWW", "WW..WW"], Vector2i(16, 18))
	for y in range(20, 35):
		_put(g, 13 - (1 if y > 30 else 0), y, "Q")
		_put(g, 25 + (1 if y > 30 else 0), y, "Q")
	_rect(g, Rect2i(18, 19, 2, 12), "T")
	_stamp(g, ["tTTt", ".tt."], Vector2i(17, 31))
	# the nest core where the heart would be, pulsing
	var rad: float = [3.0, 3.6, 4.2, 3.6, 4.8][f]
	for y in range(19, 33):
		for x in range(12, 27):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - 25.0).length()
			if d < rad:
				_put(g, x, y, "x" if d < rad * 0.3 else ("X" if d < rad * 0.6 else ("N" if d < rad * 0.85 else "n")))
	_stamp(g, GLITCH_HEAD, Vector2i(10, 0))
	# below the waist it comes apart into falling glyphs
	for i in 5:
		var gx := 9 + i * 4
		var gy := 36 + (i * 2 + f) % 3
		var ch := "p" if i % 2 == 0 else "q"
		if phase == 2 and i % 2 == 0:
			ch = "r"
		_glyph(g, (i + f) % 6, Vector2i(gx, gy), ch)
	var pal := GLITCH_PAL.duplicate()
	if tele:
		pal["G"] = "threat:3"
		pal["g"] = "threat:4"
		pal["o"] = "threat:1"
	if phase >= 1:
		# the stack unwinds: holes open through the body
		for k in 5 + phase * 4:
			var hx := rng.randi_range(7, 31)
			var hy := rng.randi_range(21, 34)
			if absf(hx - cx) < 4.0 and hy < 30:
				continue   # the core stays whole
			_rect(g, Rect2i(hx, hy, rng.randi_range(1, 3), 1 + rng.randi_range(0, 1)), ".")
	if phase == 2:
		# the revert takes it apart from the feet up: chunks of the lower body are gone
		for k in 26:
			var hx := rng.randi_range(4, 34)
			var hy := rng.randi_range(24, 41)
			if rng.randf() < float(hy - 22) / 20.0:
				_rect(g, Rect2i(hx, hy, rng.randi_range(1, 3), 1), ".")
	var img := PixelArt.paint(_rows(g), pal)
	# scan-line tears, more of them as it breaks down
	var bands := [[5 + (f * 7) % 28, 1, 1 if f % 2 else -1]]
	if phase >= 1:
		bands.append([12 + (f * 5) % 20, 2, 2])
		bands.append([27 + (f * 3) % 9, 1, -2])
	if phase >= 2:
		bands.append([19 + (f * 11) % 16, 2, -3])
	img = RigBaker.tear(img, bands)
	if phase == 1 and f < 4:
		_old_boss(img, f)
	return img


## A 3x5 code glyph (Bestiary.CODE_GLYPHS) stamped in one colour.
static func _glyph(g: Array, k: int, at: Vector2i, ch: String) -> void:
	var gl: Array = Bestiary.CODE_GLYPHS[posmod(k, Bestiary.CODE_GLYPHS.size())]
	for j in 5:
		for i in 3:
			if String(gl[j])[i] == "#":
				_put(g, at.x + i, at.y + j, ch)


## Phase 1 (Stack unwind): a patch of an old boss flickers in its chest, one per frame:
## the Loop's eye, the Collector's lid, a code block, Copy-Paste's shades.
static func _old_boss(img: Image, f: int) -> void:
	var src: Image
	var from := Vector2i.ZERO
	match f:
		0:
			src = Bestiary.loop_head(false).get_image()
			from = Vector2i(2, 4)
		1:
			src = Bestiary.collector(false).get_image()
			from = Vector2i(8, 12)
		2:
			src = Bestiary.code_block(4).get_image()
			from = Vector2i(3, 2)
		_:
			src = (Bestiary.clone_frames()[0] as Texture2D).get_image()
			from = Vector2i(5, 6)
	var at := Vector2i(10, 22)
	for j in 8:
		for i in 12:
			var sp := from + Vector2i(i, j)
			if sp.x >= src.get_width() or sp.y >= src.get_height():
				continue
			var c := src.get_pixel(sp.x, sp.y)
			var q := at + Vector2i(i, j)
			if c.a > 0.0 and img.get_pixel(q.x, q.y).a > 0.0:
				img.set_pixel(q.x, q.y, c)


# ------------------------------------------------------------------ residents

## The three residents standing (idle loop, frames 0-3), facing right.
static func resident(id: StringName, frame: int) -> Texture2D:
	var f := posmod(frame, 4)
	return _baked("res_%s_%d" % [id, f], func() -> Image: return _resident(id, f))


const GREP_BODY := [
	".....111........",
	"....12221.......",
	"...1222221......",
	"..122222222211..",
	"..1222223SS41...",
	".12222223SoS4...",
	".1222222mSSSS...",
	"12212222mmMmmm..",
	"12221222mmmMmmm.",
	"122221222mmmMhh.",
	"1222221222mmmhh.",
	"12222221222m1...",
	".12222221222....",
	".122222221221...",
	".1122222212221..",
	"..11211221121...",
	"...kk....kk.....",
]
const GREP_LANTERN := [
	"..s..",
	".sSs.",
	"sgGgs",
	"sgGgs",
	".sss.",
]
const HOTFIX_BODY := [
	"........rrrrrr........",
	".......rRRRRRRr.......",
	".......rReRReRr.......",
	".......rRRRRRRr.......",
	"...ssssrrrrrrrrRRRRr..",
	"..sSSSSs3333RRRRrRRRRr",
	"..sSSSSsx333xRRRrRRRRr",
	"..sSSSSs3x3x3RRRrRRRRr",
	"..sSSSSs33x33cCRrRRRRr",
	"..sSSSSs3x3x3CcRrRRRRr",
	"..sSSSSsx333xRRRrRRRRr",
	"..sssss.2222222r.rrrr.",
	"..SSSS..2222222..RRRR.",
	"..ssss..ww...ww..rrrr.",
	"........kk...kk.......",
]
const CACHE_BODY := [
	"..444...........",
	".44444..........",
	".22222..........",
	"..33333.........",
	"..44444.........",
	".22222..........",
	"..33333.........",
	"..44444.........",
	"...22222........",
	"...33333........",
	"...44444..11....",
	"...22222.1vv1...",
	"....33331vvvV1..",
	"....44441vSSce..",
	"....22221SSSS1..",
	".....3331vSS1...",
	"......1vvvvv1...",
	"......1vvvVvv1..",
	"......1vvvVvvh..",
	"......1vvvVvv1..",
	"......1vvvVvv1..",
	".....1vvvvVvvv1.",
	".....1vvvvVvvv1.",
	".....1vvvvvvvv1.",
	"....1vvvvvvvvvv1",
	"....11111111111.",
	".......kk..kk...",
]


static func _resident(id: StringName, f: int) -> Image:
	var breathe := 1 if f == 1 or f == 2 else 0
	match id:
		&"grep":
			var g := _grid(22, 22)
			var pal := {"1": "bone:1", "2": "bone:2", "3": "bone:3", "4": "bone:4", "o": "quill:0",
				"m": "moss:2", "M": "moss:3", "h": "bone:3", "k": "quill:1", "p": "wood:2",
				"s": "brass:2", "S": "brass:3", "g": "gold:3", "G": "gold:4"}
			if f == 2:
				pal["G"] = "amber:4"   # the flame flickers
			_stamp(g, GREP_BODY, Vector2i(0, 4 + (1 - breathe)))
			# the pole, from his hands up and forward, with a hook at the tip
			var hand := Vector2i(13, 13 + (1 - breathe))
			_line(g, hand, Vector2i(19, 1), "p")
			_put(g, 20, 1, "p")
			var sway: int = [0, 1, 0, -1][f]
			_put(g, 20 + sway, 2, "s")
			_stamp(g, GREP_LANTERN, Vector2i(18 + sway, 3))
			return PixelArt.paint(_rows(g), pal)
		&"hotfix":
			var g := _grid(22, 16)
			var pal := {"r": "rust:2", "R": "rust:3", "s": "steel:2", "S": "steel:3", "2": "wood:2", "3": "wood:3",
				"4": "rust:4", "e": "ember:4", "x": "bone:4", "c": "ember:3", "C": "ember:4", "w": "rust:1", "W": "rust:2",
				"k": "night:1"}
			if f == 1 or f == 2:
				pal["c"] = "ember:4"
				pal["C"] = "gold:4"
			_stamp(g, HOTFIX_BODY, Vector2i(0, 1 - breathe))
			if f == 3:
				# a puff of steam from the seam on his head
				_put(g, 10, 0, "x")
			return PixelArt.paint(_rows(g), pal)
		_:
			var g := _grid(16, 28)
			var pal := {"1": "violet:1", "v": "violet:2", "V": "violet:3", "S": "violet:3", "c": "cyan:4", "e": "cyan:3",
				"2": "vellum:2", "3": "vellum:3", "4": "vellum:4", "h": "violet:3", "k": "night:2"}
			_stamp(g, CACHE_BODY, Vector2i(0, 1 - breathe))
			if f == 3:
				# the top page flicks up
				_stamp(g, ["44...", ".4.44"], Vector2i(0, 0))
				_put(g, 1, 1, ".")
				_put(g, 2, 1, ".")
			return PixelArt.paint(_rows(g), pal)


# ------------------------------------------------------------------ portraits

## Speech-box faces at the Duck's size (Hud.duck_face: 12x11 painted, 14x13 with the outline),
## drawn at the same spot. Built from a base face plus a brow block (6x2), an eye row (6x1)
## and a mouth block (4x2); "_" in a block keeps the base pixel.
## mood: 0 neutral, 1 happy, 2 worried, 3 stern.
const BROWS := [
	["______", "bb__bb"],
	["bb__bb", "______"],
	["_b__b_", "b____b"],
	["b____b", "_b__b_"],
]
const MOUTHS := [
	[["____", "_kk_"], ["k__k", "_kk_"], ["_kk_", "k__k"], ["kkkk", "____"]],
	[["_kk_", "krrk"], ["krrk", "_kk_"], ["_kk_", "krrk"], ["kkkk", "krrk"]],
]
const FACES := {
	&"grep": {
		"rows": [
			"...111111...",
			"..12222221..",
			".12SSSSSSy1.",
			".12SSSSSSy1.",
			".12SSSSSSy1.",
			".12SSSnSSy1.",
			".1mmSSSSmm1.",
			".mmmmmmmmmm.",
			".mMmmmmmmMm.",
			"..mmmMmmmm..",
			"...mmmmmm...",
		],
		"pal": {"1": "bone:1", "2": "bone:2", "S": "bone:3", "n": "bone:2", "y": "gold:3", "m": "moss:2",
			"M": "moss:3", "b": "bone:4", "o": "quill:0", "w": "bone:4", "d": "bone:2", "k": "moss:0", "r": "quill:1"},
		"brow": Vector2i(3, 2), "eyes": Vector2i(3, 4), "mouth": Vector2i(4, 7),
		"open": "wo__wo", "shut": "dd__dd",
	},
	&"hotfix": {
		"rows": [
			"..rrrrrsss..",
			".rRRRRRSSSs.",
			".rRRRRRSSSs.",
			".rRRRRRSSSs.",
			".rRRRRRSSSs.",
			".rRRRRRxSxs.",
			".rRRRRRSxSs.",
			".rRRRRRxSxs.",
			".rRRRRRRRRr.",
			"..rrrrrrrr..",
			"...k....k...",
		],
		"pal": {"r": "rust:2", "R": "rust:3", "s": "steel:2", "S": "steel:3", "x": "bone:4", "b": "rust:1",
			"o": "ember:4", "w": "ember:3", "d": "rust:1", "k": "night:1"},
		"brow": Vector2i(3, 2), "eyes": Vector2i(3, 4), "mouth": Vector2i(3, 7),
		"open": "wo__wo", "shut": "dd__dd", "inner": "ember:2",
	},
	&"cache": {
		"rows": [
			"444.1111....",
			"222122221...",
			"3331SSSSS1..",
			"444SSSSSSS1.",
			"22SSSSSSSS1.",
			"3.1SSSSSSS1.",
			"..1SSSSSSS1.",
			"...SSSSSSS1.",
			"...1SSSSSS1.",
			"....1SSSS1..",
			".....1111...",
		],
		"pal": {"1": "violet:1", "2": "violet:2", "S": "violet:3", "3": "vellum:3", "4": "vellum:4", "b": "violet:1",
			"o": "cyan:4", "w": "cyan:3", "d": "violet:2", "k": "violet:1", "r": "quill:1"},
		"brow": Vector2i(3, 2), "eyes": Vector2i(3, 4), "mouth": Vector2i(5, 7),
		"open": "wo__wo", "shut": "dd__dd",
	},
}


static func portrait(id: StringName, mood: int, talk: bool, blink: bool) -> Texture2D:
	var m := clampi(mood, 0, 3)
	var key := "face_%s_%d_%d_%d" % [id, m, int(talk), int(blink)]
	return _baked(key, func() -> Image: return _portrait(id, m, talk, blink))


static func _portrait(id: StringName, mood: int, talk: bool, blink: bool) -> Image:
	var d: Dictionary = FACES.get(id, FACES[&"grep"])
	var g := _grid(12, 11)
	_stamp(g, d["rows"], Vector2i.ZERO)
	_stamp(g, BROWS[mood], d["brow"])
	var eyes: String = d["shut"] if blink else d["open"]
	if mood == 1 and not blink:
		eyes = eyes.replace("w", "_")   # a smiling squint
	_stamp(g, [eyes], d["eyes"])
	_stamp(g, MOUTHS[int(talk)][mood], d["mouth"])
	var pal: Dictionary = (d["pal"] as Dictionary).duplicate()
	if d.has("inner"):
		pal["r"] = d["inner"]
	return PixelArt.paint(_rows(g), pal)


# ------------------------------------------------------------------ props

## The cage a resident waits in: brass bars between a "[" and a "]" on a quill plinth with a
## verdigris label plate. 28x32. Open: the middle bars bent apart and the "]" swung out.
static func cage(open: bool) -> Texture2D:
	return _baked("cage_%d" % int(open), func() -> Image: return _cage(open))


static func _cage(open: bool) -> Image:
	var g := _grid(26, 30)
	# the top plate
	_rect(g, Rect2i(3, 0, 20, 1), "B")
	_rect(g, Rect2i(1, 1, 24, 1), "b")
	_rect(g, Rect2i(1, 2, 24, 1), "d")
	# the "[" on the left
	_rect(g, Rect2i(1, 2, 2, 24), "b")
	_rect(g, Rect2i(1, 2, 1, 24), "B")
	_rect(g, Rect2i(3, 3, 2, 1), "b")
	_rect(g, Rect2i(3, 24, 2, 1), "b")
	# the bars
	for x in [7, 11, 14, 18]:
		for y in range(3, 26):
			var dx := 0
			if open and (x == 11 or x == 14) and y > 6 and y < 23:
				var k := sin(PI * float(y - 6) / 17.0)
				dx = int(round(k * 3.0)) * (-1 if x == 11 else 1)
			_put(g, x + dx, y, "b")
	if open:
		# the "]" hangs open on its bottom hinge, turned toward us: a short slab
		_rect(g, Rect2i(23, 18, 2, 8), "b")
		_rect(g, Rect2i(21, 24, 2, 1), "b")
		_line(g, Vector2i(23, 17), Vector2i(25, 12), "d")
	else:
		_rect(g, Rect2i(23, 2, 2, 24), "b")
		_rect(g, Rect2i(21, 3, 2, 1), "b")
		_rect(g, Rect2i(21, 24, 2, 1), "b")
		# a small padlock on the "]"
		_stamp(g, [".L.", "L.L", "PPP", "PkP"], Vector2i(22, 12))
	# the plinth and its label plate
	_rect(g, Rect2i(0, 26, 26, 1), "Q")
	_rect(g, Rect2i(0, 27, 26, 2), "q")
	_rect(g, Rect2i(0, 29, 26, 1), "u")
	_rect(g, Rect2i(9, 27, 8, 2), "v")
	_rect(g, Rect2i(10, 27, 6, 1), "V")
	var pal := {"B": "brass:4", "b": "brass:3", "d": "brass:2", "Q": "quill:4", "q": "quill:3", "u": "quill:2",
		"v": "verdigris:2", "V": "verdigris:3", "L": "steel:3", "P": "steel:4", "k": "void:0"}
	return PixelArt.paint(_rows(g), pal)


## Seven-segment digits (3x7): which segments are lit, in the order a b c d e f g.
const SEG := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd",
	"6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg", "-": "g", " ": "",
}


## A wall clock / terminal plaque: amber seven-segment digits (the unlit segments glow
## faintly, like an old vacuum display) on a void screen in a brass frame. "16:59:57" is
## 35x14; the width follows the text.
static func clock(text: String) -> Texture2D:
	return _baked("clock_" + text, func() -> Image: return _clock(text))


static func _clock(text: String) -> Image:
	var inner := 0
	for i in text.length():
		inner += (1 if text[i] == ":" else 3) + (1 if i < text.length() - 1 else 0)
	var w := inner + 6
	var g := _grid(w, 12)
	_rect(g, Rect2i(0, 0, w, 11), "b")
	_rect(g, Rect2i(0, 0, 1, 11), "B")
	_rect(g, Rect2i(1, 1, w - 2, 9), "s")
	_rect(g, Rect2i(2, 11, w - 4, 1), "d")
	_put(g, 1, 10, "d")
	var x := 3
	for i in text.length():
		var ch := text[i]
		if ch == ":":
			_put(g, x, 4, "D")
			_put(g, x, 6, "E")
			x += 2
			continue
		var on: String = SEG.get(ch, "")
		for s in "abcdefg":
			var c := ("D" if s in "abfg" else "E") if on.contains(s) else "u"
			match s:
				"a": _rect(g, Rect2i(x, 2, 3, 1), c)
				"b": _rect(g, Rect2i(x + 2, 2, 1, 4), c)
				"c": _rect(g, Rect2i(x + 2, 5, 1, 4), c)
				"d": _rect(g, Rect2i(x, 8, 3, 1), c)
				"e": _rect(g, Rect2i(x, 5, 1, 4), c)
				"f": _rect(g, Rect2i(x, 2, 1, 4), c)
				"g": _rect(g, Rect2i(x, 5, 3, 1), c)
		# lit segments win where they cross unlit ones
		for s in on:
			var c2 := "D" if s in "abfg" else "E"
			match s:
				"a": _rect(g, Rect2i(x, 2, 3, 1), c2)
				"b": _rect(g, Rect2i(x + 2, 2, 1, 4), c2)
				"c": _rect(g, Rect2i(x + 2, 5, 1, 4), c2)
				"d": _rect(g, Rect2i(x, 8, 3, 1), c2)
				"e": _rect(g, Rect2i(x, 5, 1, 4), c2)
				"f": _rect(g, Rect2i(x, 2, 1, 4), c2)
				"g": _rect(g, Rect2i(x, 5, 3, 1), c2)
		x += 4
	var pal := {"B": "brass:4", "b": "brass:3", "d": "brass:2", "s": "void:1", "u": "amber:0", "D": "amber:4", "E": "amber:3"}
	return PixelArt.paint(_rows(g), pal, false)


## The revert glyph: a green curled "undo" arrow, 12x12, frames 0-3 a pulse (the arrow
## brightens and a spark runs around the curl).
const REVERT := [
	"...LLLL...",
	"..L3333L..",
	".A3....3L.",
	"AAA.....3L",
	".A......3L",
	"........3L",
	".......3L.",
	".L3...33L.",
	"..L3333L..",
	"...LLLL...",
]
const REVERT_SPARK := [Vector2i(4, 1), Vector2i(8, 3), Vector2i(7, 7), Vector2i(3, 8)]


static func revert_glyph(frame: int) -> Texture2D:
	var f := posmod(frame, 4)
	return _baked("revert_%d" % f, func() -> Image:
		var g := _grid(10, 10)
		_stamp(g, REVERT, Vector2i.ZERO)
		_put(g, REVERT_SPARK[f].x, REVERT_SPARK[f].y, "W")
		var hi := f == 1 or f == 2
		var pal := {"L": "leaf:2" if not hi else "leaf:3", "3": "leaf:3" if not hi else "leaf:4",
			"A": "leaf:4", "W": "leaf:4"}
		return PixelArt.paint(_rows(g), pal))


## A Memory Leak puddle (a slowing hazard): spilled amber, the Leak's own colour, darkest
## in the middle, a lighter rim, a see-through edge and two glints that shift on frame 1.
## Radius 4..16 px; the texture is (2r+2)^2, centred.
static func puddle(radius: int, frame: int) -> Texture2D:
	var r := clampi(radius, 4, 16)
	var f := posmod(frame, 2)
	return _baked("puddle_%d_%d" % [r, f], func() -> Image:
		var s := r * 2 + 2
		var img := PixelArt.blank(s, s)
		var c := Vector2(s / 2.0, s / 2.0)
		var deep := Style.c("amber:1")
		var body := Style.c("amber:2")
		var rim := Style.c("amber:3")
		for j in s:
			for i in s:
				var p := Vector2(i + 0.5, j + 0.5) - c
				var a := p.angle()
				# a blobby edge: a few lobes, fixed per radius
				var edge := r * (1.0 + 0.08 * sin(a * 3.0 + r) + 0.05 * sin(a * 5.0 + r * 2.0))
				var d := p.length()
				if d > edge:
					continue
				# spilled amber, thick like honey: only the outer ring is see-through; a bright
				# meniscus on the lit side, a darker, deeper middle
				var col := body
				var alpha := 0.62
				if d > edge - 1.0:
					col = rim
					alpha = 0.38
				elif d > edge - 2.0:
					var lit := p.y < 0.0 or p.x < 0.0
					col = Style.c("amber:4") if lit else rim
					alpha = 0.72 if lit else 0.62
				elif d < edge * 0.55:
					col = body.lerp(deep, 0.45)
					alpha = 0.66
				img.set_pixel(i, j, Color(col, alpha))
		# glints on the top-left, where the light is
		var g1 := Vector2i(c + Vector2(-r * 0.45, -r * 0.35 + f))
		var g2 := Vector2i(c + Vector2(-r * 0.1 + f * 2, -r * 0.55))
		for q in [g1, g2]:
			if q.x >= 0 and q.y >= 0 and q.x < s - 1 and q.y < s:
				img.set_pixel(q.x, q.y, Color(Style.c("amber:4"), 0.85))
				img.set_pixel(q.x + 1, q.y, Color(Style.c("amber:3"), 0.7))
		return img)


## A Lost Page pickup: a vellum page with ink lines and a folded corner, 10x12. Frames 0-3
## flutter: flat, corner lifting, turning edge-on a little, the other corner.
const PAGE := [
	[
		"44444...",
		"4222433.",
		"4k2k2443",
		"42222223",
		"4kk2kk23",
		"42222223",
		"4kkk2k23",
		"42222223",
		"4k2kk223",
		"33333333",
	],
	[
		"444443..",
		"42222443",
		"4k2k2223",
		"42222223",
		"4kk2kk23",
		"42222223",
		"4kkk2k23",
		"42222223",
		"4k2kk223",
		"3333333.",
	],
	[
		".4444...",
		".422443.",
		".4k2k43.",
		".42222.3",
		".4kk2k3.",
		".42222.3",
		".4kkk23.",
		".42222.3",
		".4k2k23.",
		".333333.",
	],
	[
		"44444...",
		"4222433.",
		"4k2k2443",
		"42222223",
		"4kk2kk23",
		"42222223",
		"4kkk2k23",
		"42222223",
		"4k2kk33.",
		"3333.33.",
	],
]


static func page(frame: int) -> Texture2D:
	var f := posmod(frame, 4)
	return _baked("page_%d" % f, func() -> Image:
		return PixelArt.paint(PackedStringArray(PAGE[f]), {"4": "vellum:4", "3": "vellum:3", "2": "vellum:4", "k": "quill:3"}))


## The Glitch's diff attack, one tile (16 px) tall and `width` px long. add=false: a red "-"
## row (the threat ramp: it IS an enemy attack); add=true: a green "+" row that stays safe.
static func diff_row(width: int, add: bool) -> Texture2D:
	var w := maxi(16, width)
	return _baked("diff_%d_%d" % [w, int(add)], func() -> Image:
		var img := PixelArt.blank(w, 16)
		var ramp := "leaf" if add else "threat"
		var fill := Color(Style.c(ramp + ":1"), 0.45)
		var edge := Color(Style.c(ramp + ":2"), 0.9)
		var glyph := Style.c(ramp + ":3")
		var core := Style.c(ramp + ":4")
		img.fill_rect(Rect2i(0, 1, w, 14), fill)
		img.fill_rect(Rect2i(0, 0, w, 1), edge)
		img.fill_rect(Rect2i(0, 15, w, 1), edge)
		# hatching on the minus row so it reads as danger without its colour
		if not add:
			for x in range(0, w, 4):
				img.set_pixel(x, 1, edge)
				img.set_pixel(x + 1 if x + 1 < w else x, 14, edge)
		# the sign every 16 px, centred in its cell
		var cells := w / 16
		var off := (w - cells * 16) / 2
		for k in cells:
			var x := off + k * 16
			img.fill_rect(Rect2i(x + 4, 7, 8, 2), glyph)
			img.fill_rect(Rect2i(x + 5, 7, 6, 1), core)
			if add:
				img.fill_rect(Rect2i(x + 7, 4, 2, 8), glyph)
				img.fill_rect(Rect2i(x + 7, 5, 1, 6), core)
		return img)
