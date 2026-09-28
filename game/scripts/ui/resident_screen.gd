class_name ResidentScreen
extends Screen
## A resident's service (0.20, Residents), opened by using them a second time in the Workshop
## (0.21: their talk plays as bubbles over their heads first, in the world):
##   Grep     SEARCH       one true hint a run
##   Hotfix   SKIN FORGE   wand skins for Bits (looks, never power)
##   Cache    THE STACKS   the Lost Pages, read like source files
## A compact panel over the dimmed Workshop: their face and name, their story so far, and
## the service.

var who: StringName = &"grep"
var hint := ""                 # Grep's answer, once asked
var page := -1                 # Cache: the page being read
var meta: Dictionary = {}


func _opened() -> void:
	meta = SaveGame.load_meta()
	if who == &"cache" and Residents.pages() > 0:
		page = Residents.pages() - 1


func _paint() -> void:
	dim(0.5)
	var sr := safe()
	var d: Dictionary = Residents.DEFS[who]
	var col := Color(d["color"])
	var r := Rect2(sr.get_center().x - minf(sr.size.x - 8.0, 340.0) / 2.0, sr.position.y + 4, minf(sr.size.x - 8.0, 340.0), sr.size.y - 8)
	panel(r, true)
	# the face and name
	var face := KernelArt.portrait(who, 1 if who == &"hotfix" else 0, false, fmod(_age, 3.3) < 0.12)
	var fs := face.get_size() * 2.0
	draw_texture_rect(face, Rect2(r.position + Vector2(6, 6), fs), false)
	var fx := r.position.x + fs.x + 12
	text(Vector2(fx, r.position.y + 18), String(d["name"]).to_upper(), col, 16, "body")
	text(Vector2(fx, r.position.y + 29), fit(String(d["title"]), r.end.x - 70 - fx, "bold"), MUTED, 8, "bold")
	button(Rect2(r.end.x - 62, r.position.y + 5, 56, 22), "close", "BACK", "primary")
	# their story so far: a pip a beat, and what the next one waits for
	var pr := Residents.progress(who, meta)
	var py := r.position.y + 40
	for k in int(pr[1]):
		var pc := Vector2(fx + 3 + k * 9, py)
		if k < int(pr[0]):
			draw_circle(pc, 3.0, col)
		else:
			draw_arc(pc, 2.5, 0.0, TAU, 10, MUTED, 1.0)
	var wf := Residents.waits_for(who, meta)
	var wx := fx + int(pr[1]) * 9 + 6
	text(Vector2(wx, py + 3), fit(wf if wf != "" else "Their story is told.", r.end.x - 8 - wx), MUTED)
	# the service
	var top := maxf(r.position.y + fs.y + 12, py + 10)
	var rr := Rect2(r.position.x + 6, top, r.size.x - 12, r.end.y - top - 6)
	panel(rr, false)
	text(rr.position + Vector2(8, 13), String(d["service"]), col, 8, "bold")
	text(rr.position + Vector2(8, 23), fit(String(d["sub"]), rr.size.x - 16), MUTED)
	match who:
		&"grep":
			_paint_search(rr)
		&"hotfix":
			_paint_skins(rr)
		&"cache":
			_paint_pages(rr)


func _paint_search(rr: Rect2) -> void:
	var asked := int(meta.get("hint_run", -1)) == int(meta.get("runs", 0))
	para(Rect2(rr.position.x + 8, rr.position.y + 36, rr.size.x - 16, 30),
		"Ask once a run. He answers literally, and he's always right.", TEXT)
	if hint != "":
		text(Vector2(rr.position.x + 8, rr.position.y + 74), "GREP", Color(Residents.DEFS[&"grep"]["color"]), 8, "bold")
		para(Rect2(rr.position.x + 8, rr.position.y + 78, rr.size.x - 16, rr.size.y - 118), hint, Style.c("gold:4"))
	button(Rect2(rr.position.x + 8, rr.end.y - 34, rr.size.x - 16, 26), "search", "ASK GREP" if not asked else "ASKED THIS RUN", "primary", hint == "")


