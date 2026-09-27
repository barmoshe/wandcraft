class_name CodexScreen
extends Screen
## The Codex (design v2): the goals book. Each goal is something to do in a run; doing it
## unlocks a named bundle for every run after (Meta.GOALS). Left: the goals, done ones
## ticked. Right: the picked goal's bundle, and tapping an item reads it. Drag or scroll
## the list.

const ROW := 24.0
const GAP := 3.0

var tab := "goals"   # "goals" or "logs" (the commit log, research/story.md)
var sel := 0
var sel_item := -1
var _scroll := 0.0
var _max_scroll := 0.0


func _paint() -> void:
	dim(0.94)
	var sr := safe()
	text(sr.position + Vector2(2, 16), "CODEX", GOLD, 16, "body")
	var done := Meta.goals_done()
	button(Rect2(sr.position.x + 68, sr.position.y, 84, 24), "tab_goals", "GOALS %d/%d" % [done.size(), Meta.GOALS.size()], "primary" if tab == "goals" else "ghost")
	button(Rect2(sr.position.x + 156, sr.position.y, 84, 24), "tab_logs", "LOGS %d/%d" % [Story.logs_found().size(), Story.LOGS.size()], "primary" if tab == "logs" else "ghost")
	button(Rect2(sr.end.x - 76, sr.position.y, 76, 24), "close", "BACK", "primary")
	if tab == "logs":
		_paint_logs(sr)
		return
	text(sr.position + Vector2(2, 32), "Do a goal in any run to unlock what it lists, for every run after.", MUTED)
	# the goals
	var lw := minf(sr.size.x * 0.5, 250.0)
	var top := sr.position.y + 40
	var bottom := sr.end.y
	var n := Meta.GOALS.size()
	for i in n:
		var g: Dictionary = Meta.GOALS[i]
		var r := Rect2(sr.position.x, top + i * (ROW + GAP) - _scroll, lw, ROW)
		if r.end.y < top or r.position.y > bottom:
			continue
		var have: bool = done.has(g["id"])
		panel(r, i == sel)
		# a tick when done, an empty box when not
		var b := Rect2(r.position + Vector2(6, 7), Vector2(10, 10))
		draw_rect(b, INK)
		draw_rect(b.grow(-1.0), Style.c("night:2"))
		if have:
			draw_line(b.position + Vector2(2, 5), b.position + Vector2(4, 8), Style.UI_GOOD, 2.0)
			draw_line(b.position + Vector2(4, 8), b.position + Vector2(9, 2), Style.UI_GOOD, 2.0)
		text(r.position + Vector2(22, 15), g["text"], TEXT if not have else MUTED, 8)
		area(r, "goal%d" % i)
	_max_scroll = maxf(0.0, n * (ROW + GAP) - (bottom - top))
	# the picked goal's bundle
	var dr := Rect2(sr.position.x + lw + 8, top, sr.size.x - lw - 8, bottom - top)
	panel(dr, true)
	var g: Dictionary = Meta.GOALS[clampi(sel, 0, n - 1)]
	var have: bool = done.has(g["id"])
	text(dr.position + Vector2(8, 13), "UNLOCKED" if have else "UNLOCKS", Style.UI_GOOD if have else GOLD, 8, "bold")
	var items: Array = g["unlocks"]
	var y := dr.position.y + 20
	for k in items.size():
		var id: StringName = items[k]
		var ir := Rect2(dr.position.x + 6, y, dr.size.x - 12, 18)
		if k == sel_item:
			draw_rect(ir, Color(GOLD, 0.12))
		icon_at(_icon(id), ir.position + Vector2(9, 9), 1.0, Color.WHITE if have else Color(0.55, 0.5, 0.65))
		text(ir.position + Vector2(22, 12), Meta.title(id), TEXT if have else MUTED, 8, "bold")
		text_right(ir.end.x - 2, ir.position.y + 12, _kind(id), MUTED.darkened(0.2))
		area(ir, "item%d" % k)
		y += 19
		if y > dr.end.y - 60:
			break
	if sel_item >= 0 and sel_item < items.size():
		draw_rect(Rect2(dr.position.x + 6, y + 2, dr.size.x - 12, 1), RIM)
		para(Rect2(dr.position.x + 8, y + 6, dr.size.x - 16, dr.end.y - y - 10), _desc(items[sel_item]), MUTED)


## The commit log: every entry found so far, in log order; the rest wait as "??????".
func _paint_logs(sr: Rect2) -> void:
	text(sr.position + Vector2(2, 32), "The Source's commit log. Debug Terminals and story beats give up the entries.", MUTED)
	var got: Array = Story.logs_found().map(func(l: Dictionary) -> String: return l["id"])
	var top := sr.position.y + 40
	var rh := minf(20.0, (sr.end.y - top) / Story.LOGS.size())
	for i in Story.LOGS.size():
		var l: Dictionary = Story.LOGS[i]
		var r := Rect2(sr.position.x, top + i * rh, sr.size.x, rh - 2)
		var have: bool = got.has(l["id"])
		draw_rect(r, Color(0.1, 0.07, 0.18, 0.8 if have else 0.4))
		var y := r.position.y + r.size.y / 2.0 + 3
		text(Vector2(r.position.x + 6, y), "commit " + (String(l["id"]) if have else "??????"), Style.c("cyan:4") if have else MUTED, 8, "bold")
		if have:
			text(Vector2(r.position.x + 96, y), String(l["who"]), GOLD)
			text(Vector2(r.position.x + 160, y), String(l["text"]), TEXT)


func _icon(id: StringName) -> Texture2D:
	if RunState.LOADOUTS.has(id):
		return Icons.glyph("wand", Catalog.wand(RunState.LOADOUTS[id]["wand"]).color)
	if Catalog.spells().has(id):
		return Icons.spell(Catalog.spell(id))
	if Relics.DEFS.has(id):
		return Icons.relic(id)
	if Catalog.wands().has(id):
		return Hero.wand_angles(Hero.gem_ramp(Catalog.wand(id).color))[14]
	return Icons.glyph("box", Style.c("gold:3"))


func _kind(id: StringName) -> String:
	if RunState.LOADOUTS.has(id):
		return "HERO"
	if Catalog.spells().has(id):
		return kind_name(Catalog.spell(id)).to_upper()
	if Relics.DEFS.has(id):
		return "RELIC"
	if Catalog.wands().has(id):
		return "WAND"
	return "UPGRADE"


func _desc(id: StringName) -> String:
	if RunState.LOADOUTS.has(id):
		return Rewards.hero_text(id)
	if Catalog.spells().has(id):
		return Catalog.spell(id).text_at(1)
	if Relics.DEFS.has(id):
		var fl: String = Relics.DEFS[id].get("flavor", "")
		return Rewards.item_desc({"t": &"relic", "id": id}) + ("  (\"%s\")" % fl if fl != "" else "")
	if Catalog.wands().has(id):
		return Rewards.wand_desc(Catalog.wand(id))
	return "Every run starts with one more empty slot on your first wand."


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
	elif id == "tab_goals" or id == "tab_logs":
		tab = id.substr(4)
		_scroll = 0.0
	elif id.begins_with("goal"):
		sel = int(id.substr(4))
		sel_item = -1
		Audio.sfx("ui")
	elif id.begins_with("item"):
		var k := int(id.substr(4))
		sel_item = -1 if sel_item == k else k
		Audio.sfx("ui")
