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
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#.............oo...............#",
		"#.............oo...............#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
		"#..............................#",
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
var orb: Dictionary = {}       # reward orb: {"pos", "kind", "t"}
var npc: Dictionary = {}       # {"pos", "kind": shop|forge|spring, "used", "near"}
var boss: Boss
var boss_t := 0.0
var dead_t := 0.0
## Screen shake as "trauma" (0..1, decays linearly); the camera shakes by trauma², so
## small events barely move it and big ones slam (design-plan §10, Eiserloh GDC 2016).
var trauma := 0.0
const TRAUMA_DECAY := 1.6    # per second
var caught := false            # Try / Catch used in this room
var damage_done := 0.0
var _kill_streak := 0
var _stop := 0.0               # hit-stop: the sim holds for a few frames on big hits
var _last_stop := -9.0
var _flash_t := -9.0
var _bot_dmg_seen := 0.0
var _bot_progress_t := 0.0

# move_body results
var marked: Enemy               # Hex Cursor: payloads aim here (D2)
var grid_ver := 0              # bumped on every grid change (the flow field rebuilds)
var last_hit_x := false
var last_hit_y := false

var _uid := 0
var _cascading := false
var _floor: Sprite2D
var _vignette: Sprite2D
var _vignette_tex: GradientTexture2D
var _deco: Node2D
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
	glow_layer.add_child(fx)
	_ambient = CanvasModulate.new()
	_ambient.color = AMBIENT
	add_child(_ambient)
	_lights = Node2D.new()
	add_child(_lights)
	player = Player.new()
	player.setup(self)
	_actors.add_child(player)
	var pl_light := make_light(Color(0.75, 0.8, 1.0), 1.05, 150.0)
	pl_light.position = Vector2(0, -6)
	player.add_child(pl_light)
	spells = SpellRunner.new(self)
	Events.player_died.connect(_on_player_died)


## Starts (or resumes) a run: builds the room the run is standing in.
func start_run(r: RunState) -> void:
	run = r
	rng.seed = r.seed_value * 7919 + r.step
	player.dead = false
	dead_t = 0.0
	paused = false
	enter_room()


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
		&"start", &"shop", &"spring", &"forge":
			tpl = "camp"
		&"mini":
			tpl = "arena_open"
		&"boss":
			tpl = "arena_ring"
		_:
			tpl = FIGHT_ROOMS[rng.randi() % FIGHT_ROOMS.size()]
	if run.doors.is_empty():
		run.doors = Chapter.door_options(run)
	if kind == &"shop" and run.shop.is_empty():
		run.shop = Rewards.shop_stock(run)
	build_room(tpl, kind)
	if run.has_relic(&"interest") and run.gold >= 60:
		run.gold += 3
	if run.step == 0:
		Hints.show("move")
	SaveGame.save_run(run)


func build_room(tpl: String, kind: StringName) -> void:
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
	caught = false
	var rows: Array = ROOMS[tpl]
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
			grid[y * gw + x] = tile
	grid_ver += 1
	_place_doors()
	doors_open = false
	cleared = false
	_floor.texture = ImageTexture.create_from_image(RoomPainter.paint(grid, gw, gh, run_seed * 131 + (run.step if run else 0) * 17 + tpl.length()))
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
	waves = []
	wave_i = 0
	wave_t = 0.8
	var mid := _find_floor(gw / 2, gh / 2 - 1)
	match kind:
		&"start":
			orb = {"pos": mid, "kind": &"start", "t": 0.0}
			cleared = true
		&"shop", &"forge", &"spring":
			npc = {"pos": mid, "kind": kind, "used": false, "near": false}
			_clear_room(false)
		&"mini", &"boss":
			boss_t = 1.0
		&"fight", &"challenge":
			waves = _compose_waves(kind)
		&"empty":
			cleared = true   # tests and the showcase: a room with nothing in it
	_deco.queue_redraw()
	Audio.music("boss" if kind == &"mini" or kind == &"boss" else "grove")
	Events.room_entered.emit({"no": run.step if run else 0, "kind": kind, "tpl": tpl,
		"title": _room_title(kind)})
	room_built.emit()


