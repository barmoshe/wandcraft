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
##   --world=N           in world N (1 or 2)
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
	Meta.active = true   # D9: the unlock pool applies in the real game only
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if _args.has("shot"):
		SaveGame.in_memory = true   # screenshots never touch the player's save
	UiAudit.on = _args.has("uiaudit")   # 0.20: record text and panel rects for tools/uiaudit.sh
	if _args.has("textbig"):
		Game.text_big = true   # 0.22: shots and the audit at the large text setting
	SaveGame.reset_if_stale()       # 0.18.1: everyone starts over (SaveGame.EPOCH)
	if _args.has("nohints"):
		Hints.mark_all_seen()       # store screenshots: no first-run tips over the scene
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
	# design v2: goals are checked at every room clear; a new one says what it unlocked
	Events.room_entered.connect(func(def: Dictionary) -> void:
		if world.run and not world.bot and not world.run.sandbox:
			RunLog.room_entered(world.run, StringName(def.get("kind", ""))))
	Events.room_cleared.connect(func() -> void:
		if world.run == null or world.bot or world.run.sandbox:
			return
		RunLog.room_cleared(world.run)
		Meta.fold_dex(world.run)
		# meta v2: a bounty fixed mid-run says so; its items open now, its Bits wait at the board
		for b in Meta.check(world.run):
			var names: Array = (b.get("unlocks", []) as Array).map(func(id: StringName) -> String: return Meta.title(id))
			var got := (". Unlocked " + ", ".join(names.slice(0, 3))) if not names.is_empty() else ""
			Events.toast.emit("Bounty fixed: %s%s (+%d Bits)" % [b["text"], got, int(b["bits"])]))
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
	if _args.has("runs") or _args.has("wins"):
		# screenshots and tests: a player with this many runs and wins (in the in-memory save)
		var m := SaveGame.load_meta()
		m["runs"] = int(_args.get("runs", "0"))
		m["wins"] = int(_args.get("wins", "0"))
		m["tutorial_done"] = m["runs"] > 0
		m["intro_seen"] = m["runs"] > 0
		m["bits"] = int(_args.get("bits", "0"))
		SaveGame.save_meta(m)
	if _args.has("residents"):
		# screenshots: residents moved in (--residents=grep,hotfix,cache --pages=N)
		for id in String(_args["residents"]).split(","):
			Residents.rescue(StringName(id))
		var m := SaveGame.load_meta()
		m["pages"] = int(_args.get("pages", "0"))
		SaveGame.save_meta(m)
	if direct and not _args.get("screen", "") in ["title", "hub"] and not _HUB_SCREENS.has(_args.get("screen", "")):
		_start_from_args()
	elif _HUB_SCREENS.has(_args.get("screen", "")):
		_show_hub(false)
		_hub_use(_HUB_SCREENS[_args["screen"]], int(_args.get("arg", "1" if _args["screen"] in ["grep", "hotfix", "cache"] else "0")))
	elif _args.get("screen", "") == "hub":
		_show_hub(false)
		if _args.has("at"):
			world.player.position = world.hub.anchors.get(String(_args["at"]), [world.player.position])[0] + Vector2(0, 14)
	else:
		_launch_app()


# ------------------------------------------------------------------ flow

## Screens a screenshot can open straight in the Workshop (--screen=NAME).
const _HUB_SCREENS := {"runsheet": "portal", "heroes": "heroes", "bench": "repl", "pkg": "pkg",
	"board": "bounty", "docs": "docs", "wall": "log", "terminal": "terminal", "hubmenu": "menu",
	"grep": "grep", "hotfix": "hotfix", "cache": "cache"}

## True while the player walks the Workshop (between runs).
var _hub := false


