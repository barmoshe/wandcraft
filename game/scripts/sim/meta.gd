class_name Meta
extends RefCounted
## Meta v2 (0.19, research/workshop-0.19.md): what carries over between runs, and how the
## rest of the game opens.
##   - The CORE pool is the game a first-time player sees: 23 spells (0.20: triggers moved to
##     their own pack), 24 relics, 6 wands,
##     the Apprentice (design v2, research/design-v2.md §3). It never changes.
##   - BITS are the one currency that survives a run: every run pays some (rooms, bosses, a
##     win, heat), and bounties pay more. They buy PACKS at the Workshop's merchant: themed
##     bundles of spells and relics, fixed and shown before you buy (content, never power).
##   - BOUNTIES replace design v2's goals: tickets on the Workshop's board ("Defeat a
##     mini-boss"). Progress counts before a ticket is shown; a fixed ticket opens its items
##     at once and its Bits wait at the board to be claimed.
##   - The COMPENDIUM ("dex") records what you have met: spells and relics seen or used,
##     enemies seen and their kills. Runs buffer it (RunState.dex) and fold it in here.
##
## Stored in user://meta.json beside the lifetime numbers: "bits", "packs" (owned ids),
## "bounties" (fixed ids), "claimed", "dex", "history" (the Commit Wall), "meta_v". Saves
## from before v2 are migrated once (migrate). Locking applies only in the running game
## (main.gd sets `active`) and in tests that set `test_meta`, never in the balance bench
## unless it asks for the core pool (`core_only`).

const CORE_SPELLS: Array[StringName] = [
	&"mote", &"needle", &"lance", &"fan", &"moths", &"ember", &"frost", &"spark", &"burst",
	&"turret", &"daemon",
	&"empower", &"twin", &"keen", &"seek", &"phase", &"wide", &"ember_coat", &"frost_coat", &"static_coat",
	&"seed",
	&"mana_well", &"heatsink",
]
const CORE_RELICS: Array[StringName] = [
	&"hot_patch", &"garbage_collector", &"interest", &"leech_loop", &"buffer_overflow", &"try_catch",
	&"recursion", &"aperture", &"null_pointer", &"cascade_failure", &"wildfire", &"cold_boot",
	&"event_loop", &"off_by_one", &"tail_call", &"loop_counter", &"stack_trace", &"surge_protector",
	&"race_condition", &"memory_leak", &"force_push", &"legacy_code",
	&"thermal_throttle", &"zero_day",
]
const CORE_WANDS: Array[StringName] = [&"twig", &"stub", &"oak", &"crystal", &"harp", &"daemon_rod"]

## The Bug Bounty Board, in board order. "check" names what _met tests; "bits" is paid when
## the ticket is claimed at the board; "unlocks" open the moment it is fixed; "needs" hides
## a ticket until that pack is owned.
const BOUNTIES := [
	{"id": "room", "text": "Clear a room", "check": "rooms>=1", "bits": 10, "unlocks": [&"chorus", &"ricochet"]},
	{"id": "clean", "text": "Clear a room without getting hit", "check": "clean>=1", "bits": 10, "unlocks": [&"heavy", &"deadline"]},
	{"id": "runs1", "text": "Finish a run", "check": "runs>=1", "bits": 15, "unlocks": [&"disc", &"static", &"duck"]},
	{"id": "mini", "text": "Defeat a mini-boss", "check": "bosses>=1", "bits": 20, "unlocks": [&"pyromancer", &"firewall", &"cold_start"]},
	{"id": "triggers", "text": "Clear a room with 2 triggers in your wand", "check": "trigger_rooms>=1", "bits": 15, "unlocks": [&"ping"], "needs": "triggers"},
	{"id": "runs3", "text": "Play 3 runs", "check": "runs>=3", "bits": 10, "unlocks": [&"slot"]},
	{"id": "big_hit", "text": "Deal 60 damage in one hit", "check": "max_hit>=60", "bits": 15},
	{"id": "rich", "text": "Hold 150 gold", "check": "max_gold>=150", "bits": 15},
	{"id": "kills", "text": "Defeat 100 enemies in one run", "check": "kills>=100", "bits": 15},
	{"id": "elites", "text": "Defeat 5 elites in one run", "check": "elites>=5", "bits": 20},
	{"id": "thermal", "text": "Set off 5 Thermal Shocks in one run", "check": "thermal>=5", "bits": 20},
	{"id": "crash", "text": "Crash 10 enemies with Bitrot in one run", "check": "crashes>=10", "bits": 20, "needs": "glitch"},
	{"id": "duo", "text": "Own a Duo relic", "check": "duos>=1", "bits": 25},
	{"id": "compile", "text": "Compile a spell at the forge", "check": "compiled>=1", "bits": 25},
	{"id": "boss", "text": "Reach the Infinite Loop", "check": "reached_boss>=1", "bits": 25},
	{"id": "world1", "text": "Defeat the Infinite Loop", "check": "worlds>=1", "bits": 40, "unlocks": [&"tinkerer"]},
	{"id": "untouched", "text": "Beat a boss without getting hit", "check": "untouched>=1", "bits": 40},
	{"id": "daily", "text": "Finish a daily run", "check": "daily>=1", "bits": 15},
	{"id": "win", "text": "Win a run (clear World 3)", "check": "won>=1", "bits": 60},
	# 0.20, the Kernel (research/world3-0.20.md)
	{"id": "world2", "text": "Defeat Deadlock", "check": "worlds>=2", "bits": 50},
	{"id": "rescue", "text": "Free someone from a cage", "check": "residents>=1", "bits": 20},
	{"id": "pages", "text": "Find a Lost Page", "check": "pages>=1", "bits": 15},
	{"id": "fixed", "text": "Fix it forward", "check": "fixed>=1", "bits": 100},
	{"id": "heat1", "text": "Win at heat 1 or higher", "check": "heat_win>=1", "bits": 60},
	{"id": "heat3", "text": "Win at heat 3 or higher", "check": "heat_win>=3", "bits": 100},
]
## How many open tickets the board shows at once.
const BOARD_SIZE := 3

