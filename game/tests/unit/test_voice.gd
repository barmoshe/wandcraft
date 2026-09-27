extends "res://tests/unit/test_helpers.gd"
## The voices (research/voices-plan.md): every Story line has its file, lines are short, and
## Dialogue plays one at a time, in order, dropping stale lines and staying quiet when asked.

const LONG_OK := ["intro.", "ending.", "log."]   # read on their own screens or as a log


func setup(_t: SceneTree) -> void:
	Dialogue.clear()


func teardown() -> void:
	Dialogue.clear()
	Game.voice = true


func test_every_line_has_its_voice_file() -> void:
	var man_path := ProjectSettings.globalize_path("res://").path_join("../assets_src/voice/manifest.json")
	var man: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(man_path))
	ok(man != null, "the manifest exists")
	for l in Story.all_lines():
		var st := Dialogue.stream(l["id"])
		ok(st != null, "%s has a voice file" % l["id"])
		var row: Dictionary = man.get(Story.file_id(l["id"]), {})
		eq(row.get("text", ""), l["text"], "%s's file says the current text (run tools/voices.sh)" % l["id"])
		if st:
			var cap := 8.5 if LONG_OK.any(func(p: String) -> bool: return String(l["id"]).begins_with(p)) else 6.5
			ok(st.get_length() <= cap, "%s runs %.1f s (at most %.1f)" % [l["id"], st.get_length(), cap])


func test_lines_play_one_at_a_time_in_order() -> void:
	var got := []
	var on := func(who: String, _s: String, id: String, _d: float) -> void: got.append([who, id])
	Dialogue.line_started.connect(on)
	Game.voice = false   # text timing only: nothing is heard in tests
	for l in Story.entry("death", 0):
		Dialogue.enqueue(l["who"], l["text"], l["id"])
	Dialogue._process(0.0)
	eq(got.size(), 1, "the first line starts")
	eq(got[0], [Story.LINT, "death.0.0"], "LINT first")
	Dialogue._process(0.5)
	eq(got.size(), 1, "the second waits while the first is up")
	Dialogue._process(Dialogue._busy + 0.01)
	Dialogue._process(0.0)
	eq(got.size(), 2, "then the second")
	eq(got[1], [Story.DUCK, "death.0.1"], "the Duck answers")
	Dialogue.clear()
	Dialogue.enqueue(Story.DUCK, "old", "run.0")
	Dialogue._queue[0]["t"] = float(Dialogue._queue[0]["t"]) - 10.0
	Dialogue._process(0.0)
	eq(got.size(), 2, "a line waiting over 6 s is dropped")
	Dialogue.line_started.disconnect(on)


func test_quiet_and_voice_off_play_nothing() -> void:
	Game.voice = false
	ok(not Dialogue._can_play(), "VOICE off: text only")
	Game.voice = true
	Game.quiet += 1
	ok(not Dialogue._can_play(), "a quiet world: nothing")
	Game.quiet -= 1
