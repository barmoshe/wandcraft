extends "res://tests/unit/world_fixture.gd"
## 0.21 relics: Area (Crowd Blast, Blast Share, Scorch Zone, the Aftershock super), summons
## (Shared Boosts, Summon Refund, the Summon Volley super), Shock (Shock Charge, Charged
## Strike), Frost (Frost Spread, Quick Freeze) and the rule relics (Clean Streak, Risky Code,
## Relic Copy, Fixed Vitals, Wand Variety). Plus the two new systems: Relics.DEPENDS (supers
## wait for two relics of a tag) and Relics.RIVALS (Merge Conflicts shut each other out).

const NEW := [&"load_spike", &"side_effects", &"burn_in", &"chain_reaction", &"inheritance", &"graceful_exit",
	&"hive_mind", &"live_wire", &"overvoltage", &"cold_spill", &"flash_freeze", &"clean_build", &"risky_code",
	&"git_clone", &"version_pin", &"code_coverage"]


func _alone(pos: Vector2) -> Enemy:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)
	var e := _dummy(pos)
	world.hash.rebuild(world.enemies)
	return e


## The wand tip with the aim straight up (where a Rune Burst goes off).
func _tip() -> Vector2:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)
	world.player.aim = -PI / 2.0
	return world.player.tip()


func _hurt(e: Enemy) -> bool:
	return e.hp < e.max_hp


func test_the_round_is_sixteen_tagged_relics_with_icons() -> void:
	eq(NEW.size(), 16, "sixteen relics")
	var vocab := {}
	for id in Catalog.TAGS:
		for t in Catalog.TAGS[id]:
			vocab[t] = true
	for id in NEW:
		ok(Relics.DEFS.has(id), "%s is a relic" % id)
		ok(int(Relics.DEFS[id]["rar"]) < 3, "%s is not Corrupted" % id)
		ok(not IconArt.relic(id).is_empty(), "%s has an icon" % id)
		for t in Relics.tags(id):
			ok(vocab.has(t), "%s: tag %s is in the vocabulary" % [id, t])
	var area := NEW.filter(func(id: StringName) -> bool: return Relics.tags(id).has("Area")).size()
	ok(area >= 3, "three or more Area relics (%d)" % area)


func test_crowd_blast_grows_with_the_room() -> void:
	var r := RunState.create(3)
	eq(Relics.blast_mul(r, 5), 1.0, "without the relic, no change")
	r.add_relic(&"load_spike")
	ok(is_equal_approx(Relics.blast_mul(r, 3), 1.18), "three enemies: +18%")
	ok(is_equal_approx(Relics.blast_mul(r, 30), 1.48), "capped at +48%")
	# a Rune Burst (radius 30, 8 px past the tip) misses a dummy 38 px from its center, until
	# the crowd makes it reach
	var hit := func(relic: bool) -> bool:
		var t := _tip()
		var e := _dummy(t + Vector2(0, -46))
		for p in [Vector2(60, 60), Vector2(360, 60), Vector2(60, 100), Vector2(360, 100)]:
			_dummy(p)
		world.run.relics.clear()
		if relic:
			world.run.add_relic(&"load_spike")
		_fire([&"burst"])
		return _hurt(e)
	ok(not hit.call(false), "a plain burst falls short")
	ok(hit.call(true), "five enemies up: the burst reaches it")


func test_blast_share_passes_statuses_around() -> void:
	var t := _tip()
	var a := _dummy(t + Vector2(-8, -6))
	var b := _dummy(t + Vector2(8, -6))
	a.burn_t = 2.0
	a.burn_dps = 9.0
	b.rot_n = 2
	b.rot_t = 3.0
	world.run.add_relic(&"side_effects")
	_fire([&"burst"])
	ok(b.burn_t > 0.0 and b.burn_dps >= 9.0, "the fire reached the other enemy")
	eq(a.rot_n, 2, "and the Bitrot came back the other way")


func test_scorch_zone_sets_standing_enemies_on_fire() -> void:
	var t := _tip()
	var e := _dummy(t + Vector2(0, -10))
	world.run.add_relic(&"burn_in")
	_fire([&"burst"])
	eq(world.spells.relic_fx.zones.size(), 1, "the blast left scorched ground")
	world.step(DT)
	ok(e.burn_t > 0.0, "an enemy standing on it catches fire")
	_steps(2.0)
	eq(world.spells.relic_fx.zones.size(), 0, "and it burns out")


