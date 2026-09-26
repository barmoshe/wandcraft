class_name Bestiary
extends RefCounted
## D1: the weaver, ram and sentry palettes are lifted a step so their bodies pass the
## grayscale value test against the floor (tools/artsheet.sh check).
## Enemies and bosses, drawn for 0.4 (decisions/0007). Each enemy is a body layer plus an
## optional second layer (legs, drips, a sprout) so frames animate by moving parts:
##   frame 0: rest      frame 1: the "b" layer offset by "bo" (a step or a squash)
## All sprites face right; the node flips them. Hitboxes stay in Enemy.DEFS (gameplay is
## unchanged by art size).

const ART := {
	"slime": {
		"w": 18, "h": 14,
		"pal": {"1": "toxic:1", "2": "toxic:2", "3": "toxic:3", "4": "toxic:4", "w": "bone:4", "o": "night:0",
			"M": "leaf:3", "m": "leaf:2", "k": "leaf:1"},
		"a": [
			"........Mm........",
			".......MMm........",
			"........k.........",
			".....23333332.....",
			"...233w44444332...",
			"..234ww4444ww432..",
			".2344ww4444ww4432.",
			".2344wo4444wo4432.",
		],
		"b": [
			"234444444444444432",
			"2344444oooo4444432",
			"233444444444444332",
			"122333333333333321",
			".1122222222222211.",
			"..11111111111111..",
		],
		"b_at": Vector2i(0, 8), "a_at": Vector2i(0, 0), "move": "a", "mo": Vector2i(0, 1),
	},
	"weaver": {
		"w": 22, "h": 16,
		"pal": {"1": "violet:2", "2": "violet:3", "3": "violet:4", "4": "bone:4", "r": "blood:2", "R": "blood:4",
			"o": "night:0", "L": "violet:1", "l": "violet:2", "g": "glitch:3", "G": "glitch:4"},
		"a": [
			".......1222221........",
			".....12233333221......",
			"....1223334rrr321.....",
			"....123334rRRRr321....",
			"....12333rRRoRRr21....",
			"....12333rRRoRRr21....",
			"....123334rRRRr321....",
			"....1223334rrr321.....",
			".....1223gGg32211.....",
			"......112g2g2211......",
			".......11111111.......",
		],
		"b": [
			"..ll..............ll..",
			".l..l............l..l.",
			"l....ll........ll....l",
			"L...l..L......L..l...L",
			"L..L....L....L....L..L",
			".L.L............L..L..",
			"L...L..........L....L.",
			"L...............L...L.",
		],
		"b_at": Vector2i(0, 6), "a_at": Vector2i(0, 2), "move": "b", "mo": Vector2i(0, -1),
		"b_under": true,
	},
	"ram": {
		"w": 23, "h": 16,
		"pal": {"1": "wood:1", "2": "wood:2", "3": "wood:3", "4": "wood:4", "T": "leaf:3", "t": "leaf:2", "u": "leaf:1",
			"W": "bone:4", "V": "bone:2", "r": "ember:4", "n": "rose:2", "k": "stone:1", "e": "wood:0"},
		"a": [
			"....T.....T.....T......",
			"...TT....TT....TT......",
			"..uTTu..uTTu..uTTu.....",
			".233333333333333332....",
			"23444444444444444322...",
			"234444444444444443322e.",
			"2344444444444444433222e",
			"23444444444444444322r22",
			"233444444444444443222nn",
			"2233444444444444332222n",
			".22333333333333322VWW..",
			"..222222222222222..VW..",
			"...1111111111111.......",
		],
		"b": [
			"...kk...kk.....kk..kk..",
			"...kk...kk.....kk..kk..",
			"..kkk..kkk....kkk.kkk..",
		],
		"b1": [
			"....kk...kk...kk..kk...",
			"....kk..kk.....kk..kk..",
			"...kkk.kkk.....kkk.kkk.",
		],
		"b_at": Vector2i(0, 13), "a_at": Vector2i(0, 0), "move": "b", "mo": Vector2i.ZERO,
	},
	"bugling": {
		"w": 14, "h": 11,
		"pal": {"1": "glitch:1", "2": "glitch:2", "3": "glitch:3", "4": "glitch:4", "w": "#ffffff",
			"c": "cyan:3", "C": "cyan:4", "o": "night:0", "k": "violet:2"},
		"a": [
			".........C..C.",
			"..........cc..",
			"...222222.33..",
			"..23344w323o3.",
			".234444323333.",
			".2344443233...",
			".233333222....",
			"..1111111.....",
		],
		"b": [
			".k..k..k..k...",
			"k..k..k..k....",
			"..............",
		],
		"b1": [
			"k..k..k..k....",
			".k..k..k..k...",
			"..............",
		],
		"b_at": Vector2i(0, 8), "a_at": Vector2i(0, 0), "move": "b", "mo": Vector2i.ZERO,
	},
	"puffcap": {
		"w": 16, "h": 17,
		"pal": {"1": "rose:1", "2": "rose:2", "3": "rose:3", "4": "rose:4", "W": "bone:4",
			"s": "bone:3", "S": "bone:2", "o": "night:0", "n": "blood:2", "l": "wood:1"},
		"a": [
			".....222222.....",
			"...2234433322...",
			"..23WW44443WW2..",
			".234WW44444WW32.",
			".2344444WW44432.",
			"23444444WW444432",
			"2333333333333332",
			".11.11111111.11.",
			".....SssssS.....",
			".....SsosoS.....",
			".....SssssS.....",
			".....SsnnsS.....",
			".....SsssSS.....",
		],
		"b": [
			"....ll....ll....",
			"...lll....lll...",
		],
		"b1": [
			".....ll..ll.....",
			"....lll..lll....",
		],
		"b_at": Vector2i(0, 13), "a_at": Vector2i(0, 0), "move": "a", "mo": Vector2i(0, 1),
	},
	"sentry": {
		"w": 16, "h": 17,
		"pal": {"1": "steel:1", "2": "steel:2", "3": "steel:3", "4": "steel:4", "r": "ember:2", "R": "ember:3",
			"y": "ember:4", "w": "#fff4e0", "m": "moss:3"},
		"a": [
			"......1111......",
			"....11222211....",
			"...1223333221...",
			"..122333333221..",
			"..12333333332...",
			"..12233333322...",
			"...1223333221...",
			"..11112222111m..",
			"..12333333332m..",
			"...123433321....",
			"...122333221....",
			"..m1223333221...",
			".11222222222211.",
			".11111111111111.",
		],
		"b": [
			".rRRRr..",
			"rRywyRr.",
			".rRRRr..",
		],
		"b1": [
			".rrrrr..",
			"rRRyRRr.",
			".rrrrr..",
		],
		"b_at": Vector2i(4, 3), "a_at": Vector2i(0, 0), "move": "b", "mo": Vector2i.ZERO,
	},
	"golem": {
		"w": 20, "h": 15,
		"pal": {"1": "wood:1", "2": "wood:2", "3": "wood:3", "4": "wood:4", "y": "gold:4", "M": "moss:3", "m": "moss:2",
			"S": "stone:4", "s": "stone:3"},
		"a": [
			"......MMmm..........",
			".....2333322........",
			"...223444443322.....",
			"..2344y44y444432....",
			"..234444444444432...",
			".sSSS2344444432SSSs.",
			"sSSSSS23444432SSSSSs",
			"sSSSS2334444332SSSSs",
			".sSS.2344444432.SSs.",
			"..s..2344444432..s..",
			".....2334444332.....",
			".....1223333221.....",
			"......11222211......",
		],
		"b": [
			"..2222....2222..",
			"..1111....1111..",
		],
		"b1": [
			".2222......2222.",
			".1111......1111.",
		],
		"b_at": Vector2i(2, 13), "a_at": Vector2i(0, 0), "move": "b", "mo": Vector2i.ZERO,
	},
	"wisp": {
		"w": 12, "h": 14,
		"pal": {"3": "glitch:3", "4": "glitch:4", "w": "#ffffff", "b": "bone:3", "c": "glitch:2", "C": "glitch:4"},
		"a": [
			".....3......",
			"....343.....",
			"....3w3.....",
			"...34w43....",
			"..bbbbbbb...",
			"..b.cwc.b...",
			"..b.cwc.b...",
			"..b.cCc.b...",
			"..bbbbbbb...",
			"....bbb.....",
		],
		"b": [
			"..c.c.",
			".c...c",
			"c.....",
		],
		"b1": [
			".c.c..",
			"c...c.",
			".....c",
		],
		"b_at": Vector2i(3, 10), "a_at": Vector2i(0, 0), "move": "a", "mo": Vector2i(0, 1),
	},
	"stump": {
		"w": 18, "h": 11,
		"pal": {"1": "wood:1", "2": "wood:2", "3": "wood:3", "4": "sand:3", "o": "night:0", "g": "glitch:4", "m": "moss:3"},
		"a": [
			"...mm....m........",
			"..233333333332....",
			".23444444444432...",
			".2344o44o44o432...",
			".23444444444432...",
			".2334g44444g432...",
			".2333333333332....",
			"..2222222222222...",
			".122222222222221..",
		],
		"b": [
			"1.1..1....1..1.1",
			"..1..........1..",
		],
		"b1": [
			".1.1.1....1.1.1.",
			"..1..........1..",
		],
		"b_at": Vector2i(1, 9), "a_at": Vector2i(0, 0), "move": "b", "mo": Vector2i.ZERO,
	},
	"tick": {
		"w": 10, "h": 8,
		"pal": {"2": "violet:3", "3": "violet:4", "w": "#ffffff", "g": "glitch:3", "G": "glitch:4", "k": "violet:2"},
		"a": [
			"...2222...",
			"..233332..",
			".23w33w32.",
			".23333332.",
			".22gGGg22.",
			"..222222..",
		],
		"b": [
			"k.k..k.k..",
			".k.k..k.k.",
		],
		"b1": [
			".k.k..k.k.",
			"k.k..k.k..",
		],
		"b_at": Vector2i(0, 6), "a_at": Vector2i(0, 0), "move": "b", "mo": Vector2i.ZERO,
	},
	"slimelet": {
		"w": 11, "h": 7,
		"pal": {"1": "toxic:1", "2": "toxic:2", "3": "toxic:3", "4": "toxic:4", "w": "bone:4", "o": "night:0"},
		"a": [
			"...2333....",
			"..234w43...",
			".2344o432..",
			".23444432..",
		],
		"b": [
			".12333321..",
			"..111111...",
		],
		"b_at": Vector2i(0, 4), "a_at": Vector2i(0, 0), "move": "a", "mo": Vector2i(0, 1),
	},
	"loop_seg": {
		"w": 14, "h": 12,
		"pal": {"1": "leaf:1", "2": "leaf:2", "3": "leaf:3", "4": "leaf:4", "y": "gold:3", "Y": "gold:4", "w": "#fffbe0"},
		"a": [
			"....222222....",
			"..2233443322..",
			".233444444332.",
			".234yyyyyy432.",
			"2344yYwwYy4432",
			"2344yYYYYy4432",
			"2334yyyyyy4332",
			".233344443332.",
			".223333333322.",
			"..2222222222..",
			"....111111....",
		],
		"b": [],
		"b_at": Vector2i.ZERO, "a_at": Vector2i.ZERO, "move": "a", "mo": Vector2i(0, 1),
	},
}


