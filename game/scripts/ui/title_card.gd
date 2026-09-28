class_name TitleCard
extends Screen
## The title (0.19): the logo over the live Workshop, a moment, then a tap puts you in
## control of your hero. CONTINUE resumes a saved run. On the web this tap is also the one
## iOS needs before any sound can play.

var has_save := false


func _opened() -> void:
	has_save = SaveGame.has_run()


func _paint() -> void:
	var v := view()
	var sr := safe()
	# the Workshop shows through: a dark band behind the logo only
	draw_rect(Rect2(0, 0, v.x, v.y), Color(0.02, 0.01, 0.05, 0.55))
	var cx := v.x / 2.0
	var y := sr.position.y + v.y * 0.3
	var f := Game.font("body")
	var title := "WANDCRAFT"
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var at := Vector2(cx - w / 2.0, y).round()
	var glitch := fmod(_age, 3.1) < 0.14
	var jit := 2.0 if glitch else 1.0
	draw_string(f, at + Vector2(-jit, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Style.c("glitch:3"), 0.75))
	draw_string(f, at + Vector2(jit, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(Style.c("cyan:3"), 0.75))
	draw_string_outline(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 4, INK)
	draw_string(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Style.c("gold:4"))
	if glitch:
		draw_rect(Rect2(at + Vector2(-4, -14), Vector2(w + 8, 2)), Color(Style.c("cyan:3"), 0.5))
	text_center(cx, y + 16, "Program your wand. Break the Glitch.", MUTED)
	area(Rect2(Vector2.ZERO, v), "play")
	var a := 0.55 + 0.45 * sin(_age * 3.0)
	text_center(cx, y + 60, "TAP TO PLAY" if Game.is_touch() or Game.touch_seen else "CLICK OR PRESS ANY KEY", Color(GOLD, a), 8, "bold")
	if has_save:
		button(Rect2(cx - 70, y + 76, 140, 30), "continue", "CONTINUE RUN", "primary")
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	var build := Game.web_build()
	if build != "":
		ver += "  web " + build
	text_right(sr.end.x, sr.position.y + 10, ver, MUTED.darkened(0.3))


func _unhandled_key_input(ev: InputEvent) -> void:
	if _age > GUARD and ev.is_pressed() and not ev.is_echo():
		_on_button("play")


func _on_button(id: String) -> void:
	if id == "continue":
		Audio.sfx("ui_confirm")
		finished.emit({"action": "continue"})
	elif id == "play":
		finished.emit({})
