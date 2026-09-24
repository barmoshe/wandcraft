class_name Controls
extends RefCounted
## What the player wants this tick, from touch sticks, keyboard/mouse, a gamepad or a bot.
## Sources write here; Player reads it. Keeps input handling out of the simulation.

var move := Vector2.ZERO     # left stick, length 0..1
var aim := Vector2.ZERO      # right stick; non-zero means "fire this way"
var fire := false            # fire toward the auto target without aiming
var select_wand := -1        # edge-triggered: Player clears it


func clear() -> void:
	move = Vector2.ZERO
	aim = Vector2.ZERO
	fire = false
	select_wand = -1
