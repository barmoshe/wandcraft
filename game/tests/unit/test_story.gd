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


## Round 2: entries each event had before (their text is voiced and frozen). Everything
## after them is new, and new lines fit a speech bubble.
const ROUND1 := {"first_run": 1, "run": 6, "grove": 3, "world2": 3, "core": 2, "boss:Copy-Paste": 2,
	"boss:Garbage Collector": 2, "boss:The Infinite Loop": 3, "boss:Deadlock": 2, "down:The Infinite Loop": 2,
	"down:Deadlock": 1, "down:mini": 2, "untouched": 1, "descend": 1, "death": 5, "win": 1, "heat:1": 1,
	"heat:2": 1, "heat:3": 1, "heat:4": 1, "heat:5": 1, "hub_first": 1, "hub_back": 3, "hub_death": 3,
	"hub_boss": 2, "hub_win": 2, "hub_quit": 2, "hub_unlock": 1, "hub_hero": 2, "pkg_bought": 2, "hub_duck": 4,
	"hub_lint": 3, "world3": 3, "ring": 2, "interrupt": 1, "boss:Data Race": 2, "down:Data Race": 1,
	"boss:The Glitch": 2, "glitch:unwind": 1, "glitch:revert": 1, "down:The Glitch": 1, "true_win": 1, "hub_epilogue": 3}
const BUBBLE := 60


func test_round_two_lines_fit_and_every_pack_has_a_word() -> void:
	for ev in Story.LINES:
		var entries: Array = Story.LINES[ev]
		ok(entries.size() >= int(ROUND1.get(ev, 0)), "%s kept its old entries" % ev)
		for i in range(int(ROUND1.get(ev, 0)), entries.size()):
			for l in Story.entry(ev, i):
				ok(Story.SPEAKERS.has(l["who"]), "%s: a known speaker" % l["id"])
				ok(String(l["text"]).length() <= BUBBLE, "%s fits a bubble: %s" % [l["id"], l["text"]])
	for ev in ["first_run", "descend", "untouched", "win", "interrupt", "hub_unlock", "down:The Infinite Loop",
			"down:Deadlock", "down:mini", "down:Data Race", "down:The Glitch", "world3", "ring", "archive",
			"heat:1", "heat:2", "heat:3", "heat:4", "heat:5", "glitch:unwind", "glitch:revert"]:
		ok((Story.LINES.get(ev, []) as Array).size() >= 3, "%s has 3 or more entries" % ev)
	for p in Meta.PACKS:
		ok(Story.LINES.has("pkg_bought:" + String(p["id"])), "a word for the %s pack" % p["id"])


func test_the_log_has_seventeen_entries_and_hotfix_tells_his() -> void:
	eq(Story.LOGS.size(), 17, "seventeen entries")
	eq(Story.LOGS[16]["id"], "h07f1x", "the seventeenth is Hotfix's")
	Residents._mem = {"runs": 0, "wins": 1, "best_step": 25, "story_flags": ["confessed"]}
	Residents.rescue(&"hotfix")
	var m := Residents._mem
	m["residents"]["hotfix"]["beat"] = 5
	m["runs"] = 3
	Residents._mem = m
	eq(Residents.next_beat(&"hotfix"), -1, "not before four runs have passed")
	m["runs"] = 4
	Residents._mem = m
	eq(Residents.next_beat(&"hotfix"), 5, "with Grep's told and runs behind him, his secret")
	var said := Residents.talk(&"hotfix")
	eq(said[0]["id"], "res.hotfix.arc.5.0", "the sixth beat")
	ok(Residents.flag("hotfix_told"), "remembered")
	ok(Story.logs_found().any(func(l: Dictionary) -> bool: return l["id"] == "h07f1x"), "and the commit is in the log")
	eq(Residents.waits_for(&"hotfix"), "More to say once you own 3 skins.", "his last beat waits on the forge")
	Residents._mem = {}


func test_residents_have_six_or_more_beats_with_varied_gates() -> void:
	var gates := {}
	for id in Residents.ORDER:
		var arc: Array = Residents.ARCS[id]
		ok(arc.size() >= 6 and arc.size() <= 7, "%s has 6-7 beats (%d)" % [id, arc.size()])
		for b in arc:
			for k in b["need"]:
				gates[k] = true
	ok(gates.size() >= 7, "the beats wait on many kinds of thing (%s)" % str(gates.keys()))


func test_chatter_and_opinions() -> void:
	Residents._mem = {"runs": 0}
	eq(Residents.chatter(), [], "nobody home, no chatter")
	Residents.rescue(&"grep")
	Residents.rescue(&"hotfix")
	eq(Residents.chatter()[0]["id"], "res.chat.0.0", "the first that fits")
	eq(Residents.chatter()[0]["id"], "res.chat.3.0", "then the next that fits")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	ok(not Residents.chatter(rng).is_empty(), "then any of them")
	eq(Residents.opinion(&"grep", &"hotfix")[0]["id"], "res.grep.of.hotfix", "Grep on Hotfix")
	eq(Residents.opinion(&"grep", &"cache"), [], "not on someone who hasn't moved in")
	for c in Residents.CHATTER:
		ok((c["lines"] as Array).size() >= 2 and (c["lines"] as Array).size() <= 3, "chatter is 2-3 lines")
		for l in c["lines"]:
			ok(String(l[1]).length() <= BUBBLE, "fits a bubble: %s" % l[1])
	Residents._mem = {}
