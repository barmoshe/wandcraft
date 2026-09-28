class_name World
extends Node2D
## One room of the run and everything in it. `step(dt)` advances the whole simulation by
## one fixed tick; the scene calls it from _physics_process and tests call it directly.
## The run itself (map position, wands, relics, gold) lives in `run` (RunState). The world
## never opens menus: it emits `ui_request` and waits (`paused`) until main.gd resolves it.
##
## Room legend: '#' wall, 'o' pillar, '~' spike plate, 's' spawn socket, 'L' torch,
## 'c' crate (breakable cover: spells smash it for gold, enemy shots stop on it).
## Doors are carved into the top wall and open on clear.

const TS := 16
## Room ambient light. Bright enough that actors always read (0.4 art direction); torch and
## player lights add warm pools on top.
const AMBIENT := Color(0.74, 0.74, 0.86)
const ROOMS := {
	"hall": [
		"##########################",
		"#L.......s.......s......L#",
		"#........................#",
		"#...o......~~......o.....#",
		"#s.........~~...........s#",
		"#........................#",
		"#....c..............c....#",
		"#...o......s.......o.....#",
		"#........................#",
		"#s......................s#",
		"#.......~~......~~.......#",
		"#........................#",
		"#L..........s...........L#",
		"#........................#",
		"##########################"],
	"cross": [
		"############################",
		"#L..s........##........s..L#",
		"#............##............#",
		"#..~~........##........~~..#",
		"#..~~..................~~..#",
		"#s........................s#",
		"####......o......o......####",
		"####...........c........####",
		"#s........................s#",
		"#..~~..................~~..#",
		"#..~~........##........~~..#",
		"#............##............#",
		"#L..s........##........s..L#",
		"#.............s............#",
		"############################"],
	"pillars": [
		"##############################",
		"#L..........s......s........L#",
		"#............................#",
		"#..o....o....o....o....o.....#",
		"#s...........................#",
		"#.......~~.........~~.......s#",
		"#..o....o....o....o....o.....#",
		"#............................#",
		"#s......c...........c.......s#",
		"#..o....o....o....o....o.....#",
		"#............~~..............#",
		"#............................#",
		"#L........s........s........L#",
		"##############################"],
	"donut": [
		"##########################",
		"#L....s.....s.....s.....L#",
		"#........................#",
		"#....~.............~.....#",
		"#s.......########.......s#",
		"#........#......#........#",
		"#...c....#..cc..#....c...#",
		"#........#......#........#",
		"#s.......####..##.......s#",
		"#....~..............~....#",
		"#........................#",
		"#L.........s.s..........L#",
		"#........................#",
		"##########################"],
	"split": [
		"################################",
		"#L....s..........#.....s......L#",
		"#................#.............#",
		"#..~~~...........#.......~~~...#",
		"#s...............#............s#",
		"#.......o...............o......#",
		"#..............................#",
		"#....c......................c..#",
		"#.......o...............o......#",
		"#s...............#............s#",
		"#..~~~...........#.......~~~...#",
		"#................#.............#",
		"#L.......s.......#......s.....L#",
		"################################"],
	"camp": [
		"####################",
		"#L................L#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#.....c......c.....#",
		"#..................#",
		"#..................#",
		"#..................#",
		"#L................L#",
		"#..................#",
		"####################"],
	"arena_open": [
		"##############################",
		"#L..........................L#",
		"#............................#",
		"#............................#",
		"#.....o..................o...#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#............................#",
		"#.....o..................o...#",
		"#............................#",
		"#............................#",
		"#L..........................L#",
		"#............................#",
		"##############################"],
	"arena_ring": [
		"################################",
		"#L............................L#",
		"#..Y........................Y..#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#.............oo...............#",
		"#.............oo...............#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..Y........................Y..#",
		"#L............................L#",
		"#..............................#",
		"################################"],
}
const FIGHT_ROOMS := ["hall", "cross", "pillars", "donut", "split"]
const EARLY_ROSTER: Array[StringName] = [&"slime", &"bugling", &"weaver", &"puffcap"]
const ROSTER: Array[StringName] = [&"slime", &"bugling", &"weaver", &"puffcap", &"ram", &"sentry"]

signal room_built
## kind: reward | shop | forge | victory | defeat. main.gd opens the screen, then calls
## ui_done() (or reward_taken()) so the room can continue.
signal ui_request(kind: StringName, data: Dictionary)

var run: RunState
var grid := PackedByteArray()
var gw := 0
var gh := 0
var enemies: Array[Enemy] = []
var hash := SpatialHash.new()
var bullets: BulletPool
var ebullets: BulletPool
var spells: SpellRunner
var player: Player
var controls := Controls.new()
var fx: FxLayer
var rng := RandomNumberGenerator.new()
var time := 0.0
var room_time := 0.0
var auto_step := true
var paused := false
var bot := false
var run_seed := 1

# room state
var room_kind: StringName = &"start"
var room_tpl := "camp"
var sockets: Array[Vector2] = []
var torches: Array[Vector2] = []
var hazards: Array[Vector2i] = []
var doors: Array = []          # {"col": int, "def": door dictionary}
var doors_open := false
var cleared := false
var waves: Array = []          # each wave: Array of [kind, elite]
var wave_i := 0
var wave_t := 0.0
var wave_live: Array = []       # the enemies of the latest wave (the next comes at 70% down)
var puzzle: StringName = &""    # a themed puzzle room (Encounter.PUZZLES), or none
var orb: Dictionary = {}       # reward orb: {"pos", "kind", "t"}
var npc: Dictionary = {}       # {"pos", "kind": shop|forge|spring, "used", "near"}
## 0.20: a resident's cage in a Resident room (Residents): {"pos", "who", "open", "t"}
var cage: Dictionary = {}
## 0.20: Page Leak puddles: {"pos", "r", "owner" (uid), "t"}. They grow while their leak lives.
var puddles: Array = []
const PUDDLE_R0 := 5.0
const PUDDLE_MAX := 15.0
const PUDDLE_GROW := 1.6      # px a second
const PUDDLE_SLOW := 0.55     # your speed inside one
const SKATE_SPEED := 1.25     # Puddle Skater (0.20 relic): faster inside one instead
const SKATE_MANA := 4.0       # and mana a second to the wand in hand
const JOIN_R := 48.0          # Finisher (0.20 relic): how close a kill finishes others
const JOIN_HP := 0.15         # and below what share of their HP
const SPILL_R := 40.0         # Frost Spread (0.21 relic): how far a chilled death chills
## 0.19: the Workshop, while the player is in it (null during a run).
var hub: Hub = null
## 0.21: the Duck and LINT, following the hero through a run (world/companion.gd); hidden in
## the Workshop, where the fixed ones stand.
var companions: Array[Companion] = []
var _low_barked := false      # 0.21 barks: low HP said once until you heal back up
var _status_barked := false   # ... and a status build once a room
var _bark_check := 0.0
const SQUIGGLE_DMG := 1.15    # LINT's Red Squiggle (story round 2): the marked enemy takes more
var _squiggle := false        # the trick is unlocked (read as the room opens)
var _squiggled := false       # and has marked someone this room
var boss: Boss
var boss_t := 0.0
var dead_t := 0.0
## Screen shake as "trauma" (0..1, decays linearly); the camera shakes by trauma², so
## small events barely move it and big ones slam (design-plan §10, Eiserloh GDC 2016).
var trauma := 0.0
## Design v3 (Vlambeer): the camera kicks back against each shot, a few pixels, springing home.
var kick := Vector2.ZERO
const TRAUMA_DECAY := 1.6    # per second
var caught := false            # Try / Catch used in this room
var undone := false            # 0.20: Take-Back used in this room
var warm := 0                  # 0.20: Warm-Up: casts this room since the last hit
var damage_done := 0.0
var _kill_streak := 0
var _stop := 0.0               # hit-stop: the sim holds for a few frames on big hits
var _last_stop := -9.0
var _flash_t := -9.0
var _bot_dmg_seen := 0.0
var _bot_progress_t := 0.0

# move_body results
var hit_in_room := false        # Uptime: the player was hit in this room
## A boss or mini-boss beaten without a hit leaves a second orb, Untouched rare relics, once
## its own reward is taken (research/magicraft-progression.md, lesson 6).
var bonus_orb := false
var _leak_t := 0.0              # Memory Leak: time to the next HP lost
var treasure := Vector2.INF     # a secret chest behind a cracked wall (D5)
var secret_open := false
var pylon_cd: Dictionary = {}   # tile index -> seconds until that pylon can pulse again
var _paint_seed := 0
var force_tpl := ""             # screenshots and tests: build this layout for the next fight
var marked: Enemy               # Hex Cursor: payloads aim here (D2)
var grid_ver := 0              # bumped on every grid change (the flow field rebuilds)
var shot_sound := "eshot"     # D8: the sound of the enemy shot being fired (Enemy.shoot sets it)
var hit_sound := "hit"        # D8: the element sound of the hit being dealt (SpellRunner sets it)
var last_hit_x := false
var last_hit_y := false

var _uid := 0
var _cascading := false
var _floor: Sprite2D
var _vignette: Sprite2D
var _vignette_tex: GradientTexture2D
var _deco: Node2D
var _decals: Node2D            # D6: telegraph decals on the floor, under the actors
var life: AmbientLife          # D6: tufts, motes, leaves
var _lips: Array[Sprite2D] = [] # D6: front-cap lips, y-sorted with the actors
const LIP := 6                 # px a wall's cap rises above its tile
var _actors: Node2D
var _top: Node2D
var _ambient: CanvasModulate
var _lights: Node2D
static var _light_tex: Texture2D


