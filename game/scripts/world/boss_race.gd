class_name BossRace
extends Boss
## World 3's mini-boss (0.20, research/world3-0.20.md): Data Race. Two threads, A (this node)
## and B, lap one oval track in opposite directions and burst where their paths cross. Each
## has its own HP, and they may only fall together: when one drops, the other has RACE_T
## seconds; if it isn't down too, the fallen one respawns at RESPAWN of its HP. The counter
## is the wand, not the aim: hurt both, then finish them close together.
##   Phase 1  Volley (each fires a small aimed fan in turn); Cut (one thread leaves the track
##            and dashes through you along a telegraphed line)
##   Phase 2  at 50% of A: they lap faster, and Crossfire joins (a ring from each)

const LAP_W := 0.5            # radians a second
const RACE_T := 2.0           # seconds the survivor has
const RESPAWN := 0.4
const THREAD_HP := 520.0
const CUT_SPD := 260.0

var center := Vector2.ZERO
var rx := 140.0
var ry := 70.0
var theta := 0.0
var w := LAP_W
var thread_b: Enemy
var a_down := false
var b_down := false
var race_t := 0.0
var _cd := 0.0
var _cross_cd := 0.0
var _cut_who := 0             # 0 A, 1 B
var _cut_from := Vector2.ZERO
var _cut_a := 0.0
var _off_a := Vector2.ZERO    # a thread off the track (cutting) is here instead
var _off_b := Vector2.ZERO
var _fr := 0.0


func _init_boss() -> void:
	mini = true
	title = "Data Race"
	subtitle = "Hurt both. Finish them together."
	phase_lines = ["", "They speed up"]
	max_hp = THREAD_HP
	r = 8.0
	spd = 0.0
	move_table = {
		&"volley": [0.5, 1.4, 0.5],
		&"cut": [0.7, 0.6, 0.6],
		&"crossfire": [0.6, 0.3, 0.7],
	}
	phases = [
		{"at": 1.0, "moves": [&"volley", &"cut"]},
		{"at": 0.5, "moves": [&"volley", &"cut", &"crossfire"]},
	]
	center = world.room_size() / 2.0 + Vector2(0, 6)
	rx = minf(world.room_size().x * 0.32, 150.0)
	ry = minf(world.room_size().y * 0.28, 66.0)
	theta = PI * 0.5
	frames = [KernelArt.thread(0, 0), KernelArt.thread(0, 1)]
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 2.0)
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	add_child(world.make_light(Color(0.5, 0.9, 1.0), 0.6, 60.0))
	thread_b = world.spawn_enemy(&"thread", position)
	thread_b.ai = &"part"
	thread_b.spawn_t = 0.0
	thread_b.sprite.visible = true
	thread_b.r = r
	thread_b.heavy = true
	thread_b.dmg = dmg * 0.5
	thread_b.max_hp = THREAD_HP
	thread_b.hp = THREAD_HP
	thread_b.owner_boss = self
	thread_b.clips = {}
	thread_b.frames = [KernelArt.thread(1, 0), KernelArt.thread(1, 1)]
	thread_b.sprite.texture = thread_b.frames[0]
	thread_b.sprite.offset = sprite.offset
	parts.append(thread_b)
	_place()


## Where each thread is on the track: A at theta, B at -theta (so they meet at the ends).
func _place() -> void:
	var pa := center + Vector2(cos(theta) * rx, sin(theta) * ry)
	var pb := center + Vector2(cos(-theta) * rx, sin(-theta) * ry)
	position = pa if _off_a == Vector2.ZERO else _off_a
	if thread_b:
		thread_b.position = pb if _off_b == Vector2.ZERO else _off_b


## Thread A's HP ran out: it falls only if B is already down (in the race window).
func can_die() -> bool:
	if b_down:
		return true
	if a_down:
		return false
	_fall(true)
	return false


## Thread B's HP ran out: if A is down, both fall now; else B waits for A.
func part_can_die(p: Enemy) -> bool:
	if p != thread_b:
		return true
	if a_down:
		hp = 0.0
		world.kill_enemy(self)
		return false
	if not b_down:
		_fall(false)
	return false


func _fall(is_a: bool) -> void:
	race_t = RACE_T
	if is_a:
		a_down = true
		hp = 1.0
		invuln = RACE_T + 0.1
		dmg = 0.0   # a fallen thread is a ghost: it doesn't bump
	else:
		b_down = true
		thread_b.hp = 1.0
		thread_b.locked = true
	var at := position if is_a else thread_b.position
	world.fx.text(at + Vector2(0, -30), "THREAD %s DOWN: FINISH THE OTHER" % ("A" if is_a else "B"), Style.c("gold:4"), 10)
	world.fx.ring(at, 3.0, 26.0, 0.4, Style.c("gold:4"))
	Audio.sfx("phase", at)


func _respawn() -> void:
	var at: Vector2
	if a_down:
		a_down = false
		hp = max_hp * RESPAWN
		invuln = 0.4
		dmg = 12.0
		at = position
	if b_down:
		b_down = false
		thread_b.hp = thread_b.max_hp * RESPAWN
		thread_b.locked = false
		at = thread_b.position
	world.fx.text(at + Vector2(0, -30), "RESPAWNED", Style.c("threat:4"), 10)
	world.fx.ring(at, 3.0, 30.0, 0.4, Style.c("threat:3"))
	Audio.sfx("race_respawn", at)
	if world.run and world.run.daily == "":
		Story.say("boss:Data Race")


