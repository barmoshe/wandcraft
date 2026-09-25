extends "res://tests/unit/world_fixture.gd"
## The D2 spell system in the world (research/design-plan.md §1): statuses and reactions,
## the new shooting spells, familiars, runes at cast time and the new passives.


func _alone(pos: Vector2) -> Enemy:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	var e := _dummy(pos)
	world.hash.rebuild(world.enemies)
	return e


func _live(id: StringName) -> int:
	var n := 0
	for b in world.bullets.active:
		if b.alive and b.cast and b.cast.spell.id == id:
			n += 1
	return n


func test_thermal_shock_when_fire_meets_ice() -> void:
	var e := _alone(Vector2(208, 120))
	world.apply_status(e, 1, 0, 10.0)
	ok(e.burn_t > 0.0, "burning")
	var hp := e.hp
	world.apply_status(e, 0, 1, 10.0)
	ok(e.hp < hp - 10.0, "the chill set off a Thermal Shock (%.0f damage)" % (hp - e.hp))
	ok(e.burn_t <= 0.0 and e.chill_t <= 0.0, "which uses both statuses up")


func test_three_chills_freeze() -> void:
	var e := _alone(Vector2(208, 120))
	for k in 3:
		world.apply_status(e, 0, 1, 5.0)
	ok(e.frozen_t > 0.0, "frozen solid")
	var p := e.position
	e.ai = &"chase"
	e.tick(DT)
	eq(e.position, p, "and it cannot move")


func test_five_bitrot_stacks_crash() -> void:
	var e := _alone(Vector2(208, 120))
	for k in 4:
		world.add_rot(e, 1)
	eq(e.rot_n, 4, "four stacks")
	var hp := e.hp
	world.add_rot(e, 1)
	eq(e.rot_n, 0, "the fifth crashes it")
	ok(e.hp <= hp - 20.0, "for real damage (%.0f)" % (hp - e.hp))


func test_static_arcs_the_next_hit() -> void:
	var a := _alone(Vector2(208, 120))
	var b := _dummy(Vector2(240, 120))
	world.charge(a)
	world.hurt_enemy(a, 10.0, a.position, 0.0, 0.0)
	ok(b.hp < b.max_hp, "the hit arced to the neighbour")
	eq(a.static_t, 0.0, "and used the charge")


func test_two_statuses_overclock() -> void:
	var e := _alone(Vector2(208, 120))
	var plain := world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0)
	world.apply_status(e, 1, 0, 10.0)
	world.add_rot(e, 1)
	var over := world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0)
	ok(is_equal_approx(over, plain * 1.2), "Overclocked: +20%% (%.1f vs %.1f)" % [over, plain])


func test_firewall_stops_enemy_shots() -> void:
	_range_setup()
	_fire([&"firewall"])
	world.step(DT)
	ok(_live(&"firewall") >= 3, "a line of flames")
	var mid: Bullet = world.spells.blockers[world.spells.blockers.size() / 2]
	ok(world.spells.blocked(mid.pos, 2.5), "that blocks shots")
	world.enemy_shoot(mid.pos + Vector2(0, -30), PI / 2.0, 120.0, 5.0)
	_steps(0.5)
	eq(world.ebullets.live_count(), 0, "an enemy shot dies in it")


func test_hex_cursor_marks_and_payloads_follow() -> void:
	_range_setup()
	_fire([&"hexcursor"])
	_steps(0.6)
	ok(world.marked != null, "an enemy is marked")
	var far := world.marked
	eq(world.spells.target_near(world.player.position, 5.0), far, "payloads aim at the mark from anywhere")


func test_ping_delivers_on_the_nearest_enemy() -> void:
	_range_setup()
	Game.inf_mana = true
	_fire([&"ping", &"burst"])
	world.step(DT)
	Game.inf_mana = false
	ok(world.damage_done > 20.0, "the Rune Burst went off on the enemy at once (%.0f)" % world.damage_done)


func test_daemon_orbits_and_casts_its_payload() -> void:
	_range_setup()
	Game.inf_mana = true
	_fire([&"daemon", &"mote"])
	world.step(DT)
	eq(world.spells.summons.size(), 1, "a daemon is out")
	var seq := world.spells.cast_seq
	_steps(3.2)
	Game.inf_mana = false
	ok(world.spells.cast_seq >= seq + 2, "it cast its Mote a few times (%d)" % (world.spells.cast_seq - seq))
	ok(world.damage_done > 0.0, "and hit")