func setup(seed_value: int) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	_floor = Sprite2D.new()
	_floor.centered = false
	_floor.position = -Vector2(RoomPainter.MARGIN * TS)
	add_child(_floor)
	# the surroundings fade into the dark toward the screen edges
	_vignette = Sprite2D.new()
	_vignette.centered = false
	_vignette.position = _floor.position
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(Style.RAMPS["night"][1], 0.0))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(Style.RAMPS["night"][1], 0.92))
	g.add_point(0.52, Color(Style.RAMPS["night"][1], 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_SQUARE
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	_vignette_tex = gt
	_vignette.texture = gt
	add_child(_vignette)
	_deco = Node2D.new()
	add_child(_deco)
	_deco.draw.connect(_draw_deco)
	_decals = Node2D.new()
	add_child(_decals)
	_decals.draw.connect(_draw_decals)
	life = AmbientLife.new()
	life.setup(self)
	add_child(life)
	_actors = Node2D.new()
	_actors.y_sort_enabled = true
	add_child(_actors)
	# emissive things live on their own layer that follows the camera, so the ambient
	# CanvasModulate (which darkens the room between lights) never dims them
	var glow_layer := CanvasLayer.new()
	glow_layer.layer = 1
	glow_layer.follow_viewport_enabled = true
	add_child(glow_layer)
	_top = Node2D.new()
	glow_layer.add_child(_top)
	glow_layer.add_child(life.glow)
	_top.draw.connect(_draw_top)
	ebullets = BulletPool.new()
	# normal blend so the dark rim shows on bright magic; drawn above the player's bullets
	ebullets.setup(512, _enemy_bullet_texture(), false)
	ebullets.z_index = 2
	glow_layer.add_child(ebullets)
	bullets = BulletPool.new()
	bullets.setup_atlas(2048, Projectiles.atlas(), Projectiles.cell_count())
	glow_layer.add_child(bullets)
	fx = FxLayer.new()
	fx.rng.seed = seed_value + 7
	fx.trail_pool = bullets
	glow_layer.add_child(fx)
	_ambient = CanvasModulate.new()
	_ambient.color = AMBIENT
	add_child(_ambient)
	_lights = Node2D.new()
	add_child(_lights)
	player = Player.new()
	player.setup(self)
	_actors.add_child(player)
	for k in [&"duck", &"lint"]:
		var c := Companion.new()
		c.setup(self, k)
		c.visible = false
		_actors.add_child(c)
		companions.append(c)
	var pl_light := make_light(Color(0.75, 0.8, 1.0), 1.05, 150.0)
	pl_light.position = Vector2(0, -6)
	player.add_child(pl_light)
	spells = SpellRunner.new(self)
	Events.player_died.connect(_on_player_died)


## Starts (or resumes) a run: builds the room the run is standing in.
## 0.20: the wand skin worn this run (Residents.SKINS; the plain oak when none).
var skin: Dictionary = {}


## 0.21: the companions react (Barks): the event and its facts go to the bark rules, and
## whatever they pick is said (a bubble over the speaker). Quiet in bot runs and dailies.
## 0.22 (Bar: quiet in fights): while a room is being fought only the moments that matter
## right now speak (low HP, a boss phase, a rule wand's first cast); the rest is held and
## the best of it is said when the room clears. Never in the Workshop, a daily or a lesson.
const FIGHT_BARKS: Array[StringName] = [&"low_hp", &"boss_phase", &"rule_first"]
const HELD_ORDER: Array[StringName] = [&"elite_kill", &"big_hit", &"status", &"mana_empty"]
const BARK_GAP := 2.0   # an event asks at most this often (a burst of big hits asks once)
var _held := {}         # event -> facts, this room
var _bark_at := {}      # event -> world time it last asked


func bark(event: StringName, facts: Dictionary = {}) -> void:
	if bot or Game.quiet > 0 or run == null or run.tutorial or run.sandbox or hub != null or run.daily != "":
		return
	if time - float(_bark_at.get(event, -99.0)) < BARK_GAP:
		return
	_bark_at[event] = time
	if not cleared and not FIGHT_BARKS.has(event):
		_held[event] = facts
		return
	_say_bark(event, facts)


func _say_bark(event: StringName, facts: Dictionary) -> void:
	for l in Barks.pick(event, facts, Time.get_ticks_msec() / 1000.0):
		Events.say.emit(l[0], l[1], l[2])


## The room is clear: the best moment held back during the fight gets its line, or a quick
## clear gets one. At most one.
func _flush_barks() -> void:
	for ev in HELD_ORDER:
		if _held.has(ev):
			var f: Dictionary = _held[ev]
			_held.clear()
			_say_bark(ev, f)
			return
	if room_time < 12.0 and room_kind != &"start":
		bark(&"room_fast", {"time": room_time})


func _on_boss_phase(n: int, _line: String) -> void:
	if boss and not boss.dead:
		bark(&"boss_phase", {"boss": boss.title.trim_suffix(" 2.0"), "phase": n})


## Barks that watch the state rather than an event: low HP, and a status build in full swing.
func _bark_tick(dt: float) -> void:
	_bark_check -= dt
	if _bark_check > 0.0:
		return
	_bark_check = 0.5
	if _squiggle and not _squiggled and not cleared and room_time > 1.5:
		# LINT underlines the toughest one in the room: an elite first, else the most HP
		var best: Enemy = null
		for e in enemies:
			if e.dead or e.spawn_t > 0.0 or e is Boss or e.locked:
				continue
			if best == null or (e.elite and not best.elite) or (e.elite == best.elite and e.max_hp > best.max_hp):
				best = e
		if best:
			best.squiggle = true
			_squiggled = true
	var k := run.hp / run.max_hp
	if k < 0.3 and not _low_barked and not player.dead:
		_low_barked = true
		bark(&"low_hp", {"hp": k, "boss": boss != null and not boss.dead})
	elif k > 0.5:
		_low_barked = false
	if not _status_barked and not cleared:
		var counts := {"burn": 0, "frost": 0, "rot": 0, "shock": 0}
		for e in enemies:
			if e.dead:
				continue
			if e.burn_t > 0.0:
				counts["burn"] += 1
			if e.chill_t > 0.0 or e.frozen_t > 0.0:
				counts["frost"] += 1
			if e.rot_n > 0:
				counts["rot"] += 1
			if e.static_t > 0.0:
				counts["shock"] += 1
		for st in counts:
			if counts[st] >= 5:
				_status_barked = true
				bark(&"status", {"status": st, "n": counts[st]})
				break


func start_run(r: RunState) -> void:
	hub = null
	Barks.reset()
	run = r
	skin = Residents.skin(Residents.skin_on())
	rng.seed = r.seed_value * 7919 + r.step
	player.set_look(r.hero)
	player.dead = false
	dead_t = 0.0
	paused = false
	enter_room()


## 0.19: the Workshop between runs (world/hub.gd). It never calls enter_room, so nothing
## is saved.
func enter_hub(r: RunState) -> void:
	assert(not bot, "the bot never enters the Workshop")
	run = r
	skin = Residents.skin(Residents.skin_on())
	rng.seed = 4242
	player.set_look(r.hero)
	player.dead = false
	dead_t = 0.0
	paused = false
	hub = Hub.new(self)
	build_room("hub", &"hub")
	hub.populate()


# ------------------------------------------------------------------ rooms

func room_plan() -> StringName:
	return Chapter.PLAN[clampi(run.step, 0, Chapter.PLAN.size() - 1)]


## Builds the room for the run's current step and saves the run (a resume lands here).
func enter_room() -> void:
	var plan := room_plan()
	var kind: StringName = plan
	if plan == &"room":
		kind = StringName(run.room.get("kind", "fight"))
	var tpl: String
	match kind:
		&"start", &"shop", &"spring", &"forge", &"altar", &"terminal":
			tpl = "camp"
		&"mini":
			tpl = "arena_open"
		&"boss":
			tpl = "arena_ring"
		_:
			var pool: Array = RoomLayouts.pool(run.step)
			if run.step >= 3:
				pool.append_array(FIGHT_ROOMS)   # the POC's five stay in the medium pool
			tpl = pool[rng.randi() % pool.size()]
			if force_tpl != "":
				tpl = force_tpl
				force_tpl = ""
	if run.doors.is_empty():
		run.doors = Chapter.door_options(run)
	if kind == &"shop" and run.shop.is_empty():
		run.shop = Rewards.shop_stock(run)
	build_room(tpl, kind)
	if run.has_relic(&"interest") and run.gold >= 60:
		run.gold += 3
	run.stats["room_hp"] = run.hp   # Checkpoint: a fatal hit puts you back here
	if run.step == 0:
		Hints.show("move")
	SaveGame.save_run(run)


## The music a room plays (D8): the boss cue for both bosses, the shop cue where you trade,
## otherwise the area's stems (the Cellar for rooms 1-4, the Corrupted Grove after).
func room_music(kind: StringName) -> String:
	if kind == &"hub":
		return "title"
	if kind == &"mini" and Audio.track_ready("mini"):
		return "mini"
	if kind == &"mini" or kind == &"boss":
		return "boss"
	if kind == &"shop" or kind == &"forge":
		return "shop"
	if biome() >= 4:
		return "kernel"
	if biome() >= 2:
		return "foundry"
	return "cellar" if biome() == 0 else "grove"


## Music layers follow the fight (sound v2 §5.2): intensity 1 (drums) while enemies are up,
## 2 (the lead) with an elite, eight or more, or a boss; the boss's p2 and p3 layers from its
## second and third phases. A clear drops the intensity at once.
func _music_layers() -> void:
	var alive := 0
	var elite := false
	for e in enemies:
		if not e.dead:
			alive += 1
			elite = elite or e.elite
	var level := 0 if cleared or alive == 0 else (2 if elite or alive >= 8 or boss != null else 1)
	Audio.intensity(level, cleared)
	Audio.layer("p2", boss != null and not boss.dead and boss.phase > 0)
	Audio.layer("p3", boss != null and not boss.dead and boss.phase > 1)


func build_room(tpl: String, kind: StringName) -> void:
	if Game.quiet == 0:
		Audio.stop_world()
	for e in enemies:
		e.queue_free()
	enemies.clear()
	boss = null
	bullets.clear_all()
	ebullets.clear_all()
	spells.clear_room()
	marked = null
	fx.clear_all()
	orb = {}
	npc = {}
	room_tpl = tpl
	room_kind = kind
	room_time = 0.0
	hit_in_room = false
	bonus_orb = false
	caught = false
	undone = false
	warm = 0
	var rows: Array = Hub.ROWS if tpl == "hub" else (ROOMS[tpl] if ROOMS.has(tpl) else RoomLayouts.ART[tpl]["rows"])
	treasure = Vector2.INF
	secret_open = false
	pylon_cd.clear()
	gh = rows.size()
	gw = String(rows[0]).length()
	grid.resize(gw * gh)
	sockets.clear()
	torches.clear()
	hazards.clear()
	for y in gh:
		var row: String = rows[y]
		for x in gw:
			var tile := 0
			match row[x]:
				"#":
					tile = 1
				"o":
					tile = 3
				"~":
					tile = 2
					hazards.append(Vector2i(x, y))
				"s":
					sockets.append(_center(x, y))
				"L":
					torches.append(_center(x, y))
				"c":
					tile = 4
				"_":
					tile = 5
				"b":
					tile = 6
				"X":
					tile = 7
				"P":
					tile = 8
				"Y":
					tile = 9
				"T":
					treasure = _center(x, y)
			grid[y * gw + x] = tile
	grid_ver += 1
	_place_doors()
	doors_open = false
	cleared = false
	_paint_seed = run_seed * 131 + (run.step if run else 0) * 17 + tpl.length()
	_repaint()
	life.reset(_paint_seed)
	_ambient.color = [AMBIENT, AMBIENT.lerp(Style.c("violet:4"), 0.12), AMBIENT.lerp(Style.c("frost:4"), 0.1), AMBIENT.lerp(Style.c("ember:4"), 0.14),
		AMBIENT.lerp(Style.c("vellum:4"), 0.3), AMBIENT.lerp(Style.c("frost:4"), 0.06)][biome()]
	if run and Chapter.twist_of(run.room) == &"dark" and kind == &"fight":
		_ambient.color = _ambient.color.darkened(0.6)   # design v3: lights out
	var vs := RoomPainter.size_px(gw, gh)
	_vignette_tex.width = vs.x
	_vignette_tex.height = vs.y
	for l in _lights.get_children():
		l.queue_free()
	for tp in torches:
		var tl := make_light(Color(1.0, 0.62, 0.3), 1.1, 130.0)
		tl.position = tp + Vector2(0, -6)
		_lights.add_child(tl)
	hash.resize(gw * TS, gh * TS)
	player.position = _find_floor(gw / 2, gh - 2)
	player.vel = Vector2.ZERO
	player.reset_physics_interpolation()
	for c in companions:
		c.visible = kind != &"hub"
		c.snap()
	waves = []
	wave_i = 0
	wave_t = 0.8
	wave_live.clear()
	puzzle = &""
	cage = {}
	_squiggle = hub == null and run != null and not run.tutorial and run.daily == "" and Barks.lint_trick()
	_squiggled = false
	_held.clear()
	_status_barked = false
	_low_barked = false
	puddles.clear()
	if run:
		for w in run.wands:
			w.suspended = -1
	var mid := _find_floor(gw / 2, gh / 2 - 1)
	match kind:
		&"start":
			# 0.19: a hero chosen at the Workshop's Hero Hall means no hero orb here
			if run and not run.picked:
				orb = {"pos": mid, "kind": &"start", "t": 0.0}
			else:
				_open_doors()
			cleared = true
		&"shop", &"forge", &"spring", &"altar", &"terminal":
			npc = {"pos": mid, "kind": kind, "used": false, "near": false}
			_clear_room(false)
		&"mini", &"boss":
			boss_t = 1.0
		&"fight", &"challenge", &"glitch", &"risk":
			waves = _compose_waves(kind)
		&"resident":
			# 0.20: a fight around a cage; clearing it frees who's inside (Residents)
			waves = _compose_waves(&"fight")
			cage = {"pos": mid, "who": StringName(run.room.get("who", "grep")), "open": false, "t": 0.0}
		&"empty", &"hub":
			cleared = true   # tests and the showcase: a room with nothing in it; the Workshop
	_deco.queue_redraw()
	if Game.quiet == 0:
		Audio.music(room_music(kind))
		Audio.ambience(["cellar", "grove", "foundry", "foundry", "kernel", "ring"][biome()])
		Events.room_entered.emit({"no": run.step if run else 0, "kind": kind, "tpl": tpl,
			"title": _room_title(kind)})
		_story_on_enter(kind)
	room_built.emit()


## The story's beats as rooms open (research/story.md): the Duck at a run's start, at the
## second area and at a new world; a Debug Terminal holds the next commit-log entry.
func _story_on_enter(kind: StringName) -> void:
	if run == null or run.daily != "" or kind == &"hub":
		return
	if kind == &"start":
		if run.world >= 2:
			Story.say("world3")
			Story.find_log("world3")
		elif run.world == 1:
			Story.say("world2")
		else:
			Story.say("first_run" if run.tutorial or not Story.intro_seen() else "run")
			if run.heat > 0:
				Story.say("heat:%d" % mini(run.heat, 5))
	elif run.step == Chapter.AREAS[1]["from"] and kind != &"mini":
		if run.world == 0:
			Story.say("grove")
			Story.find_log("grove")
		elif run.world == 1:
			Story.say("core")
		else:
			Story.say("ring")
	elif kind == &"terminal":
		Story.find_log()


func _room_title(kind: StringName) -> String:
	if puzzle != &"":
		return "PUZZLE: " + String(Encounter.PUZZLES[puzzle]["title"])
	if Tutorial.active(run) and kind == &"fight":
		return Tutorial.title(run).to_upper()
	match kind:
		&"hub":
			return "THE WORKSHOP"
		&"start":
			return "WORLD %d" % (run.world + 1) if run else "WORLD 1"
		&"mini":
			return "MINI-BOSS"
		&"boss":
			return "BOSS"
	if kind == &"fight" and run:
		# design v2: the banner names the room, not its prize ("FIGHT: SPELL")
		return "FIGHT: " + String(Chapter.INFO.get(String(run.room.get("reward", "spell")), {"name": "?"})["name"]).to_upper()
	var key := String(kind)
	return String(Chapter.INFO.get(key, {"name": String(kind)})["name"]).to_upper()


## 1-3 doors of two tiles each, spread along the top wall over floor.
func _place_doors() -> void:
	doors.clear()
	var defs: Array = run.doors if run else [{"kind": &"fight", "reward": &"spell"}]
	var n := defs.size()
	for k in n:
		var col := int(gw * (k + 1) / float(n + 1)) - 1
		for shift in [0, 1, -1, 2, -2, 3, -3]:
			var c: int = col + shift
			if c >= 1 and c + 1 < gw - 1 and tile_at(c, 1) == 0 and tile_at(c + 1, 1) == 0:
				col = c
				break
		doors.append({"col": col, "def": defs[k]})


func _compose_waves(kind: StringName) -> Array:
	if Tutorial.active(run) and kind == &"fight":
		puzzle = &""
		return Tutorial.waves(run)
	puzzle = Encounter.puzzle_for(run, kind, rng)
	return Encounter.compose(run, kind, rng, puzzle)


func _spawn_wave(list: Array) -> void:
	# design v3: an ambush room's first wave lands in a ring around you
	var ambush := wave_i == 0 and run != null and Chapter.twist_of(run.room) == &"ambush" and room_kind == &"fight"
	var socks := Encounter.ambush_points(self) if ambush else Encounter.spawn_points(self)
	_shuffle(socks)
	wave_live.clear()
	for i in list.size():
		var p: Vector2 = socks[i % socks.size()] + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var er: float = float(Enemy.DEFS[list[i][0]]["r"]) + (2.0 if list[i][1] else 0.0)
		if not body_fits(p, er):
			p = socks[i % socks.size()]
		var e := spawn_enemy(list[i][0], p, list[i][1])
		if (list[i] as Array).size() > 2 and list[i][2] == &"warded":
			e.make_warded()   # a room whose door asked for Shock
		e.spawn_t = 0.8 + rng.randf() * 0.2   # the rune shows 0.8-1.0 s before anything lands
		wave_live.append(e)
	Audio.sfx("spawn")
	if list.any(func(x: Array) -> bool: return bool(x[1])):
		Audio.sfx("elite_arrive")
	if wave_i == 0:
		Audio.sfx("door_shut")
	Hints.show("aim")


const DMG_PER_ROOM := 0.03
const ROOM_HEAL := 3.0      # research/difficulty.md: 6 before (8 before 0.16.1)
const SPRING_HEAL := 0.5    # of max HP (0.3 at heat 4+); 0.6 / 0.4 before


func spawn_enemy(kind: StringName, pos: Vector2, elite := false) -> Enemy:
	var e := Enemy.new()
	_uid += 1
	var step := Chapter.scale_depth(run) if run else 1.0
	# enemy HP climbs with depth (heat 2 now raises damage instead, below)
	# design v2: ten rooms, so HP climbs a little slower per room and ends where it did; in
	# World 2 it keeps climbing from where World 1 ended
	# research/difficulty.md: damage climbs with depth too (x1.3 at the Loop, x1.6 at Deadlock)
	# heat 2 (research/difficulty.md: rules, not HP): enemies hit 20% harder
	e.setup(self, kind, pos, _uid, 1.0 + step * 0.055, elite, (1.0 + step * DMG_PER_ROOM) * (1.2 if run and run.heat >= 2 else 1.0))
	enemies.append(e)
	_actors.add_child(e)
	if run:
		run.see_enemy(kind)
	return e


## Meta v2's run counters (bounties: elites, thermal shocks, bitrot crashes, clean bosses).
func _count(key: String, n := 1) -> void:
	if run:
		run.stats[key] = int(run.stats.get(key, 0)) + n


## Design v3: the mini-boss pool. The lesson run always meets Copy-Paste; other runs meet it
## or the Garbage Collector, by the run's seed.
var force_mini: StringName = &""   # tests: &"copy_paste" or &"collector"


## World 2 meets the one World 1 did not; World 3 meets Data Race (0.20).
func mini_boss() -> Boss:
	if force_mini == &"collector":
		return BossCollector.new()
	if force_mini == &"race":
		return BossRace.new()
	if force_mini == &"copy_paste" or run == null:
		return BossCopyPaste.new()
	if run.world >= 2:
		return BossRace.new()
	var cp := run.tutorial or run.seed_value % 2 == 1
	if run.world % 2 == 1:
		cp = not cp
	return BossCopyPaste.new() if cp else BossCollector.new()


## Each world's boss: the Infinite Loop, Deadlock, then the Glitch in the Kernel (0.20).
func world_boss() -> Boss:
	var w := run.world if run else 0
	if w >= 2:
		return BossGlitch.new()
	return BossDeadlock.new() if w == 1 else BossLoop.new()


func _spawn_boss() -> void:
	var b: Boss = mini_boss() if room_kind == &"mini" else world_boss()
	_uid += 1
	enemies.append(b)
	_actors.add_child(b)
	b.setup_boss(self, Vector2(gw * TS / 2.0, gh * TS * 0.35), _uid)
	if run and run.world == 1 and b.mini:
		b.max_hp *= 1.7    # World 2's mini-boss: the other one, version 2.0
		b.hp = b.max_hp
		b.title += " 2.0"
	boss = b
	Audio.sting("glitch" if b is BossGlitch else "boss")
	Hints.show("boss")
	Events.boss_started.emit(b.title, b.subtitle)
	if not Events.boss_phase.is_connected(_on_boss_phase):
		Events.boss_phase.connect(_on_boss_phase)
	if run and run.daily == "":
		Story.say("boss:" + b.title.trim_suffix(" 2.0"))


func _clear_room(reward := true) -> void:
	cleared = true
	clear_enemy_bullets()
	if not reward:
		_open_doors()
		return
	run.stats["rooms"] += 1
	_status_barked = false
	_flush_barks()
	if run.world == 2 and not run.stats.has("archive_said"):
		run.stats["archive_said"] = true
		Story.say("archive")   # the Page Archive's first cleared room
	var cloned := Relics.on_room_clear(run)   # 0.21 Relic Copy
	if cloned != &"":
		fx.text(player.position + Vector2(0, -44), "COPIED: %s" % String(Relics.DEFS[cloned]["title"]).to_upper(), Style.c("steel:4"), 10)
	run.uptime = 0 if hit_in_room else mini(10, run.uptime + 1)
	# design v2 goals (Meta.GOALS): what this room counted toward
	if not hit_in_room:
		run.stats["clean"] = int(run.stats.get("clean", 0)) + 1
	var trig := run.wand().slots.filter(func(s: Variant) -> bool: return s != null and Screen.fam(Catalog.spell(s["id"])) == Screen.Fam.TRIGGER).size()
	if trig >= 2:
		run.stats["trigger_rooms"] = int(run.stats.get("trigger_rooms", 0)) + 1
	run.stats["max_gold"] = maxi(int(run.stats.get("max_gold", 0)), run.gold)
	player.heal(ROOM_HEAL)
	Audio.sfx("heal_small")
	fx.text(player.position + Vector2(0, -34), "ROOM CLEAR", Color("#ffe066"), 10)
	if room_kind == &"mini" or room_kind == &"boss":
		Audio.sting("boss_down")   # in place of the room-clear stinger
	Events.room_cleared.emit()
	var mid := _find_floor(gw / 2, gh / 2)
	match room_kind:
		&"mini", &"boss":
			orb = {"pos": mid, "kind": room_kind, "t": 0.0}
			if not hit_in_room:
				bonus_orb = true
				_count("untouched")
				fx.text(player.position + Vector2(0, -24), "UNTOUCHED", Color("#9fe8ff"), 10)
			if run.daily == "" and boss:
				var beat := "down:mini" if room_kind == &"mini" else "down:" + boss.title
				Story.say(beat)
				Story.find_log(beat)
			if room_kind == &"boss":
				player.heal(run.max_hp)
				Audio.sfx("heal")
				run.stats["worlds"] = run.world + 1   # the goal "Defeat the Infinite Loop" counts now
			_lost_page()
		&"resident":
			_free_resident()
		&"challenge", &"glitch":
			orb = {"pos": mid, "kind": room_kind, "t": 0.0}
		&"risk":
			# the Untouched door: a clean clear earns rare relics, a hit a little gold
			if not hit_in_room:
				fx.text(player.position + Vector2(0, -24), "UNTOUCHED", Color("#9fe8ff"), 10)
				orb = {"pos": mid, "kind": &"risk", "t": 0.0}
			else:
				run.gold += 15
				fx.text(player.position + Vector2(0, -24), "HIT: +15 GOLD", Color("#ffd36b"), 10)
				_open_doors()
		_:
			var r := StringName(run.room.get("reward", "spell"))
			match r:
				&"gold":
					var g := roundi((18 + run.step * 3) * Relics.gold_mul(run))
					run.gold += g
					fx.text(player.position + Vector2(0, -24), "+%d GOLD" % g, Color("#ffd36b"), 10)
					Audio.sfx("coin", player.position)
					_open_doors()
				&"heart":
					run.max_hp += 15.0
					player.heal(15.0)
					Audio.sfx("heart")
					fx.text(player.position + Vector2(0, -24), "MAX HP LOCKED" if run.has_relic(&"version_pin") else "MAX HP +15", Color("#ff4d6d"), 10)
					_open_doors()
				_:
					orb = {"pos": mid, "kind": r, "t": 0.0}
	_deco.queue_redraw()


func _open_doors() -> void:
	if not doors_open and room_kind != &"start":
		Hints.show("doors")
	if not doors_open and room_time > 0.2:
		Audio.sfx("door")   # the doors unlock (not the ones already open as a quiet room is built)
	doors_open = true
	for d in doors:
		for dx in 2:
			grid[int(d["col"]) + dx] = 0
	grid_ver += 1
	_deco.queue_redraw()


## 0.20, World 3: a Page Leak's puddle, where it stands.
func add_puddle(e: Enemy, pos: Vector2) -> void:
	if puddles.size() >= 24:
		return
	puddles.append({"pos": pos, "r": PUDDLE_R0, "owner": e.uid, "t": 0.0})
	Audio.sfx("leak_drip", pos)


## Its memory freed: every puddle it left dries up.
func dry_puddles(e: Enemy) -> void:
	var n := puddles.size()
	puddles = puddles.filter(func(p: Dictionary) -> bool: return int(p["owner"]) != e.uid)
	if puddles.size() < n:
		Audio.sfx("leak_dry", e.position)
		fx.text(e.position + Vector2(0, -16), "MEMORY FREED", Style.c("gold:4"))


func _grow_puddles(dt: float) -> void:
	for p in puddles:
		p["r"] = minf(PUDDLE_MAX, float(p["r"]) + PUDDLE_GROW * dt)
		p["t"] = float(p["t"]) + dt
	# Puddle Skater (0.20 relic): standing in a leak refills the wand in hand
	if run and player and run.has_relic(&"swap_space") and puddle_slow(player.position) > 1.0:
		var w := run.wand()
		w.mana = minf(w.max_mana(), w.mana + SKATE_MANA * dt)


## How fast you move here: slowed inside a puddle.
func puddle_slow(pos: Vector2) -> float:
	for p in puddles:
		if pos.distance_squared_to(p["pos"]) < float(p["r"]) * float(p["r"]):
			return SKATE_SPEED if run and run.has_relic(&"swap_space") else PUDDLE_SLOW
	return 1.0


## A Dangling Pointer snapped from `from` to `to`: you're hit if you stood on the line.
func pointer_snap(e: Enemy, from: Vector2, to: Vector2) -> void:
	Audio.sfx("null_blink", to)
	fx.ring(to, 2.0, 12.0, 0.2, Style.c("threat:4"))
	var p := player.position
	var seg := Geometry2D.get_closest_point_to_segment(p, from, to)
	if p.distance_to(seg) < Enemy.POINT_W / 2.0 + player.r:
		player.hurt(e.dmg, to, "snap:%s" % e.kind)


## An Interrupt takes one of your wand's spells while it lives: a boost or a trigger first,
## a shooting spell only if the wand keeps another. One lock at a time.
func interrupt_claim(e: Enemy) -> void:
	if run == null or player == null:
		return
	var w := run.wand()
	if w.suspended >= 0:
		return
	var boosts: Array = []
	var shots: Array = []
	for i in w.slots.size():
		var s: Variant = w.slots[i]
		if s == null:
			continue
		var d := Catalog.spell(s["id"])
		if d == null or d.kind == SpellDef.Kind.PASSIVE:
			continue
		if d.kind == SpellDef.Kind.PROJ:
			shots.append(i)
		else:
			boosts.append(i)
	var pick := -1
	if not boosts.is_empty():
		pick = boosts[rng.randi() % boosts.size()]
	elif shots.size() >= 2:
		pick = shots[rng.randi() % shots.size()]
	if pick < 0:
		return
	w.suspended = pick
	e.lock_wand = w
	Audio.sfx("interrupt_lock", e.position)
	fx.text(player.position + Vector2(0, -30), "SPELL SUSPENDED", Style.c("violet:4"), 10)
	if run.daily == "" and not bool(run.stats.get("interrupted", false)):
		run.stats["interrupted"] = true
		Story.say("interrupt")


func interrupt_release(e: Enemy) -> void:
	if e.lock_wand != null:
		e.lock_wand.suspended = -1
		e.lock_wand = null
		Audio.sfx("interrupt_free", player.position if player else e.position)
		if player:
			fx.text(player.position + Vector2(0, -30), "SPELL BACK", Style.c("violet:4"))


## 0.20: the cage opens. The resident draws in, says hello, and moves into the Workshop.
func _free_resident() -> void:
	if cage.is_empty():
		_open_doors()
		return
	cage["open"] = true
	cage["t"] = 0.0
	var who: StringName = cage["who"]
	var fresh := not Residents.rescued(who)
	if not bot:   # 0.22: a bench or demo run never writes the player's Workshop
		Residents.rescue(who)
	if fresh:     # a resumed room never counts the rescue twice
		run.stats["residents"] = int(run.stats.get("residents", 0)) + 1
	Audio.sfx("resident_free", cage["pos"])
	# 0.21: the news sits under the cage, clear of the resident's first bubble over it
	fx.text(cage["pos"] + Vector2(0, 22), "%s JOINS THE WORKSHOP" % String(Residents.DEFS[who]["name"]).to_upper(), Color("#72e06a"), 10)
	# 0.22: they speak as the cage opens (the reveal plays under the bubble), so leaving at
	# once never skips them
	cage["said"] = true
	if fresh and Game.quiet == 0 and run.daily == "" and not bot:
		for l in Residents.freed_lines(who):
			Events.say.emit(l["who"], l["text"], l["id"])
	_open_doors()


## 0.20: once Cache lives in the Workshop, each boss and mini-boss drops a Lost Page.
func _lost_page() -> void:
	if run.daily != "" or bot:
		return
	var i := Residents.find_page()
	if i < 0:
		return
	run.stats["pages"] = int(run.stats.get("pages", 0)) + 1
	Audio.sfx("page_take", player.position)
	Events.toast.emit("Lost Page: %s (%d of %d)" % [Residents.PAGES[i]["title"], i + 1, Residents.PAGES.size()])


## Called by main.gd when the reward screen closes (taken or skipped).
func reward_taken() -> void:
	orb = {}
	paused = false
	# the start orb may have swapped the hero (Rewards.grant -> set_loadout): dress the part
	player.set_look(run.hero)
	if bonus_orb:
		bonus_orb = false
		orb = {"pos": _find_floor(gw / 2, gh / 2), "kind": &"risk", "t": 0.0}
		Story.say("untouched")
		return
	if not run.bag.is_empty() or run.spell_refs().size() > 2:
		Hints.show("editor")
	_open_doors()
	SaveGame.save_run(run)


## Called by main.gd when a shop or forge screen closes.
func ui_done() -> void:
	paused = false
	SaveGame.save_run(run)


func _check_doors() -> void:
	if not doors_open or player.position.y > TS * 0.9:
		return
	for d in doors:
		var x0 := int(d["col"]) * TS
		if player.position.x >= x0 - 2 and player.position.x <= x0 + TS * 2 + 2:
			go_through(d["def"])
			return


func go_through(def: Dictionary) -> void:
	if StringName(def["kind"]) == &"descend" or (StringName(def["kind"]) == &"exit" and run.world + 1 < Chapter.WORLDS.size()):
		# the descent screen (main opens WorldScreen, then calls enter_next_world); with no
		# one to show it (tests, the bot, the bench) the run goes straight on
		if bot or ui_request.get_connections().is_empty():
			enter_next_world()
		else:
			paused = true
			Audio.sting("reward")
			ui_request.emit(&"world", {"to": run.world + 1})
		return
	if StringName(def["kind"]) == &"exit":
		run.won = true
		paused = true
		SaveGame.clear_run()
		ui_request.emit(&"victory", {})
		return
	run.path.append(Chapter.door_key(def))
	if def.has("lane"):
		run.lane = int(def["lane"])
	if StringName(def["kind"]) == &"glitch":
		# the Glitch Door takes its toll on the way in
		run.max_hp = maxf(20.0, run.max_hp - Chapter.GLITCH_COST)
		run.hp = minf(run.hp, run.max_hp)
		Events.toast.emit("The Glitch takes %d max HP" % int(Chapter.GLITCH_COST))
		Audio.sfx("glitch_toll")
	run.room = def
	run.step += 1
	run.doors = []
	run.shop = []
	enter_room()


## The boss fell and the descent leads on (research/design-w2.md, research/story.md): the
## next world's start room, a fresh map, the lesson run's coaching over, and the world-clear
## bonus (+10 max HP, a full heal).
const WORLD_BONUS_HP := 10.0


func enter_next_world() -> void:
	paused = false
	run.max_hp += WORLD_BONUS_HP
	run.hp = run.max_hp
	player.hp = run.max_hp
	run.world += 1
	run.step = 0
	run.tutorial = false
	run.room = {}
	run.doors = []
	run.shop = []
	run.lane = 1
	run.map = []
	run.map = Chapter.make_map(run)
	enter_room()
	Audio.sting("world")   # after the room: the new world's music is the current track
	Events.toast.emit("World clear: +%d max HP" % int(WORLD_BONUS_HP))


func _on_player_died() -> void:
	dead_t = 1.1   # death to the retry screen quickly (design-plan: back in a run in ~3 s)
	Audio.snapshot(&"dead")
	fx.text(player.position + Vector2(0, -30), "THE GLITCH WINS", Color("#ff3fa4"), 10)


# ------------------------------------------------------------------ simulation

func _physics_process(dt: float) -> void:
	if auto_step:
		step(dt)


func _process(_dt: float) -> void:
	var frac := Engine.get_physics_interpolation_fraction()
	bullets.sync(frac)
	ebullets.sync(frac)
	_deco.queue_redraw()
	_decals.queue_redraw()
	_top.queue_redraw()


func step(dt: float) -> void:
	if paused or run == null:
		return
	if _stop > 0.0:
		_stop -= dt
		fx.update(dt * 0.25)
		return
	time += dt
	room_time += dt
	run.stats["time"] += dt
	if Game.assist > 0.0:
		run.stats["assist"] = true   # 0.22: a daily played with Assist shows ASSIST
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * dt)
	kick = kick.move_toward(Vector2.ZERO, dt * 24.0)
	if dead_t > 0.0:
		dead_t -= dt
		player.death_tick(dt)
		fx.update(dt)
		if dead_t <= 0.0:
			paused = true
			SaveGame.clear_run()
			ui_request.emit(&"defeat", {})
		return
	# drop the dead, then index the living for this tick
	var alive: Array[Enemy] = []
	for e in enemies:
		if e.dead:
			e.queue_free()
		else:
			alive.append(e)
	enemies = alive
	hash.rebuild(enemies)
	if bot:
		_bot_drive()
	player.tick(dt)
	for c in companions:
		if c.visible:
			c.tick(dt)
	_bark_tick(dt)
	if Game.quiet == 0:
		Audio.player_hp(run.hp / run.max_hp)
	for e in enemies:
		if not e.dead:
			e.tick(dt)
	_separate()
	_unstick()
	spells.update(dt)
	_update_enemy_bullets(dt)
	_leak(dt)
	_grow_puddles(dt)
	_update_room(dt)
	_music_layers()
	_check_doors()
	fx.update(dt)


func _update_room(dt: float) -> void:
	if hub:
		hub.update(dt)
		return
	if not cage.is_empty() and cage["open"]:
		cage["t"] = float(cage["t"]) + dt
		if not cage.get("said", true) and float(cage["t"]) >= CAGE_REVEAL:
			cage["said"] = true
			if Game.quiet == 0 and run.daily == "":
				for l in Residents.freed_lines(cage["who"]):
					Events.say.emit(l["who"], l["text"], l["id"])
	if not cleared:
		if room_kind == &"mini" or room_kind == &"boss":
			if boss == null:
				boss_t -= dt
				if boss_t <= 0.0:
					_spawn_boss()
			elif boss.dead:
				_clear_room()
		elif wave_i < waves.size():
			if Encounter.wave_done(wave_live):
				wave_t -= dt
				if wave_t <= 0.0:
					_spawn_wave(waves[wave_i])
					wave_i += 1
					wave_t = 0.6
		elif enemies.all(func(e: Enemy) -> bool: return e.dead):
			_clear_room()
	# the reward orb opens the reward screen on touch
	if not orb.is_empty():
		if orb["t"] > 0.8:
			Hints.show("orb")
		orb["t"] += dt
		if orb["t"] > 0.5 and player.position.distance_to(orb["pos"]) < 14.0:
			paused = true
			Audio.sting("reward")
			var kind: StringName = orb["kind"]
			ui_request.emit(&"reward", {"kind": kind, "offer": Rewards.offer(run, kind)})
			return
	if secret_open and treasure != Vector2.INF and player.position.distance_to(treasure) < 14.0:
		treasure = Vector2.INF
		paused = true
		Audio.sfx("chest")
		Audio.sting("reward")
		ui_request.emit(&"reward", {"kind": &"secret", "offer": Rewards.offer(run, &"secret")})
		return
	if not npc.is_empty():
		var near: bool = player.position.distance_to(npc["pos"]) < 18.0
		if near and not npc["near"]:
			match npc["kind"]:
				&"spring":
					if not npc["used"]:
						npc["used"] = true
						player.heal(run.max_hp * (SPRING_HEAL - 0.2 if run.heat >= 4 else SPRING_HEAL))
						Audio.sfx("heal")
						fx.ring(npc["pos"], 4.0, 50.0, 0.6, Color("#6fb8ff"))
						Events.toast.emit("The spring restores you")
				&"shop", &"forge":
					paused = true
					ui_request.emit(npc["kind"], {})
				&"altar", &"terminal":
					if not npc["used"]:
						npc["used"] = true
						paused = true
						ui_request.emit(&"reward", {"kind": npc["kind"], "offer": Rewards.offer(run, npc["kind"])})
		npc["near"] = near


func _separate() -> void:
	for a in enemies:
		if a.dead or a.spawn_t > 0.0 or a.heavy:
			continue
		for k in hash.query(a.position, a.r + 12.0):
			var b: Enemy = enemies[k]
			if b == a or b.dead or b.spawn_t > 0.0:
				continue
			var d := b.position - a.position
			var dist := d.length()
			var m := a.r + b.r
			if dist < m and dist > 0.01:
				a.position = move_body(a.position, a.r, -d * (m - dist) * 0.25 / dist)


## Safety net: anything that ended up inside a wall (a dash into a corner, a shove from a
## crowd) is put back on the nearest open floor, so no fight can get stuck.
func _unstick() -> void:
	for e in enemies:
		if not e.dead and e.spawn_t <= 0.0 and e.ai != &"part" and not (e is Boss) and solid_at(e.position):
			e.position = _find_floor(floori(e.position.x / TS), floori(e.position.y / TS))
			e.knock = Vector2.ZERO
	if solid_at(player.position):
		player.position = _find_floor(floori(player.position.x / TS), floori(player.position.y / TS))


func _update_enemy_bullets(dt: float) -> void:
	for b in ebullets.active:
		if not b.alive:
			continue
		b.prev = b.pos
		b.life -= dt
		if b.accel != 0.0:
			b.vel += b.vel.normalized() * b.accel * dt
		b.pos += b.vel * dt
		b.spin += dt * 6.0
		if b.life <= 0.0 or solid_at(b.pos):
			b.alive = false
			fx.sparks(b.pos, 3, b.color, 40.0)
			continue
		if not spells.blockers.is_empty() and spells.blocked(b.pos, b.r):
			b.alive = false
			fx.sparks(b.pos, 3, Style.c("gold:4"), 40.0)
			shots_stopped(1)
			continue
		if not spells.summons.is_empty() and spells.decoy_takes(b.pos, b.r):
			b.alive = false
			fx.sparks(b.pos, 3, Style.c("gold:4"), 40.0)
			continue
		if player.hit_by(b.pos, b.r):
			b.alive = false
			player.hurt(b.dmg, b.pos, b.by)
	ebullets.compact()


func clear_enemy_bullets() -> void:
	for b in ebullets.active:
		if b.alive:
			b.alive = false
			fx.sparks(b.pos, 1, b.color, 20.0)


## EMP: wipes out the enemy shots within r of p. Returns how many.
func clear_enemy_bullets_in(p: Vector2, r: float) -> int:
	var n := 0
	for b in ebullets.active:
		if b.alive and b.pos.distance_squared_to(p) < (r + b.r) * (r + b.r):
			b.alive = false
			fx.sparks(b.pos, 2, Style.c("cyan:4"), 40.0)
			n += 1
	return n


## Enemy shots your spells stopped (a blocker or EMP). Shot Recycler refills the wand in hand.
func shots_stopped(n: int) -> void:
	if n <= 0 or run == null or not run.has_relic(&"liquid_cooling"):
		return
	var w := run.wand()
	w.mana = minf(w.max_mana(), w.mana + 2.0 * n)


func enemy_shoot(pos: Vector2, ang: float, spd: float, dmg: float, accel := 0.0, by := "") -> void:
	var b := ebullets.spawn()
	if b == null:
		return
	b.pos = pos
	b.prev = pos
	# Bug Reports 3+: race conditions, shots fly 15% faster
	b.vel = Vector2.from_angle(ang) * spd * (1.15 if run and run.heat >= 3 else 1.0) * Game.assist_shot_mul()
	b.life = 4.0
	b.max_life = 4.0
	b.dmg = dmg
	b.r = 2.5
	b.accel = accel
	b.by = by
	b.color = Color.WHITE   # the texture carries the reserved threat colors
	Audio.enemy_shot(shot_sound, by, pos)


## A soft point light. Lights brighten what the ambient CanvasModulate darkens.
func make_light(c: Color, energy: float, size_px: float) -> PointLight2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_light_tex = gt
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = c
	l.energy = energy
	l.texture_scale = size_px / 128.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l


func room_size() -> Vector2:
	return Vector2(gw * TS, gh * TS)


## The floor tile nearest to (x, y), searching outward ring by ring.
func _find_floor(x: int, y: int) -> Vector2:
	for rad in 8:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if tile_at(x + dx, y + dy) == 0:
					return _center(x + dx, y + dy)
	return _center(x, y)


func _center(x: int, y: int) -> Vector2:
	return Vector2(x * TS + TS / 2.0, y * TS + TS / 2.0)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ------------------------------------------------------------------ queries & combat

func tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return 1
	return grid[y * gw + x]


## Solid for spells and bodies: walls, pillars, crates, brambles, cracked walls, pods, pylons.
## Pits (5) are not: spells fly over them. Bodies test body_solid_at instead.
func solid_at(p: Vector2) -> bool:
	var t := tile_at(floori(p.x / TS), floori(p.y / TS))
	return t == 1 or t == 3 or t == 4 or t >= 6


## Solid for walking: everything solid, plus pits (unless something is being knocked in).
func body_solid_at(p: Vector2) -> bool:
	var t := tile_at(floori(p.x / TS), floori(p.y / TS))
	return t == 1 or t == 3 or t == 4 or t >= 5


## 0 the Cellar, 1 the Grove (World 1); 2 the Cooling Vents, 3 the Molten Core (World 2).
func biome() -> int:
	if run == null:
		return 0
	return run.world * 2 + (1 if run.step >= Chapter.AREAS[1]["from"] else 0)


func _repaint() -> void:
	var img := RoomPainter.paint(grid, gw, gh, _paint_seed, biome())
	_floor.texture = ImageTexture.create_from_image(img)
	_rebuild_lips(img)


## D6: the front-cap overlay (design-plan §7). A wall whose north side is open floor gets its
## cap raised LIP px above its tile, as a sprite y-sorted with the actors at the tile's top:
## anything standing behind it (feet above that line) has its feet hidden by the wall, so
## pillars and the south wall read as solid in front of you. One sprite per horizontal run.
func _rebuild_lips(img: Image) -> void:
	for s in _lips:
		s.queue_free()
	_lips.clear()
	var o := RoomPainter.MARGIN * TS
	for y in gh:
		var x := 0
		while x < gw:
			if not _lip_at(x, y):
				x += 1
				continue
			var x0 := x
			while x < gw and _lip_at(x, y):
				x += 1
			var region := img.get_region(Rect2i(o.x + x0 * TS, o.y + y * TS, (x - x0) * TS, LIP))
			var s := Sprite2D.new()
			s.texture = ImageTexture.create_from_image(region)
			s.centered = false
			s.position = Vector2(x0 * TS, y * TS)
			s.offset = Vector2(0, -LIP)
			_actors.add_child(s)
			_lips.append(s)


func _lip_at(x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return (t == 1 or t == 3 or t == 7) and y > 0 and tile_at(x, y - 1) != 1 and tile_at(x, y - 1) != 3 and tile_at(x, y - 1) != 7


## Smashes the crate at a tile (spells do this; enemy shots don't). Drops a little gold.
func break_crate(tx: int, ty: int) -> void:
	if tile_at(tx, ty) != 4:
		return
	grid[ty * gw + tx] = 0
	grid_ver += 1
	var p := _center(tx, ty)
	fx.dissolve(p + Vector2(0, 7), _crate_texture())
	fx.sparks(p, 6, Color("#c8a070"), 70.0)
	Audio.sfx("crate", p)
	if run:
		var g := rng.randi_range(1, 3)
		run.gold += g
		fx.text(p + Vector2(0, -10), "+%d" % g, Color("#ffd36b"))


## An explosion's effect on the room: crates smash, spore pods go off (and chain), cracked
## walls open (a secret), and a burning blast clears brambles.
func break_crates_in(p: Vector2, r: float, burning := false) -> void:
	for ty in range(floori((p.y - r) / TS), floori((p.y + r) / TS) + 1):
		for tx in range(floori((p.x - r) / TS), floori((p.x + r) / TS) + 1):
			if _center(tx, ty).distance_to(p) >= r + TS * 0.5:
				continue
			match tile_at(tx, ty):
				4:
					break_crate(tx, ty)
				6:
					if burning:
						burn_bramble(tx, ty)
				7:
					open_cracked(tx, ty)
				8:
					pop_pod(tx, ty)


## A spell hit a feature tile (the spell ends or bounces there). Brambles burn from fire,
## pods pop, pylons pulse.
func tile_hit(tx: int, ty: int, burning: bool) -> void:
	match tile_at(tx, ty):
		6:
			if burning:
				burn_bramble(tx, ty)
		8:
			pop_pod(tx, ty)
		9:
			pulse_pylon(tx, ty)


const POD_R := 34.0
const POD_DMG := 22.0
const PYLON_R := 80.0


func pop_pod(tx: int, ty: int) -> void:
	if tile_at(tx, ty) != 8:
		return
	grid[ty * gw + tx] = 0
	grid_ver += 1
	var p := _center(tx, ty)
	fx.ring(p, 3.0, POD_R, 0.3, Style.c("ember:3"))
	fx.sparks(p, 16, Style.c("ember:4"), 140.0)
	shake(0.15)
	Audio.sfx("pod_pop", p)
	for k in hash.query(p, POD_R + 16.0):
		var e: Enemy = enemies[k]
		if not e.dead and e.spawn_t <= 0.0 and e.position.distance_to(p) < POD_R + e.r:
			hurt_enemy(e, POD_DMG, p, 0.0, 1.5, false, 2)
	break_crates_in(p, POD_R)   # chains into other pods
	_deco.queue_redraw()


func burn_bramble(tx: int, ty: int) -> void:
	if tile_at(tx, ty) != 6:
		return
	grid[ty * gw + tx] = 0
	grid_ver += 1
	var p := _center(tx, ty)
	fx.sparks(p, 10, Style.c("ember:3"), 60.0)
	fx.ring(p, 2.0, 10.0, 0.25, Style.c("ember:4"))
	Audio.sfx("bramble_burn", p)
	_deco.queue_redraw()


func open_cracked(tx: int, ty: int) -> void:
	if tile_at(tx, ty) != 7:
		return
	grid[ty * gw + tx] = 0
	grid_ver += 1
	secret_open = true
	var p := _center(tx, ty)
	fx.sparks(p, 20, Style.c("stone:3"), 100.0)
	fx.text(p + Vector2(0, -16), "A SECRET!", Style.c("gold:4"), 10)
	shake(0.2)
	Audio.sfx("crack_open", p)
	Audio.sfx("secret", p)
	_repaint()
	_deco.queue_redraw()


## A rune pylon, when hit: a pulse that stuns enemies near it and strips their wards.
func pulse_pylon(tx: int, ty: int) -> void:
	var key := ty * gw + tx
	if pylon_cd.get(key, 0.0) > time:
		return
	pylon_cd[key] = time + 4.0
	var p := _center(tx, ty)
	fx.ring(p + Vector2(0, -8), 4.0, PYLON_R, 0.4, Style.c("cyan:4"))
	# the pylon's note climbs A C E A' with the Loop's derail count (sound v2 §4.8)
	Audio.sfx("pylon", p, 0.0, (boss as BossLoop).pulses if boss is BossLoop and boss.phase >= 1 else 0)
	for k in hash.query(p, PYLON_R + 16.0):
		var e: Enemy = enemies[k]
		if e.dead or e.spawn_t > 0.0 or e.position.distance_to(p) > PYLON_R + e.r:
			continue
		e.ward_n = 0
		if not (e is Boss):
			e.stun_t = maxf(e.stun_t, 1.2)
	if boss and not boss.dead:
		boss.on_pylon()
	_deco.queue_redraw()


## A body over a pit falls in (fodder only: heavy enemies and bosses never get knocked in).
func fall_check(e: Enemy) -> void:
	if e.heavy or e.dead or e is Boss or e.ai == &"part":
		return
	if tile_at(floori(e.position.x / TS), floori(e.position.y / TS)) == 5:
		fx.text(e.position + Vector2(0, -12), "FELL", Style.c("bone:4"))
		Audio.sfx("pit_fall", e.position)
		fx.ring(e.position, 2.0, 8.0, 0.25, Style.c("night:4"))
		kill_enemy(e)


func hitstop(t: float) -> void:
	_stop = maxf(_stop, t)
	Audio.on_hitstop(t)
	_last_stop = time


## A brief full-screen flash (white, never red; at most ~3 per second), if the player allows it,
## scaled by the Flash setting (100% / 50% / OFF).
func flash(amount: float, c := Color.WHITE) -> void:
	if not Game.flash_fx or time - _flash_t < 0.34:
		return
	_flash_t = time
	if Game.quiet == 0:
		Events.screen_flash.emit(c, amount * Game.flash_scale)


func hazard_at(p: Vector2) -> bool:
	return tile_at(floori(p.x / TS), floori(p.y / TS)) == 2


func spikes_up() -> bool:
	return fmod(time, 2.4) > 1.5


## Circle-vs-tiles movement, one axis at a time, in sub-steps short enough that nothing
## tunnels through a wall. Sets last_hit_x / last_hit_y.
var _fall_ok := false


## Moves a body, sliding along walls. `fall_ok`: a knock or a pull may carry it over a pit.
func move_body(pos: Vector2, r: float, delta: Vector2, fall_ok := false) -> Vector2:
	_fall_ok = fall_ok
	var n := ceili(delta.length() / 6.0)
	if n <= 1:
		last_hit_x = false
		last_hit_y = false
		return _move_step(pos, r, delta)
	var p := pos
	var hx := false
	var hy := false
	for i in n:
		p = _move_step(p, r, delta / n)
		hx = hx or last_hit_x
		hy = hy or last_hit_y
	last_hit_x = hx
	last_hit_y = hy
	return p


func _move_step(pos: Vector2, r: float, delta: Vector2) -> Vector2:
	last_hit_x = false
	last_hit_y = false
	var p := pos
	p.x += delta.x
	if delta.x != 0.0:
		var ex := p.x + (r if delta.x > 0.0 else -r)
		if _blocked(Vector2(ex, p.y - r * 0.7)) or _blocked(Vector2(ex, p.y + r * 0.7)):
			p.x = floorf(ex / TS) * TS - r - 0.01 if delta.x > 0.0 else (floorf(ex / TS) + 1.0) * TS + r + 0.01
			last_hit_x = true
	p.y += delta.y
	if delta.y != 0.0:
		var ey := p.y + (r if delta.y > 0.0 else -r)
		if _blocked(Vector2(p.x - r * 0.7, ey)) or _blocked(Vector2(p.x + r * 0.7, ey)):
			p.y = floorf(ey / TS) * TS - r - 0.01 if delta.y > 0.0 else (floorf(ey / TS) + 1.0) * TS + r + 0.01
			last_hit_y = true
	return p


func _blocked(p: Vector2) -> bool:
	return solid_at(p) if _fall_ok else body_solid_at(p)


## Line of sight. Crates block movement but not aim (spells smash them), so by default
## they do not block sight either.
func los(a: Vector2, b: Vector2, crates_block := false) -> bool:
	var n := ceili(a.distance_to(b) / 8.0)
	for k in range(1, n):
		var q := a.lerp(b, float(k) / n)
		var t := tile_at(floori(q.x / TS), floori(q.y / TS))
		if t == 1 or t == 3 or t == 6 or t == 7 or (crates_block and t == 4):
			return false
	return true


func nearest_enemy(p: Vector2, max_d: float, exclude := -1) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in enemies:
		if e.dead or e.spawn_t > 0.0 or e.uid == exclude:
			continue
		var d := e.position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	return best


## Blame: the live enemy with the most HP left (a locked guardian only when nothing else is).
func toughest_enemy(exclude := -1) -> Enemy:
	var best: Enemy = null
	var bh := -1.0
	for e in enemies:
		if e.dead or e.spawn_t > 0.0 or e.uid == exclude:
			continue
		var h := e.hp * (0.01 if e.locked else 1.0)
		if h > bh:
			bh = h
			best = e
	return best


## Auto-aim target: the nearest enemy in line of sight, else the nearest one. The current
## target is kept until another is clearly nearer (by 25%), so aim does not flicker between
## two about as close (playtest: the view and the shots swung to and fro in a swarm).
func assist_target(p: Vector2, max_d: float, keep: Enemy = null) -> Enemy:
	var best: Enemy = null
	var vis: Enemy = null
	var bd := max_d * max_d
	var vd := bd
	for e in enemies:
		if e.dead or e.spawn_t > 0.0:
			continue
		var d := e.position.distance_squared_to(p)
		if e.locked:
			d *= 9.0   # Deadlock: a locked guardian takes nothing, so aim prefers the open one
		if d < bd:
			bd = d
			best = e
		if d < vd and los(p, e.position):
			vd = d
			vis = e
	if keep and keep != vis and not keep.dead and not keep.locked and vis and keep.spawn_t <= 0.0:
		var kd := keep.position.distance_squared_to(p)
		if kd < max_d * max_d and kd * 0.5625 < vd and los(p, keep.position):
			return keep
	return vis if vis else best


## Hit flag: damage passed on from a boss's body part. It skips the head's armour.
const SOFT := 8


## Damage to an enemy. `kw` carries the hit's resist keywords (SpellRunner.keywords: 1
## pierce, 2 blast, 4 shock), which is what breaks shields, armour and wards (D4).
func hurt_enemy(e: Enemy, dmg: float, from: Vector2, crit_chance: float, kb: float, dot := false, kw := 0) -> float:
	if e.dead or e.spawn_t > 0.0:
		return 0.0
	if e.squiggle and not dot:
		dmg *= SQUIGGLE_DMG
	if e.locked and not (kw & SOFT):
		# Deadlock: the locked guardian takes nothing (a spark off the padlock); what the open
		# one takes is passed to the pool (SOFT), which lives on the other, locked or not
		if not dot and e._def_fx <= 0.0:
			e._def_fx = 0.4
			fx.text(e.position + Vector2(0, -26), "LOCKED", Style.c("steel:4"))
			Audio.sfx("locked", e.position)
		if not dot:
			fx.sparks(from, 2, Style.c("steel:4"), 50.0)
		return 0.0
	if not dot and not e.def.get("proxy", false) and e.ai != &"part" and not (e is Boss):
		# a Proxy nearby takes the hit instead (its tether shows who it covers)
		for o in enemies:
			if o != e and not o.dead and o.spawn_t <= 0.0 and o.def.get("proxy", false) and o.position.distance_squared_to(e.position) < Enemy.PROXY_R * Enemy.PROXY_R:
				fx.beam(e.position + Vector2(0, -6), o.position + Vector2(0, -6), Style.c("cyan:4"), 0.6)
				Audio.sfx("hit_proxy", o.position)
				return hurt_enemy(o, dmg, o.position, crit_chance, kb * 0.3, dot, kw)
	if e.forward:
		e.flash = 0.07
		return hurt_enemy(e.forward, dmg * e.fwd_mul, from, crit_chance, 0.0, dot, kw | SOFT)
	if e is Boss and (e as Boss).invuln > 0.0:
		return 0.0
	if not dot and (e.ward_n > 0 or e.shield_hp > 0):
		if not _through_defences(e, from, kw):
			return 0.0
	if e is Boss and (e as Boss).weak_t > 0.0:
		dmg *= (e as Boss).weak_mul
	if e.armor > 0.0 and not (kw & SOFT):
		# armour soaks everything (a boss's body passes its share straight through); Blast tears it off three times as fast
		var ad := dmg * (3.0 if kw & 2 else (0.2 if dot else 0.35))
		e.armor -= ad
		e.flash = 0.07
		if not dot:
			fx.sparks(e.position + Vector2(0, -6), 2, Style.c("steel:4"), 50.0)
			Audio.sfx("hit_armor", e.position)
			Hints.show("armor")
		if e.armor <= 0.0:
			e.armor = 0.0
			fx.text(e.position + Vector2(0, -18), "ARMOR BROKEN", Style.c("steel:4"))
			Audio.sfx("armor_break", e.position)
			fx.ring(e.position + Vector2(0, -6), 2.0, 16.0, 0.3, Style.c("steel:4"))
			shake(0.12)
		return 0.0
	var crit := crit_chance > 0.0 and rng.randf() < crit_chance
	# Zero-Day Exploit: the first hit on an unhurt enemy is always a crit
	if not dot and not crit and e.hp >= e.max_hp and run and run.has_relic(&"zero_day"):
		crit = true
	if crit:
		dmg *= 2.0
	if run and run.has_relic(&"cold_boot") and e.chill_t > 0.0:
		dmg *= 1.25
	if not dot and run and e.static_t > 0.0 and run.has_relic(&"overvoltage"):
		dmg *= 1.4   # 0.21 Charged Strike: the hit that sets off a charge
	# Target Lock: the marked enemy takes 30% more
	if run and e == marked and e.mark_t > 0.0 and run.has_relic(&"keep_alive"):
		dmg *= 1.3
	if not dot and run and run.has_relic(&"null_pointer") and e.hp >= e.max_hp:
		dmg *= 2.0
	# Overclocked (D2): two or more statuses at once and every hit lands 20% harder
	if not dot and (e.burn_t > 0.0 or e.chill_t > 0.0 or e.static_t > 0.0 or e.rot_n > 0) and e.status_count() >= 2:
		dmg *= 1.2
	dmg = maxf(1.0, dmg) if not dot else dmg
	e.hp -= dmg
	e.flash = 0.07
	damage_done += dmg
	if run:
		run.stats["damage"] += dmg
		if not dot and dmg > float(run.stats.get("max_hit", 0.0)):
			run.stats["max_hit"] = dmg
		if not dot and dmg >= 60.0:
			bark(&"big_hit", {"dmg": dmg})
	if not e.heavy and kb > 0.0:
		e.knock += (e.position - from).normalized() * kb * (70.0 if crit else 38.0)
	if crit and time - _last_stop > 0.25:
		hitstop(0.06)   # 0.22: 45 ms read as a stutter, 60 ms as a hit
		shake(0.15)
	if not dot:
		fx.number(e.position + Vector2(0, -e.r - 10), dmg, crit, e.uid)
		fx.hit_spark(e.position + Vector2(0, -6), (e.position - from).angle(), Style.c("gold:4") if crit else Style.c("arcane:4"))
		Audio.hit(hit_sound, e.position, crit, e.heavy or e is Boss or e.ai == &"part")
		if crit:
			Game.haptic("crit")
	# Static: a charged enemy passes the next hit on to a neighbour as an arc
	if not dot and not _cascading and e.static_t > 0.0:
		e.static_t = 0.0
		# Surge Protector: two arcs at full damage
		var surge := run != null and run.has_relic(&"surge_protector")
		var done: Array[int] = [e.uid]
		_cascading = true
		var cold := run != null and run.has_relic(&"superconductor")   # Cold Current: one more arc, and they chill
		for k in (2 if surge else 1) + (1 if cold else 0):
			var nb: Enemy = null
			var bd := 70.0 * 70.0
			for o in enemies:
				if o.dead or o.spawn_t > 0.0 or done.has(o.uid):
					continue
				var dd := o.position.distance_squared_to(e.position)
				if dd < bd:
					bd = dd
					nb = o
			if nb == null:
				break
			done.append(nb.uid)
			fx.beam(e.position + Vector2(0, -4), nb.position + Vector2(0, -4), Style.c("gold:4"), 1.0)
			hurt_enemy(nb, dmg * (1.0 if surge else 0.6), e.position, 0.0, 0.3, false, 4)
			if cold:
				apply_status(nb, 0, 1, dmg)
		_cascading = false
	# 0.21 Shock Charge: a hit that strips wards (Shock) charges what it hits (arcs do not)
	if kw & 4 and not dot and not _cascading and not e.dead and run and run.has_relic(&"live_wire"):
		e.static_t = 4.0
	if crit and not dot and not _cascading and run and run.has_relic(&"cascade_failure"):
		var nx := nearest_enemy(e.position, 60.0, e.uid)
		if nx:
			_cascading = true
			fx.beam(e.position + Vector2(0, -4), nx.position + Vector2(0, -4), Color("#fff27a"), 1.0)
			hurt_enemy(nx, dmg * 0.5, e.position, 0.0, 0.3)
			_cascading = false
	if e.hp <= 0.0 and e.can_die():
		kill_enemy(e)
	return dmg


## Burn and chill (D2): three chills in a row freeze; fire meeting ice is a Thermal Shock.
func apply_status(e: Enemy, burn: int, chill: int, dmg: float) -> void:
	if e.dead:
		return
	var tgt := e.forward if e.forward else e
	if (burn > 0 and tgt.chill_t > 0.0) or (chill > 0 and tgt.burn_t > 0.0):
		if tgt.shock_t <= 0.0:
			_thermal_shock(tgt, dmg)
			return
	if burn > 0:
		var base := tgt.burn_dps if tgt.burn_t > 0.0 else 0.0
		# design v2: the Pyromancer's burns last 50% longer and hurt 25% more
		var pyro := run != null and run.hero == &"pyromancer"
		tgt.burn_t = 2.5 * (1.5 if pyro else 1.0)
		tgt.burn_dps = maxf(base, maxf(4.0 + burn * 4.0, dmg * 0.4) * (1.25 if pyro else 1.0))
	if chill > 0 and not (tgt is Boss):
		tgt.chill_t = 1.2 + chill * 0.4
		tgt.chill_slow = [0.6, 0.5, 0.4][clampi(chill, 1, 3) - 1]
		tgt.chill_n += chill
		if tgt.chill_n >= (2 if run and run.has_relic(&"flash_freeze") else 3) and tgt.frozen_t <= 0.0:   # 0.21 Quick Freeze
			tgt.chill_n = 0
			tgt.frozen_t = 0.9
			fx.ring(tgt.position + Vector2(0, -4), 2.0, 12.0, 0.25, Style.c("frost:4"))
			fx.text(tgt.position + Vector2(0, -16), "FROZEN", Style.c("frost:4"))
			Audio.sfx("freeze", tgt.position)


## Thermal Shock: burn and chill cancel in a burst that hurts the target and its neighbours.
func _thermal_shock(e: Enemy, dmg: float) -> void:
	_count("thermal")
	e.shock_t = 0.6
	e.burn_t = 0.0
	e.chill_t = 0.0
	e.chill_n = 0
	var hit := 10.0 + dmg * 0.8
	var reach := 22.0
	var throttle := run != null and run.has_relic(&"thermal_throttle")
	if throttle:
		hit *= 2.0
		reach = 44.0
	fx.ring(e.position + Vector2(0, -4), 2.0, reach, 0.3, Style.c("frost:4"))
	fx.ring(e.position + Vector2(0, -4), 2.0, 16.0, 0.25, Style.c("ember:3"))
	fx.text(e.position + Vector2(0, -16), "THERMAL SHOCK", Style.c("ember:4"))
	Audio.sfx("thermal", e.position)
	for k in hash.query(e.position, reach + 18.0):
		var o: Enemy = enemies[k]
		if o != e and not o.dead and o.spawn_t <= 0.0 and o.position.distance_to(e.position) < reach + o.r:
			hurt_enemy(o, hit * 0.5, e.position, 0.0, 0.6)
			if throttle and not o.dead:
				o.burn_t = 2.5
				o.burn_dps = maxf(o.burn_dps, 8.0)
	hurt_enemy(e, hit, e.position, 0.0, 0.6)


## Wards and shields (D4). False when the hit is swallowed.
##   ward    swallows a whole hit per charge; a Shock hit strips it at once and goes through
##   shield  a frontal arc toward the enemy's target; a Pierce hit breaks it and goes through,
##           any other frontal hit is blocked and wears it down (so nothing is ever unkillable)
func _through_defences(e: Enemy, from: Vector2, kw: int) -> bool:
	if e.ward_n > 0:
		if kw & 4:
			e.ward_n = 0
			Audio.sfx("ward_break", e.position)
			fx.text(e.position + Vector2(0, -18), "WARD STRIPPED", Style.c("cyan:4"))
			fx.ring(e.position + Vector2(0, -6), 2.0, e.r + 6.0, 0.25, Style.c("cyan:4"))
		else:
			e.ward_n -= 1
			Hints.show("ward")
			Audio.sfx("hit_ward", e.position)
			fx.ring(e.position + Vector2(0, -6), 1.0, e.r + 4.0, 0.15, Style.c("cyan:4"))
			if e._def_fx <= 0.0:
				e._def_fx = 0.5
				fx.text(e.position + Vector2(0, -18), "WARDED", Style.c("cyan:4"))
			return false
	if e.shield_hp > 0:
		var to_target := (target_pos() - e.position).angle()
		var to_hit := (from - e.position).angle()
		if absf(angle_difference(to_target, to_hit)) < 1.1:
			if kw & 1:
				e.shield_hp = 0
				Audio.sfx("shield_break", e.position)
				fx.text(e.position + Vector2(0, -18), "SHIELD BROKEN", Style.c("steel:4"))
				fx.sparks(e.position + Vector2(0, -6), 10, Style.c("steel:4"), 90.0)
				shake(0.1)
			else:
				e.shield_hp -= 1
				Hints.show("shield")
				Audio.sfx("hit_shield", e.position)
				fx.sparks(from, 3, Style.c("steel:4"), 60.0)
				if e._def_fx <= 0.0:
					e._def_fx = 0.5
					fx.text(e.position + Vector2(0, -18), "BLOCKED", Style.c("steel:4"))
				return false
	return true


## Static Coat / Static Cone: the enemy's next hit arcs to a neighbour.
func charge(e: Enemy) -> void:
	var tgt := e.forward if e.forward else e
	if not tgt.dead:
		tgt.static_t = 4.0


## Bitrot: five stacks crash the target in a small burst.
func add_rot(e: Enemy, n: int) -> void:
	var tgt := e.forward if e.forward else e
	if tgt.dead:
		return
	tgt.rot_n += n
	tgt.rot_t = 4.0
	if tgt.rot_n < (3 if run and run.has_relic(&"rot_index") else 5):
		return
	tgt.rot_n = 0
	_count("crashes")
	var hit := 20.0 + minf(tgt.max_hp * 0.2, 40.0)
	fx.ring(tgt.position + Vector2(0, -4), 2.0, 20.0, 0.3, Style.c("glitch:3"))
	fx.sparks(tgt.position + Vector2(0, -4), 12, Style.c("glitch:3"), 100.0)
	fx.text(tgt.position + Vector2(0, -16), "CRASH", Style.c("glitch:4"))
	Audio.sfx("crash", tgt.position)
	for k in hash.query(tgt.position, 40.0):
		var o: Enemy = enemies[k]
		if o != tgt and not o.dead and o.spawn_t <= 0.0 and o.position.distance_to(tgt.position) < 26.0 + o.r:
			hurt_enemy(o, hit * 0.5, tgt.position, 0.0, 0.8, false, 2)
	hurt_enemy(tgt, hit, tgt.position, 0.0, 0.8, false, 2)


## Hex Cursor: triggers and carriers aim their payloads at the marked enemy.
func mark(e: Enemy, t: float) -> void:
	var tgt := e.forward if e.forward else e
	if tgt.dead:
		return
	tgt.mark_t = t * (2.0 if run and run.has_relic(&"keep_alive") else 1.0)   # Target Lock
	marked = tgt


## Cornered: three or more enemies within reach of the player.
func cornered() -> bool:
	var n := 0
	for k in hash.query(player.position, 60.0):
		var e: Enemy = enemies[k]
		if not e.dead and e.spawn_t <= 0.0 and e.position.distance_squared_to(player.position) < 3600.0:
			n += 1
			if n >= 3:
				return true
	return false


## Memory Leak: a fight slowly drains 1 HP every 10 s (never the last one).
func _leak(dt: float) -> void:
	if cleared or not run.has_relic(&"memory_leak"):
		return
	_leak_t += dt
	if _leak_t >= 10.0:
		_leak_t = 0.0
		if player.hp > 1.0:
			player.hp -= 1.0
			fx.text(player.position + Vector2(0, -30), "-1 LEAK", Style.c("glitch:4"))


## Where enemies go and shoot: the Rubber Duck while one is out, else the player.
func target_pos() -> Vector2:
	if spells == null or spells.summons.is_empty():
		return player.position
	var dk := spells.decoy()
	return dk.pos if dk else player.position


func kill_enemy(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	e.visible = false
	if run:
		run.stats["kills"] += 1
		run.see_enemy(e.kind, true)
		if e.elite:
			_count("elites")
			bark(&"elite_kill", {"elites": int(run.stats.get("elites", 0))})
		run.gold += roundi(int(e.def.get("gold", 1)) * (4 if e.elite else 1) * Relics.gold_mul(run) * 0.5)
		for w in run.wands:
			w.on_kill()   # 0.20: a Recycle Bin refills on kills
		if run.has_relic(&"garbage_collector"):
			for w in run.wands:
				if w.def.rule != &"blood":   # 0.22: an Unsafe Staff has no mana to refill
					w.mana = minf(w.max_mana(), w.mana + 3.0)
		if run.has_relic(&"leech_loop"):
			_kill_streak += 1
			if _kill_streak % 6 == 0:
				player.heal(4.0)
				Audio.sfx("heal_small")
		if run.has_relic(&"wildfire") and e.burn_t > 0.0:
			for k in hash.query(e.position, 44.0):
				var o: Enemy = enemies[k]
				if o != e and not o.dead and o.position.distance_to(e.position) < 36.0 + o.r:
					apply_status(o, 1, 0, e.burn_dps / 0.4)
			fx.ring(e.position, 2.0, 36.0, 0.3, Color("#ff8a3c"))
		if run.has_relic(&"bug_bounty") and not (e is Boss):
			var swarm := run.has_relic(&"swarm_protocol")
			for k in (2 if swarm else 1):
				_release_bug(e.position, 20.0 if swarm else 10.0)
		_relics_on_kill(e)   # 0.20: Contagion, Finisher
		spells.on_kill(e)    # 0.21: Flame Graph's fire spreads
	_on_death(e)
	# design v3: it dies the way it was hurt: burning ones flare into embers, frozen or chilled
	# ones shatter hard, charged ones spit sparks
	var tint := Color(0, 0, 0, 0)
	var burst := 1.0
	if e.burn_t > 0.0:
		tint = Style.c("ember:3")
		fx.sparks(e.position + Vector2(0, -6), 8, Style.c("ember:4"), 70.0)
	elif e.frozen_t > 0.0 or e.chill_t > 0.0:
		tint = Style.c("frost:4")
		burst = 1.7
		fx.ring(e.position + Vector2(0, -4), 2.0, 12.0, 0.2, Style.c("frost:4"))
	elif e.static_t > 0.0:
		tint = Style.c("gold:4")
		for k in 3:
			fx.beam(e.position + Vector2(0, -5), e.position + Vector2(0, -5) + Vector2.from_angle(fx.rng.randf() * TAU) * 12.0, Style.c("gold:4"), 1.0)
	fx.dissolve(e.position, e.sprite.texture if e.sprite else null, e.sprite.flip_h if e.sprite else false, e.sprite.scale.x if e.sprite else 1.0, tint, burst)
	fx.poof(e.position + Vector2(0, -4))
	if not (e is Boss):
		var how := &"burn" if e.burn_t > 0.0 else (&"frost" if e.frozen_t > 0.0 or e.chill_t > 0.0 else (&"static" if e.static_t > 0.0 else &""))
		Audio.kill(e.kind, e.position, 2 if e.elite else (1 if e.heavy else 0), how)
	if e.elite:
		hitstop(0.08)
		shake(0.25)
		Game.haptic("elite_kill")
	elif not (e is Boss) and time - _last_stop > 0.15:
		# design v3 (Vlambeer's "sleep"): two frames on a kill, three on a heavy one; spaced so
		# a swarm dying at once reads as punches, not a stutter
		hitstop(0.05 if e.heavy else 0.033)
	if e is Boss:
		(e as Boss).die()
		run.stats["bosses"] += 1
		hitstop(0.3)
		flash(0.45)
		Game.haptic("boss_kill")
		shake(0.8)
		for k in 6:
			fx.ring(e.position + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)), 2.0, 20.0 + k * 6.0, 0.5, [Color("#ff3fa4"), Color("#ffc94a"), Color("#5ce1ff")][k % 3])
		fx.sparks(e.position, 40, Color("#ffe066"), 180.0)
		Events.boss_defeated.emit()
	fx.sparks(e.position + Vector2(0, -4), 14, Color("#c46bff"), 120.0)
	fx.ring(e.position, 2.0, 12.0, 0.25, Color("#ff3fa4"))
	shake(0.1)
	if Game.quiet == 0:
		Events.enemy_killed.emit(e.kind, e.position)


## What an enemy leaves behind (D4): a Moss Blob splits in two, a Mirrored elite leaves a
## weaker copy, a Forked elite bursts into a ring of shots.
func _on_death(e: Enemy) -> void:
	if e is Boss or e.ai == &"part":
		return
	if e.kind == &"leak":
		dry_puddles(e)
	if e.lock_wand != null:
		interrupt_release(e)
	var n := int(e.def.get("split", 0))
	if n > 0:
		Audio.sfx("split", e.position)
	for k in n:
		var s := spawn_enemy(&"slimelet", e.position + Vector2.from_angle(TAU * k / n + 0.5) * 5.0)
		s.spawn_t = 0.05
	if e.affix == &"mirrored":
		var m := spawn_enemy(e.kind, e.position + Vector2(6, 0))
		m.spawn_t = 0.3
		m.max_hp = e.max_hp * 0.4
		m.hp = m.max_hp
		fx.text(e.position + Vector2(0, -18), "MIRRORED", Style.c("glitch:4"))
	elif e.affix == &"forked":
		for k in 6:
			enemy_shoot(e.position + Vector2(0, -6), TAU * k / 6.0, 80.0, e.dmg * 0.5, 0.0, "fork:%s" % e.kind)


## 0.20 relics at the kill site. Contagion: two or more statuses pass to the nearest enemy
## (stacks kept). Finisher: enemies close by under 15% HP die too, and their deaths chain
## (each enemy once, since the dead are skipped). Bosses and their parts are never finished.
func _relics_on_kill(e: Enemy) -> void:
	if run.has_relic(&"shared_memory") and e.status_count() >= 2:
		var o := nearest_enemy(e.position, 90.0, e.uid)
		if o and not o.dead:
			var t := o.forward if o.forward else o
			if e.burn_t > 0.0:
				t.burn_t = maxf(t.burn_t, e.burn_t)
				t.burn_dps = maxf(t.burn_dps, e.burn_dps)
			if (e.chill_t > 0.0 or e.frozen_t > 0.0) and not (t is Boss):
				t.chill_t = maxf(t.chill_t, maxf(e.chill_t, 1.2))
				t.chill_slow = minf(t.chill_slow, e.chill_slow)
			if e.static_t > 0.0:
				t.static_t = maxf(t.static_t, e.static_t)
			if e.rot_n > 0:
				t.rot_n = maxi(t.rot_n, e.rot_n)
				t.rot_t = maxf(t.rot_t, e.rot_t)
			fx.beam(e.position + Vector2(0, -4), t.position + Vector2(0, -4), Style.c("glitch:4"), 1.0)
	# 0.21 Frost Spread: a chilled enemy's death chills the enemies close by
	if run.has_relic(&"cold_spill") and (e.chill_t > 0.0 or e.frozen_t > 0.0):
		fx.ring(e.position + Vector2(0, -4), 2.0, SPILL_R, 0.3, Style.c("frost:4"))
		for k in hash.query(e.position, SPILL_R + 16.0):
			var o: Enemy = enemies[k]
			if o != e and not o.dead and o.spawn_t <= 0.0 and o.position.distance_to(e.position) < SPILL_R + o.r:
				apply_status(o, 0, 1, 0.0)
	if run.has_relic(&"thread_join"):
		for k in hash.query(e.position, JOIN_R + 16.0):
			var o: Enemy = enemies[k]
			if o == e or o.dead or o.spawn_t > 0.0 or o is Boss or o.ai == &"part" or o.locked:
				continue
			if o.hp < o.max_hp * JOIN_HP and o.position.distance_to(e.position) < JOIN_R + o.r and o.can_die():
				fx.beam(e.position + Vector2(0, -4), o.position + Vector2(0, -4), Style.c("blood:4"), 1.0)
				fx.text(o.position + Vector2(0, -16), "JOINED", Style.c("blood:4"))
				o.hp = 0.0
				kill_enemy(o)


## Bug Bounty: a small homing bolt that hunts the nearest enemy.
func _release_bug(p: Vector2, dmg := 10.0) -> void:
	var b := bullets.spawn()
	if b == null:
		return
	var a := rng.randf() * TAU
	b.pos = p + Vector2(0, -4)
	b.prev = b.pos
	b.a = a
	b.vel = Vector2.from_angle(a) * 150.0
	b.dmg = dmg
	b.r = 2.0
	b.home = 9.0
	b.life = 1.8
	b.max_life = 1.8
	b.color = Color("#9cd01c")
	b.depth = SpellRunner.MAX_DEPTH


## Adds trauma (kill 0.1, crit 0.15, hurt 0.35, boss kill 0.8). Game.shake_scale is the
## player's Shake setting.
func shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount * Game.shake_scale)


