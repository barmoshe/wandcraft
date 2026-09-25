class_name RewardScreen
extends Screen
## Choose 1 of 3. Tapping a card only inspects it (highlight); TAKE confirms, so a stray tap
## never picks a reward. SKIP pays a little gold. A spell goes to the bag (D2: placing it
## is the player's call), so TAKE & EQUIP opens the wand editor right after.
## Result: {"taken": item or null, "equip": bool}.

const TITLES := {
	&"start": ["BEFORE YOU GO", "Pick your hero"],
	&"spell": ["SPELL", "Pick one spell"],
	&"relic": ["RELIC", "Pick one relic"],
	&"challenge": ["CHALLENGE CLEARED", "Pick your prize"],
	&"glitch": ["GLITCH CLEARED", "Corrupted relics: power with a price"],
	&"secret": ["A SECRET", "Pick one"],
	&"altar": ["THE ALTAR", "Each gift costs 15% of your max HP"],
	&"terminal": ["DEBUG TERMINAL", "Apply one patch"],
	&"wand": ["WAND", "Pick one"],
	&"mini": ["MINI-BOSS DEFEATED", "Pick your prize"],
	&"boss": ["BOSS DEFEATED", "Pick your prize"],
}

var kind: StringName = &"spell"
var offer: Array = []
var sel := -1
var _layouts: Dictionary = {}   # card index -> the wand laid out with it (spells), cached


func _paint() -> void:
	dim()
	var v := view()
	var sr := safe()
	var t: Array = TITLES.get(kind, ["REWARD", "Pick one"])
	text_center(v.x / 2.0, sr.position.y + 16, t[0], GOLD, 16, "body")
	text_center(v.x / 2.0, sr.position.y + 29, t[1], MUTED)
	var n := offer.size()
	var gap := 10.0
	var cw := minf(170.0, (sr.size.x - gap * (n - 1)) / maxf(1, n))
	var y0 := sr.position.y + 36
	var bh := 28.0
	var ch := minf(200.0, sr.end.y - y0 - bh - 8.0)
	var total := cw * n + gap * (n - 1)
	var x0 := v.x / 2.0 - total / 2.0
	for i in n:
		var r := Rect2(x0 + i * (cw + gap), y0, cw, ch)
		_card(r, offer[i], i == sel)
		area(r, "card%d" % i)
	var by := y0 + ch + 8
	var can_take: bool = sel >= 0 and not offer[sel].get("locked", false)
	if kind == &"start":
		# the start: only TAKE, centred under the cards
		button(Rect2(v.x / 2.0 - 55.0, by, 110, bh), "take", "TAKE", "primary", can_take)
		return
	# TAKE & EQUIP only where a spell is on offer (it opens the wand editor)
	var has_spell := offer.any(func(o: Dictionary) -> bool: return o["t"] == &"spell")
	var nb := 3 if has_spell else 2
	var bw := minf(120.0, (sr.size.x - 16.0) / 3.0)
	var bx := v.x / 2.0 - (bw * nb + 8.0 * (nb - 1)) / 2.0
	# a lesson's prize is the lesson: no skipping it
	button(Rect2(bx, by, bw, bh), "skip", "SKIP  +%d GOLD" % Rewards.SKIP_GOLD, "ghost", not Tutorial.active(run))
	button(Rect2(bx + bw + 8, by, bw, bh), "take", "TAKE", "primary", can_take)
	if has_spell:
		var spell: bool = can_take and offer[sel]["t"] == &"spell"
		button(Rect2(bx + (bw + 8) * 2, by, bw, bh), "equip", "TAKE & EQUIP", "primary", spell)


