extends "res://tests/unit/test_helpers.gd"
## D9: Source Fragments, the unlock pool, the starting slot, and the Bug Reports tiers.


func teardown() -> void:
	Meta.test_meta = null


func test_nothing_is_locked_when_saving_is_off() -> void:
	Meta.test_meta = null
	ok(not Meta.is_locked(&"include"), "tests and the bench see the whole game")


func test_locked_content_is_never_offered_until_bought() -> void:
	Meta.test_meta = {"fragments": 0, "unlocked": []}
	ok(Meta.is_locked(&"include") and Meta.is_locked(&"stub"), "a new player's pool leaves the runes and the Stub start out")
	var run := RunState.create(7)
	var seen := {}
	for i in 400:
		seen[Rewards.roll_spell(run)] = true
	for u in Meta.UNLOCKS:
		if u["t"] == &"spell" or u["t"] == &"rune":
			ok(not seen.has(u["id"]), "%s is not offered while locked" % u["id"])
	var loads: Array = Rewards.offer(run, &"start").map(func(o: Dictionary) -> StringName: return o["id"])
	ok(loads == [&"twig"], "only the Twig start until the Stub is bought (%s)" % [loads])
	for k in 60:
		for r in Rewards.roll_relics(run, 3):
			ok(not Meta.is_locked(r), "%s is not offered while locked" % r)


func test_fragments_buy_unlocks() -> void:
	Meta.test_meta = {"fragments": 10, "unlocked": []}
	ok(not Meta.buy(&"include"), "too dear")
	ok(Meta.buy(&"stub"), "the Stub start costs 6")
	ok(Meta.fragments() == 4 and not Meta.is_locked(&"stub"), "fragments spent, the Stub is in the pool")
	ok(not Meta.buy(&"stub"), "an unlock is bought once")


func test_what_a_run_earns() -> void:
	var run := RunState.create(7)
	run.stats["rooms"] = 6
	run.stats["bosses"] = 1
	ok(Meta.earned(run) == 9, "six rooms and the mini-boss: 6 + 3 (%d)" % Meta.earned(run))
	run.stats["bosses"] = 2
	run.won = true
	run.stats["rooms"] = 8
	ok(Meta.earned(run) == 21, "a win: 8 + 3 + 5 + 5 (%d)" % Meta.earned(run))
	run.heat = 2
	ok(Meta.earned(run) == roundi(21 * 1.4), "Bug Reports add 20%% a tier (%d)" % Meta.earned(run))


func test_the_starting_slot_upgrade() -> void:
	Meta.test_meta = {"fragments": 40, "unlocked": []}
	ok(Meta.extra_slots() == 0, "no extra slot before buying it")
	Meta.buy(&"slot")
	ok(Meta.extra_slots() == 1, "one extra slot after")
	var run := RunState.create(7)
	var n := run.wand().slots.size()
	run.set_loadout(&"twig")
	ok(run.wand().slots.size() == n + 1, "the start room's loadout keeps the extra slot")


func test_bug_reports_add_elites_and_raise_prices() -> void:
	var run := RunState.create(9)
	run.step = 2
	run.heat = 1
	var rng := RandomNumberGenerator.new()
	for s in 20:
		rng.seed = s
		var waves := Encounter.compose(run, &"fight", rng)
		var last: Array = waves[waves.size() - 1]
		ok(last.any(func(e: Array) -> bool: return e[1]) or last.all(func(e: Array) -> bool: return e[0] == &"bugling"),
			"tier 1: the last wave carries an elite (seed %d)" % s)
	run.heat = 0
	var base := Rewards.shop_stock(run)
	run.heat = 4
	var dear := Rewards.shop_stock(run)
	ok(int(dear[dear.size() - 2]["price"]) > int(base[base.size() - 2]["price"]), "tier 4: the shop's heal costs more")
	ok(Meta.HEAT.size() == 6, "five tiers and none")
