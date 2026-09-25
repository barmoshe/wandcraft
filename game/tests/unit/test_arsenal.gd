extends "res://tests/unit/world_fixture.gd"
## The 0.4 arsenal (research/arsenal-v04.md): new spell behaviors, boosts and the trigger.


func _hurt_count() -> int:
	var n := 0
	for e in world.enemies:
		if e.hp < e.max_hp:
			n += 1
	return n


func test_boomerang_disc_returns_and_hits_twice() -> void:
	_range_setup()
	var one := Catalog.spell(&"disc").damage_at(1)
	_fire([&"disc"])
	_steps(0.4)
	var out := world.damage_done
	_steps(1.6)
	ok(out > 0.0, "the disc hits on the way out")
	ok(world.damage_done >= out + one * 0.9, "and again on the way back (%.0f -> %.0f)" % [out, world.damage_done])
	eq(world.bullets.active.filter(func(b: Bullet) -> bool: return b.alive).size(), 0, "it ends back in the hand")


func test_glitch_mine_arms_then_blasts() -> void:
	_range_setup()
	_fire([&"mine"])
	_steps(0.2)
	eq(world.damage_done, 0.0, "a mine does nothing before it arms")
	_steps(1.5)
	ok(world.damage_done >= Catalog.spell(&"mine").damage_at(1), "then it blasts the dummies (%.0f)" % world.damage_done)
	ok(_hurt_count() >= 2, "the blast has an area (%d hurt)" % _hurt_count())


func test_static_cone_hits_everything_in_front() -> void:
	_range_setup()
	_fire([&"static"])
	_steps(0.1)
	eq(_hurt_count(), 4, "all four dummies stand inside the cone")


func test_null_orb_drags_enemies_in() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	var e := _dummy(Vector2(240, 150))
	var before := e.position.x
	_fire([&"null_orb"])
	_steps(1.4)
	ok(e.position.x < before - 4.0, "the dummy is pulled toward the orb's path (%.1f -> %.1f)" % [before, e.position.x])


func test_split_rune_spreads_the_hit() -> void:
	_range_setup()
	_fire([&"mote"])
	_steps(1.0)
	var alone := _hurt_count()
	_range_setup()
	_fire([&"split", &"mote"])
	_steps(1.0)
	ok(_hurt_count() > alone, "splitting reaches more dummies (%d vs %d)" % [_hurt_count(), alone])


func test_gravity_rune_pulls_toward_bolts() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	var e := _dummy(Vector2(236, 120))
	var before := e.position.x
	_fire([&"gravity", &"quicken", &"mote"])
	_steps(0.8)
	ok(e.position.x < before - 1.0, "a passing bolt drags the dummy (%.1f -> %.1f)" % [before, e.position.x])


func test_finally_fires_on_a_kill() -> void:
	_range_setup()
	var first: Enemy = world.enemies[0]
	first.hp = 1.0
	_fire([&"mote", &"finally", &"mote"])
	_steps(1.2)
	ok(first.dead, "the weak dummy dies")
	ok(world.spells.cast_seq >= 2, "and its death releases the payload")


func test_finally_does_nothing_without_a_kill() -> void:
	_range_setup()
	_fire([&"mote", &"finally", &"mote"])
	_steps(1.2)
	eq(world.spells.cast_seq, 1, "no kill, no payload")


# ------------------------------------------------------------------ relics (0.4)

func _give(id: StringName) -> void:
	world.run.relics.append(id)


func test_busy_wait_charges_a_still_cast() -> void:
	_range_setup()
	_fire([&"mote"])
	_steps(0.8)
	var plain := world.damage_done
	_range_setup()
	_give(&"busy_wait")
	world.player.still_t = 1.0
	_fire([&"mote"])
	_steps(0.8)
	ok(world.damage_done >= plain * 1.5, "a charged cast hits harder (%.0f vs %.0f)" % [world.damage_done, plain])


