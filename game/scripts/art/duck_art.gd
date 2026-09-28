class_name DuckArt
extends RefCounted
## 0.24, the Debug Duck (research/duck-design.md, ADR 0036). Bar: "reinvent the duck". One
## design for every place the Duck appears: a glossy rubber duck with a big eye behind tiny
## teal glasses (the hero's own shades, Hero.PAL), a shine on the crown and the chest, and an
## orange beak. It faces right; nodes flip it. Style ramps only (ADR 0007).
##   face(mood, talk, blink)   12x11, the speech box and story tags (Hud.duck_face)
##   body(frame, talk, blink)  15x16, the companion in a run (feet waddle)
##   sit(talk, blink, mood)    15x14, the Workshop's Duck, sitting on the floor
##   familiar(frame)           14x11, the Rubber Duck spell on the field
##   ICON                      12x12, the Rubber Duck spell's icon (IconSpellsC)
##   bust(talk, blink, ripple) 44x40, the story panels (drawn at 2-3x)

## Moods for face(): what the line is doing.
const PLAIN := 0
const SMUG := 1
const PLEASED := 2

const PAL := {
	"y": "gold:2", "Y": "gold:3", "L": "gold:4", "d": "gold:1", "s": "bone:4",
	"o": "ember:3", "O": "ember:4", "m": "ember:1",
	"k": "night:0", "G": "cyan:2", "g": "cyan:4", "p": "night:0", "b": "gold:1",
	"f": "ember:2",
}

# ---- the head, shared by face / body / sit (8 rows, 12 wide, the bill to the right)
const HEAD := [
	"...yyyy.....",
	"..yLsLYy....",
	".yLLYYYYy...",
	".yLkkkkkk...",
	".yYkgGpGk...",
	".yYkGGGGkOOO",
	".yYYkkkkooo.",
	"..yYYYYYyo..",
]
## Rows 2-5 per mood (brow, lens): plain looks ahead, smug has a heavy brow and a lid half
## down, pleased squints happily (an arc).
const EYES := {
	PLAIN: [".yLLYYYYy...", ".yLkkkkkk...", ".yYkgGpGk...", ".yYkGGGGkOOO"],
	SMUG: [".yLbbbbby...", ".yLkkkkkk...", ".yYkkkkpk...", ".yYkgGGGkOOO"],
	PLEASED: [".yLLYYYYy...", ".yLkkkkkk...", ".yYkgGpGk...", ".yYkGpGpkOOO"],
}
## A blink: the lens with the lid down.
const BLINK := [".yYkGGGGk...", ".yYkGkkGkOOO"]
## Rows 6-7 while talking: the lower bill drops a pixel, the mouth shows between.
const BEAK_OPEN := [".yYYkkkkmm..", "..yYYYYYooo."]

const BODY := [
	"yy..yyYYYYYyy..",
	"yYyyYLLYYYYYYy.",
	".yYYLsLYYYYYYYy",
	".yYYYLYYYYYYYYy",
	"..yddYYYYYYYdy.",
	"...yddddddddy..",
]
const FEET := [["....o...o......", "...oo..oo......"], ["...o.....o.....", "..oo....oo....."]]


## The mood a line gives the Duck, from its id (Story and Barks events): pleased when
## something went right, smug when it gets to be right about something, plain otherwise.
const PLEASED_IN := ["win", "clear", "kill", "fast", "ending", "bought", "bounty", "unlock", "big_hit", "first"]
const SMUG_IN := ["death", "died", "quit", "abandon", "mana_empty", "status", "lint", "same_", "last_"]


static func mood_of(id: String) -> int:
	for k in PLEASED_IN:
		if id.contains(k):
			return PLEASED
	for k in SMUG_IN:
		if id.contains(k):
			return SMUG
	return PLAIN


