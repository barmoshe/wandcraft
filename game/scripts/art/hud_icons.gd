class_name HudIcons
extends RefCounted
## D6: the HUD's own icons, drawn like every other sprite (Style ramps, top rim light, sel-out
## outline) instead of the flat 7x7 "plate" glyphs they replace: the coin, the pause button,
## the spell bag, and a heart and a mana drop for the vitals bars. Also a 3x5 pixel digit
## font, so counters fit inside a relic icon instead of spilling onto its neighbour.

const COIN := [
	"...3333...",
	"..344443..",
	".34422443.",
	"3442112443",
	"3442112443",
	"3442112443",
	"3442112443",
	".34422443.",
	"..233332..",
	"...2222...",
]
const PAUSE := [
	"33..33",
	"43..43",
	"43..43",
	"43..43",
	"43..43",
	"43..43",
	"32..32",
]
const BAG := [
	"....kk....",
	"...k..k...",
	"..333333..",
	".34444443.",
	".34gGG443.",
	".333gg333.",
	".32222223.",
	".32222223.",
	".22222222.",
	"..111111..",
]
const HEART := [
	".33.33.",
	"3443443",
	"3444443",
	"2344432",
	".23432.",
	"..232..",
	"...2...",
]
const DROP := [
	"..3..",
	"..3..",
	".343.",
	"34443",
	"34433",
	"23332",
	".222.",
]

## 3x5 digits, "#" lit.
const DIGITS := {
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
}


static func coin() -> Texture2D:
	return PixelArt.cached("hud_coin", func() -> Image:
		return PixelArt.paint(PackedStringArray(COIN), {"1": "gold:1", "2": "gold:2", "3": "gold:2", "4": "gold:3"}))


static func pause() -> Texture2D:
	return PixelArt.cached("hud_pause", func() -> Image:
		return PixelArt.paint(PackedStringArray(PAUSE), {"2": "bone:2", "3": "bone:3", "4": "bone:4"}))


static func bag() -> Texture2D:
	return PixelArt.cached("hud_bag", func() -> Image:
		return PixelArt.paint(PackedStringArray(BAG), {"1": "wood:1", "2": "wood:2", "3": "wood:3", "4": "wood:4",
			"k": "sand:3", "g": "gold:3", "G": "gold:4"}))


static func heart() -> Texture2D:
	return PixelArt.cached("hud_heart", func() -> Image:
		return PixelArt.paint(PackedStringArray(HEART), {"2": "blood:2", "3": "blood:3", "4": "blood:4"}))


static func drop() -> Texture2D:
	return PixelArt.cached("hud_drop", func() -> Image:
		return PixelArt.paint(PackedStringArray(DROP), {"2": "arcane:2", "3": "arcane:3", "4": "arcane:4"}))


## Width in pixels of a string in the 3x5 digit font (1 px between digits).
static func digits_width(s: String) -> int:
	return s.length() * 4 - 1


## Draws digits with a 1 px ink backing, top-left at `at`.
static func draw_digits(ci: CanvasItem, at: Vector2, s: String, c: Color) -> void:
	var w := digits_width(s)
	ci.draw_rect(Rect2(at - Vector2.ONE, Vector2(w + 2, 7)), Style.INK)
	for k in s.length():
		var rows: Array = DIGITS.get(s[k], DIGITS["0"])
		for j in 5:
			for i in 3:
				if String(rows[j])[i] == "#":
					ci.draw_rect(Rect2(at + Vector2(k * 4 + i, j), Vector2.ONE), c)