func _room_title(kind: StringName) -> String:
	match kind:
		&"start":
			return "THE RUINED GROVE"
		&"mini":
			return "MINI-BOSS"
		&"boss":
			return "BOSS"
	var key := String(kind) if kind != &"fight" else String(run.room.get("reward", "spell")) if run else "fight"
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
	var step := run.step if run else 1
	var budget := (6.0 + step * 2.0) * (1.3 if kind == &"challenge" else 1.0)
	var roster: Array = EARLY_ROSTER if step <= 2 else ROSTER
	var out: Array = []
	var n := 2
	for w in n:
		var b := budget / n * (1.2 if w == n - 1 else 0.9)
		var list: Array = []
		var guard := 0
		while b > 0.0 and list.size() < 14 and guard < 40:
			guard += 1
			var opts := roster.filter(func(k: StringName) -> bool: return float(Enemy.DEFS[k]["cost"]) <= b + 1.0)
			if opts.is_empty():
				break
			var k: StringName = opts[rng.randi() % opts.size()]
			b -= float(Enemy.DEFS[k]["cost"])
			list.append([k, false])
		out.append(list)
	if kind == &"challenge":
		var picks := roster.filter(func(k: StringName) -> bool: return k != &"bugling")
		out[n - 1].append([picks[rng.randi() % picks.size()], true])
	return out


func _spawn_wave(list: Array) -> void:
	var socks := sockets.filter(func(p: Vector2) -> bool: return p.distance_to(player.position) > 80.0)
	if socks.is_empty():
		socks = sockets.duplicate()
	_shuffle(socks)
	for i in list.size():
		var p: Vector2 = socks[i % socks.size()] + Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var er: float = float(Enemy.DEFS[list[i][0]]["r"]) + (2.0 if list[i][1] else 0.0)
		if not body_fits(p, er):
			p = socks[i % socks.size()]
		var e := spawn_enemy(list[i][0], p, list[i][1])
		e.spawn_t = 0.5 + rng.randf() * 0.3
	Audio.sfx("spawn")
	Hints.show("aim")


func spawn_enemy(kind: StringName, pos: Vector2, elite := false) -> Enemy:
	var e := Enemy.new()
	_uid += 1
	var step := run.step if run else 1
	e.setup(self, kind, pos, _uid, 1.0 + step * 0.07, elite)
	enemies.append(e)
	_actors.add_child(e)
	return e


func _spawn_boss() -> void:
	var b: Boss = BossCopyPaste.new() if room_kind == &"mini" else BossLoop.new()
	_uid += 1
	enemies.append(b)
	_actors.add_child(b)
	b.setup_boss(self, Vector2(gw * TS / 2.0, gh * TS * 0.35), _uid)
	boss = b
	Hints.show("boss")
	Events.boss_started.emit(b.title, b.subtitle)


func _clear_room(reward := true) -> void:
	cleared = true
	clear_enemy_bullets()
	if not reward:
		_open_doors()
		return
	run.stats["rooms"] += 1
	player.heal(8.0)
	fx.text(player.position + Vector2(0, -34), "ROOM CLEAR", Color("#ffe066"), 10)
	Events.room_cleared.emit()
	var mid := _find_floor(gw / 2, gh / 2)
	match room_kind:
		&"mini", &"boss":
			orb = {"pos": mid, "kind": room_kind, "t": 0.0}
			if room_kind == &"boss":
				player.heal(run.max_hp)
		&"challenge":
			orb = {"pos": mid, "kind": &"challenge", "t": 0.0}
		_:
			var r := StringName(run.room.get("reward", "spell"))
			match r:
				&"gold":
					var g := roundi((18 + run.step * 3) * Relics.gold_mul(run))
					run.gold += g
					fx.text(player.position + Vector2(0, -24), "+%d GOLD" % g, Color("#ffd36b"), 10)
					Audio.sfx("coin")
					_open_doors()
				&"heart":
					run.max_hp += 15.0
					player.heal(15.0)
					fx.text(player.position + Vector2(0, -24), "MAX HP +15", Color("#ff4d6d"), 10)
					_open_doors()
				_:
					orb = {"pos": mid, "kind": r, "t": 0.0}
	_deco.queue_redraw()


