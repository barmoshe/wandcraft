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
	"h": "night:1", "H": "slate:2",
	# face, shades, beard
	"S": "skin:2", "s": "skin:3", "z": "skin:4", "n": "skin:2",
	"o": "night:0", "G": "cyan:2", "g": "cyan:4",
	"B": "night:1", "m": "rose:1",
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


## One frame. bob: head drops 1px; feet: FEET index; cast: the wand hand comes up.
static func frame(bob: int, feet: int, cast := false) -> Image:
	var layers := []
	layers.append([FEET[feet], Vector2i(0, 25)])
	layers.append([BODY, Vector2i(0, 16)])
	layers.append([HEAD, Vector2i(0, bob)])
	if cast:
		layers.append([["...............Yss", "...............ysz"], Vector2i(0, 19)])
	return PixelArt.layered(W, H, layers, PAL)


## idle0, idle1, walk0..3, cast (same order the player node expects).
static func frames() -> Array[Texture2D]:
	var specs := [[0, 0, false], [1, 0, false], [0, 1, false], [1, 2, false], [0, 3, false], [1, 4, false], [0, 0, true]]
	var out: Array[Texture2D] = []
	for i in specs.size():
		var s: Array = specs[i]
		out.append(PixelArt.cached("hero%d" % i, func() -> Image: return frame(s[0], s[1], s[2])))
	return out
