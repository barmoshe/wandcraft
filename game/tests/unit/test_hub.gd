extends "res://tests/unit/world_fixture.gd"
## The Workshop (research/workshop-0.19.md): the hub room, its stations, the portal, the
## training dummy, the fire gate, and the screens its stations open.

var tree: SceneTree
var _asked: Array = []


func setup(t: SceneTree) -> void:
	super.setup(t)
	tree = t
	# a fresh in-memory save: the hub reads and writes meta, never the player's files
	SaveGame.enabled = true
	SaveGame.in_memory = true
	SaveGame._mem = {}
	_asked = []
	world.ui_request.connect(func(kind: StringName, data: Dictionary) -> void: _asked.append([kind, data]))


func teardown() -> void:
	SaveGame.in_memory = false
	SaveGame._mem = {}
	Meta.test_meta = null
	super.teardown()


func _enter(runs := 3) -> void:
	var m := SaveGame.load_meta()
	m["runs"] = runs
	SaveGame.save_meta(m)
	world.enter_hub(Hub.make_run(SaveGame.load_meta()))


func test_the_room_fits_one_screen_and_is_quick_to_cross() -> void:
	_enter()
	ok(world.gw * Hub.TS + 20 <= 360, "fits a 4:3 screen's width with the camera pads (%d px)" % (world.gw * Hub.TS))
	ok(world.gh * Hub.TS + 88 <= 270, "and its height (%d px)" % (world.gh * Hub.TS))
	var cross := (world.gw - 2) * Hub.TS / Player.SPEED
	ok(cross <= 2.8, "crossing takes %.1f s" % cross)
	eq(world.room_kind, &"hub", "a hub room")
	ok(world.enemies.size() == 1 and world.hub.dummy != null, "only the training dummy")
	ok(world.run.sandbox, "on a sandbox run")


func test_every_station_is_on_floor_and_reachable() -> void:
	_enter()
	var start := Vector2i(world.player.position / Hub.TS)
	var seen := {start: true}
	var todo: Array = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= world.gw or n.y >= world.gh or seen.has(n):
				continue
			if world.grid[n.y * world.gw + n.x] != 0:
				continue
			seen[n] = true
			todo.append(n)
	for id in Hub.STATIONS:
		ok(world.hub.anchors.has(id), "%s is in the room" % id)
		for p in world.hub.anchors.get(id, []):
			ok(seen.has(Vector2i(p / Hub.TS)), "%s at %s can be walked to" % [id, p])
	eq((world.hub.anchors["heroes"] as Array).size(), Hub.HEROES.size(), "a pedestal per hero")


func test_walking_opens_nothing_but_the_portal() -> void:
	_enter()
	for id in Hub.STATIONS:
		if id == "portal":
			continue
		world.player.position = world.hub.anchors[id][0] + Vector2(0, 10)
		_steps(0.3)
		eq(world.hub.near, id, "%s is in reach" % id)
	eq(_asked.size(), 0, "walking past every station opened none of them")
	world.player.position = world.hub.anchors["portal"][0]
	_steps(0.2)
	eq(_asked.size(), 1, "walking into the portal asks for the run sheet")
	eq(_asked[0][1]["id"], "portal", "by name")
	_steps(0.5)
	eq(_asked.size(), 1, "once, while you stand there")
	world.player.position = world.hub.anchors["duck"][0]
	_steps(0.2)
	world.player.position = world.hub.anchors["portal"][0]
	_steps(0.2)
	eq(_asked.size(), 2, "and again after stepping away")


func test_stations_open_with_runs() -> void:
	_enter(0)
	ok(not world.hub.open("pkg") and not world.hub.open("repl"), "a new player: no merchant or bench yet")
	ok(world.hub.open("portal") and world.hub.open("heroes") and world.hub.open("bounty"), "the rest are open")
	_enter(1)
	ok(world.hub.open("pkg") and not world.hub.open("repl"), "the merchant after one run")
	_enter(2)
	ok(world.hub.open("repl"), "the bench after two")


func test_the_hub_never_saves_a_run() -> void:
	_enter()
	_steps(1.0)
	ok(not SaveGame._mem.has(SaveGame.RUN_PATH), "no run file")
	SaveGame.save_run(world.run)
	ok(not SaveGame._mem.has(SaveGame.RUN_PATH), "not even when asked")
	SaveGame.record_run(world.run)
	eq(int(SaveGame.load_meta()["runs"]), 3, "and it never counts as a run")


