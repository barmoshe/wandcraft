class_name PauseScreen
extends Screen
## Pause: resume, the relics you carry (tap one to read it), settings, and abandoning the run
## (which needs a second tap to confirm). A run resumed from a save opens here first.

var sel_relic := -1
var confirm_abandon := false
var resumed := false     # opened by "continue": says so in the title
## 0.19: the Workshop's Terminal. Settings and credits; no run to resume or abandon.
var hub := false


func _paint() -> void:
	dim()
	var v := view()
	var sr := safe()
	var cx := v.x / 2.0
	if hub:
		_paint_terminal(sr, cx)
		return
	text_center(v.x / 2.0, sr.position.y + 22, "PAUSED" if not resumed else "WELCOME BACK", GOLD, 16, "body")
	var step_txt := ("%s  -  %s" % [Chapter.WORLDS[run.world]["name"], Chapter.area_name(0, run.world)]) if run.step == 0 else "%s, room %d of %d  -  %s" % [Chapter.WORLDS[run.world]["name"], run.step, Chapter.PLAN.size() - 1, Chapter.area_name(run.step, run.world)]
	text_center(v.x / 2.0, sr.position.y + 36, step_txt, MUTED)
	var y := sr.position.y + 48
	# relics
	var rw := minf(sr.size.x - 20, 360.0)
	var picked := sel_relic >= 0 and sel_relic < run.relics.size()
	var desc := Rewards.item_desc({"t": &"relic", "id": run.relics[sel_relic]}) if picked else ""
	var desc_n := _wrap(Game.font("small"), desc, rw - 16, 8).size() if picked else 1
	var rr := Rect2(cx - rw / 2.0, y, rw, 51 + desc_n * 11)
	panel(rr)
	text(rr.position + Vector2(8, 12), "RELICS  %d" % run.relics.size(), MUTED, 8, "bold")
	if run.relics.is_empty():
		text(rr.position + Vector2(8, 30), "None yet. Relic rooms and bosses give them.", MUTED)
	elif not picked:
		text_right(rr.end.x - 8, rr.position.y + 12, "TAP ONE TO READ IT", MUTED.darkened(0.3))
	for i in run.relics.size():
		var p := rr.position + Vector2(18 + i * 22, 30)
		if p.x > rr.end.x - 10:
			break
		icon_at(Icons.relic(run.relics[i]), p, 1.0 if i != sel_relic else 1.3)
		area(Rect2(p - Vector2(10, 10), Vector2(20, 20)), "relic%d" % i)
	if picked:
		var rd: Dictionary = Relics.DEFS[run.relics[sel_relic]]
		text(rr.position + Vector2(8, 48), rd["title"], TEXT, 8, "bold")
		if rd.has("flavor"):
			text_right(rr.end.x - 8, rr.position.y + 48, "\"%s\"" % rd["flavor"], MUTED.darkened(0.3))
		para(Rect2(rr.position + Vector2(8, 50), Vector2(rw - 16, desc_n * 11)), desc, MUTED)
	y = rr.end.y + 6
	button(Rect2(cx - 70, y, 140, 28), "resume", "RESUME", "primary")
	y += 34
	y = _settings_rows(sr, cx, y)
	var bw := 96.0
	button(Rect2(cx - bw * 1.5 - 6, y, bw, 26), "gloss", "HOW IT WORKS", "ghost")
	button(Rect2(cx - bw / 2.0, y, bw, 26), "hints", "SHOW TIPS", "ghost")
	button(Rect2(cx + bw / 2.0 + 6, y, bw, 26), "abandon", "SURE? TAP" if confirm_abandon else "ABANDON RUN", "danger")
	_web_diag(sr, cx, y)
	if show_glossary:
		glossary_panel()


## The Terminal (the Workshop): a monitor's worth of settings, how it works, and credits.
func _paint_terminal(sr: Rect2, cx: float) -> void:
	text_center(cx, sr.position.y + 22, "TERMINAL", Color("#5ce1ff"), 16, "body")
	text_center(cx, sr.position.y + 36, "guild@source:~$ settings", Style.UI_GOOD)
	var y := _settings_rows(sr, cx, sr.position.y + 50)
	var bw := 96.0
	button(Rect2(cx - bw * 1.5 - 6, y, bw, 26), "gloss", "HOW IT WORKS", "ghost")
	button(Rect2(cx - bw / 2.0, y, bw, 26), "hints", "SHOW TIPS", "ghost")
	button(Rect2(cx + bw / 2.0 + 6, y, bw, 26), "credits", "CREDITS", "ghost")
	button(Rect2(cx - 70, y + 34, 140, 28), "resume", "BACK", "primary")
	_web_diag(sr, cx, y + 34)
	if show_glossary:
		glossary_panel()


