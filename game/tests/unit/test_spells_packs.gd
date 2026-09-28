extends "res://tests/unit/world_fixture.gd"
## The 0.19 spell packs (Catalog.PACK_ITEMS): Networking, Concurrency, Version Control and
## Hardware. One test per item, in the world where it acts there, else in the compiler.


func _give(id: StringName) -> void:
	world.run.relics.append(id)


## An empty room with dummies at the given spots.
func _room(spots: Array) -> Array[Enemy]:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)   # 0.20: the hand (Player.GRIP) moved 3 px out; the tip stays where it was
	var out: Array[Enemy] = []
	for p in spots:
		out.append(_dummy(p))
	world.hash.rebuild(world.enemies)
	return out


func _hurt(list: Array) -> Array:
	return list.filter(func(e: Enemy) -> bool: return e.hp < e.max_hp)


func _live(id: StringName) -> Array[Bullet]:
	var out: Array[Bullet] = []
	for b in world.bullets.active:
		if b.alive and b.cast and b.cast.spell.id == id:
			out.append(b)
	return out


## The aim that points the wand tip at e (the tip moves with the aim, so aim first).
func _aim_at(e: Enemy) -> float:
	world.player.aim = (e.position - world.player.origin()).angle()
	return (e.position - world.player.tip()).angle()


# ---- Networking ----

func test_traceroute_hops_and_marks_the_last_one() -> void:
	var d := _room([Vector2(208, 170), Vector2(208, 130), Vector2(208, 90), Vector2(240, 90)])
	_fire([&"traceroute"])
	_steps(1.2)
	eq(_hurt(d).size(), 4, "one bolt, three hops: four enemies hit")
	eq(world.marked, d[3], "the last hop holds the mark")
	ok(d[3].mark_t > 0.0, "and it is still on")
	eq(world.spells.target_near(world.player.position, 5.0), d[3], "so triggers aim there")


func test_multicast_reaches_the_nearest_three_and_costs_twice() -> void:
	var d := _room([Vector2(208, 150), Vector2(140, 150), Vector2(290, 110), Vector2(208, 40)])
	var w := WandState.make(Catalog.wand(&"apprentice"))
	w.set_slots([{"id": &"multicast", "lv": 2}, &"mote"])
	var plan := WandProgram.compile(w, 0, Mods.new())
	eq(plan.mana, 13.0, "Multicast 7 + a Mote at 2x (3 targets): 13")
	eq(WandProgram.compile(wand(["ping", "mote"]), 0, Mods.new()).mana, 6.0, "a plain Ping still pays 1x")
	var seq := world.spells.cast_seq
	_fire([{"id": &"multicast", "lv": 2}, &"mote"])
	_steps(0.5)
	eq(_hurt(d).size(), 3, "three enemies reached at once")
	ok(d[3].hp >= d[3].max_hp, "the farthest one is left alone")
	ok(world.damage_done > 3.0 * Catalog.spell(&"multicast").damage_at(2), "and each got a Mote too (%.0f)" % world.damage_done)
	ok(world.spells.cast_seq > seq, "the payloads went out")


func test_multicast_with_one_enemy_sends_one_copy() -> void:
	var d := _room([Vector2(208, 150)])
	_fire([&"multicast", &"burst"])
	world.step(DT)
	var one := world.damage_done
	ok(one > 0.0 and _hurt(d).size() == 1, "the lone enemy is reached (%.0f)" % one)
	ok(one < 2.0 * (Catalog.spell(&"burst").damage_at(1) + Catalog.spell(&"multicast").damage_at(1)) * 1.3, "once, not once per copy")


func test_broadcast_hits_the_room_and_carries_coats() -> void:
	var d := _room([Vector2(208, 150), Vector2(110, 216), Vector2(310, 216), Vector2(160, 250), Vector2(260, 60)])
	_fire([&"static_coat", &"broadcast"])
	world.step(DT)
	eq(_hurt(d).size(), d.size(), "every enemy around you is hit, behind you too")
	eq(d.filter(func(e: Enemy) -> bool: return e.static_t > 0.0).size(), d.size(), "and the coat on its left charged them all")


