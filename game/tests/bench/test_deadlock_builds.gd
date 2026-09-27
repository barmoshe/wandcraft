extends "res://tests/unit/test_helpers.gd"
## Deadlock tests the build, it doesn't wipe it (research/magicraft-progression.md, lesson 5):
## a single-target wand and a crowd wand both break it in a fair time. The bot fights with
## god mode on, so this measures the fight's length, not survival (tools/balance.sh).

const DT := 1.0 / 60.0
const LIMIT := 240.0
const BUILDS := {
	"single-target": [&"empower", &"needle", &"needle", &"keen", &"needle"],
	"crowd": [&"fan", &"ember", &"burst", &"frost", &"mote"],
}

func _fight(slots: Array) -> float:
	Game.god_mode = true
	Game.auto_fire = true
	SaveGame.enabled = false
	var world := World.new()
	world.auto_step = false
	runner.root.add_child(world)
	world.setup(7)
	world.bot = true
	var r := RunState.create(7)
	r.wands[0] = WandState.make(Catalog.wand(&"oak"), slots)
	world.start_run(r)
	world.run.world = 1
	world.run.step = Chapter.PLAN.size() - 1
	world.build_room("arena_ring", &"boss")
	world.call("_spawn_boss")
	var b := world.boss
	var t := 0.0
	while t < LIMIT and b and not b.dead:
		world.step(DT)
		t += DT
	world.free()
	Game.god_mode = false
	SaveGame.enabled = true
	return t


func test_deadlock_falls_to_every_build() -> void:
	var times := {}
	for name in BUILDS:
		times[name] = _fight(BUILDS[name])
		print("    Deadlock vs a %s wand: %.0f s" % [name, times[name]])
		ok(times[name] < LIMIT - 1.0, "a %s wand breaks Deadlock" % name)
	var lo := minf(times["single-target"], times["crowd"])
	var hi := maxf(times["single-target"], times["crowd"])
	ok(hi <= lo * 2.0, "neither build takes more than twice as long (%.0f vs %.0f s)" % [lo, hi])
