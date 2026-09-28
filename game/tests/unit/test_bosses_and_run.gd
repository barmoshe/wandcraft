extends "res://tests/unit/test_helpers.gd"
## Bosses and a whole World 1 run, played by the bot at 60 Hz (headless, god mode).

const DT := 1.0 / 60.0
const STUCK := 300.0    # sim-seconds in one room before the full run gives up
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


func _mid_run(step: int, kind: StringName, w := 0) -> RunState:
	var r := RunState.create(4242)
	r.world = w
	r.tutorial = w == 0 and r.tutorial
	r.wand().set_slots([&"twin", &"spark", &"seed", &"ember"])
	r.add_wand(&"oak")
	r.wands[1].set_slots([&"empower", &"fan", &"then", &"burst", &"needle", &"frost"])
	r.cur = 0
	r.step = step
	r.room = {"kind": kind, "reward": &"relic"}
	return r


func _fight_boss(step: int, kind: StringName, limit: float, w := 0) -> Array:
	world.start_run(_mid_run(step, kind, w))
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
	world.force_mini = &"copy_paste"
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


## 0.20: World 3's mini-boss and boss, with the same strong loadout.
func test_data_race_can_be_beaten() -> void:
	var res := _fight_boss(Chapter.PLAN.find(&"mini"), &"mini", 200.0, 2)
	var boss: Boss = res[0]
	ok(boss is BossRace, "Data Race appeared")
	ok(boss != null and boss.dead, "and was beaten (%.0fs, hp %.0f)" % [res[1], boss.hp if boss else -1.0])


func test_the_glitch_can_be_beaten() -> void:
	var res := _fight_boss(Chapter.PLAN.size() - 1, &"boss", 300.0, 2)
	var boss: Boss = res[0]
	ok(boss is BossGlitch, "the Glitch appeared")
	ok(boss != null and boss.dead, "and was beaten (%.0fs, hp %.0f)" % [res[1], boss.hp if boss else -1.0])
	ok(res[2] >= 2, "it reached phase 3 (revert)")


## The full run: World 1 (start, 4 rooms, mini-boss, 4 rooms, the Loop), then World 2 the
## same way (its mini-boss, then Deadlock), then World 3 (Data Race, the Glitch), and the exit.
func test_bot_completes_all_three_worlds() -> void:
	world.start_run(RunState.create(99))
	var t := 0.0
	# 0.21: a watchdog. A bot stuck in one room (it used to burn the whole hour, 30+ minutes
	# of CPU) stops the run after STUCK sim-seconds without moving on, and says where.
	var mark := Vector2i(world.run.world, world.run.step)
	var mark_t := 0.0
	var stuck := false
	while not victory and t < 3600.0:
		world.step(DT)
		t += DT
		var now := Vector2i(world.run.world, world.run.step)
		if now != mark:
			mark = now
			mark_t = t
		elif t - mark_t > STUCK:
			stuck = true
			break
	if stuck:
		print("    STUCK in world %d step %d (%s) for %.0fs" % [mark.x + 1, mark.y, world.room_kind, STUCK])
	print("    full run: step %d, %.0f sim-seconds, %d kills, path %s" % [world.run.step, t, world.run.stats["kills"], world.run.path])
	if not victory:
		print("    DEBUG room ", world.run.room, " alive: ", world.enemies.filter(func(e: Enemy) -> bool: return not e.dead).map(func(e: Enemy) -> String: return "%s hp%.0f ward%d arm%.0f sh%d at %s" % [e.kind, e.hp, e.ward_n, e.armor, e.shield_hp, e.position.round()]))
	ok(victory, "all three worlds cleared (reached world %d step %d of %d in %.0fs)" % [world.run.world + 1, world.run.step, Chapter.PLAN.size(), t])
	ok(world.run.won, "the run is marked won")
	eq(int(world.run.stats["bosses"]), 6, "all six bosses defeated (two a world)")
	eq(world.run.world, 2, "and it ended in World 3")
