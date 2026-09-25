extends Node2D
## Builds the game in code (glow environment, world, camera, HUD, touch controls) and runs
## the app flow: title -> run (room by room) -> reward / shop / forge / editor / pause
## screens -> victory or defeat -> title.
## Desktop testing: WASD/arrows move, hold the left mouse button to aim and fire,
## 1/2/3 pick a wand, Tab/E opens the wand editor, Esc pauses, F toggles auto-fire.
## Gamepads: sticks, LB/RB switch wands, Start pauses, Select opens the editor.
##
## Command-line options (after `--`):
##   --demo              skip the title; a bot plays (god mode) and answers every screen
##   --showcase          a staged fight (enemies placed, unlimited mana) for screenshots
##   --seed=N            run seed
##   --step=N --kind=K   start at chapter step N in a room of kind K (fight, shop, boss...)
##   --loadout=strong    a strong late-run build (for boss screenshots)
##   --screen=S          open a screen right away: reward, shop, forge, editor, pause, title, end
##   --coach=N           with --screen=editor: the tutorial coach for lesson N (1-3)
##   --shot=out.png --frames=N   save a screenshot after N frames, then quit
##   --touchdemo         draw sample thumbs on the sticks (store screenshots)
##   --wand=N            start with wand N selected
##   --resethints        show the first-run tips again

var world: World
var hud: Hud
var touch: TouchControls
var cam: Camera2D
var screen: Screen
var _screens: CanvasLayer
var _args: Dictionary = {}
var _frames := 0
var _playing := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.has("resethints"):
		Hints.reset()
	_build_environment()
	world = World.new()
	add_child(world)
	world.setup(int(_args.get("seed", "7")))
	world.ui_request.connect(_on_ui_request)
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
	touch.hud_pressed.connect(_on_hud)
	ui.add_child(touch)
	_build_shockwave()
	Events.shockwave.connect(_on_shockwave)
	_screens = CanvasLayer.new()
	_screens.layer = 20
	add_child(_screens)
	if OS.has_feature("web"):
		var rot := CanvasLayer.new()
		rot.layer = 100
		add_child(rot)
		rot.add_child(RotateHint.new())
	var direct := _args.has("demo") or _args.has("showcase") or _args.has("step") or _args.has("kind") or _args.has("screen")
	if direct and _args.get("screen", "") != "title":
		_start_from_args()
	else:
		_show_title()


# ------------------------------------------------------------------ flow

func _show_title() -> void:
	_playing = false
	hud.visible = false
	touch.enabled = false
	world.visible = false
	Audio.music("title")
	var t := TitleScreen.new()
	_open(t, func(res: Dictionary) -> void:
		if res.get("action") == "credits":
			_open(CreditsScreen.new(), func(_r: Dictionary) -> void: _show_title())
			return
		if res.get("action") == "continue":
			var r := SaveGame.load_run()
			if r:
				_begin(r)
				_open_pause(true)
				return
		_begin(_new_run()))


## A fresh run. A player's very first run is the curriculum (D9, Tutorial).
func _new_run() -> RunState:
	var r := RunState.create(int(Time.get_unix_time_from_system()) % 100000 + 1)
	var m := SaveGame.load_meta()
	r.tutorial = int(m.get("runs", 0)) == 0 and not bool(m.get("tutorial_done", false))
	return r


func _begin(r: RunState) -> void:
	world.visible = true
	hud.visible = true
	touch.enabled = true
	_playing = true
	world.start_run(r)
	_follow_camera(true)


