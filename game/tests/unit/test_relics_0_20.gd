extends "res://tests/unit/world_fixture.gd"
## 0.20 relics (research/arsenal-0.20/7-relics.md): the Kernel pack (Locked Fury, Puddle
## Skater, Finisher, Take-Back, Warm-Up), the Refactor pack (Tail Boost, Mixed Program, Short
## Wand, Buyback, Technical Debt) and the core additions (Refund Misses, Swap Dodge, Bit
## Savings, Contagion, and the Double Tick and Cold Current duos).


func setup(tree: SceneTree) -> void:
	super.setup(tree)
	Story._mem = {}


func teardown() -> void:
	Story._mem = {}
	Game.god_mode = true
	super.teardown()


func _alone(pos: Vector2) -> Enemy:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)
	var e := _dummy(pos)
	world.hash.rebuild(world.enemies)
	return e


func test_kernel_only_relics_wait_for_world_three() -> void:
	var r := RunState.create(3)
	for id in [&"graceful_degrade", &"swap_space"]:
		r.world = 0
		ok(not Relics.offerable(r, id), "%s is not offered in World 1" % id)
		r.world = 1
		ok(not Relics.offerable(r, id), "%s is not offered in World 2" % id)
		r.world = 2
		ok(Relics.offerable(r, id), "%s is offered in World 3" % id)
	r.world = 0
	for k in 60:
		for id in Rewards.roll_relics(r, 3):
			ok(int(Relics.DEFS[id].get("from", 0)) == 0, "a World 1 offer holds no Kernel relic (%s)" % id)
	ok(Relics.offerable(r, &"thread_join"), "Finisher works everywhere, so it has no world gate")


func test_duos_need_both_parents() -> void:
	for duo in [&"cron_job", &"superconductor"]:
		var parents: Array = Relics.DEFS[duo]["duo"]
		var r := RunState.create(3)
		ok(not Relics.offerable(r, duo), "%s: not with no parent" % duo)
		r.add_relic(parents[0])
		ok(not Relics.offerable(r, duo), "%s: not with one" % duo)
		r.relics.clear()
		r.add_relic(parents[1])
		ok(not Relics.offerable(r, duo), "%s: not with only the other" % duo)
		r.add_relic(parents[0])
		ok(Relics.offerable(r, duo), "%s: offered with both" % duo)
		eq(Relics.completes_duo(RunState.create(3), parents[0]), &"", "no Enables chip with neither owned")


func test_locked_fury_while_a_slot_is_held() -> void:
	_range_setup()
	world.run.add_relic(&"graceful_degrade")
	var w := _fire([&"empower", &"mote"])
	eq(world.spells.cast_bonus(w, false, false), 1.0, "nothing held: no bonus")
	w.suspended = 0
	ok(is_equal_approx(world.spells.cast_bonus(w, false, false), 1.4), "an Interrupt holds a slot: +40%")


func test_puddle_skater_turns_leaks_into_speed_and_mana() -> void:
	_alone(Vector2(208, 120))
	var at := world.player.position
	world.puddles.append({"pos": at, "r": 12.0, "owner": 999, "t": 0.0})
	eq(world.puddle_slow(at), World.PUDDLE_SLOW, "a puddle slows you")
	world.run.add_relic(&"swap_space")
	eq(world.puddle_slow(at), World.SKATE_SPEED, "Puddle Skater: it speeds you up")
	var w := world.run.wand()
	w.mana = 0.0
	world.call("_grow_puddles", 1.0)
	ok(is_equal_approx(w.mana, World.SKATE_MANA), "and refills the wand in hand (%.1f)" % w.mana)
	eq(world.puddle_slow(at + Vector2(80, 0)), 1.0, "outside a puddle, no change")


func test_finisher_finishes_weak_neighbours_and_chains() -> void:
	var e := _alone(Vector2(208, 120))
	var near := _dummy(Vector2(236, 120))
	var chain := _dummy(Vector2(266, 120))
	var healthy := _dummy(Vector2(180, 120))
	var far := _dummy(Vector2(120, 120))
	for o in [near, chain, far]:
		o.hp = o.max_hp * 0.1
	healthy.hp = healthy.max_hp * 0.5
	world.hash.rebuild(world.enemies)
	world.run.add_relic(&"thread_join")
	world.kill_enemy(e)
	ok(near.dead, "a weak enemy close by is finished")
	ok(chain.dead, "and its death finishes the next one (a chain)")
	ok(not healthy.dead, "a healthy one is left alone")
	ok(not far.dead, "a far one is left alone")


func test_finisher_joins_data_race_threads() -> void:
	world.run.world = 2
	world.run.step = Chapter.PLAN.find(&"mini")
	world.build_room("arena_open", &"mini")
	world.call("_spawn_boss")
	var b := world.boss as BossRace
	ok(b != null, "Data Race appeared")
	b.invuln = 0.0
	b.sm = &"idle"
	b.st_t = 99.0
	world.hash.rebuild(world.enemies)
	world.run.add_relic(&"thread_join")
	b.thread_b.hp = b.thread_b.max_hp * 0.1
	world.hurt_enemy(b, 9999.0, b.position, 0.0, 0.0)
	ok(b.dead, "A's fall finished B (under 15%), so both are down")


