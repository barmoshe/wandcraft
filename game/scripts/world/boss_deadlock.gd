class_name BossDeadlock
extends Boss
## World 2 boss (research/design-w2.md): Deadlock. Two iron guardians, Mutex A and Mutex B,
## circle the arena on opposite sides with a beam between them. One holds the lock: it
## takes no damage (a padlock on its core, shots spark off). The lock changes hands every
## few seconds, or sooner once the open one has taken enough, so you keep switching targets.
##   Phase 1  Volley (the open one fires at you); Sweep (the beam flickers, then burns while
##            they spin: get out of the circle or cross behind it).
##   Phase 2  at 60%: they close in, spin faster, and Crossfire joins (a ring from each).
##   Phase 3  at 25%: the locks break (both take damage), and the beam burns slowly all
##            the time. Kill the pair.
## Mutex B is a body part (Boss.make_part) that passes its damage on to the one HP pool.

const ORBIT_W := 0.35         # radians a second while they stroll
const SWEEP_W := 1.05
const SWAP_T := 5.0           # the lock changes hands this often...
const SWAP_DMG := 110.0       # ...or once the open one has taken this much
const BEAM_W := 4.0           # half width of the burning beam
const SCALE := 1.5            # the guardians are drawn half again as large as their art
const CORE := Vector2(0, -19) # the core (and the beam's anchor), at that scale

var center := Vector2.ZERO
var rx := 150.0
var ry := 78.0
var theta := 0.0
var w := ORBIT_W
var b_open := false           # which one is open: false = A (this node), true = B
var swap_t := SWAP_T
var hp_at_swap := 0.0
var beam := 0                 # 0 cold, 1 warming (a flicker), 2 burning
var mutex_b: Enemy
var _cd := 0.0
var _beam_hit_t := 0.0


func _init_boss() -> void:
	title = "Deadlock"
	subtitle = "World 2 boss"
	phase_lines = ["", "They close in", "The locks break"]
	max_hp = 1800.0
	r = 11.0
	spd = 0.0
	move_table = {
		&"volley": [0.6, 1.4, 0.5],
		&"sweep": [0.9, 2.6, 0.6],
		&"crossfire": [0.7, 0.3, 0.8],
	}
	phases = [
		{"at": 1.0, "moves": [&"volley", &"sweep"]},
		{"at": 0.6, "moves": [&"volley", &"sweep", &"crossfire"]},
		{"at": 0.25, "moves": [&"volley", &"crossfire"]},
	]
	center = world.room_size() / 2.0 + Vector2(0, 4)
	rx = minf(world.room_size().x * 0.3, 150.0)
	ry = minf(world.room_size().y * 0.27, 64.0)   # low enough that the top one clears the HUD
	theta = PI
	frames = [art(false, false), art(true, false)]
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 2.0)
	sprite.scale = Vector2(SCALE, SCALE)
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	add_child(world.make_light(Color(1.0, 0.6, 0.3), 0.8, 80.0))
	mutex_b = make_part(&"mutex", r, 1.0)
	mutex_b.clips = {}
	mutex_b.frames = [art(false, true), art(false, true)]
	mutex_b.sprite.texture = mutex_b.frames[0]
	mutex_b.sprite.offset = sprite.offset
	mutex_b.sprite.scale = sprite.scale
	mutex_b.dmg = dmg
	hp_at_swap = max_hp
	_place()
	_apply_locks()


## The guardians' art: an iron body with a glowing core (A burns orange, B cyan). Locked, the
## core goes cold steel (the padlock is drawn over it in _draw).
static func art(locked: bool, is_b: bool) -> Texture2D:
	return PixelArt.cached("mutex_%d_%d" % [int(locked), int(is_b)], func() -> Image:
		var core := "steel" if locked else ("cyan" if is_b else "ember")
		# cold steel bodies, so they stand off the Foundry's rust floor
		var pal := {"o": "night:0", "I": "steel:4", "i": "steel:3", "d": "steel:1", "s": "gold:4",
			"E": core + ":4", "C": core + ":3", "c": core + ":4"}
		return PixelArt.paint(PackedStringArray([
			".....oooooooo.....",
			".....oIIIIIIo.....",
			".....oiiiiiio.....",
			".....ooEooEoo.....",
			".....oiiiiiio.....",
			".....oiiiiiio.....",
			".....oooooooo.....",
			".oooooooooooooooo.",
			".oIIIIIIIIIIIIIIo.",
			".oIsiiiiiiiiiisdo.",
			".oIiiooooooooiddo.",
			".oIiioCCCCCCoiddo.",
			".oIiioCccccCoiddo.",
			".oIiioCccccCoiddo.",
			".oIiioCCCCCCoiddo.",
			".oIsiooooooooisdo.",
			".oIiiiiiiiiiiiddo.",
			".oooooooooooooooo.",
			"...odddo..odddo...",
			"...odddo..odddo...",
			"...odddo..odddo...",
			"...ooooo..ooooo...",
		]), pal))


func _place() -> void:
	var off := Vector2(cos(theta) * rx, sin(theta) * ry)
	position = center + off
	if mutex_b:
		mutex_b.position = center - off


