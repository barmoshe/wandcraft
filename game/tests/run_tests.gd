extends SceneTree
## Headless test runner (no plugins). Loads every tests/unit/test_*.gd, calls each test_* method
## on a fresh instance, and exits non-zero on any failure.
## Run: godot --headless --path game -s res://tests/run_tests.gd [-- --only=name]

var failures := 0
var passed := 0
var current := ""


func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var dir := DirAccess.open("res://tests/unit")
	var files := Array(dir.get_files()).filter(func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for f in files:
		if only != "" and not String(f).contains(only):
			continue
		var script: GDScript = load("res://tests/unit/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var inst: Object = script.new()
			if inst.has_method("setup"):
				inst.call("setup", self)
			current = "%s::%s" % [f, name]
			inst.set("runner", self)
			var before := failures
			await inst.call(name)
			if failures == before:
				passed += 1
			else:
				print("  FAIL ", current)
			if inst.has_method("teardown"):
				inst.call("teardown")
			if inst is Node and is_instance_valid(inst):
				(inst as Node).queue_free()
	print("\nTESTS: %d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("[%s] %s" % [current, msg])
		printerr("    assert: ", msg)
