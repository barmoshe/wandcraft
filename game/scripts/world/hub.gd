class_name Hub
extends RefCounted
## The Workshop (0.19, research/workshop-0.19.md): the Guild's workshop inside the Source, a
## one-screen room you walk around between runs. Every pre-run action is a station in it:
## walk up to one and a USE button opens it (main.gd `_hub_use`). Only the portal opens by
## walking in, like the doors in a run. The room plays on a sandbox run: never saved, and it
## counts for nothing (no Bits, no bounties, no Compendium).
##
## One screen at every aspect (18 x 11 tiles is 288 x 176 px, inside 360 x 270 with the
## camera's pads) and about 2.7 s to cross, so the hub is never a walk you pay for.

const TS := 16
## Markers (anything the room builder does not know is floor): H hero pedestals, R the
## portal, U the training dummy, B the wand bench, Q the bounty board, M the merchant,
## C the Compendium, W the Commit Wall, K the Terminal, D the Duck, N LINT. 0.25: the Duck and
## LINT stand by the way in, below the open floor, so their bubbles rise over empty floor and
## not over a station's name.
## 0.20: the residents' corners (empty until they move in): G Grep, F Hotfix, A Cache.
const ROWS := [
	"##################",
	"#L........R...U.L#",
	"#..H.H.H......B..#",
	"#Q..............M#",
	"#..G..........F..#",
	"#C...............#",
	"#................#",
	"#W.A...D..N.....K#",
	"#................#",
	"#L..............L#",
	"##################",
]
## The training ground (tiles): the only place in the hub the wand fires.
const FIRE_ZONE := Rect2(11 * TS, 0, 7 * TS, 4 * TS)
const USE_R := 22.0
const PORTAL_R := 12.0
const DPS_WINDOW := 3.0
const BENCH_WAND := &"oak"

## Stations: the marker, a name, one line, the USE button's glyph and colour, and "runs",
## the finished runs that open it ("locked" says so until then).
const STATIONS := {
	"portal": {"mark": "R", "title": "PORTAL", "sub": "Start a run", "glyph": "spiral", "color": "#ffe066"},
	"heroes": {"mark": "H", "title": "HERO HALL", "sub": "Choose your hero", "glyph": "wand", "color": "#ffd05e"},
	"repl": {"mark": "B", "title": "WAND BENCH", "sub": "Build a wand, try it on the dummy", "glyph": "anvil", "color": "#5ce1ff",
		"runs": 2, "locked": "Opens after your second run"},
	"pkg": {"mark": "M", "title": "MERCHANT", "sub": "Spell packs for Bits", "glyph": "bag", "color": "#ffc94a",
		"runs": 1, "locked": "Opens after your first run"},
	"bounty": {"mark": "Q", "title": "BUG BOUNTY BOARD", "sub": "Fix bugs, claim Bits", "glyph": "skull", "color": "#ff7b7b"},
	"docs": {"mark": "C", "title": "COMPENDIUM", "sub": "Everything you have met", "glyph": "stack", "color": "#9fe8ff"},
	"log": {"mark": "W", "title": "COMMIT WALL", "sub": "Your runs, as commits", "glyph": "loop", "color": "#72e06a"},
	"terminal": {"mark": "K", "title": "TERMINAL", "sub": "Settings and credits", "glyph": "chip", "color": "#5ce1ff"},
	"duck": {"mark": "D", "title": "DUCK", "sub": "Talk", "glyph": "heart", "color": "#ffe066"},
	"lint": {"mark": "N", "title": "LINT", "sub": "Talk", "glyph": "eye", "color": "#5ce1ff"},
	# 0.20: the residents (Residents), each in the room only once rescued
	"grep": {"mark": "G", "title": "GREP", "sub": "Talk, and Search: one true hint a run", "glyph": "eye", "color": "#e8d9b4", "resident": true},
	"hotfix": {"mark": "F", "title": "HOTFIX", "sub": "Talk, and the Skin Forge", "glyph": "anvil", "color": "#ff9a3a", "resident": true},
	"cache": {"mark": "A", "title": "CACHE", "sub": "Talk, and the Lost Pages", "glyph": "stack", "color": "#b98cff", "resident": true},
}
## The small names always shown under the stations.
const SHORT := {"portal": "RUN", "repl": "BENCH", "pkg": "SHOP", "bounty": "BOUNTIES", "docs": "BOOKS", "log": "COMMITS", "terminal": "TERMINAL"}
## The heroes on the pedestals, left to right.
const HEROES: Array[StringName] = [&"apprentice", &"pyromancer", &"tinkerer"]
## Trophies by the portal: a bounty fixed puts that boss on a plinth (the hub grows with you).
const TROPHIES := [
	{"bounty": "mini", "title": "Mini-boss", "color": "#ff3fa4", "glyph": "ghost"},
	{"bounty": "world1", "title": "The Infinite Loop", "color": "#5ce1ff", "glyph": "loop"},
	{"bounty": "world2", "title": "Deadlock", "color": "#ff9a3a", "glyph": "shield"},
	{"bounty": "win", "title": "The Glitch", "color": "#ff6fd2", "glyph": "ghost"},
]

