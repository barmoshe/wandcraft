extends "res://tests/unit/world_fixture.gd"
## World 3, the Kernel (0.20, research/world3-0.20.md): its enemies' counters, Data Race's
## together rule, the Glitch's revert glyphs, the resident's cage and the residents' talk.


func setup(tree: SceneTree) -> void:
	super.setup(tree)
	Story._mem = {}
	Residents._mem = {}


func teardown() -> void:
	Story._mem = {}
	Residents._mem = {}
	super.teardown()


func _boss(kind: StringName) -> Boss:
	world.run.world = 2
	world.run.step = Chapter.PLAN.size() - 1 if kind == &"boss" else Chapter.PLAN.find(&"mini")
	world.build_room("arena_ring" if kind == &"boss" else "arena_open", kind)
	world.call("_spawn_boss")
	var b := world.boss
	b.invuln = 0.0
	b.sm = &"idle"
	b.st_t = 99.0
	world.hash.rebuild(world.enemies)
	return b


func _live(kind: StringName, pos: Vector2) -> Enemy:
	var e := world.spawn_enemy(kind, pos)
	e.spawn_t = 0.0
	e.sprite.visible = true
	return e


func test_world_three_meets_its_own_bosses() -> void:
	world.run.world = 2
	world.run.tutorial = false
	ok(world.mini_boss() is BossRace, "World 3: Data Race")
	ok(world.world_boss() is BossGlitch, "and the Glitch")
	world.run.world = 1
	ok(world.world_boss() is BossDeadlock, "World 2 keeps Deadlock")
	eq(Chapter.area_name(0, 2), "The Page Archive", "the Archive first")
	eq(Chapter.area_name(6, 2), "Ring Zero", "then Ring Zero")


func test_a_page_leaks_puddles_slow_you_and_dry_when_it_dies() -> void:
	world.build_room("hall", &"empty")
	var e := _live(&"leak", Vector2(200, 150))
	world.add_puddle(e, Vector2(120, 150))
	eq(world.puddles.size(), 1, "a puddle")
	ok(world.puddle_slow(Vector2(120, 150)) < 1.0, "slows you inside it")
	eq(world.puddle_slow(Vector2(300, 150)), 1.0, "not outside")
	var r0 := float(world.puddles[0]["r"])
	_steps(2.0)
	ok(float(world.puddles[0]["r"]) > r0, "it grows while the leak lives")
	world.hurt_enemy(e, 9999.0, e.position, 0.0, 0.0)
	eq(world.puddles.size(), 0, "killing the leak frees its memory")


func test_a_dangling_pointer_hits_only_on_its_line() -> void:
	world.build_room("hall", &"empty")
	Game.god_mode = false
	var e := _live(&"null_ptr", Vector2(100, 150))
	world.player.position = Vector2(160, 150)
	var hp0 := world.run.hp
	world.pointer_snap(e, Vector2(100, 150), Vector2(220, 150))
	ok(world.run.hp < hp0, "standing on the line: hit")
	world.player.dash_inv = 0.0
	world.player.position = Vector2(160, 190)
	world.player.inv = 0.0
	var hp1 := world.run.hp
	world.pointer_snap(e, Vector2(100, 150), Vector2(220, 150))
	eq(world.run.hp, hp1, "off the line: nothing")
	Game.god_mode = true


func test_an_interrupt_suspends_a_boost_until_it_dies() -> void:
	world.build_room("hall", &"empty")
	var w := wand([&"empower", &"mote"])
	world.run.wands[0] = w
	world.run.cur = 0
	var e := _live(&"interrupt", Vector2(200, 100))
	world.interrupt_claim(e)
	eq(w.suspended, 0, "the boost is suspended, not the only shooting spell")
	var plan := WandProgram.compile(w)
	ok(plan.groups.size() >= 1, "the wand still casts")
	world.hurt_enemy(e, 9999.0, e.position, 0.0, 0.0)
	eq(w.suspended, -1, "its death gives the spell back")
	var lone := wand([&"mote"])
	world.run.wands[0] = lone
	var e2 := _live(&"interrupt", Vector2(200, 100))
	world.interrupt_claim(e2)
	eq(lone.suspended, -1, "a wand with one spell keeps it")


func test_data_race_threads_fall_only_together() -> void:
	var b := _boss(&"mini") as BossRace
	ok(b != null, "Data Race appeared")
	ok(b.thread_b != null, "with Thread B")
	world.hurt_enemy(b, 9999.0, b.position, 0.0, 0.0)
	ok(not b.dead, "A alone does not fall")
	ok(b.a_down, "it is down, waiting")
	b.race_t = 0.01
	world.step(DT)
	ok(not b.a_down, "the race clock ran out: A respawned")
	ok(b.hp > 0.0 and b.hp < b.max_hp, "at part of its HP (%.0f)" % b.hp)
	b.invuln = 0.0
	world.hurt_enemy(b, 9999.0, b.position, 0.0, 0.0)
	ok(b.a_down, "A down again")
	world.hurt_enemy(b.thread_b, 9999.0, b.thread_b.position, 0.0, 0.0)
	ok(b.dead, "B falls in the window: both are done")