func test_the_wand_fires_only_at_the_training_ground() -> void:
	_enter()
	Game.auto_fire = true
	world.player.position = Vector2(world.gw * Hub.TS / 2.0, (world.gh - 2) * Hub.TS)
	world.controls.aim = Vector2(1, 0)
	_steps(1.5)
	eq(float(world.run.stats["damage"]), 0.0, "no casting across the Workshop")
	world.controls.aim = Vector2.ZERO
	world.player.position = world.hub.dummy.position + Vector2(-40, 6)
	_steps(2.0)
	ok(float(world.run.stats["damage"]) > 0.0, "the dummy takes hits at the training ground")
	ok(world.hub.dps > 0.0, "and shows DPS (%.1f)" % world.hub.dps)
	Game.auto_fire = false
	var hurt := world.hub.dummy.hp < world.hub.dummy.max_hp
	_steps(2.2)
	ok(hurt and world.hub.dummy.hp == world.hub.dummy.max_hp, "left alone, it heals")


func test_a_run_leaves_the_hub_behind() -> void:
	_enter()
	world.start_run(RunState.create(5))
	ok(world.hub == null, "start_run clears the Workshop")
	ok(world.room_kind == &"start", "into the start room")
	var r := RunState.create(6)
	r.picked = true
	world.start_run(r)
	ok(world.orb.is_empty() and world.doors_open, "a hero picked in the Hall: no orb, the doors open")


func test_the_greeting_fits_the_last_run() -> void:
	eq(Hub.greeting({}), "hub_first", "a first visit")
	var m := {"hub_seen": true, "runs": 4, "greeted": 3, "last_run": {"won": false, "boss": true}}
	eq(Hub.greeting(m), "hub_boss", "a death at a boss")
	m["last_run"] = {"won": true}
	eq(Hub.greeting(m), "hub_win", "a win")
	m["last_run"] = {"quit": true}
	eq(Hub.greeting(m), "hub_quit", "a quit")
	m["last_run"] = {}
	m["greeted"] = 4
	eq(Hub.greeting(m), "hub_back", "nothing new")
	eq(Hub.greeting({"hub_seen": true, "runs": 1, "greeted": 0, "last_run": {"won": false}}), "hub_unlock", "a station just opened")


func test_the_chosen_hero_runs_and_locked_heroes_do_not() -> void:
	Meta.test_meta = {"meta_v": 2, "bounties": [], "packs": [], "unlocked": []}
	eq(Hub.next_hero({"hero": "pyromancer"}), &"apprentice", "a locked hero falls back to the Apprentice")
	Meta.test_meta["bounties"] = ["mini"]
	eq(Hub.next_hero({"hero": "pyromancer"}), &"pyromancer", "an open one is used")
	eq(Hub.make_run({"hero": "pyromancer"}).hero, &"pyromancer", "the Workshop dresses you as them")
	ok(Hub.library().all(func(e: Dictionary) -> bool: return not Meta.is_locked(e["id"])), "the bench's library holds only open spells")


func _screen(s: Screen) -> Screen:
	s.run = world.run
	tree.root.add_child(s)
	if not s.is_node_ready():
		s._opened()
	return s


func test_station_screens() -> void:
	_enter()
	var got := []
	var sheet := _screen(RunSheet.new()) as RunSheet
	sheet.finished.connect(func(r: Dictionary) -> void: got.append(r))
	sheet.press("new")
	eq(got.back().get("action"), "new", "the run sheet starts a new run")
	sheet.free()
	var menu := _screen(HubMenu.new()) as HubMenu
	menu.finished.connect(func(r: Dictionary) -> void: got.append(r))
	menu.press("docs")
	eq(got.back().get("station"), "docs", "the menu opens a station by name")
	menu.free()
	var term := PauseScreen.new()
	term.hub = true
	_screen(term)
	term.finished.connect(func(r: Dictionary) -> void: got.append(r))
	term.press("credits")
	ok(got.back().get("credits", false), "the Terminal has CREDITS")
	term.free()
	var m := SaveGame.load_meta()
	m["bits"] = 70
	SaveGame.save_meta(m)
	var shop := _screen(PackScreen.new()) as PackScreen
	shop.press("buy0")
	eq(shop.bought, "glitch", "INSTALL buys the first pack on the shelf")
	eq(Meta.bits(), 10, "for its price")
	shop.press("skip")
	shop.finished.connect(func(r: Dictionary) -> void: got.append(r))
	shop.press("done")
	eq(got.back().get("bought"), "glitch", "DONE after the opening")
	shop.free()
	var r := RunState.create(3)
	r.stats["rooms"] = 1
	Meta.check(r)
	var board := _screen(BountyScreen.new()) as BountyScreen
	board.press("claim:room")
	eq(Meta.bits(), 20, "CLAIM pays the ticket")
	board.free()
	var bench := EditorScreen.new()
	bench.library = Hub.library()
	_screen(bench)
	var first: Dictionary = world.run.bag[0]
	bench.press("slot:-1:0")
	bench.press("slot:1:0")
	eq(world.run.wands[1].slots[0]["id"], first["id"], "the bench copies a spell from the library")
	eq(world.run.bag[0]["id"], first["id"], "and the library keeps it")
	bench.press("slot:1:0")
	bench.press("slot:-1:3")
	eq(world.run.wands[1].slots[0], null, "dropping it back clears the slot")
	bench.free()