func _open_doors() -> void:
	if not doors_open and room_kind != &"start":
		Hints.show("doors")
	doors_open = true
	for d in doors:
		for dx in 2:
			grid[int(d["col"]) + dx] = 0
	grid_ver += 1
	_deco.queue_redraw()


## Called by main.gd when the reward screen closes (taken or skipped).
func reward_taken() -> void:
	orb = {}
	paused = false
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
	if StringName(def["kind"]) == &"exit":
		run.won = true
		paused = true
		SaveGame.clear_run()
		ui_request.emit(&"victory", {})
		return
	run.path.append(Chapter.door_key(def))
	run.room = def
	run.step += 1
	run.doors = []
	run.shop = []
	enter_room()


func _on_player_died() -> void:
	dead_t = 1.1   # death to the retry screen quickly (design-plan: back in a run in ~3 s)
	Audio.death_sweep()
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
	trauma = maxf(0.0, trauma - TRAUMA_DECAY * dt)
	if dead_t > 0.0:
		dead_t -= dt
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
	for e in enemies:
		if not e.dead:
			e.tick(dt)
	_separate()
	_unstick()
	spells.update(dt)
	_update_enemy_bullets(dt)
	_update_room(dt)
	_check_doors()
	fx.update(dt)


func _update_room(dt: float) -> void:
	if not cleared:
		if room_kind == &"mini" or room_kind == &"boss":
			if boss == null:
				boss_t -= dt
				if boss_t <= 0.0:
					_spawn_boss()
			elif boss.dead:
				_clear_room()
		elif enemies.all(func(e: Enemy) -> bool: return e.dead):
			if wave_i < waves.size():
				wave_t -= dt
				if wave_t <= 0.0:
					_spawn_wave(waves[wave_i])
					wave_i += 1
					wave_t = 0.9
			else:
				_clear_room()
	# the reward orb opens the reward screen on touch
	if not orb.is_empty():
		if orb["t"] > 0.8:
			Hints.show("orb")
		orb["t"] += dt
		if orb["t"] > 0.5 and player.position.distance_to(orb["pos"]) < 14.0:
			paused = true
			Audio.sfx("pick")
			var kind: StringName = orb["kind"]
			ui_request.emit(&"reward", {"kind": kind, "offer": Rewards.offer(run, kind)})
			return
	if not npc.is_empty():
		var near: bool = player.position.distance_to(npc["pos"]) < 18.0
		if near and not npc["near"]:
			match npc["kind"]:
				&"spring":
					if not npc["used"]:
						npc["used"] = true
						player.heal(run.max_hp * 0.6)
						Audio.sfx("heal")
						fx.ring(npc["pos"], 4.0, 50.0, 0.6, Color("#6fb8ff"))
						Events.toast.emit("The spring restores you")
				&"shop", &"forge":
					paused = true
					ui_request.emit(npc["kind"], {})
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
		if (not spells.blockers.is_empty() and spells.blocked(b.pos, b.r)) or (not spells.summons.is_empty() and spells.decoy_takes(b.pos, b.r)):
			b.alive = false
			fx.sparks(b.pos, 3, Style.c("gold:4"), 40.0)
			continue
		if b.pos.distance_squared_to(player.position + Vector2(0, -4)) < pow(b.r + player.r, 2):
			b.alive = false
			player.hurt(b.dmg, b.pos, b.by)
	ebullets.compact()


func clear_enemy_bullets() -> void:
	for b in ebullets.active:
		if b.alive:
			b.alive = false
			fx.sparks(b.pos, 1, b.color, 20.0)


