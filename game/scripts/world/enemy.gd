class_name Enemy
extends Node2D
## A World 1 enemy. Four behaviours for the slice: chase, shoot (keeps range), charge
## (telegraph then dash), turret (bursts). Names and numbers are original (decisions/0002).

const DEFS := {
	&"slime": {"title": "Moss Blob", "ai": &"chase", "hp": 16.0, "spd": 34.0, "r": 6.0, "dmg": 5.0, "cost": 1, "gold": 1},
	&"weaver": {"title": "Hex Weaver", "ai": &"shoot", "hp": 22.0, "spd": 40.0, "r": 6.0, "dmg": 8.0, "cost": 3, "gold": 3,
		"shot": {"n": 1, "spd": 85.0, "cd": 2.2}},
	&"ram": {"title": "Thornback", "ai": &"charge", "hp": 34.0, "spd": 30.0, "r": 7.0, "dmg": 8.0, "cost": 3, "gold": 3},
	&"bugling": {"title": "Bugling", "ai": &"chase", "hp": 7.0, "spd": 50.0, "r": 4.0, "dmg": 3.0, "cost": 1, "gold": 1},
	&"puffcap": {"title": "Puffcap", "ai": &"turret", "hp": 26.0, "spd": 0.0, "r": 6.0, "dmg": 8.0, "cost": 3, "gold": 3,
		"shot": {"n": 8, "spd": 62.0, "cd": 3.0, "ring": true}},
	&"loop_seg": {"title": "Loop Segment", "ai": &"part", "hp": 1e9, "spd": 0.0, "r": 6.0, "dmg": 12.0, "cost": 0, "gold": 0},
	&"sentry": {"title": "Rune Sentry", "ai": &"turret", "hp": 44.0, "spd": 0.0, "r": 7.0, "dmg": 10.0, "cost": 4, "gold": 5,
		"shot": {"n": 1, "spd": 120.0, "cd": 0.45, "burst": 3, "bcd": 2.6}},
}

const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
static var _shader: Shader

var world: World
var kind: StringName
var def: Dictionary
var uid := 0
var ai: StringName
var hp := 1.0
var max_hp := 1.0
var r := 6.0
var spd := 30.0
var dmg := 8.0
var elite := false
var heavy := false
var dead := false
var spawn_t := 0.75
var knock := Vector2.ZERO
var cd := 1.0
var state: StringName = &"move"
var st_t := 0.0
var aim_a := 0.0
var flash := 0.0
var face := 1
var t := 0.0
var ph := 0.0
var burst := 0
var bcd := 0.0
var hit_wall := false
var vel := Vector2.ZERO        # measured each tick (aim-ahead uses it)
var _prev := Vector2.ZERO
var burn_t := 0.0
var burn_dps := 0.0
var chill_t := 0.0
var chill_slow := 1.0
var _st_tick := 0.0
var forward: Enemy          # body parts pass their damage to this (a boss)
var fwd_mul := 1.0
var sprite: Sprite2D
const ELITE_SCALE := 1.25
## Where shots leave, relative to the feet (half the sprite height).
var muzzle := Vector2(0, -6)
var frames: Array[Texture2D]
var _mat: ShaderMaterial


func setup(w: World, k: StringName, pos: Vector2, id: int, hp_mul := 1.0, is_elite := false) -> void:
	world = w
	kind = k
	def = DEFS[k]
	uid = id
	ai = def["ai"]
	elite = is_elite
	max_hp = float(def["hp"]) * hp_mul * (2.8 if elite else 1.0)
	hp = max_hp
	r = float(def["r"]) + (2.0 if elite else 0.0)
	spd = def["spd"]
	dmg = def["dmg"]
	heavy = ai == &"turret"
	position = pos
	ph = w.rng.randf() * TAU
	cd = w.rng.randf_range(0.8, 2.0)
	frames = Bestiary.frames(String(k)) if Bestiary.has(String(k)) else Sprites.enemy_frames(String(k))
	muzzle = Vector2(0, -roundf(frames[0].get_height() * 0.5))
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 2.0)
	if elite:
		sprite.scale = Vector2(ELITE_SCALE, ELITE_SCALE)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	sprite.visible = false
	add_child(sprite)


## Burn ticks damage; chill slows everything the enemy does. Returns the slowed dt.
func statuses(dt: float) -> float:
	if burn_t > 0.0:
		burn_t -= dt
		_st_tick -= dt
		if _st_tick <= 0.0:
			_st_tick = 0.25
			world.hurt_enemy(self, burn_dps * 0.25, position, 0.0, 0.0, true)
			Audio.sfx("burn", 0.2, -8.0)
			world.fx.sparks(position + Vector2(0, -6), 1, Color("#ff8a3c"), 30.0)
	if chill_t > 0.0:
		chill_t -= dt
		return dt * chill_slow
	return dt


static func _flash_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = FLASH_SHADER
	return _shader


