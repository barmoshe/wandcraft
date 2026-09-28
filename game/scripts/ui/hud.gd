class_name Hud
extends Control
## The in-run HUD, drawn directly at the pixel base resolution. Layout:
##   top-left     wand rows: the wand badge, then its slots as round sockets (tap to select)
##                and the WANDS button that opens the editor
##   top-center   the chapter map strip (start, 3 rooms, mini-boss, 3 rooms, boss)
##   top-right    pause, gold, and the relics you carry
##   bottom-left  HP and the selected wand's mana
##   bottom       the boss bar during boss fights
## Everything sits inside the safe area (notch, Dynamic Island, home bar).

const SOCKET := 18    # the 0.4 icons are 18 px; their frame is the socket
const SGAP := 4       # between sockets: room for the cast-direction chevron (design v2)
const BTN := 26.0
const GOLD := Style.UI_GOLD
const INK := Style.INK
const PANEL := Color(0.07, 0.05, 0.13, 0.86)
const RIM := Style.UI_RIM

var world: World
var wand_rows: Array[Rect2] = []
var buttons: Dictionary = {}     # id -> Rect2 (hit area, at least 32 px)
var banner := ""
var banner_sub := ""
var banner_t := 0.0
var toast := ""
var toast_t := 0.0
var boss_title := ""
var hint := ""
var hint_t := 0.0
var _hint_queue: Array[String] = []   # tips wait their turn; each gets its full time
var flash_c := Color.WHITE
var flash_a := 0.0
var fade_a := 0.0     # design v3: a quick fade from black when a room opens
var intro_t := 0.0    # design v3: letterbox bars while a boss makes its entrance
var banner_low := false
## The story: the line being spoken (Dialogue.line_started), in a box at the bottom middle, clear
## of the thumbs. The speaker's face and name: the Duck in gold, LINT in cyan.
var say_text := ""
var say_who := ""
var say_t := 0.0
var say_len := 0.0
var say_id := ""   # 0.24: the line's id, for the Duck's mood (DuckArt.mood_of)
## 0.20 layout: what the HUD already covers this frame. Messages (tips, the spoken line,
## banners, toasts) are placed around it, never over it (tools/uiaudit.sh checks).
var _taken: Array[Rect2] = []
var _eased := {}      # message -> its eased y, so a box glides when a tip pushes it up
var _eased_seen := {}
var _hold_hint := false
var _hold_toast := false
const RELIC_ROW := 6     # relics shown by the gold; more fold into a "+N" (the pause menu lists all)
var _map := Rect2()   # the room strip this frame; the first wand's cast icons stop short of it


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Events.room_entered.connect(_on_room)
	Events.toast.connect(func(s: String) -> void:
		toast = s
		toast_t = 2.2 + minf(2.5, s.length() / 40.0))
	Events.room_cleared.connect(func() -> void:
		banner = "ROOM CLEAR"
		banner_sub = ""
		banner_low = false
		banner_t = 1.4)
	Events.hint.connect(func(s: String) -> void: _hint_queue.append(s))
	# 0.22: a line cut short (you walked off, a screen opened, a new run) takes its bubble with it
	Dialogue.line_cut.connect(func() -> void:
		say_t = 0.0
		say_text = "")
	Dialogue.line_started.connect(func(who: String, s: String, id: String, dur: float) -> void:
		say_who = who
		say_id = id
		say_text = s
		say_len = dur
		say_t = dur)
	Events.screen_flash.connect(func(c: Color, a: float) -> void:
		flash_c = c
		flash_a = maxf(flash_a, a))
	Events.boss_started.connect(func(t: String, sub: String) -> void:
		boss_title = t
		banner = t.to_upper()
		banner_sub = sub
		banner_t = 2.2
		banner_low = true
		intro_t = 1.8)
	Events.boss_phase.connect(func(n: int, line: String) -> void:
		banner = "PHASE %d" % n
		banner_sub = line
		banner_t = 1.8
		banner_low = true)


func _on_room(def: Dictionary) -> void:
	fade_a = 1.0
	banner_low = false
	banner = def.get("title", "")
	var no := int(def["no"])
	if def.get("kind", &"") == &"hub":
		banner_sub = "Walk to a station to use it" if Game.is_touch() or Game.touch_seen else "Walk to a station, or click one"
		banner_t = 2.0
		return
	var th := Chapter.threat_of(world.run.room) if world and world.run and def.get("kind", &"") != &"start" else &""
	var tw := Chapter.twist_of(world.run.room) if world and world.run and def.get("kind", &"") == &"fight" else &""
	if def.get("kind", &"") == &"risk":
		banner_sub = Chapter.RISK_ASK
	elif tw != &"":
		banner_sub = String(Chapter.TWISTS[tw])
	elif th != &"":
		banner_sub = String(Chapter.THREATS[th]["ask"])   # design v2: what this room asks for
	elif no == 0 and world and world.run and world.run.daily != "":
		banner_sub = "Daily - " + String(Chapter.daily_rule(world.run.daily)["text"])
	elif no == 0:
		banner_sub = Chapter.area_name(no, _world_no())
	else:
		banner_sub = "%s  -  room %d of %d" % [Chapter.area_name(no, _world_no()), no, Chapter.PLAN.size() - 1]
	banner_t = 2.0


func _world_no() -> int:
	return world.run.world if world and world.run else 0


func _process(dt: float) -> void:
	banner_t = maxf(0.0, banner_t - dt)
	# 0.21 (Bar: "this is overwhelming"): one message at a time. A banner holds the toast; a
	# banner, a spoken line or a toast holds the tip. Held ones wait, their time untouched.
	_hold_toast = banner_t > 0.0 and banner != ""
	_hold_hint = _hold_toast or (say_t > 0.0 and say_text != "") or toast_t > 0.0
	if not _hold_toast:
		toast_t = maxf(0.0, toast_t - dt)
	say_t = maxf(0.0, say_t - dt)
	if not _hold_hint:
		hint_t = maxf(0.0, hint_t - dt)
	if hint_t <= 0.0 and not _hint_queue.is_empty() and not _hold_hint:
		hint = _hint_queue.pop_front()
		Audio.sfx("tip")
		hint_t = 5.0
	flash_a = maxf(0.0, flash_a - dt * 2.5)
	fade_a = maxf(0.0, fade_a - dt * 3.5)
	intro_t = maxf(0.0, intro_t - dt)
	queue_redraw()


