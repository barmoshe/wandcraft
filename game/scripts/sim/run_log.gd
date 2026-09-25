class_name RunLog
extends RefCounted
## Design v3 (V0): a small local play log for playtests. What each run did, room by room:
## time and HP lost per room, what was offered and taken (or skipped), how often the wand
## was edited, and what ended the run. Stored in user://runlog.json (the last 30 runs), never
## sent anywhere. On the web build `window.wandcraftRunLog()` returns it, so a tester can
## paste it back to Bar; SaveGame's in-memory mode keeps tools from touching it.

const PATH := "user://runlog.json"
const KEEP := 30

static var _cur: Dictionary = {}
static var _room_t0 := 0.0
static var _room_hp0 := 0.0


static func start(run: RunState) -> void:
	_cur = {"seed": run.seed_value, "hero": String(run.hero), "daily": run.daily, "heat": run.heat,
		"tutorial": run.tutorial, "rooms": [], "picks": [], "edits": 0, "result": "", "killed_by": "",
		"date": Time.get_datetime_string_from_system(false, true)}
	_room_t0 = 0.0
	_room_hp0 = run.hp


static func room_entered(run: RunState, kind: StringName) -> void:
	if _cur.is_empty():
		return
	_room_t0 = float(run.stats["time"])
	_room_hp0 = run.hp
	(_cur["rooms"] as Array).append({"step": run.step, "kind": String(kind),
		"threat": String(Chapter.threat_of(run.room)), "t": 0.0, "hp_lost": 0.0, "cleared": false})


static func room_cleared(run: RunState) -> void:
	var rooms: Array = _cur.get("rooms", [])
	if rooms.is_empty():
		return
	var r: Dictionary = rooms[rooms.size() - 1]
	r["t"] = snappedf(float(run.stats["time"]) - _room_t0, 0.1)
	r["hp_lost"] = roundi(maxf(0.0, _room_hp0 - run.hp))
	r["cleared"] = true


## A reward screen's answer: what was offered and what was taken ("" for a skip).
static func pick(kind: StringName, offer: Array, taken: Variant) -> void:
	if _cur.is_empty():
		return
	(_cur["picks"] as Array).append({"kind": String(kind),
		"offer": offer.map(func(o: Dictionary) -> String: return String(o.get("id", o.get("t", "")))),
		"took": String(taken["id"]) if taken is Dictionary else ""})


static func edited() -> void:
	if not _cur.is_empty():
		_cur["edits"] = int(_cur["edits"]) + 1


## Closes the run and stores it with the last KEEP ones.
static func finish(run: RunState, killed_by: String) -> void:
	if _cur.is_empty():
		return
	_cur["result"] = "win" if run.won else "death"
	_cur["killed_by"] = killed_by
	_cur["step"] = run.step
	_cur["time"] = roundi(float(run.stats["time"]))
	_cur["first_edit"] = snappedf(float(run.stats.get("first_edit", -1.0)), 0.1)
	var all := load_all()
	all.append(_cur)
	while all.size() > KEEP:
		all.pop_front()
	SaveGame._write(PATH, {"runs": all})
	_cur = {}
	_publish()


static func load_all() -> Array:
	var d: Variant = SaveGame._read(PATH)
	return (d["runs"] as Array) if d is Dictionary and d.has("runs") else []


## Web: window.wandcraftRunLog() hands the log to a tester's console.
static func _publish() -> void:
	if not OS.has_feature("web"):
		return
	var js := JSON.stringify({"runs": load_all()}).replace("\\", "\\\\").replace("'", "\\'")
	JavaScriptBridge.eval("window.wandcraftRunLog = function() { return '%s'; };" % js, true)
