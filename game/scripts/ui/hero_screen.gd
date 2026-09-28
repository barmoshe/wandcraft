class_name HeroScreen
extends Screen
## The Hero Hall (0.19): the three heroes side by side, each with their own look, wand and
## twist. CHOOSE makes one the hero of every run after (meta "hero"); a locked hero stands
## as a silhouette with where it comes from.

var focus := 0          # the pedestal the player walked up to
var chosen: StringName = &"apprentice"


func _opened() -> void:
	chosen = Hub.next_hero(SaveGame.load_meta())


func _paint() -> void:
	dim(0.88)
	var v := view()
	var sr := safe()
	var cx := v.x / 2.0
	text_center(cx, sr.position.y + 18, "THE HERO HALL", GOLD, 16, "body")
	text_center(cx, sr.position.y + 32, "Your hero for every run after this one.", MUTED)
	var n := Hub.HEROES.size()
	var cw := minf(110.0, (sr.size.x - 16) / n - 6)
	var x0 := cx - (n * (cw + 6) - 6) / 2.0
	for i in n:
		var id: StringName = Hub.HEROES[i]
		var locked := Meta.is_locked(id)
		var r := Rect2(x0 + i * (cw + 6), sr.position.y + 44, cw, 150)
		panel(r, i == focus)
		var fr: Array = Hero.frames(id)
		var tex: Texture2D = fr[int(_age * 2.0 + i) % 2]
		var sz := tex.get_size() * 2.0
		var feet := Vector2(r.get_center().x, r.position.y + 84)
		draw_texture_rect(tex, Rect2((feet - Vector2(sz.x / 2.0, sz.y)).round(), sz), false, Color(0.06, 0.04, 0.12, 0.92) if locked else Color.WHITE)
		text_center(r.get_center().x, r.position.y + 98, String(RunState.LOADOUTS[id]["title"]).to_upper(), MUTED if locked else GOLD, 8, "bold")
		if locked:
			para(Rect2(r.position.x + 6, r.position.y + 106, r.size.x - 12, 40), Meta.source_text(id), MUTED)
		else:
			para(Rect2(r.position.x + 6, r.position.y + 106, r.size.x - 12, 40), String(RunState.LOADOUTS[id]["twist"]), TEXT)
		if id == chosen:
			text_center(r.get_center().x, r.position.y + 12, "YOUR HERO", Style.UI_GOOD, 8, "bold")
		area(r, "card%d" % i)
	var sel: StringName = Hub.HEROES[clampi(focus, 0, n - 1)]
	var ok := not Meta.is_locked(sel) and sel != chosen
	button(Rect2(cx - 110, sr.end.y - 30, 104, 28), "choose", "CHOOSE", "primary", ok)
	button(Rect2(cx + 6, sr.end.y - 30, 104, 28), "close", "BACK", "ghost")


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
	elif id.begins_with("card"):
		focus = int(id.substr(4))
	elif id == "choose":
		var sel: StringName = Hub.HEROES[focus]
		if Meta.is_locked(sel):
			toast(Meta.source_text(sel))
			return
		Audio.sfx("ui_confirm")
		finished.emit({"hero": sel})