func safe() -> Rect2:
	return Game.safe_rect(get_viewport_rect().size).grow(-4.0)


## Index of the wand row under a point, or -1.
func hit_wand(p: Vector2) -> int:
	for i in wand_rows.size():
		if wand_rows[i].grow(2.0).has_point(p):
			return i
	return -1


## Id of the HUD button under a point ("pause", "edit"), or "".
func hit_button(p: Vector2) -> String:
	# 0.22: tap areas are at least 32 px and may overlap; the nearest one to the finger wins
	var best := ""
	var bd := INF
	for id in buttons:
		var r: Rect2 = buttons[id]
		if r.has_point(p):
			var d := r.get_center().distance_squared_to(p)
			if d < bd:
				bd = d
				best = id
	return best


func _draw() -> void:
	if world == null or world.run == null:
		return
	var sr := safe()
	var run := world.run
	buttons.clear()
	_taken.clear()
	UiAudit.begin(self)
	_map = Rect2()
	if world.hub:
		_draw_hub(sr, run)
		_ease_forget()
		return
	_draw_low_hp(run)
	_map = _map_rect(sr, run)
	UiAudit.owner = "wands"
	_draw_wands(sr.position, run)
	UiAudit.owner = "vitals"
	_draw_vitals(Vector2(sr.position.x, sr.end.y), run)
	UiAudit.owner = "top right"
	_draw_top_right(Vector2(sr.end.x, sr.position.y), run)
	if Game.is_touch() or Game.touch_seen:
		UiAudit.owner = "dash"
		_draw_dash(sr)
	UiAudit.owner = "map"
	_draw_map(run)
	if world.boss and not world.boss.dead:
		UiAudit.owner = "boss bar"
		_draw_boss_bar(sr)
	_draw_messages(sr)
	_ease_forget()
	if flash_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(flash_c.r, flash_c.g, flash_c.b, flash_a))
	if intro_t > 0.0:
		# letterbox bars slide in, hold, and slide out
		var v := get_viewport_rect().size
		var k := clampf(minf((1.8 - intro_t) / 0.25, intro_t / 0.3), 0.0, 1.0)
		var bh := roundf(22.0 * k)
		draw_rect(Rect2(0, 0, v.x, bh), Color(0.01, 0.0, 0.03))
		draw_rect(Rect2(0, v.y - bh, v.x, bh), Color(0.01, 0.0, 0.03))
	if fade_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.01, 0.05, fade_a * fade_a))


## A slow red glow at the screen edges when HP is low (a pulse, not a flash).
func _draw_low_hp(run: RunState) -> void:
	var k := run.hp / run.max_hp
	if k >= 0.3 or world.player.dead:
		return
	# 0.22: reduce motion holds it as a steady tint
	var a := (0.3 - k) / 0.3 * (0.22 + (0.0 if Game.reduce_motion else 0.1 * sin(world.time * 3.0)))
	var v := get_viewport_rect().size
	for i in 10:
		var c := Color(0.85, 0.1, 0.2, a * (1.0 - i / 10.0))
		draw_rect(Rect2(0, 0, v.x, 2), c)
		draw_rect(Rect2(i * 2, 0, 2, v.y), c)
		draw_rect(Rect2(v.x - (i + 1) * 2, 0, 2, v.y), c)
		draw_rect(Rect2(0, v.y - (i + 1) * 2, v.x, 2), c)


func _draw_hint(sr: Rect2, bottom: float) -> float:
	var a := clampf(hint_t * 2.0, 0.0, 1.0) * clampf((5.0 - hint_t) * 4.0, 0.0, 1.0)
	var f := Game.font("small")
	var ms := _msg_px()
	var w := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
	var bh := 10.0 + ms
	UiAudit.owner = "hint"
	var r := _place(Rect2(sr.get_center().x - w / 2.0 - 20, bottom - bh, w + 30, bh), true, "hint")
	UiAudit.box(self, r)
	draw_rect(r, Color(0.07, 0.05, 0.13, 0.9 * a))
	draw_rect(r, Color(GOLD.r, GOLD.g, GOLD.b, a), false, 1.0)
	draw_circle(r.position + Vector2(10, bh / 2.0), 5.0, Color(GOLD.r, GOLD.g, GOLD.b, a))
	_text(r.position + Vector2(8, bh / 2.0 + 4), "?", Color(0.1, 0.06, 0.15, a), 8, "bold")
	_text(r.position + Vector2(20, bh / 2.0 + ms / 2.0), hint, Color(1, 0.96, 0.85, a), ms)
	return r.position.y


func _panel(r: Rect2, gold := false) -> void:
	_take(r)
	draw_rect(r, PANEL)
	draw_rect(r, INK, false, 1.0)
	var inner := r.grow(-1.0)
	var lit := Style.c("gold:2") if gold else Style.UI_PANEL_HI.lightened(0.25)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), lit)
	draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), lit.darkened(0.2))
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(inner.size.x, 1)), RIM.darkened(0.3))
	draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1, 0), Vector2(1, inner.size.y)), RIM.darkened(0.3))
	if gold:
		for c in [r.position, Vector2(r.end.x - 2, r.position.y), Vector2(r.position.x, r.end.y - 2), r.end - Vector2(2, 2)]:
			draw_rect(Rect2(c, Vector2(2, 2)), Style.c("gold:3"))


