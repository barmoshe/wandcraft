extends "res://tests/unit/test_helpers.gd"
## 0.20, World 3: every KernelArt piece bakes at a sane size, the new enemies bake as rigs,
## and the Kernel's room themes paint (and stay phone-cheap).


func _size_ok(t: Texture2D, lo: Vector2i, hi: Vector2i, what: String) -> void:
	ok(t != null, "%s bakes" % what)
	if t == null:
		return
	var s := Vector2i(t.get_size())
	ok(s.x >= lo.x and s.y >= lo.y and s.x <= hi.x and s.y <= hi.y, "%s is a sane size (got %s)" % [what, s])


func test_every_kernel_piece_bakes() -> void:
	for w in 2:
		for f in 5:
			_size_ok(KernelArt.thread(w, f), Vector2i(16, 16), Vector2i(24, 24), "thread %d.%d" % [w, f])
	for p in 3:
		for f in 5:
			_size_ok(KernelArt.glitch(p, f), Vector2i(36, 40), Vector2i(44, 48), "glitch %d.%d" % [p, f])
	for id in [&"grep", &"hotfix", &"cache"]:
		for f in 4:
			_size_ok(KernelArt.resident(id, f), Vector2i(14, 16), Vector2i(28, 30), "%s %d" % [id, f])
		for m in 4:
			for talk in [false, true]:
				for blink in [false, true]:
					var t := KernelArt.portrait(id, m, talk, blink)
					eq(Vector2i(t.get_size()), Vector2i(Hud.duck_face().get_size()), "%s's face matches the Duck's" % id)
	_size_ok(KernelArt.cage(false), Vector2i(26, 30), Vector2i(30, 34), "cage")
	_size_ok(KernelArt.cage(true), Vector2i(26, 30), Vector2i(30, 34), "open cage")
	_size_ok(KernelArt.clock("16:59:57"), Vector2i(30, 12), Vector2i(40, 16), "clock")
	for f in 4:
		_size_ok(KernelArt.revert_glyph(f), Vector2i(10, 10), Vector2i(14, 14), "revert glyph %d" % f)
		_size_ok(KernelArt.page(f), Vector2i(8, 10), Vector2i(12, 14), "page %d" % f)
	for r in [1, 4, 10, 16, 40]:
		var t := KernelArt.puddle(r, 0)
		var rr := clampi(r, 4, 16)
		eq(Vector2i(t.get_size()), Vector2i(rr * 2 + 2, rr * 2 + 2), "a puddle of radius %d is (2r+2) square" % r)
	for add in [false, true]:
		var t := KernelArt.diff_row(96, add)
		eq(Vector2i(t.get_size()), Vector2i(96, 16), "a diff row is one tile tall and as wide as asked")


func test_frames_differ() -> void:
	# an idle loop that never changes would read as a frozen sprite
	ok(KernelArt.thread(0, 0).get_image().get_data() != KernelArt.thread(0, 1).get_image().get_data(), "the twins run")
	ok(KernelArt.glitch(0, 0).get_image().get_data() != KernelArt.glitch(0, 2).get_image().get_data(), "the Glitch pulses")
	for id in [&"grep", &"hotfix", &"cache"]:
		ok(KernelArt.resident(id, 0).get_image().get_data() != KernelArt.resident(id, 3).get_image().get_data(), "%s idles" % id)
		ok(KernelArt.portrait(id, 0, false, false).get_image().get_data() != KernelArt.portrait(id, 0, false, true).get_image().get_data(), "%s blinks" % id)
		ok(KernelArt.portrait(id, 0, false, false).get_image().get_data() != KernelArt.portrait(id, 0, true, false).get_image().get_data(), "%s talks" % id)


func test_the_diff_rows_keep_their_roles() -> void:
	# the "-" row is an enemy attack (the threat ramp); the "+" row is safe (green)
	var minus := KernelArt.diff_row(32, false).get_image().get_pixel(8, 8)
	var plus := KernelArt.diff_row(32, true).get_image().get_pixel(8, 8)
	ok(minus.r > minus.g * 2.0, "the minus row is red")
	ok(plus.g > plus.r, "the plus row is green")


func test_the_new_enemies_bake() -> void:
	for k in ["leak", "null_ptr", "interrupt"]:
		ok(Bestiary.has(k), "%s has art" % k)
		var c := Bestiary.clips(k)
		for clip in ["move", "tele", "attack"]:
			ok((c[clip] as Array).size() > 0, "%s has a %s clip" % [k, clip])
		var s := Vector2i((c["move"][0] as Texture2D).get_size())
		ok(s.x >= 14 and s.x <= 24 and s.y >= 12 and s.y <= 26, "%s is enemy-sized (got %s)" % [k, s])
		ok(Bestiary.TELE_EYES.has(k), "%s's eyes light up when it winds up" % k)


func test_the_kernel_themes_paint() -> void:
	var gw := 20
	var gh := 12
	var grid := PackedByteArray()
	grid.resize(gw * gh)
	grid.fill(0)
	for x in gw:
		grid[x] = 1
		grid[(gh - 1) * gw + x] = 1
	for b in RoomPainter.THEMES.size():
		var t0 := Time.get_ticks_msec()
		var img := RoomPainter.paint(grid, gw, gh, 3, b)
		var ms := Time.get_ticks_msec() - t0
		eq(img.get_size(), RoomPainter.size_px(gw, gh), "theme %d paints the whole room" % b)
		ok(ms < 1500, "theme %d paints in reasonable time (%d ms)" % [b, ms])
		ok(Props.bramble(b) != null, "theme %d has a bramble" % b)
	# the Archive's floor stays dark, so white bullet cores read
	var arch := RoomPainter.paint(grid, gw, gh, 3, 4)
	var o := RoomPainter.MARGIN * RoomPainter.TS
	var lum := 0.0
	var n := 0
	for j in range(3 * 16, 9 * 16, 3):
		for i in range(2 * 16, 18 * 16, 3):
			lum += arch.get_pixel(o.x + i, o.y + j).get_luminance()
			n += 1
	ok(lum / n < 0.2, "the Archive floor is dark (mean luminance %.2f)" % (lum / n))
