extends "res://tests/unit/test_helpers.gd"
## The 0.19 spell packs against the core (tools/balance.sh --only=pack): each pack's showcase
## wand on an Old Oak Staff, all level 1, fights Copy-Paste, the Loop, Deadlock and a room-8
## crowd. The bot fights with god mode on, so this measures the fight's length, not survival.
## Band: a pack wand takes 0.7-1.4x the better core wand's time (the geometric mean over the
## four fights), and it never beats both core wands by more than 25% on all three bosses
## (that would be power creep: a pack you buy must not be the new best build).

const DT := 1.0 / 60.0
const LIMIT := 240.0
const FIGHTS := ["Copy-Paste", "the Loop", "Deadlock", "room-8 crowd"]
const CORE := ["core single", "core crowd"]
const BUILDS := {
	"core single": {"slots": [&"empower", &"needle", &"needle", &"keen", &"needle"]},
	"core crowd": {"slots": [&"fan", &"ember", &"burst", &"frost", &"mote"]},
	"Networking": {"slots": [&"static_coat", &"broadcast", &"traceroute", &"multicast", &"burst"]},
	"Concurrency": {"slots": [&"worker", &"mote", &"spinlock", &"daemon", &"spark", &"scheduler"], "relics": [&"thread_pool"]},
	"Version Control": {"slots": [&"blame", &"empower", &"diff", &"needle", &"cherry_pick", &"burst"], "kind": "core single"},
	"Hardware": {"slots": [&"undervolt", &"cosmic_ray", &"then", &"burst", &"emp"]},
}


func _fight(build: Dictionary, fight: String) -> float:
	Game.god_mode = true
	Game.auto_fire = true
	SaveGame.enabled = false
	var world := World.new()
	world.auto_step = false
	runner.root.add_child(world)
	world.setup(7)
	world.bot = true
	var r := RunState.create(7)
	r.wands[0] = WandState.make(Catalog.wand(&"oak"), build["slots"])
	for id in build.get("relics", []):
		r.relics.append(id)
	world.start_run(r)
	match fight:
		"Copy-Paste":
			world.run.step = Chapter.PLAN.find(&"mini")
			world.force_mini = &"copy_paste"
			world.build_room("arena_open", &"mini")
			world.call("_spawn_boss")
		"the Loop", "Deadlock":
			world.run.world = 1 if fight == "Deadlock" else 0
			world.run.step = Chapter.PLAN.size() - 1
			world.build_room("arena_ring", &"boss")
			world.call("_spawn_boss")
		_:
			world.run.step = 8
			world.run.room = {"kind": "fight"}
			world.build_room("hall", &"fight")
	var t := 0.0
	while t < LIMIT:
		if fight == "room-8 crowd":
			if world.cleared:
				break
		elif world.boss == null or world.boss.dead:
			break
		world.step(DT)
		t += DT
	world.free()
	Game.god_mode = false
	SaveGame.enabled = true
	return t


func test_pack_wands_stay_in_the_core_band() -> void:
	var times := {}
	for name in BUILDS:
		times[name] = {}
		for f in FIGHTS:
			times[name][f] = _fight(BUILDS[name], f)
	print("\n    %-16s %11s %11s %11s %13s   ratio" % ["wand", FIGHTS[0], FIGHTS[1], FIGHTS[2], FIGHTS[3]])
	var gms := {}
	for name in BUILDS:
		var row := "    %-16s" % name
		var logr := 0.0
		for f in FIGHTS:
			var best := minf(times[CORE[0]][f], times[CORE[1]][f])
			var k: float = times[name][f] / maxf(best, 0.1)
			logr += log(k)
			row += " %6.0fs x%.2f" % [times[name][f], k]
		var gm := exp(logr / FIGHTS.size())
		gms[name] = gm
		print(row + "   x%.2f" % gm)
		if CORE.has(name):
			continue   # core single never breaks the Loop's armored head in time (no Blast): known
		for f in FIGHTS:
			ok(times[name][f] < LIMIT - 1.0, "%s wins against %s" % [name, f])
		# a pack built for one job (a single-target pack) is held to the core wand of its kind
		var kind: String = BUILDS[name].get("kind", "")
		var fair := gm <= 1.4 or (kind != "" and gm <= float(gms[kind]))
		ok(gm >= 0.7 and fair, "%s takes 0.7-1.4x the better core wand's time, or beats the core %s (x%.2f)" % [name, kind if kind != "" else "wands", gm])
		var creep := true
		for f in ["Copy-Paste", "the Loop", "Deadlock"]:
			var best2 := minf(times[CORE[0]][f], times[CORE[1]][f])
			creep = creep and times[name][f] < best2 * 0.75
		ok(not creep, "%s does not beat both core wands by 25%% on every boss (power creep)" % name)
