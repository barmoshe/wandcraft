extends "res://tests/unit/world_fixture.gd"
## The 0.20 arsenal (research/arsenal-0.20/6-spells-wands.md): 14 spells and 5 wands with a
## rule. One behaviour test per card, in the world where it acts there, else in the compiler.


## An empty room with dummies at the given spots.
func _room(spots: Array) -> Array[Enemy]:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)
	var out: Array[Enemy] = []
	for p in spots:
		out.append(_dummy(p))
	world.hash.rebuild(world.enemies)
	return out


func _live(id: StringName) -> Array[Bullet]:
	var out: Array[Bullet] = []
	for b in world.bullets.active:
		if b.alive and b.cast and b.cast.spell.id == id:
			out.append(b)
	return out


## Casts a wand already in hand once more (clears its cooldown first).
func _again(w: WandState, ang := -PI / 2.0) -> bool:
	w.cd = 0.0
	world.player.aim = ang
	world.hash.rebuild(world.enemies)
	return world.spells.wand_fire(w, world.player.tip(), ang)


## Puts a wand in hand without casting it.
func _hold(ids: Array, wand_id := &"apprentice") -> WandState:
	var w := wand(ids, wand_id)
	world.run.wands[0] = w
	world.run.cur = 0
	return w


func _ids(plans: Array) -> Array:
	var out: Array = []
	for plan: WandProgram.Plan in plans:
		for g in plan.groups:
			out.append(g.spell.id)
	return out


# ---- shooting spells ----

func test_drill_bit_breaks_a_shield_and_grinds_through() -> void:
	_room([])
	var s := world.spawn_enemy(&"sentry", Vector2(208, 170))
	s.ai = &"dummy"
	s.spawn_t = 0.0
	s.sprite.visible = true
	s.dmg = 0.0
	var behind := _dummy(Vector2(208, 135))
	ok(s.shield_hp > 0, "the sentry starts shielded")
	_fire([&"drill_bit"])
	_steps(1.4)
	eq(s.shield_hp, 0, "the drill breaks its shield")
	ok(s.hp < s.max_hp, "and hurts it")
	ok(behind.hp < behind.max_hp, "then grinds on into the enemy behind it")
	eq(SpellRunner.keywords(Catalog.spell(&"drill_bit"), Mods.new()) & 1, 1, "it carries Pierce")


func test_drill_bit_speeds_up_at_level_3() -> void:
	_room([Vector2(207, 180)])
	_fire([{"id": &"drill_bit", "lv": 3}])
	var b: Bullet = _live(&"drill_bit")[0]
	var v0 := b.vel.length()
	_steps(0.4)
	ok(b.vel.length() > v0 * 1.2, "faster after passing an enemy (%.0f -> %.0f)" % [v0, b.vel.length()])


func test_zip_bomb_grows_with_the_spells_cast_before_it() -> void:
	var plans := WandProgram.preview_cycle(wand(["mote", "mote", "zip_bomb"]))
	eq(plans[2].groups[0].mods.cast_n, 2, "two spells went out before it this pass")
	_range_setup()
	_fire([&"zip_bomb"])
	_steps(1.2)
	var alone := world.damage_done
	_range_setup()
	var w := _hold([&"mote", &"mote", &"zip_bomb"])
	_again(w, PI / 2.0)   # the Motes go the other way
	_again(w, PI / 2.0)
	_steps(0.1)
	world.damage_done = 0.0
	_again(w)
	_steps(1.2)
	ok(alone > 0.0, "a lone Zip Bomb lands (%.0f)" % alone)
	ok(world.damage_done > alone * 1.3, "third in line it hits 40%% harder (%.0f vs %.0f)" % [world.damage_done, alone])
	eq(SpellRunner.keywords(Catalog.spell(&"zip_bomb"), Mods.new()) & 2, 2, "it carries Blast")


func test_blue_screen_strips_a_ward_and_freezes_once() -> void:
	var d := _room([Vector2(207, 175)])
	var e := d[0]
	e.ward_n = Enemy.WARD_HITS
	_fire([&"blue_screen"])
	var frozen := 0
	var was := false
	for k in 150:
		world.step(DT)
		var now := e.frozen_t > 0.0
		if now and not was:
			frozen += 1
		was = now
	eq(e.ward_n, 0, "the ward is stripped")
	ok(e.hp < e.max_hp, "and the field hurts")
	eq(frozen, 1, "it froze the enemy exactly once")


