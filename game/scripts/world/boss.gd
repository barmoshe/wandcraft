class_name Boss
extends Enemy
## Boss framework: intro -> idle -> telegraph -> act -> recover -> idle. Each boss lists its
## moves per phase; phases switch at HP thresholds with a short invulnerable breather that
## clears the bullets (readability on a small screen beats surprise).
## Subclasses implement _init_boss() and the move hooks: _start, _go, _act, _end, _idle.

const INTRO := 1.6

var title := "Boss"
var subtitle := ""
var mini := false
var phases: Array = []          # [{"at": hp fraction, "moves": [names]}]
var move_table: Dictionary = {} # name -> [telegraph s, act s, recover s]
var phase := 0
var sm: StringName = &"intro"
var move: StringName = &""
var last_move: StringName = &""
var mt := 0.0                   # time inside the current move's act
var done := false
var invuln := 0.0
var tele: Array = []            # telegraphs: {"k": line|circle, ...}
var tele_total := 1.0           # the wind-up's length, so its decals fill up (D6)
var parts: Array[Enemy] = []
var weak_t := 0.0               # a weak window (D7): hits land x weak_mul
var weak_mul := 1.5


func setup_boss(w: World, pos: Vector2, id: int) -> void:
	world = w
	uid = id
	position = pos
	kind = &"boss"
	ai = &"boss"
	heavy = true
	spawn_t = 0.0
	dmg = 12.0
	def = {"gold": 40 if mini else 90}
	ph = 0.0
	sm = &"intro"
	st_t = INTRO
	invuln = INTRO
	_init_boss()
	hp = max_hp


func _init_boss() -> void:
	pass


func tick(dt: float) -> void:
	dt = statuses(dt)
	if dead:
		return
	if dt > 0.0:
		vel = vel.lerp((position - _prev) / dt, 0.5)
	_prev = position
	t += dt
	flash = maxf(0.0, flash - dt)
	invuln = maxf(0.0, invuln - dt)
	weak_t = maxf(0.0, weak_t - dt)
	# phase change
	while phase + 1 < phases.size() and hp / max_hp <= float(phases[phase + 1]["at"]):
		phase += 1
		invuln = 1.2
		world.clear_enemy_bullets()
		world.shake(0.5)
		world.hitstop(0.15)
		world.fx.ring(position, 4.0, 90.0, 0.6, Color.WHITE)
		Events.shockwave.emit(position)
		world.fx.text(position + Vector2(0, -28), "PHASE %d" % (phase + 1), Color("#ff3fa4"), 10)
		Audio.sfx("phase", 0.0)
		Game.buzz(120)
		world.hitstop(0.12)
		world.flash(0.35)
		sm = &"recover"
		st_t = 1.2
		tele.clear()
		_on_phase(phase)
	st_t -= dt
	match sm:
		&"intro":
			_idle(dt)
			if st_t <= 0.0:
				sm = &"idle"
				st_t = 0.4
		&"idle":
			_idle(dt)
			if st_t <= 0.0:
				_pick_move()
		&"tele":
			_tele_update(dt)
			if st_t <= 0.0:
				sm = &"act"
				mt = 0.0
				tele.clear()
				st_t = move_table[move][1]
				_go(move)
		&"act":
			mt += dt
			_act(move, dt, mt)
			if st_t <= 0.0 or done:
				sm = &"recover"
				st_t = float(move_table[move][2]) * (0.8 if phase > 0 else 1.0)
				_end(move)
		&"recover":
			_idle(dt)
			if st_t <= 0.0:
				sm = &"idle"
				st_t = 0.15
	var room := world.room_size()
	position = position.clamp(Vector2(24, 30), room - Vector2(24, 24))
	if position.distance_squared_to(world.player.position) < pow(r + world.player.r - 2.0, 2):
		world.player.hurt(dmg, position, "touch:%s" % title)
	for p in parts:
		p.flash = flash
	_animate()


func _pick_move() -> void:
	var pool: Array = phases[phase]["moves"].duplicate()
	if pool.size() > 1:
		pool.erase(last_move)
	move = pool[world.rng.randi() % pool.size()]
	last_move = move
	sm = &"tele"
	st_t = float(move_table[move][0]) * (0.85 if phase > 0 else 1.0)
	tele_total = st_t
	tele.clear()
	done = false
	mt = 0.0
	Audio.sfx("tele", 0.05, -4.0)
	_start(move)


## Opens a weak window: the boss lags and takes more damage for a moment.
func weaken(t: float, mul: float, label: String) -> void:
	weak_t = t
	weak_mul = mul
	world.fx.text(position + Vector2(0, -30), label, Style.c("gold:4"), 10)
	world.fx.ring(position, 3.0, r + 10.0, 0.3, Style.c("gold:4"))


## A rune pylon in the arena pulsed (D7: the Loop counts them).
func on_pylon() -> void:
	pass


## How full the telegraph decals are: they fill through the wind-up, then stay full.
func tele_fill() -> float:
	return clampf(1.0 - st_t / maxf(0.01, tele_total), 0.0, 1.0) if sm == &"tele" else 1.0


## A telegraph box (Select All): drawn by World like the others.
func tele_rect(rect: Rect2) -> void:
	tele.append({"k": "rect", "rect": rect})


# ---- hooks for subclasses
func _on_phase(_p: int) -> void:
	pass


func _start(_m: StringName) -> void:
	pass


func _go(_m: StringName) -> void:
	pass


func _act(_m: StringName, _dt: float, _t: float) -> void:
	pass


func _end(_m: StringName) -> void:
	pass


func _tele_update(dt: float) -> void:
	_idle(dt)


## Default idle: drift to keep a middle distance from the player.
func _idle(dt: float) -> void:
	var d := world.player.position - position
	var dist := maxf(1.0, d.length())
	var want := -1.0 if dist < 90.0 else (1.0 if dist > 140.0 else 0.0)
	position += (d / dist * want * spd + Vector2(sin(t * 0.9) * 18.0, cos(t * 0.7) * 12.0)) * dt


# ---- emitters
func ed() -> float:
	return 6.0


func ring(p: Vector2, n: int, speed: float, offset := 0.0, accel := 0.0) -> void:
	for i in n:
		world.enemy_shoot(p, offset + TAU * i / n, speed, ed(), accel, "shot:%s" % title)


func aimed(p: Vector2, n: int, spread: float, speed: float) -> void:
	var a := (world.player.position - p).angle()
	for i in n:
		world.enemy_shoot(p, a + ((float(i) / (n - 1) - 0.5) * spread if n > 1 else 0.0), speed, ed(), 0.0, "shot:%s" % title)


func tele_line(p: Vector2, ang: float, length: float, width: float) -> void:
	tele.append({"k": "line", "p": p, "a": ang, "len": length, "w": width})


func tele_circle(p: Vector2, rad: float) -> void:
	tele.append({"k": "circle", "p": p, "r": rad})


## A body segment that forwards its damage to the boss.
func make_part(k: StringName, rad: float, fwd := 0.6) -> Enemy:
	var p := world.spawn_enemy(k, position)
	p.ai = &"part"
	p.forward = self
	p.fwd_mul = fwd
	p.spawn_t = 0.0
	p.sprite.visible = true
	p.r = rad
	p.heavy = true
	p.dmg = dmg * 0.5
	p.max_hp = 1e9
	p.hp = 1e9
	parts.append(p)
	return p


func die() -> void:
	for p in parts:
		p.dead = true
		p.visible = false
	world.clear_enemy_bullets()