## 0.22: two rows. Play and feel (auto-fire, assist, shake, flash, reduce motion as MOTION
## LOW, text size), then
## sound and vibration. Vibration is hidden on web (browsers give it no tiers; iOS has none).
func _settings_rows(sr: Rect2, cx: float, y: float) -> float:
	var bw := 96.0
	var rows := [
		[["auto", "AUTO-FIRE " + _on(Game.auto_fire)], ["assist", "ASSIST " + _pct(Game.assist)],
			["shake", "SHAKE " + _pct(Game.shake_level)], ["flash", "FLASH " + _pct(Game.flash_scale)],
			["motion", "MOTION " + ("LOW" if Game.reduce_motion else "FULL")], ["text", "TEXT " + ("LARGE" if Game.text_big else "NORMAL")]],
		[["sound", "SOUND " + _on(Game.sound)], ["music", "MUSIC " + _on(Game.music)], ["voice", "VOICE " + _on(Game.voice)],
			["heartbeat", "HEARTBEAT " + _on(Game.heartbeat)]],
	]
	if not OS.has_feature("web"):
		(rows[1] as Array).append(["haptics", "VIBRATION " + _on(Game.haptics)])
	for row in rows:
		var n: int = row.size()
		var sbw := minf(bw, (sr.size.x - 30.0) / n)
		var x0 := cx - (sbw * n + 6.0 * (n - 1)) / 2.0
		for k in n:
			var b: Array = row[k]
			button(Rect2(x0 + k * (sbw + 6), y, sbw, 26), b[0], b[1])
		y += 30
	return y + 4


static func _on(v: bool) -> String:
	return "ON" if v else "OFF"


## 1.0 > "100%", 0.5 > "50%", 0.25 > "25%", 0 > "OFF".
static func _pct(v: float) -> String:
	return "%d%%" % roundi(v * 100.0) if v > 0.0 else "OFF"


func _web_diag(sr: Rect2, cx: float, y: float) -> void:
	var diag := Game.web_sound()
	if diag != "":
		# web only: lets a tester report why a phone is silent without a Mac inspector.
		# Stacked in the empty column left of the menu; one line under it if that column is too narrow.
		var lines: Array = ["web " + Game.web_build()]
		lines.append_array(("sound: " + diag).split(" / "))
		var f := Game.font("small")
		var widest := 0.0
		for ln in lines:
			widest = maxf(widest, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		var faint := MUTED.darkened(0.3)
		if sr.position.x + 4 + widest <= cx - 150 - 8:
			for i in lines.size():
				text(Vector2(sr.position.x + 4, sr.end.y - 2 - (lines.size() - 1 - i) * 10), lines[i], faint)
		else:
			text_center(cx, y + 26 + 11, "  -  ".join(lines), faint)


func _on_button(id: String) -> void:
	if id != "abandon":
		confirm_abandon = false
	match id:
		"resume":
			finished.emit({})
		"credits":
			finished.emit({"credits": true})
		"abandon":
			if confirm_abandon:
				finished.emit({"abandon": true})
			confirm_abandon = true
		"hints":
			Hints.reset()
			toast("Tips will show again")
		"auto", "sound", "music", "voice", "haptics", "heartbeat", "motion", "text":
			var s := Game.settings()
			var key: String = {"auto": "auto_fire", "motion": "reduce_motion", "text": "text_big"}.get(id, id)
			s[key] = not s[key]
			_save(s)
		"shake", "flash":
			var s := Game.settings()
			s[id] = Game.next_step(Game.SCALES, s[id])
			_save(s)
		"assist":
			var s := Game.settings()
			s["assist"] = Game.next_step(Game.ASSISTS, s["assist"])
			_save(s)
			if Game.assist > 0.0:
				toast("Assist: %d%% less damage, slower shots, wider aim" % roundi(Game.assist * 100.0))
		_:
			if id.begins_with("relic"):
				var i := int(id.substr(5))
				sel_relic = -1 if sel_relic == i else i


func _save(s: Dictionary) -> void:
	Game.apply_settings(s)
	SaveGame.save_settings(Game.settings())
