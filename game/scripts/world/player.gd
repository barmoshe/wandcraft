class_name Player
extends Node2D
## The wizard. Twin-stick movement, aim assist, and wand casting.
## On phones the right stick aims and fires; with no stick held, auto-fire shoots at the
## nearest visible enemy (Game.auto_fire), so one thumb is enough to play.

const SPEED := 92.0
const ASSIST_CONE := 0.45      # radians either side of the stick
const AUTO_RANGE := 210.0

## Where the wand is held and spells leave, relative to the feet (Hero art: hands at
## the belt, 8 px up). Floating text starts above the hat (`head`, set from the sprite).
const HAND := Vector2(0, -8)
## Busy Wait: seconds standing still (the next cast is charged at 0.6 s).
var still_t := 0.0
## Buffer Overflow: overheal kept as a shield that takes hits first.
var shield := 0.0
var head := Vector2(0, -36)
var world: World
var controls: Controls
var r := 5.0
var vel := Vector2.ZERO
var aim := 0.0
# the run owns HP, wands and the bag; these read through to it
var hp: float:
	get: return world.run.hp
	set(v): world.run.hp = v
var max_hp: float:
	get: return world.run.max_hp
	set(v): world.run.max_hp = v
var wands: Array[WandState]:
	get: return world.run.wands
var cur: int:
	get: return world.run.cur
	set(v): world.run.cur = v
var bag: Array:
	get: return world.run.bag
var target: Enemy
var inv := 0.0
var cast_t := 0.0
var recoil := 0.0          # px the wand kicks back on a cast, springing home
var face := 1
var walk_t := 0.0
var dead := false
var prev_pos := Vector2.ZERO    # position at the start of the tick (camera interpolation)
var _dust_t := 0.0
var sprite: Sprite2D
var wand_sprite: Sprite2D
var tip_glow: Sprite2D
var frames: Array[Texture2D]
## D6: the rig's clips, front and back facing (Hero.rig), and the wand's 16 angles.
var clips_front: Dictionary
var clips_back: Dictionary
var wand_tex: Array[Texture2D]
var clip := "idle"
var clip_t := 0.0
var back := false          # aiming up: the hero turns away from the camera
var hurt_t := 0.0          # seconds of the hurt clip left
var _gem := "frost"        # the held wand's gem ramp (follows the wand in hand)


func setup(w: World) -> void:
	world = w
	controls = w.controls
	frames = Hero.frames()
	clips_front = Hero.clips(false)
	clips_back = Hero.clips(true)
	wand_tex = Hero.wand_angles()
	head = Vector2(0, -frames[0].get_height() - 2.0)
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 1.0)
	add_child(sprite)
	wand_sprite = Sprite2D.new()
	wand_sprite.texture = wand_tex[0]
	wand_sprite.position = HAND
	add_child(wand_sprite)
	tip_glow = Sprite2D.new()
	tip_glow.texture = PixelArt.glow_texture(16)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tip_glow.material = mat
	add_child(tip_glow)


func wand() -> WandState:
	return wands[cur]


func tip() -> Vector2:
	return position + HAND + Vector2.from_angle(aim) * 11.0


func tick(dt: float) -> void:
	if dead:
		return
	prev_pos = position
	inv = maxf(0.0, inv - dt)
	cast_t = maxf(0.0, cast_t - dt)
	if controls.select_wand >= 0:
		if controls.select_wand < wands.size():
			cur = controls.select_wand
		controls.select_wand = -1
	# a wand with nothing to shoot is no use in hand: switch to one that can cast
	if not RunState.can_cast(wand()):
		for i in wands.size():
			if RunState.can_cast(wands[i]):
				cur = i
				break
	# movement
	var mv := controls.move.limit_length(1.0)
	var run := world.run
	var speed := SPEED * Relics.stat(run, "move")
	vel = vel.lerp(mv * speed, 1.0 - pow(0.0005, dt))
	position = world.move_body(position, r, vel * dt)
	if mv.length() > 0.1:
		walk_t += dt * mv.length()
		_dust_t -= dt
		if _dust_t <= 0.0:
			_dust_t = 0.22
			world.fx.dust(position + Vector2(0, 1))
	# aim and fire
	var auto_range := AUTO_RANGE * 1.2
	still_t = still_t + dt if mv.length() < 0.1 else 0.0
	target = world.assist_target(position, auto_range)
	var stick := controls.aim
	var firing := false
	if stick.length() > 0.3:
		aim = _assist(stick.angle())
		firing = true
	elif target and (controls.fire or Game.auto_fire):
		# aim from the hand, where the spell leaves the wand (8 px above the feet)
		var hand := position + HAND
		aim = (lead(target) - hand).angle()
		firing = world.los(hand, target.position)
	elif mv.length() > 0.1:
		aim = mv.angle()
	var regen_mul := Relics.mana_regen_mul(run)
	for w in wands:
		var k: float = regen_mul * w.regen_mul()
		w.mana = minf(w.max_mana(), w.mana + w.def.regen * k * dt)
		w.idle += dt
		w.cd = maxf(0.0, w.cd - dt)
		w.rech = maxf(0.0, w.rech - dt)
	if firing and world.spells.wand_fire(wand(), tip(), aim):
		cast_t = 0.12
		clip_t = 0.0   # each shot replays the cast clip from its anticipation frame
		recoil = 2.0
		world.fx.muzzle(tip(), aim, wand().def.color)
	# hazards
	if world.hazard_at(position) and world.spikes_up():
		hurt(6.0, position, "spikes")
	_animate()