# ------------------------------------------------------------------ bot (tests, demo)

## Keeps a fighting distance from the nearest enemy, collects rewards, walks through the
## first door, and (0.22) dashes out of trouble. Reward, shop and forge screens are answered
## by whoever listens to ui_request.
func _bot_drive() -> void:
	_bot_steer()
	_bot_dash(player.position)


func _bot_steer() -> void:
	controls.fire = true
	var p := player.position
	if not orb.is_empty():
		var op: Vector2 = orb["pos"]
		# follow the grid path (a straight line snags on pillar corners)
		controls.move = path_dir(p, op)
		return
	if cleared and doors_open:
		var d: Dictionary = doors[0]
		var below := Vector2(int(d["col"]) * TS + TS, TS * 1.5)
		if p.distance_to(below) > 10.0 and p.y > TS * 1.2:
			controls.move = path_dir(p, below)
		else:
			controls.move = Vector2(0, -1)
		return
	if boss and not boss.dead and boss.bot_goal() != Vector2.INF:
		# 0.20: the Glitch's revert glyphs are worth the walk
		controls.move = _bot_dodge(p, path_dir(p, boss.bot_goal()))
		return
	var e := nearest_enemy(p, 900.0)
	if e == null:
		controls.move = (Vector2(gw * TS / 2.0, gh * TS / 2.0) - p).limit_length(1.0) * 0.5
		return
	# watchdog: no damage for a while means we are stuck somewhere, or our spells cannot
	# reach from here (a short-range wand); walk in on the path until hits land again
	if damage_done > _bot_dmg_seen:
		_bot_dmg_seen = damage_done
		_bot_progress_t = time
	var stuck := time - _bot_progress_t > 8.0
	var to_e := e.position - p
	# sight is judged from the hand, where spells leave the wand (as the player does)
	var sees := los(p + Vector2(0, -8), e.position)
	if stuck or not sees or player.target == null:
		controls.move = _bot_dodge(p, path_dir(p, e.position))
		return
	var dist := to_e.length()
	var want := -1.0 if dist < 50.0 else (1.0 if dist > 140.0 else 0.0)
	var desire := (to_e.normalized() * want + to_e.normalized().orthogonal() * 0.7).limit_length(1.0)
	controls.move = _bot_dodge(p, desire)


