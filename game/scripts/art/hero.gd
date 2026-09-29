class_name Hero
extends RefCounted
## The hero. 0.4 (decisions/0007) made him a hipster mage after a reference Bar picked: a
## swept-up quiff, teal shades, a full dark beard, a bright yellow shirt with a red tie and
## teal suspenders, slim red trousers. 0.26 (decisions/0038) redraws him in the 3/4 view the
## design plan asked for (research/design-plan.md §7): the head and the body turned toward
## where he faces, the near arm in front of the body, the wand held up in the far hand, shoes
## that point where he goes, and a knit scarf whose tail trails behind him. Faces right; the
## node flips it for left. Style ramps only.
##
## The rig (24x36, feet at the bottom centre) is built from parts, back to front:
##   scarf   the scarf's tail, behind the body (over the back in the back view)
##   legs    hips to shoes, drawn from joints (`legs`): a stride, a tuck
##   torso   shirt turned right (a lit side plane, the front with the tie), the scarf's wrap
##   hand    the wand arm: the forearm raised from the rolled cuff, the fist over the grip
##   face    the head below the quiff, with the eyes the shades normally hide
##   hair    the quiff (it lags the face a frame)
##   shades  their own part, so they can pop up when he is hit and fly off when he dies
##   arm_b   the near arm, in front of the body: hangs, swings, holds the casting stance,
##           reaches to the face (the fidget)
## 0.19: the Pyromancer and the Tinkerer wear their own looks on the same rig (LOOKS).

const PAL := {
	# hair: base, shadow, sheen, highlight
	"h": "slate:2", "d": "slate:1", "H": "slate:3", "I": "slate:4", "i": "slate:2",
	# face: base, shade, deep shade (ear), light (nose tip); eyes; beard; mouth
	"s": "skin:3", "S": "skin:2", "z": "skin:1", "n": "skin:4",
	"W": "bone:4", "e": "night:1",
	"B": "slate:2", "b": "slate:1", "m": "rose:1",
	# shades: frame, lens, and three lens pixels a glint runs across (GLINT)
	"o": "night:0", "G": "cyan:2", "1": "cyan:4", "2": "cyan:3", "3": "cyan:3",
	# shirt (light, base, shade, the dark contour between an arm and the body), cuffs,
	# tie, suspenders, belt and buckle
	"w": "gold:4", "Y": "gold:3", "y": "gold:2", "u": "gold:1", "c": "bone:4",
	"T": "blood:2", "t": "blood:3", "Q": "cyan:2", "L": "wood:1", "k": "gold:4",
	# trousers (base, shade, the rolled cuff) and brogues
	"P": "blood:2", "p": "blood:1", "r": "blood:3", "K": "wood:2", "l": "wood:1",
	# the knit scarf: base, shade, stripe
	"X": "arcane:3", "x": "arcane:2", "j": "frost:4",
	# the free hand's spark (player magic: cool colours)
	"V": "cyan:4", "v": "frost:4",
}

const W := 24
const H := 36

## The part origins (canvas rows). Stamps are written full width from these rows.
const AT_HAIR := 0
const AT_FACE := 5
const AT_SHADES := 9
const AT_ARM := 9
const AT_SCARF := 14
const AT_TORSO := 16
const AT_HAND := 16
const AT_LEGS := 25

# --------------------------------------------------------------- the apprentice's look

## The head, rows 0-15, turned right: the pompadour juts forward over the brow and slopes to
## the nape; the ear sits behind the cheek, the nose breaks the right edge, the beard runs
## along the jaw under a moustache. The eyes (W, e) sit under the shades and show when the
## shades come off (hurt, death).
const HEAD := [
	".................IH.....",
	"...............HHHh.....",
	".............hHHhhhh....",
	"...........dhHhhhhhh....",
	"..........dhhhhhhhhhh...",
	".........ddhhhhhhhhhhh..",
	".........ddhhhhhhhhhs...",
	".........ddhhhhhsssss...",
	".........ddShssssssss...",
	".........dSssssssssss...",
	".........SzsssWesWess...",
	".........Szsssssssssn...",
	".........dsssssssssss...",
	".........bBsssssBBBBs...",
	"..........BBBBBBBmmBB...",
	"...........bBBBBBBBb....",
]

## The shades, rows 9-11: the temple arm runs back to the ear; the near lens is full, the
## far lens foreshortened. 1, 2 and 3 are the lens pixels a glint crosses.
const SHADES := [
	"..........oooooooooo....",
	"............oG12oG3o....",
	".............oGGo.......",
]

