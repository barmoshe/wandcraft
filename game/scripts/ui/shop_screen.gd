class_name ShopScreen
extends Screen
## The merchant (mode "shop") and the forge (mode "forge"). Both are a grid of tiles on the
## left and a fixed info panel on the right with the one action button, so inspecting and
## buying are separate taps. The forge also sells +1 slot for the wand in hand, and the shop
## lets you Deprecate one spell per visit: it never shows up in this run's offers again (D2).

var mode := "shop"
var sel := -1
var _forge_refs: Array = []


func _opened() -> void:
	_refresh()


func _refresh() -> void:
	if mode == "forge":
		_forge_refs = run.spell_refs().filter(func(r: Dictionary) -> bool: return int(r["s"]["lv"]) < 3)


func _items() -> Array:
	if mode == "shop":
		return run.shop
	var out: Array = []
	for evo in Rewards.compilable(run):
		out.append({"t": &"compile", "id": evo, "price": 0, "sold": false})
	if run.wand().slots.size() < Rewards.SLOT_MAX:
		out.append({"t": &"slot", "id": &"slot", "price": Rewards.SLOT_PRICE, "sold": false})
	out.append_array(_forge_refs.map(func(r: Dictionary) -> Dictionary:
		return {"t": &"spell", "id": r["s"]["id"], "lv": int(r["s"]["lv"]), "price": Rewards.forge_price(int(r["s"]["lv"])), "sold": false}))
	return out


## Index into _forge_refs for a forge tile (the +1 slot tile comes first when offered).
func _ref_index(i: int) -> int:
	return i - (1 if run.wand().slots.size() < Rewards.SLOT_MAX else 0) - Rewards.compilable(run).size()


func _paint() -> void:
	dim()
	var v := view()
	var sr := safe()
	text(sr.position + Vector2(4, 16), "MERCHANT" if mode == "shop" else "FORGE", GOLD, 16, "body")
	text(sr.position + Vector2(4, 28), "Tap an item, then buy it." if mode == "shop" else "Upgrade a spell, add a slot, or compile a level-3 spell.", MUTED)
	# gold
	var gr := Rect2(sr.end.x - 150, sr.position.y + 4, 64, 22)
	panel(gr)
	icon_at(Icons.glyph("coin", Color("#ffd36b")), gr.position + Vector2(11, 11))
	text(gr.position + Vector2(22, 15), str(run.gold), GOLD, 8, "bold")
	button(Rect2(sr.end.x - 80, sr.position.y + 2, 80, 26), "close", "LEAVE", "ghost")
	var items := _items()
	var info_w := minf(170.0, sr.size.x * 0.38)
	var grid := Rect2(sr.position + Vector2(0, 38), Vector2(sr.size.x - info_w - 10, sr.size.y - 40))
	var tw := 44.0
	var th := 52.0
	var cols := maxi(1, int(grid.size.x / (tw + 6)))
	if items.is_empty():
		para(Rect2(grid.position + Vector2(4, 8), Vector2(grid.size.x - 8, 60)), "Nothing to upgrade: every spell you own is already at the top level." if mode == "forge" else "Sold out.", MUTED)
	for i in items.size():
		var it: Dictionary = items[i]
		var r := Rect2(grid.position + Vector2((i % cols) * (tw + 6), (i / cols) * (th + 6)), Vector2(tw, th))
		panel(r, i == sel)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), rarity_color(Rewards.item_rarity(it)).darkened(0.2))
		if i == sel:
			draw_rect(r.grow(1.0), GOLD, false, 1.0)
		var mod := Color(1, 1, 1, 0.35) if it.get("sold", false) else Color.WHITE
		icon_at(item_icon(it), r.position + Vector2(tw / 2.0, 18), 2.0, mod)
		if mode == "forge" and it["t"] == &"spell":
			text_center(r.get_center().x, r.position.y + 38, "+".repeat(int(it["lv"]) - 1) + " > " + "+".repeat(int(it["lv"])), GOLD)
		var price_c := GOLD if run.gold >= int(it["price"]) else Color("#ff6b7a")
		text_center(r.get_center().x, r.end.y - 4, ("BANNED" if run.banned.has(it["id"]) else "SOLD") if it.get("sold", false) else ("COMPILE" if it["t"] == &"compile" else str(it["price"])), MUTED if it.get("sold", false) else price_c)
		area(r, "item%d" % i)
	# info panel
	var ir := Rect2(sr.end.x - info_w, sr.position.y + 38, info_w, sr.size.y - 40)
	panel(ir, true)
	if sel >= 0 and sel < items.size():
		var it: Dictionary = items[sel]
		icon_at(item_icon(it), ir.position + Vector2(18, 20), 2.0)
		text(ir.position + Vector2(34, 17), Rewards.item_title(it), TEXT, 8, "bold")
		var rar := Rewards.item_rarity(it)
		text(ir.position + Vector2(34, 28), "%s - %s" % [kind_label(it), Relics.RARITY_NAMES[rar]], rarity_color(rar))
		var kl := kind_label(it).to_lower()
		var ch := chips(ir.get_center().x, ir.position.y + 34, item_tags(it).filter(func(t: String) -> bool: return not kl.contains(t.to_lower())))
		var used := para(Rect2(ir.position + Vector2(8, 40 + ch), Vector2(ir.size.x - 16, ir.size.y - 90 - ch)), Rewards.item_desc(it), Style.c("bone:3")) + ch
		if it["t"] == &"spell":
			var lv: int = int(it.get("lv", 1)) + (1 if mode == "forge" else 0)
			text(ir.position + Vector2(8, 48 + used), spell_stats(it["id"], lv), Color("#8fd8ff"))
		var can: bool = not it.get("sold", false) and run.gold >= int(it["price"])
		var label := ("UPGRADE  %d" if mode == "forge" else "BUY  %d") % int(it["price"])
		if it["t"] == &"compile":
			label = "COMPILE"
		var deprecate: bool = mode == "shop" and it["t"] == &"spell"
		var bw := (ir.size.x - 20) / 2.0 if deprecate else ir.size.x - 16
		button(Rect2(ir.position.x + 8, ir.end.y - 38, bw, 30), "buy", label, "primary", can)
		if deprecate:
			var can_ban: bool = not it.get("sold", false) and not run.deprecated_here
			button(Rect2(ir.position.x + 12 + bw, ir.end.y - 38, bw, 30), "ban", "DEPRECATE", "ghost", can_ban)
	else:
		para(Rect2(ir.position + Vector2(8, 12), Vector2(ir.size.x - 16, 80)), "Tap an item to see what it does.", MUTED)


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
	elif id.begins_with("item"):
		var i := int(id.substr(4))
		sel = -1 if sel == i else i
		Audio.sfx("ui", 0.05)
	elif id == "buy":
		_buy()
	elif id == "ban":
		_deprecate()


