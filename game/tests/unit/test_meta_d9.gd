extends "res://tests/unit/test_helpers.gd"
## Design v2: the core pool, goals and heroes; D9's Bug Reports tiers.


func teardown() -> void:
	Meta.test_meta = null


func test_nothing_is_locked_when_saving_is_off() -> void:
	Meta.test_meta = null
	ok(not Meta.is_locked(&"include"), "tests and the bench see the whole game")


func test_a_new_player_meets_only_the_core() -> void:
	Meta.test_meta = {"meta_v": 2, "bounties": [], "packs": [], "unlocked": []}
	ok(Meta.is_locked(&"include") and Meta.is_locked(&"pyromancer"), "runes and later heroes wait on packs and bounties")
	ok(not Meta.is_locked(&"mote") and not Meta.is_locked(&"apprentice"), "the core is open")
	var run := RunState.create(7)
	var seen := {}
	for i in 400:
		seen[Rewards.roll_spell(run)] = true
	for id in seen:
		ok(Meta.CORE_SPELLS.has(id), "%s offered from the core" % id)
	for k in 60:
		for r in Rewards.roll_relics(run, 3):
			ok(Meta.CORE_RELICS.has(r), "%s offered from the core" % r)
	for k in 80:
		for it in Rewards.offer(run, &"spell"):
			ok(Meta.CORE_SPELLS.has(it["id"]), "%s in a whole offer is core (the counter pick too)" % it["id"])
	var starts: Array = Rewards.offer(run, &"start")
	var free: Array = starts.filter(func(o: Dictionary) -> bool: return not o["locked"]).map(func(o: Dictionary) -> StringName: return o["id"])
	eq(free, [&"apprentice"], "only the Apprentice until a bounty opens more")
	var pyro: Dictionary = starts.filter(func(o: Dictionary) -> bool: return o["id"] == &"pyromancer")[0]
	ok(not Rewards.grant(run, pyro), "a locked hero cannot be taken")
	run.tutorial = true
	eq(Rewards.offer(run, &"start").size(), 1, "the first run (a lesson) offers only the Apprentice")


func test_every_locked_thing_has_a_source() -> void:
	for id in Catalog.spells():
		if not Catalog.is_evolved(id) and id != &"apprentice":
			ok(Meta.CORE_SPELLS.has(id) or Meta.source_text(id) != "", "spell %s: core, a pack or a bounty" % id)
	for id in Relics.DEFS:
		ok(Meta.CORE_RELICS.has(id) or Meta.source_text(id) != "", "relic %s: core, a pack or a bounty" % id)
	for id in Catalog.wands():
		if id != &"apprentice":
			ok(Meta.CORE_WANDS.has(id) or Meta.source_text(id) != "", "wand %s: core, a pack or a bounty" % id)
	for id in Meta.CORE_SPELLS + Meta.CORE_RELICS + Meta.CORE_WANDS:
		ok(Meta.is_core(id), "%s is core and never in a pack or behind a bounty" % id)
	var once := {}
	for p in Meta.PACKS:
		for id in p["items"]:
			ok(not once.has(id), "%s sits in one pack only" % id)
			once[id] = true
			ok(Meta.bounty_for(id).is_empty(), "%s is not also a bounty's" % id)
			ok(Catalog.spells().has(id) or Relics.DEFS.has(id) or Catalog.wands().has(id), "pack item %s exists" % id)


func test_bounties_unlock_their_items() -> void:
	Meta.test_meta = {"meta_v": 2, "bounties": [], "packs": [], "unlocked": [], "runs": 0}
	var run := RunState.create(7)
	eq(Meta.check(run).size(), 0, "a fresh run met nothing")
	run.stats["rooms"] = 1
	run.stats["clean"] = 1
	var got := Meta.check(run).map(func(g: Dictionary) -> String: return g["id"])
	ok(got.has("room") and got.has("clean"), "a clean first room fixes two bounties (%s)" % [got])
	ok(not Meta.is_locked(&"chorus") and not Meta.is_locked(&"deadline"), "their items open at once")
	eq(Meta.check(run).size(), 0, "a bounty is fixed once")
	run.stats["bosses"] = 1
	Meta.check(run)
	ok(not Meta.is_locked(&"pyromancer"), "beating a mini-boss opens the Pyromancer")
	eq(Meta.open_bounties()[0]["id"], "runs1", "the next ticket on the board")
	eq(Meta.board().size(), Meta.BOARD_SIZE, "the board shows three")
	eq(Meta.bits(), 0, "Bits wait at the board")
	eq(Meta.claim("room"), 10, "claiming pays the ticket")
	eq(Meta.claim("room"), 0, "once")
	eq(Meta.bits(), 10, "into the bank")
	var sandbox := RunState.create(7)
	sandbox.sandbox = true
	sandbox.stats["kills"] = 500
	eq(Meta.check(sandbox).size(), 0, "the Workshop's sandbox never counts")


func test_the_starting_slot_upgrade() -> void:
	Meta.test_meta = {"meta_v": 2, "bounties": [], "packs": [], "unlocked": [], "runs": 3}
	ok(Meta.extra_slots() == 0, "no extra slot before its bounty")
	Meta.check(RunState.create(7))
	ok(Meta.extra_slots() == 1, "three runs played: one extra slot")
	var run := RunState.create(7)
	var n := run.wand().slots.size()
	run.set_loadout(&"apprentice")
	ok(run.wand().slots.size() == n + 1, "the start room's hero keeps the extra slot")


func test_heroes_start_different() -> void:
	var a := RunState.create(1, &"apprentice")
	eq(a.max_hp, RunState.BASE_HP + 20.0, "the Apprentice has 20 more max HP")
	var t := RunState.create(1, &"tinkerer")
	eq(t.wand().trig_mul, 0.7, "the Tinkerer's triggers cost less")
	eq(t.wand().slots.map(func(x: Variant) -> Variant: return x["id"] if x != null else null), [null, &"seed", &"burst"], "Carry and Rune Burst")
	var old := RunState.create(1, &"stub")
	eq(old.hero, &"pyromancer", "an old save's Stub start is the Pyromancer")


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