func enemy_shoot(pos: Vector2, ang: float, spd: float, dmg: float, accel := 0.0, by := "") -> void:
	var b := ebullets.spawn()
	if b == null:
		return
	b.pos = pos
	b.prev = pos
	b.vel = Vector2.from_angle(ang) * spd
	b.life = 4.0
	b.max_life = 4.0
	b.dmg = dmg
	b.r = 2.5
	b.accel = accel
	b.by = by
	b.color = Color.WHITE   # the texture carries the reserved threat colors
	Audio.sfx("eshot", 0.1, -6.0)


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


func solid_at(p: Vector2) -> bool:
	var t := tile_at(floori(p.x / TS), floori(p.y / TS))
	return t == 1 or t == 3 or t == 4


## Smashes the crate at a tile (spells do this; enemy shots don't). Drops a little gold.
func break_crate(tx: int, ty: int) -> void:
	if tile_at(tx, ty) != 4:
		return
	grid[ty * gw + tx] = 0
	grid_ver += 1
	var p := _center(tx, ty)
	fx.dissolve(p + Vector2(0, 7), _crate_texture())
	fx.sparks(p, 6, Color("#c8a070"), 70.0)
	Audio.sfx("crate")
	if run:
		var g := rng.randi_range(1, 3)
		run.gold += g
		fx.text(p + Vector2(0, -10), "+%d" % g, Color("#ffd36b"))


func break_crates_in(p: Vector2, r: float) -> void:
	for ty in range(floori((p.y - r) / TS), floori((p.y + r) / TS) + 1):
		for tx in range(floori((p.x - r) / TS), floori((p.x + r) / TS) + 1):
			if tile_at(tx, ty) == 4 and _center(tx, ty).distance_to(p) < r + TS * 0.5:
				break_crate(tx, ty)


func hitstop(t: float) -> void:
	_stop = maxf(_stop, t)
	_last_stop = time


## A brief full-screen flash (white, never red; at most ~3 per second), if the player allows it.
func flash(amount: float, c := Color.WHITE) -> void:
	if not Game.flash_fx or time - _flash_t < 0.34:
		return
	_flash_t = time
	Events.screen_flash.emit(c, amount)


func hazard_at(p: Vector2) -> bool:
	return tile_at(floori(p.x / TS), floori(p.y / TS)) == 2


func spikes_up() -> bool:
	return fmod(time, 2.4) > 1.5


## Circle-vs-tiles movement, one axis at a time, in sub-steps short enough that nothing
## tunnels through a wall. Sets last_hit_x / last_hit_y.
func move_body(pos: Vector2, r: float, delta: Vector2) -> Vector2:
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
		if solid_at(Vector2(ex, p.y - r * 0.7)) or solid_at(Vector2(ex, p.y + r * 0.7)):
			p.x = floorf(ex / TS) * TS - r - 0.01 if delta.x > 0.0 else (floorf(ex / TS) + 1.0) * TS + r + 0.01
			last_hit_x = true
	p.y += delta.y
	if delta.y != 0.0:
		var ey := p.y + (r if delta.y > 0.0 else -r)
		if solid_at(Vector2(p.x - r * 0.7, ey)) or solid_at(Vector2(p.x + r * 0.7, ey)):
			p.y = floorf(ey / TS) * TS - r - 0.01 if delta.y > 0.0 else (floorf(ey / TS) + 1.0) * TS + r + 0.01
			last_hit_y = true
	return p


## Line of sight. Crates block movement but not aim (spells smash them), so by default
## they do not block sight either.
func los(a: Vector2, b: Vector2, crates_block := false) -> bool:
	var n := ceili(a.distance_to(b) / 8.0)
	for k in range(1, n):
		var q := a.lerp(b, float(k) / n)
		var t := tile_at(floori(q.x / TS), floori(q.y / TS))
		if t == 1 or t == 3 or (crates_block and t == 4):
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