# ---- carrier and trigger ----

func test_tarball_releases_two_spells() -> void:
	var c := WandProgram.compile(wand(["tarball", "burst", "ember"]), 0, Mods.new())
	var t := c.groups[0]
	ok(t.payload != null and t.payload.spell.id == &"burst", "it holds the Burst")
	ok(t.payload.also != null and t.payload.also.spell.id == &"ember", "and the Ember Bolt after it")
	eq(c.mana, 3.0 + 8.0 + 6.0, "both at full mana at level 1")
	var c3 := WandProgram.compile(wand([{"id": "tarball", "lv": 3}, "burst", "ember"]), 0, Mods.new())
	eq(c3.mana, 5.0 + roundf((8.0 + 6.0) * 0.75), "75% at level 3")
	_range_setup()
	_fire([&"tarball", &"burst"])
	_steps(1.6)
	var one := world.damage_done
	_range_setup()
	_fire([&"tarball", &"burst", &"ember"])
	_steps(0.95)
	ok(_live(&"ember").size() == 1 or world.damage_done > one, "the Ember Bolt goes out where it stops")
	_steps(0.8)
	ok(world.damage_done > one, "both spells land (%.0f vs %.0f)" % [world.damage_done, one])


func test_await_casts_from_the_wand_at_the_hit_enemy() -> void:
	var d := _room([Vector2(150, 150)])
	var e := d[0]
	var ang := (e.position - world.player.origin()).angle()
	world.player.aim = ang
	var w := _hold([&"mote", &"await_hit", &"needle"])
	_again(w, (e.position - world.player.tip()).angle())
	var seen: Bullet = null
	for k in 60:
		world.step(DT)
		var n := _live(&"needle")
		if not n.is_empty():
			seen = n[0]
			break
	ok(seen != null, "the Mote's hit released the Needle")
	if seen:
		var tip := world.player.tip()
		ok(seen.pos.distance_to(tip) < 24.0, "from the wand (%.0f px from the tip)" % seen.pos.distance_to(tip))
		var want := (e.position + Vector2(0, -4) - tip).angle()
		ok(absf(angle_difference(seen.vel.angle(), want)) < 0.25, "straight at the enemy it hit")


func test_await_fires_up_to_its_level() -> void:
	for lv in [1, 3]:
		_room([Vector2(207, 170)])
		Game.inf_mana = true
		_fire([&"null_orb", {"id": &"await_hit", "lv": lv}, &"mote"])
		_steps(2.0)
		Game.inf_mana = false
		eq(world.spells.cast_seq - 1, lv, "level %d: %d casts from one orb that hits many times" % [lv, lv])


# ---- boosts ----

func test_buffering_holds_then_releases_at_recharge() -> void:
	_range_setup()
	var w := _fire([&"buffering", &"mote"])
	eq(_live(&"mote").size(), 0, "nothing goes out yet")
	var c := WandProgram.compile(wand(["buffering", "mote"]), 0, Mods.new())
	ok(is_equal_approx(c.groups[0].mods.dmg, 1.1), "+10% damage at level 1")
	eq(w.buffer.size(), 0, "a one-cast wand recharges at once, so the hold is queued for the recharge")
	_steps(w.rech_max - 0.05)
	eq(_live(&"mote").size(), 0, "still waiting just before the recharge ends")
	eq(world.damage_done, 0.0, "nothing hit yet")
	_steps(0.1)
	eq(_live(&"mote").size() + int(world.damage_done > 0.0), 1, "out when the recharge is over")
	_steps(1.0)
	ok(world.damage_done > 0.0, "and it hits")


func test_buffering_gathers_a_volley() -> void:
	_room([])
	var w := _hold([&"buffering", &"mote", &"mote", &"mote"])
	_again(w)
	_again(w)
	eq(w.buffer.size(), 2, "two casts held")
	eq(_live(&"mote").size(), 0, "none out")
	_again(w)
	_steps(w.rech_max + 0.05)
	eq(_live(&"mote").size(), 3, "all three go at once after the recharge")


func test_retry_recasts_a_miss() -> void:
	_range_setup()
	_fire([&"mote"], &"apprentice", PI / 2.0)
	_steps(1.6)
	eq(world.damage_done, 0.0, "a Mote fired away from everyone misses")
	_range_setup()
	var w := _fire([&"retry", &"mote"], &"apprentice", PI / 2.0)
	var mana := w.mana
	_steps(2.0)
	ok(world.damage_done > 0.0, "with Retry it goes again from you and hits (%.0f)" % world.damage_done)
	ok(w.mana >= mana, "for free")


