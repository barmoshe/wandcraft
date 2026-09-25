extends "res://tests/unit/world_fixture.gd"
## D3 (ADR 0014): relic stats and hooks, Merge Commit duos, Corrupted relics behind the
## Glitch Door, Compile evolutions at the forge and "Enables" chips.


func _alone(pos: Vector2) -> Enemy:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	var e := _dummy(pos)
	world.hash.rebuild(world.enemies)
	return e


func test_stats_fold_over_relics() -> void:
	var r := RunState.create(3)
	eq(Relics.stat(r, "dmg"), 1.0, "no relic, no change")
	r.add_relic(&"heap_overflow")
	r.add_relic(&"memory_leak")
	ok(is_equal_approx(Relics.stat(r, "dmg"), 1.3 * 1.5), "damage multiplies (%.2f)" % Relics.stat(r, "dmg"))
	eq(Relics.stat(r, "depth"), 3.0, "nesting depth 3 by default")
	r.add_relic(&"stack_overflow")
	eq(Relics.stat(r, "depth"), 5.0, "Stack Overflow: 5")
	eq(r.wand().depth_cap, 5, "pushed down to the wands")


func test_root_access_makes_runes_free() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([&"ifelse", &"mote", &"mote"])
	var before := WandProgram.compile(r.wand(), 0, Mods.new()).mana
	r.add_relic(&"root_access")
	var after := WandProgram.compile(r.wand(), 0, Mods.new()).mana
	eq(before - after, 2.0, "IF / ELSE no longer costs its 2 mana")


func test_stack_overflow_nests_deeper() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([&"mote", &"then", &"mote", &"then", &"mote", &"then", &"mote", &"then", &"mote", &"then", &"mote"])
	var depth := func() -> int:
		var c: CastNode = WandProgram.compile(r.wand(), 0, Mods.new()).groups[0]
		var n := 0
		while c.payload:
			c = c.payload
			n += 1
		return n
	eq(depth.call(), 3, "three payloads deep")
	r.add_relic(&"stack_overflow")
	eq(depth.call(), 5, "five with Stack Overflow")


func test_merge_commits_need_both_parents() -> void:
	var r := RunState.create(3)
	ok(not Relics.offerable(r, &"thermal_throttle"), "not offered with no parent")
	r.add_relic(&"wildfire")
	ok(not Relics.offerable(r, &"thermal_throttle"), "nor with one")
	eq(Relics.completes_duo(r, &"cold_boot"), &"thermal_throttle", "Cold Boot would complete it")
	r.add_relic(&"cold_boot")
	ok(Relics.offerable(r, &"thermal_throttle"), "offered once both are owned")


func test_corrupted_relics_only_behind_the_glitch_door() -> void:
	var r := RunState.create(3)
	for k in 40:
		for id in Rewards.roll_relics(r, 3):
			ok(int(Relics.DEFS[id]["rar"]) != 3, "a normal relic offer is never Corrupted (%s)" % id)
	var g := Rewards.offer(r, &"glitch")
	ok(g.filter(func(it: Dictionary) -> bool: return it["t"] == &"relic" and int(Relics.DEFS[it["id"]]["rar"]) == 3).size() == 2, "the Glitch Door pays two Corrupted relics")


func test_glitch_door_costs_max_hp() -> void:
	world.build_room("hall", &"empty")
	var hp := world.run.max_hp
	world.run.step = 2
	world.go_through({"kind": &"glitch", "reward": &"relic"})
	eq(world.run.max_hp, hp - Chapter.GLITCH_COST, "10 max HP to walk in")
	ok(world.waves.size() > 0, "and it is a fight")


func test_compile_evolves_a_level_three_spell() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([{"id": &"spark", "lv": 3}])
	eq(Rewards.compilable(r), [], "no catalyst yet")
	r.add_relic(&"cascade_failure")
	eq(Rewards.compilable(r), [&"storm_protocol"], "Chain Spark + Cascade Failure")
	ok(Rewards.compile_evo(r, &"storm_protocol"), "compiled")
	eq(String(r.wand().slots[0]["id"]), "storm_protocol", "in place")
	ok(r.has_relic(&"cascade_failure"), "a relic catalyst stays")


func test_compile_uses_up_a_spell_catalyst() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([{"id": &"null_orb", "lv": 3}])
	r.bag = [{"id": &"gravity", "lv": 1}]
	ok(Rewards.compile_evo(r, &"singularity"), "Null Orb + Gravity Rune")
	eq(String(r.wand().slots[0]["id"]), "singularity", "became the Singularity Kernel")
	eq(r.bag.size(), 0, "the Gravity Rune was used up")


