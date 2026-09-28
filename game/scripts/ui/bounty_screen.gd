class_name BountyScreen
extends Screen
## The Bug Bounty Board (0.19, replaces design v2's goals): tickets to fix in a run. Three
## open tickets are pinned at a time; progress counts before a ticket is pinned (Hades'
## Fated List). A fixed ticket opens its items at once, and its Bits wait here: CLAIM
## stamps it FIXED and pays.

var _stamp_t := 0.0          # the last claim's stamp, fading
var _stamp_id := ""


func _process(dt: float) -> void:
	_stamp_t = maxf(0.0, _stamp_t - dt)
	super._process(dt)


func _paint() -> void:
	dim(0.9)
	var sr := safe()
	text(sr.position + Vector2(2, 16), "BUG BOUNTY BOARD", GOLD, 16, "body")
	var done := Meta.bounties_done()
	text(sr.position + Vector2(2, 30), "FIXED %d/%d   BANK %d BITS" % [done.size(), Meta.BOUNTIES.size(), Meta.bits()], MUTED, 8, "bold")
	button(Rect2(sr.end.x - 76, sr.position.y, 76, 24), "close", "BACK", "primary")
	var y := sr.position.y + 40
	var w := minf(sr.size.x, 380.0)
	var x := sr.get_center().x - w / 2.0
	# fixed tickets waiting for their Bits
	var waiting := Meta.unclaimed()
	for bid in waiting.slice(0, 3):
		var b := Meta.bounty(bid)
		var r := Rect2(x, y, w, 26)
		_ticket(r, b, true)
		button(Rect2(r.end.x - 70, r.position.y + 3, 66, 20), "claim:" + bid, "CLAIM +%d" % int(b["bits"]), "primary")
		y += 30
	if waiting.size() > 3:
		text(Vector2(x, y + 8), "+%d more to claim" % (waiting.size() - 3), Style.UI_GOOD)
		y += 14
	y += 4
	text(Vector2(x, y + 8), "OPEN TICKETS", GOLD, 8, "bold")
	y += 12
	for b in Meta.board():
		_ticket(Rect2(x, y, w, 26), b, false)
		y += 30
	if Meta.open_bounties().is_empty():
		text_center(sr.get_center().x, y + 14, "No bugs left. The Guild is suspicious.", MUTED)
	if _stamp_t > 0.0:
		var a := clampf(_stamp_t * 2.0, 0.0, 1.0)
		var s := 1.0 + (1.0 - clampf((1.2 - _stamp_t) * 6.0, 0.0, 1.0)) * 1.5
		var f := Game.font("body")
		var c := sr.get_center()
		draw_set_transform(c, -0.2, Vector2(s, s))
		draw_string_outline(f, Vector2(-40, 8), "FIXED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 4, Color(0, 0, 0, a))
		draw_string(f, Vector2(-40, 8), "FIXED", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Style.UI_GOOD, a))
		draw_set_transform(Vector2.ZERO)


func _ticket(r: Rect2, b: Dictionary, fixed: bool) -> void:
	draw_rect(r, Color(0.12, 0.09, 0.2, 0.95) if not fixed else Color(0.08, 0.16, 0.1, 0.95))
	draw_rect(Rect2(r.position, Vector2(3, r.size.y)), Color("#ff7b7b") if not fixed else Style.UI_GOOD)
	var num := "#%03d" % (Meta.BOUNTIES.find(b) + 1)
	text(r.position + Vector2(8, 11), num, Color("#ff7b7b") if not fixed else Style.UI_GOOD, 8, "bold")
	text(r.position + Vector2(40, 11), String(b["text"]), TEXT, 8, "bold")
	var reward := "+%d Bits" % int(b["bits"])
	var names: Array = (b.get("unlocks", []) as Array).map(func(id: StringName) -> String: return Meta.title(id))
	if not names.is_empty():
		reward += "   opens " + ", ".join(names.slice(0, 3))
	text(r.position + Vector2(40, 21), reward, Color("#7cf0c8"))
	if fixed:
		text_right(r.end.x - 76, r.position.y + 11, "FIXED", Style.UI_GOOD, 8, "bold")


func _on_button(id: String) -> void:
	if id == "close":
		finished.emit({})
	elif id.begins_with("claim:"):
		var bid := id.substr(6)
		var n := Meta.claim(bid)
		if n > 0:
			Audio.sfx("coin")
			_stamp_t = 1.2
			_stamp_id = bid
			toast("+%d Bits" % n)
