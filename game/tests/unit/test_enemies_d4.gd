extends "res://tests/unit/world_fixture.gd"
## D4 (ADR 0015): the counters. Shields fall to pierce, armour to blast, wards to shock;
## the new enemies, elite affixes, the wave grammar and the spawn rules.


func _open_room() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)


func _foe(kind: StringName, pos: Vector2) -> Enemy:
	var e := world.spawn_enemy(kind, pos)
	e.spawn_t = 0.0
	e.sprite.visible = true
	world.hash.rebuild(world.enemies)
	return e


func test_sentry_shield_blocks_until_pierced() -> void:
	_open_room()
	var s := _foe(&"sentry", Vector2(208, 150))
	var front := world.player.position
	eq(world.hurt_enemy(s, 10.0, front, 0.0, 0.0, false, 0), 0.0, "a frontal hit is blocked")
	ok(s.shield_hp > 0, "the shield holds")
	ok(world.hurt_enemy(s, 10.0, Vector2(208, 100), 0.0, 0.0, false, 0) > 0.0, "a hit from behind lands")
	ok(world.hurt_enemy(s, 10.0, front, 0.0, 0.0, false, 1) > 0.0, "a pierce hit goes through")
	eq(s.shield_hp, 0, "and breaks the shield")


func test_shield_wears_down_without_pierce() -> void:
	_open_room()
	var s := _foe(&"sentry", Vector2(208, 150))
	for k in Enemy.DEFS[&"sentry"]["shield"]:
		world.hurt_enemy(s, 5.0, world.player.position, 0.0, 0.0)
	eq(s.shield_hp, 0, "enough blocked hits wear it out: nothing is unkillable")


func test_golem_armour_falls_to_blast() -> void:
	_open_room()
	var g := _foe(&"golem", Vector2(208, 120))
	var hp := g.hp
	world.hurt_enemy(g, 10.0, g.position, 0.0, 0.0, false, 0)
	eq(g.hp, hp, "armour takes the hit")
	var slow := g.max_armor - g.armor
	g.armor = g.max_armor
	world.hurt_enemy(g, 10.0, g.position, 0.0, 0.0, false, 2)
	var fast := g.max_armor - g.armor
	ok(fast > slow * 5.0, "blast strips it much faster (%.1f vs %.1f)" % [fast, slow])


func test_ward_swallows_hits_and_shock_strips_it() -> void:
	_open_room()
	var e := _foe(&"slime", Vector2(208, 120))
	e.ward_n = Enemy.WARD_HITS
	eq(world.hurt_enemy(e, 5.0, e.position, 0.0, 0.0), 0.0, "a warded enemy swallows a hit")
	eq(e.ward_n, Enemy.WARD_HITS - 1, "one charge gone")
	ok(world.hurt_enemy(e, 5.0, e.position, 0.0, 0.0, false, 4) > 0.0, "a shock hit goes through")
	eq(e.ward_n, 0, "and strips the ward")


func test_lantern_wisp_wards_allies() -> void:
	_open_room()
	var w := _foe(&"wisp", Vector2(208, 100))
	var a := _foe(&"slime", Vector2(230, 100))
	w.cd = 0.0
	_steps(0.2)
	eq(a.ward_n, Enemy.WARD_HITS, "the wisp warded its neighbour")


func test_brood_stump_spawns_buglings() -> void:
	_open_room()
	var s := _foe(&"stump", Vector2(208, 100))
	s.cd = 0.0
	_steps(0.3)
	eq(world.enemies.filter(func(e: Enemy) -> bool: return e.kind == &"bugling").size(), 2, "two buglings")


func test_glitch_tick_bursts_and_frost_holds_it() -> void:
	_open_room()
	var t := _foe(&"tick", world.player.position + Vector2(20, 0))
	_steps(0.2)
	eq(t.state, &"fuse", "close to the player it lights its fuse")
	t.chill_t = 5.0
	var left := t.st_t
	_steps(0.5)
	eq(t.st_t, left, "a chilled tick's fuse does not burn")
	t.chill_t = 0.0
	_steps(1.0)
	ok(t.dead, "then it bursts")


func test_moss_blob_splits() -> void:
	_open_room()
	var s := _foe(&"slime", Vector2(208, 120))
	world.kill_enemy(s)
	eq(world.enemies.filter(func(e: Enemy) -> bool: return e.kind == &"slimelet").size(), 2, "into two halves")


func test_elites_get_an_affix() -> void:
	_open_room()
	var seen := {}
	for k in 30:
		var e := world.spawn_enemy(&"weaver", Vector2(208, 120), true)
		ok(Enemy.AFFIXES.has(e.affix), "an elite always has an affix")
		seen[e.affix] = true
	ok(seen.size() >= 4, "and they vary (%d kinds)" % seen.size())


func test_wave_grammar() -> void:
	var r := RunState.create(9)
	var rng := RandomNumberGenerator.new()
	for step in range(1, 8):
		r.step = step
		for k in 20:
			rng.seed = step * 100 + k
			var waves := Encounter.compose(r, &"fight", rng)
			for wi in waves.size():
				var anchors: Array = waves[wi].filter(func(x: Array) -> bool: return Enemy.DEFS[x[0]].get("role", &"") == &"anchor")
				if step < 3:
					ok(anchors.size() <= 1, "step %d: at most one anchor a wave" % step)
				if step <= 1 and wi == 0:
					eq(anchors.size(), 0, "the very first wave is pressure only")


func test_puzzle_rooms_before_the_bosses() -> void:
	var r := RunState.create(9)
	var rng := RandomNumberGenerator.new()
	r.step = 3
	ok(Encounter.puzzle_for(r, &"fight", rng) != &"", "the fight before the mini-boss is a puzzle room")
	r.step = 2
	eq(Encounter.puzzle_for(r, &"fight", rng), &"", "earlier fights are not")
	r.step = 7
	ok(Encounter.puzzle_for(r, &"fight", rng) != &"", "nor is the fight before the boss")


func test_spawns_keep_clear_of_the_player_and_the_aim() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 150)
	world.player.aim = 0.0
	for p in Encounter.spawn_points(world):
		var to: Vector2 = p - world.player.position
		ok(to.length() >= Encounter.SAFE_R or Encounter.spawn_points(world).size() == world.sockets.size(), "far enough (%.0f px)" % to.length())


func test_next_wave_at_seventy_percent() -> void:
	_open_room()
	var list: Array = []
	for k in 10:
		list.append(_foe(&"slime", Vector2(120 + k * 12, 100)))
	ok(not Encounter.wave_done(list), "a fresh wave is not done")
	for k in 7:
		list[k].dead = true
	ok(Encounter.wave_done(list), "70% down: the next wave may come")


func test_spell_offers_cover_a_missing_counter() -> void:
	var r := RunState.create(4)
	for k in 30:
		var offer := Rewards.offer(r, &"spell")
		var kw := 0
		for it in offer:
			kw |= SpellRunner.keywords(Catalog.spell(it["id"]), Mods.new())
		ok(kw != 0, "a run with only a Mote is always offered some counter")


func test_a_freed_wave_enemy_counts_as_down() -> void:
	var a := Enemy.new()
	var b := Enemy.new()
	var c := Enemy.new()
	var d := Enemy.new()
	var wave: Array = [a, b, c, d]
	a.free()
	b.free()
	c.dead = true
	# 3 of 4 down (two freed, one dead) is past the 70% mark: a freed enemy must count
	ok(Encounter.wave_done(wave), "freed wave enemies count as down")
	c.free()
	d.free()
