extends "res://tests/unit/world_fixture.gd"
## Design v3: the Garbage Collector, the second mini-boss.


func _arena() -> BossCollector:
	world.force_mini = &"collector"
	world.run.step = Chapter.PLAN.find(&"mini")
	world.build_room("arena_open", &"mini")
	world.call("_spawn_boss")
	var b := world.boss as BossCollector
	b.invuln = 0.0
	world.hash.rebuild(world.enemies)
	return b


func test_it_collects_your_shots_and_spits_them_back() -> void:
	var b := _arena()
	world.player.position = b.position + Vector2(0, 60)
	b.move = &"collect"
	b.sm = &"act"
	b.st_t = 1.4
	b._start(&"collect")
	b.sm = &"act"
	Game.inf_mana = true
	for i in 60:
		world.player.aim = (b.position - world.player.position).angle()
		world.spells.wand_fire(world.run.wand(), world.player.tip(), world.player.aim)
		world.step(DT)
	Game.inf_mana = false
	ok(b.eaten > 0, "it ate your shots (%d)" % b.eaten)
	var before := world.ebullets.active.filter(func(x: Bullet) -> bool: return x.alive).size()
	b._end(&"collect")
	var after := world.ebullets.active.filter(func(x: Bullet) -> bool: return x.alive).size()
	ok(after - before >= 5, "and spat them back (%d shots)" % (after - before))


func test_the_mini_boss_pool() -> void:
	world.force_mini = &""
	world.run.tutorial = true
	ok(world.mini_boss() is BossCopyPaste, "the lesson run meets Copy-Paste")
	world.run.tutorial = false
	world.run.seed_value = 10
	ok(world.mini_boss() is BossCollector, "an even seed meets the Garbage Collector")
	world.run.seed_value = 11
	ok(world.mini_boss() is BossCopyPaste, "an odd one Copy-Paste")


func test_it_can_be_beaten() -> void:
	var b := _arena()
	Game.god_mode = true
	Game.auto_fire = true
	world.bot = true
	world.run.wand().set_slots([&"burst", &"ember", &"spark"])
	var t := 0.0
	while not b.dead and t < 150.0:
		world.step(DT)
		t += DT
	ok(b.dead, "beaten in %.0f s (hp %.0f)" % [t, b.hp])
