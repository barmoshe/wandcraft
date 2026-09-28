class_name Hero
extends RefCounted
## The hero, drawn for 0.4 (decisions/0007): a hipster mage. Tall and slim: a swept-up
## quiff, teal shades, a full dark beard, a bright yellow shirt with a red tie and teal
## suspenders, rolled sleeves, slim red trousers and dark shoes. Original pixels, drawn
## in the spirit of a reference Bar picked (2026-09-24). 20x36, built from parts (head,
## body, legs) so frames animate by moving parts. Faces right; the node flips it for
## left. Style ramps only. 0.19: that is the Apprentice; the Pyromancer and the Tinkerer
## wear their own looks on the same rig (LOOKS).

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

## 0.19: each hero has its own look. A look is palette overrides (Style ramp keys, merged
## over PAL) plus optional replacement rows for the head and the torso, front and back, with
## the same row counts and widths as HEAD, HEAD_BACK, BODY and BODY_BACK, so every pose and
## clip fits every hero. The legs and the wand hand are shared and take the look's colours
## (the hand's sleeve is "Y", the cast smear is "w"). The apprentice is PAL as drawn.
const LOOKS := {
	&"apprentice": {},
	# a flame quiff, gold goggles with smoked lenses, a pointed goatee; a dark red shirt
	# with flames licking up from the hem, an ember sash, charcoal trousers
	&"pyromancer": {
		"pal": {
			"h": "ember:2", "H": "ember:3", "F": "ember:4",
			"O": "gold:3", "e": "ember:1", "E": "ember:4", "B": "ember:2",
			"Y": "blood:1", "y": "blood:0", "u": "blood:2", "w": "ember:4",
			"f": "ember:2", "L": "ember:1", "k": "gold:3",
			"P": "slate:2", "p": "slate:3", "K": "ember:1", "l": "night:1",
		},
		"head": [
			".........H..........",
			"........HF.....H....",
			".....H.HFH....HF....",
			"....HFHFFHhhhHFh....",
			".....hhhhhhhhhhhh...",
			".....hSssssssssh....",
			".....sssssssssss....",
			".....OOOOOOOOOOO....",
			".....OeEeOsOeEeO....",
			".....sOOOsnsOOOs....",
			".....sssssssssss....",
			".....Sssssssssss....",
			"......sssmmsssS.....",
			".......ssssssS......",
			"........sBBBs.......",
			"........ssBss.......",
		],
		"head_back": [
			".........H..........",
			"........HF.....H....",
			".....H.HFH....HF....",
			"....HFHFFHhhhHFh....",
			".....hhhhhhhhhhhh...",
			".....hhhhHhhhhhh....",
			".....hhHhhhhhhhh....",
			".....hhhhhhhhhhh....",
			".....OOOOOOOOOOO....",
			".....shhhhhhhhhs....",
			".....shhhhhhhhhs....",
			"......hhhhhhhhh.....",
			".......sssssss......",
			".......sssssss......",
			"........sssss.......",
			"........sssss.......",
		],
		"body": [
			".....YYuYsssYYy.....",
			"...YYuYYYYsYYYYyy...",
			"...YYuYYYYkYYYYyy...",
			"...YYuYYYYYYYYYyy...",
			"...kkuYYYYYYYYykk...",
			"...ssYYYYYYYYYyss...",
			"...ssYfYYYfYYfyss...",
			"...ssffYfffYfYfss...",
			"...SsLLLLLkLLLLsS...",
		],
		"body_back": [
			".....YYYYsssYYy.....",
			"...YYuYYYYYYYYYyy...",
			"...YYuYYYYYYYYYyy...",
			"...YYuYYYYYYYYYyy...",
			"...kkuYYYYYYYYykk...",
			"...ssYYYYYYYYYyss...",
			"...ssYfYYYfYYfyss...",
			"...ssffYfffYfYfss...",
			"...SsLLLLLLLLLLsS...",
		],
	},
	# a green cap with steel goggles pushed up on it, a bushy moustache; a cream shirt under
	# leaf overalls with steel buttons, a tool belt with a wrench and a screwdriver
	&"tinkerer": {
		"pal": {
			"h": "wood:1", "H": "wood:2", "C": "leaf:2", "D": "leaf:1",
			"O": "steel:3", "e": "gold:3", "B": "wood:1",
			"Y": "bone:3", "y": "bone:2", "u": "bone:4", "c": "bone:4",
			"A": "leaf:2", "a": "leaf:1", "b": "steel:4", "k": "steel:3",
			"L": "wood:2", "t": "steel:3", "T": "steel:4", "r": "blood:2",
			"P": "leaf:2", "p": "leaf:3", "K": "wood:2", "l": "wood:1",
		},
		"head": [
			"....................",
			".......CCCCCC.......",
			"......CCCCCCCCC.....",
			".....COeeOOOeeOC....",
			".....DDDDDDDDDDDDDD.",
			".....hSssssssssh....",
			".....hHhssssHhss....",
			".....sssssssssss....",
			".....ssossssosss....",
			".....sssssssssss....",
			".....sssssnsssss....",
			".....ssBBBBBBBss....",
			".....sBBsmmmsBBs....",
			"......sssssssss.....",
			".......sssssss......",
			"........zsssz.......",
		],
		"head_back": [
			"....................",
			".......CCCCCC.......",
			"......CCCCCCCCC.....",
			".....OOOOOOOOOOO....",
			".....CCCCDDDCCCC....",
			".....hhhhhhhhhhh....",
			".....hhhHhhhhhhh....",
			".....hhhhhhhhhhh....",
			".....shhhhhhhhhs....",
			".....shhhhhhhhhs....",
			"......hhhhhhhhh.....",
			"......sssssssss.....",
			".......sssssss......",
			".......sssssss......",
			"........sssss.......",
			"........sssss.......",
		],
		"body": [
			".....YYYYcccYYy.....",
			"...YYuAYYYYYYAyyy...",
			"...YYuAAAAAAAAyyy...",
			"...YYuAbAAAAbAyyy...",
			"...kkuAAAAAAAAykk...",
			"...ssAAAAAAAAAAss...",
			"...ssTTAaaaaAArss...",
			"...ssAtAaaaaAArss...",
			"...SsLtLLkLLLLTsS...",
		],
		"body_back": [
			".....YYYcccYYYy.....",
			"...YYuAYYYYYYAyyy...",
			"...YYuYAYYYYAYyyy...",
			"...YYuYYAYYAYYyyy...",
			"...kkuYYYAAYYYykk...",
			"...ssAAAAAAAAAAss...",
			"...ssAAAAAAAAAAss...",
			"...ssAAAAAAAAAAss...",
			"...SsLLLLLLLLLLsS...",
		],
	},
}

