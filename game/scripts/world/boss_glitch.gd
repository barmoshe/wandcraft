class_name BossGlitch
extends Boss
## World 3's boss and the story's end (0.20, research/world3-0.20.md): the Glitch, the bug
## from your own first commit (a1f00d), made flesh in Ring Zero.
##   Phase 1  Diff (100-66%): rows across the arena are marked: red "-" rows burn a moment
##            later, green "+" rows stay safe. Burst: aimed fans between diffs.
##   Phase 2  Stack unwind (66-33%): the call stack unwinds through the run. Echoes of the
##            Loop (two Loop Jr.) and of Deadlock (a sweeping beam) come back, in miniature.
##   Phase 3  Revert (33-0%): the room is rewritten from the edges in (standing outside the
##            live rect hurts). Green revert glyphs appear one at a time: touching one reverts
##            the Glitch (a chunk of its HP and a stun) and pushes the rewrite back.

const ROW_H := 16.0
const BURN_T := 1.1
const BEAM_LEN := 150.0
const BEAM_W := 4.0
const REWRITE_SPD := 5.0      # px a second the rewrite closes in
const REWRITE_MIN := 64.0     # the live rect never shrinks below this half-height
const REVERT_EVERY := 4.5
const REVERT_HIT := 0.07      # of max HP, per glyph
const REVERT_BACK := 28.0     # px of rewrite a glyph undoes

var rows: Array = []          # {"y", "add"} for the current diff
var burning := false
var _burn_hit := 0.0
var beam_on := 0              # 0 off, 1 warming, 2 burning
var beam_a := 0.0
var _beam_hit := 0.0
var rewrite := 0.0            # px the rewrite has eaten from each edge (phase 3)
var _rewrite_hit := 0.0
var glyph := Vector2.INF      # a revert glyph on the floor
var _glyph_t := 2.0
var _cd := 0.0
var _fr := 0.0
var _echoes := 0


func _init_boss() -> void:
	title = "The Glitch"
	subtitle = "commit a1f00d. Author: you."
	phase_lines = ["", "The stack unwinds", "Revert it"]
	max_hp = 2600.0
	r = 12.0
	spd = 26.0
	move_table = {
		&"diff": [1.0, BURN_T, 0.5],
		&"burst": [0.6, 1.6, 0.6],
		&"unwind": [0.9, 3.0, 0.8],
	}
	phases = [
		{"at": 1.0, "moves": [&"diff", &"burst"]},
		{"at": 0.66, "moves": [&"diff", &"unwind", &"burst"]},
		{"at": 0.33, "moves": [&"diff", &"burst"]},
	]
	frames = [KernelArt.glitch(0, 0), KernelArt.glitch(0, 1)]
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -frames[0].get_height() / 2.0 + 2.0)
	add_child(sprite)
	_mat = ShaderMaterial.new()
	_mat.shader = _flash_shader()
	sprite.material = _mat
	add_child(world.make_light(Color(1.0, 0.4, 0.8), 0.9, 90.0))


func _room() -> Vector2:
	return world.room_size()


## The live rect in phase 3 (outside it, the rewrite hurts).
func live_rect() -> Rect2:
	var rs := _room()
	var m := minf(rewrite, rs.y / 2.0 - REWRITE_MIN)
	return Rect2(Vector2(m, m), rs - Vector2(m, m) * 2.0)


func _on_phase(p: int) -> void:
	match p:
		1:
			if world.run and world.run.daily == "":
				Story.say("glitch:unwind")
			Audio.sfx("glitch_unwind", position)
		2:
			if world.run and world.run.daily == "":
				Story.say("glitch:revert")
			_glyph_t = 1.5
			beam_on = 0