func _apply_locks() -> void:
	var broken := phase >= 2
	locked = not broken and b_open
	if mutex_b:
		mutex_b.locked = not broken and not b_open
		mutex_b.frames = [art(mutex_b.locked, true), art(mutex_b.locked, true)]
		mutex_b.sprite.texture = mutex_b.frames[0]
	sprite.texture = art(locked, false)


func _swap() -> void:
	b_open = not b_open
	swap_t = SWAP_T * (0.8 if phase > 0 else 1.0)
	hp_at_swap = hp
	_apply_locks()
	var open_at := mutex_b.position if b_open else position
	world.fx.text(open_at + Vector2(0, -44), "UNLOCKED", Style.c("gold:4"), 10)
	world.fx.ring(open_at, 3.0, r + 12.0, 0.3, Style.c("gold:4"))
	Audio.sfx("tele_mid", 0.05)


## The open guardian (where the volley comes from).
func open_body() -> Vector2:
	return mutex_b.position if b_open and mutex_b and not mutex_b.dead else position


func tick(dt: float) -> void:
	super.tick(dt)
	if dead:
		return
	if phase < 2 and sm != &"intro":
		swap_t -= dt
		if swap_t <= 0.0 or hp_at_swap - hp >= SWAP_DMG:
			_swap()
	_beam_hit_t = maxf(0.0, _beam_hit_t - dt)
	if beam == 2 and _beam_hit_t <= 0.0 and mutex_b:
		var pl := world.player
		var q := Geometry2D.get_closest_point_to_segment(pl.position + Vector2(0, -6), position + CORE, mutex_b.position + CORE)
		if q.distance_to(pl.position + Vector2(0, -6)) < BEAM_W + pl.r:
			_beam_hit_t = 0.6
			pl.hurt(ed() + 2.0, q, "beam:Deadlock")


func _idle(dt: float) -> void:
	theta += w * dt
	w = move_toward(w, ORBIT_W * (1.4 if phase > 0 else 1.0), dt)
	if phase >= 2:
		beam = 2   # the locks broke: the beam never cools
	elif beam == 2:
		beam = 0
	_place()


func _on_phase(p: int) -> void:
	match p:
		1:
			rx *= 0.8
			ry *= 0.85
		2:
			_apply_locks()
			world.fx.text(position + Vector2(0, -34), "LOCKS BROKEN", Style.c("gold:4"), 10)


func _start(m: StringName) -> void:
	_cd = 0.0
	match m:
		&"sweep":
			beam = 1
			Audio.sfx("chomp", 0.05)
		&"crossfire":
			tele_circle(position, 20.0)
			tele_circle(mutex_b.position, 20.0)


func _tele_update(dt: float) -> void:
	_idle(dt)
	if move == &"sweep":
		beam = 1


func _go(m: StringName) -> void:
	match m:
		&"sweep":
			beam = 2
			w = SWEEP_W * (1.3 if phase > 0 else 1.0)
		&"crossfire":
			var o := world.rng.randf()
			ring(position, 10, 70.0, o)
			ring(mutex_b.position, 10, 70.0, o + PI / 10.0)
			world.shake(0.15)


func _act(m: StringName, dt: float, _t_in: float) -> void:
	match m:
		&"volley":
			_idle(dt)
			_cd -= dt
			if _cd <= 0.0:
				_cd = 0.35
				# phase 3: both fire, in turn
				var from := open_body() if phase < 2 else (position if int(mt / 0.35) % 2 == 0 else mutex_b.position)
				aimed(from + CORE, 3, 0.35, 92.0)
		&"sweep":
			theta += w * dt
			beam = 2
			_place()
		_:
			_idle(dt)


func _end(m: StringName) -> void:
	if m == &"sweep" and phase < 2:
		beam = 0
		w = ORBIT_W


func _animate() -> void:
	var f := int(t * 3.0) % 2
	sprite.position.y = -1.0 if f == 1 else 0.0
	if mutex_b and not mutex_b.dead:
		mutex_b.sprite.position.y = -1.0 if f == 0 else 0.0
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 3.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	var b_at := (mutex_b.position - position) if mutex_b and not mutex_b.dead else Vector2.ZERO
	# the beam between the cores: a faint thread when cold, a flicker winding up, a burn
	if mutex_b and not mutex_b.dead:
		var a := CORE
		var bb := b_at + CORE
		match beam:
			0:
				draw_dashed_line(a, bb, Color(Style.c("ember:3"), 0.5), 1.0, 4.0)
			1:
				var on := fmod(t, 0.16) < 0.08
				draw_line(a, bb, Color(Style.c("threat:3"), 0.8 if on else 0.35), 2.0 if on else 1.0)
			2:
				draw_line(a, bb, Color(Style.c("ember:2"), 0.55), BEAM_W * 2.0 + 2.0)
				draw_line(a, bb, Style.c("ember:4"), BEAM_W)
				draw_line(a, bb, Style.c("gold:4"), 1.0)
	# padlocks on the locked core
	if locked:
		_padlock(CORE)
	if mutex_b and not mutex_b.dead and mutex_b.locked:
		_padlock(b_at + CORE)


func _padlock(at: Vector2) -> void:
	var c := Style.c("steel:4")
	draw_arc(at + Vector2(0, -3), 3.0, PI, TAU, 8, c, 1.0)
	draw_rect(Rect2(at + Vector2(-4, -2), Vector2(8, 6)), c)
	draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 2)), Style.c("night:0"))