## Design v3: the Garbage Collector, a hulking bin on treads (32x30, facing the camera).
## `open`: its lid lifted and its maw glowing (the Collect move).
static func collector(open: bool, f := 0) -> Texture2D:
	return PixelArt.cached("collector_%d_%d" % [int(open), f], func() -> Image:
		var w := 32
		var h := 30
		var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		var ink := Style.c("night:0")
		# a green dumpster: it pops off the stone floor (grey steel sank into it)
		var steel := [Style.c("leaf:1"), Style.c("leaf:2"), Style.c("leaf:3"), Style.c("leaf:4")]
		var moss := Style.c("moss:2")
		# the body: a steel box, lit top-left, dark bottom-right, with rivets and a dent
		var top := 10
		img.fill_rect(Rect2i(2, top, w - 4, h - top - 5), steel[1])
		img.fill_rect(Rect2i(3, top + 1, w - 7, 1), steel[3])
		img.fill_rect(Rect2i(3, top + 1, 1, h - top - 8), steel[2])
		img.fill_rect(Rect2i(w - 4, top + 1, 1, h - top - 7), steel[0])
		for x in [5, 13, 21, 27]:
			img.set_pixel(x, top + 3, steel[3])
			img.set_pixel(x, h - 9, steel[3])
		img.fill_rect(Rect2i(6, h - 12, 20, 1), steel[0])
		# moss and grime creeping up from the bottom
		for x in range(3, w - 3, 3):
			img.fill_rect(Rect2i(x, h - 8, 2, 2), moss)
		# the eyes: two gold slits (bright on the flicker frame)
		var eye := Style.c("gold:4") if f == 0 else Style.c("gold:3")
		img.fill_rect(Rect2i(9, top + 6, 4, 2), eye)
		img.fill_rect(Rect2i(19, top + 6, 4, 2), eye)
		# the lid: closed, a slab on top; open, tilted back with a glowing maw below
		if open:
			img.fill_rect(Rect2i(4, 0, w - 8, 3), steel[2])
			img.fill_rect(Rect2i(4, 0, w - 8, 1), steel[3])
			img.fill_rect(Rect2i(4, 3, w - 8, 1), ink)
			img.fill_rect(Rect2i(4, top - 5, w - 8, 5), Style.c("toxic:2"))
			img.fill_rect(Rect2i(6, top - 4, w - 12, 3), Style.c("toxic:4"))
		else:
			img.fill_rect(Rect2i(1, top - 4, w - 2, 4), steel[2])
			img.fill_rect(Rect2i(1, top - 4, w - 2, 1), steel[3])
			img.fill_rect(Rect2i(1, top - 1, w - 2, 1), ink)
			img.fill_rect(Rect2i(12, top - 6, 8, 2), steel[1])
		# treads
		img.fill_rect(Rect2i(1, h - 5, w - 2, 4), Style.c("night:2"))
		for x in range(2 + f, w - 2, 4):
			img.fill_rect(Rect2i(x, h - 4, 2, 2), Style.c("steel:1"))
		img.fill_rect(Rect2i(1, h - 1, w - 2, 1), ink)
		return img)


