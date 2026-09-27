class_name BossLoop
extends Boss
## World 1 boss (D7, research/design-plan.md §5): The Infinite Loop, a serpent running laps
## around the arena, faster every lap.
##   Phase 1  laps; Tail Volley; Lap Charge (the track lights 0.8 s first). The head is
##            ARMOURED (Blast breaks it); the body is soft and passes 40% of its damage on.
##   Phase 2  at 66%: segments can be broken. Every three broken, the tail breaks off as a
##            Loop Jr. that hunts on its own. while(true) rings join the moves.
##            The arena's four rune pylons: four pulses DERAIL it for 4 s at x2 damage.
##   Phase 3  at 30%: the head alone chases you, its trail burning behind it for a moment.
## Playtest (design v3): the Lap Charge now swings the track out (or in) to your lane, so
## standing outside the ring is no hiding place, and the chase is slower than you (it was
## faster, so it could not be escaped).
## At most two kinds of attack are ever in the air at once.

const SEGMENTS := 12
const SPACING := 17
const SEG_HP := 45.0
const ARMOR := 100.0
const DERAIL := 4.0
const PYLONS_TO_DERAIL := 4
const RY_MAX := 86.0          # the arena's half height, less a body: the track's widest y
const R_MIN := 44.0
const CHASE_SPEED := 78.0
const BODY_R := 6.0           # the chasing head's size against walls (its hit size stays r)     # below the player's 92: a chase you can run from (and dash)

var center := Vector2.ZERO
var radius := 92.0
var ang := -PI / 2.0
var av := 0.9
var laps := 0
var on_track := true
var trail: Array[Vector2] = []
var k := 0
var broken := 0              # segments broken in phase 2 (every 3: a Loop Jr.)
var pulses := 0              # pylon pulses toward the next derail
var derail_t := 0.0
var _trail_t := 0.0
var _aw := 0.0               # measured laps speed (radians a second), for aim-ahead
var base_r := 92.0           # the track's resting size
var _want_r := 92.0          # where the track is swinging to (a Lap Charge aims it at you)


func _init_boss() -> void:
	title = "The Infinite Loop"
	subtitle = "World 1 boss"
	phase_lines = ["", "The loop cracks", "while(alive)"]
	max_hp = 1800.0   # 0.16.1: aim fixes made it a 65 s fight on the bench; playtesters called it easy
	max_armor = ARMOR
	armor = ARMOR
	r = 10.0
	spd = 0.0
	move_table = {
		&"lap_charge": [0.8, 2.2, 0.5],
		&"tail_volley": [0.5, 1.6, 0.5],
		&"while_true": [0.6, 2.4, 0.6],
		&"chase": [0.6, 3.0, 0.6],
	}
	phases = [
		{"at": 1.0, "moves": [&"lap_charge", &"tail_volley"]},
		{"at": 0.66, "moves": [&"lap_charge", &"tail_volley", &"while_true"]},
		{"at": 0.3, "moves": [&"chase", &"while_true"]},
	]
	center = world.room_size() / 2.0 + Vector2(0, 6)
	radius = minf(world.room_size().x * 0.32, 112.0)
	base_r = radius
	_want_r = radius
	frames = [Bestiary.loop_head(false), Bestiary.loop_head(true)]
	# the head's views bake lazily, one heading at a time (Bestiary.loop_head_view)
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	var glow := world.make_light(Color(0.5, 1.0, 0.6), 0.9, 90.0)
	add_child(glow)
	for i in SEGMENTS:
		var p := make_part(&"loop_seg", 7.0, 0.4)
		# design v3: the body is a chain of glowing code blocks
		p.clips = {}
		p.frames = [Bestiary.code_block(i), Bestiary.code_block(i, 1)]
		p.sprite.texture = p.frames[0]
		p.sprite.offset = Vector2(0, -6)
		p.dmg = dmg * 0.4   # brushing the body hurts less than meeting the head
		p.chain = self


func _loop_move(dt: float, mul: float) -> void:
	if derail_t > 0.0:
		mul = 0.0
	if on_track:
		radius = move_toward(radius, _want_r, 80.0 * dt)
		var prev := ang
		ang += av * mul * dt
		if dt > 0.0:
			_aw = lerpf(_aw, av * mul, 0.3)
		if floori(prev / TAU) != floori(ang / TAU):
			laps += 1
			av = minf(2.4, av + 0.08)
		position = track(ang)
	trail.push_front(position)
	if trail.size() > SEGMENTS * SPACING + 2:
		trail.resize(SEGMENTS * SPACING + 2)
	for i in parts.size():
		var j := mini(trail.size() - 1, (i + 1) * SPACING)
		parts[i].position = trail[j]


