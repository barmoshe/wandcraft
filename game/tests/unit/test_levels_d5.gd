extends "res://tests/unit/world_fixture.gd"
## D5 (ADR 0016): every layout is sound, the room features work, and the 3-lane map follows
## its rules.


func _flood(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q: Array[Vector2i] = [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n) and world.walkable(n.x, n.y):
				seen[n] = true
				q.append(n)
	return seen


func test_every_layout_is_sound() -> void:
	for tpl in RoomLayouts.ART:
		world.build_room(tpl, &"empty")
		var start := Vector2i(floori(world.player.position.x / World.TS), floori(world.player.position.y / World.TS))
		ok(world.walkable(start.x, start.y), "%s: the player starts on floor" % tpl)
		var seen := _flood(start)
		for sp in world.sockets:
			ok(seen.has(Vector2i(floori(sp.x / World.TS), floori(sp.y / World.TS))), "%s: socket %s is reachable" % [tpl, sp])
		ok(world.sockets.size() >= 4, "%s: at least four sockets" % tpl)
		for d in world.doors:
			ok(seen.has(Vector2i(int(d["col"]), 1)), "%s: the door at column %d is reachable" % [tpl, d["col"]])
		if world.treasure != Vector2.INF:
			ok(not seen.has(Vector2i(floori(world.treasure.x / World.TS), floori(world.treasure.y / World.TS))), "%s: the secret stays walled off" % tpl)


func test_layout_pools_grow_with_the_run() -> void:
	for tpl in RoomLayouts.pool(1):
		eq(RoomLayouts.ART[tpl]["size"], "S", "the first rooms are small")
	ok(RoomLayouts.pool(7).any(func(t: String) -> bool: return RoomLayouts.ART[t]["size"] == "L"), "late rooms can be large")


func _find(tpl: String, tile: int) -> Vector2i:
	world.build_room(tpl, &"empty")
	for y in world.gh:
		for x in world.gw:
			if world.tile_at(x, y) == tile:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func test_spore_pods_chain_and_hurt() -> void:
	var c := _find("s_yard", 8)
	var e := _dummy(Vector2(c.x * World.TS + 8, c.y * World.TS + 30))
	world.hash.rebuild(world.enemies)
	world.pop_pod(c.x, c.y)
	eq(world.tile_at(c.x, c.y), 0, "the pod is gone")
	eq(world.tile_at(c.x + 1, c.y), 0, "and set off its neighbour")
	ok(e.hp < e.max_hp, "the blast hurt an enemy nearby")


func test_brambles_burn_only_with_fire() -> void:
	var c := _find("s_thorns", 6)
	world.tile_hit(c.x, c.y, false)
	eq(world.tile_at(c.x, c.y), 6, "a plain hit does nothing")
	world.tile_hit(c.x, c.y, true)
	eq(world.tile_at(c.x, c.y), 0, "fire clears it")


func test_pylon_pulse_stuns_and_strips_wards() -> void:
	var c := _find("s_pylon", 9)
	var e := _dummy(Vector2(c.x * World.TS + 30, c.y * World.TS + 8))
	e.ward_n = 3
	world.hash.rebuild(world.enemies)
	world.tile_hit(c.x, c.y, false)
	ok(e.stun_t > 0.0, "stunned")
	eq(e.ward_n, 0, "ward stripped")
	e.stun_t = 0.0
	world.tile_hit(c.x, c.y, false)
	eq(e.stun_t, 0.0, "and the pylon needs a moment before the next pulse")


func test_knockback_into_a_pit_kills_fodder() -> void:
	var c := _find("s_well", 5)
	# a still target over the middle of the pit's top edge, knocked straight in
	var e := _dummy(Vector2((c.x + 1) * World.TS + 8, c.y * World.TS - 10))
	e.knock = Vector2(0, 400)
	for i in 30:
		world.step(DT)
		if e.dead:
			break
	ok(e.dead, "knocked into the pit, it fell")
	var g := _dummy(Vector2((c.x + 1) * World.TS + 8, c.y * World.TS - 10))
	g.heavy = true
	g.knock = Vector2(0, 400)
	_steps(0.5)
	ok(not g.dead, "a heavy enemy never falls")


func test_a_blast_opens_the_secret() -> void:
	var c := _find("s_cache", 7)
	ok(world.treasure != Vector2.INF, "a chest waits behind the wall")
	world.break_crates_in(Vector2(c.x * World.TS + 8, c.y * World.TS + 8), 20.0)
	ok(world.secret_open, "the cracked wall broke")
	eq(world.tile_at(c.x, c.y), 0, "and is open floor now")


func test_the_map_follows_its_rules() -> void:
	for seed_value in [3, 17, 29, 41, 58]:
		var r := RunState.create(seed_value)
		var m := Chapter.make_map(r)
		eq(m.size(), Chapter.PLAN.size(), "one column per step")
		for step in m.size():
			var nodes: Array = m[step]
			if Chapter.PLAN[step] == &"room":
				eq(nodes.size(), 3, "three lanes on a room step")
				ok(nodes.any(func(n: Dictionary) -> bool: return not Chapter.is_quiet(n["kind"])), "a fight somewhere on every step")
			if step <= 2 and Chapter.PLAN[step] == &"room":
				ok(nodes.all(func(n: Dictionary) -> bool: return n["kind"] == &"fight"), "the first two rooms are fights")
			if step < 3:
				ok(not nodes.any(func(n: Dictionary) -> bool: return n["kind"] in [&"challenge", &"glitch", &"altar", &"terminal"]), "nothing special before the fourth room")
			if step + 1 < m.size() and Chapter.PLAN[step + 1] in [&"mini", &"boss"]:
				ok(nodes[1]["kind"] in [&"spring", &"shop"], "a spring or shop in the middle before a boss")


func test_doors_follow_lanes() -> void:
	var r := RunState.create(5)
	r.step = 1
	r.lane = 0
	r.map = Chapter.make_map(r)
	var d := Chapter.door_options(r)
	eq(d.size(), 2, "from the edge lane, two doors")
	r.lane = 1
	eq(Chapter.door_options(r).size(), 3, "from the middle, three")
	var back := RunState.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	eq(back.map.size(), r.map.size(), "the map survives a save")
	eq(back.lane, 1, "and the lane")


func test_the_altar_costs_max_hp() -> void:
	var r := RunState.create(5)
	var offer := Rewards.offer(r, &"altar")
	ok(offer.all(func(it: Dictionary) -> bool: return it.has("hp_cost")), "every altar gift has a price")
	var mhp := r.max_hp
	Rewards.grant(r, offer[0])
	eq(r.max_hp, roundf(mhp * 0.85), "15% of max HP")
