class_name MapScreen
extends Screen
## The World 1 map (D5, design v2): three lanes, two areas of four rooms, every node's icon and
## the threat its room holds. Where you are glows;
## the nodes you can still reach are lit, the rest dimmed. Read-only: you pick the next
## room at the doors, the map is for planning the route (a spring before the boss?).

func _paint() -> void:
	dim(0.92)
	var v := view()
	var sr := safe()
	text_center(v.x / 2.0, sr.position.y + 18, "WORLD 1", GOLD, 16, "body")
	text_center(v.x / 2.0, sr.position.y + 32, Chapter.area_name(run.step), MUTED)
	if run.map.is_empty():
		run.map = Chapter.make_map(run)
	var n := Chapter.PLAN.size()
	var mw := minf(sr.size.x - 40.0, 420.0)
	var gx := mw / (n - 1)
	var x0 := v.x / 2.0 - mw / 2.0
	var cy := sr.position.y + 100.0
	var gy := 34.0
	var pos := func(step: int, lane: int) -> Vector2:
		var cnt: int = (run.map[step] as Array).size()
		return Vector2(x0 + step * gx, cy + (lane - 1) * gy if cnt > 1 else cy)
	# edges first
	for step in n - 1:
		var a: Array = run.map[step]
		var b: Array = run.map[step + 1]
		for la in a.size():
			for lb in b.size():
				var ok_ := a.size() == 1 or b.size() == 1 or absi(la - lb) <= 1
				if not ok_:
					continue
				var lit := step >= run.step and _reachable(step, la) and _reachable(step + 1, lb)
				draw_line(pos.call(step, la), pos.call(step + 1, lb), Color(0.55, 0.5, 0.7, 0.8 if lit else 0.2), 1.0)
	# nodes
	for step in n:
		var nodes: Array = run.map[step]
		for lane in nodes.size():
			var d: Dictionary = nodes[lane]
			var p: Vector2 = pos.call(step, lane)
			var here := step == run.step and (nodes.size() == 1 or lane == run.lane)
			var reach := _reachable(step, lane)
			var col := Chapter.door_color(d) if d["kind"] != &"start" else GOLD
			if here:
				draw_circle(p, 12.0, Color(GOLD, 0.25 + 0.15 * sin(_age * 4.0)))
			draw_circle(p, 9.0, INK)
			draw_circle(p, 8.0, Style.c("night:3") if reach or here else Style.c("night:1"))
			draw_arc(p, 8.0, 0.0, TAU, 20, col if reach or here else col.darkened(0.6), 1.0)
			var key := Chapter.door_key(d)
			var g: String = Icons.DOOR_GLYPH.get(key, "star") if d["kind"] != &"start" else "arrow"
			var ic := Icons.glyph(g, col if reach or here else col.darkened(0.6))
			draw_texture(ic, (p - ic.get_size() / 2.0).round())
			var th := Chapter.threat_of(d)
			if th != &"":
				var ti: Dictionary = Chapter.THREATS[th]
				var tg := Icons.glyph(ti["glyph"], Color(ti["color"]) if reach or here else Color(ti["color"]).darkened(0.6))
				draw_texture(tg, (p + Vector2(9, -13)).round())
	# the two areas
	var split_x := x0 + (Chapter.AREAS[1]["from"] - 0.5) * gx
	draw_line(Vector2(split_x, cy - gy - 18), Vector2(split_x, cy + gy + 18), Color(Style.c("violet:3"), 0.4), 1.0)
	var a1: int = Chapter.AREAS[1]["from"]
	text_center(x0 + gx * (a1 - 1) / 2.0, cy + gy + 30, Chapter.AREAS[0]["name"].to_upper(), MUTED)
	text_center(x0 + gx * (a1 + n - 1) / 2.0, cy + gy + 30, Chapter.AREAS[1]["name"].to_upper(), Style.c("violet:4"))
	# design v2: the threat badges' legend
	var lx := sr.position.x + 20
	for th in Chapter.THREATS:
		var ti: Dictionary = Chapter.THREATS[th]
		icon_at(Icons.glyph(ti["glyph"], Color(ti["color"])), Vector2(lx + 5, cy + gy + 48))
		var ask: String = String(ti["ask"]).split(": ")[1] if String(ti["ask"]).contains(": ") else ti["ask"]
		text(Vector2(lx + 14, cy + gy + 51), ask, MUTED)
		lx += 14 + Game.font("small").get_string_size(ask, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 14
	button(Rect2(v.x / 2.0 - 60, sr.end.y - 32, 120, 28), "close", "BACK", "primary")


## True if the node is still ahead on a path from where the player is.
func _reachable(step: int, lane: int) -> bool:
	if step <= run.step:
		return false
	if (run.map[step] as Array).size() == 1 or run.step == 0:
		return true
	return absi(lane - run.lane) <= step - run.step


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