func test_take_back_undoes_a_hit_you_dodge_after() -> void:
	_alone(Vector2(208, 60))
	Game.god_mode = false
	world.run.add_relic(&"undo_stack")
	var p := world.player
	var hp := p.hp
	p.hurt(10.0, p.position + Vector2(10, 0))
	eq(p.hp, hp - 10.0, "the hit lands")
	ok(p.undo_t > 0.0, "and is held")
	_steps(3.2)
	eq(p.hp, hp, "three clean seconds: undone")
	ok(not world.hit_in_room, "an undone hit leaves Untouched Streak alone")
	p.inv = 0.0
	p.hurt(10.0, p.position + Vector2(10, 0))
	_steps(3.2)
	eq(p.hp, hp - 10.0, "once a room")


func test_take_back_is_lost_to_a_second_hit() -> void:
	_alone(Vector2(208, 60))
	Game.god_mode = false
	world.run.add_relic(&"undo_stack")
	var p := world.player
	var hp := p.hp
	p.hurt(10.0, p.position + Vector2(10, 0))
	p.inv = 0.0
	p.hurt(5.0, p.position + Vector2(10, 0))
	_steps(3.2)
	eq(p.hp, hp - 15.0, "a second hit in the window: nothing is undone")


func test_warm_up_climbs_and_a_hit_clears_it() -> void:
	_range_setup()
	world.run.add_relic(&"warm_cache")
	Game.inf_mana = true
	var w := _fire([&"mote"])
	eq(world.warm, 1, "each cast counts")
	world.warm = 10
	ok(is_equal_approx(world.spells.cast_bonus(w, false, false), 1.2), "ten casts: +20%")
	world.warm = 50
	ok(is_equal_approx(world.spells.cast_bonus(w, false, false), 1.4), "capped at +40%")
	Game.inf_mana = false
	Game.god_mode = false
	world.player.hurt(5.0, world.player.position + Vector2(10, 0))
	eq(world.warm, 0, "a hit clears it")


func test_tail_boost_applies_the_last_slot_to_every_spell() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([&"mote", null, &"empower"])
	var before := WandProgram.compile(r.wand(), 0, Mods.new()).groups[0].mods.dmg
	eq(before, 1.0, "a boost with nothing to its right does nothing")
	r.add_relic(&"hoisting")
	var after := WandProgram.compile(r.wand(), 0, Mods.new()).groups[0].mods.dmg
	ok(after > 1.2, "Tail Boost: the Mote is empowered (x%.2f)" % after)
	r.add_wand(&"oak")
	ok(r.wands[1].hoist, "wands found later follow it too")


func test_mixed_program_counts_kinds() -> void:
	_range_setup()
	world.run.add_relic(&"polyglot")
	var w := _fire([&"empower", &"mote", &"mote"])
	eq(Relics.kinds(w), 2, "a boost and a shooting spell")
	ok(is_equal_approx(world.spells.cast_bonus(w, false, false), 1.12), "+6% each")


func test_short_wand_recharges_faster() -> void:
	_range_setup()
	var w := _fire([&"mote"], &"twig")
	var slow := w.rech_max
	world.run.add_relic(&"short_circuit")
	w = _fire([&"mote"], &"twig")
	ok(is_equal_approx(w.rech_max, slow * 0.6), "a 3-slot wand: 40%% faster (%.3f vs %.3f)" % [w.rech_max, slow])
	var long_w := WandState.make(Catalog.wand(&"oak"))
	eq(Relics.recharge_mul(world.run, long_w), 1.0, "a long wand gets nothing")


func test_buyback_pays_and_allows_two_bans() -> void:
	var r := RunState.create(3)
	Rewards.shop_stock(r)
	ok(Rewards.deprecate(r, &"mote"), "one ban")
	ok(not Rewards.deprecate(r, &"spark"), "one a visit without Buyback")
	r = RunState.create(3)
	r.add_relic(&"end_of_life")
	Rewards.shop_stock(r)
	var g := r.gold
	ok(Rewards.deprecate(r, &"mote"), "a ban")
	ok(Rewards.deprecate(r, &"spark"), "and a second")
	ok(not Rewards.deprecate(r, &"fan"), "but not a third")
	eq(r.gold, g + 2 * Rewards.BUYBACK_GOLD, "15 gold each")
	ok(r.banned.has(&"spark"), "the spell is banned")
	Rewards.shop_stock(r)
	ok(Rewards.deprecate(r, &"fan"), "a new shop, new bans")


