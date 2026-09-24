class_name Player
extends Node2D
## The wizard. Twin-stick movement, aim assist, and wand casting.
## On phones the right stick aims and fires; with no stick held, auto-fire shoots at the
## nearest visible enemy (Game.auto_fire), so one thumb is enough to play.

const SPEED := 92.0
const ASSIST_CONE := 0.45      # radians either side of the stick
const AUTO_RANGE := 210.0

var world: World
var controls: Controls
var hp := 100.0
var max_hp := 100.0
var r := 5.0
var vel := Vector2.ZERO
var aim := 0.0
var wands: Array[WandState] = []
var cur := 0
var bag: Array = []            # spare spells: {"id", "lv"}
var target: Enemy
var inv := 0.0
var cast_t := 0.0
var face := 1
var walk_t := 0.0
var dead := false
var sprite: Sprite2D
var wand_sprite: Sprite2D
var tip_glow: Sprite2D
var frames: Array[Texture2D]


func setup(w: World) -> void:
	world = w
	controls = w.controls
	frames = Sprites.wizard_frames()
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 1.0)
	add_child(sprite)
	wand_sprite = Sprite2D.new()
	wand_sprite.texture = Sprites.wand_texture()
	wand_sprite.centered = false
	wand_sprite.offset = Vector2(0, -1)
	wand_sprite.position = Vector2(0, -8)
	add_child(wand_sprite)
	tip_glow = Sprite2D.new()
	tip_glow.texture = PixelArt.glow_texture(16)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	tip_glow.material = mat
	add_child(tip_glow)


func new_run() -> void:
	hp = max_hp
	dead = false
	wands.clear()
	wands.append(WandState.make(Catalog.wand(&"apprentice"), ["seed", "burst", "mote", null, null]))
	wands.append(WandState.make(Catalog.wand(&"harp"), ["fan", "then", "burst", "moths", null, null, null]))
	cur = 0
	bag.clear()


func wand() -> WandState:
	return wands[cur]


func tip() -> Vector2:
	return position + Vector2(0, -8) + Vector2.from_angle(aim) * 11.0


func tick(dt: float) -> void:
	if dead:
		return
	inv = maxf(0.0, inv - dt)
	cast_t = maxf(0.0, cast_t - dt)
	if controls.select_wand >= 0:
		if controls.select_wand < wands.size():
			cur = controls.select_wand
		controls.select_wand = -1
	# movement
	var mv := controls.move.limit_length(1.0)
	vel = vel.lerp(mv * SPEED, 1.0 - pow(0.0005, dt))
	position = world.move_body(position, r, vel * dt)
	if mv.length() > 0.1:
		walk_t += dt * mv.length()
	# aim and fire
	target = world.assist_target(position, AUTO_RANGE)
	var stick := controls.aim
	var firing := false
	if stick.length() > 0.3:
		aim = _assist(stick.angle())
		firing = true
	elif target and (controls.fire or Game.auto_fire):
		aim = (target.position - position).angle()
		firing = world.los(position, target.position)
	elif mv.length() > 0.1:
		aim = mv.angle()
	for w in wands:
		w.mana = minf(w.max_mana(), w.mana + w.def.regen * dt)
		w.cd = maxf(0.0, w.cd - dt)
		w.rech = maxf(0.0, w.rech - dt)
	if firing and world.spells.wand_fire(wand(), tip(), aim):
		cast_t = 0.12
	# hazards
	if world.hazard_at(position) and world.spikes_up():
		hurt(10.0, position)
	_animate()


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
			best = d.angle()
	return best


func hurt(amount: float, from: Vector2) -> void:
	if dead or inv > 0.0 or Game.god_mode:
		return
	hp -= amount
	inv = 0.7
	vel += (position - from).normalized() * 120.0
	world.fx.text(position + Vector2(0, -22), "-%d" % roundi(amount), Color("#ff5a6a"))
	world.shake(0.18)
	Events.player_hurt.emit(amount)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		Events.player_died.emit()


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	world.fx.text(position + Vector2(0, -22), "+%d" % roundi(amount), Color("#7dff6a"))


## Puts a spell into the first empty slot of any wand, else into the bag.
func take_spell(id: StringName) -> void:
	for w in wands:
		for i in w.slots.size():
			if w.slots[i] == null:
				w.slots[i] = {"id": id, "lv": 1}
				w.ptr = 0
				w.acc = Mods.new()
				return
	bag.append({"id": id, "lv": 1})


func _animate() -> void:
	var moving := vel.length() > 12.0
	if absf(cos(aim)) > 0.2:
		face = 1 if cos(aim) > 0.0 else -1
	var f := 6 if cast_t > 0.0 else (2 + int(walk_t * 9.0) % 4 if moving else int(world.time * 2.0) % 2)
	sprite.texture = frames[f]
	sprite.flip_h = face < 0
	sprite.visible = inv <= 0.0 or fmod(inv, 0.12) > 0.05
	wand_sprite.rotation = aim
	wand_sprite.z_index = -1 if sin(aim) < -0.3 else 0
	var w := wand()
	tip_glow.position = Vector2(0, -8) + Vector2.from_angle(aim) * 11.0
	var c := w.def.color if w.cd > 0.0 else Color("#8fd8ff")
	tip_glow.modulate = Color(c.r, c.g, c.b, 0.55 + (0.4 if cast_t > 0.0 else 0.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