## Design v3: the Infinite Loop's body is a chain of code blocks: a dark rounded block with a
## lit top edge and a glowing glyph ({ } ; = 0 1), 18x16. `f` 1 is the glyph's flicker frame.
const CODE_GLYPHS := [
	[".##", "#..", ".#.", "#..", ".##"],   # {
	["##.", "..#", ".#.", "..#", "##."],   # }
	[".#.", "...", ".#.", ".#.", "#.."],   # ;
	["...", "###", "...", "###", "..."],   # =
	[".#.", "#.#", "#.#", "#.#", ".#."],   # 0
	[".#.", "##.", ".#.", ".#.", "###"],   # 1
]


static func code_block(k: int, f := 0) -> Texture2D:
	return PixelArt.cached("code_block_%d_%d" % [k, f], func() -> Image:
		var w := 18
		var h := 16
		var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		var ink := Style.c("night:0")
		var body := Style.c("night:3")
		var rim := Style.c("leaf:2")
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var corner := (x == 1 or x == w - 2) and (y == 1 or y == h - 2)
				if not corner:
					img.set_pixel(x, y, body)
		# outline, a lit top-left edge (the art's light) and a dark bottom lip
		for x in range(2, w - 2):
			img.set_pixel(x, 0, ink)
			img.set_pixel(x, h - 1, ink)
			img.set_pixel(x, 2, rim.lerp(Style.c("leaf:4"), 0.4))
			img.set_pixel(x, h - 3, Style.c("night:1"))
		for y in range(2, h - 2):
			img.set_pixel(0, y, ink)
			img.set_pixel(w - 1, y, ink)
			img.set_pixel(2, y, rim)
		img.set_pixel(1, 1, ink)
		img.set_pixel(w - 2, 1, ink)
		img.set_pixel(1, h - 2, ink)
		img.set_pixel(w - 2, h - 2, ink)
		# the glyph, centred, bright green; on the flicker frame a scanline cuts it
		var g: Array = CODE_GLYPHS[posmod(k, CODE_GLYPHS.size())]
		for j in 5:
			for i in 3:
				if String(g[j])[i] == "#":
					var c := Style.c("toxic:4") if not (f == 1 and j == 2) else Style.c("toxic:2")
					img.fill_rect(Rect2i(6 + i * 2, 3 + j * 2, 2, 2), c)
		return img)


