extends "res://tests/unit/test_helpers.gd"
## Barks (story round 2): rules over facts, priority, once, cooldowns, carry-over, no
## immediate repeats, the post-mortem and LINT's code smells.


func setup(_t: SceneTree) -> void:
	SaveGame.enabled = false
	Story._mem = {}
	Residents._mem = {}
	Barks.reset()


func teardown() -> void:
	Story._mem = {}
	Residents._mem = {}
	Barks.reset()
	SaveGame.enabled = true


func _rule(lines: Array) -> String:
	return "" if lines.is_empty() else String(lines[0][2]).get_slice(".", 1)


func test_criteria() -> void:
	ok(Barks.holds({"hp": ["<", 0.3]}, {"hp": 0.2}), "< holds")
	ok(not Barks.holds({"hp": ["<", 0.3]}, {"hp": 0.5}), "< fails")
	ok(not Barks.holds({"hp": ["<", 0.3]}, {}), "a missing number never compares")
	ok(Barks.holds({"rule": ["!=", ""]}, {"rule": "shuffle"}), "!= holds")
	ok(not Barks.holds({"rule": ["!=", ""]}, {"rule": ""}), "!= fails")
	ok(Barks.holds({"won": false}, {}), "a missing flag is false")
	ok(not Barks.holds({"won": true}, {}), "so true needs it")
	ok(Barks.holds({"boss": "Deadlock"}, {"boss": &"Deadlock"}), "a StringName matches its String")
	ok(Barks.holds({"world": 1}, {"world": 1.0}), "JSON's floats match ints")
	ok(Barks.holds({"status": ["in", ["burn", "rot"]]}, {"status": "rot"}), "in holds")
	ok(not Barks.holds({"status": ["in", ["burn", "rot"]]}, {"status": "frost"}), "in fails")


func test_priority_and_specificity() -> void:
	eq(_rule(Barks.pick(&"big_hit", {"dmg": 70}, 0.0)), "big_hit", "a big hit")
	Barks.reset()
	eq(_rule(Barks.pick(&"big_hit", {"dmg": 200}, 0.0)), "big_hit_huge", "a huge one outranks it")
	Barks.reset()
	eq(Barks.pick(&"big_hit", {"dmg": 10}, 0.0), [], "a small hit matches nothing")
	eq(_rule(Barks.pick(&"low_hp", {"hp": 0.2, "boss": true}, 0.0)), "low_hp_boss", "at a boss, the boss rule")
	Barks.reset()
	eq(_rule(Barks.pick(&"boss_phase", {"boss": "Deadlock", "phase": 2}, 0.0)), "phase_deadlock", "the boss's own line beats the generic")
	Barks.reset()
	eq(_rule(Barks.pick(&"boss_phase", {"boss": "Someone", "phase": 3}, 0.0)), "phase_last", "else the phase's")
	eq(Barks.pick(&"no_such_event", {}, 0.0), [], "an unknown event says nothing")


