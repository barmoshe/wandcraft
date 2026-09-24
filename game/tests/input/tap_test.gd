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
	SaveGame.enabled = false
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
	_check(s is TitleScreen, "the title screen is open")
	if s == null:
		return _done()
	print("window %s  viewport %s  screen rect %s" % [DisplayServer.window_get_size(), root.get_visible_rect().size, s.get_global_rect()])
	await _frames(20)   # past the input guard
	var new_btn := _button_rect(s, "new")
	_check(new_btn.size != Vector2.ZERO, "NEW RUN is registered")
	await _tap(new_btn.get_center())
	await _frames(5)
	var after: Variant = main.get("screen")
	print("screen after tap: ", after)
	_check(after == null or not (after is TitleScreen), "tapping NEW RUN closes the title")
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
	# the wand editor: drag the first spell two slots to the right
	await _tap((hud.buttons["edit"] as Rect2).get_center())
	await _frames(20)
	s = main.get("screen")
	_check(s is EditorScreen, "the HUD wands button opens the editor")
	if s is EditorScreen:
		var w: WandState = world.run.wands[0]
		var first: Variant = w.slots[0]
		var a := _button_rect(s, "slot:0:0").get_center()
		var b := _button_rect(s, "slot:0:2").get_center()
		await _drag(a, b)
		_check(w.slots[2] != null and first != null and w.slots[2]["id"] == first["id"], "dragging a spell moves it to another slot")
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
	_done()


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