## The Loop's head (a serpent, facing right): frame 0 closed, frame 1 jaw open (telegraph).
const LOOP_HEAD := {
	"pal": {"1": "leaf:1", "2": "leaf:2", "3": "leaf:3", "4": "leaf:4", "y": "gold:3", "Y": "gold:4",
		"o": "night:0", "m": "blood:1", "M": "blood:2", "W": "bone:4", "V": "bone:3", "c": "toxic:3"},
	"top": [
		"......222222............",
		"....2233443322..........",
		"...233444444433222......",
		"..23444c44c444443332....",
		".2344444444444444433322.",
		"234yyy444444444444444332",
		"234yYoy44444444444444433",
		"234yyy44444444444444433.",
		"2334444444444444444332..",
	],
	"jaw": [
		"2333444444433332WV.W.V..",
		".22333333333322222......",
		"..222222222222..........",
	],
	"jaw_open": [
		"23334444444mmmmmmmm.....",
		".2233333MMMMMMMM........",
		"..2233333333332WV.W.V...",
		"...222222222222222......",
	],
}


static func loop_head(open: bool) -> Texture2D:
	return PixelArt.cached("bx_loop_head_%d" % int(open), func() -> Image:
		var d := LOOP_HEAD
		return PixelArt.layered(24, 14, [[d["top"], Vector2i(0, 0)], [d["jaw_open"] if open else d["jaw"], Vector2i(0, 9)]], d["pal"]))


