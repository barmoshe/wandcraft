extends "res://tests/unit/test_helpers.gd"
## D9: the first run's curriculum (Tutorial). A new player plays it: the bot fights, takes
## each lesson prize and does exactly what the editor's coach says (and nothing more). The
## design-plan §6 bar: the first wand edit by 120 s of play. 0.20: the third lesson hands over
## a second shooting spell, not a trigger (triggers are a pack now), so the wand reaching the
## mini-boss fires two spells in turn.

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
	# play on until the mini-boss (or give up at 400 s)
	while t < 400.0 and not seen["mini"]:
		world.step(DT)
		t += DT
	if not seen["mini"]:
		print("    STALL in ", world.room_kind, " cleared=", world.cleared, " wave ", world.wave_i, "/", world.waves.size(), " alive=", world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).map(func(e: Enemy) -> String: return "%s hp%.0f sh%d" % [e.kind, e.hp, e.shield_hp]), " orb=", world.orb, " doors_open=", world.doors_open, " wand=", run.wand().slots)
	var out := {"first_edit": float(run.stats["first_edit"]),
		"titles": seen["titles"], "offers": seen["offers"], "wand": run.wand().slots.duplicate(true), "reached_mini": seen["mini"]}
	world.free()
	SaveGame.enabled = true
	Game.god_mode = false
	return out


func test_the_curriculum_teaches_an_edit_by_120s_and_a_second_spell() -> void:
	for seed_value in [5, 17, 29]:
		var r := _new_player_run(seed_value)
		print("    onboarding seed %d: first edit %.0f s, rooms %s, wand %s" % [seed_value, r["first_edit"], r["titles"], r["wand"]])
		ok(r["reached_mini"], "seed %d: the lessons lead to the mini-boss" % seed_value)
		ok(r["first_edit"] >= 0.0 and r["first_edit"] <= 120.0, "seed %d: first wand edit by 120 s (%.0f)" % [seed_value, r["first_edit"]])
		# offers[0] is the start room's loadout pick, then one prize per lesson
		ok(r["offers"].size() >= 4 and r["offers"][1] == [&"empower"], "seed %d: the first lesson's prize is Empower" % seed_value)
		ok(r["offers"].size() >= 4 and r["offers"][3].has(&"frost"), "seed %d: the third lesson's prize is a second spell" % seed_value)
		ok(r["offers"].all(func(o: Array) -> bool: return not o.any(func(id: StringName) -> bool: return Catalog.spell(id) != null and Catalog.spell(id).kind == SpellDef.Kind.TRIG)),
			"seed %d: no trigger in the lessons" % seed_value)
		var casters: Array = r["wand"].filter(func(sp: Variant) -> bool: return sp != null and Catalog.is_caster(Catalog.spell(sp["id"])))
		ok(casters.size() >= 2, "seed %d: the wand fires two spells in turn (%s)" % [seed_value, r["wand"]])


## 0.20 (Bar: "fix all lessons"): every path through the three lessons, with and without the
## extra starting slot. The coach must finish in a few moves, never bump a spell into the bag
## when an empty slot is waiting, end with every boost left of a shooting spell and the bag
## empty, and hand over a wand whose mana keeps up (lessons 1 and 2; lesson 3 is the mana
## lesson and may run dry, but not in under 10 s of casting).
func test_every_lesson_path_coaches_cleanly() -> void:
	for extra in [false, true]:
		for p2 in Tutorial.STEPS[2]["offer"]:
			for p3 in Tutorial.STEPS[3]["offer"]:
				var run := RunState.create(5)
				run.tutorial = true
				if extra:
					run.wand().add_slot()
				for lesson in [1, 2, 3]:
					var prize: StringName = [&"empower", p2, p3][lesson - 1]
					var tag := "extra=%s %s/%s lesson %d" % [extra, p2, p3, lesson]
					run.step = lesson
					run.bag.append({"id": prize, "lv": 1})
					Tutorial.on_prize(run, lesson)
					var moves := 0
					for guard in 8:
						var c := Tutorial.coach(run, lesson)
						if c.is_empty():
							break
						var to_i: int = c["to"]["i"]
						var empty_waiting := range(run.wand().slots.size()).any(func(i: int) -> bool:
							return run.wand().slots[i] == null and run.lesson_target[i] != null)
						ok(run.wand().slots[to_i] == null or not empty_waiting, "%s: a move lands on a spell while an empty slot waits" % tag)
						ok(String(c["text"]).contains("lit slot"), "%s: the coach says where" % tag)
						run.move_spell(c["from"], c["to"])
						moves += 1
					ok(moves >= 1 and moves <= 3, "%s: %d moves" % [tag, moves])
					ok(Tutorial.coach(run, lesson).is_empty(), "%s: the coach finishes" % tag)
					ok(run.bag.is_empty(), "%s: nothing left in the bag" % tag)
					var ids: Array = run.wand().slots.map(func(sp: Variant) -> Variant: return sp["id"] if sp != null else null)
					ok(ids.has(prize), "%s: the prize is on the wand (%s)" % [tag, ids])
					eq(ids[-1], &"mote", "%s: the Mote keeps the last slot" % tag)
					var last_boost := -1
					var first_cast := -1
					for i in ids.size():
						if ids[i] == null:
							continue
						if Catalog.is_caster(Catalog.spell(ids[i])):
							if first_cast < 0:
								first_cast = i
						else:
							last_boost = i
					ok(last_boost < first_cast, "%s: every boost is left of the spells it powers (%s)" % [tag, ids])
					var dry := _dry_after(run.wand())
					if lesson < 3:
						ok(dry < 0.0, "%s: the wand's mana keeps up (%s)" % [tag, ids])
					else:
						ok(dry < 0.0 or dry >= 10.0, "%s: runs dry after %.0f s (%s)" % [tag, dry, ids])


## Seconds of steady casting before the wand runs dry, or -1 if it never does.
func _dry_after(w: WandState) -> float:
	var cost := 0.0
	var t := 0.0
	for plan in WandProgram.preview_cycle(w):
		cost += plan.mana
		t += maxf(0.03, w.def.cast_delay + plan.delay_add)
		if plan.wrapped:
			t += maxf(0.03, w.recharge_time() + plan.recharge_add)
	var regen := w.def.regen * w.regen_mul() * t
	return -1.0 if regen >= cost else w.max_mana() / ((cost - regen) / t)


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
	ok(ids.find(&"empower") == ids.find(&"mote") - 1, "Empower sits just left of the Mote it powers (%s)" % [ids])
	eq(ids[-1], &"mote", "the Mote stays in the last slot")


func test_a_normal_run_is_not_a_lesson() -> void:
	var run := RunState.create(3)
	run.step = 1
	ok(not Tutorial.active(run), "runs are not tutorials unless marked")
	ok(Rewards.offer(run, &"spell").size() == 3, "a normal spell reward is a choice of three")