## The app opens (0.19): a first-time player gets the title, the intro and straight into the
## lessons run; everyone else gets the title over the live Workshop.
func _launch_app() -> void:
	var m := SaveGame.load_meta()
	if int(m.get("runs", 0)) == 0 and not bool(m.get("tutorial_done", false)) and not SaveGame.has_run():
		_playing = false
		hud.visible = false
		touch.enabled = false
		world.visible = false
		Audio.music("title")
		_open(TitleCard.new(), func(_r: Dictionary) -> void:
			_story_then(&"intro", func() -> void: _begin(_new_run())))
		return
	_show_hub(true)


## The Workshop (research/workshop-0.19.md): walk it with the run's controls; stations open
## with USE (main._hub_use). `card` shows the title over it first.
func _show_hub(card := false) -> void:
	_hub = true
	_playing = true
	world.visible = true
	hud.visible = true
	touch.enabled = true
	Audio.snapshot(&"play")
	Dialogue.clear()
	var meta := SaveGame.load_meta()
	world.enter_hub(Hub.make_run(meta))
	_follow_camera(true)
	if card:
		_open(TitleCard.new(), func(res: Dictionary) -> void:
			if res.get("action") == "continue":
				var r := SaveGame.load_run()
				if r:
					_begin(r)
					_open_pause(true)
					return
			_hub_greet())
	else:
		_hub_greet()


## The Duck or LINT says one line that fits the last run (Hub.greeting).
func _hub_greet() -> void:
	var m := SaveGame.load_meta()
	var ev := Hub.greeting(m)
	m["hub_seen"] = true
	m["greeted"] = int(m.get("runs", 0))
	SaveGame.save_meta(m)
	# 0.21: coming home after a run, the Duck's post-mortem (Barks) replaces the plain
	# greeting; what the run's bubbles missed comes up a little later
	Barks.reset()
	# 0.22: the post-mortem is only taken (and spent) when it is actually said; a first-time,
	# unlock or epilogue greeting keeps it for the next visit
	var replaceable: bool = ev in ["hub_death", "hub_boss", "hub_win", "hub_quit", "hub_back", ""]
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if not _hub or screen != null:
			return
		var pm: Array = Barks.hub_return(_now()) if replaceable else []
		if not pm.is_empty():
			_say_lines(pm)
		elif ev != "":
			Story.say(ev))
	get_tree().create_timer(9.0).timeout.connect(func() -> void:
		if _hub and screen == null:
			_say_lines(Barks.carry_over(_now())))


## 0.21: in the Workshop, now and then (half a minute of quiet), two residents, or a
## resident and the Duck or LINT, trade a few lines in bubbles (Residents.chatter).
var _chat_t := 30.0


func _hub_chatter(dt: float) -> void:
	if not _hub or screen or world.hub == null or _args.has("shot"):
		_chat_t = 30.0
		return
	if Dialogue.busy():
		_chat_t = maxf(_chat_t, 12.0)
		return
	_chat_t -= dt
	if _chat_t > 0.0:
		return
	_chat_t = randf_range(35.0, 55.0)
	for l in Residents.chatter():
		Dialogue.enqueue(l["who"], l["text"], l["id"])


## Says an exchange from Barks ([[who, text, id], ...]); false when there was none.
func _say_lines(lines: Array) -> bool:
	for l in lines:
		Events.say.emit(l[0], l[1], l[2])
	return not lines.is_empty()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## A station in the Workshop: its screen, then back to walking.