func test_retry_gives_up_after_its_tries() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(205, 216)
	var seq := world.spells.cast_seq
	_fire([&"retry", &"mote"], &"apprentice", PI / 2.0)
	_steps(3.0)
	eq(world.spells.cast_seq, 2, "one retry at level 1 with nothing to hit (from %d)" % seq)
	_fire([{"id": &"retry", "lv": 3}, &"mote"], &"apprentice", PI / 2.0)
	_steps(4.0)
	eq(world.spells.cast_seq, 3, "two at level 3")


func test_jit_grows_per_recharge_and_resets_per_room() -> void:
	_range_setup()
	var w := _hold([&"jit", &"mote"])
	_again(w)
	_steps(0.8)
	var first := world.damage_done
	eq(w.jit_n, 1, "one recharge counted")
	for k in 4:
		_again(w, PI / 2.0)
	eq(w.jit_n, 5, "five recharges this room")
	_steps(1.0)
	world.damage_done = 0.0
	_again(w)
	_steps(0.8)
	ok(absf(world.damage_done - first * 1.3) < 0.6, "+6%% per recharge: 1.3x after five (%.1f vs %.1f)" % [world.damage_done, first])
	w.jit_n = 50
	var m := Mods.new()
	Catalog.apply_boost(&"jit", m, 1)
	eq(m.jit, 1, "Just-in-Time marks the spells on its right")
	world.build_room("hall", &"empty")
	eq(w.jit_n, 0, "a new room starts it over")


func test_end_block_stops_boosts() -> void:
	var plain := WandProgram.compile(wand(["empower", "mote"]), 0, Mods.new())
	ok(is_equal_approx(plain.groups[0].mods.dmg, 1.25), "Empower powers the Mote")
	var c := WandProgram.compile(wand(["empower", "wide", "end_scope", "mote"]), 0, Mods.new())
	ok(is_equal_approx(c.groups[0].mods.dmg, 1.0) and is_equal_approx(c.groups[0].mods.area, 1.0), "End Block: the Mote casts plain")
	eq(c.mana, 5.0 + 3.0 + 0.0 + 3.0, "the boosts are still paid for")
	var c2 := WandProgram.compile(wand(["empower", "mote", "end_scope", "needle"]), 0, Mods.new())
	ok(is_equal_approx(c2.groups[0].mods.dmg, 1.25), "spells on its left keep their boosts")
	var c3 := WandProgram.compile(wand(["end_scope", "empower", "needle"]), 0, Mods.new())
	ok(is_equal_approx(c3.groups[0].mods.dmg, 1.25), "boosts on its right work as usual")


# ---- runes ----

func test_alt_tab_alternates() -> void:
	_range_setup()
	var w := _hold([&"alt_tab", &"mote", &"needle"])
	_again(w)
	eq(_live(&"mote").size() + _live(&"needle").size(), 1, "one spell per cast")
	eq(_live(&"mote").size(), 1, "the first pass casts the spell on its right")
	eq(w.cycles, 1, "and the wand recharged")
	_again(w)
	eq(_live(&"needle").size(), 1, "the next pass casts the one after it")
	_again(w)
	eq(_live(&"mote").size(), 2, "then back again")
	var c := WandProgram.compile(wand(["alt_tab", "burst", "mote"]), 0, Mods.new())
	eq(c.mana, 1.0 + 8.0, "only the spell cast is paid for")


func test_autocomplete_fills_empty_slots() -> void:
	var w := wand(["autocomplete", "mote", null, null, "needle"])
	var plans := WandProgram.preview_cycle(w)
	eq(_ids(plans), [&"mote", &"mote", &"mote", &"needle"], "two empty slots cast Motes")
	ok(is_equal_approx(plans[1].groups[0].mods.dmg, 0.6), "at 60% damage")
	eq(plans[1].groups[0].slot, 2, "from the empty slot")
	eq(plans[1].mana, 3.0, "for the Mote's mana")
	eq(_ids(WandProgram.preview_cycle(wand(["mote", null, "needle"]))), [&"mote", &"needle"], "without it an empty slot is dead")
	eq(_ids(WandProgram.preview_cycle(wand([null, "autocomplete", null, "needle", null]))), [&"needle", &"needle"],
		"an empty slot with no spell before it stays empty")
	_range_setup()
	var h := _hold([&"autocomplete", &"mote", null, null, &"needle"])
	for k in 4:
		_again(h)
	_steps(0.6)
	ok(world.damage_done > 0.0, "the copies fly and hit")