var world: World
var anchors := {}            # station id -> Array[Vector2] (pixel centres)
var near := ""               # the station in reach ("" for none)
## 0.25, desktop: the station under the mouse ("" for none); main.gd walks you to it on a click
var hover := ""
var hover_k := 0
var near_arg := -1           # which pedestal, for the Hero Hall
## 0.21: the resident you just talked to (USE again opens their service); cleared, and the
## rest of their talk dropped, when you walk away.
var talked: StringName = &""
var talk_last := ""     # the last line id of the talk just started (main.gd)
var talk_arc := false   # ... and whether it was a story beat
## 0.22: what the Workshop draws from the save (Bits, the board, trophies, locked heroes),
## read twice a second instead of from meta.json every frame.
var snap := {}
var _snap_t := 0.0


func refresh_snap() -> void:
	var locked := {}
	for id in HEROES:
		locked[id] = Meta.is_locked(id)
	snap = {"bits": Meta.bits(), "done": Meta.bounties_done(), "board": Meta.board().size(),
		"waiting": Meta.unclaimed().size(), "locked": locked}
	_snap_t = 0.5
var dummy: Enemy
var dps := 0.0
var _armed := true           # the portal re-arms once you step away
var _hits: Array = []        # [time, damage] for the DPS window
var _last_dmg := 0.0
var _last_hit := -99.0
var _runs := 0
var news := {}               # 0.20: resident id -> a new beat is ready (read once, not per frame)


func _init(w: World) -> void:
	world = w


## The Workshop's run: the chosen hero, never saved, with the bench wand when one is kept.
static func make_run(meta: Dictionary) -> RunState:
	var r := RunState.create(1, next_hero(meta))
	r.sandbox = true
	r.picked = true
	r.max_hp = 9999.0
	r.hp = r.max_hp
	r.doors = []
	# the bench's second wand: room to build a longer program than a hero starts with
	r.add_wand(BENCH_WAND)
	var kept: Array = meta.get("bench", {}).get("wands", [])
	for i in mini(kept.size(), r.wands.size()):
		var b: Dictionary = kept[i]
		if not Catalog.wands().has(StringName(b.get("wand", ""))):
			continue
		var w := WandState.make(Catalog.wand(StringName(b["wand"])))
		w.set_slots((b.get("slots", []) as Array).map(func(e: Variant) -> Variant:
			return {"id": StringName(e["id"]), "lv": int(e["lv"])} if e is Dictionary and Catalog.spells().has(StringName(e["id"])) and not Meta.is_locked(StringName(e["id"])) else null))
		r.wands[i] = w
	return r


## The bench's wands as meta keeps them.
static func bench_of(r: RunState) -> Dictionary:
	return {"wands": r.wands.map(func(w: WandState) -> Dictionary:
		return {"wand": String(w.def.id), "slots": w.slots.map(func(x: Variant) -> Variant:
			return {"id": String(x["id"]), "lv": int(x["lv"])} if x != null else null)})}


## The hero for the next run: the one chosen at the Hero Hall, if it is open.
static func next_hero(meta: Dictionary) -> StringName:
	var h := StringName(meta.get("hero", "apprentice"))
	if not RunState.LOADOUTS.has(h) or Meta.is_locked(h):
		return &"apprentice"
	return h


## Every spell a player has open, once each at level 1, for the wand bench's library.
static func library() -> Array:
	var out: Array = []
	for id in Catalog.spells():
		if not Catalog.is_evolved(id) and id != &"apprentice" and not Meta.is_locked(id):
			out.append({"id": id, "lv": 1})
	return out


