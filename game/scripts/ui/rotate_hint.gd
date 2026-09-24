class_name RotateHint
extends Control
## Web build on a phone held upright: the game is landscape-only and a web page cannot lock
## the orientation, so this covers the screen and asks to turn the phone. Native builds
## lock landscape in the export presets and never show it.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_dt: float) -> void:
	var v := get_viewport_rect().size
	visible = v.y > v.x
	if visible:
		queue_redraw()


func _draw() -> void:
	var v := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, v), Style.c("night:1"))
	var c := v / 2.0
	# a phone outline tipping over to landscape
	var t := fmod(Time.get_ticks_msec() / 1000.0, 2.0)
	var a := clampf((t - 0.5) / 0.8, 0.0, 1.0) * -PI / 2.0
	draw_set_transform(c + Vector2(0, -24), a, Vector2.ONE)
	draw_rect(Rect2(-12, -22, 24, 44), Style.c("gold:3"), false, 2.0)
	draw_rect(Rect2(-3, 17, 6, 2), Style.c("gold:3"))
	draw_set_transform(Vector2.ZERO)
	var f := Game.font("bold")
	for i in 2:
		var s: String = ["TURN YOUR PHONE", "SIDEWAYS TO PLAY"][i]
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(f, (c + Vector2(-w / 2.0, 22 + i * 12)).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Style.UI_TEXT)
