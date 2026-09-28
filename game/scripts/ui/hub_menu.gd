class_name HubMenu
extends Screen
## MENU in the Workshop (0.19): every station as a plain list, for anyone who would rather
## not walk (Game Accessibility Guidelines: start without layers of menus).

const ORDER := ["portal", "heroes", "pkg", "repl", "bounty", "docs", "log", "terminal"]

var meta: Dictionary = {}


func _opened() -> void:
	meta = SaveGame.load_meta()


func _paint() -> void:
	dim(0.86)
	var v := view()
	var cx := v.x / 2.0
	var rh := 26.0
	var r := Rect2(cx - 120, v.y / 2.0 - (ORDER.size() * rh + 40) / 2.0, 240, ORDER.size() * rh + 40)
	panel(r, true)
	text(r.position + Vector2(10, 16), "THE WORKSHOP", GOLD, 8, "bold")
	button(Rect2(r.end.x - 56, r.position.y + 4, 52, 20), "close", "BACK", "ghost")
	for i in ORDER.size():
		var id: String = ORDER[i]
		var st: Dictionary = Hub.STATIONS[id]
		var open := Hub.is_open(id, meta)
		var br := Rect2(r.position.x + 8, r.position.y + 28 + i * rh, r.size.x - 16, rh - 3)
		draw_rect(br, Color(0.1, 0.07, 0.18, 0.9))
		icon_at(Icons.glyph(st["glyph"], Color(st["color"]) if open else MUTED), br.position + Vector2(12, br.size.y / 2.0))
		text(br.position + Vector2(26, 10), String(st["title"]), TEXT if open else MUTED, 8, "bold")
		text(br.position + Vector2(26, 20), String(st["sub"]) if open else String(st.get("locked", "")), MUTED)
		area(br, id)


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
	elif Hub.STATIONS.has(id):
		if Hub.is_open(id, meta):
			finished.emit({"station": id})
		else:
			toast(String(Hub.STATIONS[id].get("locked", "")))