func tick(dt: float) -> void:
	super.tick(dt)
	if dead:
		return
	_fr += dt
	_cross_cd = maxf(0.0, _cross_cd - dt)
	if a_down or b_down:
		race_t -= dt
		if race_t <= 0.0:
			_respawn()
	if a_down:
		invuln = maxf(invuln, 0.1)
	# B is as solid as A (unless it's down)
	if thread_b and not b_down and thread_b.position.distance_squared_to(world.player.position) < pow(r + world.player.r - 2.0, 2):
		world.player.hurt(dmg, thread_b.position, "touch:%s" % title)
	# where the paths cross (sin(theta) near 0), a burst
	if _off_a == Vector2.ZERO and _off_b == Vector2.ZERO and absf(sin(theta)) < 0.06 and _cross_cd <= 0.0 and sm != &"intro":
		_cross_cd = 1.5
		var at := center + Vector2(cos(theta) * rx, 0)
		Audio.sfx("race_cross", at)
		world.fx.ring(at, 3.0, 22.0, 0.3, Style.c("cyan:4"))
		if not a_down and not b_down:
			ring(at, 8 if phase == 0 else 12, 70.0, world.rng.randf())


func _idle(dt: float) -> void:
	theta += w * dt
	w = move_toward(w, LAP_W * (1.45 if phase > 0 else 1.0), dt)
	_place()


func _alive_body(which: int) -> Vector2:
	return position if which == 0 else thread_b.position


func _start(m: StringName) -> void:
	_cd = 0.0
	match m:
		&"cut":
			# the thread that's up (or the other, if one is down) leaves the track
			_cut_who = 1 if a_down else (0 if b_down else world.rng.randi() % 2)
			_cut_from = _alive_body(_cut_who)
			_cut_a = (world.player.position - _cut_from).angle()
			tele_line(_cut_from, _cut_a, CUT_SPD * move_table[&"cut"][1], r * 2.0)
		&"crossfire":
			tele_circle(position, 18.0)
			tele_circle(thread_b.position, 18.0)


func _tele_update(dt: float) -> void:
	_idle(dt)
	if move == &"cut":
		# the cutting thread holds still while it aims
		if _cut_who == 0:
			_off_a = _cut_from
		else:
			_off_b = _cut_from
		_place()


func _go(m: StringName) -> void:
	match m:
		&"cut":
			Audio.sfx("charge", _cut_from)
		&"crossfire":
			var o := world.rng.randf()
			if not a_down:
				ring(position, 10, 72.0, o)
			if not b_down:
				ring(thread_b.position, 10, 72.0, o + PI / 10.0)
			world.shake(0.15)


func _act(m: StringName, dt: float, _t_in: float) -> void:
	match m:
		&"volley":
			_idle(dt)
			_cd -= dt
			if _cd <= 0.0:
				_cd = 0.4
				var who := int(mt / 0.4) % 2
				if (who == 0 and not a_down) or (who == 1 and not b_down):
					aimed(_alive_body(who) + Vector2(0, -6), 3, 0.32, 95.0)
		&"cut":
			var step := Vector2.from_angle(_cut_a) * CUT_SPD * dt
			if _cut_who == 0:
				_off_a = world.move_body(_off_a, r, step)
			else:
				_off_b = world.move_body(_off_b, r, step)
			theta += w * dt
			_place()
		_:
			_idle(dt)


func _end(m: StringName) -> void:
	if m == &"cut":
		# back onto the track where it now is (the lap takes it home)
		_off_a = Vector2.ZERO
		_off_b = Vector2.ZERO
		_place()


func _animate() -> void:
	var f := int(_fr * 8.0) % 4
	var tele_f := sm == &"tele"
	sprite.texture = KernelArt.thread(0, 4 if tele_f and _cut_who == 0 and move == &"cut" else f)
	sprite.modulate.a = 0.35 if a_down else 1.0
	sprite.flip_h = cos(theta + PI / 2.0) < 0.0
	if thread_b and not thread_b.dead:
		thread_b.sprite.texture = KernelArt.thread(1, 4 if tele_f and _cut_who == 1 and move == &"cut" else (f + 2) % 4)
		thread_b.sprite.modulate.a = 0.35 if b_down else 1.0
		thread_b.sprite.flip_h = cos(-theta + PI / 2.0) > 0.0
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 3.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	# the shared track, faint; and B's HP over it (A's is the boss bar)
	var pts := PackedVector2Array()
	for k in 41:
		var a := TAU * k / 40.0
		pts.append(center - position + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, Color(Style.c("cyan:2"), 0.18), 1.0)
	if thread_b and not thread_b.dead:
		var bp := thread_b.position - position
		var bw := 26.0
		draw_rect(Rect2(bp + Vector2(-bw / 2.0, -26), Vector2(bw, 2)), Color(0.05, 0.02, 0.08, 0.9))
		draw_rect(Rect2(bp + Vector2(-bw / 2.0, -26), Vector2(bw * thread_b.hp / thread_b.max_hp, 2)), Style.c("gold:4"))
	if a_down or b_down:
		# the race clock over the survivor
		var at := (thread_b.position - position) if a_down else Vector2.ZERO
		var k := clampf(race_t / RACE_T, 0.0, 1.0)
		draw_arc(at + Vector2(0, -8), 16.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Style.c("gold:4"), 2.0)
