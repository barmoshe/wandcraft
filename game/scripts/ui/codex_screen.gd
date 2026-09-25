class_name CodexScreen
extends Screen
## D9: the Codex. What the Source Fragments you earn in runs can add to the pool (Meta), in
## cost order, and how much of the game you have unlocked. Tap a card to read it; BUY adds it
## to every run from then on. Drag or scroll to see the rest.

const CARD := Vector2(142, 28)
const GAP := 4.0

var sel := -1
var _scroll := 0.0
var _max_scroll := 0.0


func _paint() -> void:
	dim(0.94)
	var v := view()
	var sr := safe()
	text(sr.position + Vector2(2, 16), "CODEX", GOLD, 16, "body")
	text_right(sr.end.x - 84, sr.position.y + 14, "SOURCE FRAGMENTS  %d" % Meta.fragments(), GOLD, 8, "bold")
	button(Rect2(sr.end.x - 76, sr.position.y, 76, 24), "close", "BACK", "primary")
	text(sr.position + Vector2(2, 30), _collection(), MUTED)
	# the cards
	var top := sr.position.y + 38
	var bottom := sr.end.y - 44
	var cols := maxi(1, int((sr.size.x + GAP) / (CARD.x + GAP)))
	var x0 := sr.position.x + (sr.size.x - (cols * (CARD.x + GAP) - GAP)) / 2.0
	var owned: Array = Meta.unlocked()
	var n := Meta.UNLOCKS.size()
	for i in n:
		var u: Dictionary = Meta.UNLOCKS[i]
		var p := Vector2(x0 + (i % cols) * (CARD.x + GAP), top + (i / cols) * (CARD.y + GAP) - _scroll)
		if p.y + CARD.y < top or p.y > bottom:
			continue
		_card(Rect2(p, CARD), i, u, owned.has(String(u["id"])))
	_max_scroll = maxf(0.0, ceilf(float(n) / cols) * (CARD.y + GAP) - (bottom - top))
	# the picked card, and what buying it does
	var dr := Rect2(sr.position.x, sr.end.y - 38, sr.size.x, 38)
	panel(dr)
	if sel < 0:
		text(dr.position + Vector2(8, 22), "Runs earn Source Fragments (rooms, bosses, wins). Spend them to add to the pool.", MUTED)
		return
	var u: Dictionary = Meta.UNLOCKS[sel]
	var have := owned.has(String(u["id"]))
	text(dr.position + Vector2(8, 14), Meta.title(u).to_upper(), TEXT, 8, "bold")
	text(dr.position + Vector2(8, 28), _desc(u), MUTED, 8, "small", HORIZONTAL_ALIGNMENT_LEFT, dr.size.x - 120)
	if have:
		text_right(dr.end.x - 10, dr.position.y + 22, "IN THE POOL", Style.UI_GOOD, 8, "bold")
	else:
		var cost := int(u["cost"])
		button(Rect2(dr.end.x - 104, dr.position.y + 5, 96, 28), "buy", "BUY  %d" % cost, "primary", Meta.fragments() >= cost)


func _card(r: Rect2, i: int, u: Dictionary, have: bool) -> void:
	panel(r, i == sel)
	icon_at(_icon(u), r.position + Vector2(14, r.size.y / 2.0), 1.0, Color.WHITE if have else Color(0.35, 0.33, 0.45))
	text(r.position + Vector2(28, 12), Meta.title(u), TEXT if have else MUTED, 8, "bold")
	text(r.position + Vector2(28, 23), "IN THE POOL" if have else "%d fragments" % int(u["cost"]), Style.UI_GOOD if have else GOLD, 8)
	area(r, "card%d" % i)


func _icon(u: Dictionary) -> Texture2D:
	match u["t"]:
		&"spell", &"rune":
			return Icons.spell(Catalog.spell(u["id"]))
		&"relic":
			return Icons.relic(u["id"])
		&"wand", &"loadout":
			return Hero.wand_angles(Hero.gem_ramp(Catalog.wand(u["id"]).color))[14]
	return HudIcons.bag()


func _desc(u: Dictionary) -> String:
	match u["t"]:
		&"spell", &"rune":
			return Catalog.spell(u["id"]).desc
		&"relic":
			return String(Relics.DEFS[u["id"]]["desc"])
		&"wand":
			return Rewards.wand_desc(Catalog.wand(u["id"]))
		&"loadout":
			return String(Rewards.LOADOUT_TEXT.get(u["id"], ""))
		&"slot":
			return "Every run starts with one more empty slot on your first wand. The only upgrade that is not new content."
	return ""


## "Spells 40/58, relics 32/38, wands 6/9, runes 0/4": what the pool holds now.
func _collection() -> String:
	var count := func(kind: StringName) -> Array:
		var total := 0
		var locked := 0
		for u in Meta.UNLOCKS:
			if u["t"] == kind:
				total += 1
				if Meta.is_locked(u["id"]):
					locked += 1
		return [total, locked]
	var sp: Array = count.call(&"spell")
	var ru: Array = count.call(&"rune")
	var rl: Array = count.call(&"relic")
	var wd: Array = count.call(&"wand")
	return "Unlocked: spells %d/%d, runes %d/%d, relics %d/%d, wands %d/%d" % [
		sp[0] - sp[1], sp[0], ru[0] - ru[1], ru[0], rl[0] - rl[1], rl[0], wd[0] - wd[1], wd[0]]


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenDrag or (ev is InputEventMouseMotion and (ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
		_scroll = clampf(_scroll - float(ev.relative.y), 0.0, _max_scroll)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll = clampf(_scroll + 20.0, 0.0, _max_scroll)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = clampf(_scroll - 20.0, 0.0, _max_scroll)
	super._input(ev)


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
	elif id == "buy" and sel >= 0:
		if Meta.buy(Meta.UNLOCKS[sel]["id"]):
			Audio.sfx("buy", 0.0)
			toast("%s joins the pool" % Meta.title(Meta.UNLOCKS[sel]))
		else:
			Audio.sfx("deny", 0.0)
	elif id.begins_with("card"):
		sel = int(id.substr(4))
		Audio.sfx("ui", 0.05)
