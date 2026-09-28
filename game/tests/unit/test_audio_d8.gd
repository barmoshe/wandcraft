extends "res://tests/unit/test_helpers.gd"
## D8 and sound v2: the loudness meter, the licence manifest, loudness targets (v1 files: the
## flat -18/-24; v2 files: the families of research/sound-v2.md §4.1), music tracks, whole-bar
## stems and layers, voice classes and element hits.

const AUDIO := "res://assets/audio/"
## v1 (tools/gen_audio.gd UI_SOUNDS): the files normalised to -24 LUFS; every other effect -18.
const V1_UI := ["ui", "ui_back", "swap", "deny", "coin", "ui_open", "ui_close", "ui_equip", "ui_drag", "ui_drop", "buy"]
## sound-v2 §4.1: each family's momentary-max loudness target (LUFS-M).
const FAMILY_LUFS := {"W": -30.0, "C": -24.0, "C+": -22.0, "E": -20.0, "A": -17.0, "M": -15.0, "U": -24.0, "U+": -21.0}
## The v2 effects are on disk once a cue only v2 has is (the generators write them together).
const V2_SFX_MARKER := "sfx_tele_charge.wav"


func _wavs() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(AUDIO):
		if f.ends_with(".wav"):
			out.append(f)
	return out


## The music and ambience files (Ogg Vorbis since ADR 0034).
func _oggs() -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(AUDIO):
		if f.ends_with(".ogg"):
			out.append(f)
	return out


## Plays an Ogg through the engine from sample `from` for `frames` samples, one output frame
## per stream sample (the rate scale cancels the resampling, so nothing is interpolated).
static func _play(o: AudioStreamOggVorbis, from: int, frames: int) -> PackedVector2Array:
	var sr := o.packet_sequence.sampling_rate
	var pb := o.instantiate_playback()
	pb.start((from + 0.25) / sr)   # a quarter sample in: the engine truncates to the sample
	var out := PackedVector2Array()
	while out.size() < frames:
		out.append_array(pb.mix_audio(AudioServer.get_mix_rate() / sr, mini(4096, frames - out.size())))
	return out


## The source file as 16-bit PCM (the imported one is QOA-compressed).
func _raw(file: String) -> AudioStreamWAV:
	return AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(AUDIO + file))


## A cue id from an effect's file name (sfx_hit_2.wav -> hit).
static func _cue_of(file: String) -> String:
	var b := file.trim_prefix("sfx_").get_basename().trim_suffix("_heavy")
	var parts := b.split("_")
	if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
		parts.remove_at(parts.size() - 1)
	return "_".join(parts)


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
	for w in _wavs() + _oggs():
		ok(rows.has(w), "%s has a manifest row" % w)
	for k in rows:
		var r: PackedStringArray = rows[k]
		ok(not r[3].to_lower().contains("nc"), "%s is not a non-commercial licence" % k)
		if r[3].to_upper().begins_with("CC-BY"):
			ok(r[4] != "" and r[5] == "yes", "%s: a CC-BY row names its author and asks for credit" % k)


func test_sounds_sit_on_their_loudness_targets() -> void:
	var v2 := ResourceLoader.exists(AUDIO + V2_SFX_MARKER)
	var off := []
	for w in _wavs():
		var s := _raw(w)
		var buf := Loudness.samples(s)
		var peak := Loudness.peak_db(buf)
		ok(peak <= -1.0, "%s peaks under -1 dBFS (%.1f)" % [w, peak])
		if not w.begins_with("sfx_"):
			continue
		var id := _cue_of(w)
		if v2:
			# sound-v2 DOG 1: within 1 LU of the family's momentary max, or at the true-peak
			# ceiling and at most 3 LU under; never over by more than 1 LU
			var row := Audio._row(id)
			var fam := String(row["fam"])
			if (fam == "" and float(row["lufs"]) == 0.0) or id in Audio.RETIRED:
				continue
			var target: float = float(row["lufs"]) if float(row["lufs"]) != 0.0 else float(FAMILY_LUFS[fam])
			var m := Loudness.momentary_max(buf, s.mix_rate)
			var tp := Loudness.true_peak_db(buf, s.mix_rate)
			if m > target + 1.0 or (m < target - 1.0 and not (tp >= -1.2 and m >= target - 3.0)):
				off.append("%s (%s) %.1f LUFS-M, true peak %.1f" % [w, fam, m, tp])
		else:
			var target := -24.0 if id in V1_UI else -18.0
			var l := Loudness.lufs(buf, s.mix_rate)
			# on target, or as loud as the peak ceiling allows (a sharp transient reaches the
			# ceiling first); never over the target
			if l > target + 1.0 or (l < target - 1.0 and peak < -2.5):
				off.append("%s %.1f LUFS, peak %.1f" % [w, l, peak])
	ok(off.is_empty(), "every effect within its loudness target: %s" % [off])


