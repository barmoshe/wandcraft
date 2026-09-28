extends "res://tests/unit/world_fixture.gd"
## 0.22 polish (research/polish-0.22.md): the audit's fixes. No disk reads in a fight, quiet
## fights, the exploits closed, story beats and lines never lost.


func setup(tree: SceneTree) -> void:
	super.setup(tree)
	Story._mem = {}
	Residents._mem = {}
	Barks.reset()


func teardown() -> void:
	Story._mem = {}
	Residents._mem = {}
	super.teardown()


func _said(fn: Callable) -> Array:
	var got: Array = []
	var cb := func(who: String, _text: String, id: String) -> void: got.append(id)
	Events.say.connect(cb)
	fn.call()
	Events.say.disconnect(cb)
	return got


func test_the_meta_record_is_read_from_disk_once() -> void:
	var was := SaveGame.in_memory
	SaveGame.in_memory = true   # off the player's disk
	SaveGame.enabled = true     # (the fixture turns saving off)
	SaveGame.forget_meta()
	var before := SaveGame.meta_reads
	for k in 20:
		SaveGame.load_meta()
	eq(SaveGame.meta_reads - before, 1, "twenty loads, one read")
	var m := SaveGame.load_meta()
	m["bits"] = 77
	SaveGame.save_meta(m)
	eq(int(SaveGame.load_meta().get("bits", 0)), 77, "a save is seen at once")
	eq(SaveGame.meta_reads - before, 1, "without reading the file again")
	var a := SaveGame.load_meta()
	a["bits"] = 1
	eq(int(SaveGame.load_meta().get("bits", 0)), 77, "each caller gets its own copy")
	SaveGame.in_memory = was
	SaveGame.enabled = false
	SaveGame.forget_meta()


func test_fights_are_quiet_until_the_room_clears() -> void:
	world.build_room("hall", &"fight")
	world.cleared = false
	var mid := _said(func() -> void: world.bark(&"big_hit", {"dmg": 90.0}))
	eq(mid.size(), 0, "a big hit mid-fight waits")
	var after := _said(func() -> void: world.call("_clear_room"))
	ok(after.size() >= 1, "the room clears and it gets its line (%s)" % [after])


func test_what_matters_now_still_speaks_mid_fight() -> void:
	world.build_room("hall", &"fight")
	world.cleared = false
	var got := _said(func() -> void: world.bark(&"low_hp", {"hp": 0.2, "boss": false}))
	ok(got.size() >= 1, "low HP is said at once (%s)" % [got])


func test_no_barks_in_the_workshop_sandbox_or_a_daily() -> void:
	world.build_room("hall", &"fight")
	world.cleared = true
	world.run.daily = "2026-09-28"
	eq(_said(func() -> void: world.bark(&"room_fast", {"time": 3.0})).size(), 0, "a daily is quiet")
	world.run.daily = ""
	world.run.sandbox = true
	eq(_said(func() -> void: world.bark(&"room_fast", {"time": 3.0})).size(), 0, "the sandbox is quiet")
	world.run.sandbox = false


func test_lints_review_cannot_be_farmed_by_swapping_wands() -> void:
	var gap := WandState.make(Catalog.wand(&"oak"), [&"mote", null, &"needle"])
	var clean := WandState.make(Catalog.wand(&"apprentice"), [&"mote"])
	Barks.lint_review(gap, 0.0, true)
	for k in 4:
		Barks.lint_review(clean, 100.0 + k * 20.0, true)
		Barks.lint_review(gap, 110.0 + k * 20.0, true)
	eq(Barks.lint_fixes(), 0, "flipping to a clean wand fixes nothing")
	gap.slots[1] = {"id": &"spark", "lv": 1}
	Barks.lint_review(gap, 300.0, true)
	eq(Barks.lint_fixes(), 1, "filling the gap on that wand does")


func test_fixed_vitals_makes_the_altar_cost_hp() -> void:
	var r := world.run
	r.add_relic(&"version_pin")
	var max0 := r.max_hp
	r.hp = r.max_hp
	Rewards.grant(r, {"t": &"relic", "id": &"aperture", "hp_cost": 0.15})
	eq(r.max_hp, max0, "max HP stays locked")
	ok(r.hp < max0 - 1.0, "the cost comes out of HP instead (%.0f of %.0f)" % [r.hp, max0])


func test_relic_copy_turns_once_a_run() -> void:
	var r := world.run
	r.add_relic(&"hot_patch")
	r.add_relic(&"git_clone")
	for k in Relics.CLONE_ROOMS:
		Relics.on_room_clear(r)
	ok(not r.relics.has(&"git_clone"), "it turned")
	ok(not Relics.offerable(r, &"git_clone"), "and is never offered again this run")
	ok(not Relics.CLONE_SAFE.has(&"version_pin"), "Fixed Vitals is never copied")


func test_a_walked_away_story_beat_waits_for_next_time() -> void:
	Residents.rescue(&"grep")
	var m := Residents._meta()
	var before := int(Residents._rec(m)[String(&"grep")].get("beat", 0))
	var lines := Residents.talk(&"grep")
	if lines.is_empty() or not String(lines[0]["id"]).contains(".arc."):
		ok(true, "no story beat was due (nothing to keep)")
		return
	Residents.rewind(&"grep")
	var after := int(Residents._rec(Residents._meta())[String(&"grep")].get("beat", 0))
	eq(after, before, "the beat is back, to be told whole next time")


func test_a_cut_line_takes_its_bubble() -> void:
	var cut := [false]
	var cb := func() -> void: cut[0] = true
	Dialogue.line_cut.connect(cb)
	Dialogue.clear()
	Dialogue.current = {"who": Story.DUCK, "text": "quack", "id": "x"}
	Dialogue.clear()
	Dialogue.line_cut.disconnect(cb)
	ok(cut[0], "clearing a showing line says so (the HUD drops the bubble)")


func test_bench_runs_never_write_the_workshop() -> void:
	world.bot = true
	world.cage = {"pos": Vector2(200, 120), "who": &"cache", "open": false, "t": 0.0}
	world.call("_free_resident")
	world.bot = false
	ok(not Residents.rescued(&"cache"), "a bot freeing someone rescues no one in the save")


func test_new_items_are_new_only_the_first_time() -> void:
	Meta.test_meta = {}
	ok(Meta.is_new(&"ember"), "never seen: NEW")
	Meta.mark_seen([&"ember"])
	ok(not Meta.is_new(&"ember"), "seen once: not NEW any more")
	ok(Meta.is_new(&"frost"), "others still are")
	Meta.test_meta = null


func test_a_tapped_keyword_chip_explains_itself() -> void:
	var s := RewardScreen.new()
	s.run = world.run
	s.press("kw:Burn")
	eq(s._toast, String(Glossary.KEYWORDS["Burn"]), "the chip's line shows")
	s.free()


func test_a_finished_run_is_recorded_with_the_meta_cache() -> void:
	# the feel agent caught it: record_run wrote meta.json around the cache and lost runs
	var was := SaveGame.in_memory
	SaveGame.in_memory = true
	SaveGame.enabled = true
	SaveGame.forget_meta()
	var runs0 := int(SaveGame.load_meta().get("runs", 0))
	SaveGame.record_run(world.run, "", "")
	eq(int(SaveGame.load_meta().get("runs", 0)), runs0 + 1, "the run counts")
	SaveGame.forget_meta()
	eq(int(SaveGame.load_meta().get("runs", 0)), runs0 + 1, "and it is in the file too")
	SaveGame.in_memory = was
	SaveGame.enabled = false
	SaveGame.forget_meta()