func tick(dt: float) -> void:
	super.tick(dt)
	if dead:
		return
	_fr += dt
	_burn_hit = maxf(0.0, _burn_hit - dt)
	_beam_hit = maxf(0.0, _beam_hit - dt)
	_rewrite_hit = maxf(0.0, _rewrite_hit - dt)
	var pl := world.player
	# the diff burns
	if burning and _burn_hit <= 0.0:
		for row in rows:
			if not row["add"] and absf(pl.position.y - float(row["y"])) < ROW_H / 2.0 + 2.0:
				_burn_hit = 0.5
				pl.hurt(ed() + 2.0, Vector2(pl.position.x, row["y"]), "diff:%s" % title)
				break
	# the unwound beam (Deadlock's echo)
	if beam_on == 2 and _beam_hit <= 0.0:
		var a := position + Vector2(0, -12)
		var q := Geometry2D.get_closest_point_to_segment(pl.position + Vector2(0, -6), a, a + Vector2.from_angle(beam_a) * BEAM_LEN)
		if q.distance_to(pl.position + Vector2(0, -6)) < BEAM_W + pl.r:
			_beam_hit = 0.6
			pl.hurt(ed() + 2.0, q, "beam:%s" % title)
	# phase 3: the rewrite and the revert glyphs
	if phase >= 2 and sm != &"intro":
		rewrite = minf(rewrite + REWRITE_SPD * dt, _room().y / 2.0 - REWRITE_MIN)
		if not live_rect().has_point(pl.position) and _rewrite_hit <= 0.0:
			_rewrite_hit = 0.5
			pl.hurt(ed() * 0.6, pl.position, "rewrite:%s" % title)
		if glyph == Vector2.INF:
			_glyph_t -= dt
			if _glyph_t <= 0.0:
				_place_glyph()
		elif pl.position.distance_to(glyph) < 12.0:
			_take_glyph()


func _place_glyph() -> void:
	var lr := live_rect().grow(-14.0)
	for k in 12:
		var p := Vector2(world.rng.randf_range(lr.position.x, lr.end.x), world.rng.randf_range(lr.position.y, lr.end.y))
		if world.body_fits(p, 6.0) and p.distance_to(position) > 40.0:
			glyph = p
			Audio.sfx("revert_spawn", p)
			world.fx.ring(p, 2.0, 14.0, 0.3, Style.c("moss:3"))
			return
	_glyph_t = 0.5


func _take_glyph() -> void:
	var at := glyph
	glyph = Vector2.INF
	_glyph_t = REVERT_EVERY
	rewrite = maxf(0.0, rewrite - REVERT_BACK)
	Audio.sfx("revert_take", at)
	world.fx.beam(at, position + Vector2(0, -12), Style.c("moss:4"), 2.0)
	world.fx.ring(position, 4.0, 40.0, 0.4, Style.c("moss:4"))
	weaken(1.5, 1.5, "REVERTED")
	sm = &"recover"
	st_t = 1.5
	tele.clear()
	burning = false
	beam_on = 0
	world.hurt_enemy(self, max_hp * REVERT_HIT, at, 0.0, 0.0)


func _start(m: StringName) -> void:
	_cd = 0.0
	match m:
		&"diff":
			rows.clear()
			var rs := _room()
			var n := int(rs.y / ROW_H)
			# every other band of rows, offset at random; one in three is a safe "+" row
			var off := world.rng.randi() % 2
			for i in n:
				if i < 1 or i >= n - 1:
					continue
				if (i + off) % 2 == 0:
					var add := world.rng.randf() < 0.33
					var y := i * ROW_H + ROW_H / 2.0
					rows.append({"y": y, "add": add})
					if not add:
						tele_rect(Rect2(0, y - ROW_H / 2.0, rs.x, ROW_H))
			Audio.sfx("diff_warn", position)
		&"unwind":
			beam_on = 1
			beam_a = (world.player.position - position).angle() - 1.2


func _go(m: StringName) -> void:
	match m:
		&"diff":
			burning = true
			Audio.sfx("diff_burn", position)
			world.shake(0.2)
		&"burst":
			ring(position + Vector2(0, -12), 12 if phase < 2 else 16, 70.0, world.rng.randf())
		&"unwind":
			beam_on = 2
			if _echoes < 2 * phase:
				# the Loop's echo: two Loop Jr., once a cast
				for k in 2:
					var e := world.spawn_enemy(&"loop_jr", position + Vector2.from_angle(k * PI + 0.4) * 30.0)
					e.spawn_t = 0.5
					e.max_hp *= 0.6
					e.hp = e.max_hp
					_echoes += 1


