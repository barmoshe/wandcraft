class_name Enemy
extends Node2D
## A World 1 enemy. Four behaviours for the slice: chase, shoot (keeps range), charge
## (telegraph then dash), turret (bursts). Names and numbers are original (decisions/0002).

const DEFS := {
	&"slime": {"title": "Moss Blob", "ai": &"chase", "hp": 16.0, "spd": 34.0, "r": 6.0, "dmg": 5.0, "cost": 1, "gold": 1,
		"role": &"pressure", "split": 2},
	&"slimelet": {"title": "Moss Blob", "ai": &"chase", "hp": 6.0, "spd": 44.0, "r": 4.0, "dmg": 3.0, "cost": 0, "gold": 0},
	&"weaver": {"title": "Hex Weaver", "ai": &"shoot", "hp": 22.0, "spd": 40.0, "r": 6.0, "dmg": 8.0, "cost": 3, "gold": 3,
		"role": &"anchor", "shot": {"n": 1, "spd": 85.0, "cd": 2.8, "tele": 0.5, "burst": 3, "bcd": 0.14}},
	&"ram": {"title": "Thornback", "ai": &"charge", "hp": 34.0, "spd": 30.0, "r": 7.0, "dmg": 8.0, "cost": 3, "gold": 3,
		"role": &"pressure", "dash": {"range": 120.0, "tele": 0.65, "t": 0.5, "spd": 240.0, "stun": true}},
	&"bugling": {"title": "Bugling", "ai": &"charge", "hp": 7.0, "spd": 50.0, "r": 4.0, "dmg": 3.0, "cost": 1, "gold": 1,
		"role": &"pressure", "dash": {"range": 70.0, "tele": 0.3, "t": 0.28, "spd": 170.0, "stun": false}},
	&"puffcap": {"title": "Puffcap", "ai": &"turret", "hp": 26.0, "spd": 0.0, "r": 6.0, "dmg": 8.0, "cost": 3, "gold": 3,
		"role": &"anchor", "shot": {"n": 8, "spd": 62.0, "cd": 3.0, "ring": true}},
	&"loop_seg": {"title": "Loop Segment", "ai": &"part", "hp": 1e9, "spd": 0.0, "r": 6.0, "dmg": 12.0, "cost": 0, "gold": 0},
	&"sentry": {"title": "Rune Sentry", "ai": &"turret", "hp": 44.0, "spd": 0.0, "r": 7.0, "dmg": 10.0, "cost": 4, "gold": 5,
		"role": &"anchor", "shield": 8, "shot": {"n": 1, "spd": 120.0, "cd": 0.45, "burst": 3, "bcd": 2.6, "sight": 0.8}},
	# D4: four more, each with a counter (design-plan §3)
	&"golem": {"title": "Bark Golem", "ai": &"slam", "hp": 70.0, "spd": 22.0, "r": 9.0, "dmg": 10.0, "cost": 5, "gold": 5,
		"role": &"anchor", "armor": 60.0},
	&"wisp": {"title": "Lantern Wisp", "ai": &"support", "hp": 18.0, "spd": 36.0, "r": 5.0, "dmg": 0.0, "cost": 3, "gold": 3,
		"role": &"support"},
	&"stump": {"title": "Brood Stump", "ai": &"summon", "hp": 55.0, "spd": 0.0, "r": 8.0, "dmg": 6.0, "cost": 4, "gold": 4,
		"role": &"anchor"},
	&"tick": {"title": "Glitch Tick", "ai": &"fuse", "hp": 10.0, "spd": 55.0, "r": 4.0, "dmg": 14.0, "cost": 2, "gold": 2,
		"role": &"pressure"},
}

## Elite affixes (D4): one per elite in World 1, each with an outline colour.
##   armored   an armour bar (Blast breaks it)      warded    a 3-hit ward that comes back
##   hasted    moves and attacks 50% faster          forked    its shots split in three
##   mirrored  splits into a weaker copy when it dies
const AFFIXES := {
	&"armored": {"title": "ARMORED", "col": "steel:4"},
	&"warded": {"title": "WARDED", "col": "cyan:4"},
	&"hasted": {"title": "HASTED", "col": "gold:4"},
	&"forked": {"title": "FORKED", "col": "violet:4"},
	&"mirrored": {"title": "MIRRORED", "col": "glitch:4"},
}
const WARD_HITS := 3

