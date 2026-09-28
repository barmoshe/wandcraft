extends "res://tests/unit/test_helpers.gd"
## The HUD's message layout (0.20): tips, the spoken line, banners and toasts are placed
## around what the HUD already covers, never over it. tools/uiaudit.sh checks the drawn
## result on every screen; these check the placement rule itself (no rendering here).

var tree: SceneTree
var hud: Hud


func setup(t: SceneTree) -> void:
	tree = t
	hud = Hud.new()
	tree.root.add_child(hud)


func teardown() -> void:
	hud.free()


func _clear(rects: Array) -> bool:
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).intersects(rects[j]):
				return false
	return true


func test_bottom_messages_stack_without_touching() -> void:
	var sr := Rect2(4, 4, 472, 262)
	var vitals := Rect2(sr.position.x, sr.end.y - 30, 128, 30)
	var boss := Rect2(sr.get_center().x - 100, sr.end.y - 16, 200, 9)
	var title := Rect2(boss.position.x, boss.position.y - 9, 60, 8)
	hud._taken.assign([vitals, boss, title])
	var bottom := sr.end.y - 32.0
	var tip: Rect2 = hud._place(Rect2(sr.get_center().x - 160, bottom - 18, 320, 18), true, "hint")
	var say: Rect2 = hud._place(Rect2(sr.get_center().x - 140, tip.position.y - 3 - 34, 280, 34), true, "say")
	var ban: Rect2 = hud._place(Rect2(sr.get_center().x - 60, say.position.y - 3 - 30, 120, 30), true, "banner")
	ok(_clear([vitals, boss, title, tip, say, ban]), "the tip, the line and the banner stack clear of each other and the bars")
	ok(tip.end.y <= title.position.y, "the tip sits above the boss bar's title")
	ok(ban.end.y <= say.position.y and say.end.y <= tip.position.y, "banner over line over tip")


func test_a_message_that_lands_on_the_hud_moves_off_it() -> void:
	# a wide tip over a tall column of vitals on a narrow (4:3) screen moves up, not onto it
	var tall := Rect2(4, 200, 150, 60)
	hud._taken.assign([tall])
	var r: Rect2 = hud._place(Rect2(100, 230, 280, 18), true, "hint")
	ok(not r.intersects(tall), "moved off the panel")
	ok(r.end.y <= tall.position.y, "above it")


func test_top_messages_drop_below_the_wand_rows() -> void:
	# two long wand rows and the bag button on the left, a relic column on the right
	var rows := Rect2(4, 4, 206, 80)
	var relics := Rect2(380, 34, 96, 40)
	hud._taken.assign([rows, relics])
	var ban: Rect2 = hud._place(Rect2(170, 30, 140, 20), false, "banner")
	var toast: Rect2 = hud._place(Rect2(100, 30, 280, 18), false, "toast")
	ok(_clear([rows, relics, ban, toast]), "a room banner and a toast never cover the rows or the relics")
	ok(toast.position.y >= ban.end.y, "the toast comes under the banner")


func test_the_layout_resets_each_frame() -> void:
	hud._taken.assign([Rect2(0, 0, 10, 10)])
	hud._place(Rect2(100, 100, 50, 10), true, "hint")
	hud._ease_forget()
	eq(hud._eased.size(), 1, "a message drawn this frame keeps its eased y")
	hud._ease_forget()
	eq(hud._eased.size(), 0, "one that stopped showing forgets it, so it starts fresh next time")


func test_the_screen_is_never_narrower_than_the_layout() -> void:
	# 0.21: a 4:3 iPad rounded up to a scale that left a 341 px wide view
	for sz in [Vector2i(2048, 1536), Vector2i(2732, 2048), Vector2i(2556, 1179), Vector2i(1920, 1080), Vector2i(2388, 1668), Vector2i(1280, 720)]:
		var k: float = Game.scale_for(sz)
		ok(sz.x / k >= 480.0 and sz.y / k >= 270.0, "%s at x%d is %dx%d" % [sz, k, sz.x / k, sz.y / k])
	eq(Game.scale_for(Vector2i(1920, 1080)), 4.0, "a 1080p screen keeps 480x270")
	eq(Game.scale_for(Vector2i(390, 844)), 1.0, "a phone held upright on the web is not scaled to a speck")
