extends Node
## Real-input test: boots the real main scene in a real window at a phone size and taps menu
## buttons with InputEventScreenTouch through Input.parse_input_event, the same path a phone's
## touches take (including Godot's touch-to-mouse emulation). Unit tests call Screen.press()
## directly and never exercise this path; this test exists because 0.3.0 shipped with menus
## that ignored taps on real phones.
## Run: tools/taptest.sh (needs xvfb). It is a scene, not a -s script, so autoloads exist.

var failures := 0
var main: Node
var root: Window
## Touch id per gesture. Android and desktop number fingers from 0, but iPhone Safari (the
## web build) gives every touch a large new id that can wrap negative in Godot's 32-bit
## index, so "--ios" mode uses ids like that.
var _ios := false
var _next_id := -1294967296


func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


func _run() -> void:
	SaveGame.in_memory = true   # a first-time player, the same on every machine
	var rotate := OS.get_cmdline_user_args().has("--rotate")
	_ios = OS.get_cmdline_user_args().has("--ios")
	if rotate:
		# start in portrait, then turn to landscape like a phone does at launch
		DisplayServer.window_set_size(Vector2i(1080, 2340))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _frames(10)
	if rotate:
		DisplayServer.window_set_size(Vector2i(2340, 1080))
		await _frames(10)
	var s: Screen = main.get("screen")
	_check(s is TitleCard, "the title card is open")
	if s == null:
		return _done()
	print("window %s  viewport %s  screen rect %s" % [DisplayServer.window_get_size(), root.get_visible_rect().size, s.get_global_rect()])
	await _frames(20)   # past the input guard
	var play_btn := _button_rect(s, "play")
	_check(play_btn.size != Vector2.ZERO, "TAP TO PLAY is registered")
	await _tap(play_btn.get_center())
	await _frames(5)
	var after: Variant = main.get("screen")
	print("screen after tap: ", after)
	_check(after == null or not (after is TitleCard), "a tap closes the title card")
	# a first launch opens the story's intro (research/story.md); SKIP goes on to the lessons
	_check(after is StoryScreen, "a first launch opens the intro")
	if after is StoryScreen:
		await _frames(20)   # past the input guard
		await _tap(_button_rect(after, "skip").get_center())
		await _frames(5)
	_check(bool(main.get("_playing")), "tapping NEW RUN starts a run")
	await _frames(30)
	var hud: Hud = main.get("hud")
	var world: World = main.get("world")
	# pause through the HUD button (TouchControls path), then RESUME (Screen path)
	await _tap((hud.buttons["pause"] as Rect2).get_center())
	await _frames(20)
	s = main.get("screen")
	_check(s is PauseScreen, "the HUD pause button opens pause")
	if s is PauseScreen:
		await _tap(_button_rect(s, "resume").get_center())
		await _frames(5)
		_check(main.get("screen") == null and not world.paused, "RESUME closes pause")
	# the move stick: hold a thumb on the left half and slide it right, the hero walks
	var v := root.get_visible_rect().size
	var p0 := world.player.global_position
	await _drag(Vector2(v.x * 0.2, v.y * 0.6), Vector2(v.x * 0.2 + 40.0, v.y * 0.6), 30)
	_check(world.player.global_position.x > p0.x + 4.0, "the left stick moves the hero (%.1f px)" % (world.player.global_position.x - p0.x))
	# D9: the DASH button, drawn on touch screens
	await _frames(2)
	_check(hud.buttons.has("dash"), "the DASH button is drawn on a touch screen")
	if hud.buttons.has("dash"):
		await _tap((hud.buttons["dash"] as Rect2).get_center())
		await _frames(2)
		_check(world.player.dash_cd > 0.0, "tapping DASH dashes")
	# the wand editor: drag the start spell (in the last slot) two slots to the left
	await _tap((hud.buttons["edit"] as Rect2).get_center())
	await _frames(20)
	s = main.get("screen")
	_check(s is EditorScreen, "the HUD wands button opens the editor")
	if s is EditorScreen:
		var w: WandState = world.run.wands[0]
		var first: Variant = w.slots[2]
		var a := _button_rect(s, "slot:0:2").get_center()
		var b := _button_rect(s, "slot:0:0").get_center()
		await _drag(a, b)
		_check(w.slots[0] != null and first != null and w.slots[0]["id"] == first["id"], "dragging a spell moves it to another slot")
		await _tap(_button_rect(s, "done").get_center())
		await _frames(5)
		_check(main.get("screen") == null, "DONE closes the editor")
	# a reward screen: pick a card, then TAKE
	var offer := Rewards.offer(world.run, &"spell")
	main.call("_on_ui_request", &"reward", {"kind": &"spell", "offer": offer})
	await _frames(20)
	s = main.get("screen")
	_check(s is RewardScreen, "a reward screen opens")
	if s is RewardScreen:
		var bag_before := world.run.bag.size() + _filled(world.run)
		await _tap(_button_rect(s, "card0").get_center())
		await _tap(_button_rect(s, "take").get_center())
		await _frames(5)
		_check(main.get("screen") == null, "TAKE closes the reward screen")
		_check(world.run.bag.size() + _filled(world.run) > bag_before, "TAKE grants the spell")
	# desktop: a real (non-emulated) mouse click works too
	main.call("_open_pause", false)
	await _frames(20)
	s = main.get("screen")
	if s is PauseScreen:
		var wp: Vector2 = root.get_final_transform() * _button_rect(s, "resume").get_center()
		for pressed in [true, false]:
			var m := InputEventMouseButton.new()
			m.button_index = MOUSE_BUTTON_LEFT
			m.pressed = pressed
			m.position = wp
			m.global_position = wp
			Input.parse_input_event(m)
			await _frames(2)
		_check(main.get("screen") == null, "a mouse click on RESUME closes pause")
	await _hub_phase()
	_done()