## The torso, rows 16-24: the scarf's wrap, then the shirt turned right: the lit side plane on
## the left, the front plane with the near strap and the tie right of centre, the far side in
## shade; tucked high into the belt.
const BODY := [
	"..........xXXjXXjXx.....",
	".........wwXXXXXXXXY....",
	".........wYwQwwTTwYY....",
	".........YYYQYYTYYYY....",
	".........YYYQYYTYYYy....",
	".........yYYQYYtYYYy....",
	".........yyYQYYTYYYy....",
	".........yyYQYYtYYyy....",
	".........LLLLLLLkLLL....",
]

## The back view (aiming up): the combed-back head with its nape, the ear and the beard's edge
## on the right; the suspenders crossing between the shoulder blades.
const HEAD_BACK := [
	".................IH.....",
	"...............HHHh.....",
	".............hHHhhhh....",
	"...........dhHhhhhhh....",
	"..........dhhhhhhhhhh...",
	".........ddhhhhhhhhhhh..",
	".........dhhhiiihhhhh...",
	".........dhiihhhiiihh...",
	".........ddhhiiiihhhs...",
	".........ddhhhhhhhhzs...",
	"..........dhhhhhhhhzsS..",
	"..........ddhhhhhhhss...",
	"...........dhhhhhhBB....",
	"............sssssBBB....",
	"............ssssBB......",
	"............ssss........",
]

const BODY_BACK := [
	"..........xXXjXXjXx.....",
	".........wwXXXXXXXXY....",
	".........wYYQYYYQYY.....",
	".........YYYYQYQYYY.....",
	".........YYYYYQYYYy.....",
	".........yYYYQYQYYy.....",
	".........yyYQYYYQYy.....",
	".........yyYYYYYYyy.....",
	".........LLLLLLLLLL.....",
]

# ---------------------------------------------------------------- shared stamps

## The wand arm, rows 16-21: the fist at chest height over the wand's grip (Player.GRIP, the
## canvas pixel 21, 18), the forearm running down to the rolled cuff at the elbow.
const HAND := [
	"........................",
	".....................ss.",
	".....................Ss.",
	"....................us..",
	"...................usS..",
	"...................cc...",
]

## The near arm, rows 9-24, drawn over the body and the face. The dark "u" is its contour.
const ARM := {
	"hang": [
		"", "", "", "", "", "", "", "",
		"........ww..",
		"........wwu.",
		"........wYu.",
		"........YYu.",
		"........YYu.",
		"........cu..",
		"........ss..",
		"........Ss..",
	],
	# the run: swung forward across the body, and back behind it
	"fwd": [
		"", "", "", "", "", "", "", "",
		"........ww..",
		"........wYu.",
		".........YYu",
		".........YYu",
		"..........cu",
		"..........ss",
		"..........Ss",
		"............",
	],
	"back": [
		"", "", "", "", "", "", "", "",
		"........ww..",
		".......wwu..",
		".......YYu..",
		"......YYu...",
		"......cu....",
		".....ss.....",
		".....S......",
		"............",
	],
	# the casting stance: the free hand held up and back, its spark flickering
	"up": [
		"", "", "",
		"....ss......",
		"....Ss......",
		"....cc......",
		".....YY.....",
		"......YY....",
		".......wwu..",
		"........wu..",
		"", "", "", "", "", "",
	],
	"spark": [
		"",
		"...v..v.....",
		".....V......",
		"...Vss.V....",
		"....Ss......",
		"....cc......",
		".....YY.....",
		"......YY....",
		".......wwu..",
		"........wu..",
		"", "", "", "", "", "",
	],
	"spark2": [
		"..v.........",
		"......v.....",
		"..V.........",
		"....ssV.....",
		"...VSs......",
		"....cc......",
		".....YY.....",
		"......YY....",
		".......wwu..",
		"........wu..",
		"", "", "", "", "", "",
	],
	# hurt: flung out to the side
	"flail": [
		"", "", "", "", "",
		"..ss........",
		"..Sc........",
		"...cYY......",
		".....YYw....",
		"........wu..",
		"", "", "", "", "", "",
	],
	# the fidget: a finger on the shades' bridge (col 16, row 10)
	"reach": [
		"",
		"................s.......",
		"...............ss.......",
		"..............sS........",
		".............cc.........",
		"............YY..........",
		"...........YY...........",
		"..........YY............",
		"........wwY.............",
		"........wu..............",
		"", "", "", "", "", "",
	],
}

