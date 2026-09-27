extends "res://tests/unit/world_fixture.gd"
## World 2 (research/design-w2.md): the exit after the Loop leads on, Deadlock's locks and
## beam, and the Foundry's enemies.


func _deadlock() -> BossDeadlock:
	world.run.world = 1
	world.run.step = Chapter.PLAN.size() - 1
	world.build_room("arena_ring", &"boss")
	world.call("_spawn_boss")
	var b := world.boss as BossDeadlock
	b.invuln = 0.0
	b.sm = &"idle"
	b.st_t = 99.0
	world.hash.rebuild(world.enemies)
	return b


func test_the_loops_exit_leads_to_world_two() -> void:
	world.run.step = Chapter.PLAN.size() - 1
	world.go_through({"kind": "exit"})
	eq(world.run.world, 1, "on to World 2")
	eq(world.run.step, 0, "at its start room")
	ok(not world.run.won, "the run goes on")
	eq(world.room_kind, &"start", "a start room")
	eq(world.biome(), 2, "the Cooling Vents")
	eq(Chapter.area_name(6, 1), "The Molten Core", "and the Molten Core after the mini-boss")
	eq(Chapter.depth(world.run), 10, "difficulty counts on from World 1")
	world.run.step = Chapter.PLAN.size() - 1
	world.go_through({"kind": "exit"})
	ok(world.run.won, "World 2's exit wins the run")


func test_world_two_meets_the_other_mini_boss() -> void:
	world.run.seed_value = 3   # odd: World 1 meets Copy-Paste
	world.run.tutorial = false
	ok(world.mini_boss() is BossCopyPaste, "World 1: Copy-Paste")
	world.run.world = 1
	ok(world.mini_boss() is BossCollector, "World 2: the Garbage Collector")


func test_deadlock_is_its_boss_and_one_guardian_is_locked() -> void:
	var b := _deadlock()
	ok(b is BossDeadlock, "Deadlock appeared")
	ok(b.mutex_b != null, "with Mutex B")
	ok(b.locked != b.mutex_b.locked, "exactly one of them is locked")
	var locked_one: Enemy = b if b.locked else b.mutex_b
	var open_one: Enemy = b.mutex_b if b.locked else b
	var hp0 := b.hp
	world.hurt_enemy(locked_one, 50.0, locked_one.position, 0.0, 0.0)
	eq(b.hp, hp0, "the locked one takes nothing")
	world.hurt_enemy(open_one, 50.0, open_one.position, 0.0, 0.0)
	ok(b.hp < hp0, "the open one takes the hit (%.0f)" % (hp0 - b.hp))


func test_the_lock_changes_hands() -> void:
	var b := _deadlock()
	var was := b.b_open
	b.sm = &"idle"
	b.st_t = 99.0
	b.swap_t = 0.05
	_steps(0.2)
	ok(b.b_open != was, "on its timer")
	was = b.b_open
	var open_one: Enemy = b.mutex_b if b.b_open else b
	world.hurt_enemy(open_one, BossDeadlock.SWAP_DMG + 5.0, open_one.position, 0.0, 0.0)
	_steps(0.05)
	ok(b.b_open != was, "and sooner once the open one has taken enough")


func test_the_burning_beam_hurts_and_the_cold_one_does_not() -> void:
	Game.god_mode = false
	var b := _deadlock()
	var mid := (b.position + b.mutex_b.position) / 2.0 + Vector2(0, -4)
	world.player.position = mid
	world.player.hp = 100.0
	b.beam = 0
	b.tick(DT)
	eq(world.player.hp, 100.0, "a cold beam is only a thread")
	# a Sweep in progress: the beam burns
	b.move = &"sweep"
	b.sm = &"act"
	b.st_t = 5.0
	b.beam = 2
	world.player.position = (b.position + b.mutex_b.position) / 2.0 + Vector2(0, -4)
	b.tick(DT)
	ok(world.player.hp < 100.0, "a burning one hurts")
	Game.god_mode = true


func test_phase_three_breaks_the_locks() -> void:
	var b := _deadlock()
	b.hp = b.max_hp * 0.2
	b.invuln = 0.0
	b.tick(DT)
	eq(b.phase, 2, "phase 3")
	ok(not b.locked and not b.mutex_b.locked, "both take damage now")


func test_a_proxy_takes_its_allies_hits() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	var p := _dummy(Vector2(208, 120))
	p.def = Enemy.DEFS[&"proxy"]
	var ally := _dummy(Vector2(230, 120))
	var hp_p := p.hp
	var hp_a := ally.hp
	world.hurt_enemy(ally, 20.0, ally.position, 0.0, 0.0)
	eq(ally.hp, hp_a, "the ally is covered")
	ok(p.hp < hp_p, "the Proxy took it")
	ally.position = Vector2(208 + Enemy.PROXY_R + 20.0, 120)
	world.hurt_enemy(ally, 20.0, ally.position, 0.0, 0.0)
	ok(ally.hp < hp_a, "out of its reach, the ally is not")


func test_kernel_panic_runs_at_half_hp_and_bursts() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	var e := world.spawn_enemy(&"kernel_panic", Vector2(208, 120))
	e.spawn_t = 0.0
	world.hash.rebuild(world.enemies)
	world.hurt_enemy(e, e.max_hp * 0.55, e.position, 0.0, 0.0)
	world.step(DT)
	ok(e.panicked and e.state == &"fuse", "half its HP gone: it panics")
	var d0 := e.position.distance_to(world.player.position)
	_steps(0.5)
	ok(e.dead or e.position.distance_to(world.player.position) < d0, "and runs at you")
	_steps(1.2)
	ok(e.dead, "then bursts")
