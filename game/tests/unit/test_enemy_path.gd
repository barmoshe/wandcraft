extends "res://tests/unit/world_fixture.gd"
## Enemies find their way around cover and only shoot what they can see (decisions/0008).
## Before 0.4.1 they walked in a straight line and parked behind the first pillar.


func _tile(x: int, y: int) -> Vector2:
	return Vector2(x * World.TS + World.TS / 2.0, y * World.TS + World.TS / 2.0)


func _enemy(kind: StringName, pos: Vector2) -> Enemy:
	var e := world.spawn_enemy(kind, pos)
	e.spawn_t = 0.0
	e.sprite.visible = true
	e.max_hp = 99999.0
	e.hp = e.max_hp
	return e


## Steps until the enemy touches the player; returns the seconds it took (or -1).
func _reach(e: Enemy, limit: float) -> float:
	var t := 0.0
	while t < limit:
		world.step(DT)
		t += DT
		if e.position.distance_to(world.player.position) < e.r + world.player.r + 4.0:
			return t
	return -1.0


func _case(tpl: String, kind: StringName, from: Vector2i, to: Vector2i, limit: float, what: String) -> void:
	world.build_room(tpl, &"empty")
	world.player.position = _tile(to.x, to.y)
	world.player.reset_physics_interpolation()
	var e := _enemy(kind, _tile(from.x, from.y))
	ok(not world.clear_path(e.position, world.player.position, e.r), "%s: the straight line is blocked" % what)
	var t := _reach(e, limit)
	ok(t >= 0.0, "%s: reaches the player (%s)" % [what, ("%.1f s" % t) if t >= 0.0 else "stuck at %s" % e.position])


func test_chasers_walk_around_cover() -> void:
	_case("pillars", &"slime", Vector2i(8, 2), Vector2i(8, 4), 5.0, "slime behind a pillar")
	_case("split", &"slime", Vector2i(14, 2), Vector2i(20, 2), 12.0, "slime across the split wall")
	_case("donut", &"bugling", Vector2i(12, 2), Vector2i(11, 5), 14.0, "bugling into the donut ring")
	_case("pillars", &"ram", Vector2i(3, 2), Vector2i(3, 8), 12.0, "ram past a pillar column")


func test_shooters_need_a_clear_line() -> void:
	# a weaver outside the donut ring cannot see the player inside it: no shots
	world.build_room("donut", &"empty")
	world.player.position = _tile(11, 5)
	var w := _enemy(&"weaver", _tile(12, 2))
	w.cd = 0.0
	var fired := 0
	for i in int(1.0 / DT):
		world.step(DT)
		fired = maxi(fired, world.ebullets.live_count())
	eq(fired, 0, "a weaver behind a wall holds its fire")
	# in the open it shoots
	world.build_room("hall", &"empty")
	world.player.position = _tile(8, 7)
	w = _enemy(&"weaver", _tile(14, 7))
	w.cd = 0.0
	fired = 0
	for i in int(0.5 / DT):
		world.step(DT)
		fired = maxi(fired, world.ebullets.live_count())
	ok(fired > 0, "a weaver with a clear line shoots")
	# a turret behind a pillar holds its fire too
	world.build_room("pillars", &"empty")
	world.player.position = _tile(8, 4)
	var s := _enemy(&"sentry", _tile(8, 2))
	s.cd = 0.0
	fired = 0
	for i in int(1.0 / DT):
		world.step(DT)
		fired = maxi(fired, world.ebullets.live_count())
	eq(fired, 0, "a sentry behind a pillar holds its fire")


func test_waves_spawn_clear_of_walls() -> void:
	var bad := []
	for tpl in World.FIGHT_ROOMS:
		for k in 6:
			world.build_room(tpl, &"empty")
			world.player.position = _tile(2, 2)
			world.call("_spawn_wave", [[&"slime", false], [&"weaver", false], [&"ram", false], [&"bugling", false], [&"puffcap", false], [&"sentry", false]])
			for e in world.enemies:
				if not world.body_fits(e.position, e.r):
					bad.append("%s %s at %s" % [tpl, e.kind, e.position])
	eq(bad, [], "every spawned enemy fits clear of walls")