## The scarf's tail, rows 14-22, tied at the back of the neck (col 10, row 16).
const SCARF := {
	# hanging behind him, a stripe and the fringe showing past his back
	"rest": [
		"............",
		"............",
		"..........xX",
		".........xX.",
		".........Xj.",
		"........xX..",
		"........XX..",
		"........jX..",
		"........j.j.",
	],
	"sway": [
		"............",
		"............",
		"..........xX",
		".........xX.",
		"........Xj..",
		".......xX...",
		".......XX...",
		".......jX...",
		"......j.j...",
	],
	# the run: it trails back in a wave, three phases
	"fly0": [
		"............",
		"............",
		"....jXXjXXXX",
		"..xX........",
		".j..........",
		"............",
		"............",
		"............",
		"............",
	],
	"fly1": [
		"............",
		"............",
		".jXXjXXXXXXX",
		"j.xx........",
		"............",
		"............",
		"............",
		"............",
		"............",
	],
	"fly2": [
		"............",
		".jj.........",
		"...XXjXXXXXX",
		"..........x.",
		"............",
		"............",
		"............",
		"............",
		"............",
	],
	# the dash: pulled straight back
	"stream0": [
		"............",
		"............",
		"XXjXXjXXXXXX",
		".xx.xxX.....",
		"............",
		"............",
		"............",
		"............",
		"............",
	],
	"stream1": [
		"............",
		"jXXj........",
		"..xXXjXXXXXX",
		".....x......",
		"............",
		"............",
		"............",
		"............",
		"............",
	],
	# death: it drops
	"drop": [
		"............",
		"............",
		"..........xX",
		"..........X.",
		".........xX.",
		".........Xj.",
		".........XX.",
		".........jX.",
		"........j.j.",
	],
}

## Legs, rows 25-35: hips, slim trousers with a rolled cuff, brogues pointing right. The near
## leg (left at the hip) is drawn over the far one, which is a step darker.
static var LEG_IDLE: Array = legs(Vector2i(10, 30), Vector2i(10, 33), Vector2i(14, 30), Vector2i(14, 33))

## The run, 8 poses: contact, down, passing, up, then the same on the other leg. Each pose
## is [near knee, near ankle, far knee, far ankle] in canvas pixels, drawn by `legs` (the
## near leg leaves the hip at x 10, the far leg at x 14).
const RUN_JOINTS := [
	[Vector2i(8, 30), Vector2i(6, 33), Vector2i(16, 30), Vector2i(17, 33)],   # contact
	[Vector2i(8, 30), Vector2i(5, 32), Vector2i(15, 31), Vector2i(16, 33)],   # down
	[Vector2i(12, 29), Vector2i(9, 31), Vector2i(14, 30), Vector2i(14, 33)],  # passing
	[Vector2i(14, 29), Vector2i(16, 32), Vector2i(12, 30), Vector2i(10, 32)], # up
	[Vector2i(12, 30), Vector2i(14, 33), Vector2i(12, 30), Vector2i(10, 33)], # contact
	[Vector2i(12, 31), Vector2i(13, 33), Vector2i(12, 30), Vector2i(9, 32)],  # down
	[Vector2i(10, 30), Vector2i(10, 33), Vector2i(15, 29), Vector2i(12, 31)], # passing
	[Vector2i(9, 30), Vector2i(7, 32), Vector2i(16, 29), Vector2i(18, 32)],   # up
]
static var RUN: Array = RUN_JOINTS.map(func(j: Array) -> Array: return legs(j[0], j[1], j[2], j[3]))

## The dash: knees tucked under a forward lean.
static var LEG_TUCK: Array = legs(Vector2i(13, 29), Vector2i(9, 31), Vector2i(16, 29), Vector2i(13, 31))


## A leg pose from its joints (canvas pixels): each leg runs hip -> knee -> ankle as a
## 3-pixel column stepped along the line, then the rolled cuff at the ankle and the brogue
## pointing right under it. The rows start at AT_LEGS.
static func legs(nk: Vector2i, na: Vector2i, fk: Vector2i, fa: Vector2i) -> Array:
	var g: Array = []
	for j in H - AT_LEGS:
		var row: Array = []
		row.resize(W)
		row.fill(".")
		g.append(row)
	for i in range(8, 17):
		g[0][i] = "P"
		g[1][i] = "P"
	g[1][13] = "p"
	for leg in [[Vector2i(14, 27), fk, fa, "p", "l"], [Vector2i(10, 27), nk, na, "P", "K"]]:
		var hip: Vector2i = leg[0]
		var knee: Vector2i = leg[1]
		var ankle: Vector2i = leg[2]
		for y in range(hip.y, ankle.y):
			var x: int
			if y <= knee.y:
				x = roundi(lerpf(hip.x, knee.x, float(y - hip.y) / maxf(1.0, knee.y - hip.y)))
			else:
				x = roundi(lerpf(knee.x, ankle.x, float(y - knee.y) / maxf(1.0, ankle.y - knee.y)))
			_span(g, y, x - 1, x + 1, leg[3])
		_span(g, ankle.y, ankle.x - 1, ankle.x + 1, "r")
		_span(g, ankle.y + 1, ankle.x - 1, ankle.x + 2, leg[4])
		_span(g, ankle.y + 2, ankle.x - 1, ankle.x + 2, "l")
	var out: Array = []
	for row in g:
		out.append("".join(PackedStringArray(row)))
	return out