func _hub_use(id := "", arg := -1) -> void:
	if not _hub or screen or world.hub == null:
		return
	if id == "":
		id = world.hub.near
		arg = world.hub.near_arg
	if id == "menu":
		world.paused = true
		_open(HubMenu.new(), func(res: Dictionary) -> void:
			world.paused = false
			if res.has("station"):
				var st := String(res["station"])
				_hub_use.call_deferred(st, 1 if Hub.STATIONS.get(st, {}).get("resident", false) else 0))
		return
	if id == "" or not Hub.STATIONS.has(id):
		return
	if not world.hub.open(id):
		Events.toast.emit(String(Hub.STATIONS[id].get("locked", "")))
		Audio.sfx("deny")
		return
	var back := func(_res: Dictionary) -> void: world.paused = false
	match id:
		"duck":
			Story.say("hub_duck")
			return
		"lint":
			# 0.21: LINT reviews the wand you hold (code smells), else small talk
			if not _say_lines(Barks.lint_review(world.run.wand(), _now(), true)):
				Story.say("hub_lint")
			return
		"grep", "hotfix", "cache":
			var rid := StringName(id)
			if arg != 1 and world.hub.resident_use(rid) == "talk":
				# 0.21: they talk in the Workshop, in bubbles over their heads; USE again
				# (or the menu) opens their service
				Dialogue.clear()
				var said := Residents.talk(rid)
				for l in said:
					Dialogue.enqueue(l["who"], l["text"], l["id"])
				world.hub.talk_last = String(said[-1]["id"]) if not said.is_empty() else ""
				world.hub.talk_arc = not said.is_empty() and String(said[0]["id"]).contains(".arc.")
				world.hub.news[rid] = Residents.has_news(rid)
				return
			world.hub.talked = rid
			var rs := ResidentScreen.new()
			rs.who = rid
			world.paused = true
			_open(rs, func(_res: Dictionary) -> void:
				world.paused = false
				world.skin = Residents.skin(Residents.skin_on())
				world.hub.news[StringName(id)] = Residents.has_news(StringName(id)))
			return
		"portal":
			world.paused = true
			_open(RunSheet.new(), func(res: Dictionary) -> void:
				world.paused = false
				if res.has("action"):
					_launch(res))
			return
		"heroes":
			var h := HeroScreen.new()
			h.focus = clampi(arg, 0, Hub.HEROES.size() - 1)
			world.paused = true
			_open(h, func(res: Dictionary) -> void:
				world.paused = false
				if res.has("hero"):
					var m := SaveGame.load_meta()
					m["hero"] = String(res["hero"])
					SaveGame.save_meta(m)
					var at := world.player.position
					world.enter_hub(Hub.make_run(m))
					world.player.position = at
					Story.say("hub_hero"))
			return
		"repl":
			var e := EditorScreen.new()
			e.library = Hub.library()
			world.paused = true
			_open(e, func(_res: Dictionary) -> void:
				world.paused = false
				world.run.bag = []
				var m := SaveGame.load_meta()
				m["bench"] = Hub.bench_of(world.run)
				SaveGame.save_meta(m))
			return
		"pkg":
			world.paused = true
			_open(PackScreen.new(), func(res: Dictionary) -> void:
				world.paused = false
				if res.has("bought"):
					var ev := "pkg_bought:" + String(res["bought"])
					Story.say(ev if Story.LINES.has(ev) else "pkg_bought")
				if res.get("try", false):
					_hub_use.call_deferred("repl", 0))
			return
		"bounty":
			world.paused = true
			_open(BountyScreen.new(), back)
		"docs":
			world.paused = true
			_open(CompendiumScreen.new(), back)
		"log":
			world.paused = true
			_open(WallScreen.new(), back)
		"terminal":
			var t := PauseScreen.new()
			t.hub = true
			world.paused = true
			_open(t, func(res: Dictionary) -> void:
				world.paused = false
				if res.get("credits", false):
					world.paused = true
					_open.call_deferred(CreditsScreen.new(), back))


## The portal's choice: a new run as your hero, the saved run, or the daily.
func _launch(res: Dictionary) -> void:
	var m := SaveGame.load_meta()
	m["heat"] = int(res.get("heat", 0))
	SaveGame.save_meta(m)
	match res.get("action"):
		"continue":
			var r := SaveGame.load_run()
			if r:
				_begin(r)
				_open_pause(true)
				return
			_begin(_new_run())
		"daily":
			_begin(_daily_run())
		_:
			_begin(_new_run())


