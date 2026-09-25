class_name EndScreen
extends Screen
## The end of a run: victory (World 1 cleared) or defeat, the route taken, and the numbers.

var won := false


func _paint() -> void:
	dim(0.9)
	var v := view()
	var sr := safe()
	var cx := v.x / 2.0
	var y := sr.position.y + 26
	text_center(cx, y, "WORLD 1 CLEARED" if won else "THE GLITCH WINS", GOLD if won else Color("#ff3fa4"), 16, "body")
	y += 14
	text_center(cx, y, "The Infinite Loop is broken. For now." if won else "Your run ends in room %d of %d." % [run.step + 1, Chapter.PLAN.size()], MUTED)
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
	y += 30
	var r := Rect2(cx - 110, y, 220, 88)
	panel(r, won)
	var st := run.stats
	var rows := [
		["Rooms cleared", str(st["rooms"])],
		["Enemies defeated", str(st["kills"])],
		["Damage dealt", str(roundi(float(st["damage"])))],
		["Time", "%d:%02d" % [int(st["time"]) / 60, int(st["time"]) % 60]],
		["Relics / gold", "%d / %d" % [run.relics.size(), run.gold]],
		["Source Fragments", "+%d  (%d to spend)" % [int(SaveGame.load_meta().get("last_fragments", Meta.earned(run))), Meta.fragments()]],
	]
	for i in rows.size():
		text(r.position + Vector2(10, 14 + i * 12), rows[i][0], MUTED)
		text_right(r.end.x - 10, r.position.y + 14 + i * 12, rows[i][1], TEXT, 8, "bold")
	y = r.end.y + 10
	if won:
		text_center(cx, y + 4, "Worlds 2-5 are coming in the full game.", Color("#ffe066"))
		y += 12
	button(Rect2(cx - 116, y, 110, 30), "again", "NEW RUN", "primary")
	button(Rect2(cx + 6, y, 110, 30), "title", "TITLE", "ghost")


func _on_button(id: String) -> void:
	finished.emit({"action": id})
