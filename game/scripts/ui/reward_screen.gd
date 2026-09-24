class_name RewardScreen
extends Screen
## Choose 1 of 3. Tapping a card only inspects it (highlight); TAKE confirms, so a stray tap
## never picks a reward. SKIP pays a little gold. Result: {"taken": item or null}.

const TITLES := {
	&"start": ["BEFORE YOU GO", "Pick your first spell"],
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
	var ch := minf(150.0, sr.size.y - 96.0)
	var total := cw * n + 12.0 * (n - 1)
	var x0 := v.x / 2.0 - total / 2.0
	var y0 := sr.position.y + 44
	for i in n:
		var r := Rect2(x0 + i * (cw + 12.0), y0, cw, ch)
		_card(r, offer[i], i == sel)
		area(r, "card%d" % i)
	var by := y0 + ch + 12
	var can_take := sel >= 0
	button(Rect2(v.x / 2.0 + 6, by, 110, 30), "take", "TAKE", "primary", can_take)
	if kind != &"start":
		button(Rect2(v.x / 2.0 - 116, by, 110, 30), "skip", "SKIP  +%d GOLD" % Rewards.SKIP_GOLD, "ghost")


func _card(r: Rect2, item: Dictionary, selected: bool) -> void:
	var rar := Rewards.item_rarity(item)
	var rc := rarity_color(rar)
	panel(r, selected)
	# rarity band: color plus a gem count, so it reads without color too
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 3)), rc.darkened(0.2))
	for k in rar + 1:
		draw_rect(Rect2(r.end.x - 8 - k * 5, r.position.y + 7, 3, 3), rc)
	if selected:
		draw_rect(r.grow(2.0), GOLD, false, 1.0)
	icon_at(item_icon(item), Vector2(r.get_center().x, r.position.y + 30), 2.0)
	var cx := r.get_center().x
	text_center(cx, r.position.y + 58, Rewards.item_title(item), TEXT, 8, "bold")
	text_center(cx, r.position.y + 69, "%s  -  %s" % [kind_label(item), Relics.RARITY_NAMES[rar]], rc)
	var body := Rect2(r.position + Vector2(7, 74), Vector2(r.size.x - 14, r.size.y - 92))
	para(body, Rewards.item_desc(item), MUTED)
	if item["t"] == &"spell":
		text(Vector2(r.position.x + 7, r.end.y - 6), spell_stats(item["id"]), Color("#8fd8ff"))


func _on_button(id: String) -> void:
	if id.begins_with("card"):
		var i := int(id.substr(4))
		sel = -1 if sel == i else i
	elif id == "take" and sel >= 0:
		var item: Dictionary = offer[sel]
		if not Rewards.grant(run, item):
			toast("Your bag is full: make room in the wand editor")
			return
		finished.emit({"taken": item})
	elif id == "skip":
		run.gold += Rewards.SKIP_GOLD
		finished.emit({"taken": null})