func test_in_order_then_no_immediate_repeats() -> void:
	var r: Dictionary = Barks.RULES.filter(func(x: Dictionary) -> bool: return x["id"] == "elite_kill")[0]
	for i in (r["lines"] as Array).size():
		eq(Barks.pick(&"elite_kill", {"elites": 1}, 20.0 * i), Barks.entry(r, i), "entry %d in order" % i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := {}
	for k in 40:
		var got := Barks.pick(&"elite_kill", {"elites": 1}, 100.0 + 20.0 * k, rng)
		ok(not got.is_empty(), "then one every time (%d)" % k)
		if got.is_empty():
			continue
		var who: String = got[0][0]
		ok(last.get(who, "") != got[0][2], "never the same line twice running: %s" % got[0][2])
		last[who] = got[0][2]


func test_cooldowns() -> void:
	ok(not Barks.pick(&"elite_kill", {}, 0.0).is_empty(), "a bark")
	eq(Barks.pick(&"mana_empty", {}, 1.0), [], "nothing inside the global cooldown")
	eq(Barks.pick(&"mana_empty", {}, 4.0), [], "the Duck waits out its own (its turn first)")
	ok(not Barks.pick(&"mana_empty", {}, 9.0).is_empty(), "then it speaks")
	ok(not Barks.pick(&"boss_phase", {"phase": 2}, 9.5).is_empty(), "a boss phase ignores cooldowns")
	Barks.stash({"won": false})
	ok(not Barks.hub_return(9.6).is_empty(), "and the Workshop's post-mortem too")


func test_once_and_memory() -> void:
	Barks.stash({"won": true, "first_win": true})
	eq(_rule(Barks.hub_return(0.0)), "pm_first_win", "the first win, framed")
	eq(Barks.recall("framed"), true, "and remembered")
	Barks.stash({"won": true, "first_win": true})
	eq(_rule(Barks.hub_return(10.0)), "pm_win_wall", "once: never again, and the memory calls back")
	eq(Barks.hub_return(20.0), [], "the stash is used once")


func test_carry_over() -> void:
	ok(not Barks.pick(&"room_fast", {"time": 8.0}, 0.0).is_empty(), "a quick room")
	eq(Barks.pick(&"elite_kill", {"elites": 2}, 1.0), [], "an elite falls while the Duck is cooling")
	eq(Barks.pick(&"elite_kill", {"elites": 3}, 1.5), [], "and another")
	eq(Barks.pick(&"mana_empty", {}, 2.0), [], "an empty wand too")
	var c := Barks.carried()
	eq(c.map(func(x: Dictionary) -> String: return x["event"]), ["elite_kill"], "the elite is saved once; mana isn't carried")
	eq(int(c[0]["elites"]), 2, "with its facts")
	eq(_rule(Barks.carry_over(0.0)), "carry_elite", "the Workshop brings it up")
	eq(Barks.carried(), [], "then it's cleared")
	eq(Barks.carry_over(0.0), [], "nothing left")


func test_post_mortem() -> void:
	var run := RunState.create(3)
	run.world = 0
	run.step = Chapter.PLAN.size() - 1
	var f := Barks.run_facts(run, "touch:The Infinite Loop", false, {"runs": 2, "wins": 0, "best_step": 4})
	eq(f["died_to"], "The Infinite Loop", "died to the Loop")
	eq(f["died_how"], "touch", "by touch")
	ok(f["died_boss"], "at a boss")
	ok(f["record"], "deeper than ever")
	ok(not f["first_win"], "not a win")
	eq(f["rule"], "", "no wand rule")
	Barks.stash(f)
	eq(_rule(Barks.hub_return(0.0)), "pm_record", "a record outranks the boss")
	f["record"] = false
	Barks.stash(f)
	eq(_rule(Barks.hub_return(10.0)), "pm_same", "the same killer twice")
	Barks.stash(f)
	eq(_rule(Barks.hub_return(20.0)), "pm_nemesis", "three times: a nemesis")
	var run2 := RunState.create(4, &"apprentice")
	run2.won = true
	run2.heat = 2
	var w := Barks.run_facts(run2, "", false, {"runs": 5, "wins": 0})
	ok(w["first_win"] and w["died_to"] == "", "a first win")
	Story._mem["packs"] = ["glitch"]
	Barks.stash(w)
	eq(_rule(Barks.hub_return(30.0)), "pm_first_win", "the first win first")
	var q := Barks.run_facts(RunState.create(5), "shot:moss", true, {"runs": 5})
	ok(q["quit"] and q["died_to"] == "", "a quit names no killer")
	Barks.stash(q)
	eq(_rule(Barks.hub_return(40.0)), "pm_quit", "a quit")
	Story._mem["packs"] = ["glitch", "flow"]
	Barks.stash({"won": false, "world": 1})
	eq(_rule(Barks.hub_return(50.0)), "pm_pack", "a new pack, asked about")


func test_smells() -> void:
	var kinds := func(w: WandState) -> Array: return Story.smells(w).map(func(s: Dictionary) -> String: return "%s@%d" % [s["smell"], s["slot"]])
	eq(kinds.call(wand(["mote", "mote", "mote", null, null])), ["copy3@2"], "the same spell three times")
	eq(kinds.call(wand(["empower", "mote", null, "mote", "empower"])), ["gap@2", "boost_tail@4"], "a gap, and a boost at the end")
	eq(kinds.call(wand(["mote", "then", null, null, null])), ["trig_tail@1"], "a trigger calling nothing")
	eq(kinds.call(wand(["empower", "twin", null, null, null])), ["no_spell@-1", "boost_tail@0", "boost_tail@1"], "nothing shoots")
	eq(kinds.call(wand([null, null, "empower", "mote", "spark"])), [], "a clean wand")
	eq(kinds.call(wand([])), [], "an empty wand says nothing")
	eq(kinds.call(wand(["mote", "empower", null, null, null], &"palindrome")), [], "a palindrome reads back, so the boost is fed")
	var w := wand(["mote", "mote", "mote", null, "empower"])
	var before := w.slots.duplicate(true)
	Story.smells(w)
	eq(w.slots, before, "read-only")


func test_lint_arc() -> void:
	var bad := wand(["mote", "empower", null, null, null])
	eq(_rule(Barks.lint_review(bad, 0.0)), "smell_boost_tail", "LINT flags the boost")
	eq(Barks.lint_review(bad, 1.0), [], "once, unless asked")
	eq(_rule(Barks.lint_review(bad, 2.0, true)), "smell_boost_tail", "asked, it says it again")
	eq(_rule(Barks.lint_review(wand(["empower", "mote"]), 3.0)), "lint_fixed", "fixed: advice followed")
	eq(Barks.lint_fixes(), 1, "counted")
	eq(_rule(Barks.lint_review(wand(["empower", null, "mote"]), 4.0)), "smell_gap", "the next smell")
	eq(_rule(Barks.lint_review(wand(["empower", "mote"]), 5.0)), "lint_fixed", "fixed")
	ok(not Barks.lint_trick(), "no trick yet")
	eq(_rule(Barks.lint_review(wand(["mote", "then"]), 6.0)), "smell_trig_tail", "a third")
	var got := Barks.lint_review(wand(["mote", "then", "spark"]), 7.0)
	eq(_rule(got), "lint_trick", "the third fix unlocks the trick")
	ok(Barks.lint_trick(), "remembered")
	eq(_rule(Barks.lint_review(wand([null, "mote"]), 8.0, true)), "lint_clean", "a clean wand, asked")


func test_every_bark_is_short_known_and_unique() -> void:
	var ids := {}
	for r in Barks.RULES:
		ok(not ids.has(r["id"]), "%s is unique" % r["id"])
		ids[r["id"]] = true
		ok(Barks.EVENTS.has(StringName(r["event"])), "%s: a known event" % r["id"])
		var cap := Barks.COMBAT_MAX if Barks.COMBAT.has(StringName(r["event"])) else Barks.BUBBLE_MAX
		for i in (r["lines"] as Array).size():
			for l in Barks.entry(r, i):
				ok(Story.SPEAKERS.has(l[0]), "%s: a known speaker" % l[2])
				ok(String(l[1]).length() <= cap, "%s fits a bubble (%d > %d): %s" % [l[2], String(l[1]).length(), cap, l[1]])
				ok(not String(l[1]).contains("—"), "%s has no em dash" % l[2])
	for ev in Barks.COMBAT:
		var rules := Barks.RULES.filter(func(r: Dictionary) -> bool: return r["event"] == ev)
		var n := 0
		var who := {}
		for r in rules:
			n += (r["lines"] as Array).size()
			for i in (r["lines"] as Array).size():
				who[Barks.entry(r, i)[0][0]] = true
		ok(n >= 3, "%s has 3 or more lines (%d)" % [ev, n])
		ok(who.has(Story.DUCK) and who.has(Story.LINT), "%s: the Duck and LINT both" % ev)
	var pm := 0
	for r in Barks.RULES:
		if r["event"] == &"hub_return":
			pm += (r["lines"] as Array).size()
	ok(pm >= 15, "15 or more post-mortem entries (%d)" % pm)