func test_target_lock_amplifies_and_stretches_marks() -> void:
	var d := _room([Vector2(208, 150)])
	var e := d[0]
	var plain := world.hurt_enemy(e, 20.0, e.position, 0.0, 0.0)
	world.mark(e, 4.0)
	eq(e.mark_t, 4.0, "a plain mark lasts its time")
	_give(&"keep_alive")
	world.mark(e, 4.0)
	eq(e.mark_t, 8.0, "Target Lock: twice as long")
	var marked := world.hurt_enemy(e, 20.0, e.position, 0.0, 0.0)
	ok(is_equal_approx(marked, plain * 1.3), "and the mark takes 30%% more (%.1f vs %.1f)" % [marked, plain])


# ---- Concurrency ----

func test_worker_thread_casts_its_payload() -> void:
	_range_setup()
	Game.inf_mana = true
	_fire([&"worker", &"mote"])
	world.step(DT)
	eq(world.spells.summons.size(), 1, "a worker is planted")
	var s: SpellRunner.Summon = world.spells.summons[0]
	eq(s.kind, &"turret", "in the Turret's slot")
	ok(s.payload != null and s.payload.spell.id == &"mote", "carrying the Mote")
	var seq := world.spells.cast_seq
	_steps(3.0)
	Game.inf_mana = false
	ok(world.spells.cast_seq >= seq + 2, "it cast its Mote a few times (%d)" % (world.spells.cast_seq - seq))
	ok(world.damage_done > 0.0, "and hit")


func test_worker_shares_the_turret_cap() -> void:
	_range_setup()
	Game.inf_mana = true
	_fire([&"turret"])
	_steps(0.1)
	_fire([&"worker", &"mote"])
	_steps(0.1)
	_fire([&"worker", &"mote"])
	_steps(0.1)
	Game.inf_mana = false
	eq(world.spells.summons.size(), 2, "two turret-kind summons at most")


func test_spinlock_orbits_and_blocks_a_shot() -> void:
	var d := _room([Vector2(208, 160)])
	d[0].heavy = true   # stays in reach (a light one is knocked out of the ring)
	_fire([&"spinlock"])
	_steps(0.5)
	var blades := _live(&"spinlock")
	eq(blades.size(), 3, "three blades")
	var ctr := world.player.position + Player.HAND
	for b in blades:
		var r := b.pos.distance_to(ctr)
		ok(r > 20.0 and r < 60.0, "circling you (%.0f px out)" % r)
	_steps(1.0)
	ok(_hurt(d).size() == 1, "cutting the enemy in reach")
	var hp := d[0].hp
	_steps(0.5)
	ok(d[0].hp < hp, "again and again (%.0f -> %.0f, %.0f px out)" % [hp, d[0].hp, d[0].position.distance_to(world.player.position + Player.HAND)])
	var b0: Bullet = _live(&"spinlock")[0]
	world.enemy_shoot(b0.pos, 0.0, 1.0, 5.0)
	world.step(DT)
	eq(world.ebullets.live_count(), 0, "a shot that meets a blade is stopped")
	_steps(2.0)
	eq(_live(&"spinlock").size(), 0, "the blades last their time (no Orbit Rune stretch)")


func test_scheduler_speeds_the_wand_while_a_summon_is_out() -> void:
	_range_setup()
	var w := _fire([&"scheduler", &"mote"])
	var plain := w.cd
	var s := SpellRunner.Summon.new()
	s.kind = &"duck"
	s.life = 5.0
	s.pos = Vector2(100, 100)
	world.spells.summons.append(s)
	w.cd = 0.0
	world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	ok(is_equal_approx(w.cd, plain * 0.8), "20%% faster at level 1 (%.3f vs %.3f)" % [w.cd, plain])
	world.spells.summons.clear()
	w.cd = 0.0
	world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	ok(is_equal_approx(w.cd, plain), "and back to normal when it is gone")