func _act(m: StringName, dt: float, _t_in: float) -> void:
	match m:
		&"burst":
			_idle(dt)
			_cd -= dt
			if _cd <= 0.0:
				_cd = 0.4 if not pressed() else 0.3
				aimed(position + Vector2(0, -12), 5, 0.6, 96.0)
		&"unwind":
			beam_a += (1.1 if phase < 2 else 1.4) * dt
			_idle(dt * 0.5)
		_:
			_idle(dt)


func _end(m: StringName) -> void:
	match m:
		&"diff":
			burning = false
			rows.clear()
		&"unwind":
			beam_on = 0


func _idle(dt: float) -> void:
	# hovers mid-room, keeping away from the rewritten edges
	var lr := live_rect().grow(-30.0)
	var d := world.player.position - position
	var dist := maxf(1.0, d.length())
	var want := -1.0 if dist < 80.0 else (1.0 if dist > 150.0 else 0.0)
	position += (d / dist * want * spd + Vector2(sin(t * 0.8) * 20.0, cos(t * 0.6) * 10.0)) * dt
	if lr.size.x > 0.0 and lr.size.y > 0.0:
		position = position.clamp(lr.position, lr.end)


func bot_danger(q: Vector2) -> float:
	var d := 0.0
	for row in rows:
		if not row["add"] and absf(q.y - float(row["y"])) < ROW_H / 2.0 + 4.0:
			d += 6.0
	if phase >= 2 and not live_rect().grow(-6.0).has_point(q):
		d += 8.0
	return d


func bot_goal() -> Vector2:
	return glyph


func _animate() -> void:
	var f := int(_fr * 6.0) % 4
	sprite.texture = KernelArt.glitch(mini(phase, 2), 4 if sm == &"tele" else f)
	_mat.set_shader_parameter("flash", clampf(flash * 12.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r + 4.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	var rs := _room()
	# the diff: red rows burning, green rows safe (the telegraphs are World's decals)
	if burning or sm == &"tele" and move == &"diff":
		for row in rows:
			if row["add"] or burning:
				var tex := KernelArt.diff_row(int(rs.x), row["add"])
				draw_texture(tex, Vector2(0, float(row["y"]) - ROW_H / 2.0) - position, Color(1, 1, 1, 0.55 if row["add"] else 0.8))
	# the beam
	if beam_on > 0:
		var a := Vector2(0, -12)
		var b := a + Vector2.from_angle(beam_a) * BEAM_LEN
		if beam_on == 1:
			var on := fmod(t, 0.16) < 0.08
			draw_line(a, b, Color(Style.c("threat:3"), 0.8 if on else 0.35), 2.0 if on else 1.0)
		else:
			draw_line(a, b, Color(Style.c("violet:2"), 0.55), BEAM_W * 2.0 + 2.0)
			draw_line(a, b, Style.c("violet:4"), BEAM_W)
			draw_line(a, b, Color.WHITE, 1.0)
	# the rewrite: the room's edges eaten from the outside in
	if phase >= 2:
		var lr := live_rect()
		var c := Color(Style.c("glitch:1"), 0.55)
		var o := -position
		draw_rect(Rect2(o, Vector2(rs.x, lr.position.y)), c)
		draw_rect(Rect2(o + Vector2(0, lr.end.y), Vector2(rs.x, rs.y - lr.end.y)), c)
		draw_rect(Rect2(o + Vector2(0, lr.position.y), Vector2(lr.position.x, lr.size.y)), c)
		draw_rect(Rect2(o + Vector2(lr.end.x, lr.position.y), Vector2(rs.x - lr.end.x, lr.size.y)), c)
		draw_rect(Rect2(o + lr.position, lr.size), Color(Style.c("glitch:4"), 0.6 + 0.3 * sin(t * 6.0)), false, 1.0)
	if glyph != Vector2.INF:
		var g := KernelArt.revert_glyph(int(_fr * 6.0) % 4)
		draw_texture(g, (glyph - position - g.get_size() / 2.0 + Vector2(0, -2 - sin(t * 4.0) * 2.0)).round())