## Aim-ahead (design v3 playtest: auto-aim fired at the wall): on the track the head runs
## round the ellipse, so a straight-line lead flies off at a tangent. Predict along the path.
func predict(t: float) -> Vector2:
	if on_track and derail_t <= 0.0:
		return track(ang + _aw * t)
	return super.predict(t)


## A block is where the head was (i + 1) * SPACING ticks ago, so its next second is already
## in the trail; past the trail's front it goes where the head is going.
func predict_part(p: Enemy, t: float) -> Vector2:
	var i := parts.find(p)
	if i < 0 or trail.is_empty():
		return p.position
	var j := mini(trail.size() - 1, (i + 1) * SPACING) - roundi(t * Engine.physics_ticks_per_second)
	return trail[j] if j >= 0 else predict(float(-j) / Engine.physics_ticks_per_second)


## The point at angle `a` on the track: an ellipse 3:4, flattened further near the arena's
## top and bottom walls.
func track(a: float) -> Vector2:
	return center + Vector2(cos(a) * radius, sin(a) * minf(radius * 0.75, RY_MAX))


## The track size that runs through `p`.
func _radius_through(p: Vector2) -> float:
	var d := p - center
	return clampf(sqrt(d.x * d.x + pow(d.y / 0.75, 2.0)), R_MIN, maxf(base_r, center.x - 40.0))


func tick(dt: float) -> void:
	if derail_t > 0.0:
		derail_t -= dt
		if derail_t <= 0.0:
			world.fx.text(position + Vector2(0, -26), "BACK ON TRACK", Color("#7de08a"), 10)
			Audio.sfx("back_on_track", position)
	_check_segments()
	super.tick(dt)


func _idle(dt: float) -> void:
	_loop_move(dt, 1.0)


func _tele_update(dt: float) -> void:
	_loop_move(dt, 0.5)


func _on_phase(p: int) -> void:
	match p:
		1:
			# the shell cracks: segments can now be broken off
			for s in parts:
				s.forward = null
				s.max_hp = SEG_HP
				s.hp = SEG_HP
			world.fx.text(position + Vector2(0, -30), "THE LOOP CRACKS", Color("#7de08a"), 10)
		2:
			# the head alone: what is left of the body falls away
			for s in parts:
				if not s.dead:
					world.fx.dissolve(s.position, s.sprite.texture)
					s.dead = true
					s.visible = false
			parts.clear()
			armor = 0.0
			on_track = false
			world.fx.text(position + Vector2(0, -30), "while(alive)", Color("#7de08a"), 10)


## Phase 2: a broken segment leaves the chain; every third one breaks off a Loop Jr.
func _check_segments() -> void:
	if phase != 1:
		return
	var i := 0
	while i < parts.size():
		if parts[i].dead or parts[i].hp <= 0.0:
			Audio.sfx("segment_break", parts[i].position)
			parts.remove_at(i)
			broken += 1
			hp = maxf(1.0, hp - max_hp * 0.03)   # breaking the body hurts the loop too
			if broken % 3 == 0:
				_spawn_junior()
			continue
		i += 1


func _spawn_junior() -> void:
	var at: Vector2 = parts[parts.size() - 1].position if not parts.is_empty() else position
	var jr := world.spawn_enemy(&"loop_jr", at)
	jr.spawn_t = 0.2
	world.fx.text(at + Vector2(0, -18), "LOOP JR.", Color("#7de08a"), 10)
	Audio.sfx("loop_jr", at)


func on_pylon() -> void:
	if phase < 1 or derail_t > 0.0:
		return
	pulses += 1
	world.fx.text(position + Vector2(0, -26), "%d/%d" % [pulses, PYLONS_TO_DERAIL], Style.c("cyan:4"))
	if pulses >= PYLONS_TO_DERAIL:
		pulses = 0
		derail_t = DERAIL
		Audio.sfx("derail")
		weaken(DERAIL, 2.0, "DERAILED")
		world.shake(0.3)


