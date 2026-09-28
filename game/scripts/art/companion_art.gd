class_name CompanionArt
extends RefCounted
## 0.21: the Duck and LINT as companions in a run (Bar: "the NPCs need to be in the world").
## Built from the faces the speech box used (Hud.duck_face, Hud.lint_face): the Duck gets
## feet and a beak that opens while it speaks; LINT gets an antenna and an eye that pulses.
## Style ramps only (ADR 0007).

const DUCK_PAL := {"y": "gold:2", "Y": "gold:3", "w": "bone:4", "k": "night:0", "o": "ember:3", "O": "ember:4"}
const LINT_PAL := {"s": "steel:2", "S": "steel:3", "k": "night:0", "c": "cyan:4", "C": "cyan:2", "a": "steel:4"}

const DUCK_HEAD := [
	"....yyyy....",
	"...yYYYYy...",
	"..yYYwkYYy..",
]
const DUCK_BEAK := ["..yYYkkYYoo.", "..yYYYYYoOo."]
const DUCK_BEAK_OPEN := ["..yYYkkYYoO.", "..yYYYYYy.o."]
const DUCK_BODY := [
	"...yYYYYy...",
	".yyYYYYYYyy.",
	"yYYYYYYYYYYy",
	"yYYYYYYYYYYy",
	".yYYYYYYYYy.",
	"..yyyyyyyy..",
]
const DUCK_FEET := [["...o....o...", "..oo...oo..."], ["..o......o..", ".oo.....oo.."]]

const LINT_ROWS := [
	".....a......",
	".....c......",
	".ssssssssss.",
	"sSSSSSSSSSSs",
	"sSkkkkkkkkSs",
	"sSkkkkkkkkSs",
	"sSkEEEEEEkSs",
	"sSkkkkkkkkSs",
	"sSkkkkkkkkSs",
	"sSSSSSSSSSSs",
	".ssssssssss.",
	"....sSSs....",
]


## The Duck, 12x13: `frame` 0/1 steps the feet, `talking` opens the beak.
static func duck(frame: int, talking: bool) -> Texture2D:
	var f := posmod(frame, 2)
	return PixelArt.cached("comp_duck_%d_%d" % [f, int(talking)], func() -> Image:
		var rows := PackedStringArray(DUCK_HEAD)
		rows.append_array(DUCK_BEAK_OPEN if talking else DUCK_BEAK)
		rows.append_array(DUCK_BODY)
		rows.append_array(DUCK_FEET[f])
		return PixelArt.paint(rows, DUCK_PAL))


## LINT, 12x12: a monitor drone. `frame` moves the scanline eye; `talking` makes it bright
## and pulsing.
static func lint(frame: int, talking: bool) -> Texture2D:
	var f := posmod(frame, 2)
	return PixelArt.cached("comp_lint_%d_%d" % [f, int(talking)], func() -> Image:
		var rows := PackedStringArray()
		for r in LINT_ROWS:
			var eye := "c" if talking and f == 0 else ("C" if talking else ("c" if f == 0 else "C"))
			rows.append(String(r).replace("E", eye))
		return PixelArt.paint(rows, LINT_PAL))