func test_thread_pool_raises_every_cap() -> void:
	_range_setup()
	_give(&"thread_pool")
	Game.inf_mana = true
	for k in 4:
		_fire([&"turret"])
		_steps(0.1)
	for k in 3:
		_fire([&"daemon"])
		_steps(0.1)
	Game.inf_mana = false
	var turrets := world.spells.summons.filter(func(s: SpellRunner.Summon) -> bool: return s.kind == &"turret")
	var daemons := world.spells.summons.filter(func(s: SpellRunner.Summon) -> bool: return s.kind == &"daemon")
	eq(turrets.size(), 3, "three turrets instead of two")
	eq(daemons.size(), 2, "two daemons instead of one")


# ---- Version Control ----

func test_cherry_pick_copies_the_last_shooting_spell() -> void:
	var w := wand(["empower", "cherry_pick", "mote", "needle"])
	var c := WandProgram.compile(w, 0, Mods.new())
	eq(c.groups[0].spell.id, &"needle", "a copy of the last shooting spell")
	ok(c.groups[0].free_copy, "for free")
	ok(is_equal_approx(c.groups[0].mods.dmg, 1.25), "with the boosts active right now")
	eq(c.mana, 5.0 + 3.0, "Empower and the rune are all it costs")
	var h := WandProgram.compile(wand(["head", "mote", "needle"]), 0, Mods.new())
	eq(h.groups[0].spell.id, &"mote", "HEAD still copies the first")
	_range_setup()
	_fire([&"cherry_pick", &"mote", &"needle"])
	_steps(0.5)
	ok(world.damage_done > 0.0, "the copy flies and hits")


func test_diff_hits_harder_the_more_hurt_its_target() -> void:
	var d := _room([Vector2(214, 150)])
	var e := d[0]
	_fire([&"diff"], &"apprentice", _aim_at(e))
	var full := world.damage_done
	ok(full > 0.0, "the beam lands (%.1f)" % full)
	e.hp = e.max_hp * 0.1
	world.step(DT)
	_fire([&"diff"], &"apprentice", _aim_at(e))
	var low := world.damage_done
	ok(low > full * 2.2 and low < full * 2.5, "90%% hurt: nearly 2.5x at level 1 (%.1f vs %.1f)" % [low, full])


func test_blame_steers_toward_the_toughest_enemy() -> void:
	var d := _room([Vector2(160, 150), Vector2(300, 90)])
	d[0].max_hp = 50.0
	d[0].hp = 50.0
	d[1].max_hp = 5000.0
	d[1].hp = 5000.0
	eq(world.toughest_enemy(), d[1], "the toughest is the one with the most HP")
	_fire([&"blame", &"mote"], &"apprentice", _aim_at(d[0]))
	_steps(0.2)
	var motes := _live(&"mote")
	ok(motes.size() == 1 and motes[0].tgt == d[1], "the Mote steers for it, not the nearer one")
	var m := Mods.new()
	Catalog.apply_boost(&"blame", m, 1)
	ok(m.blame and m.home > 0.0 and m.copy().blame, "Blame is a homing boost that survives a copy")


# ---- Hardware ----

func test_emp_purges_shots_and_breaks_defences() -> void:
	_room([Vector2(208, 120)])
	var ctr := world.player.origin()
	for a in [0.0, 1.5, 3.0]:
		world.enemy_shoot(ctr + Vector2.from_angle(a) * 20.0, a, 1.0, 5.0)
	world.enemy_shoot(ctr + Vector2(0, -90), 0.0, 1.0, 5.0)
	_fire([&"emp"])
	eq(world.ebullets.active.filter(func(b: Bullet) -> bool: return b.alive).size(), 1, "the three shots in range are wiped out, the far one flies on")
	eq(SpellRunner.keywords(Catalog.spell(&"emp"), Mods.new()), 7, "and it breaks shields, armor and wards")


