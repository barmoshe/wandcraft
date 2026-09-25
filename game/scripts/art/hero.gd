class_name Hero
extends RefCounted
## The hero, drawn for 0.4 (decisions/0007): a hipster mage. Tall and slim: a swept-up
## quiff, teal shades, a full dark beard, a bright yellow shirt with a red tie and teal
## suspenders, rolled sleeves, slim red trousers and dark shoes. Original pixels, drawn
## in the spirit of a reference Bar picked (2026-09-24). 20x36, built from parts (head,
## body, legs) so frames animate by moving parts. Faces right; the node flips it for
## left. Style ramps only.

const PAL := {
	# hair (near-black with a cool sheen)
	"h": "slate:1", "H": "slate:3",
	# face, shades, beard
	"S": "skin:2", "s": "skin:3", "z": "skin:4", "n": "skin:2",
	"o": "night:0", "G": "cyan:2", "g": "cyan:4",
	"B": "slate:1", "m": "rose:1",
	# shirt, collar, tie, suspenders, cuffs, belt
	"Y": "gold:3", "w": "gold:4", "y": "gold:2", "c": "bone:4", "T": "blood:2", "t": "blood:3",
	"Q": "cyan:2", "k": "gold:2", "L": "wood:1",
	# trousers and shoes
	"P": "blood:2", "p": "blood:3", "K": "night:2", "l": "night:1",
}

const W := 20
const H := 36

const HEAD := [
	"...........Hh.......",
	"..........HHhh.h....",
	"......hhhHHhhhhh....",
	".....hHHhhhhhhhhh...",
	".....hhhhhhhhhhh....",
	".....hSssssssssh....",
	".....hssssssssss....",
	".....ooooooooooo....",
	".....oGgGGoGgGGo....",
	".....soGGosoGGos....",
	".....sssssnsssss....",
	".....BsBBBBBBBsB....",
	".....BBBBmmmBBBB....",
	".....BBBBBBBBBBB....",
	"......BBBBBBBBB.....",
	".......BBBBBBB......",
]

const BODY := [
	".....YYQYcccYQy.....",
	"...YYwYQYYTYYQyyy...",
	"...YYwYQYYTYYQyyy...",
	"...YYwYQYYtYYQyyy...",
	"...kkwYQYYTYYQykk...",
	"...ssYYQYYTYYQyss...",
	"...ssYYQYYtYYQyss...",
	"...ssYYQYYTYYQyss...",
	"...SsLLLLLkLLLLsS...",
]

## Legs: idle and a 4-step walk cycle.
const FEET := [
	[
		".....PPPPPPPPPP.....",
		".....PpPPPPpPPP.....",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......PPP..PPP......",
		"......KKKK.KKKK.....",
		"......llll.llll.....",
	],
	[
		".....PPPPPPPPPP.....",
		".....pPPPPPPpPP.....",
		".....pPP....pPP.....",
		".....pPP....pPP.....",
		".....pPP....pPP.....",
		".....pPP....pPP.....",
		".....pPP....pPP.....",
		".....pPP....PPP.....",
		".....PPP....KKKK....",
		".....KKKK...llll....",
		".....llll...........",
	],
	[
		".....PPPPPPPPPP.....",
		".....PpPPPPpPPP.....",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......PPP..PPP......",
		"......KKKK.KKKK.....",
		"......llll.llll.....",
	],
	[
		".....PPPPPPPPPP.....",
		".....PPpPPpPPPP.....",
		".......pPPpPP.......",
		".......pPPpPP.......",
		".......pPPpPP.......",
		".......pPPpPP.......",
		".......pPPpPP.......",
		".......PPPpPP.......",
		".......KKKPPP.......",
		".......lllKKKK......",
		"..........llll......",
	],
	[
		".....PPPPPPPPPP.....",
		".....PpPPPPpPPP.....",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......pPP..pPP......",
		"......PPP..PPP......",
		"......KKKK.KKKK.....",
		"......llll.llll.....",
	],
]


## D6: the back view, for aiming up (hair, ears, the beard's edge; suspenders cross).
const HEAD_BACK := [
	"...........Hh.......",
	"..........HHhh.h....",
	"......hhhHHhhhhh....",
	".....hHHhhhhhhhhh...",
	".....hhhhhhhhhhh....",
	".....hhhhHhhhhhh....",
	".....hhHhhhhhhhh....",
	".....hhhhhhhhhhh....",
	".....shhhhhhhhhs....",
	".....shhhhhhhhhs....",
	".....BhhhhhhhhhB....",
	".....BBsssssssBB....",
	".....BBBsssssBBB....",
	"......BBBsssBBB.....",
	".......BBsssBB......",
	"........sssss.......",
]

const BODY_BACK := [
	".....YYYcccYYYy.....",
	"...YYwQYYYYYYQyyy...",
	"...YYwYQYYYYQYyyy...",
	"...YYwYYQYYQYYyyy...",
	"...kkwYYYQQYYYykk...",
	"...ssYYYYQQYYYyss...",
	"...ssYYYQYYQYYyss...",
	"...ssYYQYYYYQYyss...",
	"...SsLLLLLLLLLLsS...",
]