## The Workshop (0.19): walk up to the Terminal, USE it, BACK; MENU, the portal, NEW RUN.
func _hub_phase() -> void:
	var m := SaveGame.load_meta()
	m["runs"] = 1
	m["tutorial_done"] = true
	SaveGame.save_meta(m)
	main.call("_show_hub", false)
	await _frames(20)
	var world: World = main.get("world")
	var hud: Hud = main.get("hud")
	_check(world.hub != null and bool(main.get("_hub")), "the Workshop opens")
	if world.hub == null:
		return
	world.player.position = (world.hub.anchors["terminal"][0] as Vector2) + Vector2(-14, 8)
	await _frames(10)
	_check(world.hub.near == "terminal" and hud.buttons.has("use"), "USE shows by the Terminal")
	if hud.buttons.has("use"):
		await _tap((hud.buttons["use"] as Rect2).get_center())
		await _frames(20)
		var s: Variant = main.get("screen")
		_check(s is PauseScreen and s.hub, "USE opens the Terminal")
		if s is PauseScreen:
			await _tap(_button_rect(s, "resume").get_center())
			await _frames(5)
	await _tap((hud.buttons["menu"] as Rect2).get_center())
	await _frames(20)
	var menu: Variant = main.get("screen")
	_check(menu is HubMenu, "MENU lists the stations")
	if menu is HubMenu:
		await _tap(_button_rect(menu, "portal").get_center())
		await _frames(25)
		var sheet: Variant = main.get("screen")
		_check(sheet is RunSheet, "the menu's Portal opens the run sheet")
		if sheet is RunSheet:
			await _tap(_button_rect(sheet, "new").get_center())
			await _frames(10)
			_check(bool(main.get("_playing")) and not bool(main.get("_hub")) and world.hub == null, "NEW RUN leaves the Workshop for a run")


func _filled(run: RunState) -> int:
	var n := 0
	for w in run.wands:
		for sl in w.slots:
			if sl != null:
				n += 1
	return n


func _gesture_id() -> int:
	if not _ios:
		return 0
	_next_id += 13
	return _next_id


func _drag(a: Vector2, b: Vector2, hold_frames := 0) -> void:
	var tf := root.get_final_transform()
	var id := _gesture_id()
	var t := InputEventScreenTouch.new()
	t.index = id
	t.position = tf * a
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(2)
	for k in range(1, 9):
		var d := InputEventScreenDrag.new()
		d.index = id
		d.position = tf * a.lerp(b, k / 8.0)
		d.relative = tf.basis_xform((b - a) / 8.0)
		Input.parse_input_event(d)
		await _frames(1)
	await _frames(hold_frames)
	var u := InputEventScreenTouch.new()
	u.index = id
	u.position = tf * b
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(3)


func _button_rect(s: Screen, id: String) -> Rect2:
	for b in s._buttons:
		if b[1] == id:
			return b[0]
	return Rect2()


## Taps a point given in the game's 480x270-ish canvas coordinates.
func _tap(canvas_pos: Vector2, hold_frames := 3) -> void:
	var wp: Vector2 = root.get_final_transform() * canvas_pos
	var id := _gesture_id()
	var t := InputEventScreenTouch.new()
	t.index = id
	t.position = wp
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(hold_frames)
	var u := InputEventScreenTouch.new()
	u.index = id
	u.position = wp
	u.pressed = false
	Input.parse_input_event(u)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(cond: bool, msg: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + msg)
	if not cond:
		failures += 1


func _done() -> void:
	print("TAPTEST: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)
