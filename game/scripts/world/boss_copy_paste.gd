class_name BossCopyPaste
extends Boss
## World 1 mini-boss (D7, research/design-plan.md §5). The Glitch copied you: an oversized,
## flickering double of the wizard that mirrors your position with a lag, and COPIES YOUR
## WAND: when it spawns it reads the first three shooting spells of the wand in your hand
## and casts them back at you, last one first.
##   Phase 1  Mirror Walk (idle), Copy Cast (0.6 s glitch flash, then your program reversed),
##            Ctrl+Z (jumps back to where it was; it lags after, taking x1.5 for 1.2 s)
##   Phase 2  at 50%: splits in two (the real one flickers; the copy is a ghost that only
##            area and marks reveal), Ctrl+V (pastes buglings), Select All (a 1.2 s box
##            outline around you, then the box fills)
## Counters: area spells hit both copies; a Hex Cursor mark always finds the real one.

var hist: Array[Vector2] = []
var copied: Array = []          # [spell id, level] read from the player's wand at spawn
var ghost: Enemy                # phase 2's decoy
var _cast_q: Array = []         # Copy Cast: shots still to go, with their delay
var _box := Rect2()

## The clone is drawn a little larger than the hero (the hero art is 32 px tall).
const SCALE := 1.25
const LAG := 1.2


func _init_boss() -> void:
	title = "Copy-Paste"
	subtitle = "It read your wand"
	phase_lines = ["", "Split: one of them is a ghost"]
	mini = true
	max_hp = 360.0
	r = 9.0
	spd = 40.0
	move_table = {
		&"copy_cast": [0.6, 1.6, 0.5],
		&"undo": [0.7, 0.4, 0.8],
		&"dup_row": [0.8, 0.8, 0.6],
		&"paste": [0.6, 0.3, 1.0],
		&"select_all": [1.2, 0.5, 0.8],
	}
	phases = [
		{"at": 1.0, "moves": [&"copy_cast", &"undo", &"dup_row"]},
		{"at": 0.5, "moves": [&"copy_cast", &"undo", &"paste", &"select_all"]},
	]
	copied = read_wand(world.run.wand() if world.run else null)
	frames = Bestiary.clone_frames()
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 1.0)
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat


## The first three shooting spells of a wand, in slot order (a Mote if there are none).
static func read_wand(w: WandState) -> Array:
	var out: Array = []
	if w:
		for s in w.slots:
			if s != null and Catalog.spell(s["id"]).kind == SpellDef.Kind.PROJ:
				out.append([s["id"], int(s["lv"])])
				if out.size() >= 3:
					break
	if out.is_empty():
		out.append([&"mote", 1])
	return out


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


func _on_phase(p: int) -> void:
	if p == 1 and ghost == null:
		# the split: a ghost copy mirrors on the other axis; hits on it only flicker
		ghost = world.spawn_enemy(&"slime", position + Vector2(24, 0))
		ghost.ai = &"part"
		ghost.def = {"gold": 0}       # not a slime: no split, no gold
		ghost.kind = &"ghost"
		ghost.spawn_t = 0.0
		ghost.max_hp = 90.0
		ghost.hp = 90.0
		ghost.dmg = 0.0
		ghost.heavy = true
		ghost.frames = frames
		ghost.sprite.texture = frames[0]
		ghost.sprite.scale = Vector2(SCALE, SCALE)
		ghost.sprite.offset = sprite.offset
		ghost.sprite.visible = true
		world.fx.text(position + Vector2(0, -30), "SPLIT", Style.c("glitch:4"), 10)


func _start(m: StringName) -> void:
	match m:
		&"copy_cast":
			# a glitch flash first, so the player sees their own program coming
			world.fx.text(position + Vector2(0, -26), "CASTING YOUR SPELLS", Style.c("glitch:4"), 10)
			Audio.sfx("copy_cast", 0.0)
			tele_circle(position, 14.0)
		&"undo":
			set_meta("to", _mirror_target())
			tele_circle(get_meta("to"), 16.0)
		&"dup_row":
			var from_left := world.rng.randf() < 0.5
			set_meta("row_y", world.player.position.y)
			set_meta("left", from_left)
			var w := world.room_size().x
			tele_line(Vector2(0.0 if from_left else w, world.player.position.y), 0.0 if from_left else PI, w, 30.0)
		&"select_all":
			var pp := world.player.position
			_box = Rect2(pp - Vector2(44, 34), Vector2(88, 60))
			tele_rect(_box)
			world.fx.text(pp + Vector2(0, -44), "SELECT ALL", Style.c("threat:4"), 10)
			Audio.sfx("select_all", 0.0)
	cd = 0.0


func _go(m: StringName) -> void:
	match m:
		&"copy_cast":
			# your program, reversed: the last copied spell first
			_cast_q.clear()
			var rev := copied.duplicate()
			rev.reverse()
			var delay := 0.0
			for c in rev:
				_cast_q.append({"t": delay, "id": c[0], "lv": c[1]})
				delay += 0.35
			if ghost and not ghost.dead:
				_cast_q.append({"t": delay, "id": rev[0][0], "lv": rev[0][1], "from_ghost": true})
		&"undo":
			var to: Vector2 = get_meta("to")
			Audio.sfx("ctrl_z", 0.0)
			world.fx.beam(position, to, Color("#5ce1ff"), 2.0)
			position = to
			ring(position, 8 + phase * 4, 62.0, world.rng.randf())
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
		&"select_all":
			# the box fills: still shots across it that fade in half a second
			var y0 := _box.position.y + 6.0
			while y0 < _box.end.y:
				var x0 := _box.position.x + 6.0
				while x0 < _box.end.x:
					world.enemy_shoot(Vector2(x0, y0), 0.0, 0.0, ed(), 0.0, "box:Copy-Paste")
					x0 += 16.0
				y0 += 16.0
			_fade_box_shots()


