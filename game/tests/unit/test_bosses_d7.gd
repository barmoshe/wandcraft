extends "res://tests/unit/world_fixture.gd"
## D7 (ADR 0017): Copy-Paste copies your wand; the Infinite Loop's armoured head, breakable
## body, pylon derail and the head-only chase.


func _arena(kind: StringName) -> Boss:
	world.run.step = Chapter.PLAN.find(&"mini") if kind == &"mini" else Chapter.PLAN.size() - 1
	world.build_room("arena_open" if kind == &"mini" else "arena_ring", kind)
	world.call("_spawn_boss")
	var b: Boss = world.boss
	b.invuln = 0.0
	b.sm = &"idle"
	b.st_t = 99.0
	world.hash.rebuild(world.enemies)
	return b


func test_copy_paste_reads_your_wand() -> void:
	world.run.wand().set_slots([&"empower", &"fan", &"then", &"ember", &"needle", &"lance"])
	var b := _arena(&"mini") as BossCopyPaste
	eq(b.copied.map(func(c: Array) -> StringName: return c[0]), [&"fan", &"ember", &"needle"], "the first three shooting spells, in slot order")


func test_copy_cast_turns_spells_into_attacks() -> void:
	var b := _arena(&"mini") as BossCopyPaste
	var n0 := world.ebullets.live_count()
	b.cast_copy(&"fan", 1, b.position)
	ok(world.ebullets.live_count() > n0 + 2, "a Fan comes back as a spread")
	var n1 := world.ebullets.live_count()
	b.cast_copy(&"ember", 1, b.position)
	ok(world.ebullets.live_count() >= n1 + 8, "an Ember Bolt comes back as a ring")


func test_ctrl_z_opens_a_weak_window() -> void:
	var b := _arena(&"mini")
	b.call("_end", &"undo")
	ok(b.weak_t > 0.0, "it lags after the jump")
	var d := world.hurt_enemy(b, 10.0, b.position, 0.0, 0.0)
	eq(d, 15.0, "and takes x1.5 meanwhile")


func test_copy_paste_splits_in_phase_two() -> void:
	var b := _arena(&"mini") as BossCopyPaste
	b.hp = b.max_hp * 0.49
	_steps(0.3)
	ok(b.ghost != null and not b.ghost.dead, "a ghost copy appears")
	b.call("_start", &"select_all")
	ok(b.tele.any(func(t: Dictionary) -> bool: return t["k"] == "rect"), "Select All draws its box first")


func test_loop_head_is_armoured_and_the_body_is_soft() -> void:
	var b := _arena(&"boss")
	ok(b.armor > 0.0, "the head wears armour")
	var hp := b.hp
	world.hurt_enemy(b, 20.0, b.position, 0.0, 0.0)
	eq(b.hp, hp, "a plain hit on the head is soaked")
	world.hurt_enemy(b.parts[0], 20.0, b.parts[0].position, 0.0, 0.0)
	ok(is_equal_approx(b.hp, hp - 20.0 * 0.4), "the body passes 40%% straight through (%.1f)" % (hp - b.hp))


func test_loop_body_breaks_in_phase_two() -> void:
	var b := _arena(&"boss") as BossLoop
	b.hp = b.max_hp * 0.6
	_steps(0.4)   # past the phase change's hit-stop
	eq(b.phase, 1, "phase 2")
	var n := b.parts.size()
	for i in 3:
		world.hurt_enemy(b.parts[b.parts.size() - 1], 999.0, b.position, 0.0, 0.0)
		_steps(0.1)   # past the kill's hit-stop
	eq(b.parts.size(), n - 3, "three segments broke off")
	ok(world.enemies.any(func(e: Enemy) -> bool: return e.kind == &"loop_jr" and not e.dead), "and a Loop Jr. hunts on its own")


func test_four_pylon_pulses_derail_the_loop() -> void:
	var b := _arena(&"boss") as BossLoop
	b.hp = b.max_hp * 0.6
	_steps(0.4)
	for k in BossLoop.PYLONS_TO_DERAIL:
		b.on_pylon()
	ok(b.derail_t > 0.0, "derailed")
	eq(b.weak_mul, 2.0, "and it takes double damage")


func test_loop_phase_three_is_the_head_alone() -> void:
	var b := _arena(&"boss") as BossLoop
	b.hp = b.max_hp * 0.25
	_steps(0.5)
	eq(b.phase, 2, "phase 3")
	eq(b.parts.size(), 0, "the body fell away")
	eq(b.armor, 0.0, "and the armour with it")