## Picks the move (8 directions or standing still) with the least predicted danger over the
## next ~0.4 s, breaking ties toward where the bot wants to go. Roughly how a new player
## dodges: sees bullets coming, sidesteps, sometimes gets cornered.
func _bot_dodge(p: Vector2, desire: Vector2) -> Vector2:
	var best := desire
	var best_score := INF
	for k in 9:
		var dir := Vector2.ZERO if k == 8 else Vector2.from_angle(k * TAU / 8.0)
		# where this move would really take us (sliding along walls); a move that a wall
		# or corner blocks is no move at all
		var q := move_body(p, player.r, dir * Player.SPEED * 0.25)
		if dir != Vector2.ZERO and q.distance_to(p) < 4.0:
			continue
		if hazard_at(q) and spikes_up():
			continue
		var score := _bot_danger_at(q) * 4.0 - dir.dot(desire)
		if score < best_score:
			best_score = score
			best = dir
	return best


## How dangerous standing at q is for the walking dodge: shots about to pass close, a boss's
## hazards, a slow puddle, bodies about to touch.
func _bot_danger_at(q: Vector2) -> float:
	var danger := 0.0
	for b in ebullets.active:
		if not b.alive:
			continue
		var rel := b.pos - q
		if rel.length_squared() > 120.0 * 120.0:
			continue
		var tt := clampf(-rel.dot(b.vel) / maxf(1.0, b.vel.length_squared()), 0.0, 0.4)
		var close := (rel + b.vel * tt).length()
		if close < 12.0:
			danger += (12.0 - close) * (1.4 - tt * 2.0)
	if boss and not boss.dead:
		danger += boss.bot_danger(q)
	if puddle_slow(q) < 1.0:
		danger += 0.15   # a slow patch, not a threat: worth crossing to reach the fight
	for e in enemies:
		if not e.dead and e.spawn_t <= 0.0 and e.dmg > 0.0:
			# where the body will be in a moment, not just where it is
			var dist := minf(e.position.distance_to(q), (e.position + e.vel * 0.25).distance_to(q))
			if dist < e.r + 16.0:
				danger += (e.r + 16.0 - dist) * 1.5
	return danger


