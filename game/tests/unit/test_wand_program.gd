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


# ---- D2: Debugger runes, Pipeline, familiars, wand quirks ----

func test_head_casts_a_free_copy_of_the_first_spell() -> void:
	var w := wand(["mote", "empower", "head"])
	var a := WandProgram.compile(w, 0, Mods.new())
	var b := WandProgram.compile(w, a.ptr, a.acc)
	eq(String(b.groups[0].spell.id), "mote", "HEAD copies the Mote")
	ok(b.groups[0].free_copy, "as a free copy")
	ok(is_equal_approx(b.groups[0].mods.dmg, 1.25), "with the boosts it has right now")
	eq(b.mana, 5.0 + 4.0, "paying only for Empower and the rune")


func test_ifelse_holds_both_branches() -> void:
	var c := WandProgram.compile(wand(["ifelse", "lance", "ember"]), 0, Mods.new())
	eq(c.groups.size(), 1, "one cast")
	var g := c.groups[0]
	ok(g.cond, "a conditional node")
	eq(String(g.spell.id), "lance", "near: the Lance")
	eq(String(g.alt.spell.id), "ember", "else: the Ember Bolt")
	eq(c.mana, 2.0 + 6.0, "pays the rune and the dearer branch")


func test_goto_jumps_back_once_per_cycle() -> void:
	var w := wand(["mote", "goto", "ember"])
	var a := WandProgram.compile(w, 0, Mods.new())
	eq(String(a.groups[0].spell.id), "mote", "first cast: the Mote")
	var b := WandProgram.compile(w, a.ptr, a.acc)
	eq(String(b.groups[0].spell.id), "mote", "GOTO jumps back to slot 1")
	ok(not b.wrapped, "without recharging")
	ok(b.delay_add >= 0.3, "for a little delay")
	var c := WandProgram.compile(w, b.ptr, b.acc)
	eq(String(c.groups[0].spell.id), "ember", "the second time GOTO is skipped")
	ok(c.wrapped, "and the cycle ends")


func test_include_makes_a_boost_global() -> void:
	var w := wand(["mote", "include", "empower", "mote"])
	var a := WandProgram.compile(w, 0, Mods.new())
	ok(is_equal_approx(a.groups[0].mods.dmg, 1.25), "the Mote left of #include is empowered too")
	var b := WandProgram.compile(w, a.ptr, a.acc)
	ok(is_equal_approx(b.groups[0].mods.dmg, 1.25), "and the one on the right, once")
	eq(b.mana, roundf(5.0 + 5.0 * 1.5 + 3.0), "the included boost costs x1.5")


func test_pipeline_lines_casts_up_in_time() -> void:
	var c := WandProgram.compile(wand(["pipeline", "mote", "mote", "mote"]), 0, Mods.new())
	eq(c.groups.size(), 3, "three Motes in one cast")
	for k in 3:
		ok(is_equal_approx(c.groups[k].delay, k * 0.06), "Mote %d goes out after %.2fs" % [k + 1, k * 0.06])
		eq(c.groups[k].mods.scatter, 0.0, "with no spread")


func test_daemon_carries_its_payload_and_pays_per_shot() -> void:
	var c := WandProgram.compile(wand(["daemon", "ember"]), 0, Mods.new())
	var g := c.groups[0]
	eq(String(g.trig), "daemon", "the Daemon carries")
	eq(String(g.payload.spell.id), "ember", "the Ember Bolt")
	eq(c.mana, 10.0, "only the summon is paid up front")
	eq(g.pay_mana, 6.0, "each shot pays the Ember Bolt")


func test_daemon_rod_background_slot_is_not_in_the_program() -> void:
	var w := wand(["mote", null, null, null, null, "ember"], &"daemon_rod")
	var c := WandProgram.compile(w, 0, Mods.new())
	eq(String(c.groups[0].spell.id), "mote", "the Mote casts")
	ok(c.wrapped, "and the program ends before the background slot")
	eq(String(w.background()["id"]), "ember", "which holds the Ember Bolt")


func test_debug_build_taxes_runes() -> void:
	var c := WandProgram.compile(wand(["ifelse", "mote", "mote"], &"debug_build"), 0, Mods.new())
	eq(c.mana, 2.0 * 2.0 + 3.0, "Debugger runes cost double on a Debug Build")


func test_level_three_changes_behaviour() -> void:
	var d := Catalog.spell(&"mote")
	eq(int(d.param("pierce", 3, 0)), 1, "a level-3 Mote passes through one enemy")
	eq(int(d.param("pierce", 2, 0)), 0, "a level-2 one does not")
	eq(Catalog.resolve(&"linger"), &"quicken", "Linger folded into Long Range")
	eq(Catalog.resolve(&"shatter"), &"", "Shatter was cut")
