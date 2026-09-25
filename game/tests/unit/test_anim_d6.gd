extends "res://tests/unit/test_helpers.gd"
## D6: rigs, frame budgets, the pre-rotated wand, telegraph decals, damage-number merging.

const DT := 1.0 / 60.0
var world: World


func setup(tree: SceneTree) -> void:
	SaveGame.enabled = false
	Game.god_mode = true
	Game.auto_fire = false
	world = World.new()
	world.auto_step = false
	tree.root.add_child(world)
	world.setup(9)
	world.start_run(RunState.create(9))


func teardown() -> void:
	SaveGame.enabled = true
	Game.god_mode = false
	Game.auto_fire = true
	world.free()


func test_hero_meets_the_frame_budget_in_both_facings() -> void:
	# design-plan §8: idle 4, run 6, cast 3, dash 4, hurt 2, death 6 (25 per facing)
	var want := {"idle": 4, "run": 6, "cast": 3, "dash": 4, "hurt": 2, "death": 6}
	for back in [false, true]:
		var c := Hero.clips(back)
		for k in want:
			ok(c.has(k) and (c[k] as Array).size() == want[k], "hero %s %s has %d frames" % ["back" if back else "front", k, want[k]])
		ok(Hero.rig(back).frame_count() == 25, "25 frames per facing")
		var sz: Vector2i = (c["idle"][0] as Texture2D).get_size()
		for k in c:
			for t in c[k]:
				ok(Vector2i((t as Texture2D).get_size()) == sz, "every hero frame is the same size (%s)" % k)


func test_every_enemy_has_move_tele_attack() -> void:
	for k in Bestiary.ART:
		var c := Bestiary.clips(k)
		ok((c["move"] as Array).size() == 4 and (c["tele"] as Array).size() == 2 and (c["attack"] as Array).size() == 2,
			"%s: move 4, tele 2, attack 2" % k)
		# the telegraph must look different from walking
		var a := (c["move"][0] as Texture2D).get_image()
		var b := (c["tele"][1] as Texture2D).get_image()
		ok(a.get_data() != b.get_data(), "%s's wind-up changes its pixels" % k)


func test_bakes_are_deterministic_and_whole_pixel() -> void:
	var r := Hero.rig(false)
	var pose: Dictionary = r.clips["run"]["poses"][1]
	var a := RigBaker.pose_image(r, pose)
	var b := RigBaker.pose_image(r, pose)
	ok(a.get_data() == b.get_data(), "the same pose bakes the same pixels")
	# pixels are either fully opaque or fully clear: no fractional scaling ever blends them
	var partial := 0
	for j in a.get_height():
		for i in a.get_width():
			var al := a.get_pixel(i, j).a
			if al > 0.0 and al < 1.0:
				partial += 1
	ok(partial == 0, "no half-transparent pixels in a baked frame (%d)" % partial)


func test_squash_keeps_the_feet_planted() -> void:
	var rows := ["..a..", ".bbb.", "ccccc", ".ddd.", "..e.."]
	var sq := RigBaker.squash(rows, 1)
	ok(sq.size() == 4 and sq[sq.size() - 1] == "..e..", "a squash removes a row and keeps the bottom one")
	var st := RigBaker.squash(rows, -2)
	ok(st.size() == 7 and st[0] == "..a.." and st[6] == "..e..", "a stretch repeats a middle row")


func test_the_wand_has_sixteen_angles() -> void:
	var w := Hero.wand_angles()
	ok(w.size() == 16, "16 wand angles")
	var sz := w[0].get_size()
	for t in w:
		ok(t.get_size() == sz, "all wand angles share one canvas")
	# pointing right and pointing left are mirror images, near enough (same pixel count)
	var count := func(t: Texture2D) -> int:
		var img := t.get_image()
		var n := 0
		for j in img.get_height():
			for i in img.get_width():
				if img.get_pixel(i, j).a > 0.0:
					n += 1
		return n
	var r: int = count.call(w[0])
	var l: int = count.call(w[8])
	ok(absi(r - l) <= r / 4, "the wand keeps its size when rotated (%d vs %d)" % [r, l])