func test_familiar_caps() -> void:
	_range_setup()
	Game.inf_mana = true
	for k in 3:
		var w := _fire([&"turret"])
		_steps(0.2)
	Game.inf_mana = false
	eq(world.spells.summons.size(), 2, "at most two turrets")
	_steps(1.5)
	ok(world.damage_done > 0.0, "and they shoot")


func test_rubber_duck_draws_fire() -> void:
	_range_setup()
	_fire([&"duck"])
	world.step(DT)
	var dk := world.spells.decoy()
	ok(dk != null, "a duck is out")
	eq(world.target_pos(), dk.pos, "enemies go for the duck")
	var soak := dk.soak
	world.enemy_shoot(dk.pos + Vector2(0, -20), PI / 2.0, 120.0, 5.0)
	_steps(0.4)
	eq(dk.soak, soak - 1, "it soaked a shot")


func test_orbit_keeps_spells_around_you() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	_fire([&"orbit", &"mote"])
	_steps(1.0)
	eq(_live(&"mote"), 1, "the Mote is still out after a second")
	for b in world.bullets.active:
		if b.alive and b.cast and b.cast.spell.id == &"mote":
			ok(b.pos.distance_to(world.player.position + Player.HAND) < 32.0, "circling the caster")


func test_siphon_refunds_on_a_kill() -> void:
	_range_setup()
	for e in world.enemies:
		e.hp = 1.0
	var w := _fire([&"siphon", &"mote"])
	var after_cast := w.mana
	_steps(0.5)
	ok(w.mana > after_cast + 0.5, "a kill gave mana back (%.1f -> %.1f)" % [after_cast, w.mana])


func test_watchdog_makes_an_idle_cast_free() -> void:
	_range_setup()
	var w := WandState.make(Catalog.wand(&"apprentice"))
	w.set_slots([&"watchdog", &"mote"])
	world.run.wands[0] = w
	w.idle = 1.5
	var m := w.mana
	world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	eq(w.mana, m, "the idle cast cost nothing")
	w.cd = 0.0
	world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	ok(w.mana < m, "the next one pays")


func test_daemon_rod_fires_its_background_slot() -> void:
	_range_setup()
	var w := WandState.make(Catalog.wand(&"daemon_rod"))
	w.set_slots([null, null, null, null, null, &"mote"])
	world.run.wands[0] = w
	world.run.cur = 0
	w.bg_t = 0.0
	world.damage_done = 0.0
	_steps(1.0)
	ok(world.damage_done > 0.0, "the background Mote fired on its own")


func test_ifelse_picks_by_range() -> void:
	var e := _alone(Vector2(208, 100))   # far: more than 60 px from the wand
	_fire([&"ifelse", &"lance", &"ember"])
	eq(_live(&"ember"), 1, "nobody near: the ELSE branch (Ember Bolt)")
	e.position = Vector2(208, 180)
	_steps(1.5)
	world.damage_done = 0.0
	_fire([&"ifelse", &"lance", &"ember"])
	ok(world.damage_done > 0.0 and _live(&"ember") == 0, "enemy near: the Lance")


func test_pipeline_fires_in_a_line() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	_fire([&"pipeline", &"mote", &"mote", &"mote"])
	eq(_live(&"mote"), 1, "the first goes out at once")
	_steps(0.15)
	eq(_live(&"mote"), 3, "the rest follow a moment later")


func test_sleep_fires_after_its_time() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	Game.inf_mana = true
	_fire([&"quicken", &"mote", &"sleep", &"mote"])
	_steps(0.3)
	eq(world.spells.cast_seq, 1, "not yet")
	_steps(0.2)
	Game.inf_mana = false
	eq(world.spells.cast_seq, 2, "after 0.4 s the payload goes")


func test_reverse_fires_behind_at_bonus_damage() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	_fire([&"reverse", &"mote"])
	for b in world.bullets.active:
		if b.alive and b.cast and b.cast.spell.id == &"mote":
			ok(b.vel.y > 0.0, "flies backward")
			ok(is_equal_approx(b.dmg, 6.0 * SpellRunner.REVERSE_MUL), "for +60%")