func _start(m: StringName) -> void:
	cd = 0.0
	k = 0
	match m:
		&"lap_charge":
			# the track swings to your lane, and lights up where it will run
			_want_r = _radius_through(world.player.position)
			tele.append({"k": "track", "p": center, "r": _want_r, "ry": minf(_want_r * 0.75, RY_MAX)})
		&"while_true":
			world.fx.text(position + Vector2(0, -22), "while(true)", Color("#7de08a"), 10)
		&"chase":
			tele_line(position, (world.player.position - position).angle(), 200.0, 10.0)


func _act(m: StringName, dt: float, t_in: float) -> void:
	match m:
		&"lap_charge":
			_loop_move(dt, 2.4)
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
						world.enemy_shoot(p, (p - center).angle(), 70.0, ed(), 0.0, "shot:Loop")
		&"while_true":
			_loop_move(dt, 1.0)
			cd -= dt
			if cd <= 0.0:
				cd = 0.6
				k += 1
				ring(center, 10 + phase * 3, 60.0 + k * 12.0, k * 0.2, 10.0)
		&"chase":
			if derail_t > 0.0:
				Audio.loop("trail_loop", false)
				return
			Audio.loop("trail_loop", true, position)   # the burning trail behind the head
			var a := (world.player.position - position).angle() + sin(t_in * 5.0) * 0.5
			# round the pylons and the pillar, not into them (a head stuck behind a pylon
			# could neither reach you nor be seen)
			_route_t -= dt
			if _route_t <= 0.0:
				_route_t = 0.1
				_route = world.chase_dir(position, BODY_R)
				_route_direct = world.chase_direct
			var dir := Vector2.from_angle(a) if _route_direct else _route
			a = dir.angle()
			# it moves as a slim body (6 px), so it fits the gap by a corner pylon
			position = world.move_body(position, BODY_R, dir * CHASE_SPEED * dt)
			_loop_move(dt, 0.0)
			# the trail burns for a moment behind the head
			_trail_t -= dt
			if _trail_t <= 0.0:
				_trail_t = 0.12
				world.enemy_shoot(position - Vector2.from_angle(a) * 12.0, a, 0.0, ed(), 0.0, "trail:Loop")
				_fade_trail()


func _fade_trail() -> void:
	for b in world.ebullets.active:
		if b.alive and b.by == "trail:Loop" and b.max_life > 1.3:
			b.life = 1.2
			b.max_life = 1.2


func _end(m: StringName) -> void:
	if m == &"lap_charge":
		_want_r = base_r   # it drifts back to its resting lap
	if m == &"chase":
		Audio.loop("trail_loop", false)
	if m == &"chase" and phase < 2:
		on_track = true
		ang = atan2((position.y - center.y) / (minf(radius * 0.75, RY_MAX) / radius), position.x - center.x)


var _head_clip := "chomp"
var _head_t := 0.0


func _head_pick() -> String:
	if invuln > 0.0 and phase > 0:
		return "roar"
	if sm == &"tele":
		return "tele"
	if sm == &"act":
		return "act"
	return "chomp"


func _animate() -> void:
	# the head is drawn pre-rotated (D6), never rotated as a sprite
	var want := _head_pick()
	if want != _head_clip:
		_head_clip = want
		_head_t = 0.0
	_head_t += get_physics_process_delta_time()
	var heading := (trail[0] - trail[mini(3, trail.size() - 1)]).angle() if trail.size() > 3 else 0.0
	var k := posmod(roundi(heading / (TAU / 16.0)), 16)
	var view := Bestiary.loop_head_view(want, Bestiary.loop_rig().frame_at(want, _head_t), k)
	if sprite.texture != view:
		sprite.texture = view
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	# design v3: a glowing spine threads the blocks together (under them, in local space)
	if phase < 2 and trail.size() > 2:
		var pts := PackedVector2Array()
		var n := mini(trail.size(), parts.size() * SPACING + 1)
		for i in range(0, n, 3):
			pts.append(trail[i] - position + Vector2(0, -6))
		if pts.size() > 1:
			var pulse := 0.35 + 0.2 * sin(t * 6.0)
			draw_polyline(pts, Color(Style.c("toxic:3"), pulse), 3.0)
			draw_polyline(pts, Color(Style.c("toxic:4"), pulse + 0.2), 1.0)
	draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 2.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if armor > 0.0:
		draw_arc(Vector2.ZERO, r + 3.0, 0.0, TAU, 20, Color(Style.c("steel:4"), 0.8), 1.0)
	if derail_t > 0.0:
		draw_arc(Vector2.ZERO, r + 7.0, 0.0, TAU * derail_t / DERAIL, 20, Style.c("gold:4"), 1.0)