static func _span(g: Array, y: int, x0: int, x1: int, ch: String) -> void:
	var j := y - AT_LEGS
	if j < 0 or j >= g.size():
		return
	for x in range(maxi(0, x0), mini(W - 1, x1) + 1):
		g[j][x] = ch


## The held wand, pointing right: a wooden shaft and a gem.
const WAND := ["........gG.", "wwwwwwwwgGG", "WWWWWWWWgG."]

# ------------------------------------------------------------------ the other looks

## 0.19: each hero has its own look. A look is palette overrides (Style ramp keys, merged
## over PAL) plus optional replacement rows for the head, the torso and the shades, front
## and back, with the same row counts as HEAD, BODY, SHADES and their back views, so every
## pose and clip fits every hero. The legs, arms and the scarf are shared and take the look's
## colours (the sleeve is "Y", the cuff "c", the scarf "X", "x" and "j"). 0.26: "flicker"
## cycles palette recolours frame by frame; "reach_off" moves the fidget's hand.
const LOOKS := {
	&"apprentice": {},
	# a flame quiff, gold goggles with smoked lenses, a pointed goatee; a dark red shirt open at
	# the collar with flames licking up from the hem, charcoal trousers, an ember sash
	&"pyromancer": {
		# the flame quiff burns: its tips and highlights step along the ramps, frame by frame
		"flicker": [{}, {"F": "ember:4", "H": "gold:4"}, {"F": "gold:3", "f": "ember:4"}, {"H": "gold:3", "F": "gold:4"}],
		"pal": {
			"h": "ember:2", "d": "ember:1", "H": "ember:4", "I": "gold:4", "i": "ember:3", "F": "gold:4",
			"o": "gold:3", "G": "slate:1", "1": "gold:4", "2": "ember:4", "3": "ember:3",
			"B": "ember:2", "b": "ember:1",
			"w": "blood:3", "Y": "blood:2", "y": "blood:1", "u": "blood:0",
			"f": "ember:3", "L": "ember:1", "k": "gold:3", "c": "gold:3",
			"P": "slate:2", "p": "slate:1", "r": "slate:3", "K": "ember:1", "l": "night:1",
			"X": "ember:3", "x": "ember:2", "j": "gold:4",
			"V": "ember:4", "v": "gold:4",
		},
		"head": [
			"..............F...H.....",
			"............H.FH.HF.....",
			"...........HFHFFHFFH....",
			"...........hHFhhHFhh....",
			"..........dhhhhhhhhhh...",
			".........ddhhhhhhhhhhh..",
			".........ddhhhhhhhhhs...",
			".........ddhhhhhsssss...",
			".........ddShssssssss...",
			".........dSssssssssss...",
			".........SzsssWesWess...",
			".........Szsssssssssn...",
			".........dssssssssssS...",
			"..........Sssssssmmss...",
			"...........SsssssBBs....",
			"...............BBB......",
		],
		"head_back": [
			"..............F...H.....",
			"............H.FH.HF.....",
			"...........HFHFFHFFH....",
			"...........hHFhhHFhh....",
			"..........dhhhhhhhhhh...",
			".........ddhhhhhhhhhhh..",
			".........dhhhhhihhhhh...",
			".........dhhihhhhhihh...",
			".........oooooooooooo...",
			".........ddhhhhhhhhzs...",
			"..........dhhhihhhhzsS..",
			"..........ddhhhhhhhss...",
			"...........dhhhhhhhs....",
			"............sssssssB....",
			"............sssssBB.....",
			"............ssss........",
		],
		# goggles: a strap round the head and two round smoked lenses
		"shades": [
			".........ooooooooooo....",
			"............oG12oG3o....",
			".............ooo.oo.....",
		],
		"body": [
			"..........xXXjXXjXx.....",
			".........wwXXXXXXXXY....",
			".........wYwYYsssYY.....",
			".........YYYYYYsYYYY....",
			".........YYYYYYkYYYy....",
			".........yYYYYYYYYYy....",
			".........yfYYfYYYfYy....",
			".........ffYfffYfYff....",
			".........LLLLLLLkLLL....",
		],
		"body_back": [
			"..........xXXjXXjXx.....",
			".........wwXXXXXXXXY....",
			".........wYYYYYYYYY.....",
			".........YYYYYYYYYY.....",
			".........YYYYYYYYYy.....",
			".........yYYYYYYYYy.....",
			".........yfYYfYYYfy.....",
			".........ffYfffYfff.....",
			".........LLLLLLLLLL.....",
		],
	},
	# a green cap with steel goggles pushed up on it, a bushy moustache; a cream shirt under
	# leaf overalls with steel buttons, a tool belt with a wrench, a red rag for a scarf
	&"tinkerer": {
		# no shades to push up: the fidget twirls the moustache instead
		"reach_off": Vector2i(1, 3),
		"pal": {
			"h": "wood:2", "d": "wood:1", "H": "wood:3", "I": "wood:3", "i": "wood:3",
			"C": "leaf:3", "D": "leaf:1", "E": "leaf:2", "O": "steel:3", "g": "gold:3",
			"B": "wood:1", "b": "wood:1",
			"w": "bone:4", "Y": "bone:3", "y": "bone:2", "u": "bone:1", "c": "bone:4",
			"A": "leaf:2", "a": "leaf:1", "q": "steel:4", "k": "steel:3",
			"L": "wood:2", "t": "steel:3", "T": "steel:4", "R": "rust:3",
			"P": "leaf:2", "p": "leaf:1", "r": "leaf:3", "K": "wood:2", "l": "wood:1",
			"X": "blood:2", "x": "blood:1", "j": "bone:4",
			"V": "gold:4", "v": "bone:4",
		},
		"head": [
			"........................",
			"............CCCCC.......",
			"...........CCCCCCCC.....",
			"..........COggOOggOC....",
			"..........CCCCCCCCCCC...",
			".........dEEEEEEEEEEDDD.",
			".........dhhhhhsssss....",
			".........dhhhsssssss....",
			".........dhhSssssssss...",
			".........dSssssssssss...",
			".........SzsssWesWess...",
			".........Szsssssssssn...",
			".........dSsssBBBBBBs...",
			".........dSssBBBmBBBB...",
			"..........Sssssssssss...",
			"...........SSssssSS.....",
		],
		"head_back": [
			"........................",
			"............CCCCC.......",
			"...........CCCCCCCC.....",
			"..........OOOOOOOOOO....",
			"..........CCCCCCCCCCC...",
			".........EEEEEEEEEEEE...",
			".........dhhhhhhhhhhh...",
			".........dhhhhhHhhhhh...",
			".........dhhhhhhhhhhs...",
			".........ddhhhhhhhhzs...",
			"..........dhhhhhhhhzsS..",
			"..........ddhhhhhhhss...",
			"...........dhhhhhhBB....",
			"............sssssBBB....",
			"............ssssBB......",
			"............ssss........",
		],
		# no shades: his goggles sit on the cap
		"shades": [],
		"body": [
			"..........xXXjXXjXx.....",
			".........wwYAYYYYAY.....",
			".........wYYAYYYYAYY....",
			".........YYYAAAAAAYY....",
			".........YYYAqAAqAYy....",
			".........yAAAAAAAAAy....",
			".........yAAAaaaaAAA....",
			".........yTTAaaaaAAR....",
			".........LtLLLkLLLTL....",
		],
		"body_back": [
			"..........xXXjXXjXx.....",
			".........wwYAYYYYAY.....",
			".........wYYYAYYAYY.....",
			".........YYYYYAAYYY.....",
			".........YYYYYAAYYy.....",
			".........AAAAAAAAAA.....",
			".........AAAAAAAAAA.....",
			".........AAAAAAAAAA.....",
			".........LLLLLLLLLL.....",
		],
	},
}

