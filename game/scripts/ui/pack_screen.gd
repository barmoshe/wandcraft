class_name PackScreen
extends Screen
## The Merchant (0.19, research/workshop-0.19.md): spell packs for Bits. Three packs on the
## shelf, cheapest first, every item shown before you buy (fixed contents, never a gamble).
## Buying one is a moment: `$ pkg install net.pkg`, a progress bar, then the items flip in
## one at a time with the rarest last (Pokemon TCG Pocket's order). A tap skips ahead.

const INSTALL := 0.8        # seconds of the install bar
const FLIP := 0.45          # seconds between cards

var sel := 0
var bought := ""            # the pack being opened ("" while shopping)
var _open_t := 0.0


static func item(id: StringName) -> Dictionary:
	if Relics.DEFS.has(id):
		return {"t": &"relic", "id": id}
	if Catalog.wands().has(id):
		return {"t": &"wand", "id": id}
	return {"t": &"spell", "id": id}


## A pack's items, rarest last (the reveal's order).
static func reveal_order(p: Dictionary) -> Array:
	var items: Array = (p["items"] as Array).duplicate()
	items.sort_custom(func(a: StringName, b: StringName) -> bool: return _rank(a) < _rank(b))
	return items


static func _rank(id: StringName) -> int:
	if Relics.DEFS.has(id):
		return 10 + int(Relics.DEFS[id].get("rar", 0))
	if Catalog.wands().has(id):
		return 20
	return Catalog.spell(id).rarity if Catalog.spells().has(id) else 0


func _process(dt: float) -> void:
	if bought != "":
		_open_t += dt
	super._process(dt)


func _paint() -> void:
	dim(0.9)
	var sr := safe()
	var cx := view().x / 2.0
	if bought != "":
		_paint_open(sr, cx)
		return
	text(sr.position + Vector2(2, 16), "THE MERCHANT", GOLD, 16, "body")
	text_right(sr.end.x - 84, sr.position.y + 15, "%d BITS" % Meta.bits(), Color("#7cf0c8"), 8, "bold")
	button(Rect2(sr.end.x - 76, sr.position.y, 76, 24), "close", "BACK", "primary")
	var shelf := Meta.shelf()
	if shelf.is_empty():
		text_center(cx, sr.get_center().y, "Every pack is yours. The Guild is impressed.", MUTED)
		return
	text(sr.position + Vector2(2, 32), fit("Packs add spells and relics to every run after. What you see is what you get.", sr.size.x - 4.0), MUTED)
	var n := shelf.size()
	var cw := minf(150.0, (sr.size.x - 8) / n - 6)
	var x0 := cx - (n * (cw + 6) - 6) / 2.0
	for i in n:
		var p: Dictionary = shelf[i]
		var col := Color(p["color"])
		var r := Rect2(x0 + i * (cw + 6), sr.position.y + 40, cw, sr.size.y - 76)
		panel(r, i == sel)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), col)
		text(r.position + Vector2(8, 16), String(p["title"]).to_upper(), col, 8, "bold")
		text(r.position + Vector2(8, 27), String(p["file"]), MUTED)
		para(Rect2(r.position.x + 8, r.position.y + 32, r.size.x - 16, 22), String(p["blurb"]), TEXT)
		# every item, shown up front
		var items: Array = p["items"]
		var per := int((r.size.x - 12) / 22)
		for k in items.size():
			var c := r.position + Vector2(17 + (k % per) * 22, 68 + (k / per) * 22)
			var it := item(items[k])
			draw_circle(c, 9.0, Color(0.05, 0.03, 0.1))
			icon_at(Screen.item_icon(it), c)
			area(Rect2(c - Vector2(10, 10), Vector2(20, 20)), "it%d_%d" % [i, k])
		var price := Meta.pack_price(p["id"])
		var can := Meta.bits() >= price
		text_center(r.get_center().x, r.end.y - 34, "%d BITS" % price, Color("#7cf0c8") if can else Style.UI_BAD, 8, "bold")
		button(Rect2(r.position.x + 8, r.end.y - 28, r.size.x - 16, 24), "buy%d" % i, "INSTALL", "primary", can)
		area(Rect2(r.position, Vector2(r.size.x, 60)), "pack%d" % i)
	var owned := Meta.packs_owned()
	if not owned.is_empty():
		var names: Array = owned.map(func(pid: String) -> String: return String(Meta.pack(pid).get("file", pid)))
		text(Vector2(sr.position.x + 2, sr.end.y - 6), "Installed: " + ", ".join(names), MUTED)


