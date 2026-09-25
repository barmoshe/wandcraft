extends "res://tests/unit/world_fixture.gd"
## Simulation tests: the world stepped headless at 60 Hz, no rendering involved.


func test_every_spell_with_every_modifier_deals_damage() -> void:
	var shooters: Array = []
	var mods: Array = [null]
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		if d.kind == SpellDef.Kind.PROJ:
			shooters.append(id)
		elif d.kind == SpellDef.Kind.BOOST:
			mods.append(id)
	var failures := []
	for p in shooters:
		for m in mods:
			_range_setup()
			var ids: Array = [p] if m == null else [m, p]
			# the Reverse Rune fires behind the wand: aim away from the dummies
			_fire(ids, &"apprentice", PI / 2.0 if m == &"reverse" else -PI / 2.0)
			_steps(1.6)
			# a Firewall planted behind the wand stands out of the dummies' reach: not a miss
			if world.damage_done <= 0.0 and not (m == &"reverse" and p == &"firewall"):
				failures.append("%s" % [ids])
	eq(failures, [], "every shooting spell under every boost hits the dummies")


func test_every_trigger_fires_its_payload() -> void:
	var failures := []
	for p in [&"mote", &"lance", &"fan", &"burst", &"moths", &"seed"]:
		for t in [&"then", &"callback", &"loop", &"fork"]:
			_range_setup()
			Game.inf_mana = true
			_fire([p, t, &"mote"])
			_steps(1.6)
			Game.inf_mana = false
			if world.spells.cast_seq < 2:
				failures.append("%s %s mote" % [p, t])
	eq(failures, [], "a trigger always releases its payload")


func test_starwheel_sprays_its_payload_16_times() -> void:
	_range_setup()
	Game.inf_mana = true
	_fire([&"wheel", &"mote"])
	_steps(2.0)
	Game.inf_mana = false
	eq(world.spells.cast_seq, 1 + 16, "one cast plus 16 sprays")


func test_seed_delivers_burst_where_it_lands() -> void:
	_range_setup()
	_fire([&"seed", &"burst"])
	_steps(1.2)
	ok(world.spells.cast_seq >= 2, "the burst was released")
	ok(world.damage_done > 20.0, "and it hurt (got %.0f)" % world.damage_done)


func test_bot_clears_rooms_and_walks_through_doors() -> void:
	Game.auto_fire = true
	world.bot = true
	# the bot takes the first reward and leaves shops, as main.gd's bot answer does
	world.ui_request.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"reward":
			if not data["offer"].is_empty():
				Rewards.grant(world.run, data["offer"][0])
			world.reward_taken()
		elif kind == &"shop" or kind == &"forge":
			world.ui_done())
	var t := 0.0
	while world.run.step < 3 and t < 360.0:
		world.step(DT)
		t += DT
	world.bot = false
	ok(world.run.step >= 3, "bot walked three doors (step %d in %.0fs, %s)" % [world.run.step, t, world.room_kind])
	ok(int(world.run.stats["kills"]) > 5, "and killed things (%d)" % world.run.stats["kills"])
	eq(world.run.path.size(), world.run.step, "every door taken is on the map")


func test_player_can_die_and_the_run_ends() -> void:
	Game.god_mode = false
	var got := []
	world.ui_request.connect(func(kind: StringName, _d: Dictionary) -> void: got.append(kind))
	world.player.hurt(9999.0, world.player.position)
	ok(world.player.dead, "player died")
	_steps(2.0)
	eq(got, [&"defeat"], "the defeat screen was requested")
	ok(world.paused, "the world waits for the screen")


func test_walls_stop_bodies() -> void:
	world.build_room("hall", &"empty")
	var p := world.move_body(Vector2(24, 100), 5.0, Vector2(-40, 0))   # far more than a tick ever moves
	ok(p.x >= 16.0 + 5.0 - 0.1, "left wall blocks (x=%.2f)" % p.x)
	ok(world.last_hit_x, "hit flag set")


func test_bullet_pool_recycles() -> void:
	_range_setup()
	Game.inf_mana = true
	for k in 30:
		_fire([&"twin", &"fan"], &"harp")
		_steps(0.1)
	_steps(2.0)
	Game.inf_mana = false
	eq(world.bullets.live_count(), 0, "all bullets returned to the pool")


## 45 enemies and a bullet storm: the sim tick stays well inside a 60 Hz frame.
## Pinned so new DEFS entries cannot silently change the storm (D4 swapped buglings for
## slimelets through `DEFS.keys()[i % 4]`).
const STRESS_ROSTER: Array[StringName] = [&"slime", &"weaver", &"ram", &"bugling"]


func test_stress_tick_budget() -> void:
	world.build_room("pillars", &"empty")
	Game.inf_mana = true
	for i in 45:
		var e := world.spawn_enemy(STRESS_ROSTER[i % 4], world.sockets[i % world.sockets.size()] + Vector2(i % 5, i % 3) * 6.0)
		e.spawn_t = 0.0
		e.max_hp = 5000.0
		e.hp = 5000.0
	var w := WandState.make(Catalog.wand(&"harp"))
	w.set_slots([&"twin", &"chorus", &"fan", &"moths", &"fan", &"mote", &"fan"])
	world.run.wands[0] = w
	var worst := 0
	var total := 0
	var peak := 0
	for i in 300:
		w.cd = 0.0
		world.spells.wand_fire(w, world.player.tip(), float(i) * 0.3)
		var t0 := Time.get_ticks_usec()
		world.step(DT)
		var us := Time.get_ticks_usec() - t0
		total += us
		worst = maxi(worst, us)
		peak = maxi(peak, world.bullets.live_count())
	Game.inf_mana = false
	var avg := total / 300.0
	print("    stress: avg %.2f ms, worst %.2f ms, peak bullets %d" % [avg / 1000.0, worst / 1000.0, peak])
	ok(peak > 500, "the storm really happened (%d bullets)" % peak)
	# budget: 60% of a 60 Hz frame on the (slow) Linux dev container; phones run GDScript faster
	ok(avg < 10000.0, "average tick under 10 ms (%.2f ms)" % (avg / 1000.0))
