extends "res://tests/unit/world_fixture.gd"
## Design v3: the Corrupted Grove's own enemies do their own thing.


func _one(kind: StringName, pos: Vector2) -> Enemy:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(120, 140)
	var e := world.spawn_enemy(kind, pos)
	e.spawn_t = 0.0
	e.sprite.visible = true
	return e


func test_the_blink_tick_blinks_next_to_you() -> void:
	var e := _one(&"blink_tick", Vector2(300, 140))
	var jumped := false
	for i in 300:
		var before := e.position
		world.step(DT)
		if e.dead:
			break
		if before.distance_to(e.position) > 20.0:
			jumped = true
			ok(e.position.distance_to(world.player.position) < 60.0, "it lands close to the player")
			break
	ok(jumped, "it blinked")


func test_the_bramble_ram_leaves_thorns() -> void:
	var e := _one(&"thorn_ram", Vector2(220, 140))
	var thorns := false
	for i in 400:
		world.step(DT)
		if world.ebullets.active.any(func(b: Bullet) -> bool: return b.alive and b.by.begins_with("thorns:")):
			thorns = true
			break
	ok(thorns, "its charge left thorns")


func test_the_grove_swaps_in_its_enemies() -> void:
	var r := RunState.create(5)
	r.step = Chapter.AREAS[1]["from"] + 1
	var rng := RandomNumberGenerator.new()
	var seen := {}
	for s in 30:
		rng.seed = s
		for w in Encounter.compose(r, &"fight", rng):
			for en in w:
				seen[en[0]] = true
	ok(seen.has(&"rot_weaver") or seen.has(&"blink_tick") or seen.has(&"thorn_ram"), "Grove fights hold Grove enemies (%s)" % [seen.keys()])
	r.step = 2
	seen.clear()
	for s in 30:
		rng.seed = s
		for w in Encounter.compose(r, &"fight", rng):
			for en in w:
				seen[en[0]] = true
	ok(not (seen.has(&"rot_weaver") or seen.has(&"blink_tick") or seen.has(&"thorn_ram")), "and the Cellar's do not")