func _paint_open(sr: Rect2, cx: float) -> void:
	var p := Meta.pack(bought)
	var col := Color(p["color"])
	var y := sr.position.y + 30
	text(Vector2(cx - 140, y), "$ pkg install %s" % p["file"], Style.UI_GOOD, 8, "bold")
	var k := clampf(_open_t / INSTALL, 0.0, 1.0)
	draw_rect(Rect2(cx - 140, y + 8, 280, 6), Color(0.1, 0.07, 0.18))
	draw_rect(Rect2(cx - 140, y + 8, 280 * k, 6), col)
	if k >= 1.0:
		text(Vector2(cx - 140, y + 26), "added %d packages to every run" % (p["items"] as Array).size(), MUTED)
	var items := reveal_order(p)
	var n := items.size()
	var cw := minf(84.0, (sr.size.x - 8) / n - 6)
	var x0 := cx - (n * (cw + 6) - 6) / 2.0
	for i in n:
		var t := _open_t - INSTALL - i * FLIP
		var r := Rect2(x0 + i * (cw + 6), y + 40, cw, 110)
		if t < 0.0:
			panel(r, false)
			text_center(r.get_center().x, r.get_center().y + 4, "?", MUTED, 16, "body")
			continue
		# the flip: the card narrows to its edge, then opens on its face
		var f := clampf(t / 0.25, 0.0, 1.0)
		var w := r.size.x * absf(cos(f * PI))
		var face := f >= 0.5
		var fr := Rect2(r.get_center().x - w / 2.0, r.position.y, maxf(1.0, w), r.size.y)
		var last := i == n - 1
		panel(fr, face and last)
		if not face or w < r.size.x * 0.8:
			continue
		var id: StringName = items[i]
		var it := item(id)
		if last:
			draw_arc(Vector2(r.get_center().x, r.position.y + 30), 16.0 + sin(_age * 5.0) * 2.0, 0.0, TAU, 24, GOLD, 1.0)
		icon_at(Screen.item_icon(it), Vector2(r.get_center().x, r.position.y + 30), 2.0)
		text_center(r.get_center().x, r.position.y + 60, Meta.title(id), GOLD if last else TEXT, 8, "bold")
		para(Rect2(r.position.x + 4, r.position.y + 66, r.size.x - 8, 42), _short(it), MUTED)
	var done := _open_t >= INSTALL + n * FLIP + 0.25
	area(Rect2(sr.position, sr.size - Vector2(0, 36)), "skip")
	if done:
		button(Rect2(cx - 110, sr.end.y - 30, 104, 28), "try", "TRY AT THE BENCH", "primary", Hub.is_open("repl", SaveGame.load_meta()))
		button(Rect2(cx + 6, sr.end.y - 30, 104, 28), "done", "DONE", "ghost")


func _short(it: Dictionary) -> String:
	match it["t"]:
		&"spell":
			return Catalog.spell(it["id"]).text_at(1)
		&"relic":
			return String(Relics.DEFS[it["id"]]["desc"])
	return Rewards.wand_desc(Catalog.wand(it["id"]))


func _on_button(id: String) -> void:
	if bought != "":
		match id:
			"skip":
				_open_t = maxf(_open_t, INSTALL + (Meta.pack(bought)["items"] as Array).size() * FLIP + 0.3)
			"done":
				finished.emit({"bought": bought})
			"try":
				finished.emit({"bought": bought, "try": true})
		return
	var shelf := Meta.shelf()
	if id == "close":
		finished.emit({})
	elif id.begins_with("pack"):
		sel = int(id.substr(4))
	elif id.begins_with("it"):
		var parts := id.substr(2).split("_")
		var p: Dictionary = shelf[int(parts[0])]
		var iid: StringName = p["items"][int(parts[1])]
		sel = int(parts[0])
		toast("%s: %s" % [Meta.title(iid), _short(item(iid)).left(60)])
	elif id.begins_with("buy"):
		var p: Dictionary = shelf[int(id.substr(3))]
		if Meta.buy_pack(p["id"]):
			Audio.sfx("unlock")
			bought = p["id"]
			_open_t = 0.0
		else:
			toast("Not enough Bits yet")