## D6: the Infinite Loop's head as a rig: chomp while it laps, rear up and glow while it
## winds up, gape while it acts, and roar (a one-shot) on a phase change.
static func loop_rig() -> RigDef:
	if _rigs.has("loop_head"):
		return _rigs["loop_head"]
	var d := LOOP_HEAD
	var r := RigDef.new()
	r.id = "loop_head"
	r.w = 24
	r.h = 14 + HEADROOM
	r.pal = d["pal"]
	r.add_part("jaw", d["jaw"], Vector2i(0, 9 + HEADROOM))
	r.add_part("top", d["top"], Vector2i(0, HEADROOM))
	var hot := {"y": "threat:3", "Y": "threat:4", "c": "threat:4"}
	var gape := {"rows": d["jaw_open"]}
	r.add_clip("chomp", 6.0, true, [{}, {"jaw": Vector2i(0, 1)}, {"jaw": gape}, {"jaw": Vector2i(0, 1)}])
	r.add_clip("tele", 10.0, true, [
		{"jaw": gape, "top": Vector2i(0, -1), "_recolor": hot},
		{"jaw": gape, "top": Vector2i(0, -2), "_recolor": hot},
	])
	r.add_clip("act", 8.0, true, [{"jaw": gape}, {"jaw": {"rows": d["jaw_open"], "off": Vector2i(0, 1)}}])
	r.add_clip("roar", 8.0, false, [
		{"jaw": gape, "top": Vector2i(0, -1)},
		{"jaw": {"rows": d["jaw_open"], "off": Vector2i(0, 1)}, "top": Vector2i(0, -2), "_recolor": hot},
		{"jaw": {"rows": d["jaw_open"], "off": Vector2i(0, 1)}, "top": Vector2i(0, -2)},
		{"jaw": gape, "top": Vector2i(0, -1), "_recolor": hot},
	])
	_rigs["loop_head"] = r
	return r