## Legs: the 11-row stamps above, by name.
const L_IDLE := 0
const L_STRIDE := 1
const L_PASS := 3

static var _rigs := {}
static var _clips := {}
static var _wand := {}
## The held wand, pointing right: a wooden shaft and a gem.
const WAND := ["........gG.", "wwwwwwwwgGG", "WWWWWWWWgG."]


## The hero as a rig (design-plan §8: idle 4, run 6, cast 3, dash 4, hurt 2, death 6 per
## facing). The quiff lags the head by a frame; bobs and squashes are whole pixel rows.
## `hero` picks the look (LOOKS); the apprentice keeps the ids "hero_front" and "hero_back",
## the others are "hero_<id>_front" and "hero_<id>_back".
static func rig(back := false, hero := &"apprentice") -> RigDef:
	var key := _key(back, hero)
	if _rigs.has(key):
		return _rigs[key]
	var look: Dictionary = LOOKS[look_id(hero)]
	var head: Array = look.get("head_back", HEAD_BACK) if back else look.get("head", HEAD)
	var r := RigDef.new()
	r.id = "hero_" + key
	r.w = W
	r.h = H
	r.pal = palette(hero)
	r.add_part("legs", FEET[L_IDLE], Vector2i(0, 25))
	r.add_part("torso", look.get("body_back", BODY_BACK) if back else look.get("body", BODY), Vector2i(0, 16))
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
static func clips(back := false, hero := &"apprentice") -> Dictionary:
	var key := _key(back, hero)
	if not _clips.has(key):
		_clips[key] = RigBaker.bake(rig(back, hero))
	return _clips[key]


## idle0, idle1, run0..3, cast (the pre-D6 order, kept for the title screen and art sheets).
static func frames(hero := &"apprentice") -> Array[Texture2D]:
	var c := clips(false, hero)
	var run: Array = c["run"]
	return [c["idle"][0], c["idle"][1], run[0], run[1], run[3], run[4], c["cast"][1]]


## The hero whose look is drawn: `hero` if it has one, else the apprentice.
static func look_id(hero: StringName) -> StringName:
	return hero if LOOKS.has(hero) else &"apprentice"


## PAL with a look's overrides merged over it.
static func palette(hero := &"apprentice") -> Dictionary:
	var look: Dictionary = LOOKS[look_id(hero)]
	if not look.has("pal"):
		return PAL
	var pal := PAL.duplicate()
	pal.merge(look["pal"], true)
	return pal


## The cache key of one hero and facing: "front"/"back" for the apprentice (its rig ids
## predate the looks), "<id>_front"/"<id>_back" for the others.
static func _key(back: bool, hero: StringName) -> String:
	var face := "back" if back else "front"
	var id := look_id(hero)
	return face if id == &"apprentice" else "%s_%s" % [id, face]


## The held wand pre-rotated to 16 angles (design-plan §7), pivot at the grip: index k
## points along TAU * k / 16. Drawn centred on the hand.
## `gem` is the Style ramp of the gem, so each wand shows its own colour (the HUD badge and
## the hand agree).
## 0.20: `body` is the shaft's ramp (Hotfix's wand skins, Residents.SKINS).
static func wand_angles(gem := "frost", body := "wood") -> Array[Texture2D]:
	var key := gem if body == "wood" else "%s|%s" % [gem, body]
	if not _wand.has(key):
		var out: Array[Texture2D] = []
		var src := PixelArt.paint(PackedStringArray(WAND), {"w": body + ":3", "W": body + ":1", "g": gem + ":3", "G": gem + ":4"})
		# the grip is the outlined sprite's pixel (1, 2)
		for img in RigBaker.rotations(src, Vector2(1.5, 2.5), 16):
			out.append(PixelArt.tex(img))
		_wand[key] = out
	return _wand[key]


## The gem ramp for a wand colour: the nearest of the bright ramps (a brown wand's gem is
## never a dull wood or stone; it falls back to frost).
const GEMS := ["arcane", "violet", "glitch", "cyan", "frost", "leaf", "ember", "gold", "rose", "toxic"]


static func gem_ramp(c: Color) -> String:
	if c.s < 0.35:
		return "frost"
	var best := "frost"
	var bd := INF
	for k in GEMS:
		var m := Color(Style.RAMPS[k][3])
		var d := absf(angle_difference(m.h * TAU, c.h * TAU)) + absf(m.v - c.v) * 0.5
		if d < bd:
			bd = d
			best = k
	return best
