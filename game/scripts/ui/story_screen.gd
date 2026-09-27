class_name StoryScreen
extends Screen
## The story's panels (research/story.md): the intro before a first run, the ending on a
## first win. One panel at a time, a picture over a line; tap to go on, SKIP to leave. Lines
## type out, and a tap while one is typing finishes it first.

const CPS := 55.0           # characters a second as a line types out

var panels: Array = []      # the lines (Story.INTRO or Story.ENDING)
var who: Array = []         # who says each one ("" is the narrator, Story.DUCK the Duck)
var art: Array = []         # a picture per panel: "code", "clock", "glitch", "kernel", "duck"
var last_label := "DONE"   # the last panel's button ("BEGIN" for the intro)
var voice_prefix := ""     # "intro" or "ending": each panel is read aloud (Dialogue, "<prefix>.<n>")
var at := 0
var _t := 0.0               # time on this panel


func _opened() -> void:
	_speak()


func _speak() -> void:
	if voice_prefix != "":
		Dialogue.play_now("%s.%d" % [voice_prefix, at], String(who[at]) if at < who.size() else "", String(panels[at]))


func _process(dt: float) -> void:
	_t += dt
	super._process(dt)


func _typed() -> int:
	return mini(String(panels[at]).length(), int(_t * CPS))


func _paint() -> void:
	dim(0.97)
	var v := view()
	var sr := safe()
	var cx := v.x / 2.0
	var pic := Rect2(cx - 90, sr.position.y + 22, 180, 110)
	_art(String(art[at]) if at < art.size() else "code", pic)
	var s := String(panels[at])
	var speaker := String(who[at]) if at < who.size() else ""
	var tr := Rect2(cx - 150, pic.end.y + 18, 300, 60)
	if speaker != "":
		draw_texture(Hud.duck_face(), Vector2(tr.position.x - 18, tr.position.y - 2).round())
		text(tr.position + Vector2(0, 6), speaker, GOLD, 8, "bold")
		tr.position.y += 12
	para(tr, s.substr(0, _typed()), TEXT)
	# progress pips, then the buttons
	for i in panels.size():
		var p := Vector2(cx - (panels.size() - 1) * 6.0 + i * 12.0, sr.end.y - 40)
		if i == at:
			draw_circle(p, 3.0, GOLD)
		else:
			draw_arc(p, 2.5, 0.0, TAU, 10, MUTED, 1.0)
	area(Rect2(sr.position, Vector2(sr.size.x, sr.size.y - 34)), "next")
	var last := at == panels.size() - 1
	button(Rect2(cx - 50, sr.end.y - 30, 100, 26), "next", last_label if last else "NEXT", "primary")
	if not last:
		button(Rect2(sr.end.x - 70, sr.position.y, 70, 24), "skip", "SKIP", "ghost")


## The panel's picture, drawn in code like everything else.
func _art(kind: String, r: Rect2) -> void:
	draw_rect(r, Color(0.05, 0.03, 0.1))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), RIM)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), RIM)
	var c := r.get_center()
	# the Source: rows of code scrolling up behind every picture
	var rows := int(r.size.y / 8.0)
	for i in rows:
		var y := r.position.y + fmod(i * 8.0 - _age * 10.0 + r.size.y * 4.0, r.size.y)
		var seed_ := (i * 37 + int(_age * 10.0 / r.size.y * 8.0)) % 7
		var w := 20.0 + seed_ * 14.0
		var col := Color("#5ce1ff") if kind == "code" else Color(0.35, 0.3, 0.5)
		draw_rect(Rect2(r.position.x + 8 + (seed_ % 3) * 10, y, w, 2), Color(col, 0.35))
	match kind:
		"clock":
			text_center(c.x, c.y + 8, "FRI 16:59", GOLD, 16, "body")
			if int(_age * 2.0) % 2 == 0:
				text_center(c.x, c.y + 26, "git push", Style.UI_GOOD, 8, "bold")
		"glitch":
			var ft: Array = Bestiary.frames("bugling")
			for k in 3:
				var off := Vector2(randf_range(-2, 2), 0) if int(_age * 8.0) % 5 == k else Vector2.ZERO
				icon_at(ft[int(_age * 4.0 + k) % ft.size()], c + Vector2(-40 + k * 40, 6) + off, 2.0, Color(1, 0.6 + 0.2 * k, 1))
		"kernel":
			draw_circle(c, 18.0 + sin(_age * 3.0) * 2.0, Color("#ff9a3a", 0.25))
			draw_circle(c, 12.0, Color("#ff9a3a", 0.6))
			text_center(c.x, c.y + 36, "kernel()", GOLD, 8, "bold")
		"duck":
			icon_at(Hud.duck_face(), c + Vector2(0, sin(_age * 2.5) * 2.0), 5.0)
		_:
			text_center(c.x, c.y + 4, "THE SOURCE", Color("#5ce1ff"), 16, "body")


var _done := false


func _on_button(id: String) -> void:
	if _done:
		return   # a double tap on the last panel must not finish twice
	if id == "skip":
		_done = true
		Dialogue.clear()
		finished.emit({"skipped": true})
	elif id == "next":
		if _typed() < String(panels[at]).length():
			_t = 99.0   # finish the line first
		elif at < panels.size() - 1:
			at += 1
			_t = 0.0
			_speak()
		else:
			_done = true
			finished.emit({})
