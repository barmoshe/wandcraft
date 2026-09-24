class_name World
extends Node2D
## One room of the run and everything in it. `step(dt)` advances the whole simulation by
## one fixed tick; the scene calls it from _physics_process and tests call it directly.
##
## Room legend: '#' wall, 'o' pillar, '~' spike plate, 's' spawn socket, 'L' torch,
## 'c' crate (floor for now). Two doors are carved into the top wall and open on clear.

const TS := 16
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
}
const FIGHT_ROOMS := ["hall", "cross", "pillars"]
const ROSTER := [&"slime", &"weaver", &"ram", &"sentry"]
const DOOR_KINDS := [&"fight", &"elite", &"treasure"]
const LOOT := [&"mote", &"lance", &"fan", &"burst", &"moths", &"seed", &"empower", &"quicken", &"seek",
	&"phase", &"ricochet", &"twin", &"chorus", &"shatter", &"mirror", &"then", &"callback", &"loop",
	&"fork", &"cache", &"heatsink", &"wheel"]

signal room_built

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
var auto_step := true
var bot := false
var run_seed := 1

# room state
var room_no := 0
var room_kind: StringName = &"fight"
var room_tpl := "hall"
var sockets: Array[Vector2] = []
var torches: Array[Vector2] = []
var hazards: Array[Vector2i] = []
var doors: Array = []          # {"col": int, "kind": StringName}
var doors_open := false
var cleared := false
var waves_left := 0
var wave_budget := 0
var wave_t := 0.0
var pickups: Array = []        # {"pos": Vector2, "id": StringName, "t": float}
var dead_t := 0.0
var shake_amt := 0.0

# run stats
var gold := 0
var kills := 0
var damage_done := 0.0
var rooms_cleared := 0

# move_body results
var last_hit_x := false
var last_hit_y := false

var _uid := 0
var _floor: Sprite2D
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
	add_child(_floor)
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
	ebullets.setup(512, _enemy_bullet_texture())
	glow_layer.add_child(ebullets)
	bullets = BulletPool.new()
	bullets.setup(2048, PixelArt.bullet_texture())
	glow_layer.add_child(bullets)
	fx = FxLayer.new()
	fx.rng.seed = seed_value + 7
	glow_layer.add_child(fx)
	_ambient = CanvasModulate.new()
	_ambient.color = Color(0.5, 0.52, 0.66)
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


func new_run() -> void:
	gold = 0
	kills = 0
	damage_done = 0.0
	rooms_cleared = 0
	room_no = 0
	player.new_run()
	build_room("hall", &"fight")


# ------------------------------------------------------------------ rooms

func build_room(tpl: String, kind: StringName) -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	bullets.clear_all()
	ebullets.clear_all()
	fx.clear_all()
	pickups.clear()
	room_no += 1
	room_tpl = tpl
	room_kind = kind
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
			var ch := row[x]
			var tile := 0
			match ch:
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
			grid[y * gw + x] = tile
	# two doors of two tiles each, a third and two thirds along the top wall
	doors.clear()
	var kinds := DOOR_KINDS.duplicate()
	_shuffle(kinds)
	for k in 2:
		var col := int(gw * (k + 1) / 3.0) - 1
		doors.append({"col": col, "kind": kinds[k]})
	doors_open = false
	cleared = false
	_floor.texture = ImageTexture.create_from_image(RoomPainter.paint(grid, gw, gh, run_seed * 131 + room_no))
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
	match kind:
		&"treasure":
			pickups.append({"pos": _center(gw / 2, gh / 2), "id": LOOT[rng.randi() % LOOT.size()], "t": 0.0})
			_clear_room(false)
		_:
			waves_left = 2
			wave_budget = 4 + room_no + (2 if kind == &"elite" else 0)
			wave_t = 0.8
	_deco.queue_redraw()
	Events.room_entered.emit({"no": room_no, "kind": kind, "tpl": tpl})
	room_built.emit()


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