func test_buffer_overflow_turns_overheal_into_a_shield() -> void:
	_give(&"buffer_overflow")
	var p := world.player
	p.hp = p.max_hp - 5.0
	p.heal(20.0)
	eq(p.shield, 15.0, "15 of the 20 heal becomes shield")
	Game.god_mode = false
	p.inv = 0.0
	p.hurt(10.0, p.position + Vector2(10, 0))
	Game.god_mode = true
	eq(p.hp, p.max_hp, "the shield takes the hit")
	eq(p.shield, 5.0, "and shrinks")


func test_stack_trace_fires_backward_every_7th_cast() -> void:
	_range_setup()
	_give(&"stack_trace")
	Game.inf_mana = true
	var before := world.spells.casts_fired
	var seq := 0
	for i in 7:
		var w := _fire([&"mote"])
		seq += world.spells.cast_seq
		w.cd = 0.0
	Game.inf_mana = false
	eq(seq, 8, "seven casts, one of them twice (from %d)" % before)


func test_cascade_failure_arcs_crits() -> void:
	_range_setup()
	_give(&"cascade_failure")
	world.hash.rebuild(world.enemies)
	var a: Enemy = world.enemies[0]
	world.hurt_enemy(a, 10.0, world.player.position, 1.0, 0.0)
	var others := world.enemies.filter(func(e: Enemy) -> bool: return e != a and e.hp < e.max_hp)
	eq(others.size(), 1, "one other enemy takes the arc")


func test_cold_boot_amplifies_chilled_targets() -> void:
	_range_setup()
	_give(&"cold_boot")
	var e: Enemy = world.enemies[0]
	var d0 := world.hurt_enemy(e, 20.0, world.player.position, 0.0, 0.0)
	world.apply_status(e, 0, 1, 0.0)
	var d1 := world.hurt_enemy(e, 20.0, world.player.position, 0.0, 0.0)
	eq(d1, d0 * 1.25, "chilled: +25%")


func test_wildfire_spreads_burn_on_death() -> void:
	_range_setup()
	_give(&"wildfire")
	world.hash.rebuild(world.enemies)
	var e: Enemy = world.enemies[2]   # (186,140), next to (208,150) and (230,140)
	world.apply_status(e, 2, 0, 20.0)
	e.hp = 1.0
	world.hurt_enemy(e, 5.0, world.player.position, 0.0, 0.0)
	var lit := world.enemies.filter(func(o: Enemy) -> bool: return o != e and o.burn_t > 0.0)
	ok(lit.size() >= 1, "a neighbour catches fire (%d)" % lit.size())


func test_bug_bounty_releases_a_bug() -> void:
	_range_setup()
	_give(&"bug_bounty")
	var e: Enemy = world.enemies[0]
	var n := world.bullets.live_count()
	world.kill_enemy(e)
	eq(world.bullets.live_count(), n + 1, "a kill releases one bug")


func test_event_loop_repeats_payloads() -> void:
	_range_setup()
	_give(&"event_loop")
	_fire([&"mote", &"then", &"mote"])
	_steps(1.2)
	eq(world.spells.cast_seq, 3, "the cast, its payload, and the payload's echo")


func test_rewards_lean_toward_owned_tags() -> void:
	var owned := {"Burn": 1}
	eq(Rewards.tag_weight(["Burn"], owned), 1.6, "one shared tag")
	eq(Rewards.tag_weight(["Burn", "Area"], {"Burn": 1, "Area": 2}), 2.5, "capped at x2.5")
	eq(Rewards.tag_weight(["Frost"], owned), 1.0, "no shared tag, no bias")


func test_cut_relics_drop_out_of_old_saves() -> void:
	var r := RunState.create(5)
	var d := r.to_dict()
	d["relics"] = ["cache_line", "lucky_bit", "wildfire", "keen_scope"]
	var back := RunState.from_dict(d)
	eq(back.relics, [&"wildfire"] as Array[StringName], "only relics that still exist are kept (Lucky Bit was cut in D3)")
