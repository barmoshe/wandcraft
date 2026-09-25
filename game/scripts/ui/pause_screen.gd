class_name PauseScreen
extends Screen
## Pause: resume, the relics you carry (tap one to read it), settings, and abandoning the run
## (which needs a second tap to confirm). A run resumed from a save opens here first.

var sel_relic := -1
var confirm_abandon := false
var resumed := false     # opened by "continue": says so in the title


func _paint() -> void:
	dim()
	var v := view()
	var sr := safe()
	text_center(v.x / 2.0, sr.position.y + 22, "PAUSED" if not resumed else "WELCOME BACK", GOLD, 16, "body")
	var step_txt := "Room %d of %d  -  %s" % [run.step + 1, Chapter.PLAN.size(), Chapter.area_name(run.step)]
	text_center(v.x / 2.0, sr.position.y + 36, step_txt, MUTED)
	var cx := v.x / 2.0
	var y := sr.position.y + 48
	# relics
	var rw := minf(sr.size.x - 20, 300.0)
	var rr := Rect2(cx - rw / 2.0, y, rw, 62)
	panel(rr)
	text(rr.position + Vector2(8, 12), "RELICS  %d" % run.relics.size(), MUTED, 8, "bold")
	if run.relics.is_empty():
		text(rr.position + Vector2(8, 30), "None yet. Relic doors and bosses give them.", MUTED)
	for i in run.relics.size():
		var p := rr.position + Vector2(18 + i * 22, 30)
		if p.x > rr.end.x - 10:
			break
		icon_at(Icons.relic(run.relics[i]), p, 1.0 if i != sel_relic else 1.3)
		area(Rect2(p - Vector2(10, 10), Vector2(20, 20)), "relic%d" % i)
	if sel_relic >= 0 and sel_relic < run.relics.size():
		var d: Dictionary = Relics.DEFS[run.relics[sel_relic]]
		text(rr.position + Vector2(8, 48), d["title"], TEXT, 8, "bold")
		text(rr.position + Vector2(8, 58), d["desc"], MUTED)
	y = rr.end.y + 6
	button(Rect2(cx - 70, y, 140, 28), "resume", "RESUME", "primary")
	y += 34
	var bw := 96.0
	var s := Game.settings()
	var rows := [
		[["auto", "AUTO-FIRE", s["auto_fire"]], ["shake", "SHAKE", s["shake"]], ["flash", "FLASH", s["flash"]]],
		[["sound", "SOUND", s["sound"]], ["music", "MUSIC", s["music"]], ["haptics", "VIBRATION", s["haptics"]]],
	]
	for row in rows:
		for k in 3:
			var b: Array = row[k]
			button(Rect2(cx - bw * 1.5 - 6 + k * (bw + 6), y, bw, 26), b[0], "%s %s" % [b[1], "ON" if b[2] else "OFF"])
		y += 30
	y += 4
	button(Rect2(cx - 146, y, 140, 26), "hints", "SHOW TIPS AGAIN", "ghost")
	button(Rect2(cx + 6, y, 140, 26), "abandon", "TAP AGAIN TO ABANDON" if confirm_abandon else "ABANDON RUN", "danger")
	var diag := Game.web_sound()
	if diag != "":
		# web only: lets a tester report why a phone is silent without a Mac inspector
		text_center(cx, sr.end.y - 2, "web %s  -  sound: %s" % [Game.web_build(), diag], MUTED.darkened(0.3))


func _on_button(id: String) -> void:
	if id != "abandon":
		confirm_abandon = false
	match id:
		"resume":
			finished.emit({})
		"abandon":
			if confirm_abandon:
				finished.emit({"abandon": true})
			confirm_abandon = true
		"hints":
			Hints.reset()
			toast("Tips will show again")
		"auto", "shake", "flash", "sound", "music", "haptics":
			var s := Game.settings()
			var key: String = {"auto": "auto_fire", "shake": "shake", "flash": "flash", "sound": "sound", "music": "music", "haptics": "haptics"}[id]
			s[key] = not s[key]
			Game.apply_settings(s)
			SaveGame.save_settings(s)
		_:
			if id.begins_with("relic"):
				var i := int(id.substr(5))
				sel_relic = -1 if sel_relic == i else i