## Auto-aim target: the nearest enemy in line of sight, else the nearest one.
func assist_target(p: Vector2, max_d: float) -> Enemy:
	var best: Enemy = null
	var vis: Enemy = null
	var bd := max_d * max_d
	var vd := bd
	for e in enemies:
		if e.dead or e.spawn_t > 0.0:
			continue
		var d := e.position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
		if d < vd and los(p, e.position):
			vd = d
			vis = e
	return vis if vis else best


func hurt_enemy(e: Enemy, dmg: float, from: Vector2, crit_chance: float, kb: float, dot := false) -> float:
	if e.dead or e.spawn_t > 0.0:
		return 0.0
	if e.forward:
		e.flash = 0.07
		return hurt_enemy(e.forward, dmg * e.fwd_mul, from, crit_chance, 0.0, dot)
	if e is Boss and (e as Boss).invuln > 0.0:
		return 0.0
	var crit := crit_chance > 0.0 and rng.randf() < crit_chance
	if crit:
		dmg *= 2.0
	if run and run.has_relic(&"cold_boot") and e.chill_t > 0.0:
		dmg *= 1.25
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
	if not e.heavy and kb > 0.0:
		e.knock += (e.position - from).normalized() * kb * (70.0 if crit else 38.0)
	if crit and time - _last_stop > 0.25:
		hitstop(0.045)
		shake(0.15)
	if not dot:
		fx.number(e.position + Vector2(0, -e.r - 10), dmg, crit)
		Audio.sfx("crit" if crit else "hit", 0.1, 0.0 if crit else -6.0)
	# Static: a charged enemy passes the next hit on to a neighbour as an arc
	if not dot and not _cascading and e.static_t > 0.0:
		e.static_t = 0.0
		var nb := nearest_enemy(e.position, 70.0, e.uid)
		if nb:
			_cascading = true
			fx.beam(e.position + Vector2(0, -4), nb.position + Vector2(0, -4), Style.c("gold:4"), 1.0)
			hurt_enemy(nb, dmg * 0.6, e.position, 0.0, 0.3)
			_cascading = false
	if crit and not dot and not _cascading and run and run.has_relic(&"cascade_failure"):
		var nx := nearest_enemy(e.position, 60.0, e.uid)
		if nx:
			_cascading = true
			fx.beam(e.position + Vector2(0, -4), nx.position + Vector2(0, -4), Color("#fff27a"), 1.0)
			hurt_enemy(nx, dmg * 0.5, e.position, 0.0, 0.3)
			_cascading = false
	if e.hp <= 0.0:
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
		tgt.burn_t = 2.5
		tgt.burn_dps = maxf(base, maxf(4.0 + burn * 4.0, dmg * 0.4))
	if chill > 0 and not (tgt is Boss):
		tgt.chill_t = 1.2 + chill * 0.4
		tgt.chill_slow = [0.6, 0.5, 0.4][clampi(chill, 1, 3) - 1]
		tgt.chill_n += 1
		if tgt.chill_n >= 3 and tgt.frozen_t <= 0.0:
			tgt.chill_n = 0
			tgt.frozen_t = 0.9
			fx.ring(tgt.position + Vector2(0, -4), 2.0, 12.0, 0.25, Style.c("frost:4"))
			fx.text(tgt.position + Vector2(0, -16), "FROZEN", Style.c("frost:4"))


