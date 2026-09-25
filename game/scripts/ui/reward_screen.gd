class_name RewardScreen
extends Screen
## Choose 1 of 3. Tapping a card only inspects it (highlight); TAKE confirms, so a stray tap
## never picks a reward. SKIP pays a little gold. A spell goes to the bag (D2: placing it
## is the player's call), so TAKE & EQUIP opens the wand editor right after.
## Result: {"taken": item or null, "equip": bool}.

const TITLES := {
	&"start": ["BEFORE YOU GO", "Pick your wand"],
	&"spell": ["SPELL", "Pick one spell"],
	&"relic": ["RELIC", "Pick one relic"],
	&"challenge": ["CHALLENGE CLEARED", "Pick your prize"],
	&"wand": ["WAND", "Pick one"],
	&"mini": ["MINI-BOSS DEFEATED", "Pick your prize"],
	&"boss": ["BOSS DEFEATED", "Pick your prize"],
}

var kind: StringName = &"spell"
var offer: Array = []
var sel := -1


func _paint() -> void:
	dim()
	var v := view()
	var sr := safe()
	var t: Array = TITLES.get(kind, ["REWARD", "Pick one"])
	text_center(v.x / 2.0, sr.position.y + 18, t[0], GOLD, 16, "body")
	text_center(v.x / 2.0, sr.position.y + 32, t[1], MUTED)
	var n := offer.size()
	var cw := minf(128.0, (sr.size.x - 16.0 * (n - 1)) / maxf(1, n))
	var ch := minf(170.0, sr.size.y - 90.0)
	var total := cw * n + 12.0 * (n - 1)
	var x0 := v.x / 2.0 - total / 2.0
	var y0 := sr.position.y + 42
	for i in n:
		var r := Rect2(x0 + i * (cw + 12.0), y0, cw, ch)
		_card(r, offer[i], i == sel)
		area(r, "card%d" % i)
	var by := y0 + ch + 12
	var can_take := sel >= 0
	var equip := kind != &"start"
	var bx := v.x / 2.0 - (173.0 if equip else 116.0)
	if kind != &"start":
		button(Rect2(bx, by, 110, 30), "skip", "SKIP  +%d GOLD" % Rewards.SKIP_GOLD, "ghost")
	button(Rect2(bx + 118, by, 110, 30), "take", "TAKE", "primary", can_take)
	if equip:
		var spell: bool = can_take and offer[sel]["t"] == &"spell"
		button(Rect2(bx + 236, by, 110, 30), "equip", "TAKE & EQUIP", "primary", spell)


func _card(r: Rect2, item: Dictionary, selected: bool) -> void:
	var rar := Rewards.item_rarity(item)
	var rc := rarity_color(rar)
	if selected:
		r.position.y -= 3.0
		draw_rect(r.grow(4.0), Color(Style.UI_GOLD, 0.12))
	panel(r, selected)
	var cx := r.get_center().x
	# rarity header: a band in the rarity color with its name and gems (reads without color)
	var hb := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 11))
	draw_rect(hb, rc.darkened(0.55))
	draw_rect(Rect2(hb.position, Vector2(hb.size.x, 1)), rc.darkened(0.2))
	text(hb.position + Vector2(4, 9), Style.RARITY_NAMES[clampi(rar, 0, 2)].to_upper(), rc.lightened(0.2))
	for k in rar + 1:
		var g := Vector2(hb.end.x - 7 - k * 6, hb.position.y + 3)
		draw_rect(Rect2(g, Vector2(4, 4)), rc)
		draw_rect(Rect2(g, Vector2(2, 2)), rc.lightened(0.5))
	# the icon on a little pedestal with a soft glow
	var ic := Vector2(cx, r.position.y + 38)
	draw_circle(ic, 20.0, Color(rc, 0.08))
	draw_circle(ic, 14.0, Color(rc, 0.1))
	draw_set_transform(ic + Vector2(0, 17), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 14.0, Style.c("night:3"))
	draw_set_transform(Vector2.ZERO)
	icon_at(item_icon(item), ic + Vector2(0, sin(_age * 2.0 + r.position.x) * (1.0 if selected else 0.0)), 2.0)
	var y := r.position.y + 68
	text_center(cx, y, Rewards.item_title(item), TEXT, 8, "bold")
	y += 11
	text_center(cx, y, kind_label(item), MUTED)
	y += 4
	var kl := kind_label(item).to_lower()
	y += chips(cx, y, item_tags(item).filter(func(t: String) -> bool: return not kl.contains(t.to_lower())))
	var body := Rect2(r.position + Vector2(7, y - r.position.y + 2), Vector2(r.size.x - 14, r.end.y - y - 16))
	para(body, Rewards.item_desc(item), Style.c("bone:3"))
	if item["t"] == &"spell":
		draw_rect(Rect2(r.position.x + 3, r.end.y - 14, r.size.x - 6, 1), RIM)
		text(Vector2(r.position.x + 7, r.end.y - 5), spell_stats(item["id"]), Style.c("cyan:4"))


func _on_button(id: String) -> void:
	if id.begins_with("card"):
		var i := int(id.substr(4))
		sel = -1 if sel == i else i
		Audio.sfx("ui", 0.05)
	elif (id == "take" or id == "equip") and sel >= 0:
		var item: Dictionary = offer[sel]
		if not Rewards.grant(run, item):
			Audio.sfx("deny", 0.0)
			toast("Your bag is full (12). Skip this one, or merge spells.")
			return
		Audio.sfx("levelup" if _merged(item) else "pick", 0.0)
		finished.emit({"taken": item, "equip": id == "equip"})
	elif id == "skip":
		Audio.sfx("coin")
		run.gold += Rewards.SKIP_GOLD
		finished.emit({"taken": null})


## True when taking this spell just merged two copies into a higher level.
func _merged(item: Dictionary) -> bool:
	if item["t"] != &"spell":
		return false
	return run.spell_refs().any(func(r: Dictionary) -> bool: return r["s"]["id"] == item["id"] and int(r["s"]["lv"]) > 1)
