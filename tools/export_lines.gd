extends SceneTree
## Dumps every voiced line from Story (the one place lines are written) as JSON for
## tools/gen_voices.py: [{id, file, who, text}]. Run by tools/voices.sh:
##   godot --headless --path game -s res://../tools/export_lines.gd -- <out.json>


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if not args.is_empty() else "voice_lines.json"
	# loaded here, not named: under -s the autoloads Story needs exist only once the tree runs
	var story: GDScript = load("res://scripts/sim/story.gd")
	var rows: Array = story.all_lines().map(func(l: Dictionary) -> Dictionary:
		return {"id": l["id"], "file": story.file_id(l["id"]), "who": l["who"], "text": l["text"]})
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(rows, "  "))
	f.close()
	print("export_lines: %d lines -> %s" % [rows.size(), out_path])
	quit()