## The glint that runs across the lenses (the fidget): which lens pixels flash, frame by frame.
const GLINT := [{"1": "bone:4"}, {"1": "bone:4", "2": "bone:4"}, {"2": "cyan:4", "3": "bone:4"}]

static var _rigs := {}
static var _clips := {}
static var _wand := {}


## The hero as a rig (decisions/0038). Per facing: idle 6, run 8, cast 4 (the casting stance,
## looped while he fires), run_cast 8 (the run with the stance, so the legs keep running while
## he fires), dash 5, hurt 3, death 8 and the fidget 10. The quiff lags the head and the scarf
## lags the body by a frame; bobs and squashes are whole pixel rows. `hero` picks the look
## (LOOKS); the apprentice keeps the ids "hero_front" and "hero_back", the others are
## "hero_<id>_front" and "hero_<id>_back".
static func rig(back := false, hero := &"apprentice") -> RigDef:
	var key := _key(back, hero)
	if _rigs.has(key):
		return _rigs[key]
	var look: Dictionary = LOOKS[look_id(hero)]
	var head: Array = look.get("head_back", HEAD_BACK) if back else look.get("head", HEAD)
	var body: Array = look.get("body_back", BODY_BACK) if back else look.get("body", BODY)
	var shades: Array = [] if back else look.get("shades", SHADES)
	var r := RigDef.new()
	r.id = "hero_" + key
	r.w = W
	r.h = H
	r.pal = palette(hero)
	if not back:
		r.add_part("scarf", SCARF["rest"], Vector2i(0, AT_SCARF))
	r.add_part("legs", LEG_IDLE, Vector2i(0, AT_LEGS))
	r.add_part("torso", body, Vector2i(0, AT_TORSO))
	if back:
		# from behind, the tail hangs down his back
		r.add_part("scarf", _back_scarf(SCARF["rest"]), Vector2i(0, AT_SCARF))
	# the wand arm, in front of the body's far edge; from behind, the body hides it
	r.add_part("hand", HAND, Vector2i(0, AT_HAND), back)
	r.add_part("face", head.slice(AT_FACE), Vector2i(0, AT_FACE))
	r.add_part("hair", head.slice(0, AT_FACE + 2), Vector2i(0, AT_HAIR))
	r.add_part("shades", shades if not shades.is_empty() else ["."], Vector2i(0, AT_SHADES))
	r.add_part("arm_b", ARM["hang"], Vector2i(0, AT_ARM))
	r.lag = {"hair": "face", "scarf": "torso"}
	var p := _Poser.new(back, look)
	# breathing: the body settles a pixel and rises, the scarf sways
	r.add_clip("idle", 5.0, true, [
		p.pose({}),
		p.pose({}),
		p.pose({"body": Vector2i(0, 1)}),
		p.pose({"body": Vector2i(0, 1), "scarf": "sway"}),
		p.pose({"body": Vector2i(0, 1), "scarf": "sway"}),
		p.pose({}),
	])
	# contact, down, passing, up on each leg; the near arm swings against the near leg, the
	# head leads by a pixel, the scarf waves behind. run_cast is the same run holding the stance.
	var bob := [0, 1, 0, -1, 0, 1, 0, -1]
	var swing := ["fwd", "fwd", "hang", "back", "back", "back", "hang", "fwd"]
	var wave := ["fly0", "fly0", "fly1", "fly1", "fly2", "fly2", "fly1", "fly1"]
	var run: Array = []
	var run_cast: Array = []
	for i in 8:
		var d := {"legs": RUN[i], "body": Vector2i(0, bob[i]), "head": Vector2i(1, 0), "scarf": wave[i]}
		run.append(p.pose(d.merged({"arm": swing[i]})))
		run_cast.append(p.pose(d.merged({"arm": "spark" if i % 4 < 2 else "spark2"})))
	r.add_clip("run", 16.0, true, run)
	# the casting stance, held while he fires: leaning in, the free hand up and sparking
	r.add_clip("cast", 10.0, true, [
		p.pose({"body": Vector2i(1, 0), "arm": "up", "hand": {"off": Vector2i(1, 0)}}),
		p.pose({"body": Vector2i(1, 0), "arm": "spark", "hand": {"off": Vector2i(1, 0)}}),
		p.pose({"body": Vector2i(1, 0), "arm": "up", "hand": {"off": Vector2i(1, 0)}, "scarf": "sway"}),
		p.pose({"body": Vector2i(1, 0), "arm": "spark2", "hand": {"off": Vector2i(1, 0)}, "scarf": "sway"}),
	])
	r.add_clip("run_cast", 16.0, true, run_cast)
	# crouch, launch (stretched, leaning in), two frames in the air with the knees tucked and
	# the scarf pulled straight back, the landing
	r.add_clip("dash", 24.0, false, [
		p.pose({"legs": {"rows": LEG_IDLE, "sq": 1}, "body": Vector2i(0, 1), "arm": "back"}),
		p.pose({"legs": {"rows": RUN[3], "sq": -1}, "body": Vector2i(1, -1), "head": Vector2i(1, 0), "arm": "back", "scarf": "stream0"}),
		p.pose({"legs": LEG_TUCK, "body": Vector2i(1, -1), "head": Vector2i(1, 0), "arm": "back", "scarf": "stream1"}),
		p.pose({"legs": LEG_TUCK, "body": Vector2i(1, -1), "head": Vector2i(1, 0), "arm": "back", "scarf": "stream0"}),
		p.pose({"legs": {"rows": RUN[0], "sq": 1}, "body": Vector2i(0, 1), "arm": "hang", "scarf": "fly1"}),
	])
	# the head snaps back, the shades jump up his forehead and his eyes show, the near arm flies
	# out; then he shakes it off and the shades drop back
	r.add_clip("hurt", 12.0, false, [
		p.pose({"_all": Vector2i(-1, 0), "head": Vector2i(-1, 0), "shades": Vector2i(0, -2), "arm": "flail", "scarf": "sway", "_recolor": {"m": "night:0"}}),
		p.pose({"_all": Vector2i(-1, 0), "shades": Vector2i(0, -2), "arm": "flail", "scarf": "sway", "_recolor": {"m": "night:0"}}),
		p.pose({"shades": Vector2i(0, -1)}),
	])
	# the hero "crashes": hit, the shades fly off and land by his feet, his knees give and he
	# sinks, the screen goes blue, then he tears and crumbles to pixels
	var bsod := _blue_screen(r.pal)
	var torn := [[10, 2, 2], [22, 1, -2]]
	var down := {"legs": {"rows": LEG_IDLE, "sq": 5}, "body": Vector2i(0, 5), "head": Vector2i(0, 1), "arm": "hang", "scarf": "drop", "shades": Vector2i(-8, 21)}
	r.add_clip("death", 8.0, false, [
		p.pose({"_all": Vector2i(-1, 0), "head": Vector2i(-1, 0), "shades": Vector2i(0, -2), "arm": "flail", "_recolor": {"m": "night:0"}}),
		p.pose({"legs": {"rows": LEG_IDLE, "sq": 2}, "body": Vector2i(0, 2), "head": Vector2i(-1, 0), "shades": Vector2i(-5, -5), "arm": "flail", "scarf": "sway", "_recolor": {"m": "night:0"}}),
		p.pose({"legs": {"rows": LEG_IDLE, "sq": 4}, "body": Vector2i(0, 4), "shades": Vector2i(-8, 8), "arm": "hang", "scarf": "drop"}),
		p.pose(down),
		p.pose(down.merged({"_recolor": bsod})),
		p.pose(down.merged({"_recolor": bsod, "_tear": torn})),
		p.pose(down.merged({"_recolor": bsod, "_tear": torn, "_crumble": 0.45})),
		p.pose(down.merged({"_recolor": bsod, "_tear": torn, "_crumble": 0.8})),
	])
	# 0.26: standing still a while, he pushes his shades back up his nose; a glint runs across
	# them and he gives a small, pleased nod. From behind, he scratches the back of his head.
	if back:
		var scratch := {"arm": "up", "arm_off": Vector2i(4, -1)}
		r.add_clip("fidget", 8.0, false, [
			p.pose({}),
			p.pose({"arm": "up"}),
			p.pose(scratch),
			p.pose(scratch.merged({"arm_off": Vector2i(5, -1), "head": Vector2i(-1, 0)})),
			p.pose(scratch),
			p.pose(scratch.merged({"arm_off": Vector2i(5, -1), "head": Vector2i(-1, 0)})),
			p.pose(scratch),
			p.pose({"arm": "up"}),
			p.pose({"head": Vector2i(0, 1)}),
			p.pose({}),
		])
	else:
		var reach := {"arm": "reach", "reach": true}
		r.add_clip("fidget", 8.0, false, [
			p.pose({}),
			p.pose({"arm": "fwd", "shades": Vector2i(0, 1)}),
			p.pose(reach.merged({"shades": Vector2i(0, 1)})),
			p.pose(reach.merged({"nudge": Vector2i(1, -1)})),
			p.pose(reach.merged({"_recolor": GLINT[0]})),
			p.pose({"arm": "fwd", "_recolor": GLINT[1]}),
			p.pose({"_recolor": GLINT[2]}),
			p.pose({"head": Vector2i(0, 1)}),
			p.pose({"head": Vector2i(0, 1)}),
			p.pose({}),
		])
	# a look can make palette keys flicker (the Pyromancer's hair): each frame of every clip
	# but the death takes the next step of the cycle under its own recolours
	var flick: Array = look.get("flicker", [])
	for c in r.clips:
		if flick.is_empty() or c == "death":
			continue
		var poses: Array = r.clips[c]["poses"]
		for i in poses.size():
			var rc: Dictionary = (flick[i % flick.size()] as Dictionary).duplicate()
			rc.merge(poses[i].get("_recolor", {}), true)
			poses[i]["_recolor"] = rc
	_rigs[key] = r
	return r


