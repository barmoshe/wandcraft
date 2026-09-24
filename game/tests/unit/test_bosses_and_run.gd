extends "res://tests/unit/test_helpers.gd"
## Bosses and a whole World 1 run, played by the bot at 60 Hz (headless, god mode).

const DT := 1.0 / 60.0
var world: World
var tree: SceneTree


func setup(t: SceneTree) -> void:
	tree = t
	Game.god_mode = true
	Game.auto_fire = true
	SaveGame.enabled = false
	world = World.new()
	world.auto_step = false
	t.root.add_child(world)
	world.setup(4242)
	world.bot = true
	world.ui_request.connect(_answer)


func teardown() -> void:
	Game.god_mode = false
	SaveGame.enabled = true
	world.free()


var victory := false


func _answer(kind: StringName, data: Dictionary) -> void:
	match kind:
		&"reward":
			if not data["offer"].is_empty():
				Rewards.grant(world.run, data["offer"][0])
			world.reward_taken()
		&"shop", &"forge":
			world.ui_done()
		&"victory":
			victory = true


func _mid_run(step: int, kind: StringName) -> RunState:
	var r := RunState.create(4242)
	r.wand().set_slots([&"twin", &"spark", &"seed", &"ember"])
	r.add_wand(&"oak")
	r.wands[1].set_slots([&"empower", &"fan", &"then", &"burst", &"needle", &"frost"])
	r.cur = 0
	r.step = step
	r.room = {"kind": kind, "reward": &"relic"}
	return r


func _fight_boss(step: int, kind: StringName, limit: float) -> Array:
	world.start_run(_mid_run(step, kind))
	var t := 0.0
	var boss: Boss = null
	var max_phase := 0
	while t < limit:
		world.step(DT)
		t += DT
		if world.boss:
			boss = world.boss
			max_phase = maxi(max_phase, boss.phase)
		if boss and boss.dead:
			break
	return [boss, t, max_phase]


func test_copy_paste_can_be_beaten() -> void:
	var res := _fight_boss(4, &"mini", 150.0)
	var boss: Boss = res[0]
	ok(boss is BossCopyPaste, "Copy-Paste appeared")
	ok(boss != null and boss.dead, "and was beaten (%.0fs, hp %.0f)" % [res[1], boss.hp if boss else -1.0])
	ok(res[2] >= 1, "it reached phase 2")
	ok(not world.orb.is_empty() or world.cleared, "the room is cleared with a reward")


func test_the_infinite_loop_can_be_beaten() -> void:
	var res := _fight_boss(8, &"boss", 200.0)
	var boss: Boss = res[0]
	ok(boss is BossLoop, "The Infinite Loop appeared")
	ok(boss != null and boss.dead, "and was beaten (%.0fs, hp %.0f)" % [res[1], boss.hp if boss else -1.0])
	ok(res[2] >= 1, "it reached phase 2")
	eq((boss as BossLoop).parts.filter(func(p: Enemy) -> bool: return not p.dead).size(), 0, "its body went with it")


## The full chapter: start room, 3 rooms, mini-boss, 3 rooms, boss, exit.
func test_bot_completes_world_one() -> void:
	world.start_run(RunState.create(99))
	var t := 0.0
	while not victory and t < 1500.0:
		world.step(DT)
		t += DT
	print("    full run: step %d, %.0f sim-seconds, %d kills, path %s" % [world.run.step, t, world.run.stats["kills"], world.run.path])
	ok(victory, "World 1 cleared (reached step %d of %d in %.0fs)" % [world.run.step, Chapter.PLAN.size(), t])
	ok(world.run.won, "the run is marked won")
	eq(int(world.run.stats["bosses"]), 2, "both bosses defeated")
