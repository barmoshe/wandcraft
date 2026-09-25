class_name Projectiles
extends RefCounted
## Projectile sprites for 0.4 (decisions/0007): every flying spell has its own look.
## All frames live in one atlas strip of CELL x CELL cells so the player BulletPool still
## draws every bullet in one MultiMesh call (a shader picks the cell per instance).
## Player magic stays in cool colors and gold (D1): red is reserved for enemy threat, and
## pink is left to the Glitch-bodied enemies, so a projectile's color says whose it is.
## Cell 0 is the generic white core, tinted per bullet (shards, split bolts, the fan's
## rainbow). Sprites face right (+x); "dir" sprites rotate with the flight direction,
## the others spin. Drawn additive, so dark pixels simply do not show: art is light.

const CELL := 12

## name -> [frames (rows per frame), palette, directional]
const ART := {
	"mote": [[
		["............", "............", "............", "....1123....", "..112344w...", "11223444ww..", "..112344w...", "....1123....", "............"],
		["............", "............", "............", "...11233....", ".1122344w...", "1122344www..", ".1122344w...", "...11233....", "............"],
	], {"1": "arcane:1", "2": "arcane:2", "3": "arcane:3", "4": "arcane:4", "w": "#ffffff"}, true],
	"needle": [[
		["............", "............", "............", "............", "............", "1122333444ww", "............", "............"],
		["............", "............", "............", "............", "............", "..1223344www", "............", "............"],
	], {"1": "arcane:2", "2": "cyan:2", "3": "cyan:3", "4": "cyan:4", "w": "#ffffff"}, true],
	"moths": [[
		["............", "............", "...33.......", "...344......", "....4w4.....", "...344......", "...33.......", "............"],
		["............", "............", "............", "....44......", "..334w4.....", "....44......", "............", "............"],
	], {"3": "gold:3", "4": "gold:4", "w": "#ffffff"}, true],
	"frost": [[
		["............", "............", "............", ".....3......", "..1233w4....", "123344ww4...", "..1233w4....", ".....3......", "............"],
	], {"1": "frost:1", "2": "frost:2", "3": "frost:3", "4": "frost:4", "w": "#ffffff"}, true],
	"spark": [[
		["............", "............", "....4..3....", ".....4w.....", "...3wwww4...", ".....ww.....", "....4..3....", "............"],
		["............", "............", "...3...4....", "....4w......", "....wwww3...", "......w4....", "...4...3....", "............"],
	], {"3": "gold:3", "4": "gold:4", "w": "#ffffff"}, false],
	"ember": [[
		["............", "............", "......2233..", "...122334w3.", "1122334www4.", "...122334w3.", "......2233..", "............"],
		["............", "............", ".....12233..", "..1122334w3.", "112233www44.", "..1122334w3.", ".....12233..", "............"],
	], {"1": "ember:1", "2": "ember:2", "3": "ember:3", "4": "ember:4", "w": "#fff6d8"}, true],
	"seed": [[
		["............", "............", "............", ".....333....", "....34w43...", "....3444322.", "....34443...", ".....333....", "............"],
	], {"2": "leaf:3", "3": "gold:2", "4": "gold:3", "w": "gold:4"}, true],
	"wheel": [[
		[".....3......", ".....4......", "..3..4..3...", "...4w4w4....", "....www.....", "3444wwww4443", "....www.....", "...4w4w4....", "..3..4..3...", ".....4......", ".....3......"],
	], {"3": "gold:3", "4": "gold:4", "w": "#fff6d8"}, false],
	"disc": [[
		["............", "............", "....3333....", "...344443...", "..34w..w43..", "..34.44.43..", "..34.44.43..", "..34w..w43..", "...344443...", "....3333....", "............"],
		["............", "............", "....3333....", "...34w443...", "..344..443..", "..3w.44.w3..", "..34.44.43..", "..344..443..", "...344w43...", "....3333....", "............"],
	], {"3": "steel:3", "4": "cyan:4", "w": "#ffffff"}, false],
	"mine": [[
		["............", "............", ".....3......", "...3.33.3...", "....3333....", "..3334w333..", "....3333....", "...3.33.3...", ".....3......", "............"],
		["............", "............", ".....3......", "...3.33.3...", "....3333....", "..33333333..", "....3333....", "...3.33.3...", ".....3......", "............"],
	], {"3": "violet:3", "4": "violet:4", "w": "#ffffff"}, false],
	"null_orb": [[
		["....3333....", "..33....33..", ".3...11...3.", ".3..1..1..3.", "3..1....1..3", "3.1..44..1.3", "3.1..44..1.3", "3..1....1..3", ".3..1..1..3.", ".3...11...3.", "..33....33..", "....3333...."],
		["....3333....", "..34....43..", ".3...11...3.", ".4..1..1..4.", "3..1....1..3", "3.1..ww..1.3", "3.1..ww..1.3", "3..1....1..3", ".4..1..1..4.", ".3...11...3.", "..34....43..", "....3333...."],
	], {"1": "violet:2", "3": "violet:3", "4": "violet:4", "w": "#ffffff"}, false],
}

## Spell id -> sprite name (spells not listed use the tinted core).
const FOR_SPELL := {&"mote": "mote", &"needle": "needle", &"moths": "moths", &"frost": "frost", &"spark": "spark",
	&"ember": "ember", &"seed": "seed", &"wheel": "wheel", &"disc": "disc", &"mine": "mine", &"null_orb": "null_orb"}

static var _index: Dictionary = {}   # name -> [first cell, frame count, directional]
static var _cells := 0


## The atlas strip (built once) and the lookup table.
static func atlas() -> Texture2D:
	return PixelArt.cached("proj_atlas", func() -> Image:
		var cells: Array[Image] = [_core()]
		_index.clear()
		for name in ART:
			var entry: Array = ART[name]
			_index[name] = [cells.size(), (entry[0] as Array).size(), entry[2]]
			for rows in entry[0]:
				var img := PixelArt.blank(CELL, CELL)
				var art := PixelArt.paint(PackedStringArray(rows), entry[1], false, false)
				var off := (Vector2i(CELL, CELL) - art.get_size()) / 2
				off.x = 0
				PixelArt.blit(img, art, Vector2i(0, maxi(0, off.y)))
				cells.append(img)
		_cells = cells.size()
		var out := PixelArt.blank(CELL * _cells, CELL)
		for i in cells.size():
			PixelArt.blit(out, cells[i], Vector2i(i * CELL, 0))
		return out)


static func cell_count() -> int:
	atlas()
	return _cells


## [first cell, frames, directional] for a spell, or [0, 1, false] for the tinted core.
static func for_spell(id: StringName) -> Array:
	atlas()
	var n: String = FOR_SPELL.get(id, "")
	return _index.get(n, [0, 1, false])


## The generic core: a soft white dot (tinted by the bullet's color).
static func _core() -> Image:
	var img := PixelArt.blank(CELL, CELL)
	for j in CELL:
		for i in CELL:
			var d := Vector2(i + 0.5 - CELL / 2.0, j + 0.5 - CELL / 2.0).length()
			if d < 2.2:
				img.set_pixel(i, j, Color.WHITE)
			elif d < 3.6:
				img.set_pixel(i, j, Color(1, 1, 1, 0.75))
	return img
