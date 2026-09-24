class_name BossLoop
extends Boss
## World 1 boss: The Infinite Loop, a serpent running laps around the arena. Every lap makes
## it faster. Its ten body segments take hits for the head (at 60%), so a spell that pierces
## or explodes through the body pays off. Moves: lap charge, tail volley (segments fire
## outward), while(true) (rings from the centre that speed up), and in phase 2 a coil that
## leaves the track to chase you.

const SEGMENTS := 10
const SPACING := 14

var center := Vector2.ZERO
var radius := 92.0
var ang := -PI / 2.0
var av := 0.9
var laps := 0
var on_track := true
var trail: Array[Vector2] = []
var k := 0


func _init_boss() -> void:
	title = "The Infinite Loop"
	subtitle = "Boss"
	max_hp = 1300.0
	r = 10.0
	spd = 0.0
	move_table = {
		&"lap_charge": [0.8, 2.2, 0.5],
		&"tail_volley": [0.5, 1.6, 0.5],
		&"while_true": [0.6, 2.4, 0.6],
		&"coil": [0.7, 2.6, 0.8],
	}
	phases = [
		{"at": 1.0, "moves": [&"lap_charge", &"tail_volley", &"while_true"]},
		{"at": 0.5, "moves": [&"lap_charge", &"tail_volley", &"while_true", &"coil"]},
	]
	center = world.room_size() / 2.0 + Vector2(0, 6)
	radius = minf(world.room_size().x * 0.3, 96.0)
	frames = [Sprites.boss_texture(&"loop_head")]
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	for i in SEGMENTS:
		var p := make_part(&"loop_seg", 6.0)
		p.sprite.offset = Vector2(0, -3)


func _loop_move(dt: float, mul: float) -> void:
	if on_track:
		var prev := ang
		ang += av * mul * dt
		if floori(prev / TAU) != floori(ang / TAU):
			laps += 1
			av = minf(2.4, av + 0.08)
		position = center + Vector2(cos(ang) * radius, sin(ang) * radius * 0.75)
	trail.push_front(position)
	if trail.size() > SEGMENTS * SPACING + 2:
		trail.resize(SEGMENTS * SPACING + 2)
	for i in parts.size():
		var j := mini(trail.size() - 1, (i + 1) * SPACING)
		parts[i].position = trail[j]


func _idle(dt: float) -> void:
	_loop_move(dt, 1.0)


func _tele_update(dt: float) -> void:
	_loop_move(dt, 0.5)


func _start(m: StringName) -> void:
	cd = 0.0
	k = 0
	match m:
		&"lap_charge":
			tele_circle(center, radius)
		&"while_true":
			world.fx.text(position + Vector2(0, -22), "while(true)", Color("#7de08a"), 10)
		&"coil":
			on_track = false
			tele_line(position, (world.player.position - position).angle(), 200.0, 10.0)


func _act(m: StringName, dt: float, t_in: float) -> void:
	match m:
		&"lap_charge":
			_loop_move(dt, 3.2)
			if world.rng.randf() < 0.5:
				world.fx.sparks(position, 1, Color("#7de08a"), 20.0)
		&"tail_volley":
			_loop_move(dt, 0.6)
			cd -= dt
			if cd <= 0.0:
				cd = 0.5
				k += 1
				for i in parts.size():
					if i % 2 == k % 2:
						var p := parts[i].position
						world.enemy_shoot(p, (p - center).angle(), 70.0, ed())
		&"while_true":
			_loop_move(dt, 1.0)
			cd -= dt
			if cd <= 0.0:
				cd = 0.55
				k += 1
				ring(center, 12 + phase * 4, 45.0 + k * 12.0, k * 0.2, 10.0)
		&"coil":
			var a := (world.player.position - position).angle() + sin(t_in * 5.0) * 0.6
			position += Vector2.from_angle(a) * 120.0 * dt
			_loop_move(dt, 0.0)
			if world.rng.randf() < 0.12:
				world.enemy_shoot(position, a + PI + world.rng.randf_range(-0.5, 0.5), 50.0, ed())


func _end(m: StringName) -> void:
	if m == &"coil":
		on_track = true
		ang = atan2((position.y - center.y) / 0.75, position.x - center.x)


func _animate() -> void:
	sprite.rotation = (trail[0] - trail[mini(3, trail.size() - 1)]).angle() if trail.size() > 3 else 0.0
	sprite.flip_v = cos(sprite.rotation) < 0.0
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 2.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