func _text(p: Vector2, s: String, c: Color, size := 8, kind := "small", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := Game.font(kind)
	draw_string_outline(f, p.round(), s, align, width, size, 2, INK)
	draw_string(f, p.round(), s, align, width, size, c)
	_taken.append(UiAudit.text_rect(f, p.round(), s, align, width, size))
	if UiAudit.on:
		UiAudit.text(self, f, p.round(), s, align, width, size)


## A small square HUD button with a glyph; its hit area is padded to 32 px.
func _button(id: String, r: Rect2, ic: Texture2D) -> void:
	_panel(r)
	draw_texture(ic, (r.get_center() - ic.get_size() / 2.0).round())
	var pad := maxf(0.0, (32.0 - r.size.x) / 2.0)
	buttons[id] = r.grow(pad)


func _draw_wands(origin: Vector2, run: RunState) -> void:
	wand_rows.clear()
	var y := origin.y
	var widest := 0.0
	for wi in run.wands.size():
		var w: WandState = run.wands[wi]
		var sel := wi == run.cur
		var n := w.slots.size()
		var nxt := next_slot(w)
		var row := Rect2(origin.x, y, 22 + n * (SOCKET + SGAP) + 3 - SGAP + 1, SOCKET + 7)
		widest = maxf(widest, row.size.x)
		wand_rows.append(row)
		_panel(row, sel)
		var badge := Rect2(row.position + Vector2(3, 3), Vector2(18, SOCKET + 2))
		draw_rect(badge, Color(0.13, 0.09, 0.2) if sel else Color(0.09, 0.07, 0.14))
		# the wand pre-rotated to 45 degrees (never rotated at draw time), its gem in its colour
		var wt: Texture2D = Hero.wand_angles(Hero.gem_ramp(w.def.color))[14]
		draw_texture(wt, (badge.get_center() + Vector2(2, 2) - wt.get_size() / 2.0).round(), Color.WHITE if sel else Color(0.62, 0.6, 0.7))
		_text(badge.position + Vector2(1, 7), str(wi + 1), GOLD if sel else Color(0.55, 0.5, 0.65), 8, "bold")
		for i in n:
			var c := row.position + Vector2(23 + i * (SOCKET + SGAP) + SOCKET / 2.0, 3 + SOCKET / 2.0 + 1)
			# design v2: every slot the last cast read lights up, left to right as it fires
			var lit := w.lit.has(i) and world.time - w.lit_at < 0.16
			if i < n - 1:
				var cc := c + Vector2(SOCKET / 2.0 + SGAP / 2.0, 0)
				var d := -1.0 if w.def.reverse else 1.0
				var ccol := Color(GOLD, 0.7) if sel else Color(0.45, 0.4, 0.55)
				draw_line(cc + Vector2(-1 * d, -2), cc + Vector2(1 * d, 0), ccol, 1.0)
				draw_line(cc + Vector2(1 * d, 0), cc + Vector2(-1 * d, 2), ccol, 1.0)
			var s: Variant = w.slots[i]
			if s == null:
				draw_circle(c, SOCKET / 2.0 - 1.0, INK)
				draw_circle(c, SOCKET / 2.0 - 2.0, Style.c("night:2"))
				draw_arc(c, SOCKET / 2.0 - 2.0, 0.0, TAU, 20, Style.c("night:4"), 1.0)
			else:
				var ic := Icons.spell(Catalog.spell(s["id"]))
				draw_texture(ic, (c - ic.get_size() / 2.0).round(), Color.WHITE if sel else Color(0.7, 0.7, 0.78))
			if lit:
				draw_arc(c, SOCKET / 2.0, 0.0, TAU, 20, Style.c("cyan:4"), 2.0)
			if s != null:
				if int(s["lv"]) > 1:
					_text(c + Vector2(3, 7), "+".repeat(int(s["lv"]) - 1), GOLD, 8)
			if sel and i == nxt and w.rech <= 0.0:
				# the cast pointer: the slot the next press reads first
				draw_arc(c, SOCKET / 2.0 - 1.0, -PI * 0.85, -PI * 0.15, 8, Color(GOLD, 0.8), 1.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-2, 9), c + Vector2(2, 9), c + Vector2(0, 7)]), GOLD)
			if i == n - 1 and w.background() != null:
				# Daemon Rod: the background slot's timer
				draw_arc(c, SOCKET / 2.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - clampf(w.bg_t / SpellRunner.BG_EVERY, 0.0, 1.0)), 16, Style.c("violet:4"), 1.0)
			_rule_mark(w, i, c)
		var strip := Rect2(row.position.x + 23, row.end.y - 3, n * (SOCKET + SGAP) - SGAP, 2)
		draw_rect(strip, Color(0.02, 0.02, 0.06))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(w.mana / w.max_mana(), 0.0, 1.0), 2)), Color("#4aa8ff"))
		if w.mana < 0.0:
			# Virtual Memory: the debt shows in red
			draw_rect(Rect2(strip.position, Vector2(strip.size.x * minf(1.0, -w.mana / w.max_mana()), 2)), Style.c("blood:3"))
		if w.rech > 0.0:
			var k := 1.0 - w.rech / maxf(0.01, w.rech_max)
			draw_rect(Rect2(strip.position, Vector2(strip.size.x * k, 1)), Color("#ffe066"))
		if sel:
			_draw_last_cast(w, row)
		y = row.end.y + 2
	# the editor button sits under the rows, with the bag count
	var er := Rect2(origin.x, y, BTN, BTN)
	_button("edit", er, HudIcons.bag())
	if not run.bag.is_empty():
		if not (world.boss and not world.boss.dead):   # a boss fight keeps the corner quiet
			_text(er.position + Vector2(BTN + 4, 17), "%d in bag" % run.bag.size(), Color(0.75, 0.7, 0.85), 8)


## Design v3: the cast that just went out, as icons beside the wand in hand (boosts, then the
## spell, then what a trigger released), fading over half a second. The program firing,
## visible in combat and not only in the editor.
func _draw_last_cast(w: WandState, row: Rect2) -> void:
	var age := world.time - w.lit_at
	if age > 0.5 or w.lit.is_empty():
		return
	var a := 1.0 - age / 0.5
	var x := row.end.x + 5
	var stop := _map.position.x - 2.0 if _map.has_area() and row.position.y < _map.end.y else INF
	var cy := row.get_center().y
	for i in w.lit:
		if i >= w.slots.size() or w.slots[i] == null:
			continue
		var d := Catalog.spell(w.slots[i]["id"])
		var ic := Icons.spell(d)
		if x + ic.get_width() > stop:
			break
		_take(Rect2(Vector2(x, cy) - Vector2(0, ic.get_height() / 2.0), ic.get_size()), "last cast")
		draw_texture(ic, (Vector2(x, cy) - Vector2(0, ic.get_height() / 2.0)).round(), Color(1, 1, 1, a))
		x += ic.get_width() + 1
		if Screen.fam(d) == Screen.Fam.BOOST or Screen.fam(d) == Screen.Fam.TRIGGER:
			_text(Vector2(x, cy + 3), ">", Color(GOLD.r, GOLD.g, GOLD.b, a), 8)
			x += 6


