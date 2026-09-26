class_name EndScreen
extends Screen
## The end of a run: victory (World 1 cleared) or defeat, the route taken, the wand you
## ended with (design v3), what ended the run, the numbers, the goals done and the next one.

var won := false
var killed_by := ""   # Player.last_hurt_by ("shot:weaver", "touch:The Infinite Loop", "spikes")


## "a Hex Weaver's shot", "The Infinite Loop", "the spikes".
static func killer_text(by: String) -> String:
	if by == "":
		return ""
	var parts := by.split(":")
	var how := parts[0]
	var who := parts[1] if parts.size() > 1 else ""
	if who == "":
		return "the %s" % how
	var name := String(Enemy.DEFS[StringName(who)]["title"]) if Enemy.DEFS.has(StringName(who)) else who
	match how:
		"shot", "burst", "trail":
			return "%s's %s" % [name, how]
		"slam":
			return "%s's slam" % name
	return name


func _paint() -> void:
	dim(0.9)
	var v := view()
	var sr := safe()
	var cx := v.x / 2.0
	var y := sr.position.y + 26
	text_center(cx, y, "WORLD 1 CLEARED" if won else "THE GLITCH WINS", GOLD if won else Color("#ff3fa4"), 16, "body")
	y += 14
	text_center(cx, y, "The Infinite Loop is broken. For now." if won else "Your run ends in room %d of %d." % [run.step, Chapter.PLAN.size() - 1], MUTED)
	if run.daily != "":
		var dl: Dictionary = SaveGame.load_meta().get("daily", {})
		text_center(cx, y + 11, "DAILY RUN %s  -  best today: %s" % [run.daily, "a win" if dl.get("won", false) else "room %d" % int(dl.get("step", 0))], GOLD)
	y += 14
	# the route taken
	var n := Chapter.PLAN.size()
	var pw := n * 20.0
	for i in n:
		var p := Vector2(cx - pw / 2.0 + i * 20.0 + 10, y + 10)
		var key := "start" if i == 0 else (String(run.path[i - 1]) if i - 1 < run.path.size() else "")
		if i > 0:
			draw_rect(Rect2(p - Vector2(14, 0), Vector2(8, 1)), Color(0.5, 0.45, 0.6))
		if key == "start":
			draw_circle(p, 5.0, GOLD)
		elif key != "":
			icon_at(Icons.door(key), p)
		else:
			draw_arc(p, 5.0, 0.0, TAU, 12, Color(0.4, 0.35, 0.5), 1.0)
	y += 24
	# the wand you ended with, in its sockets (design v3: the build is the story of the run)
	var w: WandState = run.wand()
	var sw := w.slots.size() * 22.0
	text_right(cx - sw / 2.0 - 8, y + 14, w.def.title.to_upper(), MUTED)
	for i in w.slots.size():
		var c := Vector2(cx - sw / 2.0 + i * 22.0 + 11.0, y + 10)
		var s: Variant = w.slots[i]
		if s == null:
			draw_arc(c, 8.0, 0.0, TAU, 16, Color(0.4, 0.35, 0.5), 1.0)
			continue
		var d := Catalog.spell(s["id"])
		socket_shape(c, 9.0, fam(d), Color("#1a1330"), fam_color(d))
		icon_at(Icons.spell(d), c)
	if not won and killer_text(killed_by) != "":
		text(Vector2(cx + sw / 2.0 + 8, y + 14), "Ended by " + killer_text(killed_by), Color("#ff8a9a"))
	y += 26
	# the numbers on the left, the goals on the right
	var r := Rect2(cx - 222, y, 214, 76)
	panel(r, won)
	var st := run.stats
	var rows := [
		["Rooms cleared", str(st["rooms"])],
		["Enemies defeated", str(st["kills"])],
		["Best hit", str(roundi(float(st.get("max_hit", 0.0))))],
		["Time", "%d:%02d" % [int(st["time"]) / 60, int(st["time"]) % 60]],
		["Relics / gold", "%d / %d" % [run.relics.size(), run.gold]],
	]
	for i in rows.size():
		text(r.position + Vector2(10, 14 + i * 12), rows[i][0], MUTED)
		text_right(r.end.x - 10, r.position.y + 14 + i * 12, rows[i][1], TEXT, 8, "bold")
	var gr := Rect2(cx + 8, y, 214, 76)
	panel(gr, true)
	var got: Array = SaveGame.load_meta().get("last_goals", [])
	var gy := gr.position.y + 14
	if not got.is_empty():
		text(Vector2(gr.position.x + 10, gy), "GOALS DONE", Style.UI_GOOD, 8, "bold")
		for gid in got.slice(0, 2):
			var g: Dictionary = Meta.GOALS.filter(func(x: Dictionary) -> bool: return x["id"] == gid)[0]
			gy += 11
			text(Vector2(gr.position.x + 10, gy), "%s: %s" % [g["text"], Meta.title(g["unlocks"][0])], TEXT)
		gy += 14
	var nxt := Meta.open_goals()
	if nxt.is_empty():
		text(Vector2(gr.position.x + 10, gy), "Every goal done. Turn up the heat.", GOLD)
	else:
		text(Vector2(gr.position.x + 10, gy), "NEXT GOAL", GOLD, 8, "bold")
		para(Rect2(gr.position.x + 10, gy + 2, gr.size.x - 20, 22), nxt[0]["text"], TEXT)
		var names: Array = (nxt[0]["unlocks"] as Array).map(func(id: StringName) -> String: return Meta.title(id))
		para(Rect2(gr.position.x + 10, gy + 13, gr.size.x - 20, 22), "Unlocks " + ", ".join(names.slice(0, 2)), MUTED)
	y = r.end.y + 10
	button(Rect2(cx - 116, y, 110, 30), "again", "NEW RUN", "primary")
	button(Rect2(cx + 6, y, 110, 30), "title", "TITLE", "ghost")


func _on_button(id: String) -> void:
	finished.emit({"action": id})