func _start_from_args() -> void:
	var r := RunState.create(int(_args.get("seed", "7")))
	r.tutorial = _args.has("tutorial")
	if _args.has("demo") or _args.has("showcase"):
		world.bot = true
		Game.god_mode = true
	if _args.get("loadout", "") == "strong":
		_strong_loadout(r)
	elif _args.get("loadout", "") == "d3":
		# screenshots of D3: a Compile at the forge, a Merge Commit and Enables chips
		r.wands[0] = WandState.make(Catalog.wand(&"oak"), [&"mote", &"ember_coat"])
		r.wands[0].slots[2] = {"id": &"spark", "lv": 3}
		for id in [&"cascade_failure", &"wildfire", &"loop_counter", &"stack_trace", &"try_catch"]:
			r.add_relic(id)
		r.gold = 120
	elif _args.get("loadout", "") == "d2":
		# screenshots of the D2 spells: familiars, a Firewall, Bitrot and orbiting Motes
		r.wands[0] = WandState.make(Catalog.wand(&"oak"), [&"daemon", &"mote", &"turret", &"firewall", &"rot_coat", &"bitrot", &"orbit", &"mote"])
	if _args.has("step"):
		r.step = clampi(int(_args["step"]), 0, Chapter.PLAN.size() - 1)
	if _args.has("kind"):
		r.room = {"kind": StringName(_args["kind"]), "reward": &"spell"}
		var k := StringName(_args["kind"])
		if k == &"boss":
			r.step = Chapter.PLAN.size() - 1
		elif k == &"mini":
			r.step = 4
		elif r.step == 0:
			r.step = 1
	world.force_tpl = _args.get("room", "")
	_begin(r)
	if _args.has("showcase"):
		_showcase()
	if _args.has("wand"):
		r.cur = clampi(int(_args["wand"]) - 1, 0, r.wands.size() - 1)
	match _args.get("screen", ""):
		"reward":
			var ok_ := StringName(_args.get("offer", "spell"))
			_on_ui_request(&"reward", {"kind": ok_, "offer": Rewards.offer(r, ok_)})
		"shop":
			r.shop = Rewards.shop_stock(r)
			_on_ui_request(&"shop", {})
		"forge":
			_on_ui_request(&"forge", {})
		"editor":
			if _args.has("coach"):
				# screenshots: a lesson prize in the bag and the coached editor (--tutorial --coach=N)
				var lesson := int(_args["coach"])
				r.tutorial = true
				r.step = lesson
				if lesson >= 2:
					r.wand().set_slots([&"empower", &"mote", &"needle"] if lesson == 3 else [&"empower", &"mote", null])
				r.bag.append({"id": Tutorial.STEPS[lesson]["offer"][0], "lv": 1})
				Tutorial.on_prize(r, lesson)
				_open_editor(lesson)
			else:
				_open_editor()
		"map":
			_open_map()
		"pause":
			_open_pause(false)
		"credits":
			_open(CreditsScreen.new(), func(_r: Dictionary) -> void: pass)
		"end":
			world.paused = true
			_open_end(_args.get("won", "0") == "1")
	if _args.has("touchdemo"):
		var v := get_viewport_rect().size
		touch.touched_once = true
		touch.set("_moving", true)
		touch.set("_move_origin", Vector2(70, v.y - 60))
		touch.set("_move_pos", Vector2(84, v.y - 70))
		touch.set("_aiming", true)
		touch.set("_aim_origin", Vector2(v.x - 110, v.y - 70))
		touch.set("_aim_pos", Vector2(v.x - 96, v.y - 84))


# ------------------------------------------------------------------ shockwave (D7)

