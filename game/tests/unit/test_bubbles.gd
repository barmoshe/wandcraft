extends "res://tests/unit/world_fixture.gd"
## 0.21: speech bubbles over the speaker's head (ui/bubbles.gd) and the Duck and LINT walking
## the runs with you (world/companion.gd). No rendering: anchors, wrap, timing, layout and
## following are checked as numbers.


func test_the_duck_and_lint_speak_from_their_companions_in_a_run() -> void:
	eq(world.companions.size(), 2, "two companions")
	for c in world.companions:
		ok(c.visible, "%s walks the run" % c.kind)
	var d := Bubbles.anchor(world, Story.DUCK)
	var l := Bubbles.anchor(world, Story.LINT)
	ok(d != Vector2.INF and l != Vector2.INF, "both have a head to talk from")
	ok(d.y < world.companions[0].position.y and l.y < world.companions[1].position.y, "over their heads")
	eq(Bubbles.anchor(world, Residents.GREP), Vector2.INF, "a resident with no body here falls back to the box")
	eq(Bubbles.anchor(world, "NOBODY"), Vector2.INF, "and so does an unknown voice")


func test_a_caged_resident_speaks_from_the_cage() -> void:
	world.cage = {"pos": Vector2(200, 120), "who": &"cache", "open": true, "t": 0.0}
	var a := Bubbles.anchor(world, Residents.CACHE)
	ok(a != Vector2.INF, "the cage has a speaker")
	ok(absf(a.x - 200.0) < 0.5 and a.y < 120.0, "over the resident's head (%s)" % a)


func test_in_the_workshop_they_speak_from_their_spots() -> void:
	world.enter_hub(world.run)
	for c in world.companions:
		ok(not c.visible, "no companions in the Workshop: the fixed ones stand there")
	var d := Bubbles.anchor(world, Story.DUCK)
	eq(d, (world.hub.anchors["duck"][0] as Vector2) + Vector2(0, -10), "the Duck's spot")
	ok(Bubbles.anchor(world, Story.LINT) != Vector2.INF, "LINT's spot")


func test_lines_wrap_short_and_type_out_in_time() -> void:
	var f := Game.font("small")
	var s := "Quack. That wand reads left to right, and so does the bug that broke it. Twice."
	var two := Bubbles.lines_for(f, s, 2)
	ok(two.size() <= 2, "at most two lines in a fight")
	for ln in two:
		ok(f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x <= Bubbles.WIDE + 0.5, "each fits (%s)" % ln)
	ok(Bubbles.lines_for(f, "Hi.", 3).size() == 1, "a short line is one line")
	var dur := Dialogue.read_time(s)
	var prev := -1
	for k in 20:
		var n := Bubbles.shown_chars(dur * k / 20.0, s.length(), dur)
		ok(n >= prev, "the typewriter never goes back")
		prev = n
	eq(Bubbles.shown_chars(dur * 0.6, s.length(), dur), s.length(), "all out by 60% of the line's time")
	eq(Bubbles.alpha(dur, dur), 0.0, "gone when the line ends")
	ok(Bubbles.alpha(dur * 0.5, dur) > 0.99, "solid while it's read")
	ok(dur >= 1.5 and Dialogue.read_time("Ok") >= 1.5, "every line stays up at least 1.5 s")


func test_the_bubble_keeps_clear_of_the_hud_and_the_edges() -> void:
	var sr := Rect2(0, 0, 480, 270)
	var size := Vector2(120, 35)
	var lay := Bubbles.layout(Vector2(240, 150), size, sr, [])
	var r: Rect2 = lay["rect"]
	ok(r.end.y <= 150.0 - Bubbles.TAIL + 0.5, "above the head")
	ok(not lay["pinned"], "not pinned")
	# the head near the top: it flips under the speaker
	var top := Bubbles.layout(Vector2(240, 20), size, sr, [])
	ok((top["rect"] as Rect2).position.y > 20.0 and top["tail_up"], "flips below when there is no room above")
	# a HUD panel where it would go: it steps around it
	var panel := Rect2(160, 100, 160, 20)
	var around := Bubbles.layout(Vector2(240, 150), size, sr, [panel])
	ok(not (around["rect"] as Rect2).intersects(panel), "never on a HUD panel")
	# near the right edge: clamped inside
	var edge := Bubbles.layout(Vector2(475, 150), size, sr, [])
	ok(sr.encloses(edge["rect"]), "inside the screen")
	# off screen: pinned at the edge, arrow toward the speaker
	var off := Bubbles.layout(Vector2(700, 150), size, sr, [])
	ok(off["pinned"] and sr.encloses(off["rect"]), "pinned inside")
	ok((off["arrow"] as Vector2).x > 0.5, "the arrow points to the speaker (right)")


