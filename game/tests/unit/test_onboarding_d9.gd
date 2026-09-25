extends "res://tests/unit/test_helpers.gd"
## D9: the first run's curriculum (Tutorial). A new player plays it: the bot fights, takes
## each lesson prize and does exactly what the editor's coach says (and nothing more). The
## design-plan §6 bar: the first wand edit by 120 s of play, the first trigger by 180 s.

const DT := 1.0 / 60.0


func _new_player_run(seed_value: int) -> Dictionary:
	SaveGame.enabled = false
	Game.god_mode = true
	Game.auto_fire = true
	var world := World.new()
	world.auto_step = false
	runner.root.add_child(world)
	world.setup(seed_value)
	world.bot = true
	var run := RunState.create(seed_value)
	run.tutorial = true
	var seen := {"titles": [], "offers": [], "mini": false}
	world.room_built.connect(func() -> void:
		seen["titles"].append(world._room_title(world.room_kind))
		if world.room_kind == &"mini":
			seen["mini"] = true)
	world.ui_request.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"reward":
			var lesson := world.run.step
			if data["offer"].size() > 0:
				seen["offers"].append(data["offer"].map(func(o: Dictionary) -> StringName: return o["id"]))
				Rewards.grant(world.run, data["offer"][0])
			world.reward_taken()
			# follow the coach, move by move, like a player reading it
			Tutorial.on_prize(world.run, lesson)
			for guard in 4:
				var c := Tutorial.coach(world.run, lesson)
				if c.is_empty():
					break
				world.run.move_spell(c["from"], c["to"])
		elif kind == &"shop" or kind == &"forge":
			world.ui_done())
	world.start_run(run)
	var t := 0.0
	# play on into the mini-boss until the new wand's trigger fires (or give up at 400 s)
	while t < 400.0 and (not seen["mini"] or float(run.stats["first_trigger"]) < 0.0):
		world.step(DT)
		t += DT
	if not seen["mini"]:
		print("    STALL in ", world.room_kind, " cleared=", world.cleared, " wave ", world.wave_i, "/", world.waves.size(), " alive=", world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).map(func(e: Enemy) -> String: return "%s hp%.0f sh%d" % [e.kind, e.hp, e.shield_hp]), " orb=", world.orb, " doors_open=", world.doors_open, " wand=", run.wand().slots)
	var out := {"first_edit": float(run.stats["first_edit"]), "first_trigger": float(run.stats["first_trigger"]),
		"titles": seen["titles"], "offers": seen["offers"], "wand": run.wand().slots.duplicate(true), "reached_mini": seen["mini"]}
	world.free()
	SaveGame.enabled = true
	Game.god_mode = false
	return out


func test_the_curriculum_teaches_an_edit_by_120s_and_a_trigger_by_180s() -> void:
	for seed_value in [5, 17, 29]:
		var r := _new_player_run(seed_value)
		print("    onboarding seed %d: first edit %.0f s, first trigger %.0f s, rooms %s" % [seed_value, r["first_edit"], r["first_trigger"], r["titles"]])
		ok(r["reached_mini"], "seed %d: the lessons lead to the mini-boss" % seed_value)
		ok(r["first_edit"] >= 0.0 and r["first_edit"] <= 120.0, "seed %d: first wand edit by 120 s (%.0f)" % [seed_value, r["first_edit"]])
		ok(r["first_trigger"] >= 0.0 and r["first_trigger"] <= 180.0, "seed %d: first trigger by 180 s (%.0f)" % [seed_value, r["first_trigger"]])
		# offers[0] is the start room's loadout pick, then one prize per lesson
		ok(r["offers"].size() >= 4 and r["offers"][1] == [&"empower"], "seed %d: the first lesson's prize is Empower" % seed_value)
		ok(r["offers"].size() >= 4 and r["offers"][3].has(&"then"), "seed %d: the third lesson's prize is a trigger" % seed_value)


func test_the_trigger_lesson_ends_with_a_spell_after_the_trigger() -> void:
	var run := RunState.create(3)
	run.tutorial = true
	run.wands[0].set_slots([&"empower", &"mote", &"needle"])
	run.bag.append({"id": &"then", "lv": 1})
	Tutorial.on_prize(run, 3)
	ok(run.wand().slots.size() == 4, "the trigger prize grows the wand a slot")
	for guard in 4:
		var c := Tutorial.coach(run, 3)
		if c.is_empty():
			break
		run.move_spell(c["from"], c["to"])
	var ids: Array = run.wand().slots.map(func(s: Variant) -> Variant: return s["id"] if s != null else null)
	var p := ids.find(&"then")
	ok(p >= 1 and Catalog.is_caster(Catalog.spell(ids[p - 1])), "the trigger has a shooting spell on its left (%s)" % [ids])
	ok(p >= 0 and p + 1 < ids.size() and ids[p + 1] != null and Catalog.is_caster(Catalog.spell(ids[p + 1])), "the trigger has a spell right after it (%s)" % [ids])
	ok(ids[0] == &"empower", "the boost still leads (%s)" % [ids])


func test_the_boost_lesson_puts_empower_before_the_mote() -> void:
	var run := RunState.create(3)
	run.tutorial = true
	run.step = 1
	run.bag.append({"id": &"empower", "lv": 1})
	Tutorial.on_prize(run, 1)
	for guard in 4:
		var c := Tutorial.coach(run, 1)
		if c.is_empty():
			break
		run.move_spell(c["from"], c["to"])
	var ids: Array = run.wand().slots.map(func(s: Variant) -> Variant: return s["id"] if s != null else null)
	ok(ids[0] == &"empower" and ids[1] == &"mote", "Empower sits left of the Mote it powers (%s)" % [ids])


func test_a_normal_run_is_not_a_lesson() -> void:
	var run := RunState.create(3)
	run.step = 1
	ok(not Tutorial.active(run), "runs are not tutorials unless marked")
	ok(Rewards.offer(run, &"spell").size() == 3, "a normal spell reward is a choice of three")
