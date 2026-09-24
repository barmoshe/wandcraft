class_name Bestiary
extends RefCounted
## Enemies and bosses, drawn for 0.4 (decisions/0007). Each enemy is a body layer plus an
## optional second layer (legs, drips, a sprout) so frames animate by moving parts:
##   frame 0: rest      frame 1: the "b" layer offset by "bo" (a step or a squash)
## All sprites face right; the node flips them. Hitboxes stay in Enemy.DEFS (gameplay is
## unchanged by art size).

const ART := {
	"slime": {
		"w": 18, "h": 14,
		"pal": {"1": "toxic:1", "2": "toxic:2", "3": "toxic:3", "4": "toxic:4", "w": "bone:4", "o": "night:0",
			"M": "leaf:3", "m": "leaf:2", "k": "leaf:1"},
		"a": [
			"........Mm........",
			".......MMm........",
			"........k.........",
			".....23333332.....",
			"...233w44444332...",
			"..234ww4444ww432..",
			".2344ww4444ww4432.",
			".2344wo4444wo4432.",
		],
		"b": [
			"234444444444444432",
			"2344444oooo4444432",
			"233444444444444332",
			"122333333333333321",
			".1122222222222211.",
			"..11111111111111..",
		],
		"b_at": Vector2i(0, 8), "a_at": Vector2i(0, 0), "move": "a", "mo": Vector2i(0, 1),
	},
	"weaver": {
		"w": 22, "h": 16,
		"pal": {"1": "violet:0", "2": "violet:1", "3": "violet:2", "4": "violet:3", "r": "blood:2", "R": "blood:4",
			"o": "night:0", "L": "violet:1", "l": "violet:2", "g": "glitch:3", "G": "glitch:4"},
		"a": [
			".......1222221........",
			".....12233333221......",
			"....1223334rrr321.....",
			"....123334rRRRr321....",
			"....12333rRRoRRr21....",
			"....12333rRRoRRr21....",
			"....123334rRRRr321....",
			"....1223334rrr321.....",
			".....1223gGg32211.....",
			"......112g2g2211......",
			".......11111111.......",
		],
		"b": [
			"..ll..............ll..",
			".l..l............l..l.",
			"l....ll........ll....l",
			"L...l..L......L..l...L",
			"L..L....L....L....L..L",
			".L.L............L..L..",
			"L...L..........L....L.",
			"L...............L...L.",
		],
		"b_at": Vector2i(0, 6), "a_at": Vector2i(0, 2), "move": "b", "mo": Vector2i(0, -1),
		"b_under": true,
	},
}


static func has(kind: String) -> bool:
	return ART.has(kind)


static func frame(kind: String, step: int) -> Image:
	var d: Dictionary = ART[kind]
	var off_a: Vector2i = d["a_at"]
	var off_b: Vector2i = d["b_at"]
	if step == 1:
		if d["move"] == "a":
			off_a += d["mo"]
		else:
			off_b += d["mo"]
	var layers := []
	if d.get("b_under", false):
		layers.append([d["b"], off_b])
		layers.append([d["a"], off_a])
	else:
		layers.append([d["a"], off_a])
		layers.append([d["b"], off_b])
	return PixelArt.layered(d["w"], d["h"], layers, d["pal"])


static func frames(kind: String) -> Array[Texture2D]:
	return [
		PixelArt.cached("bx_%s_0" % kind, func() -> Image: return frame(kind, 0)),
		PixelArt.cached("bx_%s_1" % kind, func() -> Image: return frame(kind, 1)),
	]
