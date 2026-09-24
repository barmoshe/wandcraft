class_name IconRelics
extends RefCounted
## Relic icon illustrations for 0.4 (see IconArt for the legend and research/arsenal-v04.md
## for what each item does). One entry per id: {"ramp", "acc" (optional), "rows": 12 x 12}.
## Data only: Icons.framed() draws the frame and the outline.

const ART := {
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