func _paint_skins(rr: Rect2) -> void:
	var bits := int(meta.get("bits", 0))
	text_right(rr.end.x - 8, rr.position.y + 13, "%d BITS" % bits, Style.c("cyan:4"), 8, "bold")
	var owned := Residents.skins_owned(meta)
	var on := Residents.skin_on(meta)
	var rh := minf(24.0, (rr.size.y - 34.0) / Residents.SKINS.size())
	for i in Residents.SKINS.size():
		var s: Dictionary = Residents.SKINS[i]
		var y := rr.position.y + 30 + i * rh
		var has := owned.has(s["id"])
		if int(s["price"]) < 0 and not has:
			text(Vector2(rr.position.x + 34, y + 12), "??????  (a gift, later)", MUTED)
			continue
		_swatch(Vector2(rr.position.x + 10, y + 4), s)
		text(Vector2(rr.position.x + 34, y + 12), String(s["name"]), TEXT if has or bits >= int(s["price"]) else MUTED, 8, "bold")
		var br := Rect2(rr.end.x - 70, y + 1, 62, rh - 3)
		if s["id"] == on:
			button(br, "skin:" + String(s["id"]), "WORN", "ghost", false)
		elif has:
			button(br, "skin:" + String(s["id"]), "WEAR")
		else:
			button(br, "skin:" + String(s["id"]), "%d BITS" % int(s["price"]), "primary", bits >= int(s["price"]))


## A wand in a skin's colours: a stick in its body ramp and a gem.
func _swatch(at: Vector2, s: Dictionary) -> void:
	var body := String(s["body"])
	for k in 14:
		var c := Style.c("%s:%d" % [body, 1 + (k % 3)])
		draw_rect(Rect2(at + Vector2(k, 13 - k), Vector2(2, 2)), c)
	var gem := String(s["gem"])
	draw_circle(at + Vector2(16, 0), 2.5, Style.c(gem) if gem != "" else Style.c("cyan:4"))


func _paint_pages(rr: Rect2) -> void:
	var n := Residents.pages(meta)
	text_right(rr.end.x - 8, rr.position.y + 13, "%d / %d" % [n, Residents.PAGES.size()], Style.c("violet:4"), 8, "bold")
	var colw := 74.0
	var rh := minf(16.0, (rr.size.y - 34.0) / Residents.PAGES.size())
	for i in Residents.PAGES.size():
		var y := rr.position.y + 30 + i * rh
		var have := i < n
		var r := Rect2(rr.position.x + 6, y, colw, rh - 2)
		if i == page:
			draw_rect(r, Color(1, 1, 1, 0.08))
		text(r.position + Vector2(4, rh - 5), String(Residents.PAGES[i]["title"]) if have else "??????", TEXT if have else MUTED)
		if have:
			area(r, "page:%d" % i)
	# the page itself, as a source file
	var cr := Rect2(rr.position.x + colw + 12, rr.position.y + 30, rr.size.x - colw - 20, rr.size.y - 38)
	draw_rect(cr, Color(0.03, 0.03, 0.08, 0.9))
	if page < 0:
		para(Rect2(cr.position.x + 6, cr.position.y + 6, cr.size.x - 12, 60), "Every boss you beat drops a page. Bring them here.", MUTED)
		return
	var code: Array = Residents.PAGES[page]["code"]
	var cy := cr.position.y + 12
	for k in code.size():
		var ln: String = code[k]
		var comment := ln.begins_with("//") or ln.begins_with("#")
		text(Vector2(cr.position.x + 4, cy), "%2d" % (k + 1), Color(0.4, 0.35, 0.5))
		cy += para(Rect2(cr.position.x + 18, cy - 8, cr.size.x - 22, 40), ln, Style.c("moss:4") if comment else Color("#ffd05e")) + 3


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
	elif id == "search":
		hint = Residents.search()
		meta = SaveGame.load_meta()
		Audio.sfx("hint")
		Dialogue.enqueue(Residents.GREP, hint, "")
	elif id.begins_with("skin:"):
		var sid := id.substr(5)
		if Residents.take_skin(sid):
			Audio.sfx("skin_equip")
			meta = SaveGame.load_meta()
		else:
			toast("Not enough Bits")
			Audio.sfx("deny")
	elif id.begins_with("page:"):
		page = int(id.substr(5))
