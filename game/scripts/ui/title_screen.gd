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
	_frames = Hero.frames()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		_motes.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(4, 14), rng.randf() * TAU,
			[Style.c("cyan:3"), Style.c("glitch:3"), Style.c("gold:3")][i % 3]])


func _paint() -> void:
	var v := view()
	# sky: night at the top, a violet haze toward the horizon
	var bands := 14
	for k in bands:
		var t := float(k) / (bands - 1)
		draw_rect(Rect2(0, v.y * 0.75 * t, v.x, v.y * 0.75 / bands + 1), Style.c("night:1").lerp(Style.c("violet:1"), t * t * 0.8))
	draw_rect(Rect2(0, v.y * 0.75, v.x, v.y * 0.25), Style.c("violet:1"))
	# the moon and its glow
	var moon := Vector2(safe().position.x + v.x * 0.1, v.y * 0.16).round()
	for k in 4:
		draw_circle(moon, 16.0 + k * 9.0, Color(Style.c("bone:4"), 0.05))
	draw_circle(moon, 13.0, Style.c("bone:4"))
	draw_circle(moon + Vector2(-4, -3), 3.0, Style.c("bone:3"))
	draw_circle(moon + Vector2(4, 4), 2.0, Style.c("bone:3"))
	# stars
	for m in _motes:
		var p: Vector2 = Vector2(m[0].x * v.x, m[0].y * v.y * 0.55)
		var c: Color = Style.c("bone:4")
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(c.r, c.g, c.b, 0.3 + 0.7 * absf(sin(_age * 1.3 + m[2]))))
	# parallax grove, bottom-aligned
	var base_y := v.y - Backdrop.H
	for L in [[Backdrop.far(), 3.0], [Backdrop.mid(), 7.0], [Backdrop.near(), 15.0]]:
		var tex: Texture2D = L[0]
		var off := fmod(_age * float(L[1]), Backdrop.W)
		var x := -off
		while x < v.x:
			draw_texture(tex, Vector2(x, base_y).round())
			x += Backdrop.W
	# spores drifting up through the trees
	for m in _motes:
		var p: Vector2 = Vector2(fposmod(m[0].x * v.x + sin(_age * 0.7 + m[2]) * 8.0, v.x), fposmod(m[0].y * v.y - _age * float(m[1]), v.y))
		if p.y < v.y * 0.45:
			continue
		var c: Color = m[3]
		draw_rect(Rect2(p.round(), Vector2.ONE), Color(c.r, c.g, c.b, 0.5 + 0.5 * sin(_age * 2.0 + m[2])))
	var sr := safe()
	# the wizard, 3x, standing in the undergrowth on the left
	var hero_x := sr.position.x + v.x * 0.2
	var feet := v.y - 20.0
	var tex: Texture2D = _frames[int(_age * 2.0) % 2]
	var sz := tex.get_size() * 3.0
	draw_set_transform(Vector2(hero_x, feet + 4), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(tex, Rect2(Vector2(hero_x - sz.x / 2.0, feet - sz.y).round(), sz), false)
	var tip := Vector2(hero_x + 30, feet - 30)
	for k in 5:
		var a := _age * 3.0 + k * 1.3
		var sp := tip + Vector2(cos(a) * 7.0, sin(a * 1.3) * 5.0 - fmod(_age * 20.0 + k * 9.0, 22.0))
		draw_rect(Rect2(sp.round(), Vector2(1, 1)), Style.c("cyan:4") if k % 2 else Style.c("glitch:4"))
	draw_circle(tip, 3.0 + sin(_age * 6.0), Color(Style.c("cyan:3"), 0.35))
	# logo and buttons, centered in the space right of the wizard
	var cx := (hero_x + 40.0 + sr.end.x) / 2.0
	var y := sr.position.y + v.y * 0.2
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
		# a torn slice of the logo, shifted sideways
		draw_rect(Rect2(at + Vector2(-4, -14), Vector2(w + 8, 2)), Color(Style.c("cyan:3"), 0.5))
	text_center(cx, y + 16, "Program your wand. Break the Glitch.", MUTED)
	var by := y + 44
	if has_save:
		button(Rect2(cx - 70, by, 140, 32), "continue", "CONTINUE", "primary")
		by += 40
		button(Rect2(cx - 70, by, 140, 28), "new", "NEW RUN")
	else:
		button(Rect2(cx - 70, by, 140, 32), "new", "NEW RUN", "primary")
	if int(meta.get("runs", 0)) > 0:
		text_center(cx, sr.end.y - 6, "Runs %d   Wins %d   Enemies defeated %d" % [meta["runs"], meta["wins"], meta["kills"]], MUTED)
	var ver := "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	var build := Game.web_build()
	if build != "":
		ver += "  web " + build
	text(Vector2(sr.position.x, sr.end.y - 6), ver, MUTED.darkened(0.3))


func _on_button(id: String) -> void:
	if id == "continue" or id == "new":
		finished.emit({"action": id})