func _card(r: Rect2, item: Dictionary, selected: bool) -> void:
	var rar := Rewards.item_rarity(item)
	var rc := rarity_color(rar)
	if selected:
		r.position.y -= 3.0
		draw_rect(r.grow(4.0), Color(Style.UI_GOLD, 0.12))
	panel(r, selected)
	var cx := r.get_center().x
	# header band in the rarity color: the rarity on the left, what the item is on the right
	var hb := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 12))
	draw_rect(hb, rc.darkened(0.55))
	draw_rect(Rect2(hb.position, Vector2(hb.size.x, 1)), rc.darkened(0.2))
	text(hb.position + Vector2(4, 9), Style.RARITY_NAMES[clampi(rar, 0, 3)].to_upper(), rc.lightened(0.2))
	text_right(hb.end.x - 4, hb.position.y + 9, kind_label(item).to_upper(), Style.c("bone:3"))
	var lv := Rewards.level_after(run, item["id"]) if item["t"] == &"spell" else 1
	var desc := Rewards.item_desc(item, lv)
	var kl := kind_label(item).to_lower()
	var tags: Array = item_tags(item).filter(func(t: String) -> bool: return not kl.contains(t.to_lower()))
	# D3: what this pick would switch on with what you already have
	var en: Array = Rewards.enables(run, item).map(func(t: String) -> String: return "+ " + t)
	if lv > 1:
		en.push_front("Merges to level %d" % lv)
	var gain := _gain(item, lv)
	if gain >= 1.0:
		en.push_front("+%d damage/s" % roundi(gain))
	var foot := _footer(item, lv)
	# the body gets whatever the header, icon and chips leave; a long text shrinks the icon
	var chip_h := (12.0 if not tags.is_empty() else 0.0) + (14.0 if not en.is_empty() else 0.0)
	var body_w := r.size.x - 14.0
	var need := _wrap(Game.font("small"), desc, body_w, 8).size() * 11.0
	var bottom := r.end.y - (16.0 if foot[0] != "" else 4.0)
	var compact := r.position.y + 72.0 + chip_h + need > bottom
	var ic := Vector2(cx, r.position.y + (26.0 if compact else 33.0))
	if not compact:
		draw_circle(ic, 20.0, Color(rc, 0.08))
		draw_circle(ic, 14.0, Color(rc, 0.1))
		draw_set_transform(ic + Vector2(0, 17), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 14.0, Style.c("night:3"))
		draw_set_transform(Vector2.ZERO)
	icon_at(item_icon(item), ic + Vector2(0, sin(_age * 2.0 + r.position.x) * (1.0 if selected else 0.0)), 1.0 if compact else 2.0)
	var y := r.position.y + (46.0 if compact else 64.0)
	text_center(cx, y, Rewards.item_title(item) + "+".repeat(lv - 1), TEXT, 8, "bold")
	y += 4
	y += chips(cx, y, tags)
	if not en.is_empty():
		y += chips(cx, y + 2, en, Style.c("gold:4")) + 2
	para(Rect2(r.position.x + 7, y + 1, body_w, bottom - y - 1), desc, Style.c("bone:3"))
	if foot[0] != "":
		draw_rect(Rect2(r.position.x + 3, r.end.y - 14, r.size.x - 6, 1), RIM)
		_fit_line(r, foot[0], foot[1], foot[2])
	if item["t"] == &"loadout":
		# the starting spell sits by the wand
		var first: StringName = RunState.LOADOUTS[item["id"]]["spells"].filter(func(x: Variant) -> bool: return x != null)[0]
		icon_at(Icons.spell(Catalog.spell(first)), ic + Vector2(22, 10))
	if item.get("locked", false):
		# a start you have not unlocked yet: greyed, with a lock over the icon
		draw_rect(r.grow(-2.0), Color(Style.c("night:1"), 0.55))
		var lk := ic + Vector2(0, -2)
		draw_rect(Rect2(lk + Vector2(-6, -1), Vector2(12, 10)), Style.c("gold:2"))
		draw_rect(Rect2(lk + Vector2(-6, -1), Vector2(12, 1)), Style.c("gold:4"))
		draw_arc(lk + Vector2(0, -2), 4.0, PI, TAU, 8, Style.c("gold:3"), 2.0)
		draw_rect(Rect2(lk + Vector2(-1, 3), Vector2(2, 3)), Style.c("night:0"))


