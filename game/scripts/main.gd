extends Node2D
## Builds the game in code: glow environment, world, camera, HUD and touch controls.
## Desktop testing: WASD/arrows move, hold the left mouse button to aim and fire,
## 1/2 pick a wand, F toggles auto-fire. Gamepads: sticks, LB/RB switch wands.
##
## Command-line options (after `--`):
##   --demo              a bot plays (for screenshots and soak runs)
##   --seed=N            run seed
##   --room=hall|cross|pillars  --kind=fight|elite|treasure
##   --shot=out.png --frames=N   save a screenshot after N frames, then quit
##   --touchdemo         draw sample thumbs on the sticks (store screenshots)
##   --wand=N            start with wand N selected
##   --showcase          a staged fight (enemies placed, unlimited mana) for screenshots

var world: World
var hud: Hud
var touch: TouchControls
var cam: Camera2D
var _args: Dictionary = {}
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_build_environment()
	world = World.new()
	add_child(world)
	world.setup(int(_args.get("seed", "7")))
	world.bot = _args.has("demo")
	if _args.has("demo"):
		Game.god_mode = true
	world.new_run()
	if _args.has("room") or _args.has("kind"):
		world.room_no = 0
		world.build_room(_args.get("room", "hall"), StringName(_args.get("kind", "fight")))
	if _args.has("showcase"):
		_showcase()
	if _args.has("wand"):
		world.player.cur = clampi(int(_args["wand"]) - 1, 0, world.player.wands.size() - 1)
	cam = Camera2D.new()
	cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(cam)
	cam.make_current()
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Hud.new()
	hud.world = world
	ui.add_child(hud)
	touch = TouchControls.new()
	touch.controls = world.controls
	touch.hud = hud
	ui.add_child(touch)
	if _args.has("touchdemo"):
		var v := get_viewport_rect().size
		touch.touched_once = true
		touch.set("_move_id", 90)
		touch.set("_move_origin", Vector2(70, v.y - 60))
		touch.set("_move_pos", Vector2(84, v.y - 70))
		touch.set("_aim_id", 91)
		touch.set("_aim_origin", Vector2(v.x - 110, v.y - 70))
		touch.set("_aim_pos", Vector2(v.x - 96, v.y - 84))


func _showcase() -> void:
	world.bot = true
	Game.god_mode = true
	Game.inf_mana = true
	world.waves_left = 0
	var c := world.player.position
	var spots := [[&"slime", Vector2(-70, -60)], [&"weaver", Vector2(40, -110)], [&"ram", Vector2(110, -40)],
		[&"slime", Vector2(-120, -20)], [&"sentry", Vector2(150, -120)], [&"weaver", Vector2(-40, -130)],
		[&"slime", Vector2(70, -80)], [&"ram", Vector2(-150, -100)]]
	for s in spots:
		var p: Vector2 = c + s[1]
		if world.solid_at(p):
			continue
		var e := world.spawn_enemy(s[0], p)
		e.spawn_t = 0.0
		e.sprite.visible = true
		e.max_hp *= 8.0
		e.hp = e.max_hp


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	# LDR glow (hdr_2d is off: it broke 2D lights in the renderer spike, see STATUS.md);
	# only the brightest pixels (spell cores, flames, sparks) cross the threshold
	env.glow_hdr_threshold = 0.72
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, i >= 1 and i <= 4)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(_dt: float) -> void:
	_read_desktop_input()
	_follow_camera()
	_frames += 1
	if _args.has("shot") and _frames == int(_args.get("frames", "90")):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(_args["shot"])
		print("shot: room %d %s player %s hp %d visible %s | enemies %s" % [world.room_no, world.room_kind, world.player.position.round(), world.player.hp, world.player.sprite.visible,
			world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).map(func(e: Enemy) -> String: return "%s@%s" % [e.kind, e.position.round()])])
		get_tree().quit()


## The room plus padding for the HUD (wand rows on top, vitals at the bottom) is what the
## camera frames: centered when it fits, following the player when it does not.
const PAD_TOP := 58.0
const PAD_BOTTOM := 30.0
const PAD_SIDE := 10.0


func _follow_camera() -> void:
	var view := get_viewport_rect().size
	var room := world.room_size()
	var p := world.player.position
	var lo := Vector2(-PAD_SIDE, -PAD_TOP)
	var hi := room + Vector2(PAD_SIDE, PAD_BOTTOM)
	var c := Vector2.ZERO
	for ax in 2:
		if hi[ax] - lo[ax] <= view[ax]:
			c[ax] = (lo[ax] + hi[ax]) / 2.0
		else:
			c[ax] = clampf(p[ax], lo[ax] + view[ax] / 2.0, hi[ax] - view[ax] / 2.0)
	var s := world.shake_amt * 14.0
	cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s)).round()
	cam.position = cam.position.lerp(c, 0.2).round() if _frames > 1 else c.round()


func _read_desktop_input() -> void:
	if world.bot or touch.touched_once:
		return
	var c := world.controls
	var mv := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var pad_move := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var pad_aim := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	c.move = mv.normalized() if mv != Vector2.ZERO else (pad_move if pad_move.length() > 0.2 else Vector2.ZERO)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		c.aim = (world.get_local_mouse_position() - world.player.position).normalized()
	elif pad_aim.length() > 0.3:
		c.aim = pad_aim
	else:
		c.aim = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1:
				world.controls.select_wand = 0
			KEY_2:
				world.controls.select_wand = 1
			KEY_F:
				Game.auto_fire = not Game.auto_fire
				Events.toast.emit("Auto-fire %s" % ("on" if Game.auto_fire else "off"))
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			world.controls.select_wand = (world.player.cur + 1) % world.player.wands.size()
