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
	{"kind": "altar", "reward": "", "w": 0.5},
	{"kind": "terminal", "reward": "", "w": 0.5},
]
const LANES := 3
## World 1's two areas (D5): the room steps each one covers, and its name.
const AREAS := [{"name": "The Mossy Root Cellar", "from": 0}, {"name": "The Corrupted Grove", "from": 5}]

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
	"altar": {"name": "Altar", "color": "#ff4d6d"},
	"terminal": {"name": "Debug Terminal", "color": "#5ce1ff"},
	"mini": {"name": "Mini-boss", "color": "#ff3fa4"},
	"boss": {"name": "Boss", "color": "#ff3fa4"},
	"exit": {"name": "Onward", "color": "#ffe066"},
}

const QUIET := [&"start", &"shop", &"spring", &"forge", &"altar", &"terminal"]


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


static func area_name(step: int) -> String:
	return AREAS[1]["name"] if step >= AREAS[1]["from"] else AREAS[0]["name"]


## The visible 3-lane map (D5): every room step has three nodes, the mini-boss and the boss
## one each. From lane L you can reach lanes L-1..L+1 on the next step. Rules:
##   the first two room steps are fights; no challenge, Glitch Door, altar or terminal
##   before the fourth room; no quiet room twice in a row on a lane; the middle lane of the
##   step before a boss is always a spring or a shop (every lane can reach it)
static func make_map(run: RunState) -> Array:
	var rng := run.rng
	var out: Array = []
	for step in PLAN.size():
		match PLAN[step]:
			&"start":
				out.append([{"kind": &"start", "reward": &""}])
				continue
			&"mini":
				out.append([{"kind": &"mini", "reward": &"relic"}])
				continue
			&"boss":
				out.append([{"kind": &"boss", "reward": &"wand"}])
				continue
		var nodes: Array = []
		for lane in LANES:
			var prev: Dictionary = out[step - 1][mini(lane, out[step - 1].size() - 1)]
			var pool := POOL.filter(func(p: Dictionary) -> bool:
				if step <= 2 and p["kind"] != "fight":
					return false
				if step < 3 and p["kind"] in ["challenge", "glitch", "altar", "terminal"]:
					return false
				if p["kind"] != "fight" and is_quiet(StringName(p["kind"])) and is_quiet(prev["kind"]):
					return false
				if p["kind"] == "glitch" and not Relics.DEFS.keys().any(func(id: StringName) -> bool: return Relics.offerable(run, id, true)):
					return false
				return true)
			var d := {}
			for guard in 20:
				var p := _pick(pool, rng)
				d = {"kind": StringName(p["kind"]), "reward": StringName(p["reward"])}
				if not nodes.any(func(o: Dictionary) -> bool: return o["kind"] == d["kind"] and o["reward"] == d["reward"]):
					break
			nodes.append(d)
		if step + 1 < PLAN.size() and (PLAN[step + 1] == &"boss" or PLAN[step + 1] == &"mini"):
			nodes[1] = {"kind": [&"spring", &"shop"][rng.randi() % 2], "reward": &""}
		# at least one fight on every step, so no stretch is all shopping
		if not nodes.any(func(o: Dictionary) -> bool: return not is_quiet(o["kind"])):
			nodes[0] = {"kind": &"fight", "reward": &"spell"}
		out.append(nodes)
	return out


## The doors offered once the current room is cleared: the next step's nodes you can reach.
static func door_options(run: RunState) -> Array:
	var nxt := run.step + 1
	if nxt >= PLAN.size():
		return [{"kind": &"exit", "reward": &""}]
	if run.map.is_empty():
		run.map = make_map(run)
	var nodes: Array = run.map[nxt]
	if nodes.size() == 1:
		return [nodes[0].duplicate()]
	var out: Array = []
	for lane in LANES:
		if run.step == 0 or absi(lane - run.lane) <= 1:
			var d: Dictionary = nodes[lane].duplicate()
			d["lane"] = lane
			out.append(d)
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