## Deprecate: the selected spell leaves the shop and never shows up in this run again.
func _deprecate() -> void:
	var items := _items()
	if sel < 0 or sel >= items.size() or run.deprecated_here:
		return
	var it: Dictionary = items[sel]
	if it["t"] != &"spell" or it.get("sold", false):
		return
	run.banned.append(it["id"])
	run.deprecated_here = true
	it["sold"] = true
	Audio.sfx("deny", 0.0)
	toast("%s is deprecated for this run" % Catalog.spell(it["id"]).title)


func _buy() -> void:
	var items := _items()
	if sel < 0 or sel >= items.size():
		return
	var it: Dictionary = items[sel]
	var price := int(it["price"])
	if it.get("sold", false) or run.gold < price:
		Audio.sfx("deny", 0.0)
		return
	Audio.sfx("forge" if mode == "forge" else "buy", 0.0)
	if mode == "forge" and it["t"] == &"compile":
		Rewards.compile_evo(run, it["id"])
		Audio.sfx("levelup", 0.0)
		toast("Compiled %s" % Catalog.spell(it["id"]).title)
		_refresh()
		sel = -1
		return
	if mode == "forge" and it["t"] == &"slot":
		Rewards.grant(run, it)
		run.gold -= price
		toast("%s now has %d slots" % [run.wand().def.title, run.wand().slots.size()])
		sel = -1
		return
	if mode == "forge":
		var ref: Dictionary = _forge_refs[_ref_index(sel)]
		ref["s"]["lv"] = int(ref["s"]["lv"]) + 1
		run.gold -= price
		for w in run.wands:
			w.ptr = 0
			w.acc = Mods.new()
		toast("%s is now level %d" % [Catalog.spell(ref["s"]["id"]).title, ref["s"]["lv"]])
		_refresh()
		sel = -1
		return
	if not Rewards.grant(run, it):
		toast("Your bag is full")
		return
	run.gold -= price
	it["sold"] = true
	toast("Bought %s" % Rewards.item_title(it))
