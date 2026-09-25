extends "res://tests/unit/test_helpers.gd"
## Design v3 V0: the local play log keeps what a playtest needs.


func setup(_t: SceneTree) -> void:
	SaveGame.in_memory = true


func teardown() -> void:
	SaveGame.in_memory = false


func test_a_run_is_logged_room_by_room() -> void:
	var r := RunState.create(4)
	RunLog.start(r)
	r.step = 1
	RunLog.room_entered(r, &"fight")
	r.stats["time"] = 42.0
	r.hp -= 12.0
	RunLog.room_cleared(r)
	RunLog.pick(&"spell", [{"t": &"spell", "id": &"empower"}, {"t": &"spell", "id": &"fan"}], {"t": &"spell", "id": &"fan"})
	RunLog.edited()
	RunLog.finish(r, "shot:weaver")
	var last: Dictionary = RunLog.load_all().back()
	eq(last["hero"], "apprentice", "the hero")
	eq(last["rooms"][0]["t"], 42.0, "time in the room")
	eq(last["rooms"][0]["hp_lost"], 12, "HP lost in it")
	eq(last["picks"][0]["took"], "fan", "what was taken")
	eq(last["edits"], 1, "edits counted")
	eq(last["killed_by"], "shot:weaver", "what ended it")
	eq(last["result"], "death", "a death")