func test_music_tracks_build_and_their_layers_switch() -> void:
	for t in Audio.TRACKS:
		if Audio.track_ready(t):
			ok(Audio.track_stream(t) != null, "track %s builds" % t)
	ok(Audio.track_stream("cellar") is AudioStreamSynchronized, "the Cellar is synchronized stems")
	if Audio.music_v2():
		ok(Audio.track_stream("boss") is AudioStreamSynchronized, "the boss is stems with its intro folded in (a readable clock)")
	else:
		ok(Audio.track_stream("boss") is AudioStreamInteractive, "the v1 boss is an intro that hands over to its loop")
	# stems that loop under a longer base must be a whole number of bars at the track's tempo,
	# measured from the loop point where the intro is folded in (sound-v2 DOG 6). The stems are
	# Ogg (ADR 0034): the engine plays to the end and seeks back to loop_offset, the intro's end.
	for t in Audio.TRACKS:
		var def: Dictionary = Audio.TRACKS[t]
		if def.get("layers", []).is_empty() or not Audio.track_ready(t):
			continue
		var bar := 4.0 * 60.0 / Audio.track_bpm(t)
		var intro := float(def.get("intro_s", 0.0))
		ok(absf(intro / bar - roundf(intro / bar)) < 1e-6, "%s: the loop point is whole bars" % t)
		for m: String in def["stems"]:
			var path := Audio.audio_path(m)
			if not ResourceLoader.exists(path):
				continue
			var o := load(path) as AudioStreamOggVorbis
			ok(o != null, "%s ships as Ogg Vorbis" % m)
			if o == null:
				continue
			ok(o.loop, "%s loops" % m)
			ok(absf(o.loop_offset - intro) < 1e-6, "%s loops back to the end of its intro (%.3f s)" % [m, o.loop_offset])
			var bars := (o.get_length() - o.loop_offset) / bar
			# within half a 32 kHz sample of whole bars
			ok(absf(bars - roundf(bars)) * bar < 0.5 / 32000.0, "%s loops whole bars at %d bpm (%.4f)" % [m, Audio.track_bpm(t), bars])
	Audio.music("cellar", 0.0)
	var sync: AudioStreamSynchronized = Audio.track_stream("cellar")
	ok(sync.get_sync_stream_volume(1) <= -50.0, "the drums start off")
	Audio.layer("drums", true)
	ok(Audio.layer_on("drums"), "combat turns the drums on")
	Audio.music("", 0.0)


## ADR 0034: every music and ambience Ogg loops seamlessly. Played through the engine across
## its seam, what follows the end is sample for sample a playback started at the loop point
## (the end of the track's intro, else the start: no gap, no drift, the intro never replays),
## and the step across the seam is no bigger
## than the music's own steps. The stingers are one-shots.
func test_music_loops_are_seamless() -> void:
	# where each file should loop back to: the end of its track's intro, else its start
	var intro := {}
	for t in Audio.TRACKS:
		for m: String in Audio.TRACKS[t]["stems"]:
			intro[m + ".ogg"] = float(Audio.TRACKS[t].get("intro_s", 0.0))
	var n := 0
	var bad := []
	for f in _oggs():
		var o := load(AUDIO + f) as AudioStreamOggVorbis
		if o == null or not o.loop:
			bad.append("%s does not load as a looping Ogg" % f)
			continue
		var sr := o.packet_sequence.sampling_rate
		var lead := int(0.2 * sr)
		var end := int(round(o.get_length() * sr))
		var lb := int(round(float(intro.get(f, 0.0)) * sr))
		var across := _play(o, end - lead, 2 * lead)
		var fresh := _play(o, lb, lead)
		var diff := 0.0
		for i in range(4, lead):   # past the resampler's first frames
			var d := (across[lead + i] - fresh[i]).abs()
			diff = maxf(diff, maxf(d.x, d.y))
		var step := 0.0
		var body := 0.0
		for i in range(1, across.size()):
			var d := (across[i] - across[i - 1]).abs()
			if absi(i - lead) <= 2:
				step = maxf(step, maxf(d.x, d.y))
			else:
				body = maxf(body, maxf(d.x, d.y))
		if diff > 1e-5:
			bad.append("%s: after the seam it is %.5f off a playback from its loop point" % [f, diff])
		if step > body:
			bad.append("%s: the seam steps %.4f (the music's own biggest step is %.4f)" % [f, step, body])
		n += 1
	ok(n >= 20, "the music ships as Ogg (%d files)" % n)
	ok(bad.is_empty(), "every music loop is seamless: %s" % [bad])
	for w in _wavs():
		if w.begins_with("sting_"):
			var s: AudioStreamWAV = load(AUDIO + w)
			ok(s.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s plays once" % w)


func test_voice_classes_and_element_hits() -> void:
	ok(Audio.voice_class("hurt") == "crit" and Audio.voice_class("tele") == "crit", "hurt and telegraphs are critical")
	ok(Audio.voice_class("ui_equip") == "ui", "menu sounds are ui")
	ok(Audio.voice_class("hit") == "cmb" and Audio.voice_class("burn") == "det", "hits are combat, burn ticks detail")
	ok(Audio.hit_for(&"ember") == "hit_fire" and Audio.hit_for(&"frost") == "hit_ice", "fire and ice hits sound like fire and ice")
	ok(Audio.hit_for(&"mote") == "hit", "a plain bolt makes a plain hit")
	ok(Audio.hit_for_bullet(&"mote", 1, 0, false, 0) == "hit_fire", "an Ember-coated bolt hits like fire")
	ok(Audio.hit_for_bullet(&"ember", 1, 1, true, 2) == "hit_rot", "coats rank rot > static > chill > burn")
	ok(Audio.hit_for_bullet(&"frost", 0, 0, false, 0) == "hit_ice", "no coat: the spell's own element")
	ok(Audio._cue("hit").streams.size() >= 3, "a sound with variants has them all")
	for s in ["clear", "reward", "boss", "victory", "defeat"]:
		ok(ResourceLoader.exists(AUDIO + "sting_%s.wav" % s), "the %s stinger exists" % s)
	var names := {}
	for w in _wavs():
		if w.begins_with("sfx_"):
			names[_cue_of(w)] = true
	ok(names.size() >= 70, "about 70 distinct sound effects (%d)" % names.size())