## The wand hand, shown only while casting (the fire frame adds a gold smear behind it).
const HAND := ["...............Yss", "...............ysz"]
const HAND_FIRE := [".............wwYsss", "...............yssz"]

## Legs: the 11-row stamps above, by name.
const L_IDLE := 0
const L_STRIDE := 1
const L_PASS := 3

static var _rigs := {}
static var _wand: Array[Texture2D] = []


## The hero as a rig (design-plan §8: idle 4, run 6, cast 3, dash 4, hurt 2, death 6 per
## facing). The quiff lags the head by a frame; bobs and squashes are whole pixel rows.
static func rig(back := false) -> RigDef:
	var key := "back" if back else "front"
	if _rigs.has(key):
		return _rigs[key]
	var head: Array = HEAD_BACK if back else HEAD
	var r := RigDef.new()
	r.id = "hero_" + key
	r.w = W
	r.h = H
	r.pal = PAL
	r.add_part("legs", FEET[L_IDLE], Vector2i(0, 25))
	r.add_part("torso", BODY_BACK if back else BODY, Vector2i(0, 16))
	r.add_part("hair", head.slice(0, 5) + [head[4]], Vector2i.ZERO)
	r.add_part("face", head.slice(5), Vector2i(0, 5))
	# from behind, the wand hand is hidden by the body
	r.add_part("hand", HAND, Vector2i(0, 19), true)
	r.lag = {"hair": "face"}
	var down := Vector2i(0, 1)
	var stride: Array = FEET[L_STRIDE]
	var passing: Array = FEET[L_PASS]
	var show := not back
	r.add_clip("idle", 4.0, true, [
		{},
		{"torso": down, "face": down},
		{"torso": down, "face": down},
		{},
	])
	r.add_clip("run", 12.0, true, [
		{"legs": {"rows": stride}},
		{"legs": {"rows": stride, "sq": 1}, "torso": down, "face": down},
		{"legs": {"rows": passing}},
		{"legs": {"rows": stride}},
		{"legs": {"rows": stride, "sq": 1}, "torso": down, "face": down},
		{"legs": {"rows": FEET[L_IDLE]}},
	])
	r.add_clip("cast", 25.0, false, [
		{"torso": Vector2i(-1, 0), "face": Vector2i(-1, 0), "hand": {"off": Vector2i(-1, 0), "show": show}},
		{"torso": Vector2i(1, 0), "face": Vector2i(1, 0), "hand": {"off": Vector2i(1, 0), "rows": HAND_FIRE, "show": show}},
		{"hand": {"show": show}},
	])
	r.add_clip("dash", 20.0, false, [
		{"legs": {"sq": 1}, "torso": down, "face": down},
		{"legs": {"rows": stride}, "torso": Vector2i(1, 0), "face": Vector2i(2, 0)},
		{"legs": {"rows": stride}, "torso": Vector2i(1, -1), "face": Vector2i(2, -1)},
		{"legs": {"rows": passing}, "torso": Vector2i(1, 0), "face": Vector2i(1, 0)},
	])
	r.add_clip("hurt", 10.0, false, [
		{"_all": Vector2i(-1, 0), "face": Vector2i(-1, 0)},
		{"_all": Vector2i(-1, 0)},
	])
	# the hero "crashes": knees buckle, the body folds, then it tears and crumbles to pixels
	var torn := [[10, 2, 2], [22, 1, -2]]
	r.add_clip("death", 8.0, false, [
		{"_all": Vector2i(-1, 0), "face": Vector2i(-1, 0)},
		{"legs": {"sq": 2}, "torso": Vector2i(0, 2), "face": Vector2i(0, 2)},
		{"legs": {"sq": 4}, "torso": Vector2i(0, 4), "face": Vector2i(1, 5)},
		{"legs": {"sq": 6}, "torso": {"off": Vector2i(0, 6), "sq": 2}, "face": Vector2i(1, 9), "_tear": torn},
		{"legs": {"sq": 6}, "torso": {"off": Vector2i(0, 6), "sq": 2}, "face": Vector2i(1, 9), "_tear": torn, "_crumble": 0.45},
		{"legs": {"sq": 6}, "torso": {"off": Vector2i(0, 6), "sq": 2}, "face": Vector2i(1, 9), "_tear": torn, "_crumble": 0.8},
	])
	_rigs[key] = r
	return r


## Every clip of one facing, baked: clip name -> Array[Texture2D].
static func clips(back := false) -> Dictionary:
	return RigBaker.bake(rig(back))


## idle0, idle1, run0..3, cast (the pre-D6 order, kept for the title screen and art sheets).
static func frames() -> Array[Texture2D]:
	var c := clips()
	var run: Array = c["run"]
	return [c["idle"][0], c["idle"][1], run[0], run[1], run[3], run[4], c["cast"][1]]


## The held wand pre-rotated to 16 angles (design-plan §7), pivot at the grip: index k
## points along TAU * k / 16. Drawn centred on the hand.
static func wand_angles() -> Array[Texture2D]:
	if _wand.is_empty():
		# the grip is the outlined sprite's pixel (1, 2)
		for img in RigBaker.rotations(Sprites.wand_texture().get_image(), Vector2(1.5, 2.5), 16):
			_wand.append(PixelArt.tex(img))
	return _wand