## 0.22: the bot dashes like a player. When something will hit it within BOT_DASH_LOOK
## seconds (a shot on course, a boss attack at the end of its telegraph, an enemy's slam,
## burst, charge or snap about to land) and the dash is ready (Player.dash_cd, exactly the
## player's cooldown), it dashes the way that lands clear, if one does. No randomness: the
## same seed plays the same run.
const BOT_DASH_LOOK := 0.3
## An enemy telegraph this full (0..1) is about to release: 0.3-0.35 s left on a slam or burst.
const BOT_DASH_FILL := 0.65


func _bot_dash(p: Vector2) -> void:
	if player.dash_cd > 0.0 or player.dash_t > 0.0 or player.dead:
		return
	var now := _bot_threat(p, 0.0, BOT_DASH_LOOK)
	if now <= 0.0:
		return
	var reach := Player.DASH_SPEED * Player.DASH_T
	var want := controls.move
	var best := Vector2.ZERO
	var best_score := INF
	for k in 8:
		var dir := Vector2.from_angle(k * TAU / 8.0)
		var q := move_body(p, player.r, dir * reach)
		if q.distance_to(p) < reach * 0.5:
			continue   # a wall would eat the dash
		if hazard_at(q):
			continue
		# the i-frames cover the dash itself; what counts is what's coming where it lands
		var threat := _bot_threat(q, Player.DASH_T, Player.DASH_T + BOT_DASH_LOOK)
		if threat >= now:
			continue
		var score := threat * 100.0 + _bot_danger_at(q) - dir.dot(want)
		if score < best_score:
			best_score = score
			best = dir
	if best != Vector2.ZERO:
		controls.move = best
		controls.dash = true


