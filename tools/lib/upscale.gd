extends SceneTree
## Doubles every *-half.png in a folder with nearest-neighbour into the same name without
## "-half" (tools/store_shots.sh). Args after --: <folder> <factor>
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var k := int(args[1]) if args.size() > 1 else 2
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with("-half.png"):
			continue
		var img := Image.load_from_file(dir.path_join(f))
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
		img.convert(Image.FORMAT_RGB8)   # the App Store refuses alpha
		img.save_png(dir.path_join(f.replace("-half.png", ".png")))
		print("upscale: %s %s" % [f, img.get_size()])
	quit()
