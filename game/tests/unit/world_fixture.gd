extends "res://tests/unit/test_helpers.gd"
## Shared fixture for simulation tests: the world stepped headless at 60 Hz, no rendering.

const DT := 1.0 / 60.0
var world: World


func setup(tree: SceneTree) -> void:
	Game.god_mode = true
	Game.inf_mana = false
	Game.auto_fire = false
	SaveGame.enabled = false
	world = World.new()
	world.auto_step = false
	tree.root.add_child(world)
	world.setup(1234)
	world.start_run(RunState.create(1234))


func teardown() -> void:
	Game.god_mode = false
	Game.inf_mana = false
	Game.auto_fire = true
	SaveGame.enabled = true
	world.free()


func _steps(seconds: float) -> void:
	for i in int(seconds / DT):
		world.step(DT)


## A still target dummy with lots of HP.
func _dummy(pos: Vector2) -> Enemy:
	var e := world.spawn_enemy(&"slime", pos)
	e.ai = &"dummy"
	e.spawn_t = 0.0
	e.sprite.visible = true
	e.max_hp = 99999.0
	e.hp = e.max_hp
	e.dmg = 0.0
	return e


func _range_setup() -> void:
	# an empty, cleared room so waves do not interfere
	world.build_room("hall", &"empty")
	world.player.position = Vector2(208, 216)
	for p in [Vector2(208, 176), Vector2(208, 150), Vector2(186, 140), Vector2(230, 140)]:
		_dummy(p)


func _fire(ids: Array, wand_id := &"apprentice", ang := -PI / 2.0) -> WandState:
	var w := WandState.make(Catalog.wand(wand_id))
	w.set_slots(ids)
	world.run.wands[0] = w
	world.run.cur = 0
	world.damage_done = 0.0
	world.spells.cast_seq = 0
	world.player.aim = ang
	world.hash.rebuild(world.enemies)
	world.spells.wand_fire(w, world.player.tip(), ang)
	return w
