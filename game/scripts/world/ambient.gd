class_name AmbientLife
extends Node2D
## D6: the room breathes (design-plan §7 "Ambient life at 6-8 fps"). Purely visual: it never
## touches the simulation or its random numbers, so tests and the bench are unaffected.
##   - grass tufts that lean away when something walks through them, then settle back
##   - dust motes drifting in the torch light (additive, on the glow layer)
##   - leaves that fall from the canopy now and then and drift across the room
## Everything moves in whole pixels on an 8 fps step, like the rest of the pixel art.

const STEP := 1.0 / 8.0
const MAX_TUFTS := 24
const MAX_LEAVES := 3

var world: World
var rng := RandomNumberGenerator.new()
var tufts: Array = []     # [pos, lean -1..1, settle timer]
var motes: Array = []     # [pos, phase, torch]
var leaves: Array = []    # [pos, vel, phase]
var glow: Node2D          # the additive child the motes draw on
## Design v3: the Grove's corruption veins pulse (RoomPainter.veins, the same lines the floor
## bakes dark), and its tufts, spores and motes take the Grove's colours.
var veins: Array = []
var grove := false
var _acc := 0.0
var _t := 0.0


func setup(w: World) -> void:
	world = w
	glow = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.draw.connect(_draw_motes)


## A new room: scatter tufts on open floor and motes around the torches.
func reset(seed_value: int) -> void:
	rng.seed = seed_value
	grove = world.biome() == 1
	veins = RoomPainter.veins(world.grid, world.gw, world.gh, seed_value) if grove else []
	tufts.clear()
	motes.clear()
	leaves.clear()
	var tries := 0
	while tufts.size() < MAX_TUFTS and tries < 200:
		tries += 1
		var x := rng.randi_range(1, world.gw - 2)
		var y := rng.randi_range(1, world.gh - 2)
		if world.tile_at(x, y) != 0:
			continue
		tufts.append([Vector2(x * World.TS + rng.randi_range(2, 13), y * World.TS + rng.randi_range(4, 14)), 0.0, 0.0])
	for tp in world.torches:
		for k in 5:
			motes.append([tp + Vector2(rng.randf_range(-22, 22), rng.randf_range(-20, 14)), rng.randf() * TAU, tp])


func _process(dt: float) -> void:
	if world == null or world.gw == 0:
		return
	_acc += dt
	if _acc < STEP:
		return
	var st := _acc
	_acc = 0.0
	_t += st
	# tufts lean away from anything walking through them
	var movers: Array[Vector2] = [world.player.position]
	for e in world.enemies:
		if not e.dead and e.vel.length_squared() > 100.0:
			movers.append(e.position)
	for tf in tufts:
		var p: Vector2 = tf[0]
		for m in movers:
			var d := p - m
			if absf(d.x) < 9.0 and absf(d.y) < 6.0:
				tf[1] = 1.0 if d.x >= 0.0 else -1.0
				tf[2] = 0.5
		tf[2] = maxf(0.0, tf[2] - st)
		if tf[2] <= 0.0:
			tf[1] = move_toward(tf[1], 0.0, 0.5)
	# motes wander around their torch
	for m in motes:
		m[1] += st * 0.9
		var home: Vector2 = m[2]
		m[0] = home + Vector2(cos(m[1]) * 18.0, sin(m[1] * 1.3) * 12.0 - 4.0)
	# a leaf now and then from the top edge
	if leaves.size() < MAX_LEAVES and rng.randf() < 0.04:
		leaves.append([Vector2(rng.randf_range(0, world.gw * World.TS), -8.0), Vector2(rng.randf_range(-6, 6), 14.0), rng.randf() * TAU])
	for i in range(leaves.size() - 1, -1, -1):
		var lf: Array = leaves[i]
		lf[2] += st * 3.0
		lf[0] += (lf[1] + Vector2(sin(lf[2]) * 10.0, 0.0)) * st
		if lf[0].y > world.gh * World.TS + 8.0:
			leaves.remove_at(i)
	queue_redraw()
	glow.queue_redraw()


func _draw() -> void:
	var dark := Style.c("violet:2" if grove else "moss:2")
	var lit := Style.c("violet:3" if grove else "moss:3")
	for tf in tufts:
		var p := (tf[0] as Vector2).round()
		var lean := int(tf[1])
		# three blades, the tips shifted by the lean
		draw_rect(Rect2(p + Vector2(-1, -1), Vector2(1, 2)), dark)
		draw_rect(Rect2(p + Vector2(1, -1), Vector2(1, 2)), dark)
		draw_rect(Rect2(p + Vector2(0, -2), Vector2(1, 3)), lit)
		draw_rect(Rect2(p + Vector2(-1 + lean, -2), Vector2.ONE), lit)
		draw_rect(Rect2(p + Vector2(lean, -3), Vector2.ONE), lit)
		draw_rect(Rect2(p + Vector2(1 + lean, -2), Vector2.ONE), dark)
	if grove:
		return   # the Grove's spores glow (drawn on the additive layer)
	for lf in leaves:
		var p := (lf[0] as Vector2).round()
		var flip := sin(lf[2]) > 0.0
		draw_rect(Rect2(p, Vector2(2, 1)), Style.c("leaf:3") if flip else Style.c("sand:3"))
		draw_rect(Rect2(p + Vector2(1 if flip else 0, 1), Vector2.ONE), Style.c("leaf:2") if flip else Style.c("sand:2"))


func _draw_motes() -> void:
	for m in motes:
		var p := (m[0] as Vector2).round()
		var tw := 0.35 + 0.25 * sin(m[1] * 3.0)
		glow.draw_rect(Rect2(p, Vector2.ONE), Color(0.9 * tw, 0.35 * tw, 0.8 * tw) if grove else Color(1.0 * tw, 0.75 * tw, 0.45 * tw))
	if not grove:
		return
	# spores drifting down, pink and faintly lit
	for lf in leaves:
		var p := (lf[0] as Vector2).round()
		var k := 0.5 + 0.3 * sin(lf[2] * 2.0)
		glow.draw_rect(Rect2(p, Vector2.ONE), Color(1.0 * k, 0.35 * k, 0.8 * k))
	# a slow pulse travels along each vein, from its root outward
	for vi in veins.size():
		var line: PackedVector2Array = veins[vi]
		for i in line.size():
			var w := sin(_t * 2.2 - i * 0.18 + vi * 1.7)
			if w <= 0.4:
				continue
			var a := (w - 0.4) / 0.6 * 0.55
			glow.draw_rect(Rect2(line[i], Vector2.ONE), Color(0.95 * a, 0.25 * a, 0.75 * a))
