extends Node
## App-level settings and screen fitting. Keeps the pixel buffer at an integer scale of the
## screen: the virtual resolution is screen / k, with k chosen so the height is ~270 px.

const TARGET_HEIGHT := 270.0

var seed_value := 0
var god_mode := false
var inf_mana := false
var auto_fire := true
var _fonts: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	get_window().size_changed.connect(fit_pixels)
	fit_pixels()


func fit_pixels() -> void:
	var win := get_window()
	var size := Vector2(win.size)
	if size.y <= 0.0:
		return
	var k := pixel_scale()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	win.content_scale_size = Vector2i(ceili(size.x / k), ceili(size.y / k))


func pixel_scale() -> float:
	if DisplayServer.get_name() == "headless":
		return 1.0
	return maxf(1.0, roundf(float(get_window().size.y) / TARGET_HEIGHT))


## The screen area free of notches, the Dynamic Island and the home bar, in virtual pixels.
func safe_rect(view: Vector2) -> Rect2:
	if DisplayServer.get_name() == "headless" or not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, view)
	var sr := Rect2(DisplayServer.get_display_safe_area())
	var k := pixel_scale()
	return Rect2(sr.position / k, sr.size / k).intersection(Rect2(Vector2.ZERO, view))


## Pixel fonts (SIL OFL, see assets/fonts). "small" = Silkscreen (8 px grid),
## "body" = Pixelify Sans. Crisp: no antialiasing, no subpixel positioning.
func font(kind := "small") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var path: String = {
		"small": "res://assets/fonts/Silkscreen-Regular.ttf",
		"bold": "res://assets/fonts/Silkscreen-Bold.ttf",
		"body": "res://assets/fonts/PixelifySans.ttf",
	}.get(kind, "")
	var f: Font = ThemeDB.fallback_font
	if path != "" and ResourceLoader.exists(path):
		var ff := load(path) as FontFile
		if ff:
			ff = ff.duplicate() as FontFile
			ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			ff.hinting = TextServer.HINTING_NONE
			ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			ff.force_autohinter = false
			f = ff
	_fonts[kind] = f
	return f