## What the Duck or LINT says as you walk in (research/workshop-0.19.md: Hades' lines that
## react to the last run): a first visit, a station just opened, then how the run ended.
## "hub_back" when there is no new run to talk about.
static func greeting(m: Dictionary) -> String:
	if not bool(m.get("hub_seen", false)):
		return "hub_first"
	# 0.20: after the true ending, the post-mortem (research/world3-0.20.md)
	if Residents.flag("fixed_forward", m) and int(m.get("greeted", -1)) != int(m.get("runs", 0)) and (m.get("last_run", {}) as Dictionary).get("won", false):
		return "hub_epilogue"
	var runs := int(m.get("runs", 0))
	if int(m.get("greeted", -1)) == runs:
		return "hub_back"
	for id in STATIONS:
		if int(STATIONS[id].get("runs", 0)) == runs and runs > 0:
			return "hub_unlock"
	var lr: Dictionary = m.get("last_run", {})
	if lr.is_empty():
		return "hub_back"
	if lr.get("won", false):
		return "hub_win"
	if lr.get("quit", false):
		return "hub_quit"
	if lr.get("boss", false):
		return "hub_boss"
	return "hub_death"


static func is_open(id: String, meta: Dictionary) -> bool:
	return int(meta.get("runs", 0)) >= int(STATIONS[id].get("runs", 0))


## Finds the markers, puts the dummy on its spot and notes the lifetime record.
func populate() -> void:
	anchors.clear()
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			for id in STATIONS:
				if STATIONS[id]["mark"] == row[x] and (not STATIONS[id].get("resident", false) or Residents.rescued(StringName(id))):
					if not anchors.has(id):
						anchors[id] = []
					anchors[id].append(Vector2(x * TS + TS / 2.0, y * TS + TS / 2.0))
	var meta := SaveGame.load_meta()
	_runs = int(meta.get("runs", 0))
	news.clear()
	for id in Residents.ORDER:
		news[id] = Residents.has_news(id, meta)
	_last_dmg = float(world.run.stats.get("damage", 0.0))
	_spawn_dummy()


func _dummy_spot() -> Vector2:
	for y in ROWS.size():
		var x := String(ROWS[y]).find("U")
		if x >= 0:
			return Vector2(x * TS + TS / 2.0, y * TS + TS / 2.0 + 6.0)
	return Vector2.ZERO


func _spawn_dummy() -> void:
	Game.quiet += 1
	dummy = world.spawn_enemy(&"slime", _dummy_spot())
	Game.quiet -= 1
	dummy.ai = &"dummy"
	dummy.spawn_t = 0.0
	dummy.sprite.visible = true
	dummy.max_hp = 99999.0
	dummy.hp = dummy.max_hp
	dummy.dmg = 0.0


## 0.25: the station at a point in the room (a click or the mouse): its marker, or the name
## under it. Returns [id, pedestal] or [].
func station_at(q: Vector2) -> Array:
	var f := Game.font("small")
	var best: Array = []
	var bd := 18.0
	for id in anchors:
		var list: Array = anchors[id]
		for k in list.size():
			var a: Vector2 = list[k]
			var d := q.distance_to(a + Vector2(0, -4))
			var nm := String(SHORT.get(id, "")) if id != "heroes" else "HEROES"
			if nm != "" and _label_rect(f, a + Vector2(0, 16 if id != "portal" else 14), nm).grow(2.0).has_point(q):
				d = minf(d, 6.0)
			if d < bd:
				bd = d
				best = [id, k]
	return best


## What USE does at the station in reach: USE, or TALK then a resident's service.
func use_verb() -> String:
	if near == "":
		return ""
	if STATIONS[near].get("resident", false):
		return {"grep": "ASK", "hotfix": "SKINS", "cache": "PAGES"}.get(near, "USE") if talked == StringName(near) else "TALK"
	return "TALK" if near == "duck" or near == "lint" else "USE"


func open(id: String) -> bool:
	return is_open(id, {"runs": _runs})


func in_fire_zone(p: Vector2) -> bool:
	return open("repl") and FIRE_ZONE.has_point(p)


## USE on a resident: the first time you talk (their lines play as bubbles over them), the
## next time their service opens. Returns "talk" or "service".
func resident_use(id: StringName) -> String:
	if talked == id:
		return "service"
	talked = id
	return "talk"


