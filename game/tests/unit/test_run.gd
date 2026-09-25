extends "res://tests/unit/test_helpers.gd"
## Run state, chapter map, rewards, relics and saves (pure data, no world).


func setup(_tree: SceneTree) -> void:
	SaveGame.enabled = false


func teardown() -> void:
	SaveGame.enabled = true


func test_new_run_starts_with_one_wand_and_a_mote() -> void:
	var r := RunState.create(5)
	eq(r.wands.size(), 1, "one wand")
	eq(String(r.wand().slots[-1]["id"]), "mote", "an Arcane Mote in the last slot (as in Magicraft)")
	ok(r.wand().slots[0] == null and r.wand().slots[1] == null, "empty slots on its left, for boosts")
	eq(r.step, 0, "at the start room")


func test_new_spells_go_to_the_bag_unless_the_wand_cannot_cast() -> void:
	# D2: placing a spell is the player's decision, so rewards land in the bag
	var r := RunState.create(5)
	ok(r.add_spell(&"fan"), "added")
	ok(r.wand().slots[0] == null and r.wand().slots[1] == null, "not slotted by itself")
	eq(r.bag.size(), 1, "into the bag")
	# a wand with nothing to shoot takes a shooting spell straight away (onboarding)
	r.wand().set_slots([null, null, null])
	ok(r.add_spell(&"empower"), "added")
	ok(r.wand().slots[2] == null, "a boost alone does not go in")
	ok(r.add_spell(&"moths"), "added")
	eq(String(r.wand().slots[2]["id"]), "moths", "but a shooting spell does, in the last slot")


func test_two_copies_merge_into_the_next_level() -> void:
	var r := RunState.create(5)
	r.wand().slots[1] = {"id": &"fan", "lv": 1}
	r.add_spell(&"fan")
	var fans := r.spell_refs().filter(func(x: Dictionary) -> bool: return x["s"]["id"] == &"fan")
	eq(fans.size(), 1, "two fans became one")
	eq(int(fans[0]["s"]["lv"]), 2, "at level 2")
	eq(fans[0]["w"], 0, "and it is the one in the wand")
	# two level-2 copies make level 3 (four copies in all)
	r.bag.append({"id": &"fan", "lv": 1})
	r.add_spell(&"fan")
	fans = r.spell_refs().filter(func(x: Dictionary) -> bool: return x["s"]["id"] == &"fan")
	eq(fans.size(), 1, "one fan left")
	eq(int(fans[0]["s"]["lv"]), 3, "at level 3")


func test_start_offers_the_two_loadouts() -> void:
	var r := RunState.create(5)
	var offer := Rewards.offer(r, &"start")
	eq(offer.size(), 2, "two starting wands")
	ok(Rewards.grant(r, offer[1]), "taken")
	eq(String(r.wand().def.id), "stub", "the Stub Staff")
	eq(r.wand().slots.size(), 2, "two slots")
	eq(String(r.wand().slots[1]["id"]), "ember", "with an Ember Bolt in the last slot")


func test_rarity_offset_and_deprecate() -> void:
	var r := RunState.create(11)
	r.banned.append(&"fan")
	var epics := 0
	for k in 300:
		var id := Rewards.roll_spell(r)
		ok(id != &"fan", "a deprecated spell never comes back")
		if Catalog.spell(id).rarity == 2:
			epics += 1
		ok(r.rare_offset <= 0.40, "the offset is capped")
	ok(epics > 0, "epics show up (%d in 300)" % epics)


func test_forge_adds_a_slot() -> void:
	var r := RunState.create(5)
	var n := r.wand().slots.size()
	ok(Rewards.grant(r, {"t": &"slot", "id": &"slot"}), "granted")
	eq(r.wand().slots.size(), n + 1, "one more slot")
	var r2 := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	eq(r2.wand().slots.size(), n + 1, "and it survives a save")


func test_move_and_swap_spells() -> void:
	var r := RunState.create(5)
	r.wand().set_slots([&"mote", &"fan", null, null])
	r.move_spell({"w": 0, "i": 0}, {"w": 0, "i": 1})
	eq(String(r.wand().slots[0]["id"]), "fan", "swapped left")
	eq(String(r.wand().slots[1]["id"]), "mote", "swapped right")
	r.move_spell({"w": 0, "i": 1}, {"w": -1, "i": 0})
	eq(r.bag.size(), 1, "moved into the bag")
	ok(r.wand().slots[1] == null, "slot emptied")
	r.move_spell({"w": -1, "i": 0}, {"w": 0, "i": 3})
	eq(r.bag.size(), 0, "moved back out")
	eq(String(r.wand().slots[3]["id"]), "mote", "into slot 4")