func test_aftershock_waits_for_two_area_relics_then_echoes() -> void:
	var r := RunState.create(3)
	ok(not Relics.offerable(r, &"chain_reaction"), "no Area relic: not offered")
	eq(Relics.depends_count(r, &"chain_reaction"), [0, 2], "0 of 2")
	r.add_relic(&"load_spike")
	ok(not Relics.offerable(r, &"chain_reaction"), "one is not enough")
	eq(Relics.completes_super(r, &"burn_in"), &"chain_reaction", "Scorch Zone would resolve it")
	ok(Rewards.enables(r, {"t": &"relic", "id": &"burn_in"}).has("Super"), "so its card shows a Super chip")
	r.add_relic(&"burn_in")
	ok(Relics.resolved(r, &"chain_reaction"), "resolved")
	ok(Relics.offerable(r, &"chain_reaction"), "offered with two")
	var rows := Relics.depends_state(r, &"chain_reaction")
	eq(rows.map(func(row: Dictionary) -> StringName: return row["by"]), [&"load_spike", &"burn_in"], "each need met by a different relic")
	var fresh := RunState.create(3)
	for k in 80:
		ok(not Rewards.roll_relics(fresh, 3).has(&"chain_reaction"), "never offered unresolved")
	# the echo: a second, smaller blast a moment later
	var t := _tip()
	var e := _dummy(t + Vector2(0, -10))
	for id in [&"load_spike", &"burn_in", &"chain_reaction"]:
		world.run.add_relic(id)
	_fire([&"burst"])
	var first := e.max_hp - e.hp
	ok(first > 0.0, "the blast hit")
	_steps(0.4)
	ok(e.max_hp - e.hp > first, "and the aftershock hit again (%.1f then %.1f)" % [first, e.max_hp - e.hp])


func test_shared_boosts_power_summons() -> void:
	var r := RunState.create(3)
	var w := WandState.make(Catalog.wand(&"apprentice"))
	w.set_slots([&"empower", &"quicken", &"turret"])
	eq(Relics.summon_mul(r, w), 1.0, "without the relic, no change")
	r.add_relic(&"inheritance")
	ok(is_equal_approx(Relics.summon_mul(r, w), 1.3), "two boosts: +30%")
	# in the world: a turret's bolt
	_alone(Vector2(208, 120))
	world.run.add_relic(&"inheritance")
	var s := SpellRunner.Summon.new()
	s.src = w
	s.color = Color.WHITE
	world.spells.call("_familiar_bolt", s, Vector2(208, 180), -PI / 2.0, 10.0)
	var b: Bullet = world.spells.bullets.active[world.spells.bullets.active.size() - 1]
	ok(is_equal_approx(b.dmg, 13.0), "the bolt deals 13, not 10 (%.1f)" % b.dmg)


func test_summon_refund_gives_mana_back() -> void:
	_range_setup()
	var w := _fire([&"turret"])
	eq(world.spells.summons.size(), 1, "a turret is out")
	var cost := Catalog.spell(&"turret").mana_at(1)
	eq(world.spells.summons[0].cost, cost, "it knows its cost")
	var ended := func(relic: bool) -> float:
		world.run.relics.clear()
		if relic:
			world.run.add_relic(&"graceful_exit")
		var s := SpellRunner.Summon.new()
		s.kind = &"turret"
		s.src = w
		s.cost = cost
		s.life = 0.01
		world.spells.summons.clear()
		world.spells.summons.append(s)
		w.mana = 0.0
		world.spells.call("_update_summons", 0.05)
		return w.mana
	eq(ended.call(false), 0.0, "no relic: nothing back")
	ok(is_equal_approx(ended.call(true), cost * 0.5), "half its mana back")


func test_summon_volley_waits_for_two_summon_relics_and_fires_them() -> void:
	var r := RunState.create(3)
	r.add_relic(&"thread_pool")
	ok(not Relics.offerable(r, &"hive_mind"), "one summon relic is not enough")
	r.add_relic(&"graceful_exit")
	ok(Relics.offerable(r, &"hive_mind"), "two: offered")
	_range_setup()
	Game.inf_mana = true
	world.run.add_relic(&"hive_mind")
	_fire([&"turret"])
	var s: SpellRunner.Summon = world.spells.summons[0]
	world.step(DT)
	s.cd = 5.0
	_fire([&"mote"])
	eq(s.cd, 0.0, "a cast makes the turret fire at once")
	s.cd = 5.0
	_fire([&"mote"])
	eq(s.cd, 5.0, "but only once a second")


