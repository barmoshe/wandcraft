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
	# 0.26 polish (decisions/0038): the quiff's sheen, beard strands, the inner shade of each
	# trouser leg, the belt buckle and a shine on each toe
	"i": "slate:2", "I": "slate:4", "b": "slate:2", "d": "blood:1", "x": "gold:4", "j": "slate:3",
}

const W := 20
const H := 36

const HEAD := [
	"...........IH.......",
	"..........HIHh.h....",
	"......hhiHHihhhh....",
	".....hiHHihhhiihh...",
	".....hhiihhhhhhh....",
	".....hSssssssssh....",
	".....hssssssssss....",
	".....ooooooooooo....",
	".....oGgGGoGgGGo....",
	".....soGGosoGGos....",
	".....sssssnsssss....",
	".....BsbbBBBbbsB....",
	".....BBBBmmmBBBB....",
	".....BBbBBBBBbBB....",
	"......BBBBBBBBB.....",
	".......BBBBBBB......",
]

const BODY := [
	".....YYQcccccQy.....",
	"...YYwYQYcTcYQyyy...",
	"...YYwYQYYTYYQyyy...",
	"...YYwYQYYtYYQyyy...",
	"...kkwYQYYTYYQykk...",
	"...ssYYQYYTYYQyss...",
	"...ssYYQYYtYYQyss...",
	"...ssyyxyyTyyxyss...",
	"...SsLLLLLxLLLLsS...",
]

## Legs: idle and a 4-step walk cycle.
const FEET := [
	[
		".....PPPPPPPPPP.....",
		".....PpPPPPpPPP.....",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......ppp..ppp......",
		"......KKKj.KKKj.....",
		"......llll.llll.....",
	],
	[
		".....PPPPPPPPPP.....",
		".....pPPPPPPpPP.....",
		".....pPd....pPd.....",
		".....pPd....pPd.....",
		".....pPd....pPd.....",
		".....pPd....pPd.....",
		".....pPd....pPd.....",
		".....pPd....ppp.....",
		".....ppp....KKKj....",
		".....KKKj...llll....",
		".....llll...........",
	],
	[
		".....PPPPPPPPPP.....",
		".....PpPPPPpPPP.....",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......ppp..ppp......",
		"......KKKj.KKKj.....",
		"......llll.llll.....",
	],
	[
		".....PPPPPPPPPP.....",
		".....PPpPPpPPPP.....",
		".......pPdpPd.......",
		".......pPdpPd.......",
		".......pPdpPd.......",
		".......pPdpPd.......",
		".......pPdpPd.......",
		".......ppppPd.......",
		".......KKjppp.......",
		".......lllKKKj......",
		"..........llll......",
	],
	[
		".....PPPPPPPPPP.....",
		".....PpPPPPpPPP.....",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......pPd..pPd......",
		"......ppp..ppp......",
		"......KKKj.KKKj.....",
		"......llll.llll.....",
	],
]


