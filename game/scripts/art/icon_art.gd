class_name IconArt
extends RefCounted
## Illustrated icons for 0.4 (decisions/0007). Each is 12x12 art that sits inside a 16x16
## frame (Icons draws the frame from the item's kind), 18x18 with the outline.
##
## Legend (per icon, "ramp" is the main color ramp, "acc" an accent ramp, default gold):
##   1 2 3 4  main ramp steps (dark -> light)     w  near-white highlight
##   a b c    accent ramp steps 1..3              o  ink (dark detail)
##   .        empty (the frame shows through)

const SPELLS := {
	&"mote": {"ramp": "arcane", "rows": [
		"........333.",
		".......34443",
		"......34ww43",
		"......34w443",
		".....2344432",
		"....2233332.",
		"...22222....",
		"..2222......",
		".1222.......",
		".111........",
		"11..........",
		"1...........",
	]},
	&"ember": {"ramp": "ember", "rows": [
		"....2.......",
		"....22..2...",
		"...232.22...",
		"..2332233...",
		"..23433342..",
		".2344443432.",
		".2344ww4432.",
		".234wwww432.",
		".2344ww4432.",
		"..23444432..",
		"...233332...",
		"....1111....",
	]},
	&"frost": {"ramp": "frost", "rows": [
		"......4.....",
		".....4w3....",
		".....4w3....",
		"..4..4w32.3.",
		".4w3.4w32434",
		".4w324w3243.",
		"..4w24w32.3.",
		"..4324w322..",
		"...32433221.",
		"....332221..",
		".....2221...",
		"......11....",
	]},
	&"empower": {"ramp": "blood", "acc": "gold", "rows": [
		".....44.....",
		"....4ww4....",
		"...4w44w4...",
		"..4w4334w4..",
		".44433334444",
		"....3333....",
		"....3223....",
		"....3223....",
		"...ab22ba...",
		"...bccccb...",
		"....aaaa....",
		"............",
	]},
	&"then": {"ramp": "gold", "acc": "arcane", "rows": [
		"............",
		".bbb........",
		"bcccb.......",
		"bcwcb..4....",
		"bcccb..44...",
		".bbb.44w44..",
		"....4444w44.",
		"......444...",
		"......44..2.",
		"......4..232",
		"........2343",
		".........22.",
	]},
}

const RELICS := {
	&"hot_patch": {"ramp": "blood", "acc": "sand", "rows": [
		"............",
		"..333..333..",
		".34w43344w3.",
		".3w44444443.",
		".3444ccc443.",
		".344cabac43.",
		"..34cabac3..",
		"...3cccc3...",
		"....3443....",
		".....33.....",
		"......2.....",
		"............",
	]},
	&"overclock": {"ramp": "ember", "acc": "steel", "rows": [
		"..c.c.c.c...",
		".bbbbbbbbb..",
		"cb1111111bc.",
		".b1344431b..",
		"cb134ww31bc.",
		".b134w431b..",
		"cb1344431bc.",
		".b1111111b..",
		"cbbbbbbbbbc.",
		"..c.c.c.c...",
		"............",
		"............",
	]},
}


## Colors for one icon's legend.
static func legend(entry: Dictionary) -> Dictionary:
	var r: Array = Style.RAMPS[entry.get("ramp", "arcane")]
	var a: Array = Style.RAMPS[entry.get("acc", "gold")]
	return {
		"1": Color(r[1]), "2": Color(r[2]), "3": Color(r[3]), "4": Color(r[4]),
		"w": Color("#fffaf0"), "o": Style.INK,
		"a": Color(a[1]), "b": Color(a[2]), "c": Color(a[3]),
	}
