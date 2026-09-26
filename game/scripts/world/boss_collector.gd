class_name BossCollector
extends Boss
## Design v3: the second mini-boss, the Garbage Collector (runs pick it or Copy-Paste). A
## hulking bin on treads that collects what you throw at it.
##   Phase 1  Collect: the lid opens (0.7 s) and for 1.4 s every one of your shots that comes
##            close is sucked in; then it spits them back at you as a fan (your own storm).
##            Compact: a line telegraph, then a short charge that leaves trash behind.
##   Phase 2  at 50%: Dump: garbage (Moss Blobs) tipped out beside it, and a ring of shots.
## It is ARMOURED: Blast tears the plating off three times as fast (the armour system), and
## while the lid is open a blast in the maw staggers it (x2 damage for 2 s).
## Counter: stop shooting into the open lid (or blast it), and Blast its armour.

const PULL_R := 72.0
const EAT_R := 27.0   # wider than its body, so a shot is eaten before it lands a hit

var eaten := 0
var _charge_dir := Vector2.ZERO


func _init_boss() -> void:
	title = "Garbage Collector"
	subtitle = "It keeps what you throw"
	phase_lines = ["", "It starts dumping"]
	mini = true
	max_hp = 380.0
	max_armor = 90.0
	armor = max_armor
	r = 13.0
	spd = 22.0
	move_table = {
		&"collect": [0.7, 1.4, 0.4],
		&"compact": [0.8, 0.6, 0.7],
		&"dump": [0.6, 0.3, 0.9],
	}
	phases = [
		{"at": 1.0, "moves": [&"collect", &"compact"]},
		{"at": 0.5, "moves": [&"collect", &"compact", &"dump"]},
	]
	frames = [Bestiary.collector(false), Bestiary.collector(false, 1)]
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 2.0)
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat


func _idle(dt: float) -> void:
	# it trundles toward you, slowly
	var to := world.player.position - position
	if to.length() > 40.0:
		position = world.move_body(position, r, to.normalized() * spd * dt)


func _start(m: StringName) -> void:
	match m:
		&"collect":
			eaten = 0
			tele_circle(position, PULL_R)
			world.fx.text(position + Vector2(0, -40), "COLLECTING", Style.c("toxic:4"), 10)
			Audio.sfx("tele_mid", 0.05)
		&"compact":
			_charge_dir = (world.player.position - position).normalized()
			tele_line(position, _charge_dir.angle(), 150.0, 22.0)
		&"dump":
			tele_circle(position, 30.0)


func _act(m: StringName, dt: float, _t_in: float) -> void:
	match m:
		&"collect":
			# your shots bend in toward the maw and vanish into it
			for b in world.spells.bullets.active:
				if not b.alive:
					continue
				var d := position + Vector2(0, -6) - b.pos
				var dist := d.length()
				if dist < EAT_R:
					b.alive = false
					eaten += 1
					if b.kw & 2:
						weaken(2.0, 2.0, "CHOKED")   # a blast in the maw staggers it
				elif dist < PULL_R:
					b.vel = b.vel.lerp(d.normalized() * b.vel.length(), 0.18)
		&"compact":
			position = world.move_body(position, r, _charge_dir * 180.0 * dt)
			if world.rng.randf() < 0.35:
				world.enemy_shoot(position, 0.0, 0.0, ed(), 0.0, "trash:Garbage Collector")


func _go(m: StringName) -> void:
	match m:
		&"dump":
			for k in 3:
				var e := world.spawn_enemy(&"slime", position + Vector2.from_angle(k * TAU / 3.0) * 28.0)
				e.spawn_t = 0.3
			ring(position, 12, 60.0, world.rng.randf())


func _end(m: StringName) -> void:
	match m:
		&"collect":
			# it spits back what it collected, a fan aimed at you (at least a few, at most 18)
			var n := clampi(eaten, 5, 18)
			var a0 := (world.player.position - position).angle()
			for i in n:
				var a := a0 + (i - (n - 1) / 2.0) * 0.12
				world.enemy_shoot(position + Vector2(0, -16), a, 105.0, ed(), 0.0, "shot:Garbage Collector")
			if eaten > 0:
				world.fx.text(position + Vector2(0, -40), "RETURNED %d" % eaten, Style.c("toxic:4"), 10)
			Audio.sfx("eshot", 0.05)
		&"compact":
			world.shake(0.2)
			_fade_trash()


## Compact's trash lies still for a moment.
func _fade_trash() -> void:
	for b in world.ebullets.active:
		if b.alive and b.by == "trash:Garbage Collector" and b.max_life > 1.6:
			b.life = 1.5
			b.max_life = 1.5


func _animate() -> void:
	var open := move == &"collect" and (sm == &"tele" or sm == &"act")
	var f := int(t * 4.0) % 2
	sprite.texture = Bestiary.collector(open, f)
	sprite.flip_h = false
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 3.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if armor > 0.0:
		draw_arc(Vector2(0, -14), r + 5.0, 0.0, TAU * armor / max_armor, 24, Color(Style.c("steel:4"), 0.8), 1.0)
	if weak_t > 0.0:
		draw_arc(Vector2(0, -14), r + 8.0, 0.0, TAU, 20, Color(Style.c("gold:4"), 0.7), 1.0)
	# the pull, while the lid is open
	if move == &"collect" and sm == &"act":
		var k := fmod(t * 2.0, 1.0)
		draw_arc(Vector2(0, -18), PULL_R * (1.0 - k), 0.0, TAU, 32, Color(Style.c("toxic:3"), 0.35 * k), 1.0)