## The slot the wand reads first on its next cast (skipping empty slots and passives, and
## right to left on a Mirror Rod), or -1.
static func next_slot(w: WandState) -> int:
	var held := w.held()   # 0.20: the wand's own order (Shuffle Play, Palindrome, pages)
	for p in range(w.ptr, w.prog_len()):
		var i := w.slot_at(p)
		var s: Variant = w.slots[i]
		if s != null and not held.has(i) and Catalog.spell(s["id"]).kind != SpellDef.Kind.PASSIVE:
			return i
	return -1


## 0.20 wand rules on a HUD socket: Shuffle Play shows the next order as small numbers, and a
## Double Buffer dims the page that is not playing.
func _rule_mark(w: WandState, i: int, c: Vector2) -> void:
	match w.def.rule:
		&"shuffle":
			var p := w.read_pos(i)
			if p >= 0:
				_text(c + Vector2(-SOCKET / 2.0, -SOCKET / 2.0 + 6), str(p + 1), Style.c("glitch:4"), 8)
		&"pages", &"singleton":
			# the idle page, or a repeat that sits out (0.21 Singleton Wand)
			if w.read_pos(i) < 0:
				draw_circle(c, SOCKET / 2.0, Color(0, 0, 0, 0.55))


func _bar(r: Rect2, k: float, fill: Color, label: String) -> void:
	draw_rect(r, INK)
	draw_rect(r.grow(-1.0), Color(0.06, 0.04, 0.1))
	var inner := r.grow(-1.0)
	var fw := roundf(inner.size.x * clampf(k, 0.0, 1.0))
	draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), fill)
	draw_rect(Rect2(inner.position, Vector2(fw, 1)), fill.lightened(0.35))
	draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(fw, 1)), fill.darkened(0.35))
	if label != "":
		_text(Vector2(r.position.x + 4, r.position.y + r.size.y - 2), label, Color.WHITE, 8)


## D9: the dash button on phones, low on the right above the aim stick's zone; its rim fills
## back up through the cooldown.
func _draw_dash(sr: Rect2) -> void:
	var c := Vector2(sr.end.x - 26, sr.end.y - 74)
	var p := world.player
	var ready := p.dash_cd <= 0.0
	draw_circle(c, 15.0, INK)
	draw_circle(c, 13.0, Style.c("arcane:1") if ready else Style.c("night:2"))
	var k := 1.0 - clampf(p.dash_cd / (Player.DASH_T + Player.DASH_CD), 0.0, 1.0)
	draw_arc(c, 13.0, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Style.c("arcane:4") if ready else Style.c("arcane:2"), 2.0)
	# three chevrons: the dash
	for i in 3:
		var x := c.x - 5 + i * 4
		var col := Style.c("arcane:4") if ready else Style.c("night:4")
		draw_line(Vector2(x, c.y - 4), Vector2(x + 3, c.y), col, 1.0)
		draw_line(Vector2(x + 3, c.y), Vector2(x, c.y + 4), col, 1.0)
	buttons["dash"] = Rect2(c - Vector2(16, 16), Vector2(32, 32))
	_take(Rect2(c - Vector2(15, 15), Vector2(30, 30)))
	# design v2: switching wands sits by the right thumb (the rows are out of reach mid-fight)
	var run := world.run
	if run.wands.size() > 1:
		var sc := c + Vector2(0, -38)
		var nxt: WandState = run.wands[(run.cur + 1) % run.wands.size()]
		draw_circle(sc, 15.0, INK)
		draw_circle(sc, 13.0, Style.c("night:2"))
		draw_arc(sc, 13.0, 0.0, TAU, 24, Style.c("gold:3"), 1.0)
		var wt: Texture2D = Hero.wand_angles(Hero.gem_ramp(nxt.def.color))[14]
		draw_texture(wt, (sc - wt.get_size() / 2.0).round())
		_text(sc + Vector2(5, 11), str((run.cur + 1) % run.wands.size() + 1), GOLD, 8, "bold")
		buttons["swap"] = Rect2(sc - Vector2(16, 16), Vector2(32, 32))
		_take(Rect2(sc - Vector2(15, 15), Vector2(30, 30)))