## The merchant's packs, cheapest first. Legacy packs hold what design v2's goals used to
## open; the four ".pkg" packs are new content (Catalog.PACK_ITEMS). "needs" keeps a pack off
## the shelf until that bounty is fixed.
const PACKS := [
	# 0.20 (Bar, after playing): triggers leave the first run. The cheapest pack, so it's the
	# first thing a first run's Bits can buy, once the wand has two spells to join.
	{"id": "triggers", "title": "Triggers", "file": "triggers.pkg", "price": 30, "color": "#ff9a3a",
		"blurb": "Chain one spell into the next: Then, Callback, While Loop.",
		"items": [&"then", &"callback", &"loop"]},
	{"id": "glitch", "title": "Glitch", "file": "glitch.pkg", "price": 60, "color": "#a060d8",
		"blurb": "Marks, mines and rot: enemies that crash.",
		"items": [&"hexcursor", &"mine", &"bitrot", &"rot_coat", &"null_orb", &"rot_index"]},
	{"id": "flow", "title": "Flow Control", "file": "flow.pkg", "price": 60, "color": "#ffe066",
		"blurb": "More triggers, and ways to chain the whole wand.",
		"items": [&"finally", &"sleep", &"fork", &"pipeline", &"wheel", &"busy_wait", &"fork_branch"]},
	{"id": "physics", "title": "Physics", "file": "physics.pkg", "price": 60, "color": "#b48cff",
		"blurb": "Bend where your spells go: gravity, orbits, mirrors.",
		"items": [&"gravity", &"orbit", &"reverse", &"mirror", &"split", &"quicken", &"cornered", &"birch"]},
	{"id": "risk", "title": "Risk", "file": "risk.pkg", "price": 60, "color": "#ff6b7a",
		"blurb": "Big payoffs for playing on the edge.",
		"items": [&"siphon", &"watchdog", &"low_battery", &"heap_overflow", &"empty_set", &"uptime", &"bug_bounty", &"swarm_protocol", &"version_control"]},
	{"id": "debugger", "title": "Debugger", "file": "debugger.pkg", "price": 100, "color": "#5ce1ff", "needs": "world1",
		"blurb": "Runes that edit the program itself.",
		"items": [&"head", &"ifelse", &"goto", &"include", &"debug_build", &"root_access", &"stack_overflow", &"mirror_rod"]},
	{"id": "net", "title": "Networking", "file": "net.pkg", "price": 120, "color": "#7cf0c8",
		"blurb": "Mark a target, then deliver to it from anywhere.",
		"items": [&"traceroute", &"multicast", &"broadcast", &"keep_alive"]},
	{"id": "threads", "title": "Concurrency", "file": "threads.pkg", "price": 120, "color": "#ffb86b",
		"blurb": "Workers and blades that fight beside you.",
		"items": [&"worker", &"spinlock", &"scheduler", &"thread_pool"]},
	{"id": "git", "title": "Version Control", "file": "git.pkg", "price": 120, "color": "#9cf06a",
		"blurb": "Finish the toughest target. Undo one bad room.",
		"items": [&"cherry_pick", &"diff", &"blame", &"last_good_commit"]},
	{"id": "hw", "title": "Hardware", "file": "hw.pkg", "price": 120, "color": "#8ff0ff",
		"blurb": "Cheap spam, and a pulse that wipes out shots.",
		"items": [&"emp", &"cosmic_ray", &"undervolt", &"liquid_cooling", &"dual_core"]},
]
## How many packs the merchant shelves at once.
const SHELF := 3

