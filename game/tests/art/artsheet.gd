extends Node2D
## Contact sheets for art review: every sprite, frame, icon and tile drawn at 4x on a dark
## ground with a label, saved to shots/artsheet-<name>.png. Run: tools/artsheet.sh [name].
## Sheets: chars, icons, tiles, fx, ui, all (default).

var S := 4
const PAD := 6

var items: Array = []   # [label, Texture2D] or ["#section", null]
var sheet := "all"
var only := ""
var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--scale="):
			S = int(a.substr(8))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	_collect()
	# draw into a fixed-size offscreen viewport, independent of the window
	var vp := SubViewport.new()
	vp.size = Vector2i(1800, 4000)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var bg := ColorRect.new()
	bg.color = Color(Style.RAMPS["night"][1])
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var canvas := _Canvas.new()
	canvas.sheet = self
	vp.add_child(canvas)
	add_child(vp)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var used := _extent()
	img = img.get_region(Rect2i(Vector2i.ZERO, Vector2i(mini(used.x, img.get_width()), mini(used.y, img.get_height()))))
	var path := "%s/artsheet-%s%s.png" % [out_dir, sheet, ("-" + only) if only != "" else ""]
	img.save_png(path)
	print("artsheet: ", path, " ", img.get_size())
	get_tree().quit()


func add(label: String, t: Texture2D) -> void:
	if only == "" or label.contains(only):
		items.append([label, t])


func section(title: String) -> void:
	if only == "":
		items.append(["#" + title, null])


func _collect() -> void:
	var want := func(n: String) -> bool: return sheet == "all" or sheet == n
	if want.call("chars"):
		ArtSheets.chars(self)
	if want.call("icons"):
		ArtSheets.icons(self)
	if want.call("tiles"):
		ArtSheets.tiles(self)
	if want.call("fx"):
		ArtSheets.fx(self)
	if want.call("ui"):
		ArtSheets.ui(self)
	if sheet == "style":
		ArtSheets.style(self)


var _layout: Array = []
var _size := Vector2i.ZERO


func _extent() -> Vector2i:
	return _size + Vector2i(PAD, PAD) * S


class _Canvas extends Node2D:
	var sheet: Node

	func _draw() -> void:
		sheet.paint_on(self)


func paint_on(ci: CanvasItem) -> void:
	var f := Game.font("small")
	var width := 1800.0
	var x := PAD * S
	var y := PAD * S
	var row_h := 0
	_size = Vector2i.ZERO
	for it in items:
		var label: String = it[0]
		if label.begins_with("#"):
			x = PAD * S
			y += row_h + (14 if row_h > 0 else 0)
			row_h = 0
			ci.draw_string(f, Vector2(x, y + 16), label.substr(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Style.UI_GOLD)
			y += 26
			continue
		var t: Texture2D = it[1]
		var sz := Vector2i(t.get_size()) * S
		var cell_w := maxi(sz.x, int(f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x) + 2)
		if x + cell_w > width - PAD * S:
			x = PAD * S
			y += row_h + 14
			row_h = 0
		ci.draw_rect(Rect2(Vector2(x, y), sz), Color(Style.RAMPS["night"][2]))
		ci.draw_texture_rect(t, Rect2(Vector2(x, y), sz), false)
		ci.draw_string(f, Vector2(x, y + sz.y + 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Style.UI_MUTED)
		row_h = maxi(row_h, sz.y + 12)
		_size.x = maxi(_size.x, x + cell_w)
		x += cell_w + PAD * S
		_size.y = maxi(_size.y, y + row_h)