func tick(dt: float) -> void:
	if spawn_t > 0.0:
		spawn_t -= dt
		_prev = position
		if spawn_t <= 0.0:
			sprite.visible = true
			world.fx.ring(position, 2.0, 14.0, 0.25, Color("#c46bff"))
		return
	dt = statuses(dt)
	if dead:
		return
	t += dt
	flash = maxf(0.0, flash - dt)
	if ai == &"part":
		# a boss segment is moved by its boss; still measure how fast it goes
		if dt > 0.0:
			vel = vel.lerp((position - _prev) / dt, 0.5)
		_prev = position
		_animate()
		return
	_prev = position
	var pl := world.player
	var d := pl.position - position
	var dd := maxf(1.0, d.length())
	var dir := d / dd
	var mv := Vector2.ZERO
	match ai:
		&"chase":
			mv = dir + Vector2(sin(t * 2.0 + ph), cos(t * 2.0 + ph)) * 0.35
		&"shoot":
			var want := -1.0 if dd < 80.0 else (1.0 if dd > 125.0 else 0.0)
			var side := 1.0 if sin(ph + t * 0.4) > 0.0 else -1.0
			mv = dir * want + dir.orthogonal() * 0.7 * side
			cd -= dt
			if cd <= 0.0 and dd < 220.0:
				shoot(d.angle())
				cd = float(def["shot"]["cd"]) * world.rng.randf_range(0.85, 1.15)
		&"charge":
			match state:
				&"move":
					mv = dir
					if dd < 120.0:
						cd -= dt
						if cd <= 0.0:
							state = &"tele"
							st_t = 0.65
				&"tele":
					st_t -= dt
					aim_a = d.angle()
					flash = 0.6 if sin(st_t * 40.0) > 0.0 else 0.0
					if st_t <= 0.0:
						state = &"dash"
						st_t = 0.5
				&"dash":
					st_t -= dt
					hit_wall = false
					position = world.move_body(position, r, Vector2.from_angle(aim_a) * 240.0 * dt)
					if world.last_hit_x or world.last_hit_y:
						state = &"stun"
						st_t = 1.0
						world.shake(0.12)
						world.fx.text(position + Vector2(0, -12), "BONK", Color.WHITE)
					elif st_t <= 0.0:
						state = &"move"
						cd = world.rng.randf_range(1.2, 2.2)
				&"stun":
					st_t -= dt
					if st_t <= 0.0:
						state = &"move"
						cd = world.rng.randf_range(1.0, 2.0)
		&"turret":
			cd -= dt
			var shot: Dictionary = def["shot"]
			if burst > 0:
				bcd -= dt
				if bcd <= 0.0:
					shoot(d.angle())
					burst -= 1
					bcd = shot["cd"]
			elif cd <= 0.0 and dd < 240.0:
				if shot.has("burst"):
					burst = shot["burst"]
					bcd = 0.0
					cd = shot["bcd"]
				else:
					shoot(d.angle())
					cd = float(shot["cd"]) * world.rng.randf_range(0.85, 1.15)
	if mv.length() > 1.0:
		mv = mv.normalized()
	if state != &"dash":
		position = world.move_body(position, r, mv * spd * dt)
	if absf(mv.x) > 0.1:
		face = 1 if mv.x > 0.0 else -1
	if knock.length_squared() > 1.0:
		position = world.move_body(position, r, knock * dt)
		knock *= pow(0.004, dt)
	if dmg > 0.0 and position.distance_squared_to(pl.position) < pow(r + pl.r - 1.0, 2):
		pl.hurt(dmg, position, "touch:%s" % kind)
		if state == &"dash":
			# a charge that lands ends there: the ram stops, dazed
			state = &"stun"
			st_t = 0.8
	if world.hazard_at(position) and world.spikes_up():
		world.hurt_enemy(self, 12.0 * dt * 4.0, position, 0.0, 0.0, true)
	if dt > 0.0:
		vel = vel.lerp((position - _prev) / dt, 0.3)
	_animate()


func _animate() -> void:
	sprite.texture = frames[int(t * 4.0 + ph) % 2]
	sprite.flip_h = face < 0
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	sprite.modulate = Color(0.6, 0.85, 1.3) if chill_t > 0.0 else (Color(1.3, 0.85, 0.6) if burn_t > 0.0 else Color.WHITE)
	var sq := 1.0 + sin(t * 8.0 + ph) * 0.06 if ai != &"turret" else 1.0
	sprite.scale = Vector2(1.0 / sq, sq) * (ELITE_SCALE if elite else 1.0)
	queue_redraw()


func shoot(ang: float) -> void:
	var shot: Dictionary = def["shot"]
	var n: int = shot["n"]
	var off := world.rng.randf() * TAU
	for i in n:
		var a := off + TAU * i / n if shot.get("ring", false) else ang
		world.enemy_shoot(position + muzzle * sprite.scale.y, a, float(shot["spd"]), dmg * 0.6, 0.0, "shot:%s" % kind)
	world.fx.ring(position + muzzle * sprite.scale.y, 1.0, 7.0, 0.15, Color("#ff5a7a"))


func _draw() -> void:
	if spawn_t > 0.0:
		return   # the spawn rune is drawn by World on the glow layer
	# contact shadow
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 1.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if state == &"tele":
		draw_line(muzzle, Vector2.from_angle(aim_a) * 60.0 + muzzle, Color(1, 0.3, 0.3, 0.5), 1.0)
	if hp < max_hp:
		var w := r * 2.0 + 2.0
		var y := -float(frames[0].get_height()) * sprite.scale.y - 1.0
		draw_rect(Rect2(-w / 2.0, y, w, 2.0), Color(0.05, 0.02, 0.08, 0.9))
		draw_rect(Rect2(-w / 2.0, y, w * hp / max_hp, 2.0), Color("#ff4a5a"))
