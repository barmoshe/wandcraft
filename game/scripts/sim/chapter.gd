class_name Chapter
extends RefCounted
## The shape of a world: a start room, three chosen rooms, the mini-boss, three chosen
## rooms, the boss. After each cleared room the player picks a door, and every door shows
## what is behind it, so the route is a decision (heal before the boss? gamble on a relic?).

## The Glitch Door costs this much max HP to walk through (its prizes are Corrupted relics).
const GLITCH_COST := 10.0

const PLAN: Array[StringName] = [&"start", &"room", &"room", &"room", &"mini", &"room", &"room", &"room", &"boss"]

## Door pool: kind + the reward promised on the door, with a weight.
const POOL := [
	{"kind": "fight", "reward": "spell", "w": 5.0},
	{"kind": "fight", "reward": "relic", "w": 1.6},
	{"kind": "fight", "reward": "gold", "w": 1.6},
	{"kind": "fight", "reward": "heart", "w": 1.3},
	{"kind": "fight", "reward": "wand", "w": 0.7},
	{"kind": "challenge", "reward": "relic", "w": 0.9},
	{"kind": "shop", "reward": "", "w": 1.2},
	{"kind": "spring", "reward": "", "w": 0.9},
	{"kind": "forge", "reward": "", "w": 1.0},
	{"kind": "glitch", "reward": "relic", "w": 0.6},
]

const INFO := {
	"spell": {"name": "Spell", "color": "#5ce1ff"},
	"relic": {"name": "Relic", "color": "#ffc94a"},
	"gold": {"name": "Gold", "color": "#ffd36b"},
	"heart": {"name": "Max HP", "color": "#ff4d6d"},
	"wand": {"name": "Wand", "color": "#c79a5a"},
	"challenge": {"name": "Challenge", "color": "#ff7b7b"},
	"shop": {"name": "Shop", "color": "#ffc94a"},
	"spring": {"name": "Spring", "color": "#6fb8ff"},
	"forge": {"name": "Forge", "color": "#ff8a3c"},
	"glitch": {"name": "Glitch Door", "color": "#ff6fd2"},
	"mini": {"name": "Mini-boss", "color": "#ff3fa4"},
	"boss": {"name": "Boss", "color": "#ff3fa4"},
	"exit": {"name": "Onward", "color": "#ffe066"},
}

const QUIET := [&"start", &"shop", &"spring", &"forge"]


static func is_quiet(kind: StringName) -> bool:
	return QUIET.has(kind)


## The key used for a door's icon and label: the reward for fights, the kind otherwise.
static func door_key(d: Dictionary) -> String:
	var kind := String(d.get("kind", ""))
	if kind == "fight":
		return String(d.get("reward", "spell"))
	return kind


static func door_name(d: Dictionary) -> String:
	return INFO.get(door_key(d), {"name": "?"})["name"]


static func door_color(d: Dictionary) -> Color:
	return Color(INFO.get(door_key(d), {"color": "#ffffff"})["color"])


## The doors offered once the current room is cleared.
static func door_options(run: RunState) -> Array:
	var nxt := run.step + 1
	if nxt >= PLAN.size():
		return [{"kind": &"exit", "reward": &""}]
	match PLAN[nxt]:
		&"mini":
			return [{"kind": &"mini", "reward": &"relic"}]
		&"boss":
			return [{"kind": &"boss", "reward": &"wand"}]
	var rng := run.rng
	var n := 2 + (1 if rng.randf() < 0.3 else 0)
	var last := StringName(run.room.get("kind", ""))
	var pool := POOL.filter(func(p: Dictionary) -> bool:
		# no quiet room twice in a row, and the first room is always a fight
		if p["kind"] != "fight" and p["kind"] == String(last):
			return false
		if nxt == 1 and p["kind"] != "fight":
			return false
		# no challenge or Glitch Door before the fourth room, and the Glitch Door only while
		# a Corrupted relic is left to find
		if (p["kind"] == "challenge" or p["kind"] == "glitch") and nxt < 3:
			return false
		if p["kind"] == "glitch" and not Relics.DEFS.keys().any(func(id: StringName) -> bool: return Relics.offerable(run, id, true)):
			return false
		return true)
	var out: Array = []
	# right before a boss or mini-boss: always offer a way to recover or spend gold
	if nxt + 1 < PLAN.size() and (PLAN[nxt + 1] == &"boss" or PLAN[nxt + 1] == &"mini"):
		var k: StringName = [&"spring", &"shop"][rng.randi() % 2]
		if k == last:
			k = &"spring" if k == &"shop" else &"shop"
		out.append({"kind": k, "reward": &""})
	var guard := 0
	while out.size() < n and guard < 50:
		guard += 1
		var p := _pick(pool, rng)
		var d := {"kind": StringName(p["kind"]), "reward": StringName(p["reward"])}
		if out.any(func(o: Dictionary) -> bool: return o["kind"] == d["kind"] and o["reward"] == d["reward"]):
			continue
		# at most one quiet door, most of the time
		var quiet_n := out.filter(func(o: Dictionary) -> bool: return is_quiet(o["kind"])).size()
		if is_quiet(d["kind"]) and quiet_n >= 1 and rng.randf() < 0.7:
			continue
		out.append(d)
	if not out.any(func(o: Dictionary) -> bool: return o["kind"] == &"fight" or o["kind"] == &"challenge" or o["kind"] == &"glitch"):
		out[out.size() - 1] = {"kind": &"fight", "reward": &"spell"}
	# shuffle so the guaranteed door is not always first
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out


static func _pick(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for p in pool:
		total += float(p["w"])
	var x := rng.randf() * total
	for p in pool:
		x -= float(p["w"])
		if x <= 0.0:
			return p
	return pool[pool.size() - 1]