## The Workshop (0.19): no vitals or map, the Bits in the bank, a MENU that lists every
## station, the wands only at the training ground, and USE in the dash slot when a station
## is in reach (its glyph says which).
func _draw_hub(sr: Rect2, run: RunState) -> void:
	var h := world.hub
	# the Bits, top left
	if h.snap.is_empty():
		h.refresh_snap()
	var bits: int = h.snap["bits"]
	UiAudit.owner = "bits"
	_take(Rect2(sr.position, Vector2(92, 18)))
	draw_rect(Rect2(sr.position, Vector2(92, 18)), Color(0.05, 0.03, 0.1, 0.7))
	draw_texture(Icons.glyph("chip", Color("#7cf0c8")), (sr.position + Vector2(2, 1)).round())
	_text(sr.position + Vector2(20, 13), "%d BITS" % bits, Color("#7cf0c8"), 8, "bold")
	var waiting: int = h.snap["waiting"]
	if waiting > 0:
		_text(sr.position + Vector2(2, 28), "%d bount%s to claim" % [waiting, "y" if waiting == 1 else "ies"], Style.UI_GOOD, 8)
	# MENU, top right
	var mc := Vector2(sr.end.x - 16, sr.position.y + 14)
	UiAudit.owner = "menu"
	_take(Rect2(mc - Vector2(13, 13), Vector2(26, 26)))
	draw_circle(mc, 13.0, INK)
	draw_circle(mc, 11.0, Style.c("night:2"))
	for k in 3:
		draw_rect(Rect2(mc + Vector2(-5, -4 + k * 4), Vector2(10, 1.5)), GOLD)
	buttons["menu"] = Rect2(mc - Vector2(16, 16), Vector2(32, 32))
	if not (Game.is_touch() or Game.touch_seen):
		# 0.25, desktop: the key that opens it
		var ew := Game.font("small").get_string_size("ESC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(mc + Vector2(-ew / 2.0, 24), "ESC", Style.UI_MUTED, 8)
	# the wands, only where they fire
	if h.in_fire_zone(world.player.position):
		UiAudit.owner = "wands"
		_draw_wands(sr.position + Vector2(0, 40), run)
	# USE (or the dash, on touch, when nothing is in reach)
	# 0.25: on desktop the key prompt stands at the station itself (Hub.draw_top), and a click
	# on a station walks you there, so the round USE button is for touch only
	var touchy := Game.is_touch() or Game.touch_seen
	if h.near != "" and touchy:
		var st: Dictionary = Hub.STATIONS[h.near]
		var c := Vector2(sr.end.x - 26, sr.end.y - 74)
		var col := Color(st["color"]) if h.open(h.near) else Color(0.5, 0.45, 0.6)
		UiAudit.owner = "use"
		_take(Rect2(c - Vector2(17, 17), Vector2(34, 34)))
		draw_circle(c, 17.0, INK)
		draw_circle(c, 15.0, Style.c("night:2"))
		draw_arc(c, 15.0, 0.0, TAU, 24, col, 2.0)
		var g := Icons.glyph(st["glyph"], col)
		draw_texture(g, (c - g.get_size() / 2.0).round())
		# 0.21: a resident's button says what it does: talk first, then their service
		var use := h.use_verb()
		var uw := Game.font("bold").get_string_size(use, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(c + Vector2(-roundf(uw / 2.0), 26), use, col, 8, "bold")
		buttons["use"] = Rect2(c - Vector2(18, 18), Vector2(36, 36))
	elif Game.is_touch() or Game.touch_seen:
		UiAudit.owner = "dash"
		_draw_dash(sr)
	_draw_messages(sr)
	if fade_a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.01, 0.05, fade_a * fade_a))


