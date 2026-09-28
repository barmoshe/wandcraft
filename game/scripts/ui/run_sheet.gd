class_name RunSheet
extends Screen
## The portal (0.19): what the next run is. NEW RUN as your hero, CONTINUE a saved run,
## the DAILY run, and the heat (Bug Reports, one tier per win).

var heat := 0
var has_save := false
var meta: Dictionary = {}


func _opened() -> void:
	has_save = SaveGame.has_run()
	meta = SaveGame.load_meta()
	heat = clampi(int(meta.get("heat", 0)), 0, mini(5, int(meta.get("wins", 0))))


func _paint() -> void:
	dim(0.82)
	var v := view()
	var cx := v.x / 2.0
	var r := Rect2(cx - 110, v.y / 2.0 - 102, 220, 204)
	panel(r, true)
	text_center(cx, r.position.y + 18, "THE PORTAL", GOLD, 16, "body")
	var hero := Hub.next_hero(meta)
	# 0.21: two short lines, clear of BACK (one long line ran under it)
	text_center(cx, r.position.y + 36, "As the %s" % RunState.LOADOUTS[hero]["title"], TEXT)
	text_center(cx, r.position.y + 46, "(change it at the Hero Hall)", MUTED)
	var by := r.position.y + 54
	if has_save:
		button(Rect2(cx - 80, by, 160, 30), "continue", "CONTINUE RUN", "primary")
		by += 36
		button(Rect2(cx - 80, by, 160, 26), "new", "NEW RUN")
		by += 32
	else:
		button(Rect2(cx - 80, by, 160, 30), "new", "NEW RUN", "primary")
		by += 36
	if int(meta.get("runs", 0)) > 0:
		button(Rect2(cx - 80, by, 160, 24), "daily", "DAILY RUN", "ghost")
		var dl: Dictionary = meta.get("daily", {})
		var d := Time.get_date_dict_from_system()
		if dl.get("date", "") == "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]:
			text_center(cx, by + 34, "Today's best: %s%s" % ["a win" if dl.get("won", false) else "room %d" % int(dl.get("step", 0)),
				"  ASSIST" if dl.get("assist", false) else ""], MUTED)
		by += 40
	var max_heat := mini(5, int(meta.get("wins", 0)))
	if max_heat > 0:
		button(Rect2(cx - 80, by, 26, 22), "heat_down", "-", "ghost", heat > 0)
		text_center(cx, by + 15, "HEAT  %d" % heat, Style.c("threat:4") if heat > 0 else MUTED, 8, "bold")
		button(Rect2(cx + 54, by, 26, 22), "heat_up", "+", "ghost", heat < max_heat)
		para(Rect2(cx - 100, by + 26, 200, 22), Meta.HEAT[heat], MUTED)
	button(Rect2(r.end.x - 60, r.position.y + 4, 56, 22), "close", "BACK", "ghost")


func _on_button(id: String) -> void:
	match id:
		"close":
			finished.emit({})
		"heat_up":
			heat += 1
		"heat_down":
			heat -= 1
		"continue", "new", "daily":
			Audio.sfx("ui_confirm")
			finished.emit({"action": id, "heat": heat})