## Bits a run pays (bits_for): per room cleared, per boss or mini-boss beaten, for beating
## the Loop, for a win, and a head start on a player's first runs (Gungeon's early bonus).
const BITS_ROOM := 2
const BITS_BOSS := 8
const BITS_LOOP := 10
const BITS_WIN := 25
const BITS_EARLY := 15
const EARLY_RUNS := 3

## Bug Reports (design-plan §6): heat tiers that stack, unlocked one per win (up to five).
const HEAT := [
	"No heat",
	"Every fight brings an elite",
	"...and enemies hit 20% harder",
	"...enemy shots fly 15% faster, one fewer door",
	"...and springs heal less, shops charge 25% more",
	"...and bosses fight their last phase early, faster",
]

## Tests: an in-memory meta record used instead of user://meta.json (and locking applies).
static var test_meta: Variant = null
## Set by main.gd when the game runs for real.
static var active := false
## The balance bench: measure the core pool (the game a new player gets).
static var core_only := false
static var _bounty_of := {}
static var _pack_of := {}


## The bounty that unlocks an id ({} when none does).
static func bounty_for(id: StringName) -> Dictionary:
	if _bounty_of.is_empty():
		for b in BOUNTIES:
			for u in b.get("unlocks", []):
				_bounty_of[u] = b
	return _bounty_of.get(id, {})


## The pack that holds an id ({} when none does).
static func pack_for(id: StringName) -> Dictionary:
	if _pack_of.is_empty():
		for p in PACKS:
			for u in p["items"]:
				_pack_of[u] = p
	return _pack_of.get(id, {})


static func pack(pid: String) -> Dictionary:
	for p in PACKS:
		if p["id"] == pid:
			return p
	return {}


static func bounty(bid: String) -> Dictionary:
	for b in BOUNTIES:
		if b["id"] == bid:
			return b
	return {}


static func is_core(id: StringName) -> bool:
	return bounty_for(id).is_empty() and pack_for(id).is_empty()


static func enforced() -> bool:
	return core_only or test_meta != null or (active and SaveGame.enabled)


static func _load() -> Dictionary:
	return migrate(test_meta) if test_meta != null else SaveGame.load_meta()


static func _store(m: Dictionary) -> void:
	if test_meta != null:
		test_meta = m
	else:
		SaveGame.save_meta(m)


## Fixed bounty ids.
static func bounties_done() -> Array:
	return [] if core_only else _load().get("bounties", [])


## Owned pack ids.
static func packs_owned() -> Array:
	return [] if core_only else _load().get("packs", [])


## Ids opened outside packs and bounties (fragments before v2; goal items after migration).
static func unlocked() -> Array:
	return [] if core_only else _load().get("unlocked", [])


static func bits() -> int:
	return int(_load().get("bits", 0))


## True when `id` waits on a pack or a bounty (and locking applies here).
static func is_locked(id: StringName) -> bool:
	if not enforced() or is_core(id):
		return false
	if unlocked().has(String(id)):
		return false
	var p := pack_for(id)
	if not p.is_empty():
		return not packs_owned().has(p["id"])
	return not bounties_done().has(bounty_for(id)["id"])


## Where a locked id comes from, for cards and the Compendium: "PACK: NETWORKING".
static func source_text(id: StringName) -> String:
	var p := pack_for(id)
	if not p.is_empty():
		return "PACK: %s" % String(p["title"]).to_upper()
	var b := bounty_for(id)
	if not b.is_empty():
		return "BOUNTY: %s" % String(b["text"]).to_upper()
	return ""


## The tickets the board shows: open ones whose pack is owned, in board order.
static func open_bounties() -> Array:
	var done := bounties_done()
	var owned := packs_owned()
	return BOUNTIES.filter(func(b: Dictionary) -> bool:
		return not done.has(b["id"]) and (not b.has("needs") or owned.has(b["needs"])))


static func board() -> Array:
	return open_bounties().slice(0, BOARD_SIZE)


## Fixed tickets whose Bits wait at the board.
static func unclaimed() -> Array:
	var m := _load()
	var claimed: Array = m.get("claimed", [])
	return bounties_done().filter(func(bid: String) -> bool: return not claimed.has(bid))