## Rows for the head with a mood, blink and beak state, padded to `w` with the head at `x`.
static func _head(mood: int, talk: bool, blink: bool, x: int, w: int) -> PackedStringArray:
	var rows := PackedStringArray(HEAD)
	var e: Array = EYES.get(mood, EYES[PLAIN])
	for i in 4:
		rows[2 + i] = e[i]
	if blink and mood != PLEASED:
		rows[4] = BLINK[0]
		rows[5] = BLINK[1]
	if talk:
		rows[6] = BEAK_OPEN[0]
		rows[7] = BEAK_OPEN[1]
	var out := PackedStringArray()
	for r in rows:
		out.append((".".repeat(x) + r + ".".repeat(maxi(0, w - x - r.length()))).substr(0, w))
	return out


## The speech-box face: 12x11 grid, a 14x13 texture (resident portraits match its size).
static func face(mood := PLAIN, talk := false, blink := false) -> Texture2D:
	return PixelArt.cached("duck2_face_%d_%d_%d" % [mood, int(talk), int(blink)], func() -> Image:
		var rows := _head(mood, talk, blink, 0, 12)
		rows.append(".yyYYYYYYy..")
		rows.append("yYLsYYYYYYy.")
		rows.append("yYYYYYYYYdy.")
		return PixelArt.paint(rows, PAL))


## The companion: 15x16, `frame` 0/1 steps the feet.
static func body(frame := 0, talk := false, blink := false) -> Texture2D:
	var f := posmod(frame, 2)
	return PixelArt.cached("duck2_body_%d_%d_%d" % [f, int(talk), int(blink)], func() -> Image:
		var rows := _head(PLAIN, talk, blink, 3, 15)
		rows.append_array(PackedStringArray(BODY))
		rows.append_array(PackedStringArray(FEET[f]))
		return PixelArt.paint(rows, PAL))


## The Workshop's Duck, sitting: the companion without its feet.
static func sit(talk := false, blink := false, mood := PLAIN) -> Texture2D:
	return PixelArt.cached("duck2_sit_%d_%d_%d" % [int(talk), int(blink), mood], func() -> Image:
		var rows := _head(mood, talk, blink, 3, 15)
		rows.append_array(PackedStringArray(BODY))
		return PixelArt.paint(rows, PAL))


## The Rubber Duck spell's familiar: 14x11 side view, `frame` 1 opens the bill.
const FAMILIAR := [
	[
		".......yyyy...",
		"......yLsYYy..",
		"......ykkkkk..",
		"......ykgpGkOO",
		"y.....yYkkkooo",
		"yy...yYYYYYyo.",
		"yYyyyLYYYYYy..",
		"yYLsYYYYYYYYy.",
		".yYYYYYYYYYYy.",
		"..yddddddddy..",
		"...yyyyyyyy...",
	],
	[
		".......yyyy...",
		"......yLsYYy..",
		"......ykkkkk..",
		"......ykgpGkOO",
		"y.....yYkkkm..",
		"yy...yYYYYYooo",
		"yYyyyLYYYYYy..",
		"yYLsYYYYYYYYy.",
		".yYYYYYYYYYYy.",
		"..yddddddddy..",
		"...yyyyyyyy...",
	],
]


static func familiar(frame := 0) -> Texture2D:
	var f := posmod(frame, 2)
	return PixelArt.cached("duck2_fam_%d" % f, func() -> Image: return _familiar_image(f))


static func _familiar_image(f: int) -> Image:
	return PixelArt.paint(PackedStringArray(FAMILIAR[posmod(f, 2)]), PAL)


## The spell icon's 12x12 grid, in IconArt's legend (1-4 the gold steps, "c"/"b" the
## ember accent for the bill, "o" ink for the glasses, "w" the glint and the shine).
const ICON := [
	"............",
	"......333...",
	".....34w43..",
	".....oooo3..",
	".....ow4occc",
	".....3oo3bb.",
	"3....34443..",
	"33333444443.",
	"34w44444443.",
	".3444444443.",
	"..33333333..",
	"............",
]


# ---- the bust, for the story panels: drawn with shapes, not a grid (it is big)

## 44x40: the Duck from the chest up, three-quarters to the right, in its bath. `ripple`
## (0..2) moves the water line.
static func bust(talk := false, blink := false, ripple := 0) -> Texture2D:
	var rp := posmod(ripple, 3)
	return PixelArt.cached("duck2_bust_%d_%d_%d" % [int(talk), int(blink), rp], func() -> Image:
		return _bust(talk, blink, rp))


