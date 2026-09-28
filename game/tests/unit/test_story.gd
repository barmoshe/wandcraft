extends "res://tests/unit/test_helpers.gd"
## The story (research/story.md): the Duck's lines, the commit log and the descent screen.

var tree: SceneTree


func setup(t: SceneTree) -> void:
	tree = t
	SaveGame.enabled = false
	Story._mem = {}


func teardown() -> void:
	Story._mem = {}
	SaveGame.enabled = true


func test_lines_play_in_order_then_pick() -> void:
	var n: int = Story.LINES["death"].size()
	for i in n:
		eq(Story.pick("death"), Story.entry("death", i), "death entry %d in order" % i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var any := Story.pick("death", rng)
	ok(range(n).any(func(i: int) -> bool: return Story.entry("death", i) == any), "then any of them")
	eq(Story.line("no_such_event"), "", "an unknown event says nothing")
	eq(Story.duck_text(Story.entry("death", 0)), "The Glitch wins this one. Not the next.", "the end screen shows the Duck's line")


func test_every_line_has_a_speaker_and_a_unique_id() -> void:
	var ids := {}
	for l in Story.all_lines():
		ok(Story.SPEAKERS.has(l["who"]), "%s: a known speaker" % l["id"])
		ok(not ids.has(l["id"]), "%s is unique" % l["id"])
		ids[l["id"]] = true
		ok(String(l["text"]).length() <= 120, "%s is short enough to say in 6 s" % l["id"])
		ok(not String(l["text"]).contains("\u2014"), "%s has no em dash" % l["id"])
	ok(ids.size() >= 70, "about 80 voiced lines (%d)" % ids.size())
	var files := {}
	for id in ids:
		files[Story.file_id(id)] = true
	eq(files.size(), ids.size(), "and unique file names")


func test_the_commit_log_is_found_in_order() -> void:
	eq(Story.find_log()["id"], "a1f00d", "a terminal gives the first entry")
	eq(Story.find_log()["id"], "b00b1e", "then the next")
	eq(Story.find_log("grove")["id"], "deadbe", "a story beat gives its own entry")
	eq(Story.find_log("grove"), {}, "once")
	eq(Story.find_log()["id"], "c0ffee", "terminals skip the beat entries")
	eq(Story.logs_found().map(func(l: Dictionary) -> String: return l["id"]), ["a1f00d", "b00b1e", "c0ffee", "deadbe"], "found, in log order")
	eq(Story.find_log("win")["id"], "7e57ed", "the win gives the Duck's")
	eq(Story.find_log("down:Deadlock")["id"], "10c4ed", "Deadlock's fall gives two")
	eq(Story.find_log("down:Deadlock")["id"], "c10ud0", "the second: mkdir /world3")
	eq(Story.find_log_id("1a7e57")["id"], "1a7e57", "a resident's beat gives its own by id")
	eq(Story.find_log_id("1a7e57"), {}, "once")


func test_the_intro_is_marked_seen() -> void:
	ok(not Story.intro_seen(), "not seen at first")
	Story.mark("intro_seen")
	ok(Story.intro_seen(), "then seen")


func test_descend_waits_for_the_drop() -> void:
	var s := WorldScreen.new()
	s.run = RunState.create(1)
	s.to = 1
	tree.root.add_child(s)
	var got := []
	s.finished.connect(func(res: Dictionary) -> void: got.append(res))
	s._age = 0.2
	s.press("descend")
	eq(got.size(), 0, "not while the hero is still falling")
	s._age = WorldScreen.DROP + 0.1
	s.press("descend")
	eq(got.size(), 1, "then DESCEND goes on")
	eq(Story.WORLD_CARDS.size(), Chapter.WORLDS.size(), "every world has a card")
	s.free()


func test_panels_type_then_advance_then_finish() -> void:
	var s := StoryScreen.new()
	s.run = RunState.create(1)
	s.panels = Story.INTRO
	s.who = Story.INTRO_WHO
	s.art = Story.INTRO_ART
	tree.root.add_child(s)
	var got := []
	s.finished.connect(func(res: Dictionary) -> void: got.append(res))
	s.press("next")
	eq(s.at, 0, "a tap while typing finishes the line first")
	for i in Story.INTRO.size() - 1:
		s.press("next")
		s.press("next")
	eq(s.at, Story.INTRO.size() - 1, "then panel by panel to the last")
	eq(got.size(), 0, "not done yet")
	s.press("next")
	s.press("next")
	eq(got.size(), 1, "the last tap finishes, once")
	s.free()
	var k := StoryScreen.new()
	k.run = RunState.create(1)
	k.panels = Story.ENDING
	tree.root.add_child(k)
	var got2 := []
	k.finished.connect(func(res: Dictionary) -> void: got2.append(res))
	k.press("skip")
	ok(got2.size() == 1 and got2[0].get("skipped", false), "SKIP leaves at once")
	k.free()
	eq(Story.INTRO_ART.size(), Story.INTRO.size(), "a picture per intro panel")
	eq(Story.ENDING_ART.size(), Story.ENDING.size(), "and per ending panel")


func test_an_old_save_is_wiped_once() -> void:
	# in memory, so the real save is never touched
	SaveGame.in_memory = true
	SaveGame.enabled = true
	SaveGame._mem = {}
	ok(not SaveGame.reset_if_stale(), "in-memory saves are never wiped")
	SaveGame.in_memory = false
	SaveGame.enabled = false
	ok(not SaveGame.reset_if_stale(), "nor with saving off (tests)")
