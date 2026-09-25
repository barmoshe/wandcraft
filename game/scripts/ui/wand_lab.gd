class_name WandLab
extends SubViewport
## The firing range (design v2, pillar 1: see it before you cast it). A quiet copy of the
## world where a wand fires on loop at three training dummies, so what the editor shows is
## what the game does, not a formula. Noita players needed an outside simulator to read
## their wands; this one is in the game.
##
## Two uses:
##   - shown: the editor draws this viewport's texture; the wand fires in real time, with
##     real mana, so a wand that runs dry visibly stalls.
##   - probe: one hidden lab (probe()) measures damage per second for any layout, a few
##     steps each frame so a phone never stutters; results are cached by layout.
## Nothing leaks out: Game.quiet is raised around every step (no sound, buzz, tips, HUD).

const DT := 1.0 / 60.0
const HERO := Vector2(136, 136)
const DUMMIES := [Vector2(236, 118), Vector2(268, 140), Vector2(244, 164)]
## What the shown range frames (room pixels), and how long a probe measures.
const VIEW := Rect2(104, 82, 200, 100)
const PROBE_SECONDS := 3.0
const PROBE_STEPS_PER_FRAME := 24

var world: World
var wand: WandState
var sig := ""
var shown := true
var _dummies: Array[Enemy] = []
var _t := 0.0
## probe queue: [{"sig", "run", "def", "slots"}], and results by signature
var _queue: Array = []
var _busy: Dictionary = {}
var _steps_left := 0
var _cache: Dictionary = {}

static var _probe: WandLab


## The hidden measuring lab, created on first use and kept for the session.
static func probe(tree: SceneTree) -> WandLab:
	if _probe == null or not is_instance_valid(_probe):
		_probe = WandLab.new()
		_probe.shown = false
		tree.root.add_child(_probe)
	return _probe


## A layout's identity: the wand, its slots and the relics that change damage.
static func signature(run: RunState, def: WandDef, slots: Array) -> String:
	var ids := slots.map(func(s: Variant) -> String: return "-" if s == null else "%s%d" % [s["id"], int(s["lv"])])
	return "%s|%s|%s" % [def.id, ",".join(ids), ",".join(run.relics) if run else ""]


func _ready() -> void:
	_build()
	canvas_transform = Transform2D(0.0, -VIEW.position)


## Builds the range once (from _ready, or on first use when the tree is not running yet).
func _build() -> void:
	if world != null:
		return
	size = Vector2i(int(VIEW.size.x), int(VIEW.size.y))
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	Game.quiet += 1
	world = World.new()
	world.auto_step = false
	add_child(world)
	world.setup(99)
	world.run = RunState.create(99)
	world.build_room("hall", &"empty")
	world.player.position = HERO
	world.controls.fire = true
	Game.quiet -= 1
	if is_inside_tree():
		canvas_transform = Transform2D(0.0, -VIEW.position)


## Frames a w x h window of the range at 1:1 (pixel art stays crisp), centred on the fight.
func set_view(sz: Vector2i) -> void:
	if size == sz:
		return
	size = sz
	var centre := Vector2(214, 126)
	if is_inside_tree():
		canvas_transform = Transform2D(0.0, -(centre - Vector2(sz) / 2.0).round())


## Shows (or measures) this wand: a copy with the run's relics, reset to a fresh range.
func load_wand(run: RunState, def: WandDef, slots: Array) -> void:
	_build()
	sig = signature(run, def, slots)
	var r := world.run
	r.relics = run.relics.duplicate() if run else []
	r.max_hp = 9999.0
	r.hp = r.max_hp
	wand = WandState.make(def)
	wand.set_slots(slots.duplicate(true))
	r.wands = [wand]
	r.cur = 0
	r.apply_relics()
	_reset()


func _reset() -> void:
	Game.quiet += 1
	world.bullets.clear_all()
	world.ebullets.clear_all()
	world.spells.clear_room()
	world.fx.clear_all()
	for e in world.enemies:
		e.queue_free()
	world.enemies.clear()
	_dummies.clear()
	for p in DUMMIES:
		var e := world.spawn_enemy(&"slime", p)
		e.ai = &"dummy"
		e.spawn_t = 0.0
		e.sprite.visible = true
		e.max_hp = 99999.0
		e.hp = e.max_hp
		e.dmg = 0.0
		_dummies.append(e)
	world.player.position = HERO
	world.player.dead = false
	world.damage_done = 0.0
	_t = 0.0
	if wand:
		wand.mana = wand.max_mana()
		wand.ptr = 0
		wand.acc = Mods.new()
		wand.cd = 0.3
	Game.quiet -= 1


func _step(n: int) -> void:
	Game.quiet += 1
	for i in n:
		world.step(DT)
		# dummies stay home: knockback and pulls would walk them out of the range
		for k in _dummies.size():
			var e := _dummies[k]
			if is_instance_valid(e):
				e.position = e.position.lerp(DUMMIES[k], 0.2)
				e.hp = e.max_hp
	Game.quiet -= 1


func _process(_dt: float) -> void:
	if shown:
		if wand == null:
			return
		_step(1)
		_t += DT
		# a fresh range every few seconds, so the first casts of the loop stay on screen
		if _t > 4.0 and wand.mana >= wand.max_mana() * 0.5:
			_reset()
		return
	_pump()


# ------------------------------------------------------------------ probe

## Damage per second of this layout (mana is not the limit here; the editor's sustain bar
## shows that). Returns the cached number, or -1 while it is still being measured.
func dps(run: RunState, def: WandDef, slots: Array) -> float:
	var s := signature(run, def, slots)
	if _cache.has(s):
		return _cache[s]
	if not _busy.has(s):
		_busy[s] = true
		_queue.append({"sig": s, "run": run, "def": def, "slots": slots.duplicate(true)})
	return -1.0


## Measures synchronously (tests and the bot): the same number dps() settles on.
func measure_now(run: RunState, def: WandDef, slots: Array) -> float:
	var s := signature(run, def, slots)
	if not _cache.has(s):
		_steps_left = 0   # a queued measurement in progress restarts afterwards
		load_wand(run, def, slots)
		var was := Game.inf_mana
		Game.inf_mana = true
		_step(int(PROBE_SECONDS / DT))
		Game.inf_mana = was
		_cache[s] = world.damage_done / PROBE_SECONDS
	return _cache[s]


func _pump() -> void:
	if _steps_left <= 0:
		if _queue.is_empty():
			return
		var job: Dictionary = _queue[0]
		load_wand(job["run"], job["def"], job["slots"])
		_steps_left = int(PROBE_SECONDS / DT)
	var n := mini(PROBE_STEPS_PER_FRAME, _steps_left)
	var was := Game.inf_mana
	Game.inf_mana = true
	_step(n)
	Game.inf_mana = was
	_steps_left -= n
	if _steps_left <= 0:
		var job: Dictionary = _queue.pop_front()
		_cache[job["sig"]] = world.damage_done / PROBE_SECONDS
		_busy.erase(job["sig"])
