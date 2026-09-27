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
	var lines: Array = Story.LINES["death"]
	for i in lines.size():
		eq(Story.line("death"), lines[i], "death line %d in order" % i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	ok(lines.has(Story.line("death", rng)), "then any of them")
	eq(Story.line("no_such_event"), "", "an unknown event says nothing")


func test_the_commit_log_is_found_in_order() -> void:
	eq(Story.find_log()["id"], "a1f00d", "a terminal gives the first entry")
	eq(Story.find_log()["id"], "b00b1e", "then the next")
	eq(Story.find_log("grove")["id"], "deadbe", "a story beat gives its own entry")
	eq(Story.find_log("grove"), {}, "once")
	eq(Story.find_log()["id"], "c0ffee", "terminals skip the beat entries")
	eq(Story.logs_found().map(func(l: Dictionary) -> String: return l["id"]), ["a1f00d", "b00b1e", "c0ffee", "deadbe"], "found, in log order")
	eq(Story.find_log("win")["id"], "7e57ed", "the win gives two")
	eq(Story.find_log("win")["id"], "c10ud0", "the second")


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
