class_name EndScreen
extends Screen
## The end of a run: victory (World 1 cleared) or defeat, the route taken, the wand you
## ended with (design v3), what ended the run, the numbers, the goals done and the next one.

var won := false
var killed_by := ""   # Player.last_hurt_by ("shot:weaver", "touch:The Infinite Loop", "spikes")
var duck_line := ""   # the Duck's word on a death (Story.line("death"))


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
	text_center(cx, y, "RUN COMPLETE" if won else "THE GLITCH WINS", GOLD if won else Color("#ff3fa4"), 16, "body")
	y += 14
	var lost_at := "Your run ends in %s, room %d of %d." % [Chapter.WORLDS[run.world]["name"], run.step, Chapter.PLAN.size() - 1]
	text_center(cx, y, "Deadlock is broken. Both worlds are clear." if won else lost_at, MUTED)
	if run.daily != "":
		var dl: Dictionary = SaveGame.load_meta().get("daily", {})
		text_center(cx, y + 11, "DAILY RUN %s  -  best today: %s" % [run.daily, "a win" if dl.get("won", false) else "room %d" % int(dl.get("step", 0))], GOLD)
	elif duck_line != "":
		var f := Game.font("small")
		var w := f.get_string_size(duck_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_texture(DuckArt.face(DuckArt.SMUG if not won else DuckArt.PLEASED), Vector2(cx - w / 2.0 - 16, y + 2).round(), Color(1, 1, 1, 0.9))
		text_center(cx, y + 11, duck_line, Color("#ffd05e"))
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
	var r := Rect2(cx - 222, y, 214, 84)
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
	var gr := Rect2(cx + 8, y, 214, 84)
	panel(gr, true)
	var meta := SaveGame.load_meta()
	var got: Array = meta.get("last_bounties", [])
	# every line is measured, so a long ticket wraps inside the panel, never over the next line
	var gx := gr.position.x + 10
	var gw := gr.size.x - 20
	var gy := gr.position.y + 4
	# meta v2: the Bits this run paid, then the bounties it fixed, then the next ticket
	text(Vector2(gx, gy + 10), "+%d BITS" % int(meta.get("last_bits", 0)), Color("#7cf0c8"), 8, "bold")
	text_right(gr.end.x - 10, gy + 10, "%d in the bank" % int(meta.get("bits", 0)), MUTED)
	gy += 14
	var nxt := Meta.open_bounties()
	if not got.is_empty():
		text(Vector2(gx, gy + 10), "BOUNTIES FIXED", Style.UI_GOOD, 8, "bold")
		gy += 12
		var shown := got.slice(0, 1 if not nxt.is_empty() else 2)
		for bid in shown:
			var b := Meta.bounty(bid)
			var more := " (+%d more)" % (got.size() - 1) if shown.size() == 1 and got.size() > 1 else ""
			para(Rect2(gx, gy, gw, 11), "%s: +%d Bits%s" % [b.get("text", bid), int(b.get("bits", 0)), more], TEXT)
			gy += 11
		gy += 3
	if nxt.is_empty():
		text(Vector2(gx, gy + 10), "Every bounty fixed. Turn up the heat.", GOLD)
	else:
		text(Vector2(gx, gy + 10), "NEXT BOUNTY", GOLD, 8, "bold")
		gy += 12
		var room := gr.end.y - 4 - gy
		para(Rect2(gx, gy, gw, maxf(11.0, room)), "%s  (+%d Bits)" % [nxt[0]["text"], int(nxt[0]["bits"])], TEXT)
	y = r.end.y + 10
	button(Rect2(cx - 116, y, 110, 30), "again", "NEW RUN", "primary")
	button(Rect2(cx + 6, y, 110, 30), "title", "WORKSHOP", "ghost")
	if run.daily != "":
		button(Rect2(cx + 122, y, 96, 30), "share", "COPY RESULT", "ghost")


func _on_button(id: String) -> void:
	if id == "share":
		# design v3: a result line to paste to a friend
		var rule := Chapter.daily_rule(run.daily)
		DisplayServer.clipboard_set("Wandcraft daily %s (%s): %s" % [run.daily, rule["text"],
			"cleared World 1" if won else "reached room %d of %d" % [run.step, Chapter.PLAN.size() - 1]])
		toast("Result copied")
		return
	finished.emit({"action": id})