## The station whose speaker is talking right now ("" for none): its label and "!" step
## aside for the bubble.
static func speaking() -> String:
	var who := String(Dialogue.current.get("who", ""))
	if who == "":
		return ""
	var res := Residents.id_of(who)
	if res != &"":
		return String(res)
	return "duck" if who == Story.DUCK else ("lint" if who == Story.LINT else "")


func update(dt: float) -> void:
	_snap_t -= dt
	if _snap_t <= 0.0 or snap.is_empty():
		refresh_snap()
	var p := world.player.position
	# the station in reach: the nearest marker within USE_R
	near = ""
	near_arg = -1
	var best := USE_R
	for id in anchors:
		var list: Array = anchors[id]
		for k in list.size():
			var d := p.distance_to(list[k])
			if d < best:
				best = d
				near = id
				near_arg = k
	if talked != &"" and anchors.has(String(talked)) and p.distance_to(anchors[String(talked)][0]) > USE_R + 10.0:
		if talk_arc and Dialogue.last_started != talk_last:
			Residents.rewind(talked)   # left before the beat's last line: it keeps for next time
		talk_arc = false
		Dialogue.drop_prefix("res.%s." % talked)
		talked = &""
	# the portal is the one walk-in (the doors in a run work the same way)
	var pp: Vector2 = anchors.get("portal", [Vector2.INF])[0]
	var dp := p.distance_to(pp)
	if dp < PORTAL_R and _armed and not world.paused:
		_armed = false
		world.ui_request.emit(&"station", {"id": "portal"})
	elif dp > 30.0:
		_armed = true
	# the dummy: damage per second over the last few seconds; it heals once left alone
	var total := float(world.run.stats.get("damage", 0.0))
	var got := total - _last_dmg
	_last_dmg = total
	if got > 0.0:
		_hits.append([world.time, got])
		_last_hit = world.time
	while not _hits.is_empty() and world.time - float(_hits[0][0]) > DPS_WINDOW:
		_hits.pop_front()
	var sum := 0.0
	for h in _hits:
		sum += float(h[1])
	dps = sum / DPS_WINDOW
	if dummy == null or not is_instance_valid(dummy) or dummy.dead:
		_spawn_dummy()
	elif world.time - _last_hit > 1.5:
		dummy.hp = dummy.max_hp


# ------------------------------------------------------------------ drawing

func _shadow(ci: CanvasItem, p: Vector2, r := 10.0) -> void:
	ci.draw_set_transform(p + Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.4))
	ci.draw_set_transform(Vector2.ZERO)


func _stand(ci: CanvasItem, tex: Texture2D, p: Vector2, mod := Color.WHITE) -> void:
	ci.draw_texture(tex, (p + Vector2(-tex.get_width() / 2.0, 8 - tex.get_height())).round(), mod)