## The Duck's box: its face, its name, the line (wrapped to two lines at most).
func _draw_say(sr: Rect2, cx: float, bottom: float) -> float:
	var a := clampf(say_t * 3.0, 0.0, 1.0) * clampf((say_len - say_t) * 6.0, 0.0, 1.0)
	var lint := say_who == Story.LINT
	var col := Color("#5ce1ff") if lint else Color(1.0, 0.85, 0.3)
	# 0.20: a resident speaks with their own face and colour
	var res := Residents.id_of(say_who)
	if res != &"":
		col = Color(Residents.DEFS[res]["color"])
	var f := Game.font("small")
	var ms := _msg_px()
	var lines := _wrap_lines(f, say_text, minf(250.0, sr.size.x - 150.0), ms)
	var wdt := 0.0
	for ln in lines:
		wdt = maxf(wdt, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x)
	var h := maxf(24.0, lines.size() * (ms + 2.0) + 14.0)
	UiAudit.owner = "say"
	var r := _place(Rect2(cx - (wdt + 34.0) / 2.0, bottom - h, wdt + 34.0, h), true, "say")
	UiAudit.box(self, r)
	draw_rect(r, Color(0.05, 0.03, 0.1, 0.85 * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(col, a))
	# the speaker's mouth moves while the line plays (after its first 0.4 s), and they blink
	var talk := fmod(say_t, 0.24) < 0.12 and say_t < say_len - 0.4
	var blink := fmod(say_t, 3.1) < 0.1
	var face := lint_face() if lint else DuckArt.face(DuckArt.mood_of(say_id), talk, blink)
	if res != &"":
		face = KernelArt.portrait(res, 0, talk, blink)
	draw_texture(face, (r.position + Vector2(5, 4)).round(), Color(1, 1, 1, a))
	_text(r.position + Vector2(26, 10), say_who, Color(col, a), 8)
	for k in lines.size():
		_text(r.position + Vector2(26, 12 + ms + k * (ms + 2.0)), lines[k], Color(0.92, 0.95, 1.0, a), ms)
	return r.position.y


## LINT's face, 12 px: a little monitor with a cyan scanline eye.
static func lint_face() -> Texture2D:
	return PixelArt.cached("lint_face", func() -> Image:
		return PixelArt.paint(PackedStringArray([
			".ssssssssss.",
			"sSSSSSSSSSSs",
			"sSkkkkkkkkSs",
			"sSkkkkkkkkSs",
			"sSkcccccckSs",
			"sSkkkkkkkkSs",
			"sSkkkkkkkkSs",
			"sSSSSSSSSSSs",
			".ssssssssss.",
			"....sSSs....",
			"..ssSSSSss..",
		]), {"s": "steel:2", "S": "steel:3", "k": "night:0", "c": "cyan:4"}))


## The Duck's face, 12x11 (14x13 with its outline): DuckArt, plain, beak shut, eyes open.
static func duck_face() -> Texture2D:
	return DuckArt.face()


## 0.22: the size messages are drawn at: 8, or 10 with the large text setting (only the
## messages, which are placed around the HUD; fixed layouts keep their size).
static func _msg_px() -> int:
	return 10 if Game.text_big else 8


func _wrap_lines(f: Font, s: String, width: float, size := 8) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in s.split(" "):
		var t := word if line == "" else line + " " + word
		if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out


func _draw_vitals(bl: Vector2, run: RunState) -> void:
	var w := run.wand()
	var panel := Rect2(bl.x, bl.y - 30, 128, 30)
	_panel(panel)
	# a heart and a mana drop label the bars (D6 HUD icons)
	var hi := HudIcons.heart()
	var di := HudIcons.drop()
	draw_texture(hi, (panel.position + Vector2(8 - hi.get_width() / 2.0, 9.5 - hi.get_height() / 2.0)).round())
	draw_texture(di, (panel.position + Vector2(8 - di.get_width() / 2.0, 21.5 - di.get_height() / 2.0)).round())
	_bar(Rect2(panel.position + Vector2(15, 4), Vector2(109, 11)), run.hp / run.max_hp, Style.c("blood:2"), "%d/%d" % [roundi(run.hp), roundi(run.max_hp)])
	if world.player.shield > 0.0:
		var sk := world.player.shield / 30.0
		draw_rect(Rect2(panel.position + Vector2(16, 5), Vector2(107 * sk, 2)), Style.c("frost:3"))
	# Virtual Memory: below zero the bar turns red and fills with the debt
	var debt := w.mana < 0.0
	if w.def.rule == &"blood":
		# 0.21 Unsafe Staff: it spends HP, not mana; the bar says so
		_bar(Rect2(panel.position + Vector2(15, 17), Vector2(109, 9)), 1.0, Style.c("blood:2"), "PAYS IN HP")
	else:
		_bar(Rect2(panel.position + Vector2(15, 17), Vector2(109, 9)), (-w.mana if debt else w.mana) / w.max_mana(), Style.c("blood:3") if debt else Style.c("arcane:3"), "%d/%d" % [roundi(w.mana), roundi(w.max_mana())])


func _draw_top_right(tr: Vector2, run: RunState) -> void:
	_button("pause", Rect2(tr.x - BTN, tr.y, BTN, BTN), HudIcons.pause())
	var gr := Rect2(tr.x - BTN - 62, tr.y, 58, BTN)
	_panel(gr)
	var coin := HudIcons.coin()
	draw_texture(coin, (gr.position + Vector2(4, (BTN - coin.get_height()) / 2.0)).round())
	_text(gr.position + Vector2(20, 17), str(run.gold), GOLD, 8, "bold")
	# relics, a compact column under the gold
	var shown := run.relics.size() if run.relics.size() <= RELIC_ROW else RELIC_ROW - 1
	if shown < run.relics.size():
		# the rest fold into a "+N" cell; tapping it opens the pause menu, which lists them all
		var mp := Vector2(tr.x - 9 - shown * 19, tr.y + BTN + 12)
		_take(Rect2(mp - Vector2(9, 9), Vector2(18, 18)), "relics")
		draw_rect(Rect2(mp - Vector2(8, 7), Vector2(16, 14)), Color(0.07, 0.05, 0.13, 0.85))
		var more := "+%d" % (run.relics.size() - shown)
		var mw := Game.font("bold").get_string_size(more, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var was := UiAudit.owner
		UiAudit.owner = "relics"
		_text(mp + Vector2(-roundf(mw / 2.0), 3), more, GOLD, 8, "bold")
		UiAudit.owner = was
		buttons["relics_more"] = Rect2(mp - Vector2(16, 16), Vector2(32, 32))
	for i in shown:
		var p := Vector2(tr.x - 9 - i * 19, tr.y + BTN + 12)
		var ic := Icons.relic(run.relics[i])
		_take(Rect2(p - Vector2(9, 9), Vector2(18, 18)), "relics")
		draw_texture(ic, (p - ic.get_size() / 2.0).round())
		buttons["relic%d" % i] = Rect2(p - Vector2(16, 16), Vector2(32, 32))   # design v2: tap to read (0.22: a 32 px target)
		# counter pips (D3): a count, or a lit dot when the relic is ready right now
		var pip := relic_pip(run.relics[i])
		if pip.is_empty():
			continue
		var at := p + Vector2(5, 5)
		if pip[0] != "":
			# a 3x5 counter tucked into the icon's bottom-right corner, inside its own cell
			var dw := HudIcons.digits_width(pip[0])
			HudIcons.draw_digits(self, (p + Vector2(6 - dw, 2)).round(), pip[0], GOLD if pip[1] else Color(0.75, 0.7, 0.85))
		else:
			draw_circle(at, 2.5, INK)
			draw_circle(at, 1.5, Style.c("leaf:4") if pip[1] else Style.c("night:4"))


## [label, lit] for a relic's HUD pip, or [] when it has none. Counters show how many
## casts are left (lit on the last one); the rest show a dot, lit while they are active.
func relic_pip(id: StringName) -> Array:
	var run := world.run
	var fired := world.spells.casts_fired
	var tick := Relics.cast_tick(run)   # 0.20: Double Tick counts each cast twice
	match id:
		&"stack_trace":
			var left := ceili((7 - fired % 7) / float(tick))
			return [str(left), left == 1]
		&"loop_counter":
			var left2 := ceili((10 - fired % 10) / float(tick))
			return [str(left2), left2 == 1]
		&"uptime":
			return [str(run.uptime), run.uptime > 0] if run.uptime > 0 else []
		&"try_catch":
			return ["", not world.caught]
		&"cold_start":
			return ["", run.wand().fresh]
		&"low_battery":
			return ["", run.wand().mana < run.wand().max_mana() * 0.25]
		&"cornered":
			return ["", world.cornered()]
		&"deadline":
			return ["", world.room_time < 6.0 and not world.cleared]
		&"busy_wait":
			return ["", world.player.still_t >= 0.6]
		# 0.20
		&"graceful_degrade":
			return ["", run.wands.any(func(w: WandState) -> bool: return w.suspended >= 0)]
		&"swap_space":
			return ["", world.puddle_slow(world.player.position) > 1.0]
		&"undo_stack":
			return ["", world.player.undo_t > 0.0]
		&"warm_cache":
			var wm := mini(world.warm, Relics.WARM_MAX)
			return [str(wm), wm >= Relics.WARM_MAX] if wm > 0 else []
		&"polyglot":
			var kn := Relics.kinds(run.wand())
			return [str(kn), kn >= 4]
		&"short_circuit":
			return ["", run.wand().slots.size() <= 3]
		&"context_switch":
			return ["", world.player.swap_cd <= 0.0]
		# 0.21
		&"clean_build":
			return [str(run.clean), run.clean >= Relics.CLEAN_MAX] if run.clean > 0 else []
		&"code_coverage":
			return [str(run.cover), run.cover >= Relics.COVER_MAX] if run.cover > 0 else []
		&"git_clone":
			var left3 := maxi(0, Relics.CLONE_ROOMS - int(run.stats.get("clone_rooms", 0)))
			return [str(left3), left3 <= 1]
		&"hive_mind":
			return ["", world.time - world.spells.relic_fx.volley_at >= RelicFx.VOLLEY_CD]
		&"risky_code":
			var un := 0
			for sl in run.wand().slots:
				if sl != null and Relics.unsafe(sl["id"]):
					un += 1
			return [str(un), un > 0] if un > 0 else []
	return []


## The room strip's rect: top middle, but right of the first wand row and left of the gold
## when they would touch (a long wand on a narrow 4:3 screen), with tighter dots if it must.
func _map_rect(sr: Rect2, run: RunState) -> Rect2:
	var n := Chapter.PLAN.size()
	var w0: WandState = run.wands[0]
	var left := sr.position.x + 22 + w0.slots.size() * (SOCKET + SGAP) + 4 - SGAP + 4
	var right := sr.end.x - BTN - 62 - 4
	var gap := 13.0
	while gap > 9.0 and (n - 1) * gap + 32 > right - left:
		gap -= 1.0
	var w := (n - 1) * gap + 32
	var cx := clampf(sr.get_center().x, left + w / 2.0, maxf(left + w / 2.0, right - w / 2.0))
	return Rect2(roundf(cx - w / 2.0), sr.position.y + 1, w, 14)


func _draw_map(run: RunState) -> void:
	var n := Chapter.PLAN.size()
	var gap := (_map.size.x - 32) / maxf(1.0, n - 1)
	var x0 := _map.position.x + 24
	var y := _map.position.y + 7
	_take(_map)
	draw_rect(_map, Color(0.05, 0.03, 0.1, 0.6))
	# which world you're in, before its rooms (research/story.md: the switch is always clear)
	_text(Vector2(x0 - 21, y + 3), "W%d" % (run.world + 1), [Color(0.75, 0.7, 0.85), Color("#ff9a3a"), Color("#c79bff")][clampi(run.world, 0, 2)], 8, "bold")
	buttons["map"] = Rect2(x0 - 10, y - 16, (n - 1) * gap + 20, 32)   # tap the strip for the map
	for i in n:
		var p := Vector2(x0 + i * gap, y)
		if i > 0:
			draw_rect(Rect2(p - Vector2(gap - 3, 0), Vector2(gap - 6, 1)), Color(0.45, 0.4, 0.55) if i <= run.step else Color(0.25, 0.22, 0.32))
		var plan: StringName = Chapter.PLAN[i]
		var done := i < run.step
		var here := i == run.step
		var c := Color("#ff3fa4") if plan == &"mini" or plan == &"boss" else (GOLD if here else Color(0.6, 0.55, 0.7))
		var rad := 4.0 if plan == &"boss" else 3.0
		if here:
			draw_circle(p, rad + 2.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 + 0.2 * sin(world.time * 5.0)))
		if done or here:
			draw_circle(p, rad, c)
		else:
			draw_arc(p, rad, 0.0, TAU, 12, c, 1.0)


func _draw_boss_bar(sr: Rect2) -> void:
	var b := world.boss
	# clear of the vitals panel (128 px) on the left, and as far from the right edge
	var w := minf(220.0, sr.size.x - 2.0 * 136.0)
	var r := Rect2(sr.get_center().x - w / 2.0, sr.end.y - 16, w, 9)
	_take(r)
	_text(Vector2(r.position.x, r.position.y - 2), boss_title, Color("#ff8ab8"), 8, "bold")
	_bar(r, b.hp / b.max_hp, Color("#ff3fa4"), "")
	for ph in b.phases:
		var at := float(ph["at"])
		if at < 1.0:
			draw_rect(Rect2(r.position.x + r.size.x * at, r.position.y, 1, r.size.y), INK)


## Tips, the spoken line, banners and toasts (0.20 layout), placed around what the HUD already
## covers this frame (_taken) so nothing lands on anything: the bottom ones stack up from
## above the vitals and the boss bar (the tip lowest, then the line, then a boss banner),
## the top ones stack down from under the map, clear of the wand rows and the relics.
func _draw_messages(sr: Rect2) -> void:
	var cx := sr.get_center().x
	var bottom := sr.end.y - 32.0
	if hint_t > 0.0 and hint != "" and not _hold_hint:
		bottom = _draw_hint(sr, bottom) - 3.0
	# 0.21: a speaker with a body here talks in a bubble over their head (drawn last, around
	# everything else); one without (a voice over a story beat) keeps the box
	var speaker := Vector2.INF
	if say_t > 0.0 and say_text != "":
		speaker = Bubbles.anchor(world, say_who)
		if speaker == Vector2.INF:
			bottom = _draw_say(sr, cx, bottom) - 3.0
	if banner_t > 0.0 and banner != "":
		_draw_banner(sr, cx, bottom)
	if toast_t > 0.0 and toast != "" and not _hold_toast:
		_draw_toast(sr, cx)
	if speaker != Vector2.INF:
		_draw_bubble(sr, speaker)


## The room and boss banners: boss and phase banners sit low, over the boss bar, so the
## boss's entrance stays in view; the others under the map.
func _draw_banner(sr: Rect2, cx: float, bottom: float) -> void:
	var a := clampf(banner_t * 2.0, 0.0, 1.0)
	var f := Game.font("body")
	var bw := f.get_string_size(banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var wdt := bw
	var h := 30.0 if banner_sub != "" else 20.0
	if banner_sub != "":
		wdt = maxf(wdt, Game.font("small").get_string_size(banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	UiAudit.owner = "banner"
	var top := sr.position.y + (2.0 if world and world.hub else 26.0)   # 0.25: the Workshop's banner clears the room
	var r := _place(Rect2(cx - wdt / 2.0 - 12, (bottom - h) if banner_low else top, wdt + 24, h), banner_low, "banner")
	UiAudit.box(self, r)
	var at := Vector2(cx - bw / 2.0, r.position.y + 15).round()
	UiAudit.text(self, f, at, banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_rect(r, Color(0.05, 0.03, 0.1, 0.75 * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, a))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(GOLD.r, GOLD.g, GOLD.b, a))
	draw_string_outline(f, at, banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 3, Color(0, 0, 0, a))
	draw_string(f, at, banner, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.8, a))
	if banner_sub != "":
		var sw := Game.font("small").get_string_size(banner_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		_text(Vector2(cx - sw / 2.0, r.position.y + 26), banner_sub, Color(0.75, 0.7, 0.85, a), 8)


## A toast (goals, relic taps): wrapped on a panel, under the top banner.
func _draw_toast(sr: Rect2, cx: float) -> void:
	var a := clampf(toast_t * 2.0, 0.0, 1.0)
	var f := Game.font("small")
	var ms := _msg_px()
	var lines := _wrap_lines(f, toast, minf(320.0, sr.size.x - 40.0), ms)
	var wdt := 0.0
	for ln in lines:
		wdt = maxf(wdt, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x)
	UiAudit.owner = "toast"
	var tr := _place(Rect2(cx - wdt / 2.0 - 8, sr.position.y + 26, wdt + 16, lines.size() * (ms + 2.0) + 8), false, "toast")
	UiAudit.box(self, tr)
	draw_rect(tr, Color(0.07, 0.05, 0.13, 0.85 * a))
	for k in lines.size():
		var lw := f.get_string_size(lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x
		_text(Vector2(cx - lw / 2.0, tr.position.y + 4 + ms + k * (ms + 2.0)), lines[k], Color(0.9, 0.95, 1.0, a), ms)


## The speech bubble (0.21): the speaker's name in their colour, the line typed out, a tail
## down to their head; pinned at the screen's edge with an arrow when they are off screen.
func _draw_bubble(sr: Rect2, at: Vector2) -> void:
	var el := say_len - say_t
	var al := Bubbles.alpha(el, say_len)
	var f := Game.font("small")
	var ms := _msg_px()
	var lh := ms + 2.0
	var lines := Bubbles.lines_for(f, say_text, 3 if world.hub else 2, ms)
	var wdt := f.get_string_size(say_who, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4.0
	var total := 0
	for ln in lines:
		wdt = maxf(wdt, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, ms).x)
		total += ln.length()
	var size := Vector2(roundf(wdt) + Bubbles.PAD.x * 2.0, 15.0 + lines.size() * lh)
	var ct := get_viewport().get_canvas_transform()
	var hero := ct * world.player.position
	# the hero is never under a bubble (nor are the HUD's panels)
	var keep: Array = _taken.duplicate()
	keep.append(Rect2(hero + Vector2(-9, -36), Vector2(18, 38)))
	if world.hub:
		# 0.25: nor are the Workshop's station names
		for lr in world.hub.label_rects():
			var q: Rect2 = lr
			keep.append(Rect2(ct * q.position, ct.basis_xform(q.size)))
	var lay := Bubbles.layout(ct * at, size, sr, keep, hero)
	var r: Rect2 = lay["rect"]
	var col := Bubbles.color_of(say_who)
	UiAudit.owner = "bubble"
	_take(r)
	# see-through in a fight (the room stays readable under it), solid in the Workshop
	var body := Color(Style.c("night:1"), (0.92 if world.hub else 0.78) * al)
	draw_rect(r, body)
	draw_rect(r, Color(col, al), false, 1.0)
	var tx: float = lay["tail_x"]
	if lay["pinned"]:
		# an arrow on the side toward the speaker
		var d: Vector2 = lay["arrow"]
		for k in 3:
			var w := 5.0 - k * 2.0
			if absf(d.x) > absf(d.y):
				var x := (r.end.x + k) if d.x > 0.0 else (r.position.x - 1.0 - k)
				draw_rect(Rect2(x, r.get_center().y - w / 2.0, 1, w).abs(), Color(col, al))
			else:
				var y := (r.end.y + k) if d.y > 0.0 else (r.position.y - 1.0 - k)
				draw_rect(Rect2(clampf(tx, r.position.x + 4, r.end.x - 4) - w / 2.0, y, w, 1), Color(col, al))
	else:
		for k in 3:
			var w := 5.0 - k * 2.0
			var y := (r.position.y - 1.0 - k) if lay["tail_up"] else (r.end.y + k)
			draw_rect(Rect2(tx - floorf(w / 2.0), y, w, 1), Color(col, al))
	_text(r.position + Vector2(Bubbles.PAD.x, 11), say_who, Color(col, al), 8, "bold")
	var left := Bubbles.shown_chars(el, total, say_len)
	for k in lines.size():
		if left <= 0:
			break
		var ln: String = lines[k].substr(0, left)
		left -= lines[k].length()
		_text(r.position + Vector2(Bubbles.PAD.x, 11 + (k + 1) * lh), ln, Color(0.94, 0.95, 1.0, al), ms)


## Moves a message's rect off everything taken this frame (up for the bottom stack, down for
## the top one), eases it there when it moves, and takes it.
func _place(r: Rect2, up: bool, key: String) -> Rect2:
	for _i in 24:
		var moved := false
		for t in _taken:
			if t.intersects(r.grow(1.0)):
				r.position.y = (t.position.y - 2.0 - r.size.y) if up else (t.end.y + 2.0)
				moved = true
				break
		if not moved:
			break
	r.position.y = _ease(key, r.position.y)
	_taken.append(r)
	return r


## A message glides to a new y (a tip pushing the spoken line up) instead of jumping; one
## that just appeared starts where it belongs.
func _ease(key: String, y: float) -> float:
	_eased_seen[key] = true
	if not _eased.has(key):
		_eased[key] = y
		return y
	var cur: float = _eased[key]
	cur = lerpf(cur, y, 1.0 - exp(-get_process_delta_time() * 14.0))
	if absf(cur - y) < 0.5:
		cur = y
	_eased[key] = cur
	return roundf(cur)


func _ease_forget() -> void:
	for k in _eased.keys():
		if not _eased_seen.has(k):
			_eased.erase(k)
	_eased_seen.clear()


## Marks a HUD element's rect as covered, for the messages' layout and the overlap audit.
func _take(r: Rect2, who := "") -> void:
	_taken.append(r)
	UiAudit.box(self, r, who)