## Claims a fixed ticket's Bits. Returns the Bits paid (0 if nothing to claim).
static func claim(bid: String) -> int:
	var m := _load()
	var claimed: Array = m.get("claimed", [])
	if claimed.has(bid) or not (m.get("bounties", []) as Array).has(bid):
		return 0
	var n := int(bounty(bid).get("bits", 0))
	claimed.append(bid)
	m["claimed"] = claimed
	m["bits"] = int(m.get("bits", 0)) + n
	m["bits_life"] = int(m.get("bits_life", 0)) + n
	_store(m)
	return n


## Checks every bounty against this run (and the lifetime record), stores the newly fixed
## ones, and returns them. Called at each room clear and when a run ends. Sandbox runs (the
## Workshop) never count.
static func check(run: RunState) -> Array:
	if run.sandbox:
		return []
	var m := _load()
	var done: Array = m.get("bounties", [])
	var got: Array = []
	for b in BOUNTIES:
		if done.has(b["id"]):
			continue
		if _met(String(b["check"]), run, m):
			done.append(b["id"])
			got.append(b)
	if not got.is_empty():
		m["bounties"] = done
		_store(m)
	return got


static func _met(check: String, run: RunState, m: Dictionary) -> bool:
	var parts := check.split(">=")
	var need := float(parts[1])
	var st := run.stats
	var v := 0.0
	match parts[0]:
		"rooms", "clean", "bosses", "trigger_rooms", "compiled", "kills", "elites", "thermal", "crashes", "untouched", "residents", "pages", "fixed":
			v = float(st.get(parts[0], 0))
		"max_hit": v = float(st.get("max_hit", 0.0))
		"max_gold": v = float(maxi(run.gold, int(st.get("max_gold", 0))))
		"duos": v = float(run.relics.filter(func(r: StringName) -> bool: return Relics.DEFS.get(r, {}).has("duo")).size())
		"reached_boss": v = 1.0 if run.step >= Chapter.PLAN.size() - 1 else 0.0
		"won": v = 1.0 if run.won else 0.0
		"worlds": v = float(maxi(run.world, int(st.get("worlds", 0))))
		"runs": v = float(m.get("runs", 0))
		"daily": v = float(m.get("dailies", 0))
		"heat_win": v = float(run.heat) if run.won else -1.0
	return v >= need


## Bits a finished run pays (before bounties).
static func bits_for(run: RunState, runs_before: int) -> int:
	if run.sandbox:
		return 0
	var st := run.stats
	var n := int(st.get("rooms", 0)) * BITS_ROOM + int(st.get("bosses", 0)) * BITS_BOSS
	if run.world >= 1 or int(st.get("worlds", 0)) >= 1:
		n += BITS_LOOP
	if run.world >= 2 or int(st.get("worlds", 0)) >= 2:
		n += BITS_LOOP   # 0.20: Deadlock too
	if run.won:
		n += BITS_WIN
	if runs_before < EARLY_RUNS:
		n += BITS_EARLY
	return roundi(n * (1.0 + 0.1 * run.heat))


## The packs on the merchant's shelf: unowned, their "needs" met, cheapest first.
static func shelf() -> Array:
	var owned := packs_owned()
	var done := bounties_done()
	var open := PACKS.filter(func(p: Dictionary) -> bool:
		return not owned.has(p["id"]) and (not p.has("needs") or done.has(p["needs"])))
	return open.slice(0, SHELF)


## A pack's price: its list price times the share of its items not already open (a player
## who owned half a legacy pack before v2 pays half).
static func pack_price(pid: String) -> int:
	var p := pack(pid)
	if p.is_empty():
		return 0
	var items: Array = p["items"]
	var have := unlocked()
	var left := items.filter(func(id: StringName) -> bool: return not have.has(String(id))).size()
	return ceili(float(p["price"]) * left / maxf(1.0, items.size()))


## Buys a pack. Returns true when it was bought (enough Bits, not owned).
static func buy_pack(pid: String) -> bool:
	var m := _load()
	var owned: Array = m.get("packs", [])
	var price := pack_price(pid)
	if owned.has(pid) or pack(pid).is_empty() or int(m.get("bits", 0)) < price:
		return false
	m["bits"] = int(m.get("bits", 0)) - price
	owned.append(pid)
	m["packs"] = owned
	_store(m)
	return true