func _spawn_wave() -> void:
	waves_left -= 1
	var budget := wave_budget
	var socks := sockets.filter(func(p: Vector2) -> bool: return p.distance_to(player.position) > 70.0)
	if socks.is_empty():
		socks = sockets.duplicate()
	_shuffle(socks)
	var i := 0
	var elite_left := 1 if room_kind == &"elite" and waves_left == 0 else 0
	while budget > 0 and i < 24:
		var k: StringName = ROSTER[rng.randi() % ROSTER.size()]
		var cost: int = Enemy.DEFS[k]["cost"]
		if cost > budget:
			k = &"slime"
			cost = 1
		budget -= cost
		var p: Vector2 = socks[i % socks.size()] + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		spawn_enemy(k, p, elite_left > 0)
		elite_left = 0
		i += 1


func spawn_enemy(kind: StringName, pos: Vector2, elite := false) -> Enemy:
	var e := Enemy.new()
	_uid += 1
	e.setup(self, kind, pos, _uid, 1.0 + room_no * 0.06, elite)
	enemies.append(e)
	_actors.add_child(e)
	return e


func _clear_room(reward := true) -> void:
	cleared = true
	doors_open = true
	for d in doors:
		for dx in 2:
			grid[int(d["col"]) + dx] = 0
	if reward:
		rooms_cleared += 1
		player.heal(10.0)
		fx.text(player.position + Vector2(0, -34), "ROOM CLEAR", Color("#ffe066"), 10)
		Events.room_cleared.emit()
	_deco.queue_redraw()


func _check_doors() -> void:
	if not doors_open or player.position.y > TS * 0.9:
		return
	for d in doors:
		var x0 := int(d["col"]) * TS
		if player.position.x >= x0 and player.position.x <= x0 + TS * 2:
			enter_door(d["kind"])
			return


func enter_door(kind: StringName) -> void:
	var tpl: String = FIGHT_ROOMS[rng.randi() % FIGHT_ROOMS.size()]
	if kind == &"treasure":
		tpl = "hall"
	build_room(tpl, kind)


func _on_player_died() -> void:
	dead_t = 2.0
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
	time += dt
	shake_amt = maxf(0.0, shake_amt - dt)
	if dead_t > 0.0:
		dead_t -= dt
		if dead_t <= 0.0:
			new_run()
		fx.update(dt)
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
	spells.update(dt)
	_update_enemy_bullets(dt)
	_update_pickups(dt)
	# waves
	if not cleared:
		var living := 0
		for e in enemies:
			if not e.dead:
				living += 1
		if living == 0:
			if waves_left > 0:
				wave_t -= dt
				if wave_t <= 0.0:
					_spawn_wave()
					wave_t = 0.6
			else:
				_clear_room()
	_check_doors()
	fx.update(dt)


func _separate() -> void:
	for a in enemies:
		if a.dead or a.spawn_t > 0.0:
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


func _update_enemy_bullets(dt: float) -> void:
	for b in ebullets.active:
		if not b.alive:
			continue
		b.prev = b.pos
		b.life -= dt
		b.pos += b.vel * dt
		b.spin += dt * 6.0
		if b.life <= 0.0 or solid_at(b.pos):
			b.alive = false
			fx.sparks(b.pos, 3, b.color, 40.0)
			continue
		if b.pos.distance_squared_to(player.position + Vector2(0, -4)) < pow(b.r + player.r, 2):
			b.alive = false
			player.hurt(b.dmg, b.pos)
	ebullets.compact()


func enemy_shoot(pos: Vector2, ang: float, spd: float, dmg: float) -> void:
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
	b.color = Color("#ff4a7a")