func test_technical_debt_trades_recharge_for_slots() -> void:
	var r := RunState.create(3)
	ok(not Relics.offerable(r, &"technical_debt"), "not a normal offer")
	ok(Relics.offerable(r, &"technical_debt", true), "a Glitch Door one")
	var n := r.wand().slots.size()
	r.add_relic(&"technical_debt")
	eq(r.wand().slots.size(), n + 2, "two more slots")
	r.add_wand(&"birch")
	eq(r.wands[1].slots.size(), Catalog.wand(&"birch").slots + 2, "on wands found later too")
	eq(Relics.recharge_mul(r, r.wands[1]), 1.5, "recharges take 50% longer")


func test_refund_misses_gives_a_missed_shots_mana_back() -> void:
	# the same cast, mana set low while it flies: only a miss with the relic gets its cost back
	var after := func(relic: bool, hit: bool) -> float:
		if hit:
			_range_setup()
		else:
			world.build_room("hall", &"empty")
			world.player.position = Vector2(205, 216)
		world.run.relics.clear()
		if relic:
			world.run.add_relic(&"lazy_eval")
		var w := _fire([&"mote"])
		w.mana = 10.0
		for k in 150:
			world.step(DT)
		return w.mana
	var plain: float = after.call(false, false)
	var back: float = after.call(true, false)
	var cost := Catalog.spell(&"mote").mana_at(1)
	ok(cost > 0.0, "a Mote costs mana")
	ok(absf(back - plain - cost) < 0.01, "a miss refunds its %.1f mana (got %.1f)" % [cost, back - plain])
	var hit: float = after.call(true, true)
	ok(absf(hit - plain) < 0.01, "a hit refunds nothing (%.1f vs %.1f)" % [hit, plain])


func test_swap_dodge_on_wand_switch() -> void:
	_alone(Vector2(208, 60))
	world.run.add_relic(&"context_switch")
	world.run.add_wand(&"birch")
	world.run.wands[1].set_slots([&"mote"])
	var p := world.player
	p.inv = 0.0
	p.controls.select_wand = 1
	world.step(DT)
	eq(world.run.cur, 1, "switched")
	ok(p.inv >= Player.SWAP_INV - 0.05, "untouchable for a moment")
	p.inv = 0.0
	p.controls.select_wand = 0
	world.step(DT)
	eq(world.run.cur, 0, "switched back")
	eq(p.inv, 0.0, "but only every 4 s")


func test_bit_savings_pays_for_held_gold() -> void:
	var r := RunState.create(3)
	r.gold = 200
	var base := Meta.bits_for(r, 99)
	r.add_relic(&"cold_storage")
	eq(Meta.bits_for(r, 99), base + 5, "200 gold: 5 Bits")
	r.gold = 5000
	var rich := Meta.bits_for(r, 99)
	r.relics.clear()
	eq(rich - Meta.bits_for(r, 99), 10, "up to 10")


func test_contagion_passes_statuses_on() -> void:
	var e := _alone(Vector2(208, 120))
	var o := _dummy(Vector2(236, 120))
	world.hash.rebuild(world.enemies)
	world.run.add_relic(&"shared_memory")
	e.burn_t = 2.0
	e.burn_dps = 9.0
	e.static_t = 3.0
	e.rot_n = 2
	world.kill_enemy(e)
	ok(o.burn_t > 0.0 and o.burn_dps >= 9.0, "the fire moved on")
	ok(o.static_t > 0.0, "the charge too")
	eq(o.rot_n, 2, "Bitrot keeps its stacks")
	var a := _dummy(Vector2(208, 100))
	var b := _dummy(Vector2(236, 100))
	world.hash.rebuild(world.enemies)
	a.burn_t = 2.0
	world.kill_enemy(a)
	eq(b.burn_t, 0.0, "one status is not enough")


func test_double_tick_counts_each_cast_twice() -> void:
	_range_setup()
	for id in [&"stack_trace", &"loop_counter", &"cron_job"]:
		world.run.add_relic(id)
	Game.inf_mana = true
	var seq := 0
	for i in 4:
		var w := _fire([&"mote"])
		seq += world.spells.cast_seq
		w.cd = 0.0
	Game.inf_mana = false
	eq(seq, 5, "Back Shot fired on the 4th cast, not the 7th")
	var w2 := _fire([&"mote"])
	w2.cd = 0.0
	world.spells.casts_fired = 8
	var m := w2.mana
	world.spells.wand_fire(w2, world.player.tip(), -PI / 2.0)
	eq(w2.mana, m, "Tally Charm's free cast comes every 5th cast")


func test_cold_current_arcs_further_and_chills() -> void:
	var a := _alone(Vector2(208, 120))
	var b := _dummy(Vector2(236, 120))
	var c := _dummy(Vector2(180, 120))
	var d := _dummy(Vector2(208, 150))
	world.hash.rebuild(world.enemies)
	for id in [&"surge_protector", &"cold_boot", &"superconductor"]:
		world.run.add_relic(id)
	world.charge(a)
	world.hurt_enemy(a, 10.0, a.position, 0.0, 0.0)
	for o in [b, c, d]:
		ok(o.hp < o.max_hp, "three arcs: each neighbour was hit")
		ok(o.chill_t > 0.0, "and chilled")