## What will hit a body standing at q between t0 and t1 seconds from now, counted in hits.
func _bot_threat(q: Vector2, t0: float, t1: float) -> float:
	var n := 0.0
	var c := q + (Player.HURT_TOP + Player.HURT_LOW) / 2.0   # the hurt capsule's middle
	var half := (Player.HURT_LOW - Player.HURT_TOP).length() / 2.0
	for b in ebullets.active:
		if not b.alive or b.life <= t0:
			continue
		var rel := b.pos + b.vel * t0 - c
		var reach := b.vel.length() * (t1 - t0) + 20.0
		if rel.length_squared() > reach * reach:
			continue
		var span := minf(t1, b.life) - t0
		var tt := clampf(-rel.dot(b.vel) / maxf(1.0, b.vel.length_squared()), 0.0, span)
		if (rel + b.vel * tt).length() < b.r + player.r + half + 1.0:
			n += 1.0
	if boss and not boss.dead:
		n += boss.bot_threat(q, t0, t1)
	for e in enemies:
		if e.dead or e.spawn_t > 0.0 or e is Boss or e.dmg <= 0.0:
			continue
		var tl := e.telegraph()
		if not tl.is_empty() and float(tl.get("fill", 0.0)) >= BOT_DASH_FILL and Boss.tele_hits(tl, q, player.r + 2.0):
			n += 1.0
	return n