func _update_pickups(dt: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var p: Dictionary = pickups[i]
		p["t"] += dt
		if p["t"] > 0.4 and player.position.distance_to(p["pos"]) < 12.0:
			var sd := Catalog.spell(p["id"])
			player.take_spell(p["id"])
			fx.text(player.position + Vector2(0, -30), sd.title.to_upper(), sd.color, 8)
			fx.ring(p["pos"], 2.0, 18.0, 0.3, sd.color)
			Events.toast.emit("Found %s" % sd.title)
			pickups.remove_at(i)
			_deco.queue_redraw()


# ------------------------------------------------------------------ queries & combat

func tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= gw or y >= gh:
		return 1
	return grid[y * gw + x]


func solid_at(p: Vector2) -> bool:
	var t := tile_at(floori(p.x / TS), floori(p.y / TS))
	return t == 1 or t == 3


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


func los(a: Vector2, b: Vector2) -> bool:
	var n := ceili(a.distance_to(b) / 8.0)
	for k in range(1, n):
		if solid_at(a.lerp(b, float(k) / n)):
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
	var crit := crit_chance > 0.0 and rng.randf() < crit_chance
	if crit:
		dmg *= 2.0
	dmg = maxf(1.0, dmg) if not dot else dmg
	e.hp -= dmg
	e.flash = 0.07
	damage_done += dmg
	if not e.heavy and kb > 0.0:
		e.knock += (e.position - from).normalized() * kb * (70.0 if crit else 38.0)
	if not dot:
		fx.number(e.position + Vector2(0, -e.r - 10), dmg, crit)
	if e.hp <= 0.0:
		kill_enemy(e)
	return dmg


func kill_enemy(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	e.visible = false
	kills += 1
	gold += int(e.def["gold"]) * (4 if e.elite else 1)
	fx.sparks(e.position + Vector2(0, -4), 14, Color("#c46bff"), 120.0)
	fx.ring(e.position, 2.0, 12.0, 0.25, Color("#ff3fa4"))
	shake(0.06)
	Events.enemy_killed.emit(e.kind, e.position)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


# ------------------------------------------------------------------ bot (tests, demo)

## Keeps a fighting distance from the nearest enemy, collects loot, walks through a door.
func _bot_drive() -> void:
	controls.fire = true
	var p := player.position
	if cleared:
		if not pickups.is_empty():
			controls.move = (pickups[0]["pos"] - p).normalized()
			return
		var d: Dictionary = doors[0]
		var goal := Vector2(int(d["col"]) * TS + TS, -8.0)
		var to := goal - p
		# get under the door first, then walk up
		controls.move = Vector2(signf(to.x) if absf(to.x) > 4.0 else 0.0, -1.0 if absf(to.x) < 24.0 else 0.0)
		if controls.move == Vector2.ZERO:
			controls.move = Vector2(0, -1)
		return
	var e := nearest_enemy(p, 400.0)
	if e == null:
		controls.move = (Vector2(gw * TS / 2.0, gh * TS / 2.0) - p).limit_length(1.0) * 0.5
		return
	var to_e := e.position - p
	var want := -1.0 if to_e.length() < 70.0 else (1.0 if to_e.length() > 120.0 else 0.0)
	var mv := to_e.normalized() * want + to_e.normalized().orthogonal() * 0.8
	# dodge the nearest enemy bullet heading our way
	for b in ebullets.active:
		if b.alive and b.pos.distance_squared_to(p) < 40.0 * 40.0:
			mv += (p - b.pos).normalized().orthogonal() * 1.5
			break
	if hazard_at(p + mv.normalized() * 10.0):
		mv = -mv
	controls.move = mv.limit_length(1.0)


# ------------------------------------------------------------------ drawing

func _enemy_bullet_texture() -> Texture2D:
	return PixelArt.cached("ebullet", func() -> Image:
		var img := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		for j in 8:
			for i in 8:
				var d := Vector2(i + 0.5 - 4.0, j + 0.5 - 4.0).length()
				if d < 1.6:
					img.set_pixel(i, j, Color.WHITE)
				elif d < 3.8:
					img.set_pixel(i, j, Color(1, 1, 1, 0.8))
		return img)


const DOOR_ICONS := {
	&"fight": ["..w...w..", "...w.w...", "....w....", "...w.w...", "..w...w..", ".h.....h."],
	&"elite": [".wwwwwww.", "w.w...w.w", "wwwwwwwww", ".w.w.w.w.", "..wwwww..", "........."],
	&"treasure": [".hhhhhhh.", "hwwwwwwwh", "hhhhghhhh", "hwwwgwwwh", "hwwwwwwwh", "hhhhhhhhh"],
}


## Floor-level details that change during the room: spikes, doors, torches, loot.
func _draw_deco() -> void:
	var up := spikes_up()
	for h in hazards:
		if up:
			for k in 4:
				var x := h.x * TS + 4 + (k % 2) * 7
				var y := h.y * TS + 4 + (k / 2) * 7
				_deco.draw_colored_polygon(PackedVector2Array([Vector2(x, y + 2), Vector2(x + 1.5, y - 3), Vector2(x + 3, y + 2)]), Color("#cfd4e0"))
	for d in doors:
		var x0 := float(int(d["col"]) * TS)
		var r := Rect2(x0, 0, TS * 2, TS)
		_deco.draw_rect(r, Color("#0c0818"))
		if doors_open:
			var c := _door_color(d["kind"])
			_deco.draw_rect(r.grow(-2), Color(c.r, c.g, c.b, 0.35))
			_deco.draw_rect(Rect2(x0 + 3, 3, TS * 2 - 6, TS - 3), Color(c.r, c.g, c.b, 0.25))
		else:
			for k in 5:
				_deco.draw_rect(Rect2(x0 + 3 + k * 6, 1, 2, TS - 1), Color("#6a6078"))
		_deco.draw_rect(Rect2(x0 - 2, 0, 2, TS), Color("#8a7a5a"))
		_deco.draw_rect(Rect2(x0 + TS * 2, 0, 2, TS), Color("#8a7a5a"))
		_deco.draw_rect(Rect2(x0 - 2, 0, TS * 2 + 4, 2), Color("#b8a070"))
		var icon := PixelArt.cached("door_%s" % d["kind"], func() -> Image:
			return PixelArt.from_rows(PackedStringArray(DOOR_ICONS[d["kind"]]), {"w": "#f2ecff", "h": "#b9851a", "g": "#ffd36b"}, true, false))
		_deco.draw_texture(icon, Vector2(x0 + TS - icon.get_width() / 2.0, 4).round(), Color(1, 1, 1, 1.0 if doors_open else 0.45))
	for p in pickups:
		var sd := Catalog.spell(p["id"])
		var bob := sin(time * 3.0) * 2.0
		_deco.draw_circle(p["pos"] + Vector2(0, 5), 5.0, Color(0, 0, 0, 0.4))
		_deco.draw_texture(Icons.spell(sd), (p["pos"] - Vector2(7, 11 + bob)).round())


func _door_color(kind: StringName) -> Color:
	match kind:
		&"elite":
			return Color("#ff5a5a")
		&"treasure":
			return Color("#ffd36b")
	return Color("#8fd8ff")


## Additive glow on top of the actors: torch flames and pickup shine.
func _draw_top() -> void:
	for tp in torches:
		var f := 0.8 + sin(time * 9.0 + tp.x) * 0.1 + sin(time * 23.0 + tp.y) * 0.05
		_top.draw_circle(tp + Vector2(0, -6), 18.0 * f, Color(1.0, 0.55, 0.2, 0.06))
		_top.draw_circle(tp + Vector2(0, -6), 8.0 * f, Color(1.0, 0.6, 0.25, 0.12))
		_top.draw_rect(Rect2(tp + Vector2(-1, -2), Vector2(2, 5)), Color("#5a3a22"))
		_top.draw_rect(Rect2(tp + Vector2(-1.5, -7 - f), Vector2(3, 4)), Color(1.8, 1.0, 0.35))
		_top.draw_rect(Rect2(tp + Vector2(-0.5, -8 - f * 2.0), Vector2(1, 2)), Color(2.0, 1.8, 1.0))
	if doors_open:
		for d in doors:
			var c := _door_color(d["kind"])
			var x := int(d["col"]) * TS + TS
			_top.draw_circle(Vector2(x, 10), 16.0 + sin(time * 4.0) * 2.0, Color(c.r, c.g, c.b, 0.08))