func test_cosmic_ray_prefers_the_mark() -> void:
	_range_setup()
	var far: Enemy = world.enemies[3]
	world.mark(far, 4.0)
	_fire([&"cosmic_ray"])
	eq(_hurt(world.enemies).size(), 1, "one enemy struck")
	ok(far.hp < far.max_hp, "the marked one")
	_range_setup()
	world.marked = null
	_fire([&"cosmic_ray"])
	eq(_hurt(world.enemies).size(), 1, "with no mark it still strikes exactly one")


func test_undervolt_cuts_mana_speed_and_damage() -> void:
	var plain := WandProgram.compile(wand(["fan"]), 0, Mods.new())
	var c := WandProgram.compile(wand(["undervolt", "fan"]), 0, Mods.new())
	eq(plain.mana, 10.0, "a Spectrum Fan costs 10")
	eq(c.mana, 6.0, "under Undervolt: 40% less")
	ok(is_equal_approx(c.groups[0].mods.dmg, 0.8) and is_equal_approx(c.groups[0].mods.spd, -0.4), "for 20% less damage and 40% slower")
	var c3 := WandProgram.compile(wand([{"id": "undervolt", "lv": 3}, "fan"]), 0, Mods.new())
	eq(c3.mana, 4.0, "60% less at level 3")


func test_checkpoint_saves_once() -> void:
	ok(world.run.stats.has("room_hp"), "entering a room records its HP")
	_give(&"last_good_commit")
	var p := world.player
	world.run.stats["room_hp"] = 60.0
	Game.god_mode = false
	p.hp = 5.0
	p.inv = 0.0
	p.hurt(50.0, p.position + Vector2(10, 0))
	ok(not p.dead, "a fatal hit is rolled back")
	eq(p.hp, 60.0, "to the HP you entered the room with")
	p.inv = 0.0
	p.hp = 5.0
	p.hurt(50.0, p.position + Vector2(10, 0))
	Game.god_mode = true
	ok(p.dead, "but only once a run")


func test_shot_recycler_refills_the_wand_in_hand() -> void:
	_room([Vector2(208, 120)])
	_give(&"liquid_cooling")
	var ctr := world.player.origin()
	for a in [0.0, 1.5, 3.0]:
		world.enemy_shoot(ctr + Vector2.from_angle(a) * 20.0, a, 1.0, 5.0)
	var w := WandState.make(Catalog.wand(&"apprentice"))
	w.set_slots([&"emp"])
	world.run.wands[0] = w
	world.run.cur = 0
	w.mana = 30.0
	world.spells.wand_fire(w, world.player.tip(), -PI / 2.0)
	eq(w.mana, 30.0 - 12.0 + 6.0, "EMP stopped three shots: +2 mana each")
	# a blocker (Firewall) stopping a shot pays too
	_fire([&"firewall"])
	world.step(DT)
	var mid: Bullet = world.spells.blockers[world.spells.blockers.size() / 2]
	var hand := world.run.wand()
	hand.mana = 20.0
	world.enemy_shoot(mid.pos, PI / 2.0, 1.0, 5.0)
	world.step(DT)
	ok(hand.mana > 21.5, "a shot stopped by a Firewall refills too (%.1f)" % hand.mana)


# ---- art ----

func test_every_pack_item_has_an_icon() -> void:
	for id in Catalog.PACK_ITEMS:
		if Catalog.spells().has(id):
			ok(not IconArt.spell(id).is_empty(), "%s has a spell icon" % id)
			ok(Icons.spell(Catalog.spell(id)) != null, "%s icon renders" % id)
		elif Relics.DEFS.has(id):
			ok(not IconArt.relic(id).is_empty(), "%s has a relic icon" % id)
			ok(not Relics.CUT.has(id), "%s is not a cut relic's id" % id)
		else:
			ok(Catalog.wands().has(id), "%s is a wand" % id)
		ok(not Meta.CORE_SPELLS.has(id) and not Meta.CORE_RELICS.has(id) and not Meta.CORE_WANDS.has(id), "%s is not core" % id)
