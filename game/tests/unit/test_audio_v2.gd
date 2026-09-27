extends "res://tests/unit/test_helpers.gd"
## Sound v2 runtime (research/sound-v2.md §6, research/sound-v2-runtime-audit.md §3): the voice
## manager (budget, merging, priority steals, the hurt reserve), the variant picker, pitch
## walks, snapshots and settings, the bar clock, intensity hysteresis, telegraph alignment,
## still-hazard routing, quiet sandboxes and cue coverage.

const DT := 1.0 / 60.0


func setup(_tree: SceneTree) -> void:
	Audio.apply({"sound": true, "music": true, "heartbeat": true})
	Audio.reset()


func teardown() -> void:
	Audio.reset()
	Audio.music("", 0.0)
	Audio.snapshot(&"play")
	Audio.apply(Game.settings())


func _busy(cls: String, id: String) -> bool:
	return Audio.voices_busy(cls).has(id)


func test_a_storm_merges_and_the_budget_keeps_the_highest() -> void:
	# 200 hits and 50 booms in one frame are two requests, not 250
	for i in 200:
		Audio.sfx("hit", Vector2(i, 0))
	for i in 50:
		Audio.sfx("boom", Vector2(0, i))
	var started := Audio.flush()
	eq(started, 2, "a storm of two cues starts two voices")
	ok(_busy("cmb", "boom") and _busy("cmb", "hit"), "the boom and one merged hit play")
	# twelve different cues in one frame: only the budget's worth start, the highest first
	Audio.reset()
	var ids := ["crate", "pod_pop", "bramble_burn", "crack_open", "secret", "pit_fall", "chest", "door",
		"dash", "charge", "bonk", "summon"]
	for id in ids:
		Audio.sfx(id, Vector2.ZERO)
	var n := Audio.flush()
	eq(n, Audio.BUDGET_NATIVE, "no more than the per-frame budget starts")
	ok(_busy("cmb", "charge") and _busy("cmb", "secret"), "the higher priorities won the budget")
	ok(not _busy("cmb", "bramble_burn"), "the lowest priority waited out this frame")


func test_steals_take_the_weakest_and_never_outrank() -> void:
	var fill := ["crate", "pod_pop", "bramble_burn", "crack_open", "secret", "pit_fall", "chest", "door",
		"dash", "charge", "bonk", "summon", "ward_up", "spawn"]
	for k in 2:
		for i in range(k * 7, k * 7 + 7):
			Audio.sfx(fill[i], Vector2.ZERO)
		Audio.flush()
	eq(Audio.voices_busy("cmb").size(), 14, "the combat pool is full")
	Audio.sfx("boom", Vector2.ZERO)
	Audio.flush()
	ok(_busy("cmb", "boom"), "a boom (prio 70) gets a voice in a full pool")
	ok(not _busy("cmb", "bramble_burn"), "it took the weakest voice (bramble_burn, prio 45)")
	Audio.sfx("hit", Vector2.ZERO)
	Audio.flush()
	ok(not _busy("cmb", "hit"), "a hit (prio 40) cannot steal from anything louder in rank")


func test_one_critical_voice_is_kept_for_hurt() -> void:
	for id in ["phase", "roar", "bigboom", "derail", "kill_big"]:
		Audio.sfx(id)
	Audio.flush()
	eq(Audio.voices_busy("crit").size(), 5, "five moments fill the open Critical voices")
	Audio.sfx("slam", Vector2.ZERO)
	Audio.flush()
	ok(not _busy("crit", "slam"), "a slam cannot take the reserved voice or outrank a moment")
	Audio.sfx("hurt")
	Audio.flush()
	ok(_busy("crit", "hurt"), "hurt always has its voice")


func test_variants_never_repeat_and_casts_keep_their_heavy_one() -> void:
	var c: Object = Audio._cue("hit")
	var last := -1
	var seen := {}
	for i in 40:
		var k: int = Audio._pick(c)
		if k == last:
			ok(false, "no variant twice in a row (%d)" % k)
		last = k
		seen[k] = true
	eq(seen.size(), c.streams.size(), "every variant gets played")
	for i in 20:
		var k: int = Audio._pick(Audio._cue("cast_spark"))
		var hc: int = Audio._cue("cast_spark").heavy_idx
		ok(hc < 0 or k != hc, "a cast's heavy variant is never picked at random")