## Under the actors: every station's prop, locked ones dimmed.
func draw_deco(ci: CanvasItem) -> void:
	var t := world.time
	var dim := Color(0.35, 0.3, 0.45, 0.8)
	var chosen := world.run.hero
	# the Hero Hall: three pedestals; yours stands empty (you are the one on it)
	var hs: Array = anchors.get("heroes", [])
	for k in mini(hs.size(), HEROES.size()):
		var p: Vector2 = hs[k]
		var id := HEROES[k]
		ci.draw_rect(Rect2(p + Vector2(-8, 4), Vector2(16, 5)), Style.c("stone:2") if Style.RAMPS.has("stone") else Color("#4a4460"))
		ci.draw_rect(Rect2(p + Vector2(-8, 4), Vector2(16, 1)), Color("#8a80a8"))
		if id == chosen:
			ci.draw_arc(p + Vector2(0, 6), 9.0, 0.0, TAU, 16, Color(1.0, 0.85, 0.3, 0.6 + 0.3 * sin(t * 3.0)), 1.0)
			continue
		var fr: Array = Hero.frames(id)
		var tex: Texture2D = fr[int(t * 2.0 + k) % 2]
		var locked: bool = snap.get("locked", {}).get(id, false)
		ci.draw_texture(tex, (p + Vector2(-tex.get_width() / 2.0, 5 - tex.get_height())).round(), Color(0.06, 0.04, 0.12, 0.92) if locked else Color.WHITE)
	# the portal's frame in the top wall (its swirl is drawn on top)
	var pp: Vector2 = anchors.get("portal", [Vector2.ZERO])[0]
	ci.draw_texture(Props.door(Color("#ffe066"), true), Vector2(pp.x - TS - 5, -9))
	# trophies either side of the portal
	var done: Array = snap.get("done", [])
	for k in TROPHIES.size():
		var tr: Dictionary = TROPHIES[k]
		var tp := pp + Vector2(-34 - k * 14 if k < 2 else 30, 6)
		ci.draw_rect(Rect2(tp + Vector2(-4, 2), Vector2(8, 6)), Color("#3a3350"))
		if done.has(tr["bounty"]):
			ci.draw_texture(Icons.glyph(tr["glyph"], Color(tr["color"])), (tp + Vector2(-8, -12)).round())
	# the wand bench and the dummy's patch of floor
	var bp: Vector2 = anchors.get("repl", [Vector2.ZERO])[0]
	_shadow(ci, bp)
	ci.draw_rect(Rect2(bp + Vector2(-10, -2), Vector2(20, 8)), Color("#6b4a2e") if open("repl") else dim)
	ci.draw_rect(Rect2(bp + Vector2(-10, -2), Vector2(20, 2)), Color("#a8764a") if open("repl") else dim)
	ci.draw_texture(Icons.glyph("wand", Color("#5ce1ff")), (bp + Vector2(-8, -14)).round(), Color.WHITE if open("repl") else dim)
	if open("repl"):
		ci.draw_rect(Rect2(FIRE_ZONE.position + Vector2(2, TS + 2), FIRE_ZONE.size - Vector2(4, TS + 4)), Color(0.36, 0.88, 1.0, 0.05))
	# the merchant
	var mp: Vector2 = anchors.get("pkg", [Vector2.ZERO])[0]
	_shadow(ci, mp)
	_stand(ci, Props.merchant(int(t * 2.0) % 2), mp, Color.WHITE if open("pkg") else dim)
	# the bounty board: a cork board with its three tickets
	var qp: Vector2 = anchors.get("bounty", [Vector2.ZERO])[0]
	ci.draw_rect(Rect2(qp + Vector2(-9, -20), Vector2(18, 22)), Color("#6b4a2e"))
	ci.draw_rect(Rect2(qp + Vector2(-8, -19), Vector2(16, 20)), Color("#b08a5a"))
	var board: int = snap.get("board", 0)
	var waiting: int = snap.get("waiting", 0)
	for k in 3:
		var tk := Rect2(qp + Vector2(-6 + (k % 2) * 7, -17 + k * 6), Vector2(6, 5))
		ci.draw_rect(tk, Color("#f4eeff") if k < board else Color("#8a6a44"))
	if waiting > 0:
		ci.draw_circle(qp + Vector2(8, -20), 4.0 + sin(t * 5.0), Color("#72e06a"))
	# the Compendium: a bookshelf of coloured spines
	var cp: Vector2 = anchors.get("docs", [Vector2.ZERO])[0]
	ci.draw_rect(Rect2(cp + Vector2(-9, -22), Vector2(18, 24)), Color("#4a3322"))
	var spines := ["#5ce1ff", "#ff8a3c", "#72e06a", "#ffd05e", "#a060d8", "#ff6b7a"]
	for row in 3:
		for k in 5:
			ci.draw_rect(Rect2(cp + Vector2(-8 + k * 3.2, -21 + row * 8), Vector2(2.4, 6)), Color(spines[(row * 5 + k) % spines.size()]).darkened(0.15))
	# the Commit Wall: a dark panel of green lines
	var wp: Vector2 = anchors.get("log", [Vector2.ZERO])[0]
	ci.draw_rect(Rect2(wp + Vector2(-9, -20), Vector2(18, 22)), Color("#0e1a14"))
	for k in 6:
		ci.draw_rect(Rect2(wp + Vector2(-7, -18 + k * 3.3), Vector2(4 + (k * 5) % 11, 1)), Color("#72e06a", 0.8))
	# the Terminal: a monitor on a desk
	var kp: Vector2 = anchors.get("terminal", [Vector2.ZERO])[0]
	_shadow(ci, kp)
	ci.draw_rect(Rect2(kp + Vector2(-9, 0), Vector2(18, 6)), Color("#3a3350"))
	ci.draw_rect(Rect2(kp + Vector2(-7, -14), Vector2(14, 12)), Color("#1a1330"))
	ci.draw_rect(Rect2(kp + Vector2(-6, -13), Vector2(12, 9)), Color(0.36, 0.88, 1.0, 0.55 + 0.1 * sin(t * 4.0)))
	# the Duck and LINT
	var dp: Vector2 = anchors.get("duck", [Vector2.ZERO])[0]
	_shadow(ci, dp, 7.0)
	# 0.24: the Debug Duck sits on the floor (DuckArt.sit): it blinks, and its bill moves and
	# its mood shows while it speaks
	var duck_says := speaking() == "duck"
	var dmood := DuckArt.mood_of(String(Dialogue.current.get("id", ""))) if duck_says else DuckArt.PLAIN
	var dtex := DuckArt.sit(duck_says and fmod(t, 0.24) < 0.12, fmod(t, 3.7) < 0.12, dmood)
	ci.draw_texture(dtex, (dp + Vector2(-8, -14 + sin(t * 2.5) * 0.5)).round())
	var np: Vector2 = anchors.get("lint", [Vector2.ZERO])[0]
	_shadow(ci, np, 6.0)
	ci.draw_texture(Hud.lint_face(), (np + Vector2(-6, -10 + sin(t * 1.7 + 1.0) * 1.0)).round())
	# 0.20: the residents, in their corners once they've moved in
	for id in Residents.ORDER:
		var key := String(id)
		if not anchors.has(key):
			continue
		var rp: Vector2 = anchors[key][0]
		_shadow(ci, rp, 7.0)
		_stand(ci, KernelArt.resident(id, int(t * 3.0 + rp.x) % 4), rp)


