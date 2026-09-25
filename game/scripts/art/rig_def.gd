class_name RigDef
extends Resource
## D6: a character as parts and poses (design-plan §7 "Pipeline", §8 frame budgets).
## Parts are ASCII stamps that share one Style palette (the same keys `PixelArt.paint` takes).
## A clip is a list of poses; a pose moves parts by whole pixels, swaps a part's rows, or
## squashes and stretches a part by taking away or adding a pixel row. Nothing is ever
## scaled or rotated at a fractional size. RigBaker bakes every clip to cached textures.
##
## A pose maps a part name to either a Vector2i offset or a dictionary:
##   "off":  Vector2i   whole-pixel offset from the part's rest position
##   "rows": Array      replacement rows for this pose (a blink, an open jaw, a stride)
##   "sq":   int        > 0 squashes (removes rows from the middle), < 0 stretches (repeats
##                      the middle row); the part stays planted on its bottom edge
##   "hide": bool       leave the part out
##   "show": bool       draw a part that is hidden by default (a hand that only casts)
## and may carry rig-wide keys:
##   "_all":    Vector2i  moves every part
##   "_tear":   Array     scan-line tears: [[y, height, dx], ...] shift bands sideways
##   "_crumble": float    0..1 of the opaque pixels removed, in a fixed dither order
##   "_recolor": Dictionary  palette key -> palette key for this pose (a glowing eye)

@export var id := ""
@export var w := 16
@export var h := 16
@export var pal := {}
## part name -> {"rows": Array[String], "at": Vector2i}
@export var parts := {}
## Draw order, back to front.
@export var order: Array[String] = []
## clip name -> {"fps": float, "loop": bool, "poses": Array[Dictionary]}
@export var clips := {}
## Secondary motion: part -> leader part. The part takes its leader's offset from the
## previous pose, so hair and capes trail the body by one frame.
@export var lag := {}


func add_part(part_name: String, rows: Array, at := Vector2i.ZERO, hidden := false) -> RigDef:
	parts[part_name] = {"rows": rows, "at": at, "hidden": hidden}
	order.append(part_name)
	return self


func add_clip(clip_name: String, fps: float, loop: bool, poses: Array) -> RigDef:
	clips[clip_name] = {"fps": fps, "loop": loop, "poses": poses}
	return self


func frame_count() -> int:
	var n := 0
	for k in clips:
		n += (clips[k]["poses"] as Array).size()
	return n


## Seconds one pass of a clip lasts.
func clip_length(clip_name: String) -> float:
	var c: Dictionary = clips[clip_name]
	return (c["poses"] as Array).size() / float(c["fps"])


## The frame index of a clip at time t (a one-shot clip holds its last frame).
func frame_at(clip_name: String, t: float) -> int:
	var c: Dictionary = clips[clip_name]
	var n: int = (c["poses"] as Array).size()
	var i := int(floorf(maxf(0.0, t) * float(c["fps"])))
	return i % n if c["loop"] else mini(i, n - 1)
