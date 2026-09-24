extends RefCounted
## Base for tests: `runner` is set by run_tests.gd.
var runner: Object


func ok(cond: bool, msg: String) -> void:
	runner.call("check", cond, msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	runner.call("check", a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])


static func wand(ids: Array, wand_id := &"apprentice") -> WandState:
	var w := WandState.make(Catalog.wand(wand_id))
	w.set_slots(ids)
	return w