func test_the_bubble_leans_away_from_the_hero() -> void:
	var sr := Rect2(0, 0, 480, 270)
	var lay := Bubbles.layout(Vector2(250, 150), Vector2(120, 35), sr, [], Vector2(240, 170))
	ok((lay["rect"] as Rect2).get_center().x > 250.0, "a companion right of the hero talks to the right")


func test_companions_follow_and_never_stand_in_walls() -> void:
	world.build_room("hall", &"empty")
	var p0 := world.player.position
	for k in 180:
		world.player.position = p0 + Vector2(sin(k / 30.0) * 60.0, cos(k / 45.0) * 30.0)
		world.step(DT)
		for c in world.companions:
			ok(c.position.distance_to(world.player.position) <= Companion.LEASH + 0.5, "%s stays close" % c.kind)
	for c in world.companions:
		ok(not world.body_solid_at(c.position) or c.kind == &"lint", "the Duck never stands in a wall")
		ok(not world.enemies.has(c), "never an enemy: shots pass through")


func test_companions_arrive_with_you_in_a_new_room() -> void:
	world.build_room("hall", &"empty")
	for c in world.companions:
		ok(c.position.distance_to(world.player.position) < Companion.GAP + 10.0, "%s is at your side when the room opens" % c.kind)


func test_dialogue_drops_a_walked_away_talk_and_keeps_exchanges_fresh() -> void:
	Dialogue.clear()
	Dialogue.enqueue(Residents.GREP, "one", "res.grep.arc.0.0")
	Dialogue.enqueue(Residents.GREP, "two", "res.grep.arc.0.1")
	Dialogue.enqueue(Story.DUCK, "quack", "hub_duck")
	Dialogue.drop_prefix("res.grep.")
	eq(Dialogue._queue.size(), 1, "the rest of Grep's talk is dropped")
	eq(String(Dialogue._queue[0]["id"]), "hub_duck", "the Duck's line stays")
	eq(Dialogue.group("res.grep.arc.0.1"), "res.grep.arc.0", "an exchange is its id without the last part")
	Dialogue.clear()


func test_lints_red_squiggle_marks_the_toughest_and_it_takes_more() -> void:
	world.build_room("hall", &"empty")
	world.cleared = false
	var small := _dummy(Vector2(120, 120))
	var big := _dummy(Vector2(260, 120))
	small.max_hp = 500.0
	small.hp = 500.0
	world._squiggle = true   # the trick, unlocked (Barks.lint_trick)
	_steps(2.2)
	ok(big.squiggle and not small.squiggle, "the toughest one is underlined")
	var a := world.hurt_enemy(small, 10.0, small.position, 0.0, 0.0)
	var b := world.hurt_enemy(big, 10.0, big.position, 0.0, 0.0)
	ok(b > a, "and takes more from you (%.1f vs %.1f)" % [b, a])


func test_the_companions_react_to_a_fast_room() -> void:
	var said: Array = []
	var cb := func(who: String, text: String, _id: String) -> void: said.append(who)
	Events.say.connect(cb)
	Barks.reset()
	world.build_room("hall", &"fight")
	world.room_time = 4.0
	world.call("_clear_room")
	Events.say.disconnect(cb)
	ok(not said.is_empty(), "a quick clear gets a line (%s)" % [said])