func test_shock_charge_charges_on_shock_hits() -> void:
	var e := _alone(Vector2(208, 120))
	world.hurt_enemy(e, 5.0, e.position, 0.0, 0.0, false, 4)
	eq(e.static_t, 0.0, "no relic: a shock hit leaves no charge")
	world.run.add_relic(&"live_wire")
	world.hurt_enemy(e, 5.0, e.position, 0.0, 0.0, false, 0)
	eq(e.static_t, 0.0, "a plain hit charges nothing")
	world.hurt_enemy(e, 5.0, e.position, 0.0, 0.0, false, 4)
	ok(e.static_t > 0.0, "a hit that strips wards charges it")


func test_charged_strike_hits_charged_enemies_harder() -> void:
	var e := _alone(Vector2(208, 120))
	e.static_t = 4.0
	eq(world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0), 10.0, "no relic: 10")
	world.run.add_relic(&"overvoltage")
	eq(world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0), 10.0, "not charged any more: 10")
	e.static_t = 4.0
	ok(is_equal_approx(world.hurt_enemy(e, 10.0, e.position, 0.0, 0.0), 14.0), "charged: 14")


func test_frost_spread_chills_neighbours_on_death() -> void:
	var e := _alone(Vector2(208, 120))
	var near := _dummy(Vector2(236, 120))
	var far := _dummy(Vector2(120, 120))
	world.hash.rebuild(world.enemies)
	world.run.add_relic(&"cold_spill")
	e.chill_t = 1.0
	world.kill_enemy(e)
	ok(near.chill_t > 0.0, "a close enemy is chilled")
	eq(far.chill_t, 0.0, "a far one is not")
	var warm := _dummy(Vector2(208, 150))
	var n2 := _dummy(Vector2(230, 150))
	world.hash.rebuild(world.enemies)
	world.kill_enemy(warm)
	eq(n2.chill_t, 0.0, "an enemy that was not chilled spreads nothing")


func test_quick_freeze_freezes_at_two_chills() -> void:
	var e := _alone(Vector2(208, 120))
	world.apply_status(e, 0, 1, 5.0)
	world.apply_status(e, 0, 1, 5.0)
	eq(e.frozen_t, 0.0, "two chills do not freeze")
	var q := _dummy(Vector2(240, 120))
	world.run.add_relic(&"flash_freeze")
	world.apply_status(q, 0, 1, 5.0)
	eq(q.frozen_t, 0.0, "one chill does not freeze")
	world.apply_status(q, 0, 1, 5.0)
	ok(q.frozen_t > 0.0, "Quick Freeze: two do")


func test_clean_streak_builds_and_an_unsafe_cast_resets_it() -> void:
	ok(Relics.unsafe(&"needle"), "Needle is tagged Glitch: unsafe")
	ok(not Relics.unsafe(&"mote"), "a Mote is safe")
	_range_setup()
	Game.inf_mana = true
	world.run.add_relic(&"clean_build")
	_fire([&"mote"])
	var w := _fire([&"empower", &"mote"])
	eq(world.run.clean, 2, "two clean casts")
	ok(is_equal_approx(world.spells.cast_bonus(w, false, false), 1.06), "+6%")
	w = _fire([&"mirror", &"mote"])
	eq(world.run.clean, 0, "a Glitch spell in the cast resets it")
	eq(world.spells.cast_bonus(w, false, false), 1.0, "and that cast gets nothing")
	world.run.clean = 99
	ok(is_equal_approx(Relics.shape_mul(world.run, w, 0), 1.6), "capped at +60%")
	if Catalog.wands().has(&"unsafe_staff"):
		_fire([&"mote"])
		_fire([&"mote"], &"unsafe_staff")
		eq(world.run.clean, 0, "a cast paid in HP (the Unsafe Staff) resets it too")


func test_risky_code_counts_unsafe_spells() -> void:
	_range_setup()
	world.run.add_relic(&"risky_code")
	var w := _fire([&"needle", &"mine", &"mote"])
	ok(is_equal_approx(world.spells.cast_bonus(w, false, false), 1.24), "two unsafe spells: +24%")


