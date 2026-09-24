class_name TitleScreen
extends Screen
## Title: the logo, CONTINUE (when a run is saved), NEW RUN, and lifetime numbers.

var has_save := false
var meta: Dictionary = {}
var _frames: Array[Texture2D] = []
var _motes: Array = []


func _opened() -> void:
	has_save = SaveGame.has_run()
	meta = SaveGame.load_meta()
	_frames = Sprites.wizard_frames()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		_motes.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(4, 14), rng.randf() * TAU,
			[Color("#5ce1ff"), Color("#c46bff"), Color("#ffe066")][i % 3]])


func _paint() -> void:
	var v := view()
	draw_rect(Rect2(Vector2.ZERO, v), Color("#07051a"))
	for k in 8:
		draw_rect(Rect2(0, v.y * (0.55 + k * 0.06), v.x, v.y * 0.06), Color(0.08 + k * 0.012, 0.06 + k * 0.01, 0.16 + k * 0.012))
	for m in _motes:
		var p: Vector2 = Vector2(m[0].x * v.x, fposmod(m[0].y * v.y - _age * float(m[1]), v.y))
		var c: Color = m[3]
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(c.r, c.g, c.b, 0.5 + 0.5 * sin(_age * 2.0 + m[2])))
	var sr := safe()
	var cx := v.x / 2.0
	# logo with a glitch offset
	var y := sr.position.y + v.y * 0.2
	var f := Game.font("body")
	var title := "WANDCRAFT"
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
	var at := Vector2(cx - w / 2.0, y).round()
	var jit := 1.0 if fmod(_age, 2.7) < 0.12 else 0.0
	draw_string(f, at + Vector2(-1 - jit, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(1.0, 0.25, 0.65, 0.7))
	draw_string(f, at + Vector2(1 + jit, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.36, 0.88, 1.0, 0.7))
	draw_string_outline(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 4, INK)
	draw_string(f, at, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#fff3c8"))
	text_center(cx, y + 16, "Program your wand. Break the Glitch.", MUTED)
	# the wizard, idling
	var tex: Texture2D = _frames[int(_age * 2.0) % 2]
	icon_at(tex, Vector2(cx, y + 50), 2.0)
	var by := y + 84
	if has_save:
		button(Rect2(cx - 70, by, 140, 32), "continue", "CONTINUE", "primary")
		by += 40
		button(Rect2(cx - 70, by, 140, 28), "new", "NEW RUN")
	else:
		button(Rect2(cx - 70, by, 140, 32), "new", "NEW RUN", "primary")
	if int(meta.get("runs", 0)) > 0:
		text_center(cx, sr.end.y - 6, "Runs %d   Wins %d   Enemies defeated %d" % [meta["runs"], meta["wins"], meta["kills"]], MUTED)
	text(Vector2(sr.position.x, sr.end.y - 6), "v" + str(ProjectSettings.get_setting("application/config/version", "")), MUTED.darkened(0.3))


func _on_button(id: String) -> void:
	if id == "continue" or id == "new":
		finished.emit({"action": id})