func test_chapter_doors() -> void:
	var r := RunState.create(9)
	for step in Chapter.PLAN.size():
		r.step = step
		var doors := Chapter.door_options(r)
		ok(doors.size() >= 1 and doors.size() <= 3, "step %d offers 1-3 doors" % step)
		var nxt := step + 1
		if nxt >= Chapter.PLAN.size():
			eq(doors[0]["kind"], &"exit", "after the boss: the exit")
		elif Chapter.PLAN[nxt] == &"mini" or Chapter.PLAN[nxt] == &"boss":
			eq(doors.size(), 1, "the boss door is the only door")
		else:
			ok(doors.any(func(d: Dictionary) -> bool: return d["kind"] == &"fight" or d["kind"] == &"challenge"), "step %d has a fight" % step)
			if nxt == 1:
				ok(doors.all(func(d: Dictionary) -> bool: return d["kind"] == &"fight"), "the first room is a fight")
			if Chapter.PLAN[nxt + 1] == &"mini" or Chapter.PLAN[nxt + 1] == &"boss":
				ok(doors.any(func(d: Dictionary) -> bool: return d["kind"] == &"spring" or d["kind"] == &"shop"), "before a boss: spring or shop")


func test_rewards_are_three_distinct_valid_choices() -> void:
	var r := RunState.create(11)
	for kind in [&"start", &"spell", &"relic", &"challenge", &"wand", &"mini", &"boss"]:
		for k in 20:
			var offer := Rewards.offer(r, kind)
			ok(offer.size() >= 2 and offer.size() <= 3, "%s offers 2-3 (%d)" % [kind, offer.size()])
			var ids := offer.map(func(o: Dictionary) -> String: return "%s:%s" % [o["t"], o["id"]])
			var uniq := {}
			for id in ids:
				uniq[id] = true
			eq(uniq.size(), ids.size(), "%s: no duplicates %s" % [kind, ids])
			for o in offer:
				ok(Rewards.item_title(o) != "" and Rewards.item_desc(o) != "", "%s has text" % o["id"])


func test_every_spell_and_relic_has_text_and_an_icon() -> void:
	for id in Catalog.spells():
		var d := Catalog.spell(id)
		ok(d.title != "" and d.desc != "", "%s text" % id)
		ok(not IconArt.spell(id).is_empty(), "%s has an illustrated icon" % id)
	for id in Relics.DEFS:
		ok(not IconArt.relic(id).is_empty(), "%s has an illustrated icon" % id)


func test_relics_that_act_on_pickup() -> void:
	var r := RunState.create(3)
	r.hp = 50.0
	r.add_relic(&"hot_patch")
	eq(r.max_hp, 140.0, "Hot Patch: max HP +20")
	eq(r.hp, 70.0, "and heals 20")
	var n := r.wand().slots.size()
	r.add_relic(&"off_by_one")
	eq(r.wand().slots.size(), n + 1, "Off-by-One: one more slot")
	r.add_wand(&"oak")
	eq(r.wands[1].slots.size(), Catalog.wand(&"oak").slots + 1, "and on wands found later")
	ok(Relics.dmg_mul(r, 0.0) == 1.0, "no damage relic yet")
	r.add_relic(&"heap_overflow")
	ok(is_equal_approx(Relics.dmg_mul(r, 10.0), 1.3), "Heap Overflow: +30% damage")
	eq(r.max_hp, 120.0, "and max HP -20")


func test_wands_are_capped_and_replacing_keeps_spells() -> void:
	var r := RunState.create(3)
	r.add_wand(&"birch")
	r.add_wand(&"oak")
	eq(r.wands.size(), 3, "three wands")
	eq(r.cur, 0, "new wands do not take the hand")
	r.wands[1].set_slots([&"fan", &"moths"])
	r.add_wand(&"crystal")
	eq(r.wands.size(), 3, "still three")
	eq(r.wands[2].def.id, &"crystal", "the emptiest wand (the oak) was replaced")
	eq(r.wand().def.id, &"twig", "the wand in hand is untouched")
	eq(r.bag.size(), 0, "nothing lost")
	r.wands[2].set_slots([&"then"])
	r.add_wand(&"birch")
	eq(r.wands[2].def.id, &"birch", "again the emptiest one")
	eq(r.bag.size(), 1, "its spell went to the bag")


func test_save_round_trip() -> void:
	var r := RunState.create(77)
	r.step = 3
	r.path = [&"spell", &"relic", &"shop"]
	r.room = {"kind": &"fight", "reward": &"gold"}
	r.doors = Chapter.door_options(r)
	r.gold = 55
	r.hp = 61.0
	r.add_relic(&"cold_boot")
	r.uptime = 4
	r.add_wand(&"birch")
	r.wand().set_slots([&"then", {"id": &"fan", "lv": 2}])
	r.bag = [{"id": &"seek", "lv": 1}]
	r.shop = Rewards.shop_stock(r)
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	var q := RunState.from_dict(d)
	ok(q != null, "loaded")
	eq(q.step, 3, "step")
	eq(q.path, r.path, "path")
	eq(q.room["kind"], &"fight", "room kind")
	eq(q.doors.size(), r.doors.size(), "doors")
	eq(q.gold, 55, "gold")
	eq(q.hp, 61.0, "hp")
	eq(q.relics, r.relics, "relics")
	eq(q.uptime, 4, "uptime")
	eq(q.wands.size(), 2, "wands")
	eq(q.cur, r.cur, "wand in hand")
	eq(int(q.wand().slots[1]["lv"]), 2, "spell levels")
	eq(q.bag[0]["id"], &"seek", "bag")
	eq(q.shop.size(), r.shop.size(), "shop stock")
	eq(q.rng.state, r.rng.state, "the dice continue where they were")
	ok(RunState.from_dict({"v": 999}) == null, "unknown versions are refused")
