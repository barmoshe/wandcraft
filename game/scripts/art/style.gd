class_name Style
extends RefCounted
## The art direction in one place (decisions/0007). Every sprite, tile, icon and UI piece
## picks colors from these ramps instead of inline hex values, so the game reads as one set.
##
## Rules:
##   - Ramps run dark -> light, 5 steps, and hue-shift: shadows lean cool/violet, lights lean
##     warm. Shading moves a pixel along its own ramp; it never mixes toward black or white.
##   - Light comes from the top left. Outlines are 1px: the darkest step of the neighbouring
##     color on the lit sides ("sel-out"), and INK on the shadow sides and the ground line.
##   - Characters and enemies use saturated mid-steps; the floor stays in desaturated stone
##     and moss, so actors always pop against the room.
##   - Magic is light: projectiles and effects are drawn additive in the glow layer.
##   - Role hues (D1, research/design-research.md §3): enemy THREAT is hot red with a white
##     core and is used for nothing else; player magic is cool colors plus gold; pickups are
##     gold and green; the room is desaturated. Outlines: INK only on the bottom and right
##     edges and the ground line; top and left take the pixel's own ramp step 1.

const INK := Color("#0b0816")

## name -> 5 colors, dark to light.
const RAMPS := {
	"arcane": ["#1a1650", "#2b32a0", "#4460dc", "#7d9bff", "#c9d8ff"],
	"violet": ["#1f1033", "#3d1f63", "#6a36a0", "#a060d8", "#dcb4ff"],
	"glitch": ["#34092f", "#761866", "#c2359f", "#ff6fd2", "#ffd2f2"],
	"cyan": ["#08263a", "#0f5470", "#1c94b0", "#4fd8e8", "#c8fbff"],
	"frost": ["#10284a", "#1f5a8c", "#3c9ad0", "#86d8ff", "#e6fbff"],
	"moss": ["#0f2219", "#1d4128", "#356b34", "#5f9f3f", "#a8d668"],
	"leaf": ["#13291c", "#22502d", "#3d8a3a", "#72c24a", "#c6f07a"],
	"stone": ["#15131f", "#25233a", "#3b3a55", "#5b5d78", "#8e93ab"],
	"slate": ["#11161f", "#1d2635", "#2f3d50", "#4b5d72", "#7f93a6"],
	"sand": ["#2e2014", "#5a4228", "#8c6d45", "#c4a574", "#efdcb0"],
	"wood": ["#24140e", "#472817", "#6e4224", "#9c6a3a", "#caa06a"],
	"ember": ["#3a0c12", "#8a2016", "#d4501c", "#ff9a3a", "#ffe28a"],
	"gold": ["#3a2208", "#77460f", "#c08420", "#ffd05e", "#fff2c2"],
	"blood": ["#2c0714", "#6c1026", "#b8243c", "#ff4d68", "#ffb4c2"],
	"rose": ["#3a1024", "#7a2446", "#c24a74", "#ff86ad", "#ffd6e4"],
	"skin": ["#3e2226", "#7d4a40", "#bf8062", "#efb892", "#ffe0c6"],
	"bone": ["#2a2530", "#56505c", "#948c96", "#cfc8c8", "#f6f2ea"],
	"steel": ["#16181f", "#2e3340", "#555d6e", "#8c96a8", "#d4dbe6"],
	"toxic": ["#18260a", "#34540e", "#5c8c14", "#9cd01c", "#e0ff7a"],
	"night": ["#05030d", "#0a0718", "#120d26", "#1c1638", "#2a2250"],
	# reserved for enemy attacks: bullets, telegraphs, danger. Nothing of the player's uses it.
	"threat": ["#1e0306", "#6a0710", "#d0101e", "#ff4a3a", "#fff4ec"],
}

# UI (shared by the HUD and every menu screen)
const UI_GOLD := Color("#ffd05e")
const UI_GOLD_DIM := Color("#c08420")
const UI_PANEL := Color(0.07, 0.05, 0.13, 0.95)
const UI_PANEL_HI := Color("#241c3c")
const UI_RIM := Color("#3d3260")
const UI_TEXT := Color("#f4eeff")
const UI_MUTED := Color("#a89cc8")
const UI_GOOD := Color("#72e06a")
const UI_BAD := Color("#ff4d68")

## Rarity colors (common, rare, epic), used for frames, headers and door rims.
const RARITY := ["#b8c0d0", "#4fd8e8", "#ff6fd2"]
const RARITY_NAMES := ["Common", "Rare", "Epic", "Corrupted"]


static func ramp(name: String) -> Array:
	return RAMPS[name]


## One color from a "ramp:step" key or a "#rrggbb" string.
static func c(key: String) -> Color:
	if key.begins_with("#"):
		return Color(key)
	var parts := key.split(":")
	var r: Array = RAMPS[parts[0]]
	return Color(r[clampi(int(parts[1]), 0, r.size() - 1)])


static func rarity(r: int) -> Color:
	return Color(RARITY[clampi(r, 0, 2)])


## The ramp whose middle step is closest to a color (lets old hex colors find a ramp).
static func nearest_ramp(col: Color) -> String:
	var best := "arcane"
	var bd := INF
	for k in RAMPS:
		var m := Color(RAMPS[k][2])
		var d: float = Vector3(m.r - col.r, m.g - col.g, m.b - col.b).length_squared() + absf(m.h - col.h) * 0.15
		if d < bd:
			bd = d
			best = k
	return best
