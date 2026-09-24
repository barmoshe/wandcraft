class_name Hero
extends RefCounted
## The wizard, drawn for 0.4 (decisions/0007): about 22x30, built from parts (head with
## hat, robe, feet) so frames animate by moving parts instead of redrawing. Faces right;
## the node flips it for left. Style ramps only.

const PAL := {
	# hat and robe (arcane blue), band glows cyan, a gold star pin
	"a": "arcane:1", "b": "arcane:2", "c": "arcane:3", "d": "arcane:4",
	"q": "cyan:3", "Q": "cyan:4",
	# cape (violet, behind)
	"p": "violet:1", "P": "violet:2",
	# face
	"S": "skin:2", "s": "skin:3", "z": "skin:4", "e": "night:0", "n": "rose:2",
	# beard
	"v": "bone:2", "W": "bone:3", "w": "bone:4",
	# trim, belt, boots
	"G": "gold:2", "g": "gold:3", "y": "gold:4", "l": "wood:1", "L": "wood:2", "M": "wood:3",
}

const W := 22
const H := 32

const HAT := [
	"...............bba....",
	"..............bcca....",
	".............bccba....",
	"............bccbba....",
	"...........bdcbbba....",
	"..........bdcbbbba....",
	"..........bcbbbbba....",
	".........bccbbbbbba...",
	".........qQQqqyqqqa...",
	"........bccbbbbbbbba..",
	"....abbbccbbbbbbbbbbba",
	"...abbbbbbbbbbbbbbbbba",
	"....aaaaaaaaaaaaaaaaa.",
]

const FACE := [
	"......SssssssszsS.....",
	"......Ssssssesszse....",
	"......SSssnsesszsse...",
	".....vWWwsssssssWw....",
	".....vWwwwwnnwwwwWw...",
	"......vWwwwwwwwwwW....",
	".......vWwwwwwwWv.....",
	"........vWwwwwWv......",
]

const ROBE := [
	"......abcWwwwwwWcba...",
	".....pcbbcWwwwWcbbba..",
	"....pPcbbbcWwWcbbbbaa.",
	"...pPccbbbbcWcbbbbbca.",
	"...pPcbbbbbbcbbbbbcba.",
	"...pPggbbbbbbbbbbbggba",
	"...pPszLllllgGlllllsza",
	"...pPabbbbbbGbbbbbbba.",
	"...pPcbbbbbbgbbbbbbba.",
]

const HEM := [
	"..pPPcbbbbbbgbbbbbbbba",
	"..pPcbbbbbbbgbbbbbbbba",
	"..PGgggggggggggggggggG",
]

## Boots under the hem: idle and a 4-step walk cycle.
const FEET := [
	["......lLMM...lLMM....", "......llll...llll...."],
	[".....lLMM......lLMM..", ".....llll......llll.."],
	["......lLMM...lLMM....", "......llll...llll...."],
	["........lLMMlLMM.....", "........llllllll....."],
	["......lLMM...lLMM....", "......llll...llll...."],
]
const SWAY := [0, 1, 0, -1, 0]


## One frame. bob: head and hat drop 1px; feet: FEET index; lean: robe hem sways.
static func frame(bob: int, feet: int, cast := false) -> Image:
	var layers := []
	layers.append([FEET[feet], Vector2i(0, 30)])
	layers.append([ROBE, Vector2i(0, 18)])
	layers.append([HEM, Vector2i(SWAY[feet], 27)])
	layers.append([FACE, Vector2i(0, 12 + bob)])
	layers.append([HAT, Vector2i(0, bob)])
	if cast:
		# front hand raised to the chest, ready to thrust the wand
		layers.append([["...................Gg", "...................sz", "...................Ss"], Vector2i(0, 20)])
	return PixelArt.layered(W, H, layers, PAL)


## idle0, idle1, walk0..3, cast (same order the player node expects).
static func frames() -> Array[Texture2D]:
	var specs := [[0, 0, false], [1, 0, false], [0, 1, false], [1, 2, false], [0, 3, false], [1, 4, false], [0, 0, true]]
	var out: Array[Texture2D] = []
	for i in specs.size():
		var s: Array = specs[i]
		out.append(PixelArt.cached("hero%d" % i, func() -> Image: return frame(s[0], s[1], s[2])))
	return out
