class_name CompanionArt
extends RefCounted
## 0.21: the Duck and LINT as companions in a run (Bar: "the NPCs need to be in the world").
## LINT is built from its speech-box face (Hud.lint_face): an antenna and an eye that
## pulses. The Duck lives in DuckArt since 0.24.
## Style ramps only (ADR 0007).

const LINT_PAL := {"s": "steel:2", "S": "steel:3", "k": "night:0", "c": "cyan:4", "C": "cyan:2", "a": "steel:4"}

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


## The Duck: 0.24 moved it to DuckArt (the Debug Duck); this forwards for old callers.
static func duck(frame: int, talking: bool) -> Texture2D:
	return DuckArt.body(frame, talking)


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
