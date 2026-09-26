extends "res://tests/unit/test_helpers.gd"
## Design v3 V6: runs that differ (shop decisions, reachable compiles, gentle mode).


func setup(_t: SceneTree) -> void:
	SaveGame.in_memory = true


func teardown() -> void:
	SaveGame.in_memory = false
	Game.gentle = false


func test_the_shop_rerolls_for_a_rising_price_and_has_a_sale() -> void:
	var r := RunState.create(12)
	r.shop = Rewards.shop_stock(r)
	eq(r.shop.filter(func(it: Dictionary) -> bool: return it.get("sale", false)).size(), 1, "one item on sale")
	r.gold = 100
	var before: Array = r.shop.filter(func(it: Dictionary) -> bool: return it["t"] == &"spell").map(func(it: Dictionary) -> StringName: return it["id"])
	ok(Rewards.reroll_shop(r), "a reroll")
	eq(r.gold, 90, "for 10")
	eq(Rewards.reroll_price(r), 20, "the next costs 20")
	var after: Array = r.shop.filter(func(it: Dictionary) -> bool: return it["t"] == &"spell").map(func(it: Dictionary) -> StringName: return it["id"])
	ok(before != after, "new spells (%s -> %s)" % [before, after])
	r.gold = 5
	ok(not Rewards.reroll_shop(r), "not without the gold")


func test_a_level_two_base_compiles() -> void:
	var r := RunState.create(3)
	r.wand().set_slots([null, null, {"id": &"spark", "lv": 2}])
	r.add_relic(&"cascade_failure")
	ok(Rewards.compilable(r).has(&"storm_protocol"), "Chain Spark at level 2 + Crit Arc compiles")
	ok(Rewards.compile_evo(r, &"storm_protocol"), "compiled")
	eq(r.wand().slots[2]["id"], &"storm_protocol", "into Storm Protocol")


func test_gentle_mode_scales_with_runs_lost() -> void:
	SaveGame.save_meta({"runs": 6, "wins": 1})
	eq(Game.gentle_resist(), 0.0, "off by default")
	Game.gentle = true
	ok(is_equal_approx(Game.gentle_resist(), 0.1), "five runs lost: 10%% (%.2f)" % Game.gentle_resist())
	SaveGame.save_meta({"runs": 60, "wins": 1})
	ok(is_equal_approx(Game.gentle_resist(), 0.4), "capped at 40%")
