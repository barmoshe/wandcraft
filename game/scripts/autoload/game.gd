extends Node
## App-level settings and screen fitting. Keeps the pixel buffer at an integer scale of the
## screen: the virtual resolution is screen / k, with k chosen so the height is ~270 px.

const TARGET_HEIGHT := 270.0

var seed_value := 0
var god_mode := false
var inf_mana := false
var auto_fire := true
## > 0 while a sandbox world steps (the editor's firing range, WandSim): no sound, no buzz,
## no tips and no HUD events leak out of it.
var quiet := 0
var shake_scale := 1.0      # settings: screen shake (0 = off)
var flash_fx := true        # settings: screen flash effects
var haptics := true         # settings: vibration on hits and boss moments
var sound := true
var music := true
var _fonts: Dictionary = {}


func _ready() -> void:
	apply_settings(SaveGame.load_settings())
	if DisplayServer.get_name() == "headless":
		return
	get_window().size_changed.connect(fit_pixels)
	fit_pixels()


## The web build does not always report a resize (phone rotation, browser bars sliding),
## so the window size is also checked every frame; refitting only happens on a change.
var _fitted := Vector2i.ZERO


func _process(_dt: float) -> void:
	if DisplayServer.get_name() != "headless" and get_window().size != _fitted:
		fit_pixels()


func fit_pixels() -> void:
	_fitted = get_window().size
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
	# the short side sets the scale, so a phone held upright (web) is not scaled to a speck
	var sz := get_window().size
	return maxf(1.0, roundf(float(mini(sz.x, sz.y)) / TARGET_HEIGHT))


## True on phones and tablets: the native apps, and the web build in a phone's browser.
## D9: a touch has been seen this session (a touch laptop, the tap test): phone controls such
## as the DASH button show from then on.
var touch_seen := false


func is_touch() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")


## The screen area free of notches, the Dynamic Island and the home bar, in virtual pixels.
func safe_rect(view: Vector2) -> Rect2:
	if DisplayServer.get_name() == "headless":
		return Rect2(Vector2.ZERO, view)
	if OS.has_feature("web"):
		var ins := _web_insets()
		var tl := Vector2(ins[3] * view.x, ins[0] * view.y)
		var br := Vector2(ins[1] * view.x, ins[2] * view.y)
		return Rect2(tl, view - tl - br)
	if not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, view)
	var sr := Rect2(DisplayServer.get_display_safe_area())
	var k := pixel_scale()
	return Rect2(sr.position / k, sr.size / k).intersection(Rect2(Vector2.ZERO, view))


## Web build only: the build stamp web/shell.html carries (the git commit, written in by
## tools/build_web.sh), so a phone shows which build it is running. "" natively.
func web_build() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.wandcraftBuild || ''", true))


## Web build only: a one-line sound report (audio state, iOS audio session, the engine's
## audio worklet, the silent-switch unlock), shown on the pause screen. "" natively.
func web_sound() -> String:
	if not OS.has_feature("web"):
		return ""
	return str(JavaScriptBridge.eval("window.wandcraftAudioState ? window.wandcraftAudioState() : ''", true))


## The page's CSS safe-area insets as fractions of the window [top, right, bottom, left],
## from web/shell.html. Re-read only when the window size changes (a rotation moves them).
var _insets: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _insets_for := Vector2i(-1, -1)


func _web_insets() -> Array[float]:
	var sz := get_window().size
	if sz == _insets_for:
		return _insets
	_insets_for = sz
	_insets = [0.0, 0.0, 0.0, 0.0]
	var raw := str(JavaScriptBridge.eval("window.wandcraftSafeArea ? window.wandcraftSafeArea() : ''", true))
	var parts := raw.split(",")
	if parts.size() == 4:
		for i in 4:
			_insets[i] = clampf(parts[i].to_float(), 0.0, 0.25)
	return _insets


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


func settings() -> Dictionary:
	return {"auto_fire": auto_fire, "shake": shake_scale > 0.0, "flash": flash_fx, "haptics": haptics,
		"sound": sound, "music": music}


func apply_settings(d: Dictionary) -> void:
	auto_fire = bool(d.get("auto_fire", auto_fire))
	shake_scale = 1.0 if bool(d.get("shake", true)) else 0.0
	flash_fx = bool(d.get("flash", flash_fx))
	haptics = bool(d.get("haptics", haptics))
	sound = bool(d.get("sound", sound))
	music = bool(d.get("music", music))
	var au := get_node_or_null("/root/Audio")
	if au:
		au.apply(settings())


## A short vibration on phones (hurt, boss moments), if the player allows it.
## D8 haptics map (design-plan §9): only on getting hurt, crits, elite kills, boss moments
## and UI snaps, so a buzz always means something.
const HAPTICS := {"hurt": 40, "crit": 10, "elite_kill": 25, "boss_phase": 80, "boss_kill": 200, "ui_snap": 8, "dash": 8}
var _last_buzz := {}


func haptic(kind: String) -> void:
	# crits can come many per second: at most one crit buzz every 0.25 s
	var now := Time.get_ticks_msec()
	if kind == "crit" and now - int(_last_buzz.get(kind, -9999)) < 250:
		return
	_last_buzz[kind] = now
	buzz(int(HAPTICS.get(kind, 10)))


func buzz(ms: int) -> void:
	if haptics and quiet == 0 and is_touch():
		Input.vibrate_handheld(ms)