static func _bust(talk: bool, blink: bool, rp: int) -> Image:
	var img := PixelArt.blank(44, 40)
	# the tail: a pointed flick up and back, lit along its top
	for j in 11:
		var x0 := 2 + j / 2
		var x1 := 8 + j
		img.fill_rect(Rect2i(x0, 15 + j, x1 - x0, 1), Style.c("gold:3"))
		img.set_pixel(x0, 15 + j, Style.c("gold:2"))
		if j < 6:
			img.set_pixel(x0 + 1, 15 + j, Style.c("gold:4"))
	# body: a wide round shape, shaded toward the belly
	PixelArt.disc(img, Vector2(19, 30), 14.0, Style.c("gold:2"))
	PixelArt.disc(img, Vector2(19, 29), 13.0, Style.c("gold:3"))
	PixelArt.disc(img, Vector2(14, 25), 5.0, Style.c("gold:4"))
	# head, forward and up
	PixelArt.disc(img, Vector2(26, 13), 10.0, Style.c("gold:2"))
	PixelArt.disc(img, Vector2(26, 12), 9.0, Style.c("gold:3"))
	PixelArt.disc(img, Vector2(23, 9), 5.0, Style.c("gold:4"))
	# the gloss: a crown shine and a chest shine, the rubber toy read
	for p in [Vector2i(21, 6), Vector2i(22, 6), Vector2i(21, 7), Vector2i(13, 24), Vector2i(14, 24), Vector2i(13, 25)]:
		img.set_pixel(p.x, p.y, Style.c("bone:4"))
	# beak: an upper bill and, talking, a dropped lower one with the mouth between
	var bill := Style.c("ember:3")
	var bill_hi := Style.c("ember:4")
	img.fill_rect(Rect2i(33, 13, 8, 3), bill)
	img.fill_rect(Rect2i(33, 13, 7, 1), bill_hi)
	img.set_pixel(41, 14, bill)
	if talk:
		img.fill_rect(Rect2i(33, 16, 6, 1), Style.c("ember:1"))
		img.fill_rect(Rect2i(33, 17, 6, 2), Style.c("ember:2"))
	else:
		img.fill_rect(Rect2i(33, 16, 7, 2), Style.c("ember:2"))
	# the glasses (Hero.PAL: a night frame, cyan lenses, a cyan glint): the near lens big,
	# the far lens a sliver past the bridge
	var frame := Style.c("night:0")
	img.fill_rect(Rect2i(24, 8, 9, 7), frame)
	img.fill_rect(Rect2i(25, 9, 7, 5), Style.c("cyan:2"))
	img.fill_rect(Rect2i(33, 9, 3, 1), frame)          # the bridge onto the beak
	img.fill_rect(Rect2i(35, 8, 2, 5), frame)          # the far lens, edge-on
	img.set_pixel(36, 9, Style.c("cyan:2"))
	img.fill_rect(Rect2i(19, 10, 5, 1), frame)         # the arm back to the head
	if blink:
		img.fill_rect(Rect2i(26, 11, 5, 1), frame)
	else:
		img.fill_rect(Rect2i(28, 10, 3, 3), frame)     # the eye behind the lens
		img.set_pixel(26, 10, Style.c("cyan:4"))        # the glint
		img.set_pixel(27, 10, Style.c("cyan:4"))
		img.set_pixel(26, 11, Style.c("cyan:4"))
	# a knowing brow over the frame
	img.fill_rect(Rect2i(25, 6, 6, 1), Style.c("gold:1"))
	# bath water: a line of ripples across the front, and the belly under it
	var water := Style.c("cyan:3")
	var foam := Style.c("cyan:4")
	img.fill_rect(Rect2i(0, 36, 44, 4), Style.c("cyan:1"))
	for x in 44:
		var y := 35 + (1 if (x + rp * 2) % 6 < 3 else 0)
		img.set_pixel(x, y, water)
		if (x + rp * 2) % 6 == 0:
			img.set_pixel(x, y - 1, foam)
	return PixelArt.selout(img)