## Direction along the shortest walkable path from p to goal (breadth-first search over
## the tile grid, ignoring hazards' damage). Used by the bot; cheap on rooms this small.
func path_dir(p: Vector2, goal: Vector2) -> Vector2:
	var start := Vector2i(floori(p.x / TS), floori(p.y / TS))
	var target := Vector2i(floori(goal.x / TS), floori(goal.y / TS))
	var dist := PackedInt32Array()
	dist.resize(gw * gh)
	dist.fill(-1)
	var queue: Array[Vector2i] = [target]
	dist[target.y * gw + target.x] = 0
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == start:
			break
		for d in dirs:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
				continue
			var t := grid[n.y * gw + n.x]
			if (t == 0 or t == 2) and dist[n.y * gw + n.x] < 0:
				dist[n.y * gw + n.x] = dist[c.y * gw + c.x] + 1
				queue.append(n)
	var best := start
	var bd := dist[start.y * gw + start.x] if start.x >= 0 and start.y >= 0 and start.x < gw and start.y < gh else -1
	for d in dirs:
		var n: Vector2i = start + d
		if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh:
			continue
		var v := dist[n.y * gw + n.x]
		if v >= 0 and (bd < 0 or v < bd):
			bd = v
			best = n
	var to := _center(best.x, best.y) - p
	return to.normalized() if to.length() > 1.0 else (goal - p).normalized()


# ------------------------------------------------------------------ enemy steering

## Enemies path around pillars, crates and walls (decisions/0008). One breadth-first
## distance field toward the player's tile is shared by every enemy and rebuilt only when
## the player changes tile or the grid changes (a crate breaks, doors open).
var _flow := PackedInt32Array()
var _flow_goal := Vector2i(-99, -99)
var _flow_ver := -1
## True when the last chase_dir() went straight at the player (nothing in the way).
var chase_direct := false
const _DIRS8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func walkable(x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return t == 0 or t == 2


## Whether a body of radius r can stand at p (its centre and four edge points are free).
func body_fits(p: Vector2, r: float) -> bool:
	for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if body_solid_at(p + o):
			return false
	return true


## Whether a body of radius r could travel straight from a to b: the centre line and both
## side lines are clear of walls, pillars and crates.
func clear_path(a: Vector2, b: Vector2, r: float) -> bool:
	var side := (b - a).orthogonal().normalized() * r * 0.9
	return los(a, b, true) and los(a + side, b + side, true) and los(a - side, b - side, true)


## Whether an enemy at p can see (and so shoot) the player. Enemy shots stop on crates,
## so crates block their sight.
func enemy_sees(p: Vector2) -> bool:
	return los(p, target_pos(), true)


func _flow_update() -> void:
	var tp := target_pos()
	var goal := Vector2i(floori(tp.x / TS), floori(tp.y / TS))
	if goal == _flow_goal and _flow_ver == grid_ver and _flow.size() == gw * gh:
		return
	_flow_goal = goal
	_flow_ver = grid_ver
	_flow.resize(gw * gh)
	_flow.fill(-1)
	if goal.x < 0 or goal.y < 0 or goal.x >= gw or goal.y >= gh:
		return
	var queue: Array[Vector2i] = [goal]
	_flow[goal.y * gw + goal.x] = 0
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var dc := _flow[c.y * gw + c.x] + 1
		for k in 4:
			var n: Vector2i = c + _DIRS8[k]
			if walkable(n.x, n.y) and _flow[n.y * gw + n.x] < 0:
				_flow[n.y * gw + n.x] = dc
				queue.append(n)


func _flow_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= gw or c.y >= gh:
		return -1
	return _flow[c.y * gw + c.x]


## The neighbouring tile one step closer to the player (a diagonal only when both of its
## side tiles are free, so a body never cuts a pillar corner), or c itself.
func _flow_next(c: Vector2i) -> Vector2i:
	var best := c
	var bd := _flow_at(c)
	for d in _DIRS8:
		var n: Vector2i = c + d
		var v := _flow_at(n)
		if v < 0 or (bd >= 0 and v >= bd):
			continue
		if d.x != 0 and d.y != 0 and not (walkable(c.x + d.x, c.y) and walkable(c.x, c.y + d.y)):
			continue
		best = n
		bd = v
	return best


## Direction for an enemy of radius r at p to move toward the player: straight at them
## when the way is clear, otherwise along the flow field, aiming at the furthest tile of
## the path it can reach in a straight line (so it walks smoothly rather than tile by tile).
func chase_dir(p: Vector2, r: float) -> Vector2:
	var goal := target_pos()
	var to := goal - p
	if to.length() < 1.0:
		chase_direct = true
		return Vector2.ZERO
	if clear_path(p, goal, r):
		chase_direct = true
		return to.normalized()
	chase_direct = false
	_flow_update()
	var cur := Vector2i(floori(p.x / TS), floori(p.y / TS))
	if _flow_at(cur) < 0:
		# off the field (pressed into a wall corner): step to any tile that is on it
		for d in _DIRS8:
			if _flow_at(cur + d) >= 0:
				return (_center(cur.x + d.x, cur.y + d.y) - p).normalized()
		return to.normalized()
	var aim := Vector2.INF
	var c := cur
	for i in 6:
		var nxt := _flow_next(c)
		if nxt == c:
			break
		var cp := _center(nxt.x, nxt.y)
		if i > 0 and not clear_path(p, cp, r):
			break
		aim = cp
		c = nxt
	if aim == Vector2.INF or p.distance_to(aim) < 1.0:
		return to.normalized()
	return (aim - p).normalized()


# ------------------------------------------------------------------ drawing

func _crate_texture() -> Texture2D:
	return PixelArt.cached("crate", func() -> Image:
		return PixelArt.from_rows(PackedStringArray([
			"wwwwwwwwwwwwww", "wBbbbbbbbbbbBw", "wbBbbbbbbbbBbw", "wbbBbbbbbbBbbw", "wbbbBbbbbBbbbw",
			"wbbbbBbbBbbbbw", "wbbbbbBBbbbbbw", "wbbbbbBBbbbbbw", "wbbbbBbbBbbbbw", "wbbbBbbbbBbbbw",
			"wbbBbbbbbbBbbw", "wBbbbbbbbbbbBw", "wwwwwwwwwwwwww", "dddddddddddddd",
		]), {"w": "#8a6a3a", "b": "#b8894a", "B": "#6e4a24", "d": "#3a2a18"}))


## Enemy bullets have their own look, used by nothing else (D1): a white core, a hot red
## ring and a dark rim, 9 px, so they read on the dark floor and on bright player magic.
func _enemy_bullet_texture() -> Texture2D:
	return PixelArt.cached("ebullet_v2", func() -> Image:
		var img := Image.create_empty(9, 9, false, Image.FORMAT_RGBA8)
		for j in 9:
			for i in 9:
				var d := Vector2(i + 0.5 - 4.5, j + 0.5 - 4.5).length()
				if d < 1.9:
					img.set_pixel(i, j, Style.c("threat:4"))
				elif d < 2.9:
					img.set_pixel(i, j, Style.c("threat:3"))
				elif d < 3.7:
					img.set_pixel(i, j, Style.c("threat:2"))
				elif d < 4.5:
					img.set_pixel(i, j, Style.c("threat:0"))
		return img)


## Floor-level details that change during the room: spikes, doors, the reward orb, NPCs.
func _draw_deco() -> void:
	var up := spikes_up()
	for h in hazards:
		if up:
			for k in 4:
				var x := h.x * TS + 4 + (k % 2) * 7
				var y := h.y * TS + 4 + (k / 2) * 7
				_deco.draw_colored_polygon(PackedVector2Array([Vector2(x, y + 2), Vector2(x + 1.5, y - 3), Vector2(x + 3, y + 2)]), Color("#cfd4e0"))
	for tp in torches:
		_deco.draw_texture(Props.sconce(), (tp + Vector2(-3, -3)).round())
	for d in doors:
		var def: Dictionary = d["def"]
		var x0 := float(int(d["col"]) * TS)
		var c := Chapter.door_color(def)
		_deco.draw_texture(Props.door(c, doors_open), Vector2(x0 - 5, -9))
		var icon := Icons.door(Chapter.door_key(def))
		_deco.draw_texture(icon, Vector2(x0 + TS - icon.get_width() / 2.0, -1).round(), Color(1, 1, 1, 1.0 if doors_open else 0.6))
		var th := Chapter.threat_of(def)
		if th != &"":
			# design v2: what the room behind asks of your wand, as a badge on the door
			var ti: Dictionary = Chapter.THREATS[th]
			var tg := Icons.glyph(ti["glyph"], Color(ti["color"]))
			_deco.draw_texture(tg, Vector2(x0 + TS + 4, 10).round(), Color(1, 1, 1, 1.0 if doors_open else 0.6))
	if not orb.is_empty():
		var p: Vector2 = orb["pos"]
		var bob := sin(time * 3.0) * 2.0
		var key := String(orb["kind"])
		var c := Color(Chapter.INFO.get(key, {"color": "#ffe066"})["color"])
		_deco.draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
		_deco.draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.4))
		_deco.draw_set_transform(Vector2.ZERO)
		var alt := Props.altar(c)
		_deco.draw_texture(alt, (p + Vector2(-alt.get_width() / 2.0, 7 - alt.get_height())).round())
		var o := p + Vector2(0, -12 - bob)
		_deco.draw_circle(o, 7.0, c.darkened(0.35))
		_deco.draw_circle(o + Vector2(0.5, 0.5), 5.5, c.darkened(0.1))
		_deco.draw_circle(o + Vector2(-2, -2), 2.0, c.lightened(0.6))
	if not npc.is_empty():
		_draw_npc(npc)
	if not cage.is_empty():
		_draw_cage()
	if room_kind == &"start" and run and run.daily == "" and gw > 4:
		# 0.20: the wall clock runs down with the stack trace: 16:59:57, :58, :59
		var ck := KernelArt.clock(Story.CLOCKS[clampi(run.world, 0, Story.CLOCKS.size() - 1)])
		_deco.draw_texture(ck, Vector2(TS * 3.0, -ck.get_height() + 4.0).round())
	spells.draw_summons(_deco, false)
	if hub:
		hub.draw_deco(_deco)
	var crate := _crate_texture()
	for y in gh:
		for x in gw:
			match grid[y * gw + x]:
				4:
					_deco.draw_texture(crate, Vector2(x * TS, y * TS) + Vector2(1, 0))
				6:
					_deco.draw_texture(Props.bramble(biome()), Vector2(x * TS, y * TS + 1))
				8:
					_deco.draw_texture(Props.pod(), Vector2(x * TS + 2, y * TS + 3))
				9:
					var ready: bool = pylon_cd.get(y * gw + x, 0.0) <= time
					_deco.draw_texture(Props.pylon(ready), Vector2(x * TS + 3, y * TS - 5))
	if treasure != Vector2.INF:
		var ch := Props.chest(false)
		_deco.draw_texture(ch, (treasure - Vector2(ch.get_width() / 2.0, ch.get_height() - 4)).round())