## One head frame pre-rotated to 16 headings (index k points along TAU * k / 16). Headings
## that point left use the frame flipped upside down first, so the head never swims on its
## back. Baked on first use and kept.
static func loop_head_views(clip: String, i: int) -> Array[Texture2D]:
	var key := "%s_%d" % [clip, i]
	if _views.has(key):
		return _views[key]
	var src := (clips_of(loop_rig())[clip][i] as Texture2D).get_image()
	var flipped := src.duplicate() as Image
	flipped.flip_y()
	var piv := Vector2(src.get_width() / 2.0, src.get_height() / 2.0)
	var up := RigBaker.rotations(src, piv, 16)
	var down := RigBaker.rotations(flipped, piv, 16)
	var out: Array[Texture2D] = []
	for k in 16:
		out.append(PixelArt.tex(down[k] if cos(TAU * k / 16.0) < -0.01 else up[k]))
	_views[key] = out
	return out


## Baked clips of any rig, cached by rig id.
static func clips_of(r: RigDef) -> Dictionary:
	if not _clips.has(r.id):
		_clips[r.id] = RigBaker.bake(r)
	return _clips[r.id]


## Copy-Paste: a glitched copy of the hero. Magenta and night palette, and scan-line tears
## (rows shifted sideways) that move from frame to frame.
static func clone_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var src: Array = Hero.frames()
	for i in src.size():
		out.append(PixelArt.cached("bx_clone_%d" % i, func() -> Image: return glitch((src[i] as Texture2D).get_image(), i)))
	return out


## D6: every hero clip, glitched (Copy-Paste moves with the hero's own rig).
static func clone_clips() -> Dictionary:
	if _clips.has("clone"):
		return _clips["clone"]
	var out := {}
	var src := Hero.clips(false)
	for k in src:
		var fr: Array[Texture2D] = []
		for i in (src[k] as Array).size():
			var tex: Texture2D = src[k][i]
			fr.append(PixelArt.cached("bx_clone_%s_%d" % [k, i], func() -> Image: return glitch(tex.get_image(), i)))
		out[k] = fr
	_clips["clone"] = out
	return out


## The Copy-Paste look: the glitch and night ramps by brightness, cyan-white highlights, and
## two scan-line tears whose rows depend on `i`, so the tears move from frame to frame.
static func glitch(src_img: Image, i: int) -> Image:
	var img := src_img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var ramp_hi: Array = Style.RAMPS["glitch"]
	var ramp_lo: Array = Style.RAMPS["night"]
	for j in h:
		for x in w:
			var c := img.get_pixel(x, j)
			if c.a == 0.0:
				continue
			var v := c.get_luminance()
			var nc := Color(ramp_hi[clampi(int(v * 5.0) + 1, 1, 4)])
			if v < 0.12:
				nc = Color(ramp_lo[3])
			if v > 0.8:
				nc = Color("#dffcff")   # highlights go cyan-white
			img.set_pixel(x, j, Color(nc.r, nc.g, nc.b, c.a))
	return RigBaker.tear(img, [[6 + i * 3 % 12, 2, 2], [18 + i * 5 % 9, 1, -2]])


## D6: what each enemy's eyes turn into while it winds up an attack. Telegraphs are enemy
## attacks, so they take the reserved threat ramp (the only place it appears on a body).
const TELE_EYES := {
	"slime": {"o": "threat:3"}, "slimelet": {"o": "threat:3"},
	"weaver": {"r": "threat:3", "R": "threat:4"},
	"ram": {"r": "threat:4"},
	"bugling": {"c": "threat:3", "C": "threat:4"},
	"puffcap": {"o": "threat:3"},
	"sentry": {"r": "threat:2", "R": "threat:3", "y": "threat:4"},
	"golem": {"y": "threat:4"},
	"wisp": {"w": "threat:4", "C": "threat:3"},
	"stump": {"o": "threat:3", "g": "threat:4"},
	"tick": {"g": "threat:3", "G": "threat:4"},
	"loop_seg": {"y": "threat:3", "Y": "threat:4"},
}
## Rows of empty sky above every rig, so a stretch never clips the top of the head.
const HEADROOM := 2

static var _rigs := {}
static var _clips := {}
static var _views := {}