## Builds poses in the rig's terms: "body" moves everything above the legs, "head" moves the
## head on top of that, "arm" and "scarf" pick stamps ("arm_off" nudges the arm), "shades"
## moves the shades on the face, "reach" marks the fidget's hand at the face (a look's
## "reach_off" moves it, and "nudge" wiggles it for a look without shades). Rig-wide keys
## (_all, _tear, _crumble, _recolor) pass through.
class _Poser:
	var back := false
	var reach_off := Vector2i.ZERO
	var twirl := false

	func _init(is_back: bool, look: Dictionary = {}) -> void:
		back = is_back
		reach_off = look.get("reach_off", Vector2i.ZERO)
		twirl = look.has("reach_off")

	func pose(d: Dictionary) -> Dictionary:
		var body: Vector2i = d.get("body", Vector2i.ZERO)
		var head: Vector2i = body + (d.get("head", Vector2i.ZERO) as Vector2i)
		var out := {}
		out["torso"] = body
		out["face"] = head
		out["hair"] = head
		out["shades"] = {"off": head + (d.get("shades", Vector2i.ZERO) as Vector2i)}
		var hand: Variant = d.get("hand", {})
		var hd: Dictionary = (hand as Dictionary).duplicate()
		hd["off"] = body + (hd.get("off", Vector2i.ZERO) as Vector2i)
		if not back:
			hd["show"] = true
		out["hand"] = hd
		var arm_off: Vector2i = body + (d.get("arm_off", Vector2i.ZERO) as Vector2i)
		if d.get("reach", false):
			var nudge: Vector2i = d.get("nudge", Vector2i.ZERO) if twirl else Vector2i.ZERO
			arm_off = head + reach_off + nudge
		out["arm_b"] = {"off": arm_off, "rows": Hero.ARM[d.get("arm", "hang")]}
		var sc: Array = Hero.SCARF[d.get("scarf", "rest")]
		out["scarf"] = {"off": body, "rows": Hero._back_scarf(sc) if back else sc}
		if d.has("legs"):
			var lg: Variant = d["legs"]
			out["legs"] = lg if lg is Dictionary else {"rows": lg}
		for k in ["_all", "_tear", "_crumble", "_recolor"]:
			if d.has(k):
				out[k] = d[k]
		return out