## Over the actors: the portal's swirl, the name of the station in reach, the dummy's DPS.
func draw_top(ci: CanvasItem) -> void:
	var t := world.time
	UiAudit.begin(ci, true, "Workshop labels")
	var pp: Vector2 = anchors.get("portal", [Vector2.ZERO])[0] + Vector2(0, -4)
	var gold := Color("#ffe066")
	for k in 3:
		var rr := 6.0 + k * 4.0 + sin(t * 3.0 + k) * 1.5
		var a0 := t * (2.5 - k * 0.6) + k * 2.1
		ci.draw_arc(pp, rr, a0, a0 + PI * 1.3, 16, Color(gold.r, gold.g, gold.b, 0.75 - k * 0.2), 1.0)
	ci.draw_circle(pp, 4.0 + sin(t * 6.0), Color(1.0, 0.9, 0.5, 0.35))
	var f := Game.font("small")
	# every station keeps a small name under it, so nothing in the room is a secret.
	# 0.21: the label of the station in reach wins; a name it would cover steps aside
	var near_r: Array[Rect2] = []
	var talking := speaking()
	var show_near := near != "" and near != talking
	var at: Vector2 = anchors[near][maxi(0, near_arg)] + Vector2(0, -30) if near != "" else Vector2.ZERO
	# 0.25, desktop: the key prompt over the name ("[E] USE"); a line that only repeats its verb
	# ("Talk") is left out
	var keyed := show_near and not (Game.is_touch() or Game.touch_seen) and open(near)
	var sub_line := show_near and not (keyed and _near_label(1).to_upper() == use_verb())
	if show_near:
		for k in (2 if sub_line else 1):
			near_r.append(_label_rect(f, at + Vector2(0, k * 9), _near_label(k)))
		if keyed:
			near_r.append(_label_rect(f, at + Vector2(0, -13), "[E] " + use_verb()).grow(3.0))
	var clear_of := func(p: Vector2, s1: String, size := 8) -> bool:
		var r1 := _label_rect(f, p, s1, size)
		return not near_r.any(func(q: Rect2) -> bool: return q.intersects(r1))
	var hs: Array = anchors.get("heroes", [])
	if near != "heroes" and hs.size() >= 2:
		var hp := (hs[hs.size() / 2] as Vector2) + Vector2(0, 18)
		if clear_of.call(hp, "HEROES"):
			_label(ci, f, hp, "HEROES", Color(Color(STATIONS["heroes"]["color"]), 0.8))
	for id in anchors:
		if id == near or id == "heroes" or id == "duck" or id == "lint" or STATIONS[id].get("resident", false):
			continue
		var ap: Vector2 = anchors[id][0] + Vector2(0, 16 if id != "portal" else 14)
		var nm := String(SHORT.get(id, STATIONS[id]["title"]))
		var c := Color(STATIONS[id]["color"]) if open(id) else Color(0.5, 0.45, 0.6)
		if clear_of.call(ap, nm):
			_label(ci, f, ap, nm, Color(c, 0.8))
	if show_near:
		var st: Dictionary = STATIONS[near]
		var locked := not open(near)
		_label(ci, f, at, _near_label(0), Color(st["color"]) if not locked else Color(0.6, 0.55, 0.7))
		if sub_line:
			_label(ci, f, at + Vector2(0, 9), _near_label(1), Color(0.9, 0.9, 1.0, 0.85))
		if keyed:
			# 0.25, desktop: the key, where you are looking (touch has its USE button)
			_key_chip(ci, f, at + Vector2(0, -13), "E", use_verb(), Color(st["color"]))
	elif hover != "" and hover != near and hover != talking and anchors.has(hover):
		# 0.25, desktop: the station under the mouse names itself; a click walks you there
		var hp2: Vector2 = anchors[hover][clampi(hover_k, 0, anchors[hover].size() - 1)] + Vector2(0, -30)
		var hc := Color(STATIONS[hover]["color"]) if open(hover) else Color(0.6, 0.55, 0.7)
		_label(ci, f, hp2, String(STATIONS[hover]["title"]), hc)
		_label(ci, f, hp2 + Vector2(0, 9), "Click to go there", Color(0.9, 0.9, 1.0, 0.7))
	# 0.20: a resident with a new beat to tell wears a "!" (not while talking, not under a label)
	for id in Residents.ORDER:
		var key := String(id)
		if anchors.has(key) and news.get(id, false) and key != talking:
			var ep: Vector2 = anchors[key][0] + Vector2(0, -34 + sin(t * 4.0) * 1.5)
			if clear_of.call(ep, "!", 16):
				_label(ci, f, ep, "!", Color(STATIONS[key]["color"]), 16)
	if open("repl") and dummy and is_instance_valid(dummy):
		_label(ci, f, dummy.position + Vector2(0, -22), "DPS %d" % roundi(dps), Color("#5ce1ff") if dps > 0.0 else Color(0.6, 0.55, 0.7))


