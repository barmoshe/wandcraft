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
## 0.22 feel and accessibility. Shake and flash cycle 100% / 50% / OFF (SCALES).
## shake_scale is what the camera uses: the Shake setting, halved by reduce motion.
var shake_level := 1.0      # settings: screen shake (1.0 / 0.5 / 0.0)
var shake_scale := 1.0      # effective shake (world.shake, the wand kick)
var flash_scale := 1.0      # settings: screen flash intensity (1.0 / 0.5 / 0.0)
var flash_fx := true        # flash_scale > 0 (the shockwave has no half setting)
var haptics := true         # settings: vibration on hits and boss moments
## No camera lead, a steady low-HP tint, half shake. On web it starts on when the
## browser asks for reduced motion.
var reduce_motion := false
## Large text: the messages over play (speech bubbles, tips, toasts, the speech box) draw at 10
## instead of 8 (Hud._msg_px); fixed menu layouts keep their size. text_px is the rule for a string.
var text_big := false
var sound := true
var music := true
var _fonts: Dictionary = {}


func _ready() -> void:
	reduce_motion = _web_reduced_motion()
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
	return scale_for(sz)


## The whole-number pixel scale for a window size: the short side sets it (270 virtual
## pixels tall), but never so big that the long side falls under 480 (0.21: a 4:3 iPad
## rounded 1536 / 270 up to 6 and got a 341 px wide screen, too narrow for the HUD and menus).
static func scale_for(sz: Vector2i) -> float:
	var k := roundf(float(mini(sz.x, sz.y)) / TARGET_HEIGHT)
	k = minf(k, floorf(float(maxi(sz.x, sz.y)) / 480.0))
	return maxf(1.0, k)


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
	return {"auto_fire": auto_fire, "shake": shake_level, "flash": flash_scale, "haptics": haptics,
		"sound": sound, "music": music, "assist": assist, "heartbeat": heartbeat, "voice": voice,
		"reduce_motion": reduce_motion, "text_big": text_big}


## The Duck's and LINT's voices (Voice); the lines still show as text with it off.
var voice := true


## Sound v2: the low-HP heartbeat and the music closing under it (Audio.player_hp). Some players
## find a heartbeat stressful, so it has its own switch.
var heartbeat := true


## 0.22 Assist (replaces Gentle): take 25% or 50% less damage, enemy shots fly slower and
## auto-aim reaches wider. A daily run played with it is marked ASSIST. Never shown as a
## lesser way to play.
const SCALES := [1.0, 0.5, 0.0]
const ASSISTS := [0.0, 0.25, 0.5]
const ASSIST_SHOT := 0.8     # enemy shot speed with assist on
const ASSIST_CONE := 1.5     # auto-aim cone with assist on
var assist := 0.0


## The damage taken is cut by this much (0, 0.25 or 0.5). From settings only: no disk read.
func assist_resist() -> float:
	return assist


func assist_shot_mul() -> float:
	return ASSIST_SHOT if assist > 0.0 else 1.0


func assist_cone_mul() -> float:
	return ASSIST_CONE if assist > 0.0 else 1.0


## The camera's walk lead: none with reduce motion on.
func cam_lead(base: float) -> float:
	return 0.0 if reduce_motion else base


## The draw size of a string: size-8 small text is 10 with large text on, unless the bigger
## string no longer fits `width` (when one is given).
func text_px(size: int, kind := "small", s := "", width := -1.0) -> int:
	if not text_big or size != 8 or kind != "small":
		return size
	if width > 0.0 and s != "" and font(kind).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > width:
		return size
	return 10


## The next step of a cycle (100% > 50% > OFF > 100%, or OFF > 25% > 50% > OFF).
static func next_step(steps: Array, v: float) -> float:
	return steps[(steps.find(_snap(steps, v)) + 1) % steps.size()]


## A saved level as one of `steps`. Saves before 0.22 held a bool: true is the first step
## that is on (100% for shake and flash), false is OFF.
static func _snap(steps: Array, v: Variant) -> float:
	var off: float = steps.min()
	if v is bool:
		return (steps[1] if steps[0] == off else steps[0]) if v else off
	if not (v is float or v is int):
		return steps[0]
	var best: float = steps[0]
	for x in steps:
		if absf(float(v) - x) < absf(float(v) - best):
			best = x
	return best


func apply_settings(d: Dictionary) -> void:
	auto_fire = bool(d.get("auto_fire", auto_fire))
	shake_level = _snap(SCALES, d.get("shake", shake_level))
	flash_scale = _snap(SCALES, d.get("flash", flash_scale))
	flash_fx = flash_scale > 0.0
	haptics = bool(d.get("haptics", haptics))
	sound = bool(d.get("sound", sound))
	music = bool(d.get("music", music))
	# saves before 0.22 had "gentle": on reads as Assist 25%
	assist = _snap(ASSISTS, d["assist"]) if d.has("assist") else (0.25 if bool(d.get("gentle", false)) else 0.0)
	heartbeat = bool(d.get("heartbeat", heartbeat))
	voice = bool(d.get("voice", voice))
	reduce_motion = bool(d.get("reduce_motion", reduce_motion))
	text_big = bool(d.get("text_big", text_big))
	shake_scale = shake_level * (0.5 if reduce_motion else 1.0)
	var au := get_node_or_null("/root/Audio") if is_inside_tree() else null
	if au:
		au.apply(settings())


## Web only: the browser's prefers-reduced-motion. False natively.
func _web_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("window.matchMedia('(prefers-reduced-motion: reduce)').matches", true))


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


## Native phones only: a browser's vibration is one flat buzz with no tiers, and iOS Safari
## has none (the VIBRATION setting is hidden on web).
func buzz(ms: int) -> void:
	if haptics and quiet == 0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
