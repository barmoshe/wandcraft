class_name Sprites
extends RefCounted
## Original sprite sheets for the vertical slice (wizard, four enemies, pickups).
## Ported from the Wandcraft v4 prototype art, which is our own.

const WIZ_PAL := {
	"h": "#26248a", "H": "#3f43d8", "L": "#7a86ff", "y": "#ffd36b", "f": "#f2c29b", "F": "#c88a6a",
	"e": "#1d1540", "b": "#eeeaff", "B": "#b8b0d8", "r": "#3b3ad8", "R": "#23217a", "o": "#6d78ff",
	"g": "#ffd36b", "G": "#b9851a", "k": "#2a1a30", "K": "#4a3450",
}
const WIZ_TOP := [
	".........LH.....", "........LHh.....", ".......LHHh.....", ".......HHHh.....",
	"......LHyHh.....", "......HHHHhh....", ".....LHHHHHh....", "....LHHHHHHhh...",
	"..hhHHHHHHHHhhh.", ".hhhhhhhhhhhhhh.", "....ffffffff....", "....fefFFefF....",
	"....bffffffb....", "....bbbffbbb....", "...obbbbbbbbR...", "..oorbbbbbbrRR..",
	"..orrrbbbbrrRR..", ".forrrrbbrrrRRf.", "..orrgggGggrRR..", "..orrrrrrrrrRR..",
]
const WIZ_LEGS := [
	["..oorrrrrrrrRRR.", "...kkk....kkk..."],
	["..oorrrrrrrrRR..", "..kkK.....kk...."],
	["..oorrrrrrrrRRR.", "....kk...kkK...."],
	["...orrrrrrrrRRR.", "....kkK....kk..."],
	["..oorrrrrrrrRRR.", "...kk....kkK...."],
]

const EP := {"w": "#ffffff", "e": "#1d1540", "k": "#0a0714"}
const ENEMY_ART := {
	"slime": {
		"rows": ["..a.....a..", "..a.....a..", "..gGGGGGg..", ".gGwGGGwGg.", "gGGGGGGGGGg", "gGGGGGGGGGg", ".ggggggggg."],
		"pal": {"a": "#c6e86a", "g": "#6fa83a", "G": "#9bd14f"},
	},
	"weaver": {
		"rows": ["l.l.....l.l", ".l.l...l.l.", "..lpppppl..", "l.pPrPrPp.l", ".lpPPPPPpl.", "l.pPPPPPp.l", "..lpppppl..", ".l.......l."],
		"pal": {"l": "#6b4a9a", "p": "#4a2e70", "P": "#6d45a8", "r": "#ff5a5a"},
	},
	"ram": {
		"rows": ["h..........h", ".h.oooooo.h.", "..oOOOOOOo..", ".oOOoOOoOOo.", "loOOOOOOOOol", ".oOOoOOoOOo.", "l.ooOOOOoo.l", "..hwhhhhwh..", ".l.hhhhhh.l."],
		"pal": {"h": "#3a2a1a", "o": "#3f6a2a", "O": "#5c9a3a", "l": "#3f6a2a"},
	},
	"sentry": {
		"rows": ["...mmmm...", "..mMMMMm..", ".mMrrrrMm.", ".mMrRRrMm.", ".mMrrrrMm.", "..mMMMMm..", ".mmmmmmmm.", "mMMMMMMMMm", "mMmMmMmMMm", "mmmmmmmmmm"],
		"pal": {"m": "#3a3a4a", "M": "#6a6a82", "r": "#8a1a1a", "R": "#ff5a2c"},
	},
}


static func wizard_rows(legs: int, sway: bool, cast: bool) -> PackedStringArray:
	var top: Array = WIZ_TOP.duplicate()
	if sway:
		for j in 4:
			top[j] = "." + String(top[j]).substr(0, 15)
	if cast:
		top[12] = "....bffffffb.f.."
		top[13] = "....bbbffbbb.f.."
		top[17] = ".forrrrbbrrrRR.."
	var out := PackedStringArray(top)
	out.append_array(PackedStringArray(WIZ_LEGS[legs]))
	return out


## Frames: idle0, idle1, walk0..3, cast.
static func wizard_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var specs := [[0, false, false], [0, true, false], [1, true, false], [2, false, false], [3, true, false], [4, false, false], [0, false, true]]
	for i in specs.size():
		var s: Array = specs[i]
		frames.append(PixelArt.cached("wiz%d" % i, func() -> Image:
			return PixelArt.from_rows(wizard_rows(s[0], s[1], s[2]), WIZ_PAL)))
	return frames


## Two-frame enemy animation: frame B steps the lower third sideways.
static func enemy_frames(kind: String) -> Array[Texture2D]:
	var art: Dictionary = ENEMY_ART[kind]
	var pal: Dictionary = EP.duplicate()
	pal.merge(art["pal"])
	var rows := PackedStringArray(art["rows"])
	var step := PackedStringArray()
	var from := int(rows.size() * 0.66)
	for j in rows.size():
		var r: String = rows[j]
		step.append(r if j < from else ("." + r.substr(0, r.length() - 1) if j % 2 else r.substr(1) + "."))
	return [
		PixelArt.cached("en_%s_a" % kind, func() -> Image: return PixelArt.from_rows(rows, pal)),
		PixelArt.cached("en_%s_b" % kind, func() -> Image: return PixelArt.from_rows(step, pal)),
	]


## The wand held by the wizard: a wooden shaft with a gem, pointing right (+x).
static func wand_texture() -> Texture2D:
	return PixelArt.cached("wand_held", func() -> Image:
		return PixelArt.from_rows(PackedStringArray([
			"........gG.",
			"wwwwwwwwgGG",
			"WWWWWWWWgG.",
		]), {"w": "#b8834a", "W": "#6e4524", "g": "#8fd8ff", "G": "#e8fbff"}, true, false))