## 0.25: where the stations' names sit (room coordinates), so a speech bubble keeps off them.
func label_rects() -> Array:
	var f := Game.font("small")
	var out: Array = []
	for id in anchors:
		if id == "duck" or id == "lint" or STATIONS[id].get("resident", false):
			continue
		var nm := "HEROES" if id == "heroes" else String(SHORT.get(id, STATIONS[id]["title"]))
		var list: Array = anchors[id]
		var p: Vector2 = (list[list.size() / 2] as Vector2) + Vector2(0, 18) if id == "heroes" else (list[0] as Vector2) + Vector2(0, 16 if id != "portal" else 14)
		out.append(_label_rect(f, p, nm))
	return out


## The label of the station in reach: its title (0) or its line (1).
func _near_label(k: int) -> String:
	var st: Dictionary = STATIONS[near]
	if k == 0:
		if near == "heroes" and near_arg >= 0 and near_arg < HEROES.size():
			return String(RunState.LOADOUTS[HEROES[near_arg]]["title"]).to_upper()
		return String(st["title"])
	return String(st.get("locked", "")) if not open(near) else String(st["sub"])


## Where _label draws a string, for keeping labels apart.
static func _label_rect(f: Font, at: Vector2, s: String, size := 8) -> Rect2:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return Rect2(at + Vector2(-w / 2.0 - 2, -size * 0.9), Vector2(w + 4, size * 0.9 + 3))


## A key prompt: the key in a small box, then what it does ("[E] USE").
func _key_chip(ci: CanvasItem, f: Font, at: Vector2, key: String, verb: String, c: Color) -> void:
	var kw := f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var vw := f.get_string_size(verb, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var w := kw + 6.0 + 4.0 + vw
	var x0 := roundf(at.x - w / 2.0)
	var box := Rect2(x0, at.y - 8, kw + 6.0, 10)
	ci.draw_rect(box, Color(0.05, 0.03, 0.1, 0.85))
	ci.draw_rect(box, c, false, 1.0)
	ci.draw_string(f, Vector2(x0 + 3, at.y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
	_label(ci, f, Vector2(x0 + kw + 10.0 + vw / 2.0, at.y), verb, c)
	UiAudit.text(ci, f, Vector2(x0 + 3, at.y), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)


func _label(ci: CanvasItem, f: Font, at: Vector2, s: String, c: Color, size := 8) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := (at - Vector2(w / 2.0, 0)).round()
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, 0.8))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	UiAudit.text(ci, f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