const SHOCK_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 center = vec2(0.5);
uniform float radius = 0.0;
uniform float strength = 0.0;
uniform float aspect = 1.7778;
void fragment() {
	vec2 d = SCREEN_UV - center;
	d.x *= aspect;
	float dist = length(d);
	float band = smoothstep(radius - 0.06, radius, dist) * (1.0 - smoothstep(radius, radius + 0.06, dist));
	vec2 off = normalize(d + vec2(1e-5)) * band * strength;
	off.x /= aspect;
	COLOR = texture(screen_tex, SCREEN_UV - off);
}
"""
var _shock: ColorRect
var _shock_mat: ShaderMaterial


## A screen ripple from a boss's phase change: a screen-space ring, hidden when idle.
func _build_shockwave() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_shock = ColorRect.new()
	_shock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shock_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHOCK_SHADER
	_shock_mat.shader = sh
	_shock.material = _shock_mat
	_shock.visible = false
	layer.add_child(_shock)


func _on_shockwave(world_pos: Vector2) -> void:
	if not Game.flash_fx:
		return
	var view := get_viewport_rect().size
	var screen := world_pos - (cam.position + cam.offset) + view / 2.0
	_shock_mat.set_shader_parameter("center", screen / view)
	_shock_mat.set_shader_parameter("aspect", view.x / view.y)
	_shock.visible = true
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		_shock_mat.set_shader_parameter("radius", k * 0.7)
		_shock_mat.set_shader_parameter("strength", 0.025 * (1.0 - k)), 0.0, 1.0, 0.6)
	tw.tween_callback(func() -> void: _shock.visible = false)


## A late-run build for screenshots and boss sims.
func _strong_loadout(r: RunState) -> void:
	r.wands[0] = WandState.make(Catalog.wand(&"apprentice"), [&"twin", &"spark", &"seed", &"ember", &"moths"])
	r.add_wand(&"oak")
	r.wands[1].set_slots([&"empower", &"fan", &"then", &"burst", &"ember_coat", &"needle", &"frost", &"mana_well"])
	r.cur = 0
	r.bag = [{"id": &"ifelse", "lv": 1}, {"id": &"loop", "lv": 1}, {"id": &"keen", "lv": 2}]
	for id in [&"cold_start", &"recursion", &"loop_counter", &"uptime", &"wildfire"]:
		r.add_relic(id)
	r.gold = 140
	r.path = [&"spell", &"relic", &"shop", &"mini", &"spell", &"forge", &"relic"]


func _open(s: Screen, done: Callable) -> void:
	if screen:
		screen.queue_free()
	screen = s
	s.run = world.run
	touch.release_all()
	touch.enabled = false
	world.controls.clear()
	hud.visible = false
	_screens.add_child(s)
	Audio.sfx("ui_open", 0.0)
	s.finished.connect(func(res: Dictionary) -> void:
		Audio.sfx("ui_close", 0.0)
		if screen == s:
			screen = null
		s.queue_free()
		touch.enabled = _playing
		hud.visible = _playing
		done.call(res))


func _on_ui_request(kind: StringName, data: Dictionary) -> void:
	# the bot (demo runs) answers every screen itself
	if world.bot:
		_bot_answer(kind, data)
		return
	match kind:
		&"reward":
			var s := RewardScreen.new()
			s.kind = data["kind"]
			s.offer = data["offer"]
			var lesson := world.run.step
			_open(s, func(res: Dictionary) -> void:
				world.reward_taken()
				# a lesson prize always opens the editor, with the coach on what to move where
				Tutorial.on_prize(world.run, lesson)
				if not Tutorial.coach(world.run, lesson).is_empty():
					_open_editor.call_deferred(lesson)
				elif res.get("equip", false):
					_open_editor.call_deferred())
		&"shop", &"forge":
			var s := ShopScreen.new()
			s.mode = String(kind)
			_open(s, func(_res: Dictionary) -> void: world.ui_done())
		&"victory":
			_open_end(true)
		&"defeat":
			_open_end(false)


func _bot_answer(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"reward":
			WandPlanner.bot_answer(world.run, kind, data["offer"])
			world.reward_taken()
		&"shop", &"forge":
			WandPlanner.bot_answer(world.run, kind)
			world.ui_done()
		&"victory", &"defeat":
			SaveGame.record_run(world.run)
			_begin(RunState.create(world.run.seed_value + 1))


func _open_end(won: bool) -> void:
	_playing = false
	SaveGame.record_run(world.run)
	Audio.music("")
	Audio.sting("victory" if won else "defeat")
	var s := EndScreen.new()
	s.won = won
	_open(s, func(res: Dictionary) -> void:
		if res.get("action") == "again":
			_begin(_new_run())
		else:
			_show_title())


func _open_pause(resumed: bool) -> void:
	if screen or not _playing:
		return
	world.paused = true
	var s := PauseScreen.new()
	s.resumed = resumed
	_open(s, func(res: Dictionary) -> void:
		if res.get("abandon", false):
			SaveGame.clear_run()
			world.run.won = false
			_open_end(false)
			return
		world.paused = false)


func _open_editor(lesson := -1) -> void:
	if screen or not _playing:
		return
	world.paused = true
	var s := EditorScreen.new()
	s.lesson = lesson
	_open(s, func(_res: Dictionary) -> void:
		world.paused = false
		SaveGame.save_run(world.run))


func _on_hud(id: String) -> void:
	match id:
		"pause":
			_open_pause(false)
		"edit":
			_open_editor()
		"map":
			_open_map()
		"dash":
			world.controls.dash = true


func _open_map() -> void:
	if screen or not _playing:
		return
	world.paused = true
	_open(MapScreen.new(), func(_res: Dictionary) -> void: world.paused = false)


## Save when the app goes to the background, and come back paused (never into live combat).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _playing and world.run and not world.run.won and not world.player.dead:
			SaveGame.save_run(world.run)
			if not world.bot and screen == null:
				_open_pause(false)


func _showcase() -> void:
	Game.inf_mana = true
	world.waves = []
	world.wave_i = 0
	var c := world.player.position
	var spots := [[&"slime", Vector2(-70, -60)], [&"weaver", Vector2(40, -110)], [&"ram", Vector2(110, -40)],
		[&"bugling", Vector2(-120, -20)], [&"sentry", Vector2(150, -120)], [&"weaver", Vector2(-40, -130)],
		[&"puffcap", Vector2(70, -80)], [&"ram", Vector2(-150, -100)], [&"bugling", Vector2(20, -60)]]
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
	# LDR glow (hdr_2d is off: it broke 2D lights in the renderer spike, ADR 0004);
	# only the brightest pixels (spell cores, flames, sparks) cross the threshold
	env.glow_hdr_threshold = 0.72
	env.glow_hdr_scale = 1.6
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		env.set_glow_level(i, i >= 1 and i <= 4)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(dt: float) -> void:
	_read_desktop_input()
	_follow_camera(false, dt)
	_frames += 1
	if _args.has("shot") and _frames == int(_args.get("frames", "90")):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(_args["shot"])
		if world.run:
			print("shot: step %d %s player %s hp %d | enemies %d boss %s" % [world.run.step, world.room_kind, world.player.position.round(), world.run.hp,
				world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).size(), str(world.boss.hp) if world.boss else "-"])
		get_tree().quit()


## The room plus padding for the HUD (wand rows on top, vitals at the bottom) is what the
## camera frames: centered when it fits, following the player when it does not.
const PAD_TOP := 58.0
const PAD_BOTTOM := 30.0
const PAD_SIDE := 10.0


## Camera feel (design-plan §10): it eases toward its target with a frame-rate independent
## factor (the same on 60 and 120 Hz screens), leads a little toward where you aim when the
## room is bigger than the view, and shakes by trauma² along smooth noise, in whole pixels.
const CAM_EASE := 0.8          # per 60 Hz frame: 0.8 keeps 80%, closes 20% of the gap
const CAM_LEAD := 16.0
const SHAKE_MAX := 7.0
var _cam_pos := Vector2.ZERO
var _shake_noise: FastNoiseLite


func _follow_camera(snap := false, dt := 1.0 / 60.0) -> void:
	if world.run == null or world.gw == 0:
		return
	var view := get_viewport_rect().size
	var room := world.room_size()
	# the player moves on the 60 Hz physics tick; follow its interpolated position so the
	# camera stays smooth on 90/120 Hz screens
	var p := world.player.prev_pos.lerp(world.player.position, Engine.get_physics_interpolation_fraction()) if not snap else world.player.position
	var lo := Vector2(-PAD_SIDE, -PAD_TOP)
	var hi := room + Vector2(PAD_SIDE, PAD_BOTTOM)
	var c := Vector2.ZERO
	var lead := Vector2.from_angle(world.player.aim) * CAM_LEAD
	for ax in 2:
		if hi[ax] - lo[ax] <= view[ax]:
			c[ax] = (lo[ax] + hi[ax]) / 2.0
		else:
			c[ax] = clampf(p[ax] + lead[ax], lo[ax] + view[ax] / 2.0, hi[ax] - view[ax] / 2.0)
	if snap or _frames <= 1:
		_cam_pos = c
	else:
		_cam_pos = _cam_pos.lerp(c, 1.0 - pow(CAM_EASE, dt * 60.0))
	cam.position = _cam_pos.round()
	if _shake_noise == null:
		_shake_noise = FastNoiseLite.new()
		_shake_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_shake_noise.frequency = 1.0
	var amp := world.trauma * world.trauma * SHAKE_MAX
	var t := Time.get_ticks_msec() / 1000.0 * 22.0
	cam.offset = (Vector2(_shake_noise.get_noise_2d(t, 0.0), _shake_noise.get_noise_2d(0.0, t + 50.0)) * 2.0 * amp).round()


func _read_desktop_input() -> void:
	if not _playing or screen or world.bot or touch.touched_once:
		return
	var c := world.controls
	var mv := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	var pad_move := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var pad_aim := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	c.move = mv.normalized() if mv != Vector2.ZERO else (pad_move if pad_move.length() > 0.2 else Vector2.ZERO)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and hud.hit_button(get_viewport().get_mouse_position()) == "":
		c.aim = (world.get_local_mouse_position() - world.player.position).normalized()
	elif pad_aim.length() > 0.3:
		c.aim = pad_aim
	else:
		c.aim = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	# real mouse clicks on HUD buttons (emulated-from-touch clicks are handled by TouchControls)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		var b := hud.hit_button(event.position)
		if b != "":
			_on_hud(b)
			return
		var wi := hud.hit_wand(event.position)
		if wi >= 0:
			world.controls.select_wand = wi
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_2, KEY_3:
				world.controls.select_wand = event.physical_keycode - KEY_1
			KEY_SPACE, KEY_SHIFT:
				world.controls.dash = true
			KEY_TAB, KEY_E:
				_open_editor()
			KEY_ESCAPE, KEY_P:
				_open_pause(false)
			KEY_F:
				Game.auto_fire = not Game.auto_fire
				SaveGame.save_settings(Game.settings())
				Events.toast.emit("Auto-fire %s" % ("on" if Game.auto_fire else "off"))
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
				world.controls.select_wand = (world.run.cur + 1) % world.run.wands.size()
			JOY_BUTTON_START:
				_open_pause(false)
			JOY_BUTTON_A, JOY_BUTTON_B:
				world.controls.dash = true
			JOY_BUTTON_BACK:
				_open_editor()
