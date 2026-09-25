extends "res://tests/unit/test_helpers.gd"
## D8: the loudness meter, the licence manifest, loudness targets, music tracks and layers,
## voice classes and element hits.

const AUDIO := "res://assets/audio/"


func _wavs() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(AUDIO):
		if f.ends_with(".wav"):
			out.append(f)
	return out


## The source file as 16-bit PCM (the imported one is QOA-compressed).
func _raw(file: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(AUDIO + file))


func test_the_meter_reads_the_bs1770_calibration_tone() -> void:
	# BS.1770: a 997 Hz sine at full scale in one channel reads -3.01 LKFS; at -20 dBFS, -23.01
	for rate in [32000, 44100]:
		var buf := PackedFloat32Array()
		buf.resize(rate * 3)
		for i in buf.size():
			buf[i] = 0.1 * sin(TAU * 997.0 * i / rate)
		var l := Loudness.lufs(buf, rate)
		ok(absf(l - -23.01) < 0.15, "a -20 dBFS 997 Hz tone reads -23.0 LUFS at %d Hz (%.2f)" % [rate, l])
	var quiet := PackedFloat32Array()
	quiet.resize(32000)
	ok(Loudness.lufs(quiet, 32000) == -INF, "silence reads -inf")


func test_every_audio_file_is_in_the_licence_manifest() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../assets_src/audio/LICENSES.csv")
	var f := FileAccess.open(path, FileAccess.READ)
	ok(f != null, "the manifest exists at assets_src/audio/LICENSES.csv")
	if f == null:
		return
	var header := f.get_csv_line()
	ok(Array(header) == ["file", "title", "source", "license", "author", "credit_required"], "the manifest has its columns")
	var rows := {}
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 6:
			rows[r[0]] = r
	for w in _wavs():
		ok(rows.has(w), "%s has a manifest row" % w)
	for k in rows:
		var r: PackedStringArray = rows[k]
		ok(not r[3].to_lower().contains("nc"), "%s is not a non-commercial licence" % k)
		if r[3].to_upper().begins_with("CC-BY"):
			ok(r[4] != "" and r[5] == "yes", "%s: a CC-BY row names its author and asks for credit" % k)


func test_sounds_sit_on_their_loudness_targets() -> void:
	var off := []
	for w in _wavs():
		var s := _raw(w)
		var buf := Loudness.samples(s)
		var peak := Loudness.peak_db(buf)
		ok(peak <= -1.0, "%s peaks under -1 dBFS (%.1f)" % [w, peak])
		if w.begins_with("sfx_"):
			var target := -24.0 if w.trim_prefix("sfx_").get_basename().rstrip("_23") in Audio.UI or w.begins_with("sfx_coin") else -18.0
			var l := Loudness.lufs(buf, s.mix_rate)
			# on target, or as loud as the peak ceiling allows (a sharp transient reaches the
			# ceiling first); never over the target
			if l > target + 1.0 or (l < target - 1.0 and peak < -2.5):
				off.append("%s %.1f LUFS, peak %.1f" % [w, l, peak])
	ok(off.is_empty(), "every effect within its loudness target: %s" % [off])


func test_music_tracks_build_and_their_layers_switch() -> void:
	for t in Audio.TRACKS:
		ok(Audio.track_stream(t) != null, "track %s builds" % t)
	ok(Audio.track_stream("cellar") is AudioStreamSynchronized, "the Cellar is synchronized stems")
	ok(Audio.track_stream("boss") is AudioStreamInteractive, "the boss is an intro that hands over to its loop")
	# stems that loop under a longer base must be a whole number of bars
	for pair in [["music_cellar_drums", 120.0], ["music_cellar_lead", 120.0], ["music_boss_p2", 128.0]]:
		var s := _raw(pair[0] + ".wav")
		var bar := int(round(4.0 * 60.0 / float(pair[1]) * s.mix_rate))
		ok(Loudness.samples(s).size() % bar == 0, "%s is whole bars" % pair[0])
	Audio.music("cellar", 0.0)
	var sync: AudioStreamSynchronized = Audio.track_stream("cellar")
	ok(sync.get_sync_stream_volume(1) <= -50.0, "the drums start off")
	Audio.layer("drums", true, 0.0)
	ok(Audio.layer_on("drums"), "combat turns the drums on")
	Audio.music("", 0.0)


func test_voice_classes_and_element_hits() -> void:
	ok(Audio.voice_class("hurt") == "critical" and Audio.voice_class("tele_mid") == "critical", "hurt and telegraphs are critical")
	ok(Audio.voice_class("ui_equip") == "ui", "menu sounds are ui")
	ok(Audio.voice_class("hit") == "combat", "hits are combat")
	ok(Audio.hit_for(&"ember") == "hit_fire" and Audio.hit_for(&"frost") == "hit_ice", "fire and ice hits sound like fire and ice")
	ok(Audio.hit_for(&"mote") == "hit", "a plain bolt makes a plain hit")
	ok(Audio.stream("sfx_hit") is AudioStreamRandomizer, "a sound with variants plays through a randomizer")
	for s in ["clear", "reward", "boss", "victory", "defeat"]:
		ok(ResourceLoader.exists(AUDIO + "sting_%s.wav" % s), "the %s stinger exists" % s)
	var names := 0
	for w in _wavs():
		if w.begins_with("sfx_") and not (w.ends_with("_2.wav") or w.ends_with("_3.wav")):
			names += 1
	ok(names >= 70, "about 70 distinct sound effects (%d)" % names)
