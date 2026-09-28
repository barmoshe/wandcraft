class_name WallScreen
extends Screen
## The Commit Wall (0.19): your runs as commits, newest first (Slay the Spire 2's Timeline,
## Darkest Dungeon's Graveyard), with the story's commit log beside them.

var _scroll := 0.0
var _max_scroll := 0.0


static func message(e: Dictionary) -> String:
	var where := "w%d room %d" % [int(e.get("world", 0)) + 1, int(e.get("step", 0))]
	if e.get("won", false):
		return "feat: both worlds clean, heat %d" % int(e.get("heat", 0))
	if e.get("quit", false):
		return "revert(%s): abandoned" % where
	var by := EndScreen.killer_text(String(e.get("by", "")))
	return "fix(%s): crashed%s" % [where, (" by " + by) if by != "" else ""]


func _paint() -> void:
	dim(0.94)
	var sr := safe()
	text(sr.position + Vector2(2, 16), "COMMIT WALL", GOLD, 16, "body")
	button(Rect2(sr.end.x - 76, sr.position.y, 76, 24), "close", "BACK", "primary")
	var hist: Array = SaveGame.load_meta().get("history", [])
	text(sr.position + Vector2(2, 30), "git log  (%d runs)" % hist.size(), MUTED, 8, "bold")
	var top := sr.position.y + 38
	var rh := 22.0
	var lw := sr.size.x * 0.62
	var y := top - _scroll
	if hist.is_empty():
		text(Vector2(sr.position.x + 4, top + 12), "Nothing committed yet. Go break something.", MUTED)
	for e in hist:
		if y > top - rh and y < sr.end.y:
			var c := Style.UI_GOOD if e.get("won", false) else (MUTED if e.get("quit", false) else Color("#ff8a9a"))
			draw_circle(Vector2(sr.position.x + 8, y + 8), 3.0, c)
			draw_rect(Rect2(sr.position.x + 7.5, y + 11, 1, rh - 6), Color(0.4, 0.35, 0.5))
			text(Vector2(sr.position.x + 16, y + 11), String(e.get("id", "000000")), Color("#ffd05e"), 8, "bold")
			text(Vector2(sr.position.x + 58, y + 11), message(e), TEXT)
			var meta_line := "%s  %s  %d:%02d  %s" % [RunState.LOADOUTS.get(StringName(e.get("hero", "apprentice")), {"title": "?"})["title"],
				String(e.get("wand", "")), int(e.get("time", 0)) / 60, int(e.get("time", 0)) % 60, String(e.get("date", ""))]
			text(Vector2(sr.position.x + 58, y + 20), meta_line, MUTED)
		y += rh
	_max_scroll = maxf(0.0, hist.size() * rh - (sr.end.y - top))
	# the Source's own log, on the right
	var rx := sr.position.x + lw + 10
	var rr := Rect2(rx, top, sr.end.x - rx, sr.end.y - top)
	panel(rr, false)
	text(rr.position + Vector2(8, 13), "THE SOURCE'S LOG  %d/%d" % [Story.logs_found().size(), Story.LOGS.size()], Color("#5ce1ff"), 8, "bold")
	var got: Array = Story.logs_found().map(func(l: Dictionary) -> String: return l["id"])
	var ly := rr.position.y + 26
	for l in Story.LOGS:
		if ly > rr.end.y - 8:
			break
		var have: bool = got.has(l["id"])
		text(Vector2(rr.position.x + 8, ly), (String(l["id"]) if have else "??????"), Color("#ffd05e") if have else MUTED, 8, "bold")
		if have:
			ly += para(Rect2(rr.position.x + 50, ly - 8, rr.size.x - 56, 20), String(l["text"]), TEXT)
		else:
			ly += 11


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