func test_ctrl_alt_del_fires_on_hit_and_is_out_of_the_cycle() -> void:
	var d := _room([Vector2(205, 190)])
	var w := _hold([&"ctrl_alt_del", &"burst", &"mote"])
	eq(_ids(WandProgram.preview_cycle(w)), [&"mote"], "the Burst is out of the wand's order")
	var mana := w.mana
	Game.god_mode = false
	var p := world.player
	p.inv = 0.0
	p.hurt(1.0, p.position + Vector2(10, 0))
	var hit := d[0].hp < d[0].max_hp
	var seq := world.spells.cast_seq
	p.inv = 0.0
	p.hurt(1.0, p.position + Vector2(10, 0))
	Game.god_mode = true
	ok(hit, "getting hit set off the Burst around you")
	eq(w.mana, mana, "for free")
	eq(world.spells.cast_seq, seq, "not again within its cooldown")
	w.cad_at.clear()
	Game.god_mode = false
	p.inv = 0.0
	p.hurt(1.0, p.position + Vector2(10, 0))
	Game.god_mode = true
	eq(world.spells.cast_seq, seq + 1, "ready again once the cooldown is over")


# ---- passives ----

func test_virtual_memory_casts_below_zero() -> void:
	_range_setup()
	var plain := _hold([&"burst"])
	plain.mana = 5.0
	ok(not _again(plain), "a plain wand with 5 mana cannot pay 8")
	var w := _hold([&"virtual_memory", &"burst"])
	w.mana = 5.0
	ok(_again(w), "Virtual Memory casts anyway")
	eq(w.mana, -3.0, "and goes 3 below zero")
	w.mana = -15.0
	ok(not _again(w), "but not past 20 below at level 1")
	var r := w.regen_mul()
	w.mana = 10.0
	ok(is_equal_approx(r, w.regen_mul() * 0.7), "below zero it refills 30% slower")


func test_cache_hit_discounts_a_repeat() -> void:
	_range_setup()
	var w := _hold([&"cache_hit", &"mote", &"mote", &"lance"])
	var m0 := w.mana
	_again(w)
	eq(m0 - w.mana, 3.0, "the first Mote pays in full")
	var m1 := w.mana
	_again(w)
	eq(m1 - w.mana, 2.0, "the Mote right after it pays 30% less (rounded)")
	var m2 := w.mana
	_again(w)
	eq(m2 - w.mana, 3.0, "a Prism Lance after a Mote pays in full")
	var plain := _hold([&"mote", &"mote"])
	var p0 := plain.mana
	_again(plain)
	_again(plain)
	eq(p0 - plain.mana, 6.0, "without Cache Hit both pay in full")


# ---- wands ----

func test_shuffle_play_plays_a_new_order_each_recharge() -> void:
	_range_setup()
	Game.inf_mana = true
	var w := _hold([&"mote", &"needle", &"lance", &"frost", &"spark", &"ember"], &"shuffle_play")
	var orders := {}
	for k in 30:
		_again(w)
		if w.ptr == 0:
			orders[str(w.order)] = true
			var sorted := Array(w.order)
			sorted.sort()
			eq(sorted, [0, 1, 2, 3, 4, 5], "the order is a shuffle of the six slots")
			var plan := WandProgram.compile(w)
			eq(plan.groups[0].slot, w.order[0], "the next cast follows the order shown")
			eq(Hud.next_slot(w), w.order[0], "and the HUD points at it")
	Game.inf_mana = false
	ok(orders.size() >= 2, "the order changes between recharges (%d seen)" % orders.size())
	eq(w.read_pos(w.order[0]), 0, "the editor numbers the slots in the next order")