## The story's panels (research/story.md): the intro before a first run, the ending on a
## first win, and (0.20) the true ending the first time you fix forward. Each shows once;
## `then` runs after (or straight away once seen). The ending's key is new in 0.20: it moved
## from Deadlock to the Glitch, so a 0.19 winner sees the new one.
func _story_then(which: StringName, then: Callable) -> void:
	var key: String = {&"intro": "intro_seen", &"ending": "ending3_seen", &"true_ending": "true_seen"}[which]
	if bool(SaveGame.load_meta().get(key, false)) and _args.get("screen", "") != String(which):
		then.call()
		return
	var s := StoryScreen.new()
	match which:
		&"intro":
			s.panels = Story.INTRO
			s.who = Story.INTRO_WHO
			s.art = Story.INTRO_ART
		&"ending":
			s.panels = Story.ENDING
			s.who = Story.ENDING_WHO
			s.art = Story.ENDING_ART
		_:
			s.panels = Story.TRUE_ENDING
			s.who = Story.TRUE_ENDING_WHO
			s.art = Story.TRUE_ENDING_ART
	s.last_label = "BEGIN" if which == &"intro" else "DONE"
	s.voice_prefix = String(which)
	_open(s, func(_res: Dictionary) -> void:
		Story.mark(key)
		then.call())


## Design v2: the daily run. Today's date is the seed, so everyone plays the same map and
## offers; no tutorial, no Bug Reports. The best result per day is kept (SaveGame).
func _daily_run() -> RunState:
	var d := Time.get_date_dict_from_system()
	var day := "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
	var rule := Chapter.daily_rule(day)
	var r := RunState.create(int(day.replace("-", "")), rule["hero"])
	r.daily = day
	r.daily_mod = rule["mod"]
	r.picked = true
	match r.daily_mod:
		&"glass":
			r.max_hp = roundf(r.max_hp * 0.7)
			r.hp = r.max_hp
		&"rich":
			r.gold = 80
	for k in Meta.extra_slots():
		r.wands[0].add_slot()
	return r


## A fresh run. A player's very first run is the curriculum (D9, Tutorial).
func _new_run() -> RunState:
	var m := SaveGame.load_meta()
	var tut := int(m.get("runs", 0)) == 0 and not bool(m.get("tutorial_done", false))
	# 0.19: the hero is chosen at the Workshop's Hero Hall (the lessons run is the Apprentice's)
	var r := RunState.create(int(Time.get_unix_time_from_system()) % 100000 + 1, &"apprentice" if tut else Hub.next_hero(m))
	r.tutorial = tut
	r.picked = true
	r.heat = mini(int(m.get("heat", 0)), int(m.get("wins", 0)))
	for k in Meta.extra_slots():
		r.wands[0].add_slot()
	return r


func _begin(r: RunState) -> void:
	_hub = false
	world.visible = true
	hud.visible = true
	touch.enabled = true
	_playing = true
	Audio.snapshot(&"play")
	Dialogue.clear()
	if not world.bot:
		RunLog.start(r)   # design v3: the local play log for playtests
	world.start_run(r)
	_follow_camera(true)


