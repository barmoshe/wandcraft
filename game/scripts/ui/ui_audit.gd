class_name UiAudit
extends RefCounted
## The overlap audit (0.20). When `on`, the HUD's and the menus' drawing helpers record the
## rect of every string, panel and button they draw; report() lists the collisions:
## - text on text (two strings drawn over each other),
## - text on another element's box (a label under the speech box, a tip over a button),
## - text that leaves the screen,
## - (0.22) a tap area under MIN_TAP (32 x 32 base px): a Screen's buttons and areas, the
##   HUD's buttons. A thumb misses anything smaller.
## Each canvas item (the HUD, each Screen) is its own layer: a menu drawn over the HUD dims
## it, so only collisions inside one layer count. `owner` names the element being drawn
## (the HUD sets it per element, a button sets it for its label), and an element's own
## text may sit on its own boxes. tools/uiaudit.sh runs every screen and HUD state with it.

static var on := false
static var owner := ""
## layer id -> {"name": String, "texts": [[Rect2, String, owner]], "boxes": [[Rect2, owner]]}
static var layers := {}

const SLACK := 1.0   # the 1-2 px outline may touch a neighbour; a real overlap is bigger
const MIN_TAP := 32.0


## Tap areas under MIN_TAP, one line each. `taps`: [[Rect2 hit area, id]].
static func small_taps(name: String, taps: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for t in taps:
		var r: Rect2 = t[0]
		if r.size.x < MIN_TAP - 0.01 or r.size.y < MIN_TAP - 0.01:
			out.append("%s: small tap: [%s] %dx%d" % [name, t[1], roundi(r.size.x), roundi(r.size.y)])
	return out


## The tap areas a canvas item registered in its last draw: a Screen's `_buttons`
## ([Rect2, id]) or the HUD's `buttons` (id -> Rect2).
static func taps_of(item: CanvasItem) -> Array:
	var out: Array = []
	var list: Variant = item.get("_buttons")
	if list is Array:
		out.append_array(list)
	var dict: Variant = item.get("buttons")
	if dict is Dictionary:
		for id in dict:
			out.append([dict[id], id])
	return out


## Starts a fresh record for a canvas item (called at the top of its _draw).
## `in_world`: labels drawn in the room (the Workshop's station names), which scroll with the
## camera, so leaving the screen is fine for them.
static func begin(item: CanvasItem, in_world := false, label := "") -> void:
	if not on:
		return
	var nm: String = label if label != "" else (item.get_script().get_global_name() if item.get_script() else String(item.name))
	layers[item.get_instance_id()] = {"name": nm, "texts": [], "boxes": [], "world": in_world}
	owner = ""


## The tight rect of a string drawn at baseline `p` (as draw_string places it).
static func text_rect(f: Font, p: Vector2, s: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, size := 8) -> Rect2:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := p.x
	if width > 0.0:
		match align:
			HORIZONTAL_ALIGNMENT_CENTER:
				x += (width - w) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				x += width - w
	# the pixel fonts' ascent includes a line gap above the caps; cap height is what shows
	var top := p.y - f.get_ascent(size) * 0.85
	return Rect2(x, top, w, p.y + f.get_descent(size) * 0.5 - top)


static func text(item: CanvasItem, f: Font, p: Vector2, s: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, size := 8) -> void:
	if not on or s.strip_edges() == "":
		return
	var l: Dictionary = layers.get(item.get_instance_id(), {})
	if l.is_empty():
		return
	(l["texts"] as Array).append([text_rect(f, p, s, align, width, size), s, owner])


static func box(item: CanvasItem, r: Rect2, who := "") -> void:
	if not on:
		return
	var l: Dictionary = layers.get(item.get_instance_id(), {})
	if l.is_empty():
		return
	(l["boxes"] as Array).append([r, who if who != "" else owner])


## A dim over the whole canvas item: what it drew so far no longer counts.
static func cover(item: CanvasItem) -> void:
	if not on:
		return
	var l: Dictionary = layers.get(item.get_instance_id(), {})
	if not l.is_empty():
		(l["texts"] as Array).clear()
		(l["boxes"] as Array).clear()


static func _hit(a: Rect2, b: Rect2) -> bool:
	var i := a.intersection(b)
	return i.size.x > SLACK and i.size.y > SLACK


## Every collision in the recorded layers, one line each. `bounds` is the screen.
static func report(bounds: Rect2) -> PackedStringArray:
	var out := PackedStringArray()
	for id in layers:
		var l: Dictionary = layers[id]
		if not is_instance_id_valid(id):
			continue
		var item := instance_from_id(id) as CanvasItem
		if item == null or not item.is_visible_in_tree():
			continue
		var texts: Array = l["texts"]
		var boxes: Array = l["boxes"]
		var name: String = l["name"]
		if not l.get("world", false):
			out.append_array(small_taps(name, taps_of(item)))
		for i in texts.size():
			var a: Rect2 = texts[i][0]
			if not l.get("world", false) and not bounds.grow(1.0).encloses(a):
				out.append("%s: off screen: \"%s\" %s" % [name, texts[i][1], a])
			for j in range(i + 1, texts.size()):
				if texts[j][1] == texts[i][1] and texts[j][0] == a:
					continue   # the same string drawn twice (an outline pass)
				if _hit(a, texts[j][0]):
					out.append("%s: text on text: \"%s\" [%s] x \"%s\" [%s]" % [name, texts[i][1], texts[i][2], texts[j][1], texts[j][2]])
			for b in boxes:
				if b[1] == texts[i][2] or b[1] == "":
					continue
				if _hit(a, b[0]):
					out.append("%s: text on box: \"%s\" [%s] x box [%s] %s" % [name, texts[i][1], texts[i][2], b[1], b[0]])
		# boxes of different elements (HUD panels) must not stack either
		for i in boxes.size():
			for j in range(i + 1, boxes.size()):
				if boxes[i][1] == boxes[j][1] or boxes[i][1] == "" or boxes[j][1] == "":
					continue
				if _hit(boxes[i][0], boxes[j][0]):
					out.append("%s: box on box: [%s] %s x [%s] %s" % [name, boxes[i][1], boxes[i][0], boxes[j][1], boxes[j][0]])
	# one line per distinct collision (a frame can draw the same thing twice)
	var seen := {}
	var uniq := PackedStringArray()
	for s in out:
		if not seen.has(s):
			seen[s] = true
			uniq.append(s)
	return uniq
