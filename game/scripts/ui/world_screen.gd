class_name WorldScreen
extends Screen
## The descent between worlds (research/story.md): the bug's stack trace, with your hero
## dropping from the frame you just cleared into the next one, then the new world's name, its
## line, the enemies new there and the world-clear bonus. DESCEND lights up once the drop has
## landed. main.gd opens it on the world's ui_request and then calls world.enter_next_world().

const DROP := 1.2           # seconds for the hero to fall to the next frame
const EMBER := Color("#ff9a3a")
## What each world adds to the bestiary (by index into Chapter.WORLDS).
const NEW_HERE := {1: [&"proxy", &"kernel_panic", &"spark_plug"]}

var to := 1                 # the world being entered (0-based)
var bonus_hp := 10


func _paint() -> void:
	dim(0.95)
	var v := view()
	var sr := safe()
	var t := clampf(_age / DROP, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - t, 3.0)
	var lx := sr.position.x + 18.0
	var top := sr.position.y + 22.0
	# embers rising from below (deterministic: a phase per spark, no state to keep)
	for i in 28:
		var ph := fmod(_age * (0.18 + 0.02 * (i % 5)) + i * 0.137, 1.0)
		var x := sr.position.x + fmod(i * 97.0, sr.size.x)
		var y := sr.end.y - ph * sr.size.y
		draw_rect(Rect2(x + sin(_age * 2.0 + i) * 3.0, y, 1, 1), Color(EMBER, 0.6 * (1.0 - ph)))
	# the stack trace: every world's frame, then the Kernel, still unknown
	text(Vector2(lx, top), "STACK TRACE", MUTED, 8, "bold")
	var frames: Array = Story.WORLD_CARDS.map(func(c: Dictionary) -> String: return c["frame"])
	frames.append("kernel()  ???")
	var row := 26.0
	var y0 := top + 18.0
	for i in frames.size():
		var y := y0 + i * row
		var done := i < to
		var here := i == to
		var col := Style.UI_GOOD if done else (EMBER if here else Color(0.4, 0.35, 0.5))
		draw_rect(Rect2(lx, y - 8, 150, 20), Color(0.1, 0.07, 0.18, 0.9 if here else 0.6))
		draw_rect(Rect2(lx, y - 8, 2, 20), col)
		text(Vector2(lx + 8, y + 5), "at " + String(frames[i]), TEXT if here else col, 8, "bold" if here else "small")
		if done:
			text_right(lx + 146, y + 5, "OK", Style.UI_GOOD, 8, "bold")
		if i > 0:
			draw_rect(Rect2(lx + 6, y - row + 12, 1, row - 20), Color(0.4, 0.35, 0.5))
	# the hero drops from the cleared frame into the next one
	var hf: Array = Hero.frames()
	var tex: Texture2D = hf[0 if t >= 1.0 and int(_age * 3.0) % 2 == 0 else (1 if t >= 1.0 else 6)]
	var hy := lerpf(y0 + (to - 1) * row, y0 + to * row, e) - 2.0
	draw_texture(tex, Vector2(lx + 162.0, hy - tex.get_height() / 2.0).round())
	if t < 1.0:
		for k in 3:
			draw_rect(Rect2(lx + 164.0 + k * 4.0, hy - 10.0 - k * 5.0 * (1.0 - t), 1, 4), Color(EMBER, 0.5))
	# the new world
	var card: Dictionary = Story.WORLD_CARDS[mini(to, Story.WORLD_CARDS.size() - 1)]
	var rx := maxf(lx + 200.0, v.x / 2.0 + 10.0)
	var rw := minf(220.0, sr.end.x - rx - 6.0)
	var a := clampf((_age - 0.3) * 3.0, 0.0, 1.0)
	text(Vector2(rx, top), "WORLD %d" % (to + 1), Color(MUTED, a), 8, "bold")
	text(Vector2(rx, top + 20), String(card["title"]).to_upper(), Color(EMBER, a), 16, "body")
	var y := top + 30.0 + para(Rect2(rx, top + 30, rw, 30), card["line"], Color(TEXT, a))
	var fresh: Array = NEW_HERE.get(to, [])
	if not fresh.is_empty():
		y += 10.0
		text(Vector2(rx, y), "NEW HERE", Color(GOLD, a), 8, "bold")
		y += 6.0
		for k in fresh.size():
			var kind: StringName = fresh[k]
			var c := Vector2(rx + 12.0 + k * 70.0, y + 14.0)
			var ft: Array = Bestiary.frames(String(kind))
			icon_at(ft[int(_age * 4.0) % ft.size()], c, 1.0, Color(1, 1, 1, a))
			text_center(c.x, c.y + 20.0, String(Enemy.DEFS[kind]["title"]), Color(TEXT, a))
		y += 50.0
	y += 8.0
	text(Vector2(rx, y), "WORLD CLEAR", Color(Style.UI_GOOD, a), 8, "bold")
	para(Rect2(rx, y + 4, rw, 24), "+%d max HP and a full heal. Your wands, spells and relics come with you." % bonus_hp, Color(TEXT, a))
	# what LINT and the Duck are saying, under the stack trace (subtitles: the HUD is hidden here)
	if not Dialogue.current.is_empty():
		var who := String(Dialogue.current["who"])
		text(Vector2(lx, y0 + frames.size() * row + 14), who, Color("#5ce1ff") if who == Story.LINT else GOLD, 8, "bold")
		para(Rect2(lx, y0 + frames.size() * row + 18, 170, 30), String(Dialogue.current["text"]), TEXT)
	button(Rect2(v.x / 2.0 - 60, sr.end.y - 32, 120, 28), "descend", "DESCEND", "primary", t >= 1.0)


func _opened() -> void:
	Story.say("descend")


func _on_button(id: String) -> void:
	if id == "descend" and _age >= DROP:
		finished.emit({})