## Thermal Shock: burn and chill cancel in a burst that hurts the target and its neighbours.
func _thermal_shock(e: Enemy, dmg: float) -> void:
	e.shock_t = 0.6
	e.burn_t = 0.0
	e.chill_t = 0.0
	e.chill_n = 0
	var hit := 10.0 + dmg * 0.8
	fx.ring(e.position + Vector2(0, -4), 2.0, 22.0, 0.3, Style.c("frost:4"))
	fx.ring(e.position + Vector2(0, -4), 2.0, 16.0, 0.25, Style.c("ember:3"))
	fx.text(e.position + Vector2(0, -16), "THERMAL SHOCK", Style.c("ember:4"))
	Audio.sfx("boom", 0.1, -6.0)
	for k in hash.query(e.position, 40.0):
		var o: Enemy = enemies[k]
		if o != e and not o.dead and o.spawn_t <= 0.0 and o.position.distance_to(e.position) < 22.0 + o.r:
			hurt_enemy(o, hit * 0.5, e.position, 0.0, 0.6)
	hurt_enemy(e, hit, e.position, 0.0, 0.6)


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
	if tgt.rot_n < 5:
		return
	tgt.rot_n = 0
	var hit := 20.0 + minf(tgt.max_hp * 0.2, 40.0)
	fx.ring(tgt.position + Vector2(0, -4), 2.0, 20.0, 0.3, Style.c("glitch:3"))
	fx.sparks(tgt.position + Vector2(0, -4), 12, Style.c("glitch:3"), 100.0)
	fx.text(tgt.position + Vector2(0, -16), "CRASH", Style.c("glitch:4"))
	for k in hash.query(tgt.position, 40.0):
		var o: Enemy = enemies[k]
		if o != tgt and not o.dead and o.spawn_t <= 0.0 and o.position.distance_to(tgt.position) < 26.0 + o.r:
			hurt_enemy(o, hit * 0.5, tgt.position, 0.0, 0.8)
	hurt_enemy(tgt, hit, tgt.position, 0.0, 0.8)


## Hex Cursor: triggers and carriers aim their payloads at the marked enemy.
func mark(e: Enemy, t: float) -> void:
	var tgt := e.forward if e.forward else e
	if tgt.dead:
		return
	tgt.mark_t = t
	marked = tgt


## Where enemies go and shoot: the Rubber Duck while one is out, else the player.
func target_pos() -> Vector2:
	if spells == null or spells.summons.is_empty():
		return player.position
	var dk := spells.decoy()
	return dk.pos if dk else player.position


## Explosion size multiplier from relics.
func area_mul() -> float:
	return 1.35 if run and run.has_relic(&"blast_radius") else 1.0


func kill_enemy(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	e.visible = false
	if run:
		run.stats["kills"] += 1
		run.gold += roundi(int(e.def.get("gold", 1)) * (4 if e.elite else 1) * Relics.gold_mul(run) * 0.5)
		if run.has_relic(&"garbage_collector"):
			for w in run.wands:
				w.mana = minf(w.max_mana(), w.mana + 3.0)
		if run.has_relic(&"leech_loop"):
			_kill_streak += 1
			if _kill_streak % 6 == 0:
				player.heal(4.0)
		if run.has_relic(&"wildfire") and e.burn_t > 0.0:
			for k in hash.query(e.position, 44.0):
				var o: Enemy = enemies[k]
				if o != e and not o.dead and o.position.distance_to(e.position) < 36.0 + o.r:
					apply_status(o, 1, 0, e.burn_dps / 0.4)
			fx.ring(e.position, 2.0, 36.0, 0.3, Color("#ff8a3c"))
		if run.has_relic(&"bug_bounty") and not (e is Boss):
			_release_bug(e.position)
	fx.dissolve(e.position, e.sprite.texture if e.sprite else null, e.sprite.flip_h if e.sprite else false, e.sprite.scale.x if e.sprite else 1.0)
	if e.elite:
		hitstop(0.08)
		shake(0.25)
	if e is Boss:
		(e as Boss).die()
		run.stats["bosses"] += 1
		hitstop(0.3)
		flash(0.45)
		Game.buzz(200)
		shake(0.8)
		for k in 6:
			fx.ring(e.position + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)), 2.0, 20.0 + k * 6.0, 0.5, [Color("#ff3fa4"), Color("#ffc94a"), Color("#5ce1ff")][k % 3])
		fx.sparks(e.position, 40, Color("#ffe066"), 180.0)
		Events.boss_defeated.emit()
	fx.sparks(e.position + Vector2(0, -4), 14, Color("#c46bff"), 120.0)
	fx.ring(e.position, 2.0, 12.0, 0.25, Color("#ff3fa4"))
	shake(0.1)
	Events.enemy_killed.emit(e.kind, e.position)