func test_evolutions_are_never_offered() -> void:
	var r := RunState.create(3)
	for k in 300:
		ok(not Catalog.is_evolved(Rewards.roll_spell(r, 2)), "rewards never roll an evolution")


func test_enables_chips() -> void:
	var r := RunState.create(3)
	r.bag = [{"id": &"ember_coat", "lv": 1}]
	ok(Rewards.enables(r, {"t": &"spell", "id": &"frost_coat"}).has("Thermal Shock"), "Frost Coat with fire already: Thermal Shock")
	r.add_relic(&"wildfire")
	ok(Rewards.enables(r, {"t": &"relic", "id": &"cold_boot"}).has("Merge Commit"), "Cold Boot with Wildfire: a Merge Commit")
	r.wand().set_slots([&"spark"])
	ok(Rewards.enables(r, {"t": &"relic", "id": &"cascade_failure"}).has("Compile"), "Cascade Failure with a Chain Spark: Compile")


func test_loop_counter_makes_every_tenth_cast_free() -> void:
	_range_setup()
	world.run.add_relic(&"loop_counter")
	var w := _fire([&"mote"])
	world.spells.casts_fired = 9
	w.cd = 0.0
	var m := w.mana
	world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	eq(w.mana, m, "the 10th cast cost nothing")


func test_tail_call_repeats_the_last_cast() -> void:
	_range_setup()
	world.run.add_relic(&"tail_call")
	_fire([&"mote"])
	eq(world.spells.cast_seq, 2, "the closing cast went out twice")


func test_cold_start_and_legacy_code() -> void:
	_range_setup()
	world.run.add_relic(&"cold_start")
	var w := _fire([&"mote"])
	var base := world.spells.cast_bonus(w, false, false)
	eq(base, 1.5, "the Mote closed the cycle, so the next cast is a Cold Start")
	world.run.relics.erase(&"cold_start")
	world.run.add_relic(&"legacy_code")
	world.spells.legacy = true
	var c := WandProgram.compile(w, 0, Mods.new()).groups[0]
	world.damage_done = 0.0
	world.spells.emit_cast(c, world.player.tip(), -PI / 2.0, SpellRunner.Opt.new())
	_steps(0.5)
	ok(world.damage_done >= 6.0 * 2.5 - 0.01, "slot 1 hits x2.5 (%.1f)" % world.damage_done)


func test_rot_index_crashes_sooner() -> void:
	var e := _alone(Vector2(208, 120))
	world.run.add_relic(&"rot_index")
	var hp := e.hp
	for k in 3:
		world.add_rot(e, 1)
	ok(e.hp < hp - 15.0, "three stacks crash it")


func test_surge_protector_arcs_to_two() -> void:
	var a := _alone(Vector2(208, 120))
	var b := _dummy(Vector2(236, 120))
	var c := _dummy(Vector2(180, 120))
	world.run.add_relic(&"surge_protector")
	world.charge(a)
	world.hurt_enemy(a, 10.0, a.position, 0.0, 0.0)
	ok(b.hp < b.max_hp and c.hp < c.max_hp, "both neighbours took the arc")


func test_zero_day_always_crits_the_first_hit() -> void:
	var e := _alone(Vector2(208, 120))
	world.run.add_relic(&"zero_day")
	var d := world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0)
	eq(d, 20.0, "a guaranteed crit on an unhurt enemy")
	eq(world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0), 10.0, "then normal hits")


func test_absolute_zero_freezes_on_hit() -> void:
	_range_setup()
	_fire([&"absolute_zero"])
	_steps(0.5)
	ok(world.enemies.any(func(e: Enemy) -> bool: return e.frozen_t > 0.0), "a shard froze a dummy at once")


func test_version_control_rewards_merges() -> void:
	var r := RunState.create(3)
	r.add_relic(&"version_control")
	var mhp := r.max_hp
	r.bag.append({"id": &"fan", "lv": 1})
	r.add_spell(&"fan")
	eq(r.max_hp, mhp + 8.0, "a merge gave max HP")


func test_uptime_counts_clean_rooms() -> void:
	world.build_room("hall", &"empty")
	world.run.add_relic(&"uptime")
	world.run.uptime = 2
	world.hit_in_room = false
	world.call("_clear_room")
	eq(world.run.uptime, 3, "a clean room adds one")
	ok(is_equal_approx(Relics.dmg_mul(world.run, 10.0), 1.09), "+9%% damage")
	world.hit_in_room = true
	world.call("_clear_room")
	eq(world.run.uptime, 0, "a hit resets it")
