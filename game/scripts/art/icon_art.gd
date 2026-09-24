class_name IconArt
extends RefCounted
## Illustrated icons for 0.4 (decisions/0007). Each is 12x12 art that sits inside a 16x16
## frame (Icons draws the frame from the item's kind), 18x18 with the outline.
##
## Legend (per icon, "ramp" is the main color ramp, "acc" an accent ramp, default gold):
##   1 2 3 4  main ramp steps (dark -> light)     w  near-white highlight
##   a b c    accent ramp steps 1..3              o  ink (dark detail)
##   .        empty (the frame shows through)

static func spell(id: StringName) -> Dictionary:
	return IconSpells.ART.get(id, IconSpellsB.ART.get(id, {}))


static func relic(id: StringName) -> Dictionary:
	return IconRelics.ART.get(id, {})


## Colors for one icon's legend.
static func legend(entry: Dictionary) -> Dictionary:
	var r: Array = Style.RAMPS[entry.get("ramp", "arcane")]
	var a: Array = Style.RAMPS[entry.get("acc", "gold")]
	return {
		"1": Color(r[1]), "2": Color(r[2]), "3": Color(r[3]), "4": Color(r[4]),
		"w": Color("#fffaf0"), "o": Style.INK,
		"a": Color(a[1]), "b": Color(a[2]), "c": Color(a[3]),
	}