func test_pinned_tab_joins_every_cast() -> void:
	var w := wand(["mote", "needle", "lance"], &"pinned_tab")
	var plans := WandProgram.preview_cycle(w)
	eq(plans.size(), 2, "slot 1 is out of the order: two casts")
	for plan: WandProgram.Plan in plans:
		var last := plan.groups[plan.groups.size() - 1]
		ok(last.spell.id == &"mote" and is_equal_approx(last.mods.dmg, 0.5), "each cast brings the pinned Mote at 50%")
	eq(plans[0].mana, 2.0, "for free: only the Needle is paid")
	var b := wand(["empower", "needle", "seed", "mote"], &"pinned_tab")
	var bp := WandProgram.preview_cycle(b)
	ok(is_equal_approx(bp[0].groups[0].mods.dmg, 1.25), "a pinned boost powers every spell")
	ok(is_equal_approx(bp[1].groups[0].payload.mods.dmg, 1.25), "even a carried one")
	eq(bp[0].mana, 2.0, "and costs nothing")
	_range_setup()
	var h := _hold([&"mote", &"needle"], &"pinned_tab")
	_again(h)
	eq(_live(&"mote").size() + _live(&"needle").size(), 2, "the pinned Mote flies with the Needle")


func test_palindrome_reads_there_and_back() -> void:
	var w := wand(["mote", "needle", "lance", "frost", "ember"], &"palindrome")
	eq(_ids(WandProgram.preview_cycle(w)), [&"mote", &"needle", &"lance", &"frost", &"ember", &"frost", &"lance", &"needle"],
		"1-2-3-4-5-4-3-2, then recharge")
	var back := wand(["mote", "needle", "empower", "lance"], &"palindrome")
	var bp := WandProgram.preview_cycle(back)
	# the staff has 5 slots, the fifth empty: 1-2-3-4-(5)-4-3-2
	eq(_ids(bp), [&"mote", &"needle", &"lance", &"lance", &"needle"], "there and back")
	ok(is_equal_approx(bp[2].groups[0].mods.dmg, 1.25), "on the way out the boost powers the spell on its right")
	var last := bp[4].groups[0]
	ok(last.mods.dmg > 1.3, "on the way back it powers the one on its left (%.2f)" % last.mods.dmg)


func test_double_buffer_switches_page_each_recharge() -> void:
	_range_setup()
	Game.inf_mana = true
	var w := _hold([&"mote", &"mote", null, null, &"needle", &"lance", null, null], &"double_buffer")
	eq(_ids(WandProgram.preview_cycle(w)), [&"mote", &"mote"], "page 1 plays first")
	eq(w.read_pos(4), -1, "the other page is not in the order")
	_again(w)
	_again(w)
	eq(w.page, 1, "after a recharge it turns the page")
	eq(_ids(WandProgram.preview_cycle(w)), [&"needle", &"lance"], "page 2 plays next")
	_again(w)
	_again(w)
	eq(w.page, 0, "and back")
	var e := _hold([&"mote", null, null, null, null, null, null, null], &"double_buffer")
	e.page = 1
	ok(not _again(e), "an empty page casts nothing")
	eq(e.page, 0, "and turns over at once")
	Game.inf_mana = false


func test_recycle_bin_refills_on_kills_only() -> void:
	var d := _room([Vector2(207, 170)])
	var w := _hold([&"mote"], &"recycle_bin")
	w.mana = 50.0
	_steps(1.0)
	eq(w.mana, 50.0, "no mana comes back on its own")
	d[0].hp = 1.0
	world.hurt_enemy(d[0], 5.0, d[0].position, 0.0, 0.0)
	ok(d[0].dead, "a kill")
	eq(w.mana, 50.0 + WandState.RECYCLE_MANA, "refills 12")
	world.build_room("hall", &"empty")
	eq(w.mana, w.max_mana(), "a new room starts it full")


# ---- content ----

func test_new_cards_exist_and_are_not_core() -> void:
	var spells := [&"drill_bit", &"zip_bomb", &"blue_screen", &"tarball", &"await_hit", &"buffering", &"retry", &"jit",
		&"end_scope", &"alt_tab", &"autocomplete", &"ctrl_alt_del", &"virtual_memory", &"cache_hit"]
	for id in spells:
		ok(Catalog.spell(id) != null, "%s is in the catalog" % id)
		ok(not Catalog.tags(id).is_empty(), "%s has tags" % id)
		ok(not Meta.CORE_SPELLS.has(id), "%s is not core" % id)
	eq(Catalog.spell(&"await_hit").title, "Await", "Await keeps its title under a safe id")
	for id in [&"shuffle_play", &"pinned_tab", &"palindrome", &"double_buffer", &"recycle_bin"]:
		ok(Catalog.wand(id) != null and Catalog.wand(id).rule != &"", "%s is a wand with a rule" % id)
		ok(not Meta.CORE_WANDS.has(id), "%s is not core" % id)