## Folds a run's discoveries (RunState.dex) into the Compendium. "s", "r", "w": id -> 1 seen,
## 2 used; "e": enemy kind -> kills (0 = seen).
static func fold_dex(run: RunState) -> void:
	if run.sandbox or run.dex.is_empty():
		return
	var m := _load()
	var dex: Dictionary = m.get("dex", {})
	for k in ["s", "r", "w"]:
		var into: Dictionary = dex.get(k, {})
		for id in run.dex.get(k, {}):
			into[id] = maxi(int(into.get(id, 0)), int(run.dex[k][id]))
		dex[k] = into
	var e: Dictionary = dex.get("e", {})
	for id in run.dex.get("e", {}):
		e[id] = int(e.get(id, 0)) + int(run.dex["e"][id])
	dex["e"] = e
	m["dex"] = dex
	_store(m)
	run.dex = {}


static func dex() -> Dictionary:
	return _load().get("dex", {})


## Meta v2's one-time move from design v2's goals (safe to run twice). Every goal done
## becomes a fixed bounty where one has its id, and everything a goal had opened stays open
## (into "unlocked"); legacy packs whose items are all open count as owned; the Bits those
## bounties would have paid are paid now.
const V2_GOAL_ITEMS := {
	"triggers": [&"finally", &"sleep", &"ping"], "big_hit": [&"quicken", &"busy_wait", &"null_orb"],
	"rich": [&"siphon", &"low_battery", &"heap_overflow"], "duo": [&"bug_bounty", &"swarm_protocol", &"version_control"],
	"compile": [&"hexcursor", &"mine", &"bitrot", &"rot_coat", &"rot_index"], "boss": [&"gravity", &"orbit", &"cornered", &"uptime"],
	"world1": [&"tinkerer", &"pipeline"], "win": [&"fork", &"wheel"], "runs2": [&"watchdog", &"mirror", &"split", &"birch"],
	"runs3": [&"slot", &"reverse", &"empty_set", &"fork_branch"], "heat1": [&"head", &"ifelse", &"debug_build", &"root_access"],
	"heat3": [&"goto", &"include", &"stack_overflow", &"mirror_rod"],
}


static func migrate(m: Dictionary) -> Dictionary:
	if int(m.get("meta_v", 1)) == 2:
		return _migrate_v3(m)
	if int(m.get("meta_v", 1)) >= 3:
		return m
	var goals: Array = m.get("goals", [])
	if goals.has("win") and not goals.has("world1"):
		goals = goals + ["world1"]
	var done: Array = m.get("bounties", [])
	var have: Array = m.get("unlocked", [])
	var back := 0
	for gid in goals:
		for id in V2_GOAL_ITEMS.get(gid, []):
			if not have.has(String(id)):
				have.append(String(id))
		if not bounty(gid).is_empty() and not done.has(gid):
			done.append(gid)
			back += int(bounty(gid).get("bits", 0))
	var owned: Array = m.get("packs", [])
	for p in PACKS:
		if not owned.has(p["id"]) and (p["items"] as Array).all(func(id: StringName) -> bool: return have.has(String(id))):
			owned.append(p["id"])
	var claimed: Array = m.get("claimed", [])
	for bid in done:
		if not claimed.has(bid):
			claimed.append(bid)
	m["bounties"] = done
	m["claimed"] = claimed
	m["unlocked"] = have
	m["packs"] = owned
	m["bits"] = int(m.get("bits", 0)) + back
	m["bits_life"] = int(m.get("bits_life", 0)) + back
	m.erase("goals")
	m.erase("last_goals")
	m["meta_v"] = 2
	return _migrate_v3(m)


## 0.20 (meta v3): a win used to be Deadlock's fall; that win now counts as "Defeat Deadlock".
static func _migrate_v3(m: Dictionary) -> Dictionary:
	var done: Array = m.get("bounties", [])
	var claimed: Array = m.get("claimed", [])
	if done.has("win") and not done.has("world2"):
		done.append("world2")
		claimed.append("world2")
	m["bounties"] = done
	m["claimed"] = claimed
	m["meta_v"] = 3
	return m


## The one stat unlock: an extra empty slot on the starting wand.
static func extra_slots() -> int:
	return 0 if not enforced() or is_locked(&"slot") or core_only else 1


## Display name of an unlockable id.
static func title(id: StringName) -> String:
	if RunState.LOADOUTS.has(id):
		return "%s (hero)" % RunState.LOADOUTS[id]["title"]
	if id == &"slot":
		return "+1 starting slot"
	if Catalog.spells().has(id):
		return Catalog.spell(id).title
	if Relics.DEFS.has(id):
		return String(Relics.DEFS[id]["title"])
	if Catalog.wands().has(id):
		return Catalog.wand(id).title
	return String(id)