## Damage per second this pick adds to the wand in hand, measured on the firing range
## (0 while it is measured, or when it adds nothing there). Spells: as an editing player
## would slot it. Relics: the same wand with the relic.
func _gain(item: Dictionary, lv: int) -> float:
	if run == null or run.wands.is_empty() or not (item["t"] == &"spell" or item["t"] == &"relic"):
		return 0.0
	var w := run.wand()
	var probe := WandLab.probe(get_tree())
	var now := probe.dps(run, w.def, w.slots)
	var then := -1.0
	if item["t"] == &"spell":
		var key := "%s%d" % [item["id"], lv]
		if not _layouts.has(key):
			_layouts[key] = _layout_with(item["id"], lv)
		then = probe.dps(run, w.def, _layouts[key])
	else:
		var scratch := RunState.new()
		scratch.relics = run.relics.duplicate()
		scratch.relics.append(item["id"])
		then = probe.dps(scratch, w.def, w.slots)
	if now < 0.0 or then < 0.0:
		return 0.0
	return then - now


## Where a player would put this spell: a boost in the nearest empty slot on the left of the
## first spell (what it is for; the planner's mana caution can leave it out), anything else
## as the editing bot lays it out.
func _layout_with(id: StringName, lv: int) -> Array:
	var slots: Array = run.wand().slots.duplicate(true)
	if fam(Catalog.spell(id)) == Fam.BOOST:
		var first := -1
		for i in slots.size():
			if slots[i] != null and Catalog.is_caster(Catalog.spell(slots[i]["id"])):
				first = i
				break
		for i in range(first - 1, -1, -1):
			if slots[i] == null:
				slots[i] = {"id": id, "lv": lv}
				return slots
	return WandPlanner.slots_with(run, id, lv)


## The card's bottom line: [long, short, color], or ["", "", c] for none.
func _footer(item: Dictionary, lv: int) -> Array:
	var cyan := Style.c("cyan:4")
	if item.has("hp_cost"):
		var pct := roundi(float(item["hp_cost"]) * 100.0)
		return ["COSTS %d%% OF MAX HP" % pct, "-%d%% MAX HP" % pct, Style.c("threat:4")]
	match item["t"]:
		&"spell":
			var st := spell_stats(item["id"], lv)
			return [st, "  ".join(st.split("  ").slice(0, 2)), cyan]   # short: mana and damage only
		&"loadout":
			if item.get("locked", false):
				var goal := String(Meta.goal_for(item["id"]).get("text", "")).to_upper()
				return ["UNLOCK: " + goal, "LOCKED", GOLD]
			var wd := Catalog.wand(RunState.LOADOUTS[item["id"]]["wand"])
			return ["%d SLOTS  %d MANA" % [wd.slots, int(wd.max_mana)], "%d SLOTS  %d MP" % [wd.slots, int(wd.max_mana)], cyan]
	return ["", "", cyan]


## The card's bottom stats line, centred; the short form when the long one would overflow.
func _fit_line(r: Rect2, long: String, short: String, c := Style.c("cyan:4")) -> void:
	var f := Game.font("small")
	var s := long if f.get_string_size(long, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= r.size.x - 10.0 else short
	text_center(r.get_center().x, r.end.y - 5, s, c)


## Preselect the one card you can take when there is only one (the start, lesson prizes).
func _opened() -> void:
	var free := []
	for i in offer.size():
		if not offer[i].get("locked", false):
			free.append(i)
	if free.size() == 1:
		sel = free[0]


func _on_button(id: String) -> void:
	if id.begins_with("card"):
		var i := int(id.substr(4))
		if offer[i].get("locked", false):
			Audio.sfx("deny", 0.0)
			toast("Unlock: %s" % Meta.goal_for(offer[i]["id"]).get("text", ""))
			return
		sel = -1 if sel == i else i
		Audio.sfx("ui", 0.05)
	elif (id == "take" or id == "equip") and sel >= 0:
		var item: Dictionary = offer[sel]
		if not Rewards.grant(run, item):
			Audio.sfx("deny", 0.0)
			toast("Your bag is full. Skip this one to take the gold instead.")
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