func test_walks_climb_the_key_s_pentatonic() -> void:
	var kill: Object = Audio._cue("kill")
	var steps := []
	for i in 8:
		steps.append(Audio._walk(kill, 0))
	eq(steps.slice(0, 6), [0.0, 3.0, 5.0, 7.0, 10.0, 12.0], "a kill streak climbs A C D E G A (Cellar key)")
	eq(steps[7], 12.0, "and holds at step 5")
	eq(Audio._walk(Audio._cue("cast_fire"), 2), 5.0, "a cast from slot 2 sits on the scale's third step")
	eq(Audio._walk(Audio._cue("trigger"), 2), 12.0, "a depth-2 trigger is an octave up")
	eq(Audio._walk(Audio._cue("pylon"), 3), 12.0, "the fourth pylon is the octave (A C E A')")
	eq(Audio._walk(Audio._cue("hit"), 3), 0.0, "hits never walk")


func test_snapshots_and_settings() -> void:
	var music := AudioServer.get_bus_index("Music")
	Audio.snapshot(&"pause")
	eq(Audio.current_snapshot(), &"menu", "pause is the menu snapshot")
	await runner.create_timer(0.45).timeout
	ok(AudioServer.is_bus_effect_enabled(music, 1), "the music's low-pass is on in a menu")
	ok(absf(Audio._lp_hz - 1200.0) < 1.0 and absf(AudioServer.get_bus_volume_db(music) + 4.0) < 0.3,
		"menu: 1.2 kHz and -4 dB (%.0f Hz, %.1f dB)" % [Audio._lp_hz, AudioServer.get_bus_volume_db(music)])
	Audio.snapshot(&"play")
	await runner.create_timer(0.6).timeout
	ok(not AudioServer.is_bus_effect_enabled(music, 1), "play: the low-pass is off (no cost)")
	eq(Audio.active_effects(), 3, "three bus effects run in plain play (limiter, two compressors)")
	# death: the sweep survives the music stopping (B4)
	Audio.music("cellar", 0.0)
	Audio.snapshot(&"dead")
	Audio.music("", 0.8)
	await runner.create_timer(0.3).timeout
	ok(AudioServer.is_bus_effect_enabled(music, 1) and Audio.current_snapshot() == &"dead",
		"the music fades out still closed after a death (no brightness pop)")
	Audio.snapshot(&"play")
	# settings (B1, B3): Sound mutes the world and the ambience, Music the score and stingers
	Audio.apply({"sound": false, "music": true})
	ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambience")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Critical")),
		"sound off mutes the ambience and Critical")
	ok(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Sting")), "stingers still play with sound off and music on")
	Audio.apply({"sound": true, "music": false})
	ok(AudioServer.is_bus_mute(AudioServer.get_bus_index("Sting")) and AudioServer.is_bus_mute(music), "music off mutes the stingers too")
	Audio.apply({"sound": true, "music": true})


func test_the_title_fades_the_ambience_out() -> void:
	Audio.ambience("cellar", 0.0)
	eq(Audio.ambience_name(), "cellar", "a room plays its bed")
	Audio.music("title", 0.0)
	eq(Audio.ambience_name(), "", "the title stops it (B2)")


func test_layers_land_on_the_bar() -> void:
	Audio.music("cellar", 0.0)
	await runner.create_timer(0.7).timeout
	var clk := Audio.bar_clock()
	ok(float(clk.get("pos", 0.0)) > 0.3, "the music clock runs from the player's position (%.2f s)" % float(clk.get("pos", 0.0)))
	var wait := Audio.layer("drums", true)
	var bar: float = clk["bar"]
	var due := fposmod(Audio.layer_due("drums"), bar)
	ok(due < 0.02 or due > bar - 0.02, "the drums are due on a barline (phase %.3f of %.2f s)" % [due, bar])
	await runner.create_timer(wait + 0.25).timeout
	var sync: AudioStreamSynchronized = Audio.track_stream("cellar")
	ok(sync.get_sync_stream_volume(1) > -1.0, "and they are in once it passes")
	Audio.music("", 0.0)


func test_intensity_steps_down_only_after_its_hold() -> void:
	Audio.music("cellar", 0.0)
	Audio.intensity(2)
	eq(Audio.intensity_level(), 2, "up at once")
	Audio.intensity(0)
	Audio._update_intensity(1.0)
	eq(Audio.intensity_level(), 2, "a lull between waves keeps the drums and lead")
	Audio._update_intensity(1.1)
	eq(Audio.intensity_level(), 0, "down after the 2 s hold")
	Audio.intensity(1)
	Audio.intensity(0, true)
	eq(Audio.intensity_level(), 0, "a room clear drops it at once")
	Audio.music("", 0.0)


func test_telegraphs_end_on_the_release() -> void:
	for id in ["tele", "tele_charge", "tele_slam", "tele_boss", "copy_cast", "select_all"]:
		if Audio._cue(id).streams.is_empty():
			continue
		var ln: float = Audio._cue(id).lengths[0]
		for total in [0.3, 0.51, 0.8, 1.2]:
			var left: float = total
			var prev := INF
			var starts := 0
			var end := -1.0
			var t := 0.0
			while left > -DT:
				var off: float = Audio.tele_offset(id, left, prev)
				if off >= 0.0:
					starts += 1
					end = t + (ln - off)
				prev = left
				left -= DT
				t += DT
			eq(starts, 1, "%s over a %.2f s wind-up starts once" % [id, total])
			ok(absf(end - total) <= DT + 0.001, "%s over a %.2f s wind-up ends on the release (%.3f)" % [id, total, end])
	eq(Audio.tele_for_ai(&"charge"), "tele_charge", "charges have their own telegraph")
	eq(Audio.tele_for_ai(&"fuse", true), "tele_charge", "Kernel Panic's run is a charge")
	eq(Audio.tele_for_move(&"select_all"), "select_all", "Select All winds up with its signature")
	eq(Audio.tele_for_move(&"volley"), "tele_boss", "other boss moves use the generic boss wind-up")


func test_still_hazards_do_not_fire_shot_sounds() -> void:
	for i in 10:
		Audio.enemy_shot("eshot", "trail:Loop", Vector2(i, 0))
		Audio.enemy_shot("eshot", "thorns:thorn_ram", Vector2(i, 0))
		Audio.enemy_shot("eshot", "trash:Garbage Collector", Vector2(i, 0))
		Audio.enemy_shot("eshot", "box:Copy-Paste", Vector2(i, 0))
	var queued := Audio._queue.map(func(c: Object) -> String: return c.id)
	queued.sort()
	eq(queued, ["box_fill", "thorns", "trash"], "one cue per hazard, none for the trail, never an eshot")
	Audio.reset()
	Audio.enemy_shot("eshot", "copy:ember", Vector2.ZERO)
	eq(Audio._queue[0].id, "copy:cast_fire", "a copied Ember sounds like your Ember")
	eq(Audio._queue[0].bus, "Glitch", "through the Glitch bus")


func test_a_quiet_sandbox_makes_no_sound() -> void:
	Game.quiet += 1
	Audio.sfx("hit", Vector2.ZERO)
	Audio.ui("ui")
	Audio.player_hp(0.1)
	Game.quiet -= 1
	eq(Audio.flush(), 0, "nothing reaches the mix from the firing range")


func test_one_tap_makes_one_sound() -> void:
	Audio.ui("ui")
	Audio.sfx("pick")
	Audio.ui("ui_close")
	Audio.flush()
	var ui := Audio.voices_busy("ui")
	ok(ui.size() == 1 and ui[0] == "pick", "a screen's own sound replaces the default press and close (B13): %s" % [ui])
	Audio.reset()
	Audio.ui("ui_back")
	Audio.ui("ui_close")
	Audio.flush()
	eq(Audio.voices_busy("ui").size(), 1, "two defaults in a frame make one sound")


func test_every_cue_is_played_somewhere_and_every_file_has_a_cue() -> void:
	# every effect on disk has a table row (or is a retired id awaiting regeneration)
	for f in DirAccess.get_files_at("res://assets/audio/"):
		if f.begins_with("sfx_") and f.ends_with(".wav"):
			var b := f.trim_prefix("sfx_").get_basename().trim_suffix("_heavy")
			var parts := b.split("_")
			if parts.size() > 1 and parts[parts.size() - 1].is_valid_int():
				parts.remove_at(parts.size() - 1)
			var id := "_".join(parts)
			ok(Audio.CUES.has(id) or id in Audio.RETIRED, "sfx_%s has a cue-table row" % id)
	# every table id is named by a call site or a map (sound-v2 DOG 8), unless hook_pending
	var said := {}
	var re := RegEx.create_from_string("\"([a-z0-9_]+)\"")
	for path in _scripts("res://scripts"):
		var src := FileAccess.get_file_as_string(path)
		if path.ends_with("autoload/audio.gd"):
			var a := src.find("const CUES := {")
			var b := src.find("## Cues made from")
			src = src.substr(0, a) + src.substr(b)
		for m in re.search_all(src):
			said[m.get_string(1)] = true
	for id: String in Audio.CUES:
		if not bool(Audio._row(id)["hook_pending"]):
			ok(said.has(id), "cue %s has a call site" % id)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