## 0.20: the resident in their cage; once it opens they draw in row by row (code arriving).
const CAGE_REVEAL := 1.2


func _draw_cage() -> void:
	var p: Vector2 = cage["pos"]
	var who: StringName = cage["who"]
	var open: bool = cage["open"]
	_deco.draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	_deco.draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.4))
	_deco.draw_set_transform(Vector2.ZERO)
	var rt := KernelArt.resident(who, int(time * 3.0) % 4)
	var at := (p + Vector2(-rt.get_width() / 2.0, 8 - rt.get_height())).round()
	if not open:
		# behind the bars, flickering like a process nobody answers
		_deco.draw_texture(rt, at, Color(1, 1, 1, 0.45 if fmod(time, 1.7) < 0.08 else 0.95))
	else:
		var k := clampf(float(cage["t"]) / CAGE_REVEAL, 0.0, 1.0)
		var rows := ceili(rt.get_height() * k)
		_deco.draw_texture_rect_region(rt, Rect2(at, Vector2(rt.get_width(), rows)), Rect2(0, 0, rt.get_width(), rows))
		if k < 1.0:
			_deco.draw_rect(Rect2(at + Vector2(-2, rows), Vector2(rt.get_width() + 4, 1)), Color(Style.c("cyan:4"), 0.9))
	var ct := KernelArt.cage(open)
	_deco.draw_texture(ct, (p + Vector2(-ct.get_width() / 2.0, 10 - ct.get_height())).round())
	if not open:
		_deco.draw_texture(Icons.glyph("cage", Color("#72e06a")), (p + Vector2(-9, -44)).round())


func _draw_npc(n: Dictionary) -> void:
	var p: Vector2 = n["pos"]
	_deco.draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	_deco.draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.4))
	_deco.draw_set_transform(Vector2.ZERO)
	match n["kind"]:
		&"spring":
			var f := Props.fountain(not n["used"])
			_deco.draw_texture(f, (p + Vector2(-f.get_width() / 2.0, 8 - f.get_height())).round())
		&"shop":
			var m := Props.merchant(int(time * 2.0) % 2)
			_deco.draw_texture(m, (p + Vector2(-m.get_width() / 2.0, 8 - m.get_height())).round())
			_deco.draw_texture(Icons.glyph("coin", Color("#ffd36b")), (p + Vector2(-9, -34)).round())
		&"forge":
			var a := Props.anvil()
			_deco.draw_texture(a, (p + Vector2(-a.get_width() / 2.0, 8 - a.get_height())).round())
			_deco.draw_texture(Icons.glyph("anvil", Color("#ff8a3c")), (p + Vector2(-9, -30)).round())
		&"altar", &"terminal":
			var col := Color(Chapter.INFO[String(n["kind"])]["color"])
			var al := Props.altar(col if not n["used"] else col.darkened(0.6))
			_deco.draw_texture(al, (p + Vector2(-al.get_width() / 2.0, 8 - al.get_height())).round())
			_deco.draw_texture(Icons.glyph("drop" if n["kind"] == &"altar" else "chip", col), (p + Vector2(-9, -30)).round())


## D6: telegraphs as floor decals (design-plan §7): an outline of where the attack lands,
## filled from its source as the attack nears, with a bright edge on the fill front. The
## threat ramp only (enemy attacks), drawn under the actors so bodies stay readable.
func _draw_decals() -> void:
	# 0.20: Page Leak puddles lie under everything (a slowing hazard, not an attack: no threat red)
	for p in puddles:
		var tex := KernelArt.puddle(int(p["r"]), int(float(p["t"]) * 3.0) % 2)
		_decals.draw_texture(tex, (Vector2(p["pos"]) - tex.get_size() / 2.0).round())
	for e in enemies:
		if e.dead or e is Boss:
			continue
		var tl := e.telegraph()
		if not tl.is_empty():
			_decal(tl, clampf(float(tl["fill"]), 0.0, 1.0))
	if boss and not boss.dead:
		var f := boss.tele_fill()
		for tl in boss.tele:
			_decal(tl, f)


func _decal(tl: Dictionary, fill: float) -> void:
	var edge := Style.c("threat:2")
	var body := Color(Style.c("threat:3"), 0.22 + 0.18 * fill)
	var front := Style.c("threat:4")
	match tl["k"]:
		"line":
			var p: Vector2 = tl["p"]
			var w := maxf(1.0, float(tl["w"]))
			var ln := float(tl["len"])
			_decals.draw_set_transform(p.round(), float(tl["a"]))
			_decals.draw_rect(Rect2(0, -w / 2.0, ln, w), Color(edge, 0.7), false, 1.0)
			_decals.draw_rect(Rect2(0, -w / 2.0, ln * fill, w), body)
			_decals.draw_rect(Rect2(roundf(ln * fill), -w / 2.0, 1, w), front)
			_decals.draw_set_transform(Vector2.ZERO)
		"circle":
			var p: Vector2 = (tl["p"] as Vector2).round()
			var rr := float(tl["r"])
			_decals.draw_arc(p, rr, 0.0, TAU, 40, Color(edge, 0.8), 1.0)
			_decals.draw_circle(p, rr * fill, body)
			_decals.draw_arc(p, rr * fill, 0.0, TAU, 32, front, 1.0)
		"track":
			# the Loop's lap: an oval band, lit from its edge inward as the charge nears
			var p: Vector2 = (tl["p"] as Vector2).round()
			var rx := float(tl["r"])
			var ry := float(tl["ry"])
			var pts := PackedVector2Array()
			for k in 49:
				var a := TAU * k / 48.0
				pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
			_decals.draw_polyline(pts, Color(body, 0.25 + 0.3 * fill), 6.0 + 8.0 * fill)
			_decals.draw_polyline(pts, Color(edge, 0.8), 1.0)
			if fill > 0.9:
				_decals.draw_polyline(pts, front, 2.0)
		"cone":
			var p: Vector2 = (tl["p"] as Vector2).round()
			var a := float(tl["a"])
			var sp := float(tl["spread"])
			var ln := float(tl["len"])
			var pts := PackedVector2Array([p])
			for k in 9:
				pts.append(p + Vector2.from_angle(a - sp + sp * 2.0 * k / 8.0) * ln * fill)
			if fill > 0.05:
				_decals.draw_colored_polygon(pts, body)
			_decals.draw_line(p, p + Vector2.from_angle(a - sp) * ln, Color(edge, 0.8), 1.0)
			_decals.draw_line(p, p + Vector2.from_angle(a + sp) * ln, Color(edge, 0.8), 1.0)
			_decals.draw_arc(p, ln * fill, a - sp, a + sp, 8, front, 1.0)
		"rect":
			var rc: Rect2 = tl["rect"]
			var c := rc.get_center()
			_decals.draw_rect(rc, Color(edge, 0.8), false, 1.0)
			var inner := Rect2(c - rc.size * fill / 2.0, rc.size * fill)
			_decals.draw_rect(inner, body)
			_decals.draw_rect(inner, front, false, 1.0)


## The descent (research/story.md): a vortex in the doorway that pulls sparks in, and a
## label naming where it goes, so the way down reads from across the arena.
func _draw_descent(p: Vector2) -> void:
	var ember := Style.c("ember:3")
	for k in 3:
		var rr := 7.0 + k * 5.0 + sin(time * 3.0 + k) * 1.5
		var a0 := time * (2.5 - k * 0.6) + k * 2.1
		_top.draw_arc(p, rr, a0, a0 + PI * 1.3, 16, Color(ember.r, ember.g, ember.b, 0.75 - k * 0.2), 1.0)
	_top.draw_circle(p, 5.0 + sin(time * 6.0), Color(1.0, 0.75, 0.35, 0.35))
	for k in 6:
		var t := fmod(time * 0.8 + k / 6.0, 1.0)
		var ang := k * 1.7 + time * 1.3
		_top.draw_rect(Rect2(p + Vector2.from_angle(ang) * (30.0 * (1.0 - t)), Vector2.ONE), Color(1.0, 0.8, 0.4, t))
	var label := "DOWN TO %s" % String(Chapter.WORLDS[mini(run.world + 1, Chapter.WORLDS.size() - 1)]["name"]).to_upper()
	var f := Game.font("small")
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var at := (p + Vector2(-w / 2.0, 34.0 + sin(time * 3.0))).round()
	_top.draw_string_outline(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0, 0, 0, 0.8))
	_top.draw_string(f, at, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.85, 0.5))


## Additive glow on top of the actors: torch flames, door and orb shine, boss telegraphs.
func _draw_top() -> void:
	# LINT's Red Squiggle: a wavy red line under the marked enemy, like a linter's underline
	for e in enemies:
		if e.squiggle and not e.dead:
			var y := e.position.y + 4.0
			for k in 12:
				var x := e.position.x - 6.0 + k
				_top.draw_rect(Rect2(Vector2(x, y + (1.0 if (k + int(time * 8.0)) % 4 < 2 else 0.0)).round(), Vector2.ONE), Style.c("blood:4"))
	for tp in torches:
		var fr := int(time * 9.0 + tp.x * 0.37) % 3
		_top.draw_texture(Props.flame(fr), (tp + Vector2(-3, -12)).round())
		_top.draw_circle(tp + Vector2(0, -7), 6.0 + sin(time * 11.0 + tp.y) * 0.8, Color(1.0, 0.6, 0.25, 0.12))
	if doors_open:
		for d in doors:
			var c := Chapter.door_color(d["def"])
			var x := int(d["col"]) * TS + TS
			_top.draw_circle(Vector2(x, 10), 16.0 + sin(time * 4.0) * 2.0, Color(c.r, c.g, c.b, 0.08))
			if StringName(d["def"]["kind"]) == &"descend":
				_draw_descent(Vector2(x, 12))
	if not orb.is_empty():
		var p: Vector2 = orb["pos"] + Vector2(0, -12 - sin(time * 3.0) * 2.0)
		_top.draw_circle(p, 12.0 + sin(time * 5.0), Color(1.0, 0.9, 0.5, 0.12))
		_top.draw_arc(p, 9.0, time * 2.0, time * 2.0 + PI * 1.2, 12, Color(1.0, 0.95, 0.7, 0.8), 1.0)
	spells.draw_summons(_top, true)
	if hub:
		hub.draw_top(_top)
	# Hex Cursor: brackets around the marked enemy
	if marked and not marked.dead and marked.mark_t > 0.0:
		var mp := marked.position + Vector2(0, -6)
		var h := marked.r + 4.0
		var mc := Style.c("arcane:4")
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var cp := mp + Vector2(sx * h, sy * h)
				_top.draw_line(cp, cp - Vector2(sx * 3.0, 0), mc, 1.0)
				_top.draw_line(cp, cp - Vector2(0, sy * 3.0), mc, 1.0)
	# spawn runes: where an enemy is about to appear
	for e in enemies:
		if e.spawn_t > 0.0 and not e.dead:
			var k := 1.0 - e.spawn_t / 1.1
			_top.draw_arc(e.position, 3.0 + k * 8.0, 0.0, TAU, 16, Color(0.77, 0.42, 1.0, 0.85), 1.0)
			_top.draw_arc(e.position, 10.0 - k * 6.0, time * 3.0, time * 3.0 + PI, 8, Color(Style.c("threat:3"), 0.85), 1.0)

