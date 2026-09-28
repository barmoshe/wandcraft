class_name CommitScreen
extends Screen
## The Glitch's fall, once the true ending is open (0.20, Residents.true_ending_open): your
## Friday commit as a diff, and the choice the whole story led to.
##   REVERT        the Source rolls back to 16:58 (the ending every win has had)
##   FIX FORWARD   keep what grew from the bug, patch the rest (the true ending)

const DIFF := [
	["@@ mana.spell  Friday 16:59 @@", 0],
	["  func regen(wizard):", 0],
	["-     wizard.mana += 1", -1],
	["+     wizard.mana += tiny_tweak", 1],
	["  # reviewed: LGTM (Grep, unread)", 0],
	["  # lint: warning ignored", 0],
]


func _paint() -> void:
	dim(0.97)
	var v := view()
	var sr := safe()
	var cx := v.x / 2.0
	text_center(cx, sr.position.y + 18, "COMMIT a1f00d", GOLD, 16, "body")
	text_center(cx, sr.position.y + 30, "Author: you. Status: contained. Awaiting your commit.", MUTED)
	var r := Rect2(cx - 150, sr.position.y + 40, 300, DIFF.size() * 14 + 12)
	draw_rect(r, Color(0.03, 0.03, 0.08, 0.95))
	for i in DIFF.size():
		var ln: String = DIFF[i][0]
		var k: int = DIFF[i][1]
		var y := r.position.y + 14 + i * 14
		if k != 0:
			draw_rect(Rect2(r.position.x + 2, y - 10, r.size.x - 4, 13), Color(Style.c("moss:2") if k > 0 else Style.c("threat:1"), 0.5))
		text(Vector2(r.position.x + 8, y), ln, Style.c("moss:4") if k > 0 else (Style.c("threat:4") if k < 0 else TEXT))
	var by := r.end.y + 14
	var bw := 140.0
	button(Rect2(cx - bw - 6, by, bw, 30), "revert", "REVERT", "normal")
	button(Rect2(cx + 6, by, bw, 30), "forward", "FIX FORWARD", "primary")
	para(Rect2(cx - bw - 6, by + 36, bw, 40), "Roll the world back to 16:58. Everything since goes quiet.", MUTED)
	para(Rect2(cx + 6, by + 36, bw, 40), "Keep what grew. Read every line. Patch the rest.", MUTED)


func _on_button(id: String) -> void:
	if id == "revert" or id == "forward":
		finished.emit({"choice": id})
