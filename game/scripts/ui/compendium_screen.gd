class_name CompendiumScreen
extends Screen
## The Compendium (0.19, replaces the Codex): everything in the game, filled in as you meet
## it. An entry is "?" until seen, dim once seen, bright once used (a spell or wand cast, a
## relic held); enemies count kills, and five kills add the Guild's field notes (Hollow
## Knight's Hunter's Journal). Locked entries say where they come from.

const TABS := ["spells", "relics", "wands", "enemies"]
const CELL := 22.0
const NOTES_AT := 5

var tab := "spells"
var sel := -1
var _scroll := 0.0
var _max_scroll := 0.0
var _ids: Array = []
var _dex: Dictionary = {}


func _opened() -> void:
	_dex = Meta.dex()
	_list()


func _list() -> void:
	match tab:
		"spells":
			_ids = Catalog.spells().keys().filter(func(id: StringName) -> bool: return id != &"apprentice")
		"relics":
			_ids = Relics.DEFS.keys()
		"wands":
			_ids = Catalog.wands().keys().filter(func(id: StringName) -> bool: return id != &"apprentice")
		"enemies":
			_ids = Enemy.DEFS.keys().filter(func(id: StringName) -> bool: return Enemy.DEFS[id].get("ai", &"") != &"part")


func _key() -> String:
	return {"spells": "s", "relics": "r", "wands": "w", "enemies": "e"}[tab]


## 0 unmet, 1 seen, 2 used (enemies: 1 seen, 2 with field notes).
func level(id: StringName) -> int:
	var d: Dictionary = _dex.get(_key(), {})
	if not d.has(String(id)):
		return 0
	if tab == "enemies":
		return 2 if int(d[String(id)]) >= NOTES_AT else 1
	return int(d[String(id)])


func _icon(id: StringName) -> Texture2D:
	match tab:
		"spells": return Icons.spell(Catalog.spell(id))
		"relics": return Icons.relic(id)
		"wands": return Hero.wand_angles(Hero.gem_ramp(Catalog.wand(id).color))[14]
	return Bestiary.frames(String(id))[0]


func _title(id: StringName) -> String:
	if tab == "enemies":
		return String(Enemy.DEFS[id].get("title", id))
	return Meta.title(id)


func _paint() -> void:
	dim(0.94)
	var sr := safe()
	text(sr.position + Vector2(2, 16), "COMPENDIUM", GOLD, 16, "body")
	button(Rect2(sr.end.x - 76, sr.position.y, 76, 24), "close", "BACK", "primary")
	var tx := sr.position.x
	for t in TABS:
		var d: Dictionary = _dex.get({"spells": "s", "relics": "r", "wands": "w", "enemies": "e"}[t], {})
		var total := _count(t)
		var lab := "%s %d/%d" % [t.to_upper(), mini(d.size(), total), total]
		var w := maxf(62.0, Game.font("small").get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 12)
		button(Rect2(tx, sr.position.y + 24, w, 22), "tab:" + t, lab, "primary" if tab == t else "ghost")
		tx += w + 4
	var top := sr.position.y + 52
	var lw := minf(sr.size.x * 0.55, 270.0)
	var per := int(lw / CELL)
	for i in _ids.size():
		var c := Vector2(sr.position.x + CELL / 2.0 + (i % per) * CELL, top + CELL / 2.0 + (i / per) * CELL - _scroll)
		if c.y < top or c.y > sr.end.y - 4:
			continue
		var id: StringName = _ids[i]
		var lv := level(id)
		draw_circle(c, 9.5, Color(0.1, 0.07, 0.18) if i != sel else Color(GOLD, 0.35))
		if lv == 0:
			text_center(c.x, c.y + 3, "?", MUTED.darkened(0.3), 8, "bold")
		else:
			icon_at(_icon(id), c, 1.0, Color.WHITE if lv >= 2 else Color(0.6, 0.55, 0.7, 0.8))
		if Meta.is_locked(id):
			draw_rect(Rect2(c + Vector2(4, 4), Vector2(4, 4)), Color("#7cf0c8"))
		area(Rect2(c - Vector2(CELL, CELL) / 2.0, Vector2(CELL, CELL)), "cell%d" % i)
	_max_scroll = maxf(0.0, ceilf(float(_ids.size()) / per) * CELL - (sr.end.y - top))
	# the picked entry
	var dr := Rect2(sr.position.x + lw + 8, top, sr.size.x - lw - 8, sr.end.y - top)
	panel(dr, true)
	if sel < 0 or sel >= _ids.size():
		para(Rect2(dr.position.x + 8, dr.position.y + 6, dr.size.x - 16, 60), "Tap an entry. It fills in as you meet things in your runs: seen, then used. A small green mark means it is still locked.", MUTED)
		return
	var id: StringName = _ids[sel]
	var lv := level(id)
	var x := dr.position.x + 8
	var y := dr.position.y + 14
	if lv == 0:
		text(Vector2(x, y), "NOT MET YET", MUTED, 8, "bold")
		if Meta.is_locked(id):
			para(Rect2(x, y + 6, dr.size.x - 16, 30), Meta.source_text(id), Color("#7cf0c8"))
		return
	icon_at(_icon(id), Vector2(x + 10, y + 4), 2.0)
	text(Vector2(x + 28, y + 2), _title(id), GOLD, 8, "bold")
	text(Vector2(x + 28, y + 12), ["", "SEEN", "USED" if tab != "enemies" else "FIELD NOTES"][lv], Style.UI_GOOD if lv >= 2 else MUTED)
	y += 26
	para(Rect2(x, y, dr.size.x - 16, dr.end.y - y - 20), _desc(id, lv), TEXT)
	if Meta.is_locked(id):
		text(Vector2(x, dr.end.y - 8), Meta.source_text(id), Color("#7cf0c8"))


func _desc(id: StringName, lv: int) -> String:
	match tab:
		"spells":
			return Catalog.spell(id).text_at(1)
		"relics":
			var fl: String = Relics.DEFS[id].get("flavor", "")
			return Rewards.item_desc({"t": &"relic", "id": id}) + ("  (\"%s\")" % fl if fl != "" else "")
		"wands":
			return Rewards.wand_desc(Catalog.wand(id))
	var kills := int((_dex.get("e", {}) as Dictionary).get(String(id), 0))
	var d: Dictionary = Enemy.DEFS[id]
	if lv < 2:
		return "Defeated %d. Defeat %d to read the Guild's field notes." % [kills, NOTES_AT]
	return "Defeated %d.\nHP %d, speed %d, contact %d. Role: %s." % [kills, int(d.get("hp", 0)), int(d.get("spd", 0)), int(d.get("dmg", 0)), String(d.get("role", d.get("ai", "")))]


func _count(t: String) -> int:
	match t:
		"spells": return Catalog.spells().size() - 1
		"relics": return Relics.DEFS.size()
		"wands": return Catalog.wands().size() - 1
	return Enemy.DEFS.keys().filter(func(id: StringName) -> bool: return Enemy.DEFS[id].get("ai", &"") != &"part").size()


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
	elif id.begins_with("tab:"):
		tab = id.substr(4)
		sel = -1
		_scroll = 0.0
		_list()
	elif id.begins_with("cell"):
		var k := int(id.substr(4))
		sel = -1 if sel == k else k
		Audio.sfx("ui")
