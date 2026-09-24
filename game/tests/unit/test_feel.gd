extends "res://tests/unit/test_helpers.gd"
## v0.3 feel pass: audio assets, first-run tips, aim-ahead, crates.

const DT := 1.0 / 60.0
var world: World


func setup(tree: SceneTree) -> void:
	SaveGame.enabled = false
	Game.god_mode = true
	Game.auto_fire = false
	world = World.new()
	world.auto_step = false
	tree.root.add_child(world)
	world.setup(5)
	world.start_run(RunState.create(5))


func teardown() -> void:
	SaveGame.enabled = true
	Game.god_mode = false
	Game.auto_fire = true
	world.free()


func test_every_sound_the_game_asks_for_exists() -> void:
	var names: Array = ["hit", "crit", "kill", "boom", "bigboom", "hurt", "eshot", "tele", "phase", "spawn", "burn",
		"crate", "coin", "pick", "door", "heal", "levelup", "win", "lose", "ui", "ui_back", "swap", "deny", "trigger"]
	names.append_array(Audio.CAST.values())
	for n in names:
		ok(ResourceLoader.exists("res://assets/audio/sfx_%s.wav" % n), "sfx_%s exists" % n)
	for m in ["title", "grove", "boss"]:
		var s: AudioStreamWAV = load("res://assets/audio/music_%s.wav" % m)
		ok(s != null and s.get_length() > 8.0, "music %s is a real loop (%.1fs)" % [m, s.get_length() if s else 0.0])
	for id in Catalog.spells():
		if Catalog.spell(id).kind == SpellDef.Kind.PROJ:
			ok(Audio.CAST.has(id), "%s has a cast sound" % id)


func test_tips_show_once() -> void:
	Hints.reset()
	var shown := []
	var cb := func(s: String) -> void: shown.append(s)
	Events.hint.connect(cb)
	ok(Hints.show("orb"), "first time: shown")
	ok(not Hints.show("orb"), "second time: not shown")
	ok(not Hints.show("nope"), "unknown tips are ignored")
	eq(shown.size(), 1, "one tip on screen")
	Events.hint.disconnect(cb)


func test_aim_leads_a_moving_target() -> void:
	world.build_room("hall", &"empty")
	world.player.position = Vector2(100, 200)
	var e := world.spawn_enemy(&"slime", Vector2(200, 200))
	e.spawn_t = 0.0
	e.vel = Vector2(0, -40)
	var p := world.player.lead(e)
	ok(p.y < e.position.y - 5.0, "aims ahead of an enemy moving up (%s)" % p)
	e.vel = Vector2.ZERO
	eq(world.player.lead(e), e.position, "a still enemy is aimed at directly")


func test_crates_break_and_pay() -> void:
	world.build_room("hall", &"empty")
	# the hall has crates at (5,6) and (20,6)
	eq(world.tile_at(5, 6), 4, "a crate stands there")
	ok(world.solid_at(Vector2(5 * 16 + 8, 6 * 16 + 8)), "crates block movement")
	ok(world.los(Vector2(40, 104), Vector2(140, 104)), "but not aim")
	ok(not world.los(Vector2(40, 104), Vector2(140, 104), true), "unless asked to")
	var g := world.run.gold
	world.break_crate(5, 6)
	eq(world.tile_at(5, 6), 0, "broken")
	ok(world.run.gold > g, "and it paid gold")


func test_new_wands_do_not_take_the_hand() -> void:
	var r := world.run
	r.add_wand(&"oak")
	eq(r.cur, 0, "the wand in hand stays")
	r.cur = 1
	world.player.tick(DT)
	eq(r.cur, 0, "an empty wand in hand switches back to one that can cast")