## Hit flash, status recolor and elite outline in one pass (D1). Statuses recolor along a
## Style ramp by brightness (so a burning enemy stays in palette, not tinted), and an elite's
## INK outline pixels take its affix color.
const FLASH_SHADER := """
shader_type canvas_item;
uniform float flash = 0.0;
uniform float tint = 0.0;
uniform vec3 ramp0; uniform vec3 ramp1; uniform vec3 ramp2; uniform vec3 ramp3; uniform vec3 ramp4;
uniform vec4 outline_col = vec4(0.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (outline_col.a > 0.0 && c.a > 0.0 && max(max(c.r, c.g), c.b) < 0.1) {
		c.rgb = outline_col.rgb;
	}
	if (tint > 0.0) {
		float l = clamp(dot(c.rgb, vec3(0.299, 0.587, 0.114)) * 1.6, 0.0, 1.0) * 4.0;
		vec3 r = l < 1.0 ? mix(ramp0, ramp1, l) : l < 2.0 ? mix(ramp1, ramp2, l - 1.0) : l < 3.0 ? mix(ramp2, ramp3, l - 2.0) : mix(ramp3, ramp4, l - 3.0);
		c.rgb = mix(c.rgb, r, tint);
	}
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
var strafe := 1.0              # weaver: which way it circles the player
var strafe_t := 0.0            # weaver: time until it may change direction on its own
var _flip_cd := 0.0            # weaver: a wall bump flips the strafe at most this often
var _route := Vector2.ZERO     # last route step around cover (chase_dir), re-planned every 0.1 s
var _route_direct := true
var _route_t := 0.0
var vel := Vector2.ZERO        # measured each tick (aim-ahead uses it)
var _prev := Vector2.ZERO
var burn_t := 0.0
var burn_dps := 0.0
var chill_t := 0.0
var chill_slow := 1.0
var chill_n := 0               # chills in a row: three freeze (D2)
var frozen_t := 0.0
var static_t := 0.0            # charged: the next hit arcs to a neighbour
var rot_n := 0                 # Bitrot stacks (five crash)
var rot_t := 0.0
var mark_t := 0.0              # Hex Cursor mark
var shock_t := 0.0             # Thermal Shock cooldown
var stun_t := 0.0              # a rune pylon's pulse (D5)
# D4 defences: each one has a resist keyword that breaks it
var armor := 0.0               # soaks damage; Blast hits it x3, everything else x0.35
var max_armor := 0.0
var ward_n := 0                # hits a ward swallows whole; Shock strips it at once
var shield_hp := 0             # frontal shield: Pierce breaks it, other hits wear it down
var affix: StringName = &""
var haste := 1.0
var parent_uid := -1           # Brood Stump: whose bugling this is
var _def_fx := 0.0             # rate limit for BLOCKED / WARD text
var _ward_t := 0.0
var _st_tick := 0.0
var forward: Enemy          # body parts pass their damage to this (a boss)
var fwd_mul := 1.0
var sprite: Sprite2D
var _tinted := ""
var _base_off := 0.0
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
	heavy = ai == &"turret" or ai == &"summon" or ai == &"slam"
	position = pos
	ph = w.rng.randf() * TAU
	strafe = 1.0 if sin(ph) > 0.0 else -1.0
	_route_t = fmod(ph, 0.1)   # stagger the re-plans across ticks (no extra rng draw)
	cd = w.rng.randf_range(0.8, 2.0)
	frames = Bestiary.frames(String(k)) if Bestiary.has(String(k)) else Sprites.enemy_frames(String(k))
	muzzle = Vector2(0, -roundf(frames[0].get_height() * 0.5))
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 2.0)
	_base_off = sprite.offset.y
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	max_armor = float(def.get("armor", 0.0)) * hp_mul
	armor = max_armor
	shield_hp = int(def.get("shield", 0))
	if elite:
		# elites keep pixel-perfect size; the affix shows as the outline colour
		affix = AFFIXES.keys()[w.rng.randi() % AFFIXES.size()]
		_mat.set_shader_parameter("outline_col", Style.c(AFFIXES[affix]["col"]))
		match affix:
			&"armored":
				max_armor = maxf(max_armor, max_hp * 0.6)
				armor = max_armor
			&"warded":
				ward_n = WARD_HITS
			&"hasted":
				haste = 1.5
				spd *= 1.5
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
	static_t = maxf(0.0, static_t - dt)
	mark_t = maxf(0.0, mark_t - dt)
	shock_t = maxf(0.0, shock_t - dt)
	if rot_n > 0:
		rot_t -= dt
		if rot_t <= 0.0:
			rot_n = 0
	if stun_t > 0.0:
		stun_t -= dt
		return 0.0
	if frozen_t > 0.0:
		frozen_t -= dt
		return 0.0
	if chill_t > 0.0:
		chill_t -= dt
		if chill_t <= 0.0:
			chill_n = 0
		return dt * chill_slow
	return dt


## How many statuses are on this enemy (two or more: Overclocked, +20% damage taken).
func status_count() -> int:
	return int(burn_t > 0.0) + int(chill_t > 0.0 or frozen_t > 0.0) + int(static_t > 0.0) + int(rot_n > 0)


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
			if elite:
				world.fx.text(position + Vector2(0, -18), AFFIXES[affix]["title"], Style.c(AFFIXES[affix]["col"]))
		return
	dt = statuses(dt)
	if dead:
		return
	t += dt
	flash = maxf(0.0, flash - dt)
	_def_fx = maxf(0.0, _def_fx - dt)
	if affix == &"warded" and ward_n <= 0:
		_ward_t += dt
		if _ward_t >= 6.0:
			_ward_t = 0.0
			ward_n = WARD_HITS
	if ai == &"part":
		# a boss segment is moved by its boss; still measure how fast it goes
		if dt > 0.0:
			vel = vel.lerp((position - _prev) / dt, 0.5)
		_prev = position
		_animate()
		return
	_prev = position
	var pl := world.player
	var d := world.target_pos() - position
	var dd := maxf(1.0, d.length())
	var dir := d / dd
	var mv := Vector2.ZERO
	var adt := dt * haste   # attack timers run faster on a Hasted elite
	match ai:
		&"chase":
			# along the flow field around cover; the wobble only in the open (decisions/0008)
			var cdir := _steer(dt, dir)
			var wob := 0.35 if _route_direct else 0.1
			mv = cdir + Vector2(sin(t * 2.0 + ph), cos(t * 2.0 + ph)) * wob
		&"shoot", &"support":
			var sees := world.enemy_sees(position)
			var keep := 110.0 if ai == &"support" else 100.0
			cd -= adt
			_flip_cd -= dt
			if state == &"tele":
				# the weaver glows before its volley
				st_t -= adt
				flash = 0.5 if sin(st_t * 30.0) > 0.0 else 0.0
				if st_t <= 0.0:
					state = &"move"
					burst = int(def["shot"].get("burst", 1))
					bcd = 0.0
			elif burst > 0:
				bcd -= adt
				if bcd <= 0.0:
					shoot(d.angle())
					burst -= 1
					bcd = float(def["shot"].get("bcd", 0.14))
			if sees:
				var want := -1.0 if dd < keep - 20.0 else (1.0 if dd > keep + 25.0 else 0.0)
				strafe_t -= dt
				if strafe_t <= 0.0:
					strafe = -strafe if world.rng.randf() < 0.5 else strafe
					strafe_t = world.rng.randf_range(2.0, 4.0)
				mv = dir * want + dir.orthogonal() * 0.7 * strafe
				if ai == &"shoot" and cd <= 0.0 and dd < 220.0 and state == &"move" and burst <= 0:
					var shot: Dictionary = def["shot"]
					if shot.has("tele"):
						state = &"tele"
						st_t = shot["tele"]
					else:
						shoot(d.angle())
					cd = float(shot["cd"]) * world.rng.randf_range(0.85, 1.15)
			else:
				# no line to the player: walk around the cover until it has one
				mv = _steer(dt, dir)
				cd = maxf(cd, 0.4)
			if ai == &"support" and cd <= 0.0:
				cd = 4.0
				_ward_allies()
		&"charge":
			var dash: Dictionary = def["dash"]
			match state:
				&"move":
					mv = _steer(dt, dir)
					# only wind up a charge down a clear lane (no BONK into a pillar)
					if dd < float(dash["range"]) and world.clear_path(position, pl.position, r):
						cd -= adt
						if cd <= 0.0:
							state = &"tele"
							st_t = dash["tele"]
				&"tele":
					st_t -= adt
					aim_a = d.angle()
					flash = 0.6 if sin(st_t * 40.0) > 0.0 else 0.0
					if st_t <= 0.0:
						state = &"dash"
						st_t = dash["t"]
				&"dash":
					st_t -= dt
					hit_wall = false
					position = world.move_body(position, r, Vector2.from_angle(aim_a) * float(dash["spd"]) * haste * dt)
					if (world.last_hit_x or world.last_hit_y) and dash["stun"]:
						state = &"stun"
						st_t = 1.0
						world.shake(0.12)
						world.fx.text(position + Vector2(0, -12), "BONK", Color.WHITE)
					elif st_t <= 0.0 or world.last_hit_x or world.last_hit_y:
						state = &"move"
						cd = world.rng.randf_range(1.2, 2.2)
				&"stun":
					st_t -= dt
					if st_t <= 0.0:
						state = &"move"
						cd = world.rng.randf_range(1.0, 2.0)
		&"slam":
			# the Bark Golem: plods in, then a 1 s ring telegraph before the slam
			match state:
				&"move":
					mv = _steer(dt, dir)
					cd -= adt
					if dd < 44.0 and cd <= 0.0:
						state = &"tele"
						st_t = 1.0
				&"tele":
					st_t -= adt
					if st_t <= 0.0:
						state = &"move"
						cd = 2.4
						world.shake(0.2)
						world.fx.ring(position, 4.0, SLAM_R, 0.3, Style.c("threat:3"))
						world.break_crates_in(position, SLAM_R)
						if pl.position.distance_to(position) < SLAM_R + pl.r:
							pl.hurt(dmg, position, "slam:%s" % kind)
		&"summon":
			# the Brood Stump: two buglings every few seconds, never more than four of its own
			cd -= adt
			if cd <= 0.0:
				cd = 5.0
				var mine := world.enemies.filter(func(e: Enemy) -> bool: return not e.dead and e.parent_uid == uid).size()
				for k in mini(2, 4 - mine):
					var e := world.spawn_enemy(&"bugling", position + Vector2.from_angle(ph + k * PI) * (r + 6.0))
					e.parent_uid = uid
					e.spawn_t = 0.4
				world.fx.ring(position, 2.0, 14.0, 0.3, Style.c("glitch:3"))
		&"fuse":
			# the Glitch Tick: runs in, blinks for 0.8 s, bursts. Frost holds the fuse.
			if state == &"fuse":
				if chill_t <= 0.0 and frozen_t <= 0.0:
					st_t -= dt
				flash = 0.8 if sin(st_t * 45.0) > 0.0 else 0.0
				if st_t <= 0.0:
					world.fx.ring(position, 3.0, TICK_R, 0.25, Style.c("threat:3"))
					world.shake(0.15)
					if pl.position.distance_to(position) < TICK_R + pl.r:
						pl.hurt(dmg, position, "burst:%s" % kind)
					world.kill_enemy(self)
					return
			else:
				mv = _steer(dt, dir)
				if dd < 26.0:
					state = &"fuse"
					st_t = 0.8
		&"turret":
			cd -= adt
			var shot: Dictionary = def["shot"]
			if state == &"aim":
				# the sentry's laser sight: 0.8 s of warning, then the burst
				st_t -= adt
				aim_a = d.angle()
				if st_t <= 0.0:
					state = &"move"
					burst = shot["burst"]
					bcd = 0.0
			elif burst > 0:
				bcd -= adt
				if bcd <= 0.0:
					shoot(d.angle())
					burst -= 1
					bcd = shot["cd"]
			elif cd <= 0.0 and dd < 240.0 and world.enemy_sees(position):
				if shot.has("burst"):
					cd = shot["bcd"]
					if shot.has("sight"):
						state = &"aim"
						st_t = shot["sight"]
					else:
						burst = shot["burst"]
						bcd = 0.0
				else:
					shoot(d.angle())
					cd = float(shot["cd"]) * world.rng.randf_range(0.85, 1.15)
	if mv.length() > 1.0:
		mv = mv.normalized()
	if state != &"dash":
		position = world.move_body(position, r, mv * spd * dt)
		if (ai == &"shoot" or ai == &"support") and _flip_cd <= 0.0 and (world.last_hit_x or world.last_hit_y):
			strafe = -strafe   # strafed into a wall: circle the other way
			strafe_t = world.rng.randf_range(2.0, 4.0)
			_flip_cd = 0.8
	if absf(mv.x) > 0.1:
		face = 1 if mv.x > 0.0 else -1
	if knock.length_squared() > 1.0:
		position = world.move_body(position, r, knock * dt, true)
		knock *= pow(0.004, dt)
		world.fall_check(self)
		if dead:
			return
	if dmg > 0.0 and ai != &"fuse" and frozen_t <= 0.0 and position.distance_squared_to(pl.position) < pow(r + pl.r - 1.0, 2):
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


const SLAM_R := 36.0
const TICK_R := 30.0


## The Lantern Wisp wards up to three allies near it (Shock strips a ward at once).
func _ward_allies() -> void:
	var near := world.enemies.filter(func(e: Enemy) -> bool:
		return e != self and not e.dead and e.spawn_t <= 0.0 and e.ai != &"part" and e.position.distance_to(position) < 130.0)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.position.distance_squared_to(position) < b.position.distance_squared_to(position))
	for e in near.slice(0, 3):
		e.ward_n = WARD_HITS
		world.fx.beam(position + Vector2(0, -6), e.position + Vector2(0, -6), Style.c("cyan:4"), 1.0)
	world.fx.ring(position + Vector2(0, -6), 2.0, 12.0, 0.3, Style.c("cyan:4"))


## The way toward the player: straight at them while the lane is clear, otherwise the
## route around cover from World.chase_dir. The route is re-planned every 0.1 s (it costs
## a few line checks), but a clear lane follows the player every tick.
func _steer(dt: float, dir: Vector2) -> Vector2:
	_route_t -= dt
	if _route_t <= 0.0:
		_route_t = 0.1
		_route = world.chase_dir(position, r)
		_route_direct = world.chase_direct
	return dir if _route_direct else _route


func _animate() -> void:
	sprite.texture = frames[int(t * 4.0 + ph) % 2]
	sprite.flip_h = face < 0
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	var st := "frost" if chill_t > 0.0 or frozen_t > 0.0 else ("ember" if burn_t > 0.0 else "")
	if st != _tinted:
		_tinted = st
		_mat.set_shader_parameter("tint", 0.55 if st != "" else 0.0)
		if st != "":
			for k in 5:
				_mat.set_shader_parameter("ramp%d" % k, Style.c("%s:%d" % [st, k]))
	# a whole-pixel bob instead of a fractional squash (that smeared pixels, D1)
	if ai != &"turret":
		sprite.offset.y = _base_off - (1.0 if sin(t * 8.0 + ph) > 0.4 else 0.0)
	queue_redraw()


## At most this many enemy shots in the air from normal enemies (bosses are exempt).
const SHOT_CAP := 40


func shoot(ang: float) -> void:
	if world.ebullets.live_count() >= SHOT_CAP:
		return
	var shot: Dictionary = def["shot"]
	var n: int = shot["n"]
	var off := world.rng.randf() * TAU
	var spread: Array = [0.0, -0.26, 0.26] if affix == &"forked" and not shot.get("ring", false) else [0.0]
	for i in n:
		var a := off + TAU * i / n if shot.get("ring", false) else ang
		for sp in spread:
			world.enemy_shoot(position + muzzle * sprite.scale.y, a + sp, float(shot["spd"]), dmg * 0.6, 0.0, "shot:%s" % kind)
	world.fx.ring(position + muzzle * sprite.scale.y, 1.0, 7.0, 0.15, Style.c("threat:3"))


func _draw() -> void:
	if spawn_t > 0.0:
		return   # the spawn rune is drawn by World on the glow layer
	# contact shadow
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 1.0, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO)
	if state == &"tele" and ai == &"charge":
		draw_line(muzzle, Vector2.from_angle(aim_a) * float(def["dash"]["range"]) * 0.6 + muzzle, Color(Style.c("threat:3"), 0.6), 1.0)
	elif state == &"tele" and ai == &"slam":
		var k := 1.0 - clampf(st_t, 0.0, 1.0)
		draw_arc(Vector2.ZERO, SLAM_R, 0.0, TAU, 32, Color(Style.c("threat:3"), 0.35 + 0.4 * k), 1.0)
		draw_arc(Vector2.ZERO, SLAM_R * k, 0.0, TAU, 24, Color(Style.c("threat:3"), 0.5), 1.0)
	elif state == &"fuse":
		draw_arc(Vector2.ZERO, TICK_R, 0.0, TAU, 24, Color(Style.c("threat:3"), 0.5), 1.0)
	elif state == &"aim":
		draw_line(muzzle, Vector2.from_angle(aim_a) * 200.0 + muzzle, Color(Style.c("threat:3"), 0.45), 1.0)
	# defences: a ward ring, a shield arc facing the player
	if ward_n > 0:
		draw_arc(Vector2(0, -r), r + 3.0, 0.0, TAU, 20, Color(Style.c("cyan:4"), 0.35 + 0.15 * ward_n), 1.0)
	if shield_hp > 0:
		var fa := (world.target_pos() - position).angle()
		draw_arc(muzzle, r + 4.0, fa - 1.0, fa + 1.0, 10, Style.c("steel:4"), 2.0)
	if hp < max_hp:
		var w := r * 2.0 + 2.0
		var y := -float(frames[0].get_height()) * sprite.scale.y - 1.0
		draw_rect(Rect2(-w / 2.0, y, w, 2.0), Color(0.05, 0.02, 0.08, 0.9))
		draw_rect(Rect2(-w / 2.0, y, w * hp / max_hp, 2.0), Color("#ff4a5a"))
	if armor > 0.0:
		# the armour bar sits over the health bar, steel grey
		var aw := r * 2.0 + 2.0
		var ay := -float(frames[0].get_height()) * sprite.scale.y - (4.0 if hp < max_hp else 1.0)
		draw_rect(Rect2(-aw / 2.0, ay, aw, 2.0), Color(0.05, 0.02, 0.08, 0.9))
		draw_rect(Rect2(-aw / 2.0, ay, aw * armor / maxf(1.0, max_armor), 2.0), Style.c("steel:4"))
	# status pips (D2): one colour each, at most three, over the health bar
	var pips: Array[Color] = []
	if burn_t > 0.0:
		pips.append(Style.c("ember:3"))
	if chill_t > 0.0 or frozen_t > 0.0:
		pips.append(Style.c("frost:3"))
	if static_t > 0.0:
		pips.append(Style.c("gold:4"))
	if rot_n > 0:
		pips.append(Style.c("glitch:3"))
	if not pips.is_empty():
		var py := -float(frames[0].get_height()) * sprite.scale.y - 5.0
		var px := -float(mini(3, pips.size()) * 3 - 1) / 2.0
		for k in mini(3, pips.size()):
			draw_rect(Rect2(roundf(px + k * 3), py, 2, 2), pips[k])
