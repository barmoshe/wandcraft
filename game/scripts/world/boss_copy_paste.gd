class_name BossCopyPaste
extends Boss
## World 1 mini-boss. The Glitch copied you: an oversized, flickering double of the wizard
## that mirrors your position across the arena with a lag, so where you stand decides where
## it stands. Moves: mirrored fan shots, Ctrl+Z (jumps back to where it was, with a ring),
## a duplicated row of bullets across your lane, and Ctrl+V (pastes two Buglings).

var hist: Array[Vector2] = []


## The clone is drawn a little larger than the hero (the hero art is 32 px tall).
const SCALE := 1.25

func _init_boss() -> void:
	title = "Copy-Paste"
	subtitle = "Mini-boss"
	mini = true
	max_hp = 360.0
	r = 9.0
	spd = 40.0
	move_table = {
		&"mirror_shot": [0.45, 1.4, 0.5],
		&"undo": [0.7, 0.4, 0.8],
		&"dup_row": [0.8, 0.8, 0.6],
		&"paste": [0.6, 0.3, 1.0],
	}
	phases = [
		{"at": 1.0, "moves": [&"mirror_shot", &"undo", &"dup_row"]},
		{"at": 0.5, "moves": [&"mirror_shot", &"undo", &"dup_row", &"paste"]},
	]
	frames = Bestiary.clone_frames()
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 1.0)
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat


func _mirror_target() -> Vector2:
	var c := world.room_size() / 2.0
	var h: Vector2 = hist[0] if not hist.is_empty() else world.player.position
	return c * 2.0 - h


func _idle(dt: float) -> void:
	hist.append(world.player.position)
	if hist.size() > 80:
		hist.pop_front()
	var tgt := _mirror_target()
	position += (tgt - position) * minf(1.0, dt * 2.0)


func _start(m: StringName) -> void:
	match m:
		&"undo":
			set_meta("to", _mirror_target())
			tele_circle(get_meta("to"), 16.0)
		&"dup_row":
			var from_left := world.rng.randf() < 0.5
			set_meta("row_y", world.player.position.y)
			set_meta("left", from_left)
			var w := world.room_size().x
			tele_line(Vector2(0.0 if from_left else w, world.player.position.y), 0.0 if from_left else PI, w, 30.0)
	cd = 0.0


func _go(m: StringName) -> void:
	match m:
		&"undo":
			var to: Vector2 = get_meta("to")
			world.fx.beam(position, to, Color("#5ce1ff"), 2.0)
			position = to
			ring(position, 10 + phase * 4, 62.0, world.rng.randf())
			world.fx.text(position + Vector2(0, -24), "CTRL+Z", Color("#5ce1ff"), 10)
		&"dup_row":
			var left: bool = get_meta("left")
			var y: float = get_meta("row_y")
			var w := world.room_size().x
			for i in range(-2, 3):
				for k in 2:
					var x := 20.0 + k * 14.0 if left else w - 20.0 - k * 14.0
					world.enemy_shoot(Vector2(x, y + i * 16.0), 0.0 if left else PI, 95.0, ed(), 0.0, "shot:Copy-Paste")
		&"paste":
			world.fx.text(position + Vector2(0, -24), "CTRL+V", Color("#ff3fa4"), 10)
			for k in 2:
				var e := world.spawn_enemy(&"bugling", position + Vector2(-30.0 if k == 0 else 30.0, 0))
				e.spawn_t = 0.3


func _act(m: StringName, dt: float, _t: float) -> void:
	if m == &"mirror_shot":
		cd -= dt
		if cd <= 0.0:
			aimed(position + Vector2(0, -8), 3 + phase * 2, 0.6 + phase * 0.1, 90.0 + phase * 15.0)
			cd = 0.5 - phase * 0.1


func _animate() -> void:
	var moving := true
	sprite.texture = frames[6 if sm == &"act" else (2 + int(t * 8.0) % 4 if moving else 0)]
	sprite.flip_h = world.player.position.x < position.x
	sprite.scale = Vector2(SCALE, SCALE)
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	# glitch: occasional horizontal jitter
	sprite.position.x = (world.rng.randf_range(-2, 2) if fmod(t, 1.3) < 0.08 else 0.0)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 2.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	# chromatic ghosts behind the body
	var tex := sprite.texture
	var sz := tex.get_size() * SCALE
	var at := Vector2(-sz.x / 2.0, -sz.y + 1.5)
	var off := 2.0 + sin(t * 9.0)
	draw_texture_rect(tex, Rect2(at + Vector2(-off, 0), sz), false, Color(1.0, 0.25, 0.65, 0.35))
	draw_texture_rect(tex, Rect2(at + Vector2(off, 0), sz), false, Color(0.35, 0.9, 1.0, 0.35))
