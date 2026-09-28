extends "res://tests/unit/test_helpers.gd"
## The download budget for sound (0.22 speed and size, tools/size_report.sh): the imported
## voice + audio files (what the web .pck ships) must stay under BUDGET_MB, and speech must
## keep its shrinking import settings (mono, 22.05 kHz, QOA).
##
## Measured 2026-09-28: voice 13.00 MB (629 files) + audio 13.74 MB (398 files) = 26.74 MB,
## after the voices moved to 22.05 kHz (voice was 14.13 MB at 24 kHz). The budget leaves about
## 1.3 MB for new lines and cues; raising it is a decision, not a fix (check size_report first).

const BUDGET_MB := 28.0
const DIRS := ["res://assets/voice/", "res://assets/audio/"]


## Bytes of every imported file under dir, and how many there are.
func _imported(dir: String) -> Vector2i:
	var total := 0
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".wav.import"):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(dir + f) != OK:
			continue
		var path: String = cfg.get_value("remap", "path", "")
		var fa := FileAccess.open(path, FileAccess.READ)
		if fa:
			total += fa.get_length()
			n += 1
	return Vector2i(total, n)


func test_imported_audio_fits_the_budget() -> void:
	var total := 0
	for dir: String in DIRS:
		var r := _imported(dir)
		ok(r.y > 100, "%s has its imported files (%d found; run the import)" % [dir, r.y])
		total += r.x
	var mb := total / 1e6
	ok(mb <= BUDGET_MB, "imported voice + audio is %.2f MB (budget %.1f MB; see tools/size_report.sh)" % [mb, BUDGET_MB])


func test_voices_import_small() -> void:
	var dir := "res://assets/voice/"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".wav.import"):
			continue
		var cfg := ConfigFile.new()
		cfg.load(dir + f)
		var small: bool = cfg.get_value("params", "force/mono", false) and cfg.get_value("params", "force/max_rate", false) \
			and int(cfg.get_value("params", "force/max_rate_hz", 0)) == 22050 and int(cfg.get_value("params", "compress/mode", 0)) == 2
		if not small:
			ok(false, "%s imports mono, 22.05 kHz, QOA (tools/voices.sh writes it)" % f)
			return
	ok(true, "")
