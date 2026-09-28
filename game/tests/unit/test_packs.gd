extends "res://tests/unit/test_helpers.gd"
## Meta v2 (research/workshop-0.19.md): Bits, the merchant's packs, the migration from
## design v2's goals, and the Compendium's record.


func teardown() -> void:
	Meta.test_meta = null


func _fresh(extra := {}) -> void:
	var m := {"meta_v": 2, "bounties": [], "packs": [], "unlocked": [], "runs": 0, "bits": 0}
	m.merge(extra, true)
	Meta.test_meta = m


func test_a_run_pays_bits() -> void:
	var r := RunState.create(3)
	r.stats["rooms"] = 6
	eq(Meta.bits_for(r, 0), 6 * Meta.BITS_ROOM + Meta.BITS_EARLY, "rooms, plus the early-run bonus")
	eq(Meta.bits_for(r, 5), 6 * Meta.BITS_ROOM, "no bonus after the first runs")
	r.stats["bosses"] = 2
	r.world = 1
	r.won = true
	var base := 6 * Meta.BITS_ROOM + 2 * Meta.BITS_BOSS + Meta.BITS_LOOP + Meta.BITS_WIN
	eq(Meta.bits_for(r, 9), base, "bosses, the Loop and a win")
	r.heat = 3
	eq(Meta.bits_for(r, 9), roundi(base * 1.3), "heat pays 10% a tier")
	r.sandbox = true
	eq(Meta.bits_for(r, 0), 0, "the Workshop's sandbox pays nothing")


func test_packs_stay_locked_until_bought() -> void:
	_fresh({"bits": 70})
	var run := RunState.create(11)
	var glitch: Array = Meta.pack("glitch")["items"]
	for i in 500:
		ok(not glitch.has(Rewards.roll_spell(run)), "no Glitch pack spell before buying")
		if glitch.has(Rewards.roll_spell(run)):
			break
	eq(Meta.shelf().size(), Meta.SHELF, "the merchant shelves three")
	eq(Meta.shelf()[0]["id"], "triggers", "cheapest first: 0.20's Triggers pack")
	ok(not Meta.CORE_SPELLS.has(&"then"), "triggers are not in the core pool (0.20)")
	ok(not Meta.shelf().any(func(p: Dictionary) -> bool: return p["id"] == "debugger"), "the Debugger waits on the Loop")
	ok(not Meta.buy_pack("net"), "120 Bits is too much for 70")
	ok(Meta.buy_pack("glitch"), "60 is fine")
	eq(Meta.bits(), 10, "it spent them")
	ok(not Meta.buy_pack("glitch"), "a pack is bought once")
	for id in glitch:
		ok(not Meta.is_locked(id), "%s opens with the pack" % id)
	eq(Meta.source_text(&"traceroute"), "PACK: NETWORKING", "a locked item says where it comes from")


func test_bounty_needs_hide_tickets() -> void:
	_fresh({"bounties": ["room", "clean", "runs1", "mini", "triggers", "runs3", "big_hit", "rich", "kills", "elites", "thermal"]})
	ok(not Meta.open_bounties().any(func(b: Dictionary) -> bool: return b["id"] == "crash"), "the Bitrot ticket waits on the Glitch pack")
	Meta.test_meta["packs"] = ["glitch"]
	eq(Meta.open_bounties()[0]["id"], "crash", "then it shows")


func test_migration_keeps_every_unlock() -> void:
	Meta.test_meta = {"goals": ["room", "compile", "big_hit", "runs2", "win"], "unlocked": ["include"], "runs": 4}
	var m := Meta.migrate(Meta.test_meta)
	eq(int(m["meta_v"]), 3, "migrated")
	ok(not m.has("goals"), "goals are gone")
	for id in [&"chorus", &"hexcursor", &"rot_index", &"watchdog", &"birch", &"tinkerer", &"fork", &"include"]:
		ok(not Meta.is_locked(id), "%s stays open" % id)
	ok((m["bounties"] as Array).has("room") and (m["bounties"] as Array).has("world1"), "goals with a bounty count as fixed (a win counts as the Loop)")
	ok((m["packs"] as Array).has("glitch"), "a legacy pack whose items were all open is owned")
	var paid := int(Meta.bounty("room")["bits"]) + int(Meta.bounty("compile")["bits"]) + int(Meta.bounty("big_hit")["bits"]) + int(Meta.bounty("win")["bits"]) + int(Meta.bounty("world1")["bits"])
	eq(int(m["bits"]), paid, "their Bits are paid as back pay")
	eq(Meta.unclaimed().size(), 0, "nothing waits at the board after back pay")
	var again := Meta.migrate(m.duplicate(true))
	eq(int(again["bits"]), paid, "migrating twice changes nothing")
	ok(Meta.pack_price("flow") < int(Meta.pack("flow")["price"]), "a half-open legacy pack costs less")


func test_the_compendium_records_a_run() -> void:
	_fresh()
	var run := RunState.create(5)
	Rewards.offer(run, &"relic")
	run.add_spell(&"needle")
	run.see_enemy(&"slime")
	run.see_enemy(&"slime", true)
	run.see_enemy(&"slime", true)
	Meta.fold_dex(run)
	var d := Meta.dex()
	eq(int(d["s"]["needle"]), 2, "a spell taken is used")
	ok((d["r"] as Dictionary).size() >= 1, "relics offered are seen")
	eq(int(d["e"]["slime"]), 2, "kills add up")
	eq(run.dex, {}, "the run's buffer is folded")
	var sb := RunState.create(5)
	sb.sandbox = true
	sb.add_spell(&"lance")
	Meta.fold_dex(sb)
	ok(not (Meta.dex()["s"] as Dictionary).has("lance"), "the Workshop's sandbox records nothing")