func test_the_glitchs_revert_glyph_hurts_it_and_pushes_the_rewrite_back() -> void:
	var b := _boss(&"boss") as BossGlitch
	ok(b != null, "the Glitch appeared")
	b.hp = b.max_hp * 0.3
	_steps(0.5)   # past the phase change's hit-stop
	eq(b.phase, 2, "phase 3: revert")
	b.invuln = 0.0
	b.rewrite = 40.0
	b.glyph = world.player.position
	var hp0 := b.hp
	world.step(DT)
	ok(b.hp < hp0, "touching the glyph reverts it (%.0f)" % (hp0 - b.hp))
	ok(b.rewrite < 40.0, "and pushes the rewrite back")
	eq(b.glyph, Vector2.INF, "the glyph is used")


func test_the_resident_door_waits_until_the_rescue() -> void:
	var run := RunState.create(77)
	run.tutorial = false
	eq(Residents.waiting_in(run), &"grep", "World 1: Grep")
	var map := Chapter.make_map(run)
	eq(map[Chapter.RESIDENT_STEP][1]["kind"], &"resident", "his cage is on the middle lane")
	Residents.rescue(&"grep")
	eq(Residents.waiting_in(run), &"", "rescued: no more cage")
	run.world = 1
	eq(Residents.waiting_in(run), &"hotfix", "World 2: Hotfix")
	run.daily = "2026-09-28"
	eq(Residents.waiting_in(run), &"", "never on a daily")


func test_clearing_the_cage_room_frees_the_resident() -> void:
	world.run.tutorial = false
	world.run.room = {"kind": &"resident", "reward": &"resident", "who": &"grep"}
	world.run.step = Chapter.RESIDENT_STEP
	world.build_room("hall", &"resident")
	ok(not world.cage.is_empty(), "a cage")
	world.call("_clear_room")
	ok(world.cage["open"], "clearing the room opens it")
	ok(Residents.rescued(&"grep"), "Grep moves in")
	ok(world.doors_open, "and the doors open")


func test_residents_talk_their_arc_then_react_then_idle() -> void:
	Residents._mem = {"runs": 0, "wins": 0, "best_step": 0}
	Residents.rescue(&"grep")
	var first := Residents.talk(&"grep")
	eq(first[0]["id"], "res.grep.arc.0.0", "the first beat first")
	ok(not Residents.has_news(&"grep"), "the next beat waits for a run")
	var m := Residents._mem
	m["runs"] = 1
	m["last_run"] = {"won": false, "boss": true}
	Residents._mem = m
	ok(Residents.has_news(&"grep"), "a run later: news")
	eq(Residents.talk(&"grep")[0]["id"], "res.grep.arc.1.0", "the second beat")
	eq(Residents.talk(&"grep")[0]["id"], "res.grep.react.boss", "then how the last run went")
	ok(String(Residents.talk(&"grep")[0]["id"]).begins_with("res.grep.idle."), "then idle")


func test_grep_confesses_in_the_kernel_and_opens_the_true_ending() -> void:
	Residents._mem = {"runs": 3, "wins": 1, "best_step": 25}
	for id in Residents.ORDER:
		Residents.rescue(id)
	var m := Residents._mem
	(m["residents"]["grep"] as Dictionary)["beat"] = 3
	Residents._mem = m
	ok(not Residents.true_ending_open(), "not before the confession")
	var said := Residents.talk(&"grep")
	eq(said[0]["id"], "res.grep.arc.3.0", "the confession")
	ok(Residents.flag("confessed"), "is remembered")
	ok(Residents.true_ending_open(), "and a win plus every resident opens fix forward")


func test_search_gives_one_hint_a_run() -> void:
	Residents._mem = {"runs": 2}
	var h := Residents.search()
	ok(h.contains("World 1"), "first: where someone's caged (%s)" % h)
	ok(Residents.search().begins_with("One question per run"), "once a run")


func test_skins_cost_bits_and_never_the_gift() -> void:
	Residents._mem = {"bits": 70}
	ok(Residents.take_skin("brass"), "Brass Rod for 60 Bits")
	eq(int(Residents._mem["bits"]), 10, "paid")
	eq(Residents.skin_on(), "brass", "and worn")
	ok(not Residents.take_skin("ember"), "not enough Bits")
	ok(not Residents.take_skin("hotfix"), "the gift can't be bought")
	ok(Residents.take_skin("oak"), "the plain one is always there")


func test_lost_pages_need_cache() -> void:
	Residents._mem = {}
	eq(Residents.find_page(), -1, "no archivist, no pages")
	Residents.rescue(&"cache")
	eq(Residents.find_page(), 0, "then the first")
	eq(Residents.find_page(), 1, "and the next")


func test_rescued_residents_move_into_the_workshop() -> void:
	world.enter_hub(Hub.make_run({}))
	world.hub.populate()
	ok(not world.hub.anchors.has("grep"), "no Grep before the rescue")
	for id in Residents.ORDER:
		Residents.rescue(id)
	world.hub.populate()
	for id in Residents.ORDER:
		ok(world.hub.anchors.has(String(id)), "%s has a corner" % id)
		world.player.position = world.hub.anchors[String(id)][0] + Vector2(0, 10)
		_steps(0.3)
		eq(world.hub.near, String(id), "%s can be walked up to" % id)