func _start_from_args() -> void:
	var r := RunState.create(int(_args.get("seed", "7")))
	r.tutorial = _args.has("tutorial")
	r.heat = int(_args.get("heat", "0"))
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
	if _args.has("relics"):
		# shots (tools/uiaudit.sh): a long relic column, the HUD's worst case on the right
		for id in Relics.DEFS.keys().slice(0, int(_args["relics"])):
			if not r.relics.has(id):
				r.add_relic(id)
	while r.wands.size() < int(_args.get("wands", "0")):
		r.add_wand(&"oak")
		r.wands[-1].set_slots([&"empower", &"fan", &"burst", &"needle", &"frost", &"spark"])
	if _args.has("world"):
		r.world = clampi(int(_args["world"]) - 1, 0, Chapter.WORLDS.size() - 1)
	if _args.has("step"):
		r.step = clampi(int(_args["step"]), 0, Chapter.PLAN.size() - 1)
	if _args.has("kind"):
		r.room = {"kind": StringName(_args["kind"]), "reward": &"spell"}
		var k := StringName(_args["kind"])
		if k == &"boss":
			r.step = Chapter.PLAN.size() - 1
		elif k == &"mini":
			r.step = Chapter.PLAN.find(&"mini")
		elif r.step == 0:
			r.step = 1
	world.force_tpl = _args.get("room", "")
	_begin(r)
	if _args.has("showcase"):
		_showcase()
	if _args.has("wand"):
		r.cur = clampi(int(_args["wand"]) - 1, 0, r.wands.size() - 1)
	if _args.has("bounties"):
		# screenshots: bounties just fixed (the end screen's panel), in the in-memory save
		var m := SaveGame.load_meta()
		m["bounties"] = Array(String(_args["bounties"]).split(","))
		m["last_bounties"] = m["bounties"]
		SaveGame.save_meta(m)
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
					r.wand().set_slots([&"empower", &"needle", &"mote"] if lesson == 3 else [null, &"empower", &"mote"])
				r.bag.append({"id": Tutorial.STEPS[lesson]["offer"][0], "lv": 1})
				Tutorial.on_prize(r, lesson)
				_open_editor(lesson)
			else:
				_open_editor()
		"map":
			_open_map()
		"pause":
			_open_pause(false)
			if _args.has("gloss") and screen:
				screen.show_glossary = true   # screenshots of the glossary sheet
		"world":
			world.paused = true
			_on_ui_request(&"world", {"to": int(_args.get("to", "1"))})
		"commit":
			world.paused = true
			_open(CommitScreen.new(), func(_r: Dictionary) -> void: pass)
		"intro", "ending", "true_ending":
			world.paused = true
			_story_then(StringName(_args["screen"]), func() -> void: pass)
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
	# sound v2: default open/close sounds give way to a screen's own; a screen over play is a
	# menu (the music closes, telegraphs hold)
	Audio.ui("ui_open")
	if _playing:
		Audio.snapshot(&"menu")
	s.finished.connect(func(res: Dictionary) -> void:
		Audio.ui("ui_close")
		if world.hub:
			world.hub.refresh_snap()   # a purchase or a claim shows straight away
		if screen == s:
			screen = null
		s.queue_free()
		touch.enabled = _playing
		hud.visible = _playing
		done.call(res)
		if _playing and screen == null:
			Audio.snapshot(&"play"))