## D6: an enemy as a rig (design-plan §8: move 4, telegraph 2, attack 2; the hurt flash is the
## shader's, the death is the dissolve plus FxLayer.poof). Built from the same two ART layers:
## the moving layer steps, the body squashes a row to wind up and stretches a row to strike.
## Design v3: the Corrupted Grove's enemies are variants: a base drawing under a new palette
## (their rules are their own, in Enemy.DEFS).
const VARIANTS := {
	"rot_weaver": ["weaver", {"1": "cyan:1", "2": "cyan:2", "3": "cyan:3", "L": "night:3", "l": "cyan:1", "g": "toxic:3", "G": "toxic:4"}],
	"blink_tick": ["tick", {"2": "cyan:2", "3": "cyan:3", "k": "cyan:1", "g": "gold:3", "G": "gold:4"}],
	"thorn_ram": ["ram", {"1": "violet:1", "2": "violet:2", "3": "violet:3", "4": "violet:4", "T": "glitch:3", "t": "glitch:2", "u": "glitch:1", "e": "night:1"}],
}


## A kind's drawing: its own, or its base's under the variant palette.
static func def_of(kind: String) -> Dictionary:
	if ART.has(kind):
		return ART[kind]
	var v: Array = VARIANTS[kind]
	var d: Dictionary = (ART[v[0]] as Dictionary).duplicate()
	var pal: Dictionary = (d["pal"] as Dictionary).duplicate()
	pal.merge(v[1], true)
	d["pal"] = pal
	return d


static func rig(kind: String) -> RigDef:
	if _rigs.has(kind):
		return _rigs[kind]
	var d: Dictionary = def_of(kind)
	var r := RigDef.new()
	r.id = "en_" + kind
	r.w = d["w"]
	r.h = int(d["h"]) + HEADROOM
	r.pal = d["pal"]
	var down := Vector2i(0, HEADROOM)
	if d.get("b_under", false):
		r.add_part("b", d["b"], d["b_at"] + down)
		r.add_part("a", d["a"], d["a_at"] + down)
	else:
		r.add_part("a", d["a"], d["a_at"] + down)
		r.add_part("b", d["b"], d["b_at"] + down)
	var mover: String = d["move"]
	var mo: Vector2i = d["mo"]
	var step := {mover: mo}
	var step2 := {mover: mo}
	if d.has("b1"):
		step["b"] = {"rows": d["b1"], "off": mo if mover == "b" else Vector2i.ZERO}
		step2 = {"a": {"sq": 1}}
	else:
		step2 = {mover: mo, "a": {"sq": 1, "off": mo if mover == "a" else Vector2i.ZERO}}
	r.add_clip("move", 6.0, true, [{}, step, {}, step2])
	var eyes: Dictionary = TELE_EYES.get(kind, TELE_EYES.get(VARIANTS[kind][0], {}) if VARIANTS.has(kind) else {})
	r.add_clip("tele", 8.0, true, [
		{"a": {"sq": 1}, "_recolor": eyes},
		{"a": {"sq": 2}, "_recolor": eyes},
	])
	r.add_clip("attack", 10.0, false, [
		{"a": {"sq": -1}, "_recolor": eyes},
		{"a": {"sq": -1, "off": Vector2i(1, 0)}},
	])
	_rigs[kind] = r
	return r


static func clips(kind: String) -> Dictionary:
	if not _clips.has(kind):
		_clips[kind] = RigBaker.bake(rig(kind))
	return _clips[kind]


static func has(kind: String) -> bool:
	return ART.has(kind) or VARIANTS.has(kind)


static func frame(kind: String, step: int) -> Image:
	var d: Dictionary = def_of(kind)
	var off_a: Vector2i = d["a_at"]
	var off_b: Vector2i = d["b_at"]
	if step == 1:
		if d["move"] == "a":
			off_a += d["mo"]
		else:
			off_b += d["mo"]
	var rows_b: Array = d["b1"] if step == 1 and d.has("b1") else d["b"]
	var layers := []
	if d.get("b_under", false):
		layers.append([rows_b, off_b])
		layers.append([d["a"], off_a])
	else:
		layers.append([d["a"], off_a])
		layers.append([rows_b, off_b])
	return PixelArt.layered(d["w"], d["h"], layers, d["pal"])


## The move clip (first frame at rest), for callers that only need a look.
static func frames(kind: String) -> Array[Texture2D]:
	return clips(kind)["move"]