## Where to aim to hit a moving target with a bolt of about BOLT_SPEED.
const BOLT_SPEED := 230.0


func lead(e: Enemy) -> Vector2:
	var d := e.position - position
	var t := minf(0.6, d.length() / BOLT_SPEED)
	var p := e.position + e.vel * t
	return p if world.los(position + HAND, p) else e.position


## Snaps the stick direction onto an enemy inside the assist cone.
func _assist(ang: float) -> float:
	var best := ang
	var bd := ASSIST_CONE
	for e in world.enemies:
		if e.dead or e.spawn_t > 0.0:
			continue
		var d := e.position - position
		if d.length_squared() > AUTO_RANGE * AUTO_RANGE:
			continue
		var diff := absf(angle_difference(ang, d.angle()))
		if diff < bd:
			bd = diff
			best = (lead(e) - position).angle()
	return best


var last_hurt_by := ""


func hurt(amount: float, from: Vector2, by := "") -> void:
	if dead or inv > 0.0 or Game.god_mode:
		return
	var run := world.run
	if run.has_relic(&"try_catch") and not world.caught:
		world.caught = true
		inv = 0.7
		world.fx.text(position + head, "CAUGHT", Color("#9ab0ff"))
		world.fx.ring(position + Vector2(0, -6), 2.0, 16.0, 0.3, Color("#9ab0ff"))
		return
	amount *= Relics.damage_taken_mul(run)
	if run.has_relic(&"cornered") and world.cornered():
		amount *= 0.7
	if shield > 0.0:
		var soak := minf(shield, amount)
		shield -= soak
		amount -= soak
		world.fx.ring(position + Vector2(0, -12), 2.0, 14.0, 0.25, Color("#9ab0ff"))
		if amount <= 0.0:
			inv = 0.4
			return
	last_hurt_by = by
	hurt_t = 0.2
	hp -= amount
	world.hit_in_room = true
	inv = 0.9
	vel += (position - from).normalized() * 120.0
	world.fx.hurt_number(position + head, amount)
	world.shake(0.35)
	world.hitstop(0.09)   # getting hit freezes the moment, so you feel it (design-plan §10)
	world.flash(0.15)
	Game.buzz(40)
	Events.player_hurt.emit(amount)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		Events.player_died.emit()


func heal(amount: float) -> void:
	var over := hp + amount - max_hp
	if over > 0.0 and world.run and world.run.has_relic(&"buffer_overflow"):
		shield = minf(30.0, shield + over)
	hp = minf(max_hp, hp + amount)
	world.fx.text(position + head, "+%d" % roundi(amount), Color("#7dff6a"))


## The clip the hero should show now, most urgent first (design-plan §8).
func pick_clip() -> String:
	if dead:
		return "death"
	if hurt_t > 0.0:
		return "hurt"
	if cast_t > 0.0:
		return "cast"
	return "run" if vel.length() > 12.0 else "idle"


## Plays the death clip while the world counts down to the retry prompt.
func death_tick(dt: float) -> void:
	if clip != "death":
		clip = "death"
		clip_t = 0.0
	clip_t += dt
	var fr: Array = (clips_back if back else clips_front)["death"]
	sprite.texture = fr[Hero.rig(back).frame_at("death", clip_t)]
	sprite.visible = true
	wand_sprite.visible = false
	tip_glow.visible = false


func _animate() -> void:
	var dt := get_physics_process_delta_time()
	hurt_t = maxf(0.0, hurt_t - dt)
	if absf(cos(aim)) > 0.2:
		face = 1 if cos(aim) > 0.0 else -1
	# aiming up turns the hero's back to the camera (with a little hysteresis)
	var up := -sin(aim)
	if up > 0.6:
		back = true
	elif up < 0.4:
		back = false
	var want := pick_clip()
	if want != clip:
		# a cast restarts on every shot; the walk keeps its phase from the distance walked
		clip = want
		clip_t = 0.0
	clip_t += dt
	var rig := Hero.rig(back)
	var t := walk_t * 0.75 if clip == "run" else clip_t
	var fr: Array = (clips_back if back else clips_front)[clip]
	sprite.texture = fr[rig.frame_at(clip, t)]
	sprite.flip_h = face < 0
	sprite.visible = inv <= 0.0 or fmod(inv, 0.12) > 0.05
	# the wand is drawn pre-rotated (16 angles), never rotated as a sprite
	var k := posmod(roundi(aim / (TAU / 16.0)), 16)
	var gem := Hero.gem_ramp(wand().def.color)
	if gem != _gem:
		_gem = gem
		wand_tex = Hero.wand_angles(gem)
	wand_sprite.texture = wand_tex[k]
	wand_sprite.visible = true
	tip_glow.visible = true
	recoil = maxf(0.0, recoil - 0.5)
	wand_sprite.position = (HAND - Vector2.from_angle(aim) * roundf(recoil)).round()
	wand_sprite.z_index = -1 if back or sin(aim) < -0.3 else 0
	var w := wand()
	tip_glow.position = HAND + Vector2.from_angle(aim) * 11.0
	var c := w.def.color if w.cd > 0.0 else Color("#8fd8ff")
	tip_glow.modulate = Color(c.r, c.g, c.b, 0.55 + (0.4 if cast_t > 0.0 else 0.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
