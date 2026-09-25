class_name SaveGame
extends RefCounted
## Local saves in user:// (no cloud, no accounts, no analytics). The run is saved at stable
## points: entering a room, closing a reward/shop screen, and when the app is paused. A
## resumed run restarts the room it was saved in. Settings live in their own small file.

const RUN_PATH := "user://run.json"
const SETTINGS_PATH := "user://settings.json"
const META_PATH := "user://meta.json"

## Tests switch saving off so they never touch the real save.
static var enabled := true


static func save_run(run: RunState) -> void:
	if not enabled or run == null or run.won:
		return
	_write(RUN_PATH, run.to_dict())


static func load_run() -> RunState:
	var d: Variant = _read(RUN_PATH)
	if d is Dictionary:
		return RunState.from_dict(d)
	return null


static func has_run() -> bool:
	return enabled and FileAccess.file_exists(RUN_PATH)


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
	var m := {"runs": 0, "wins": 0, "best_step": 0, "kills": 0, "hints": []}
	if d is Dictionary:
		for k in d:
			m[k] = d[k]
	return m


static func save_meta(m: Dictionary) -> void:
	if enabled:
		_write(META_PATH, m)


static func record_run(run: RunState) -> void:
	if not enabled:
		return
	var m := load_meta()
	m["runs"] = int(m["runs"]) + 1
	m["wins"] = int(m["wins"]) + (1 if run.won else 0)
	m["best_step"] = maxi(int(m["best_step"]), run.step)
	m["kills"] = int(m["kills"]) + int(run.stats["kills"])
	if run.tutorial:
		m["tutorial_done"] = true
	# D9: Source Fragments for the Codex
	var got := Meta.earned(run)
	m["fragments"] = int(m.get("fragments", 0)) + got
	m["last_fragments"] = got
	_write(META_PATH, m)


static func _write(path: String, d: Dictionary) -> void:
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
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