## D6: the back view, for aiming up (hair, ears, the beard's edge; suspenders cross).
const HEAD_BACK := [
	"...........IH.......",
	"..........HIHh.h....",
	"......hhiHHihhhh....",
	".....hiHHihhhiihh...",
	".....hhiihhhhhhh....",
	".....hhhhiihhhhh....",
	".....hhiihhhiihh....",
	".....hhhhhhhhhhh....",
	".....shhhhhhhhhs....",
	".....shhiihhhhhs....",
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

## The wand hand: a forearm and fist held out at chest height, holding the wand (the fire
## frame adds a gold smear behind it). 0.20 (Bar: "fix the wizard"): it was a fist inside the
## torso at the hip, shown only while casting, so the wand seemed to come out of his belly.
## Now the arm is out whenever the hero faces the camera, and the hanging right arm below it
## is taken off the torso (ARM_OUT).
const HAND := [".................Yss", ".................ySs"]
const HAND_FIRE := ["...............wwYss", ".................ySs"]
## The torso rows and columns of the hanging right arm (cuff and hand) the raised arm replaces.
const ARM_ROWS := [4, 5, 6, 7, 8]
const ARM_COLS := [15, 16]

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
			"d": "slate:1", "j": "ember:3",
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
			"d": "leaf:1", "j": "wood:4",
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


## The hero as a rig (design-plan §8, and decisions/0038): idle 4, run 6, cast 2 (the lean
## held while he fires), run_cast 6, dash 4, hurt 2, death 6 per facing. The quiff lags the
## head by a frame; bobs and squashes are whole pixel rows.
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
	var body: Array = look.get("body_back", BODY_BACK) if back else _arm_out(look.get("body", BODY))
	# 0.26: the free arm comes off the torso so it can swing (it is the look's own pixels)
	r.add_part("torso", _cut(body, FREE_ARM_ROWS, FREE_ARM_COLS), Vector2i(0, 16))
	var arm := _free_arm(body)
	r.add_part("arm", arm["hang"], Vector2i(0, 16))
	r.add_part("hair", head.slice(0, 5) + [head[4]], Vector2i.ZERO)
	r.add_part("face", head.slice(5), Vector2i(0, 5))
	# the wand arm, out at chest height; from behind, the body hides it
	r.add_part("hand", HAND, Vector2i(0, 17), back)
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
	# 0.26 (decisions/0038): the run bobs unevenly (down 1, down 1, up 2: research/hero-motion.md),
	# the head leads by a pixel, and the free arm swings against the stride. run_cast is the
	# same run with the arm held still: firing on the move keeps the legs running.
	var legs := [{"rows": stride}, {"rows": stride, "sq": 1}, {"rows": passing}, {"rows": stride}, {"rows": stride, "sq": 1}, {"rows": FEET[L_IDLE]}]
	var bob := [1, 2, 0, 1, 2, 0]
	var swing := ["back", "back", "hang", "fwd", "fwd", "hang"]
	var run: Array = []
	var run_cast: Array = []
	for i in 6:
		var b := Vector2i(0, bob[i])
		var pose := {"legs": legs[i], "torso": b, "face": b + Vector2i(1, 0)}
		run.append(pose.merged({"arm": {"off": b, "rows": arm[swing[i]]}}))
		run_cast.append(pose.duplicate())
	r.add_clip("run", 12.0, true, run)
	# 0.26: a steady lean while he fires. Each shot replays the smear frame; the body holds still
	# between shots instead of rocking on every one.
	r.add_clip("cast", 25.0, false, [
		{"torso": Vector2i(1, 0), "face": Vector2i(1, 0), "hand": {"off": Vector2i(1, 0), "rows": HAND_FIRE, "show": show}},
		{"torso": Vector2i(1, 0), "face": Vector2i(1, 0), "hand": {"off": Vector2i(1, 0), "show": show}},
	])
	r.add_clip("run_cast", 12.0, true, run_cast)
	r.add_clip("dash", 20.0, false, [
		{"legs": {"sq": 1}, "torso": down, "face": down},
		{"legs": {"rows": stride}, "torso": Vector2i(1, 0), "face": Vector2i(2, 0), "arm": {"off": Vector2i(1, 0), "rows": arm["back"]}},
		{"legs": {"rows": stride}, "torso": Vector2i(1, -1), "face": Vector2i(2, -1), "arm": {"off": Vector2i(1, -1), "rows": arm["back"]}},
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
	# both arms move with the torso (a bob, a lean, a fold) wherever a pose moves it
	for c in r.clips:
		for pose in r.clips[c]["poses"]:
			if not pose.has("torso"):
				continue
			var tv: Variant = pose["torso"]
			if not pose.has("hand"):
				pose["hand"] = tv if tv is Vector2i else {"off": (tv as Dictionary).get("off", Vector2i.ZERO)}
			if not pose.has("arm"):
				pose["arm"] = tv
	_rigs[key] = r
	return r


## 0.26: the free arm (the left of the sprite): its sleeve, rolled cuff and hand, in the
## torso's rows and columns. `_free_arm` lifts it off a torso and poses it.
const FREE_ARM_ROWS := [1, 2, 3, 4, 5, 6, 7, 8]
const FREE_ARM_COLS := [3, 4]
## Per arm row (FREE_ARM_ROWS order): the sideways shift of a swing, and -99 to drop the row
## (a hand swung toward or away from the camera looks a row shorter).
const ARM_SWING := {
	"hang": [0, 0, 0, 0, 0, 0, 0, 0],
	"back": [0, 0, -1, -1, -2, -2, -2, -99],
	"fwd": [0, 0, 0, 1, 1, 1, 1, -99],
}


## The free arm of a torso, posed: swing name -> full-width rows starting at the torso's row 0.
static func _free_arm(body: Array) -> Dictionary:
	var out := {}
	for k in ARM_SWING:
		var rows: Array = []
		for i in body.size():
			rows.append(".".repeat(W))
		var dx: Array = ARM_SWING[k]
		for n in FREE_ARM_ROWS.size():
			var y: int = FREE_ARM_ROWS[n]
			if int(dx[n]) == -99 or y >= body.size():
				continue
			var line: String = rows[y]
			for x in FREE_ARM_COLS:
				var ch := String(body[y])[x] if x < String(body[y]).length() else "."
				var to: int = x + int(dx[n])
				if ch != "." and to >= 0 and to < W:
					line = line.substr(0, to) + ch + line.substr(to + 1)
			rows[y] = line
		out[k] = rows
	return out


## `rows` with the given rows x columns cleared.
static func _cut(rows: Array, ys: Array, xs: Array) -> Array:
	var out: Array = []
	for i in rows.size():
		var row := String(rows[i])
		if ys.has(i):
			for x in xs:
				if x < row.length():
					row = row.substr(0, x) + "." + row.substr(x + 1)
		out.append(row)
	return out


## Where the wand hand is drawn in a clip's frame, relative to rest (whole pixels): the wand
## stays in the fist through a bob, a lean or a cast.
static func hand_offset(back: bool, hero: StringName, clip_name: String, frame: int) -> Vector2i:
	var poses: Array = rig(back, hero).clips[clip_name]["poses"]
	var pose: Dictionary = poses[clampi(frame, 0, poses.size() - 1)]
	var off: Vector2i = pose.get("_all", Vector2i.ZERO)
	var h: Variant = pose.get("hand", Vector2i.ZERO)
	return off + (h as Vector2i if h is Vector2i else ((h as Dictionary).get("off", Vector2i.ZERO) as Vector2i))


## A front torso with its right arm off (ARM_ROWS x ARM_COLS): the wand arm replaces it.
static func _arm_out(rows: Array) -> Array:
	var out: Array = []
	for i in rows.size():
		var row := String(rows[i])
		if ARM_ROWS.has(i):
			for x in ARM_COLS:
				if x < row.length():
					row = row.substr(0, x) + "." + row.substr(x + 1)
		out.append(row)
	return out


## Every clip of one facing, baked: clip name -> Array[Texture2D].
static func clips(back := false, hero := &"apprentice") -> Dictionary:
	var key := _key(back, hero)
	if not _clips.has(key):
		_clips[key] = RigBaker.bake(rig(back, hero))
	return _clips[key]


## idle0, idle1, four run frames, the cast (the pre-D6 order, kept for the title screen and
## art sheets).
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
