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


## Copy-Paste: a glitched copy of the hero. Magenta and night palette, and scan-line tears
## (rows shifted sideways) that move from frame to frame.
static func clone_frames() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var src: Array = Hero.frames()
	for i in src.size():
		out.append(PixelArt.cached("bx_clone_%d" % i, func() -> Image:
			var img: Image = (src[i] as Texture2D).get_image()
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
			# scan-line tears: two bands shifted by 2px, position depends on the frame
			var tear := img.duplicate() as Image
			for band in [[6 + i * 3 % 12, 2, 2], [18 + i * 5 % 9, 1, -2]]:
				for j in range(band[0], mini(h, band[0] + band[1])):
					for x in w:
						var sx := x - int(band[2])
						tear.set_pixel(x, j, img.get_pixel(sx, j) if sx >= 0 and sx < w else Color(0, 0, 0, 0))
			return tear))
	return out


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


## D6: an enemy as a rig (design-plan §8: move 4, telegraph 2, attack 2; the hurt flash is the
## shader's, the death is the dissolve plus FxLayer.poof). Built from the same two ART layers:
## the moving layer steps, the body squashes a row to wind up and stretches a row to strike.
static func rig(kind: String) -> RigDef:
	if _rigs.has(kind):
		return _rigs[kind]
	var d: Dictionary = ART[kind]
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
	var eyes: Dictionary = TELE_EYES.get(kind, {})
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
	return ART.has(kind)


static func frame(kind: String, step: int) -> Image:
	var d: Dictionary = ART[kind]
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