## Bug Bounty: a small homing bolt that hunts the nearest enemy.
func _release_bug(p: Vector2) -> void:
	var b := bullets.spawn()
	if b == null:
		return
	var a := rng.randf() * TAU
	b.pos = p + Vector2(0, -4)
	b.prev = b.pos
	b.a = a
	b.vel = Vector2.from_angle(a) * 150.0
	b.dmg = 10.0
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
## first door. Reward, shop and forge screens are answered by whoever listens to ui_request.
func _bot_drive() -> void:
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
	var e := nearest_enemy(p, 900.0)
	if e == null:
		controls.move = (Vector2(gw * TS / 2.0, gh * TS / 2.0) - p).limit_length(1.0) * 0.5
		return
	# watchdog: no damage for a while means we are stuck somewhere; walk the path for a bit
	if damage_done > _bot_dmg_seen:
		_bot_dmg_seen = damage_done
		_bot_progress_t = time
	var stuck := time - _bot_progress_t > 8.0 and time - _bot_progress_t < 10.0
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
		for e in enemies:
			if not e.dead and e.spawn_t <= 0.0 and e.dmg > 0.0:
				# where the body will be in a moment, not just where it is
				var dist := minf(e.position.distance_to(q), (e.position + e.vel * 0.25).distance_to(q))
				if dist < e.r + 16.0:
					danger += (e.r + 16.0 - dist) * 1.5
		var score := danger * 4.0 - dir.dot(desire)
		if score < best_score:
			best_score = score
			best = dir
	return best


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
		if solid_at(p + o):
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
	spells.draw_summons(_deco, false)
	var crate := _crate_texture()
	for y in gh:
		for x in gw:
			if grid[y * gw + x] == 4:
				_deco.draw_texture(crate, Vector2(x * TS, y * TS) + Vector2(1, 0))


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


## Additive glow on top of the actors: torch flames, door and orb shine, boss telegraphs.
func _draw_top() -> void:
	for tp in torches:
		var fr := int(time * 9.0 + tp.x * 0.37) % 3
		_top.draw_texture(Props.flame(fr), (tp + Vector2(-3, -12)).round())
		_top.draw_circle(tp + Vector2(0, -7), 6.0 + sin(time * 11.0 + tp.y) * 0.8, Color(1.0, 0.6, 0.25, 0.12))
	if doors_open:
		for d in doors:
			var c := Chapter.door_color(d["def"])
			var x := int(d["col"]) * TS + TS
			_top.draw_circle(Vector2(x, 10), 16.0 + sin(time * 4.0) * 2.0, Color(c.r, c.g, c.b, 0.08))
	if not orb.is_empty():
		var p: Vector2 = orb["pos"] + Vector2(0, -12 - sin(time * 3.0) * 2.0)
		_top.draw_circle(p, 12.0 + sin(time * 5.0), Color(1.0, 0.9, 0.5, 0.12))
		_top.draw_arc(p, 9.0, time * 2.0, time * 2.0 + PI * 1.2, 12, Color(1.0, 0.95, 0.7, 0.8), 1.0)
	spells.draw_summons(_top, true)
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
	if boss and not boss.dead:
		var a := 0.35 + 0.25 * sin(time * 20.0)
		for tl in boss.tele:
			match tl["k"]:
				"line":
					var p: Vector2 = tl["p"]
					_top.draw_line(p, p + Vector2.from_angle(tl["a"]) * float(tl["len"]), Color(Style.c("threat:3"), a * 0.6), float(tl["w"]))
				"circle":
					_top.draw_arc(tl["p"], float(tl["r"]), 0.0, TAU, 40, Color(Style.c("threat:3"), a + 0.2), 2.0)
