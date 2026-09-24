extends "res://tests/unit/test_helpers.gd"
## Golden tests for the wand compiler (rules proven in the Wandcraft prototype).


func test_single_bolt_wraps_each_cast() -> void:
	var c := WandProgram.compile(wand(["mote"]), 0, Mods.new())
	eq(c.groups.size(), 1, "one shooting spell per cast")
	ok(c.wrapped, "reaching the end closes the cycle")
	eq(c.mana, 3.0, "mote costs 3")


func test_boost_carries_to_the_right_until_recharge() -> void:
	var w := wand(["empower", "mote", "mote"])
	var a := WandProgram.compile(w, 0, Mods.new())
	eq(a.groups.size(), 1, "first cast: one mote")
	ok(is_equal_approx(a.groups[0].mods.dmg, 1.25), "empower applies to the first mote")
	ok(not a.wrapped, "not at the end yet")
	var b := WandProgram.compile(w, a.ptr, a.acc)
	ok(is_equal_approx(b.groups[0].mods.dmg, 1.25), "empower still applies to the second mote")
	ok(b.wrapped, "second cast closes the cycle")
	eq(b.acc.dmg, 1.0, "boosts reset when the wand recharges")


func test_trigger_glues_left_to_right() -> void:
	var c := WandProgram.compile(wand(["mote", "then", "burst"]), 0, Mods.new())
	eq(c.groups.size(), 1, "THEN makes one cast out of two spells")
	var g := c.groups[0]
	eq(String(g.spell.id), "mote", "left spell carries")
	eq(String(g.trig), "then", "trigger recorded")
	eq(String(g.payload.spell.id), "burst", "right spell is the payload")
	eq(c.mana, 3.0 + 4.0 + 8.0, "THEN pays the payload up front")


func test_callback_pays_when_it_fires() -> void:
	var c := WandProgram.compile(wand(["lance", "callback", "mote"]), 0, Mods.new())
	var g := c.groups[0]
	eq(String(g.trig), "callback", "callback trigger")
	eq(c.mana, 3.0 + 5.0, "the payload is not paid up front")
	ok(is_equal_approx(g.pay_mana, 3.0 * 0.8), "pays 80% of the payload per call")


func test_fork_costs_four_times() -> void:
	var c := WandProgram.compile(wand(["mote", "fork", "mote"]), 0, Mods.new())
	eq(c.mana, 3.0 + 6.0 + 3.0 * 4.0, "fork bomb: payload mana x4")


func test_carrier_seed_discount() -> void:
	var c := WandProgram.compile(wand(["seed", "burst"]), 0, Mods.new())
	var g := c.groups[0]
	eq(String(g.trig), "seed", "seed carries")
	eq(String(g.payload.spell.id), "burst", "burst is the payload")
	eq(c.mana, roundf(1.0 + 8.0 * 0.9), "payload at 90% mana")


func test_starwheel_costs_x4() -> void:
	var c := WandProgram.compile(wand(["wheel", "mote"]), 0, Mods.new())
	eq(c.mana, 12.0 + 3.0 * 4.0, "starwheel payload x4")


func test_twin_cast_stops_at_payload() -> void:
	var c := WandProgram.compile(wand(["twin", "seed", "mote"]), 0, Mods.new())
	var g := c.groups[0]
	eq(g.mods.multi, 1, "twin applies to the carrier")
	eq(g.payload.mods.multi, 0, "twin does not leak into the payload scope")


func test_chorus_draws_more_spells() -> void:
	var c := WandProgram.compile(wand(["chorus", "mote", "mote", "mote"]), 0, Mods.new())
	eq(c.groups.size(), 3, "chorus L1 draws 2 more spells into the cast")
	ok(c.mana < 9.0, "chorus makes them cheaper")
	ok(c.groups[1].mods.scatter > 0.0, "and spreads them")


func test_mirror_duplicates_next() -> void:
	var c := WandProgram.compile(wand(["mirror", "mote"]), 0, Mods.new())
	eq(c.groups.size(), 2, "mirror casts the next shooting spell twice")


func test_no_slot_read_twice_and_no_loop() -> void:
	var w := wand(["chorus", "chorus", "chorus", "mote", "mote"], &"apprentice")
	var c := WandProgram.compile(w, 0, Mods.new())
	ok(c.groups.size() <= 5, "every slot is read at most once per cast")


func test_nesting_is_capped() -> void:
	var w := WandState.make(Catalog.wand(&"harp"))
	w.set_slots(["seed", "seed", "seed", "seed", "seed", "seed", "mote"])
	var c := WandProgram.compile(w, 0, Mods.new())
	var depth := 0
	var g: CastNode = c.groups[0]
	while g.payload != null:
		depth += 1
		g = g.payload
	ok(depth <= WandProgram.MAX_DEPTH, "payload nesting stops at depth 3")


func test_passives_are_skipped_and_apply() -> void:
	var w := wand(["cache", "mote"])
	ok(w.max_mana() > 80.0, "mana cache raises max mana")
	var c := WandProgram.compile(w, 0, Mods.new())
	eq(String(c.groups[0].spell.id), "mote", "passives are never cast")


func test_empty_wand_is_safe() -> void:
	var c := WandProgram.compile(wand([null, null]), 0, Mods.new())
	eq(c.groups.size(), 0, "no shooting spell, no cast")
