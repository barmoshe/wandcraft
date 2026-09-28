class_name Companion
extends Node2D
## 0.21: the Duck and LINT walk the runs with you (Bar: "the NPCs need to be in the world and
## not in the HUD"). The Duck waddles beside the hero on the ground; LINT hovers behind as a
## little monitor drone. They are only looks: never in `world.enemies` or the spatial hash,
## so shots pass through them and nothing hits them. Their lines show in a bubble over their
## own heads (Bubbles.anchor). In the Workshop the fixed Duck and LINT stand in instead.

const FOLLOW := 0.85        # per 60 Hz frame, the part of the gap kept (eases in ~0.3 s)
const LEASH := 40.0         # never further than this from the hero
const HOVER := 24.0         # LINT floats this high, beside the hero's head, not on it
const GAP := 15.0           # how far to the hero's side they keep

var kind := &"duck"
var world: World
var prev_pos := Vector2.ZERO
var face := 1.0
var _t := 0.0
var _sprite: Sprite2D


func setup(w: World, k: StringName) -> void:
	world = w
	kind = k
	_sprite = Sprite2D.new()
	_sprite.centered = true
	add_child(_sprite)
	_redraw(false)


## Who this companion speaks as (Story.DUCK / Story.LINT).
func who() -> String:
	return Story.DUCK if kind == &"duck" else Story.LINT


## The point over its head, in world coordinates, between physics ticks (for the bubble).
func head() -> Vector2:
	var p := prev_pos.lerp(position, Engine.get_physics_interpolation_fraction())
	return p + (Vector2(0, -16) if kind == &"duck" else Vector2(0, -HOVER - 9))


## Straight to the hero's side (a new room, a door).
func snap() -> void:
	position = _target()
	if world.body_solid_at(position):
		position = world.player.position
	prev_pos = position
	reset_physics_interpolation()


func _target(flip := false) -> Vector2:
	var p := world.player
	var side := -1.0 if cos(p.aim) >= 0.0 else 1.0     # the side away from where you aim
	if flip:
		side = -side
	if kind == &"duck":
		return p.position + Vector2(side * GAP, 2.0)
	return p.position + Vector2(side * (GAP + 6.0), -4.0)


func tick(dt: float) -> void:
	prev_pos = position
	_t += dt
	# its side of the hero, else the other side, else just behind them (below on screen),
	# else it stays where it is: never on top of the hero
	var want := _target()
	for cand in [_target(true), world.player.position + Vector2(0, 10), position]:
		if not _blocked(want):
			break
		want = cand
	position = position.lerp(want, 1.0 - pow(FOLLOW, dt * 60.0))
	var off := position - world.player.position
	if off.length() > LEASH:
		position = world.player.position + off.normalized() * LEASH
	var dx := world.player.position.x + cos(world.player.aim) * 20.0 - position.x
	if absf(dx) > 2.0:
		face = signf(dx)
	_redraw(Dialogue.current.get("who", "") == who())


func _blocked(p: Vector2) -> bool:
	return world.body_solid_at(p) if kind == &"duck" else world.solid_at(p)


func _redraw(talking: bool) -> void:
	var moving := position.distance_to(prev_pos) > 0.15
	var frame := int(_t * 8.0) % 2 if moving else 0
	if kind == &"duck":
		_sprite.texture = CompanionArt.duck(frame, talking and fmod(_t, 0.24) < 0.12)
		# an idle hop every 1.6 s; a waddle while walking
		var hop := 0.0
		if not moving and fmod(_t, 1.6) < 0.2:
			hop = sin(fmod(_t, 1.6) / 0.2 * PI) * 2.0
		if moving:
			hop = float(frame)   # a one-pixel waddle (never rotated: pixel art stays whole)
		_sprite.position = Vector2(0, -6.5 - hop).round()
	else:
		_sprite.texture = CompanionArt.lint(int(_t * 3.0) % 2, talking)
		_sprite.position = Vector2(0, -HOVER + sin(_t * 2.6) * 1.5).round()
	_sprite.flip_h = face < 0.0