func test_merge_conflict_shuts_out_the_rival() -> void:
	eq(Relics.rival_of(&"clean_build"), &"risky_code", "a pair")
	eq(Relics.rival_of(&"risky_code"), &"clean_build", "both ways")
	eq(Relics.rival_of(&"mote"), &"", "most have none")
	var r := RunState.create(3)
	ok(Relics.offerable(r, &"clean_build") and Relics.offerable(r, &"risky_code"), "both offered before either is taken")
	r.add_relic(&"clean_build")
	ok(not Relics.offerable(r, &"risky_code"), "Clean Streak taken: Risky Code is gone")
	for k in 80:
		ok(not Rewards.roll_relics(r, 3).has(&"risky_code"), "and never rolled")
	var r2 := RunState.create(3)
	r2.add_relic(&"risky_code")
	ok(not Relics.offerable(r2, &"clean_build"), "and the other way round")


func test_relic_copy_turns_into_a_stacking_relic() -> void:
	var r := RunState.create(3)
	r.add_relic(&"git_clone")
	eq(Relics.on_room_clear(r), &"", "one room: still waiting")
	eq(Relics.on_room_clear(r), &"", "two rooms, but nothing it can copy")
	ok(r.has_relic(&"git_clone"), "so it stays")
	r.add_relic(&"heap_overflow")
	var hp := r.max_hp
	eq(Relics.on_room_clear(r), &"heap_overflow", "the next room it copies Glass Cannon")
	ok(not r.has_relic(&"git_clone"), "and is gone")
	eq(r.relics.count(&"heap_overflow"), 2, "two copies")
	ok(is_equal_approx(Relics.stat(r, "dmg"), 1.3 * 1.3), "the damage stacks")
	eq(r.max_hp, hp - 20.0, "and so does the cost")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	eq(back.relics.count(&"heap_overflow"), 2, "a save keeps both")
	# in the world: room clears count
	world.run.add_relic(&"git_clone")
	world.run.add_relic(&"interest")
	for k in 2:
		world.build_room("hall", &"fight")
		world.call("_clear_room")
	eq(world.run.relics.count(&"interest"), 2, "two cleared rooms: Compound Interest twice")
	ok(is_equal_approx(Relics.stat(world.run, "gold"), 1.25 * 1.25), "its gold bonus stacks")


func test_fixed_vitals_locks_max_hp() -> void:
	var r := RunState.create(3)
	r.max_hp += 10.0
	eq(r.max_hp, RunState.BASE_HP + 30.0, "before it, max HP changes")
	r.add_relic(&"version_pin")
	var pinned := r.max_hp
	ok(is_equal_approx(Relics.stat(r, "dmg"), 1.4), "+40% damage")
	r.add_relic(&"hot_patch")
	eq(r.max_hp, pinned, "Vital Patch adds nothing")
	r.add_relic(&"heap_overflow")
	eq(r.max_hp, pinned, "Glass Cannon takes nothing")
	Rewards.grant(r, {"t": &"gold", "id": &"gold", "v": 1, "hp_cost": 0.15})
	eq(r.max_hp, pinned, "an Altar price takes nothing")
	r.max_hp = 999.0
	eq(r.max_hp, pinned, "nothing else either")
	r.hp = 1.0
	r.hp = minf(r.max_hp, r.hp + 500.0)
	eq(r.hp, pinned, "healing still works up to it")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	eq(back.max_hp, pinned, "a save keeps it")


func test_wand_variety_rewards_the_less_used_wand() -> void:
	_range_setup()
	Game.inf_mana = true
	world.run.add_relic(&"code_coverage")
	var a := WandState.make(Catalog.wand(&"apprentice"))
	a.set_slots([&"mote"])
	var b := WandState.make(Catalog.wand(&"apprentice"))
	b.set_slots([&"mote"])
	world.run.wands.clear()
	world.run.wands.append(a)
	world.run.wands.append(b)
	world.hash.rebuild(world.enemies)
	var cast := func(w: WandState) -> void:
		w.cd = 0.0
		world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	for k in 3:
		cast.call(a)
	eq(world.run.cover, 0, "one wand only: nothing")
	cast.call(b)
	cast.call(b)
	eq(world.run.cover, 2, "the other wand: +1 a cast")
	ok(is_equal_approx(world.spells.cast_bonus(b, false, false), 1.08), "+8%")
	cast.call(b)
	cast.call(b)
	eq(world.run.cover, 3, "not once it is the most used")
	world.spells.clear_room()
	eq(world.run.cover, 0, "a new room starts over")