## The scarf's tail seen from behind: hanging, it lies down the spine (3 px right of where it
## hangs behind him in front); flying, it streams out to the left the same way.
static func _back_scarf(rows: Array) -> Array:
	if rows != SCARF["rest"] and rows != SCARF["sway"] and rows != SCARF["drop"]:
		return rows
	var out: Array = []
	for row in rows:
		out.append("..." + String(row))
	return out


## The "blue screen" palette: every key of `pal` moved to the same step of the arcane and
## frost ramps, the crash before he crumbles.
static func _blue_screen(pal: Dictionary) -> Dictionary:
	var out := {}
	for k in pal:
		var v := String(pal[k])
		if not v.contains(":"):
			continue
		var step := int(v.get_slice(":", 1))
		out[k] = ("frost:%d" if step >= 3 else "arcane:%d") % clampi(step + 1, 1, 4)
	return out


## Where the wand hand is drawn in a clip's frame, relative to rest (whole pixels): the wand
## follows the fist through a bob, a lean or the casting stance.
static func hand_offset(back: bool, hero: StringName, clip_name: String, frame: int) -> Vector2i:
	var r := rig(back, hero)
	var poses: Array = r.clips[clip_name]["poses"]
	var pose: Dictionary = poses[clampi(frame, 0, poses.size() - 1)]
	var off: Vector2i = pose.get("_all", Vector2i.ZERO)
	var h: Variant = pose.get("hand", Vector2i.ZERO)
	return off + (h as Vector2i if h is Vector2i else ((h as Dictionary).get("off", Vector2i.ZERO) as Vector2i))


## Every clip of one facing, baked: clip name -> Array[Texture2D].
static func clips(back := false, hero := &"apprentice") -> Dictionary:
	var key := _key(back, hero)
	if not _clips.has(key):
		_clips[key] = RigBaker.bake(rig(back, hero))
	return _clips[key]


## Seven poses for menus and art sheets (the title, the Hero Hall, Copy-Paste's frames):
## two idle, four run, the casting stance.
static func frames(hero := &"apprentice") -> Array[Texture2D]:
	var c := clips(false, hero)
	var run: Array = c["run"]
	return [c["idle"][0], c["idle"][2], run[0], run[1], run[4], run[5], c["cast"][1]]


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