## Select All's shots are still and short-lived.
func _fade_box_shots() -> void:
	for b in world.ebullets.active:
		if b.alive and b.by == "box:Copy-Paste" and b.max_life > 1.0:
			b.life = 0.55
			b.max_life = 0.55


func _act(m: StringName, dt: float, _t: float) -> void:
	if m == &"copy_cast":
		for c in _cast_q.duplicate():
			c["t"] -= dt
			if c["t"] <= 0.0:
				_cast_q.erase(c)
				var from := ghost.position if c.get("from_ghost", false) and ghost and not ghost.dead else position
				cast_copy(c["id"], c["lv"], from + Vector2(0, -8))


func _end(m: StringName) -> void:
	if m == &"undo":
		# it lags after the jump: the weak window
		weaken(LAG, 1.5, "LAG")


## One of your spells, as an enemy attack: a bolt becomes an aimed shot, a spray becomes a
## spread, an explosion becomes a ring where it lands.
func cast_copy(id: StringName, lv: int, from: Vector2) -> void:
	var d := Catalog.spell(id)
	var a := (world.player.position - from).angle()
	var n := clampi(int(d.param("count", lv, 1)), 1, 5)
	world.fx.ring(from, 1.0, 8.0, 0.15, d.color)
	match d.behavior:
		&"burst", &"bomb", &"mine", &"cone", &"wall", &"cloud", &"orb":
			var at := from.lerp(world.player.position, 0.6)
			tele_circle(at, 20.0)
			ring(at, 8, 55.0, world.rng.randf())
		_:
			if n > 1:
				aimed(from, n + phase, 0.5, 95.0)
			else:
				var spd := clampf(float(d.param("speed", lv, 200.0)) * 0.45, 80.0, 150.0)
				for k in 1 + phase:
					world.enemy_shoot(from, a + (k - phase * 0.5) * 0.12, spd, ed(), 0.0, "copy:%s" % id)


func tick(dt: float) -> void:
	super.tick(dt)
	if ghost and not ghost.dead:
		# the ghost mirrors the boss across the room's vertical axis
		var room := world.room_size()
		ghost.position = Vector2(room.x - position.x, position.y)
		ghost.sprite.flip_h = world.player.position.x < ghost.position.x
		ghost.sprite.modulate.a = 0.75


## D6: the copy moves on the hero's own rig: it runs, crouches to wind up (the dash's first
## frame), casts in a loop while it acts, and flinches (the hurt clip) on a phase change.
func _clip_now() -> String:
	if invuln > 0.0 and phase > 0:
		return "hurt"
	if sm == &"act":
		return "cast"
	if sm == &"tele":
		return "dash"
	return "run"


func _animate() -> void:
	var clip := _clip_now()
	var fr: Array = Bestiary.clone_clips()[clip]
	var i := 0 if clip == "dash" else (int(t * 12.0) % fr.size() if clip != "hurt" else mini(fr.size() - 1, int(invuln * 10.0) % 2))
	sprite.texture = fr[i]
	sprite.flip_h = world.player.position.x < position.x
	sprite.scale = Vector2(SCALE, SCALE)
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	# glitch: occasional horizontal jitter; in phase 2 the real one flickers
	sprite.position.x = (world.rng.randf_range(-2, 2) if fmod(t, 1.3) < 0.08 else 0.0)
	sprite.modulate.a = 0.55 if phase > 0 and fmod(t, 0.5) < 0.08 else 1.0
	queue_redraw()


func die() -> void:
	super.die()
	if ghost and not ghost.dead:
		world.kill_enemy(ghost)


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 2.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if weak_t > 0.0:
		draw_arc(Vector2(0, -12), r + 6.0, 0.0, TAU, 20, Color(Style.c("gold:4"), 0.7), 1.0)
	# chromatic ghosts behind the body
	var tex := sprite.texture
	var sz := tex.get_size() * SCALE
	var at := Vector2(-sz.x / 2.0, -sz.y + 1.5)
	var off := 2.0 + sin(t * 9.0)
	draw_texture_rect(tex, Rect2(at + Vector2(-off, 0), sz), false, Color(1.0, 0.25, 0.65, 0.35))
	draw_texture_rect(tex, Rect2(at + Vector2(off, 0), sz), false, Color(0.35, 0.9, 1.0, 0.35))
	# design v3: the clipboard. What it copied from your wand, shown while it enters and while
	# it winds up and casts it back (last one first, so the icons read right to left)
	var show := sm == &"intro" or (move == &"copy_cast" and (sm == &"tele" or sm == &"act"))
	if show and not copied.is_empty():
		var n := copied.size()
		var pw := n * 18.0 + 6.0
		# beside the body (above it would sit under the entrance's letterbox at the top wall)
		var top := Vector2(sz.x / 2.0 + 4.0, at.y + sz.y * 0.25)
		draw_rect(Rect2(top, Vector2(pw, 20)), Color(0.07, 0.05, 0.13, 0.9))
		draw_rect(Rect2(top, Vector2(pw, 20)), Style.c("glitch:3"), false, 1.0)
		draw_rect(Rect2(top + Vector2(pw / 2.0 - 5, -3), Vector2(10, 4)), Style.c("bone:3"))
		for i in n:
			var ic := Icons.spell(Catalog.spell(copied[n - 1 - i][0]))
			draw_texture(ic, (top + Vector2(3 + i * 18.0 + 9.0, 10.0) - ic.get_size() / 2.0).round())