func test_the_player_turns_away_when_aiming_up() -> void:
	var p := world.player
	p.aim = -PI / 2.0
	p._animate()
	ok(p.back, "aiming straight up shows the back view")
	p.aim = PI / 2.0
	p._animate()
	ok(not p.back, "aiming down shows the front")
	p.cast_t = 0.1
	ok(p.pick_clip() == "cast", "casting picks the cast clip")


func test_telegraphs_fill_as_the_attack_nears() -> void:
	var e := world.spawn_enemy(&"golem", world.player.position + Vector2(30, 0))
	e.spawn_t = 0.0
	e.state = &"tele"
	e.st_t = 0.8
	var t0 := e.telegraph()
	e.st_t = 0.2
	var t1 := e.telegraph()
	ok(t0.get("k", "") == "circle", "the golem telegraphs a circle")
	ok(float(t1["fill"]) > float(t0["fill"]), "the decal fills as the slam nears (%.2f -> %.2f)" % [t0["fill"], t1["fill"]])
	e.state = &"move"
	ok(e.telegraph().is_empty(), "no decal while it walks")


func test_hits_on_one_target_merge_into_one_number() -> void:
	var fx := world.fx
	fx.texts.clear()
	fx.number(Vector2.ZERO, 5.0, false, 42)
	fx.number(Vector2.ZERO, 7.0, false, 42)
	fx.number(Vector2.ZERO, 3.0, true, 42)
	ok(fx.texts.size() == 1 and fx.texts[0][1] == "15", "three quick hits read as one 15")
	ok(fx.texts[0][2] == Color("#ffe066"), "a crit in the merge turns the number gold")
	fx.update(0.2)
	fx.number(Vector2.ZERO, 4.0, false, 42)
	ok(fx.texts.size() == 2, "a hit after 150 ms starts a new number")
	fx.number(Vector2.ZERO, 4.0, false, 7)
	ok(fx.texts.size() == 3, "another target gets its own number")


func test_walls_with_floor_behind_get_a_front_cap() -> void:
	world.force_tpl = "pillars"
	world.build_room("pillars", &"empty")
	ok(not world._lips.is_empty(), "the pillar room has front-cap lips")
	for s in world._lips:
		var tx := int(s.position.x) / World.TS
		var ty := int(s.position.y) / World.TS
		ok(world._lip_at(tx, ty), "a lip sits on a wall tile with floor above it")
		ok(s.get_parent() == world._actors, "lips are y-sorted with the actors")
	ok(world.life.tufts.size() > 0, "the room has grass tufts")


func test_the_dash_moves_fast_with_iframes_and_a_cooldown() -> void:
	# D9 (lives here with the player's other feel tests)
	Game.god_mode = false
	var p := world.player
	world.build_room("hall", &"empty")
	var from := p.position
	world.controls.move = Vector2.RIGHT
	world.controls.dash = true
	world.step(1.0 / 60.0)
	ok(p.dash_t > 0.0 and p.dash_inv > 0.0, "a dash starts with i-frames")
	var hp0 := p.hp
	p.hurt(10.0, p.position + Vector2(10, 0))
	ok(p.hp == hp0, "a hit during the dash's i-frames does nothing")
	for i in 12:
		world.step(1.0 / 60.0)
	ok(p.position.x - from.x > 35.0, "the dash covers ground (%.0f px)" % (p.position.x - from.x))
	world.controls.dash = true
	world.step(1.0 / 60.0)
	ok(p.dash_t <= 0.0, "no second dash inside the cooldown")
	ok(world.fx.ghosts.size() >= 2, "the dash leaves afterimages (%d)" % world.fx.ghosts.size())
	world.controls.move = Vector2.ZERO
	Game.god_mode = true