func _on_ui_request(kind: StringName, data: Dictionary) -> void:
	# the bot (demo runs) answers every screen itself
	if world.bot:
		_bot_answer(kind, data)
		return
	match kind:
		&"reward":
			# design v2: a start with one hero to take is not a choice; take it and walk on
			if data["kind"] == &"start" and (data["offer"] as Array).size() == 1 and not data["offer"][0].get("locked", false):
				Rewards.grant(world.run, data["offer"][0])
				world.reward_taken()
				return
			var s := RewardScreen.new()
			s.kind = data["kind"]
			s.offer = data["offer"]
			var lesson := world.run.step
			_open(s, func(res: Dictionary) -> void:
				RunLog.pick(s.kind, s.offer, res.get("taken"))
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
		&"world":
			# the descent between worlds: the stack trace, then the next world
			var s := WorldScreen.new()
			s.to = int(data.get("to", world.run.world + 1))
			s.bonus_hp = int(World.WORLD_BONUS_HP)
			_open(s, func(_res: Dictionary) -> void: world.enter_next_world())
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
		&"world":
			world.enter_next_world()
		&"victory", &"defeat":
			SaveGame.record_run(world.run)
			_begin(RunState.create(world.run.seed_value + 1))


var _chose := false   # 0.20: the commit choice was made for this ending


func _open_end(won: bool, how := "") -> void:
	_playing = false
	# 0.20: with the true ending open, the Glitch's fall asks first: revert or fix forward
	if won and not _chose and Residents.true_ending_open() and world.run.daily == "":
		_open(CommitScreen.new(), func(res: Dictionary) -> void:
			_chose = true
			if res.get("choice", "") == "forward":
				world.run.stats["fixed"] = 1
				Residents.set_flag("fixed_forward")
				Story.find_log("true")
				_open_end(true, "forward")
			else:
				_open_end(true, how))
		return
	var forward := how == "forward"
	_chose = false
	if forward:
		how = ""
	Barks.end_run(world.run, "" if won else world.player.last_hurt_by, how == "abandon")   # the post-mortem, before the save moves on
	SaveGame.record_run(world.run, how, "" if won else world.player.last_hurt_by)
	RunLog.finish(world.run, "" if won else world.player.last_hurt_by)
	Audio.music("")
	Audio.sting("victory" if won else "defeat")
	if won:
		# a first win: the ending and the Duck's commit log; fixing forward: the true ending
		_story_then(&"true_ending" if forward else &"ending", func() -> void:
			Story.find_log("win")
			if forward and Game.quiet == 0:
				Story.say("true_win")
			_open_end_screen(true))
		return
	_open_end_screen(false)


func _open_end_screen(won: bool) -> void:
	var s := EndScreen.new()
	s.won = won
	s.killed_by = world.player.last_hurt_by
	# the end's word, spoken: LINT's build result and the Duck (the screen shows the Duck's)
	var said := Story.pick("win" if won else "death")
	s.duck_line = "" if won else Story.duck_text(said)
	Dialogue.clear()
	for l in said:
		Dialogue.enqueue(l["who"], l["text"], l["id"])
	_open(s, func(res: Dictionary) -> void:
		if res.get("action") == "again":
			_begin(_new_run())
		else:
			_show_hub(false))


func _open_pause(resumed: bool) -> void:
	if screen or not _playing:
		return
	if _hub:
		_hub_use("terminal")
		return
	world.paused = true
	var s := PauseScreen.new()
	s.resumed = resumed
	_open(s, func(res: Dictionary) -> void:
		if res.get("abandon", false):
			SaveGame.clear_run()
			world.run.won = false
			_open_end(false, "abandon")
			return
		world.paused = false)


func _open_editor(lesson := -1) -> void:
	if screen or not _playing or _hub:
		return
	world.paused = true
	var s := EditorScreen.new()
	s.lesson = lesson
	_open(s, func(_res: Dictionary) -> void:
		world.paused = false
		SaveGame.save_run(world.run)
		if lesson < 0 and not world.run.tutorial:
			_say_lines(Barks.lint_review(world.run.wand(), _now())))   # LINT reads the new wand


func _on_hud(id: String) -> void:
	match id:
		"pause", "relics_more":
			_open_pause(false)
		"edit":
			_open_editor()
		"map":
			_open_map()
		"dash":
			world.controls.dash = true
		"use":
			_hub_use()
		"menu":
			_hub_use("menu")
		"swap":
			world.controls.select_wand = (world.run.cur + 1) % world.run.wands.size()
		_:
			if id.begins_with("relic"):
				var rid: StringName = world.run.relics[int(id.substr(5))]
				Events.toast.emit("%s: %s" % [Relics.DEFS[rid]["title"], Rewards.item_desc({"t": &"relic", "id": rid})])


func _open_map() -> void:
	if screen or not _playing or _hub:
		return
	world.paused = true
	_open(MapScreen.new(), func(_res: Dictionary) -> void: world.paused = false)


## Save when the app goes to the background, and come back paused (never into live combat).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _playing and not _hub and world.run and not world.run.won and not world.player.dead:
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
	_hub_chatter(dt)
	if _args.has("hudstress") and _frames == int(_args.get("frames", "90")) - 20:
		_hud_stress()
	if _args.has("shot") and _frames == int(_args.get("frames", "90")):
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(_args["shot"])
		if UiAudit.on:
			var bad := UiAudit.report(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
			for line in bad:
				print("UIAUDIT: " + line)
			print("UIAUDIT: %d overlaps" % bad.size())
		if world.run:
			print("shot: step %d %s player %s hp %d | enemies %d boss %s" % [world.run.step, world.room_kind, world.player.position.round(), world.run.hp,
				world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).size(), str(world.boss.hp) if world.boss else "-"])
		get_tree().quit()


## Shots (--hudstress): every HUD message at once, the worst case for overlaps: a spoken
## line, a tip, a toast, and the boss's banner when there is a boss.
func _hud_stress() -> void:
	var who := String(_args.get("say", Story.DUCK))
	Dialogue.current = {"who": who, "text": "", "id": ""}
	Dialogue.line_started.emit(who, "Quack. That wand reads left to right, and so does the bug that broke it.", "", 6.0)
	Events.hint.emit("Tap a wand row to swap. Drag a spell to rearrange it.")
	Events.toast.emit("Relic: Take-Back. The next hit you take is undone.")
	if world.boss and not world.boss.dead:
		Events.boss_phase.emit(2, "It rewrites the floor as a diff")


## The room plus padding for the HUD (wand rows on top, vitals at the bottom) is what the
## camera frames: centered when it fits, following the player when it does not.
const PAD_TOP := 58.0
const PAD_BOTTOM := 30.0
const PAD_SIDE := 10.0


## Camera feel (design-plan §10): it eases toward its target with a frame-rate independent
## factor (the same on 60 and 120 Hz screens), leads a little toward where you aim when the
## room is bigger than the view, and shakes by trauma² along smooth noise, in whole pixels.
## Playtest (design v3): the lead followed the aim, and auto-aim flips between targets when a
## swarm surrounds you, so in big rooms the view swung to and fro. It leads where you walk
## now, eased on its own, so it only drifts when you do.
const CAM_EASE := 0.8          # per 60 Hz frame: 0.8 keeps 80%, closes 20% of the gap
const CAM_LEAD := 16.0
const SHAKE_MAX := 7.0
var _cam_pos := Vector2.ZERO
var _cam_lead := Vector2.ZERO
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
	# 0.22: reduce motion drops the lead (Game.cam_lead)
	var want_lead := (world.player.vel / Player.SPEED).limit_length(1.0) * Game.cam_lead(CAM_LEAD)
	_cam_lead = _cam_lead.lerp(want_lead, 1.0 - pow(0.95, dt * 60.0))
	var lead := _cam_lead
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
	cam.offset = (Vector2(_shake_noise.get_noise_2d(t, 0.0), _shake_noise.get_noise_2d(0.0, t + 50.0)) * 2.0 * amp + world.kick).round()


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
		# from the grip, where the spell leaves the wand
		c.aim = (world.get_local_mouse_position() - world.player.origin()).normalized()
		c.precise = true
	elif pad_aim.length() > 0.3:
		c.aim = pad_aim
		c.precise = false
	else:
		c.aim = Vector2.ZERO
		c.precise = false


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
	if _hub and event is InputEventKey and event.pressed and not event.echo:
		# the Workshop: E or Enter uses the station in reach, Esc lists them all
		match event.physical_keycode:
			KEY_E, KEY_ENTER, KEY_KP_ENTER:
				_hub_use()
				return
			KEY_ESCAPE, KEY_P, KEY_TAB:
				if event.physical_keycode != KEY_TAB:
					_hub_use("menu")
				return
	if _hub and event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				if world.hub and world.hub.near != "":
					_hub_use()
					return
			JOY_BUTTON_START, JOY_BUTTON_BACK:
				_hub_use("menu")
				return
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
