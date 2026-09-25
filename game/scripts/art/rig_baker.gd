class_name RigBaker
extends RefCounted
## Bakes a RigDef's clips to textures (D6). Each frame is composed with PixelArt.layered, so
## rigs get the same rim light and sel-out outline as every other sprite, then cached by
## "rig id / clip / frame". Deterministic: the same rig always bakes the same pixels.


## The textures of one clip, in order.
static func clip(rig: RigDef, clip_name: String) -> Array[Texture2D]:
	var poses: Array = rig.clips[clip_name]["poses"]
	var loop: bool = rig.clips[clip_name]["loop"]
	var out: Array[Texture2D] = []
	for i in poses.size():
		var prev: Dictionary = poses[i - 1] if i > 0 else (poses[poses.size() - 1] if loop else poses[0])
		var pose: Dictionary = poses[i]
		out.append(PixelArt.cached("rig_%s_%s_%d" % [rig.id, clip_name, i], func() -> Image:
			return pose_image(rig, pose, prev)))
	return out


## Every clip, baked: clip name -> Array[Texture2D].
static func bake(rig: RigDef) -> Dictionary:
	var out := {}
	for k in rig.clips:
		out[k] = clip(rig, k)
	return out


## One pose as an image. `prev` is the pose before it (for lagging parts).
static func pose_image(rig: RigDef, pose: Dictionary, prev: Dictionary = {}) -> Image:
	var all_off: Vector2i = pose.get("_all", Vector2i.ZERO)
	var layers := []
	for part_name in rig.order:
		var part: Dictionary = rig.parts[part_name]
		var p := _entry(pose, part_name)
		if p.get("hide", false) or (part.get("hidden", false) and not p.get("show", false)):
			continue
		var off: Vector2i = p["off"]
		if rig.lag.has(part_name) and not prev.is_empty():
			off = _entry(prev, rig.lag[part_name])["off"]
		var rows: Array = p.get("rows", part["rows"])
		var sq: int = p.get("sq", 0)
		var at: Vector2i = part["at"] + off + all_off
		if sq != 0:
			rows = squash(rows, sq)
			at.y += sq
		layers.append([rows, at])
	var pal: Dictionary = rig.pal
	if pose.has("_recolor"):
		pal = rig.pal.duplicate()
		pal.merge(pose["_recolor"], true)
	var img := PixelArt.layered(rig.w, rig.h, layers, pal)
	if pose.has("_tear"):
		img = tear(img, pose["_tear"])
	if pose.has("_crumble"):
		crumble(img, float(pose["_crumble"]))
	return img


## A pose entry as {"off": Vector2i, ...}, whichever way it was written.
static func _entry(pose: Dictionary, part_name: String) -> Dictionary:
	var v: Variant = pose.get(part_name, Vector2i.ZERO)
	if v is Vector2i:
		return {"off": v}
	var d: Dictionary = (v as Dictionary).duplicate()
	if not d.has("off"):
		d["off"] = Vector2i.ZERO
	return d


## Squash (n > 0: remove n rows) or stretch (n < 0: repeat a row). The row taken or repeated
## is the plainest one in the middle half (fewest different colours), so eyes, mouths and
## belts survive a squash; ties go to the row nearest the middle.
static func squash(rows: Array, n: int) -> Array:
	var out := rows.duplicate()
	for k in absi(n):
		if n > 0 and out.size() <= 1:
			break
		var i := _plain_row(out)
		if n > 0:
			out.remove_at(i)
		else:
			out.insert(i, out[i])
	return out


static func _plain_row(rows: Array) -> int:
	var sz := rows.size()
	var mid := sz / 2
	var best := mid
	var best_score := 1 << 20
	for i in range(sz / 4, maxi(sz / 4 + 1, sz - sz / 4)):
		var seen := {}
		for ch in String(rows[i]):
			if ch != "." and ch != " ":
				seen[ch] = true
		var score := seen.size() * 100 + absi(i - mid)
		if score < best_score:
			best_score = score
			best = i
	return best


## Scan-line tears: each band [y, height, dx] slides sideways by dx.
static func tear(img: Image, bands: Array) -> Image:
	var out := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for b in bands:
		for j in range(int(b[0]), mini(h, int(b[0]) + int(b[1]))):
			for x in w:
				var sx := x - int(b[2])
				out.set_pixel(x, j, img.get_pixel(sx, j) if sx >= 0 and sx < w else Color(0, 0, 0, 0))
	return out


## Removes a share of the opaque pixels in a fixed 4x4 Bayer order, top rows first, so a
## body crumbles from the head down and the result never flickers between runs.
static func crumble(img: Image, amount: float) -> void:
	const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var h := img.get_height()
	for j in h:
		for i in img.get_width():
			var v := (float(BAYER[(j % 4) * 4 + i % 4]) + 0.5) / 16.0
			# the top of the sprite goes first: the threshold falls toward the feet
			var k := amount * 1.6 - float(j) / h * 0.6
			if v < k:
				img.set_pixel(i, j, Color(0, 0, 0, 0))


## All clips in one image, a row per clip (for art sheets and a quick atlas).
static func sheet(rig: RigDef) -> Image:
	var baked := bake(rig)
	var cw := rig.w + 2
	var ch := rig.h + 2
	var cols := 0
	for k in baked:
		cols = maxi(cols, (baked[k] as Array).size())
	var img := Image.create_empty(cols * (cw + 1), baked.size() * (ch + 1), false, Image.FORMAT_RGBA8)
	var r := 0
	for k in baked:
		var fr: Array = baked[k]
		for i in fr.size():
			var src := (fr[i] as Texture2D).get_image()
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(i * (cw + 1), r * (ch + 1)))
		r += 1
	return img


## Pre-rotates a sprite to `n` angles (RotSprite-style, design-plan §7): each output pixel
## votes over a 3x3 grid of samples of the source, so edges stay single-pixel and no new
## colours appear. `pivot` is the source pixel that stays put; the result is a square canvas
## with the pivot at its centre. Angle k is TAU * k / n, clockwise on screen.
static func rotations(src: Image, pivot: Vector2, n := 16) -> Array[Image]:
	var sw := src.get_width()
	var sh := src.get_height()
	var reach := 0.0
	for c in [Vector2(0, 0), Vector2(sw, 0), Vector2(0, sh), Vector2(sw, sh)]:
		reach = maxf(reach, (c - pivot).length())
	var size := int(ceilf(reach)) * 2 + 1
	var mid := Vector2(size / 2, size / 2) + Vector2(0.5, 0.5)
	var out: Array[Image] = []
	for k in n:
		var a := TAU * k / n
		var ca := cos(a)
		var sa := sin(a)
		var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
		for j in size:
			for i in size:
				var votes := {}
				var best := Color(0, 0, 0, 0)
				var best_n := 0
				for sj in 3:
					for si in 3:
						var d := Vector2(i + (si + 0.5) / 3.0, j + (sj + 0.5) / 3.0) - mid
						# rotate back into the source
						var s := Vector2(d.x * ca + d.y * sa, -d.x * sa + d.y * ca) + pivot
						var x := floori(s.x)
						var y := floori(s.y)
						if x < 0 or y < 0 or x >= sw or y >= sh:
							continue
						var c := src.get_pixel(x, y)
						if c.a == 0.0:
							continue
						var key := c.to_rgba32()
						votes[key] = int(votes.get(key, 0)) + 1
						if votes[key] > best_n:
							best_n = votes[key]
							best = c
				var total := 0
				for v in votes.values():
					total += int(v)
				if total >= 5:
					img.set_pixel(i, j, best)
		out.append(img)
	return out
