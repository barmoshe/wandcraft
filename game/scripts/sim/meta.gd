class_name Meta
extends RefCounted
## D9: meta progression, Dead Cells style (design-plan §6). Every run earns Source Fragments;
## the Codex spends them to add content to the pool: spells, the Debugger runes, relics,
## wands and the second starter loadout. The only stat upgrade is one extra starting slot.
## A new player starts with a smaller pool, which also keeps the first runs readable.
##
## Stored in user://meta.json beside the lifetime numbers ("fragments", "unlocked").
## Locking applies only in the running game (main.gd sets `active`), never in tests or the
## balance bench, which keep measuring the full game and never read this machine's save.

## In the order the Codex lists them. "t": spell | rune | relic | wand | loadout | slot.
const UNLOCKS := [
	{"id": &"stub", "t": &"loadout", "cost": 6},
	{"id": &"pipeline", "t": &"spell", "cost": 8},
	{"id": &"fork", "t": &"spell", "cost": 8},
	{"id": &"hexcursor", "t": &"spell", "cost": 10},
	{"id": &"bitrot", "t": &"spell", "cost": 10},
	{"id": &"rot_coat", "t": &"spell", "cost": 10},
	{"id": &"siphon", "t": &"spell", "cost": 10},
	{"id": &"duck", "t": &"spell", "cost": 10},
	{"id": &"finally", "t": &"spell", "cost": 10},
	{"id": &"race_condition", "t": &"relic", "cost": 12},
	{"id": &"force_push", "t": &"relic", "cost": 12},
	{"id": &"legacy_code", "t": &"relic", "cost": 12},
	{"id": &"ping", "t": &"spell", "cost": 12},
	{"id": &"gravity", "t": &"spell", "cost": 12},
	{"id": &"daemon", "t": &"spell", "cost": 12},
	{"id": &"turret", "t": &"spell", "cost": 12},
	{"id": &"head", "t": &"rune", "cost": 14},
	{"id": &"memory_leak", "t": &"relic", "cost": 14},
	{"id": &"swarm_protocol", "t": &"relic", "cost": 14},
	{"id": &"zero_day", "t": &"relic", "cost": 14},
	{"id": &"daemon_rod", "t": &"wand", "cost": 16},
	{"id": &"ifelse", "t": &"rune", "cost": 16},
	{"id": &"goto", "t": &"rune", "cost": 16},
	{"id": &"crystal", "t": &"wand", "cost": 18},
	{"id": &"include", "t": &"rune", "cost": 18},
	{"id": &"debug_build", "t": &"wand", "cost": 20},
	{"id": &"slot", "t": &"slot", "cost": 40},
]

## Bug Reports (design-plan §6): heat tiers that stack, unlocked one per win (up to five).
const HEAT := [
	"No bug reports",
	"Elite reports: every fight brings an elite",
	"Load spikes: enemies have 20% more HP",
	"Race conditions: enemy shots fly 15% faster",
	"Scope creep: springs heal less, shops charge 25% more",
	"Hotfix denied: bosses have 25% more HP",
]

static var _locked_ids := {}
## Tests: an in-memory meta record used instead of user://meta.json (and locking applies).
static var test_meta: Variant = null
## Set by main.gd when the game runs for real.
static var active := false


## Everything that can be locked, by id.
static func lockable() -> Dictionary:
	if _locked_ids.is_empty():
		for u in UNLOCKS:
			_locked_ids[u["id"]] = u
	return _locked_ids


static func enforced() -> bool:
	return test_meta != null or (active and SaveGame.enabled)


static func _load() -> Dictionary:
	return test_meta if test_meta != null else SaveGame.load_meta()


static func _store(m: Dictionary) -> void:
	if test_meta != null:
		test_meta = m
	else:
		SaveGame.save_meta(m)


static func unlocked() -> Array:
	return _load().get("unlocked", [])


## True when `id` is in the unlock pool and not bought yet (and saving is on).
static func is_locked(id: StringName) -> bool:
	if not enforced() or not lockable().has(id):
		return false
	return not unlocked().has(String(id))


static func fragments() -> int:
	return int(_load().get("fragments", 0))


## Fragments a run earns: one per room cleared, three per mini-boss, five per boss, five more
## for a win, and +20% per Bug Reports tier.
static func earned(run: RunState) -> int:
	var f := int(run.stats.get("rooms", 0)) + 3 * mini(1, int(run.stats.get("bosses", 0))) \
		+ 5 * maxi(0, int(run.stats.get("bosses", 0)) - 1) + (5 if run.won else 0)
	return roundi(f * (1.0 + 0.2 * run.heat))


## Spends fragments on an unlock. False when it is unknown, owned, or too dear.
static func buy(id: StringName) -> bool:
	if not lockable().has(id):
		return false
	var m := _load()
	var owned: Array = m.get("unlocked", [])
	var cost := int(lockable()[id]["cost"])
	if owned.has(String(id)) or int(m.get("fragments", 0)) < cost:
		return false
	m["fragments"] = int(m.get("fragments", 0)) - cost
	owned.append(String(id))
	m["unlocked"] = owned
	_store(m)
	return true


## The one stat upgrade: extra empty slots on the starting wand.
static func extra_slots() -> int:
	return 0 if is_locked(&"slot") or not enforced() else 1


## Display name of an unlock.
static func title(u: Dictionary) -> String:
	match u["t"]:
		&"spell", &"rune":
			return Catalog.spell(u["id"]).title
		&"relic":
			return String(Relics.DEFS[u["id"]]["title"])
		&"wand":
			return Catalog.wand(u["id"]).title
		&"loadout":
			return "%s start" % Catalog.wand(u["id"]).title
		&"slot":
			return "+1 starting slot"
	return String(u["id"])
