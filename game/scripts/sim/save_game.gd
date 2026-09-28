class_name SaveGame
extends RefCounted
## Local saves in user:// (no cloud, no accounts, no analytics). The run is saved at stable
## points: entering a room, closing a reward/shop screen, and when the app is paused. A
## resumed run restarts the room it was saved in. Settings live in their own small file.

const RUN_PATH := "user://run.json"
const SETTINGS_PATH := "user://settings.json"
const META_PATH := "user://meta.json"
## A progress reset for every player (Bar, 2026-09-28, 0.18.1 and again in 0.18.2: a clean slate for playtest
## round 2). A save from an older epoch is wiped on launch: the run, the meta record (goals,
## unlocks, heat, logs, the story seen) and the play log. Settings stay. Raise EPOCH to reset
## everyone again.
const EPOCH := 3
const EPOCH_PATH := "user://epoch.json"
const WIPE := [RUN_PATH, META_PATH, "user://runlog.json"]
## Plan kinds that are boss fights (the Commit Wall marks a death there).
const PLAN_BOSS := [&"mini", &"boss"]

## Tests switch saving off so they never touch the real save.
static var enabled := true
## Screenshot runs (main.gd --shot): a fresh save held in memory, so tools never write the
## player's files and every shot starts from a first-time player's state.
static var in_memory := false
static var _mem := {}


## Wipes progress saved under an older epoch. Returns true when it did.
static func reset_if_stale() -> bool:
	if not enabled or in_memory:
		return false
	var d: Variant = _read(EPOCH_PATH)
	if d is Dictionary and int(d.get("epoch", 0)) >= EPOCH:
		return false
	var wiped := false
	for p in WIPE:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			wiped = true
	_write(EPOCH_PATH, {"epoch": EPOCH})
	return wiped


static func save_run(run: RunState) -> void:
	if not enabled or in_memory or run == null or run.won or run.sandbox:
		return
	_write(RUN_PATH, run.to_dict())


static func load_run() -> RunState:
	var d: Variant = _read(RUN_PATH)
	if d is Dictionary:
		return RunState.from_dict(d)
	return null


static func has_run() -> bool:
	return enabled and not in_memory and FileAccess.file_exists(RUN_PATH)


static func clear_run() -> void:
	if enabled and FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


static func load_settings() -> Dictionary:
	var d: Variant = _read(SETTINGS_PATH)
	return d if d is Dictionary else {}


static func save_settings(d: Dictionary) -> void:
	if enabled:
		_write(SETTINGS_PATH, d)


## Lifetime numbers shown on the title screen.
static func load_meta() -> Dictionary:
	var d: Variant = _read(META_PATH)
	var m := {"runs": 0, "wins": 0, "best_step": 0, "kills": 0, "hints": [], "hero": "apprentice", "heat": 0}
	if d is Dictionary:
		for k in d:
			m[k] = d[k]
	return Meta.migrate(m)


static func save_meta(m: Dictionary) -> void:
	if enabled:
		_write(META_PATH, m)


## How many runs the Commit Wall keeps.
const HISTORY := 30


## A finished run: the lifetime numbers, the daily best, the Commit Wall, the Compendium,
## its Bits and the bounties it fixed. `how` is "abandon" when the player quit; `by` is what
## ended it (Player.last_hurt_by).
static func record_run(run: RunState, how := "", by := "") -> void:
	if not enabled or run.sandbox:
		return
	Meta.fold_dex(run)
	var m := load_meta()
	var bits := Meta.bits_for(run, int(m["runs"]))
	m["bits"] = int(m.get("bits", 0)) + bits
	m["bits_life"] = int(m.get("bits_life", 0)) + bits
	m["last_bits"] = bits
	if run.daily != "":
		m["dailies"] = int(m.get("dailies", 0)) + 1
	# the Commit Wall: this run as a commit, newest first
	var at := PLAN_BOSS.has(Chapter.PLAN[clampi(run.step, 0, Chapter.PLAN.size() - 1)])
	var entry := {"id": "%06x" % (hash(str(run.seed_value) + str(m["runs"])) & 0xffffff), "won": run.won,
		"world": run.world, "step": run.step, "heat": run.heat, "hero": String(run.hero), "by": by,
		"quit": how == "abandon", "boss": at, "daily": run.daily, "wand": run.wand().def.title,
		"rooms": int(run.stats.get("rooms", 0)), "time": roundi(float(run.stats.get("time", 0.0))),
		"date": Time.get_date_string_from_system()}
	var hist: Array = m.get("history", [])
	hist.push_front(entry)
	m["history"] = hist.slice(0, HISTORY)
	m["last_run"] = entry
	m["runs"] = int(m["runs"]) + 1
	m["wins"] = int(m["wins"]) + (1 if run.won else 0)
	m["best_step"] = maxi(int(m["best_step"]), Chapter.depth(run))   # rooms deep, across worlds
	m["kills"] = int(m["kills"]) + int(run.stats["kills"])
	if run.tutorial:
		m["tutorial_done"] = true
	if run.daily != "":
		# the best daily result for that date: furthest room, then a win, then the faster time
		var best: Dictionary = m.get("daily", {})
		var mine := {"date": run.daily, "step": run.step, "won": run.won, "time": roundi(float(run.stats["time"]))}
		var better: bool = best.get("date", "") != run.daily or run.step > int(best.get("step", 0)) \
			or (run.step == int(best.get("step", 0)) and run.won and int(mine["time"]) < int(best.get("time", 99999)))
		if better:
			m["daily"] = mine
	_write(META_PATH, m)
	# meta v2: bounties the finished run fixed (the end screen lists them; their Bits wait
	# at the Workshop's board)
	var got := Meta.check(run).map(func(b: Dictionary) -> String: return b["id"])
	m = load_meta()
	m["last_bounties"] = got
	_write(META_PATH, m)


static func _write(path: String, d: Dictionary) -> void:
	if in_memory:
		_mem[path] = d.duplicate(true)
		return
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save failed: %s" % path)
		return
	f.store_string(JSON.stringify(d))
	f.close()
	# write-then-rename, so a kill mid-write never leaves a broken save
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


static func _read(path: String) -> Variant:
	if in_memory:
		return _mem.get(path, null)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
