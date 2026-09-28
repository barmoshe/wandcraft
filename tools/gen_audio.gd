extends SceneTree
## Sound v2 (research/sound-v2.md §4): renders every sound effect to game/assets/audio/sfx_*.wav.
## The music is gen_music.gd. Run: tools/audio.sh (godot --headless --path game -s <abs path>).
## ONLY=<id>,<id> renders just those cues and deletes nothing (for working on a few; the .import
## files and the manifest still need tools/audio.sh).
##
## Every sound is synthesised here from the shared toolkit tools/lib_dsp.gd (§3): envelopes,
## pitch envelopes, band-limited oscillators, the sigil, state-variable filters, saturation and
## the phantom fundamental, FM, Karplus-Strong, modal banks (stone, wood, brass, glass, plate,
## bell), grains, crackle, whooshes, combs and a small baked room. Nothing is sampled or
## downloaded, so every sound is original (ADR 0002, ADR 0019).
##
## The sonic brief (§2): a physical material struck by a digital pulse. Every cast carries the
## sigil at A6 so the wand's slot walk plays one instrument; threats (telegraphs, enemy shots,
## hurt) own the 330-1200 Hz band (R1) and dense chatter (casts, hits) leaves it empty; the crit
## is the only combat cue that rings in 2.2-3.6 kHz (R2); low bodies carry their weight to a
## phone speaker through saturated harmonics (the phantom fundamental), not through sub-bass.
##
## Files: sfx_<id>.wav, then sfx_<id>_2.wav ... for recipe variants (the runtime picks one, never
## the same twice). Casts also get sfx_<id>_heavy.wav (Heavy / Empower: an extra saturated 300 Hz
## body). The telegraph masters are 1.5 s, played from (1.5 - wind-up) so each ends on the
## attack's release; `beam` and `trail_loop` are seamless loops. Ambience spots (amb_*) are
## 22.05 kHz; everything else 44.1 kHz mono 16-bit.
##
## Levels (§4.1): each file is scaled so its maximum momentary loudness (Loudness.momentary_max,
## LUFS-M) sits on its family's target, capped at a true peak of -1.0 dBTP. The loudness
## hierarchy lives in the files: hurt and telegraphs are louder than kills, kills louder than
## hits, hits louder than casts, the world quietest.
##
## Deterministic: every random stream is seeded per (cue, variant, layer), so adding or
## reordering a cue never changes another cue's bytes, and two runs write identical bytes.
## Retired files (sfx_*.wav this run did not write) are deleted with their .import files.

const D := preload("lib_dsp.gd")
const SR := 44100
const SR_AMB := 22050
const OUT := "res://assets/audio/"
const TP_CEIL := -1.05   # dBTP: the -1.0 cap with a hair of margin for 16-bit rounding
const HP_SFX := 70.0     # the mandatory output high-pass (§3.5)
const TELE_S := 1500.0   # ms: the telegraph masters' hard stop, the moment of release

## Family targets, LUFS-M (§4.1).
const FAMILY := {"W": -30.0, "C": -24.0, "C+": -22.0, "E": -20.0, "A": -17.0, "M": -15.0, "U": -24.0, "U+": -21.0}

## Every cue: id -> [family, variants, flags, LUFS-M override (0 = the family's)]. Flags: "heavy"
## (casts: also a _heavy variant), "gap" (dense chatter: leaves R1 empty), "loop" (a seamless
## loop), "tele" (a 1.5 s offset-played telegraph master), "amb" (22.05 kHz ambience spot).
const CUES := {
	# ---- casts (§4.2): family C, the sigil first
	"cast_spark": ["C", 3, "heavy gap", 0.0],
	"cast_laser": ["C", 3, "heavy gap", 0.0],
	"cast_needle": ["C", 3, "heavy gap", 0.0],
	"cast_fan": ["C", 3, "heavy gap", 0.0],
	"cast_missile": ["C", 3, "heavy gap", 0.0],
	"cast_carry": ["C", 3, "heavy gap", 0.0],
	"cast_orbit": ["C", 2, "heavy gap", 0.0],
	"cast_boom": ["C", 3, "heavy", 0.0],
	"cast_mine": ["C", 2, "heavy gap", 0.0],
	"cast_fire": ["C", 3, "heavy gap", 0.0],
	"cast_wall": ["C", 2, "heavy gap", 0.0],
	"cast_ice": ["C", 3, "heavy gap", 0.0],
	"cast_chain": ["C", 3, "heavy gap", 0.0],
	"cast_static": ["C", 3, "heavy gap", 0.0],
	"cast_arcane": ["C", 3, "heavy gap", 0.0],
	"cast_ping": ["C", 2, "heavy gap", 0.0],
	"cast_rot": ["C", 2, "heavy gap", 0.0],
	"cast_void": ["C", 2, "heavy", 0.0],
	"cast_summon": ["C", 2, "heavy gap", 0.0],
	"trigger": ["C", 2, "gap", 0.0],
	"cast_delayed": ["W", 1, "gap", -28.0],
	"fizzle": ["C", 2, "", 0.0],
	"familiar_end": ["C", 1, "", 0.0],
	"duck_soak": ["C", 3, "", 0.0],
	# ---- hits, crits, defences (§4.3)
	"hit": ["C", 4, "gap", 0.0],
	"crit": ["E", 3, "", 0.0],
	"hit_heavy": ["C", 3, "", 0.0],
	"hit_fire": ["C", 4, "gap", 0.0],
	"hit_ice": ["C", 4, "gap", 0.0],
	"hit_static": ["C", 4, "gap", 0.0],
	"hit_arcane": ["C", 3, "gap", 0.0],
	"hit_void": ["C", 3, "gap", 0.0],
	"hit_rot": ["C", 3, "gap", 0.0],
	"hit_armor": ["C+", 3, "gap", 0.0],
	"hit_ward": ["C+", 3, "gap", 0.0],
	"hit_shield": ["C+", 3, "gap", 0.0],
	"armor_break": ["A", 2, "", 0.0],
	"shield_break": ["A", 2, "", 0.0],
	"locked": ["C+", 2, "", 0.0],
	"ward_break": ["A", 2, "", 0.0],
	# ---- kills and explosions (§4.4)
	"kill": ["E", 3, "", 0.0],
	"kill_mid": ["E", 3, "", 0.0],
	"kill_big": ["M", 2, "", 0.0],
	"kill_burn": ["E", 3, "", 0.0],
	"kill_shatter": ["E", 3, "", 0.0],
	"kill_spark": ["E", 3, "", 0.0],
	"split": ["C", 2, "", 0.0],
	"crash": ["E", 3, "", 0.0],
	"boom": ["E", 3, "", 0.0],
	"bigboom": ["M", 1, "", 0.0],
	# ---- the player (§4.5)
	"hurt": ["A", 3, "mid", -16.0],
	"dash": ["C", 3, "", 0.0],
	"mana_empty": ["C+", 2, "", 0.0],
	"low_hp": ["W", 2, "", -28.0],
	"die": ["M", 1, "", 0.0],
	"graze": ["C", 2, "", 0.0],
	"shield_soak": ["C+", 2, "", 0.0],
	"step_stone": ["W", 4, "", -32.0],
	"step_moss": ["W", 4, "", -32.0],
	"step_metal": ["W", 4, "", -32.0],
	# ---- enemies (§4.6)
	"eshot": ["C+", 3, "", 0.0],
	"eshot_ring": ["C+", 2, "", 0.0],
	"eshot_laser": ["C+", 2, "", -21.0],
	"tele": ["A", 1, "tele", 0.0],
	"tele_charge": ["A", 1, "tele", 0.0],
	"tele_slam": ["A", 1, "tele", 0.0],
	"slam": ["A", 2, "", 0.0],
	"fuse": ["W", 1, "", -26.0],
	"fuse_pop": ["A", 2, "", 0.0],
	"summon": ["C+", 2, "", 0.0],
	"ward_up": ["C+", 2, "", 0.0],
	"charge": ["C+", 2, "", -21.0],
	"bonk": ["E", 2, "", 0.0],
	"spawn": ["C+", 1, "", 0.0],
	"burn": ["W", 3, "", -30.0],
	"freeze": ["C+", 2, "", 0.0],
	"panic": ["A", 1, "", 0.0],
	"blink_charge": ["C+", 1, "", 0.0],
	"blink_land": ["C+", 2, "", 0.0],
	"thorns": ["C+", 2, "", 0.0],
	"thorns_spark": ["C+", 2, "", 0.0],
	"trail_loop": ["C+", 1, "loop", -22.0],
	"box_fill": ["A", 1, "", 0.0],
	"trash": ["C+", 1, "", 0.0],
	"elite_arrive": ["A", 1, "", 0.0],
	"hit_proxy": ["C+", 3, "gap", 0.0],
	"thermal": ["E", 2, "", 0.0],
	# ---- bosses (§4.7)
	"tele_boss": ["A", 1, "tele", 0.0],
	"copy_cast": ["A", 1, "tele", 0.0],
	"select_all": ["A", 1, "tele", 0.0],
	"tele_collect": ["A", 1, "tele", 0.0],
	"tele_lap": ["A", 1, "tele", 0.0],
	"tele_sweep": ["A", 1, "tele", 0.0],
	"ctrl_z": ["A", 1, "", 0.0],
	"paste": ["C+", 1, "", 0.0],
	"chomp": ["A", 2, "", 0.0],
	"beam": ["C+", 1, "loop", -21.0],
	"derail": ["M", 1, "", 0.0],
	"roar": ["M", 1, "", 0.0],
	"phase": ["M", 1, "", 0.0],
	"key_turn": ["E", 1, "", 0.0],
	"weak_open": ["E", 1, "", 0.0],
	"gulp": ["C+", 2, "", 0.0],
	"choked": ["E", 1, "", 0.0],
	"segment_break": ["E", 2, "", 0.0],
	"loop_jr": ["A", 1, "", 0.0],
	"back_on_track": ["A", 1, "", 0.0],
	# ---- the world (§4.8)
	"crate": ["E", 3, "", 0.0],
	"pod_pop": ["E", 2, "", 0.0],
	"bramble_burn": ["E", 2, "", 0.0],
	"crack_open": ["E", 1, "", 0.0],
	"secret": ["E", 1, "", 0.0],
	"pylon": ["E", 1, "", 0.0],
	"pit_fall": ["E", 1, "", 0.0],
	"chest": ["E", 1, "", 0.0],
	"forge": ["U+", 2, "", 0.0],
	"altar": ["E", 1, "", 0.0],
	"door": ["E", 1, "", 0.0],
	"door_shut": ["E", 1, "", 0.0],
	"glitch_toll": ["E", 1, "", 0.0],
	# ---- rewards and progression (§4.9)
	"coin": ["C", 3, "", 0.0],
	"heal": ["E", 1, "", 0.0],
	"heal_small": ["W", 2, "", -28.0],
	"heart": ["E", 1, "", 0.0],
	"relic_proc": ["C", 2, "", 0.0],
	"caught": ["M", 1, "", 0.0],
	"wand_recharge": ["W", 1, "", -30.0],
	# ---- UI (§4.10)
	"ui": ["U", 2, "", 0.0],
	"ui_back": ["U", 2, "", 0.0],
	"ui_open": ["U", 2, "", 0.0],
	"ui_close": ["U", 2, "", 0.0],
	"ui_equip": ["U+", 2, "", 0.0],
	"ui_drag": ["U", 1, "", 0.0],
	"ui_drop": ["U", 2, "", 0.0],
	"swap": ["U", 1, "", 0.0],
	"deny": ["U+", 1, "", 0.0],
	"buy": ["U+", 1, "", 0.0],
	"pick": ["U+", 1, "", 0.0],
	"levelup": ["M", 1, "", -18.0],
	"ui_confirm": ["U+", 1, "", 0.0],
	"compile": ["M", 1, "", 0.0],
	"unlock": ["U+", 1, "", 0.0],
	"ui_pick": ["U", 2, "", 0.0],
	"tip": ["U", 1, "", -27.0],
	"duck_say": ["U", 3, "", -26.0],
	"glitch_say": ["U", 3, "", -26.0],
	# ---- World 3, the Kernel (0.20, research/world3-0.20.md §3)
	"leak_drip": ["C+", 3, "", 0.0],
	"leak_dry": ["E", 2, "", 0.0],
	"null_aim": ["C+", 1, "", 0.0],
	"null_blink": ["C+", 2, "", 0.0],
	"interrupt_lock": ["E", 1, "", 0.0],
	"interrupt_free": ["E", 1, "", 0.0],
	"race_cross": ["A", 2, "", 0.0],
	"race_respawn": ["A", 1, "", 0.0],
	"diff_warn": ["A", 1, "", 0.0],
	"diff_burn": ["A", 2, "", 0.0],
	"revert_spawn": ["E", 1, "", 0.0],
	"revert_take": ["M", 1, "", 0.0],
	"glitch_unwind": ["M", 1, "", 0.0],
	"resident_free": ["M", 1, "", -18.0],
	"page_take": ["E", 1, "", 0.0],
	"skin_equip": ["U+", 2, "", 0.0],
	"hint": ["U+", 1, "", 0.0],
	# ---- ambience spots (§4.11): 22.05 kHz, played by audio.gd itself
	"amb_drip": ["W", 4, "amb", -32.0],
	"amb_creak": ["W", 2, "amb", -32.0],
	"amb_rustle": ["W", 3, "amb", -32.0],
	"amb_glitch": ["W", 3, "amb", -32.0],
	"amb_steam": ["W", 3, "amb", -32.0],
	"amb_clank": ["W", 3, "amb", -32.0],
	"amb_page": ["W", 3, "amb", -32.0],
	"amb_tick": ["W", 2, "amb", -32.0],
	"amb_nest": ["W", 2, "amb", -32.0],
	"amb_spark": ["W", 3, "amb", -32.0],
}

# pitches (the effects are tuned to A; the runtime shifts walked cues into the area's key)
const A4 := 440.0
const E5 := 659.26
const A5 := 880.0
const CS6 := 1108.73
const D6 := 1174.66
const E6 := 1318.51
const G6 := 1567.98
const GS6 := 1661.22
const A6 := 1760.0
const C7 := 2093.0
const CS7 := 2217.46
const D7 := 2349.32
const E7 := 2637.02
const G7 := 3135.96
const A7 := 3520.0
const E8 := 5274.04

var _id := ""
var _v := 0
var _written := {}
var _log: Array[String] = []
var _ms := {}


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var files := 0
	# ONLY=hit,crit (a comma list) renders just those cues and deletes nothing, for working on one
	var only := OS.get_environment("ONLY").split(",", false)
	for id: String in CUES:
		if not only.is_empty() and not id in only:
			continue
		var c0 := Time.get_ticks_msec()
		var row: Array = CUES[id]
		var flags := String(row[2])
		var rate := SR_AMB if "amb" in flags else SR
		D.set_rate(rate)
		var target := float(row[3]) if float(row[3]) != 0.0 else float(FAMILY[row[0]])
		for v in int(row[1]):
			_id = id
			_v = v
			var buf: PackedFloat32Array = call("_c_" + id, v)
			if "gap" in flags:
				buf = _r1_gap(buf)
			_write(buf, "sfx_%s%s" % [id, "" if v == 0 else "_%d" % (v + 1)], target, rate, flags, String(row[0]), v)
			files += 1
		if "heavy" in flags:
			_id = id
			_v = 0
			var base: PackedFloat32Array = call("_c_" + id, 0)
			if "gap" in flags:
				base = _r1_gap(base)
			_v = 3   # the heavy body draws on the 4th variant's streams
			_write(_heavy(base), "sfx_%s_heavy" % id, target, rate, flags, String(row[0]), 0)
			files += 1
		_ms[id] = Time.get_ticks_msec() - c0
	D.set_rate(SR)
	var removed: Array[String] = []
	if only.is_empty():
		removed = _remove_orphans()
	print("gen_audio: %d cues, %d files to %s in %.1f s; removed %d retired files: %s" % [CUES.size(), files, OUT,
		(Time.get_ticks_msec() - t0) / 1000.0, removed.size(), ", ".join(removed)])
	print("gen_audio: mastering passes: %s" % (", ".join(_log) if not _log.is_empty() else "none"))
	var slow: Array = _ms.keys()
	slow.sort_custom(func(a: String, b: String) -> bool: return int(_ms[a]) > int(_ms[b]))
	var top: Array[String] = []
	for id: String in slow.slice(0, 8):
		top.append("%s %.1f s" % [id, int(_ms[id]) / 1000.0])
	print("gen_audio: slowest cues: %s" % ", ".join(top))
	quit()


# ------------------------------------------------------------------ finishing and files

## Finishing (§3.5, §3.12, §4.1): the output high-pass and DC blocker (run over the loop twice for
## a loop, so the seam stays continuous), the anti-click fade and tail trim, the variant's voicing,
## then two measured mastering passes before the level is set:
## - phone translation (§7.4): while more than 25% of the energy sits under 200 Hz, or (Event,
##   Alarm and Moment cues) the phone model would take more than 2.8 LU away, a -3 dB shelf at
##   300 Hz is added (at most six). The recipes' own phantom harmonics carry the weight; the
##   shelf only trims what is left of the sub, an earbud bonus.
## - loudness under the cap (§4.1): a short, peaky cue that the -1 dBTP cap would hold under its
##   family target goes through the look-ahead limiter: up to 6 dB of peak reduction to land
##   within 0.3 LU of the target, and up to 12 dB only when it would otherwise sit more than
##   2.7 LU under it (DOG 1 accepts a cue held at the true-peak cap within 3 LU of its target;
##   deeper limiting would flatten the transient that makes a short cue read).
## The file is then scaled to the family's LUFS-M, never above the true-peak cap.
func _write(buf: PackedFloat32Array, fname: String, target: float, rate: int, flags: String, fam: String, v: int) -> void:
	var loop := "loop" in flags
	var x: PackedFloat32Array
	if loop:
		x = D.second_half(D.dc_block(D.hp2(D.twice(buf), HP_SFX)))
	else:
		x = D.dc_block(D.hp2(buf, HP_SFX))
		x = D.trim_tail(x, -60.0, 6.0, TELE_S + 10.0 if "tele" in flags else 0.0)
		D.fade_in(x, 0.0, 2.0)
	if v > 0:
		x = _vary_mid(x, v) if "mid" in flags else _vary(x, v, loop)
	var shelves := 0
	var squash := 0.0
	var m := 0.0
	var tp := 0.0
	var g := 0.0
	# the limiter changes the spectral balance a little, so the two passes run until both hold
	for round in 3:
		while shelves < 8 and Loudness.band_share(x, rate, 0.0, 200.0) > 0.15:
			x = _eq(x, loop, "lowshelf", 300.0, -3.0)
			shelves += 1
		if fam in ["E", "A", "M"] and not loop:
			while shelves < 8 and _phone_loss(x, rate) > 2.7:
				x = _eq(x, loop, "lowshelf", 300.0, -3.0)
				shelves += 1
		m = Loudness.momentary_max(x, rate)
		tp = Loudness.true_peak_db(x, rate)
		g = target - m
		if loop or tp + g <= TP_CEIL + 0.3 or squash >= 12.0:
			break
		# a quick release for bright cues (the transient goes, the body stays), slower with low content
		var release := 40.0 if Loudness.band_share(x, rate, 0.0, 400.0) > 0.2 else 12.0
		while (tp + g > TP_CEIL + 0.3 and squash < 6.0) or (tp + g > TP_CEIL + 2.7 and squash < 12.0):
			var over := minf(tp + g - TP_CEIL + 0.4, 3.0)
			x = D.limit(x, D.peak(x) * D.db2lin(-over), 1.5, release)
			squash += over
			m = Loudness.momentary_max(x, rate)
			tp = Loudness.true_peak_db(x, rate)
			g = target - m
	if tp + g > TP_CEIL:
		g = TP_CEIL - tp
	if shelves > 0 or squash > 0.0:
		_log.append("%s%s%s" % [fname.trim_prefix("sfx_"), " shelf -%d dB" % (3 * shelves) if shelves > 0 else "", " limit %.1f dB" % squash if squash > 0.0 else ""])
	D.save_wav(x, OUT + fname + ".wav", D.db2lin(g), rate)
	_written[fname + ".wav"] = true


## A static EQ, loop-continuous when the cue is a loop.
func _eq(x: PackedFloat32Array, loop: bool, kind: String, f: float, db: float, q := 0.7071) -> PackedFloat32Array:
	return D.second_half(D.eq(D.twice(x), kind, f, db, q)) if loop else D.eq(x, kind, f, db, q)


## Loudness lost through the phone model (§1.3: 4th-order high-pass at 300 Hz, low-pass at 12 kHz), LU.
func _phone_loss(x: PackedFloat32Array, rate: int) -> float:
	var ph := D.svf(D.svf2(x, "hp", 300.0), "lp", minf(12000.0, 0.45 * rate), 0.7071)
	return Loudness.momentary_max(x, rate) - Loudness.momentary_max(ph, rate)


## The voicing of a cue that must keep its band (hurt: 250-900 Hz): a low-mid or high-mid lift.
func _vary_mid(x: PackedFloat32Array, v: int) -> PackedFloat32Array:
	return D.eq(x, "peak", 400.0 if v % 2 == 1 else 750.0, 5.0, 1.0)


## A variant's voicing on top of its recipe changes (§4.1 "variants are recipe variants"; DOG 9
## asks for >= 2 dB in some octave band): the 2nd is brighter, the 3rd darker, the 4th has a
## forward upper-mid. The first variant is the recipe as written.
func _vary(x: PackedFloat32Array, v: int, loop: bool) -> PackedFloat32Array:
	match v % 3:
		1:
			return _eq(_eq(x, loop, "lowshelf", 800.0, -5.0), loop, "highshelf", 4000.0, 5.0)
		2:
			return _eq(_eq(x, loop, "lowshelf", 800.0, 5.0), loop, "highshelf", 4000.0, -5.0)
	return _eq(x, loop, "peak", 2000.0, 6.0, 0.8)


## Deletes every sfx_*.wav (and its .import) this run did not write: the retired cues.
func _remove_orphans() -> Array[String]:
	var out_: Array[String] = []
	var dir := ProjectSettings.globalize_path(OUT)
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("sfx_") and f.ends_with(".wav") and not _written.has(f):
			DirAccess.remove_absolute(dir.path_join(f))
			if FileAccess.file_exists(dir.path_join(f + ".import")):
				DirAccess.remove_absolute(dir.path_join(f + ".import"))
			out_.append(f.trim_suffix(".wav"))
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("sfx_") and f.ends_with(".wav.import") and not FileAccess.file_exists(dir.path_join(f.trim_suffix(".import"))):
			DirAccess.remove_absolute(dir.path_join(f))
	out_.sort()
	return out_


## Dense chatter leaves the threat band empty (§4.1 R1): the part under 290 Hz and the part
## over 1.45 kHz are kept (48 dB/oct), 330-1200 Hz is cut.
func _r1_gap(x: PackedFloat32Array) -> PackedFloat32Array:
	return D.add(D.svf2(x, "lp", 290.0), D.svf2(D.svf2(x, "hp", 1450.0), "hp", 1450.0))


## A cast's "heavy" variant (§4.2, DEV-A7): its first variant plus a phantom-saturated body near
## 300 Hz (D4, in the A minor pentatonic) about 8 dB under the cast's peak.
func _heavy(base: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(base.size(), N(140.0))
	var body := D.amp(D.sine(D.penv(440.0, 293.66, 25.0, n, "drop")), D.aenv(1.0, 130.0, n))
	body = weight(D.sat(body, 3.0, "asym"), 180.0, 4.0, 0.8, -6.0)
	D.normalize_in(body, D.peak(base) * D.db2lin(-8.0))
	return D.add(base, body)


# ------------------------------------------------------------------ recipe vocabulary

## The random stream of this cue, variant and layer.
func R(layer: int) -> RandomNumberGenerator:
	return D.rng_for(_id, _v, layer)


func N(ms: float) -> int:
	return D.n_of(ms)


## A constant frequency curve of ms.
func F(hz_: float, ms: float) -> PackedFloat32Array:
	return D.const_curve(hz_, N(ms))


## A silent output buffer of ms.
func out(ms: float) -> PackedFloat32Array:
	return D.buf_ms(ms)


## The variant's value from a list.
func P(list: Array, v: int) -> float:
	return float(list[v % list.size()])


## The variant's string from a list.
func S(list: Array, v: int) -> String:
	return String(list[v % list.size()])


## A noise burst of ms (kind "white" | "pink" | "brown") through a filter (mode "" for none),
## under aenv(a_ms, rest).
func nz(layer: int, kind: String, ms: float, mode: String, fc: float, q := 0.7071, a_ms := 0.3) -> PackedFloat32Array:
	var n := N(ms)
	var x := D.noise(n, R(layer), kind)
	if mode != "":
		x = D.svf(x, mode, fc, q)
	return D.amp(x, D.aenv(a_ms, maxf(0.5, ms - a_ms), n))


## Noise through a band-pass sweeping f1 -> f2 over sweep_ms, under aenv(a_ms, rest) of ms.
func nzs(layer: int, kind: String, ms: float, f1: float, f2: float, sweep_ms: float, q: float, a_ms := 0.5, mode := "bp") -> PackedFloat32Array:
	var n := N(ms)
	var x := D.svf_mod(D.noise(n, R(layer), kind), mode, D.penv(f1, f2, sweep_ms, n), q)
	return D.amp(x, D.aenv(a_ms, maxf(0.5, ms - a_ms), n))


## A sine body f1 -> f2 (a "drop" pitch envelope over drop_ms), under aenv(a_ms, rest) of len_ms
## (or, with hold_ms, held near full level that long before it decays), saturated (asymmetric,
## drive; 0 skips), low-passed (lp; 0 skips) and given the phone-first weight (ph = the phantom's
## mix; 0 skips; sub_db the shelf under it).
func drop(f1: float, f2: float, drop_ms: float, len_ms: float, drive: float, lp := 0.0, ph := 0.6, a_ms := 1.0, sub_db := -9.0, hold_ms := 0.0) -> PackedFloat32Array:
	var n := N(len_ms)
	var e := D.aenv(a_ms, maxf(1.0, len_ms - a_ms), n)
	if hold_ms > 0.0:
		e = D.env([[0.0, 0.0, 0.0], [a_ms, 1.0, 0.0], [a_ms + hold_ms, 0.75, 0.0], [len_ms, 0.0, 3.0]], n)
	var x := D.amp(D.sine(D.penv(f1, f2, drop_ms, n, "drop")), e)
	if drive > 0.0:
		x = D.sat(x, drive, "asym")
	if lp > 0.0:
		x = D.svf(x, "lp", lp, 0.7071)
	if ph > 0.0:
		x = weight(x, 180.0, 4.0, ph, sub_db)
	return x


## Phone-first weight (§2.1 pillar 3): the phantom fundamental (its 2nd and 3rd harmonics in
## 200-700 Hz), then the sub under about 220 Hz shelved down by sub_db, so the harmonics carry
## the body on a phone speaker and the sub stays an earbud bonus.
func weight(x: PackedFloat32Array, split := 200.0, drive := 4.0, mixv := 1.0, sub_db := -9.0) -> PackedFloat32Array:
	var y := D.phantom(x, split, drive, mixv)
	return D.eq(y, "lowshelf", 220.0, sub_db, 0.7071) if sub_db < 0.0 else y


## A modal strike: material at f0 with base T60 t60_ms, rendered for len_ms.
func md(mat: String, f0: float, t60_ms: float, len_ms: float, excite := "impulse", layer := 0, modes := 8, gains := []) -> PackedFloat32Array:
	var y := D.modal(mat, f0, t60_ms / 1000.0, N(len_ms), excite, R(layer), modes, 3.0, gains)
	D.fade_in(y, 0.0, 3.0)
	return y


## An FM tone on the frequency curve f: ratio, index i1 -> i2 over idx_ms, under aenv(a_ms, d_ms).
func fmt(f: PackedFloat32Array, ratio: float, i1: float, i2: float, idx_ms: float, a_ms: float, d_ms: float) -> PackedFloat32Array:
	var n := f.size()
	return D.amp(D.fm(f, ratio, D.index_env(i1, i2, idx_ms, n)), D.aenv(a_ms, d_ms, n))


## An oscillator ("saw" | "pulse" | "tri" | "sine") on f under the envelope e.
func osc(kind: String, f: PackedFloat32Array, e: PackedFloat32Array, duty := 0.5) -> PackedFloat32Array:
	return D.amp(D.osc(kind, f, duty), e)


## A one-sample click in a short buffer.
func click(a := 0.8) -> PackedFloat32Array:
	return D.impulse(N(2.0), 0, a)


## Crackle of ms: `rate` impulses a second, band-passed at fc, under aenv(0.5, rest).
func crk(layer: int, ms: float, rate: float, fc := 4000.0, ring := 0.82, q := 1.0) -> PackedFloat32Array:
	var n := N(ms)
	return D.amp(D.crackle(n, R(layer), rate, ring, fc, q), D.aenv(0.5, maxf(1.0, ms - 0.5), n))


## A run of sigils at the given pitches, one every step_ms.
func sigils(pitches: Array, step_ms: float, ms := 14.0, bright := 0.8) -> PackedFloat32Array:
	var o := out(step_ms * pitches.size() + ms + 5.0)
	for i in pitches.size():
		D.mix(o, D.sigil(float(pitches[i]), ms, bright), step_ms * i)
	return o


## A falling-density envelope for grains: 1 at the start to `end` at ms.
func thin(ms: float, end := 0.0) -> PackedFloat32Array:
	return D.env([[0.0, 1.0, 0.0], [ms, end, 1.0]], N(ms))


# ------------------------------------------------------------------ casts (§4.2)

func _c_cast_spark(v: int) -> PackedFloat32Array:
	var o := out(120.0)
	D.mix(o, D.sigil(A6, 20.0, P([1.0, 0.8, 1.2], v)))
	var n := N(100.0)
	var b := D.pulse(D.penv(2640.0, 1320.0, 60.0, n), P([0.25, 0.18, 0.33], v))
	b = D.svf(b, "bp", P([2500.0, 3200.0, 1900.0], v), 3.0)
	D.mix(o, D.amp(b, D.aenv(1.0, 80.0, n)), 0.0, -4.0)
	D.mix(o, nz(2, "pink", 70.0, "hp", 4000.0, 0.7071, 2.0), 0.0, P([-12.0, -9.0, -15.0], v))
	return o


func _c_cast_laser(v: int) -> PackedFloat32Array:
	var o := out(130.0)
	D.mix(o, D.sigil(A6, 15.0))
	var n := N(110.0)
	var b := D.add(D.saw(F(A7 * D.st(0.15), 110.0)), D.saw(F(A7 * D.st(-0.15), 110.0), 0.4))
	b = D.svf(b, "hp", 2000.0, 0.7071)
	b = D.svf_mod(b, "bp", D.penv(7000.0, P([3000.0, 3800.0, 2500.0], v), 80.0, n), 5.0)
	b = D.amp(b, D.aenv(0.5, 85.0, n))
	b = D.comb(b, 0.57, P([0.6, 0.45, 0.7], v), 0.5)
	D.mix(o, b, 0.0, -2.0)
	return o


func _c_cast_needle(v: int) -> PackedFloat32Array:
	var o := out(70.0)
	D.mix(o, nz(1, "white", 4.0, "hp", P([6000.0, 5000.0, 7500.0], v), 0.7071, 0.1))
	var n := N(60.0)
	D.mix(o, D.amp(D.sine(D.penv(P([4400.0, 3900.0, 5000.0], v), 2200.0, 35.0, n)), D.aenv(0.5, 55.0, n)), 0.0, -3.0)
	D.mix(o, D.sigil(A7, 15.0, 0.7))
	return o


func _c_cast_fan(v: int) -> PackedFloat32Array:
	var o := out(150.0)
	D.mix(o, sigils([A6, C7, E7], 18.0, 16.0, P([0.9, 0.7, 1.1], v)))
	D.mix(o, D.whoosh(N(110.0), R(4), P([3000.0, 2200.0, 4000.0], v), P([6000.0, 4400.0, 8000.0], v), 90.0, 1.0), 0.0, P([-6.0, -2.0, -10.0], v))
	return o


func _c_cast_missile(v: int) -> PackedFloat32Array:
	var o := out(160.0)
	D.mix(o, D.sigil(A6, 20.0))
	var n := N(120.0)
	var b := D.svf(D.noise(n, R(1), "pink"), "bp", P([3000.0, 2200.0, 4200.0], v), 4.0)
	b = D.amp(D.am(b, P([28.0, 24.0, 32.0], v), 0.8, "sine"), D.aenv(3.0, 95.0, n))
	D.mix(o, b, 0.0, -1.0)
	D.mix(o, osc("sine", D.penv(E6, 1980.0, 100.0, N(130.0)), D.aenv(2.0, 120.0, N(130.0))), 0.0, P([-10.0, -4.0, -14.0], v))
	return o


func _c_cast_carry(v: int) -> PackedFloat32Array:
	var o := out(160.0)
	var k := D.ks(A5, 0.15, P([0.4, 0.62, 0.25], v), P([0.13, 0.22, 0.31], v), N(150.0), R(1))
	D.fade_in(k, 0.0, 20.0)
	D.mix(o, k, 0.0, -2.0)
	D.mix(o, D.sigil(A6, 15.0))
	return o


func _c_cast_orbit(v: int) -> PackedFloat32Array:
	var o := out(230.0)
	var n := N(220.0)
	var f := D.vibrato(D.const_curve(A6, n), P([9.0, 7.0], v), 30.0)
	D.mix(o, fmt(f, 1.41, 3.0, 0.0, 50.0, 3.0, 170.0), 0.0, -3.0)
	var wh := D.whoosh(n, R(2), 1450.0, P([1800.0, 1700.0], v), 180.0, 1.5)
	D.mix(o, D.svf2(D.svf2(wh, "lp", 1750.0), "lp", 1750.0), 0.0, -6.0)
	D.mix(o, D.sigil(A6, 20.0))
	return o


func _c_cast_boom(v: int) -> PackedFloat32Array:
	var o := out(280.0)
	D.mix(o, D.sigil(A6, 15.0))
	D.mix(o, nz(1, "white", 6.0, "hp", 3000.0, 0.7071, 0.1), 0.0, -2.0)
	D.mix(o, drop(660.0, 220.0, 60.0, 200.0, P([4.0, 6.0, 3.0], v), P([1800.0, 1400.0, 2300.0], v), 0.6))
	D.mix(o, nz(3, "pink", 180.0, "lp", P([2500.0, 2000.0, 3000.0], v), 0.7071, 1.0), 0.0, -8.0)
	return o


func _c_cast_mine(v: int) -> PackedFloat32Array:
	var o := out(120.0)
	D.mix(o, D.sigil(A6, 15.0))
	for i in 2:
		D.mix(o, nz(1 + i, "white", 5.0, "bp", P([3000.0, 3600.0], v), 6.0, 0.1), 60.0 * i, 2.0)
	D.mix(o, fmt(F(E7, 40.0), 1.0, 0.8, 0.0, 25.0, 0.5, 30.0), 60.0, P([-4.0, -8.0], v))
	return o


func _c_cast_fire(v: int) -> PackedFloat32Array:
	var o := out(230.0)
	D.mix(o, D.sigil(A6, 18.0))
	D.mix(o, nz(1, "white", 8.0, "bp", 2000.0, 1.0, 0.2), 0.0, -3.0)
	var n := N(170.0)
	var b := D.svf_mod(D.noise(n, R(2), "pink"), "bp", D.penv(1300.0, P([3500.0, 2800.0, 4300.0], v), 150.0, n), 1.5)
	D.mix(o, D.amp(b, D.aenv(3.0, 150.0, n)))
	D.mix(o, D.grain(n, R(3), 40.0, 3.0, "noise", 3500.0, 4600.0), 0.0, -4.0)
	# the low roar sits under R1 (A3 -> E3), not in it
	D.mix(o, D.sat(osc("saw", D.penv(220.0, 164.81, 150.0, n), D.aenv(2.0, 150.0, n)), 2.0), 0.0, -14.0)
	D.mix(o, crk(4, 100.0, 300.0, 3500.0), 120.0, -6.0)
	return o


func _c_cast_wall(v: int) -> PackedFloat32Array:
	var o := out(460.0)
	D.mix(o, D.sigil(A6, 20.0))
	var n := N(440.0)
	# the roar of the wall sits between R1 and R2 (1.45-1.9 kHz, 48 dB/oct), the crackle above 4.5 kHz,
	# so a long cast never rings in the crit's band
	var b := D.svf_mod(D.noise(n, R(1), "pink"), "lp", D.penv(1500.0, P([1700.0, 1650.0], v), 250.0, n), 0.9)
	for k in 4:
		b = D.svf2(b, "lp", 1650.0)
	D.mix(o, D.amp(b, D.env([[0.0, 0.0, 0.0], [60.0, 1.0, 0.0], [440.0, 0.0, 3.0]], n)), 0.0, 4.0)
	var c := D.grain(N(400.0), R(2), P([80.0, 110.0], v), 3.0, "noise", 4800.0, 7500.0)
	D.mix(o, D.svf2(D.svf2(c, "hp", 4500.0), "hp", 4500.0), 20.0, -2.0)
	return o


func _c_cast_ice(v: int) -> PackedFloat32Array:
	var o := out(130.0)
	D.mix(o, D.sigil(A6, 15.0, 0.6))
	D.mix(o, md("glass", A7, 60.0, 120.0, S(["impulse", "noise", "mallet"], v), 1, 4), 0.0, -2.0)
	D.mix(o, nz(2, "white", 10.0, "hp", 7000.0, 0.7071, 0.1), 0.0, -6.0)
	D.mix(o, fmt(F(E8, 110.0), 1.41, P([2.0, 1.4, 2.6], v), 0.0, 60.0, 1.0, 70.0), 0.0, -6.0)
	return o


func _c_cast_chain(v: int) -> PackedFloat32Array:
	var o := out(100.0)
	D.mix(o, crk(1, 30.0, 800.0, P([4000.0, 3300.0, 4800.0], v)), 0.0, 2.0)
	D.mix(o, D.sigil(A6, 18.0))
	var n := N(80.0)
	var f := D.penv(6000.0, 1500.0, 40.0, n)
	var b := D.svf_mod(D.saw(f), "bp", f, 8.0)
	D.mix(o, D.amp(b, D.aenv(0.5, P([60.0, 45.0, 75.0], v), n)), 0.0, -3.0)
	return o


func _c_cast_static(v: int) -> PackedFloat32Array:
	var o := out(120.0)
	D.mix(o, crk(1, 60.0, 1500.0, P([4000.0, 3400.0, 4700.0], v)), 0.0, 2.0)
	D.mix(o, nzs(2, "pink", 90.0, 7000.0, 3000.0, 80.0, 1.5), 0.0, -4.0)
	D.mix(o, D.sigil(A6, 18.0))
	return o


func _c_cast_arcane(v: int) -> PackedFloat32Array:
	var o := out(230.0)
	var b := fmt(F(A6, 220.0), 3.5, P([2.5, 1.8, 3.2], v), 0.2, 120.0, 1.0, 110.0)
	D.mix(o, D.delay(b, 90.0, 0.25, 3000.0, 0.2), 0.0, -2.0)
	D.mix(o, D.sigil(A6, 18.0))
	return o


## ping: the ring sits at A6 (under R2), so the crit keeps 2.2-3.6 kHz to itself; a short glint
## above R2 gives the attack.
func _c_cast_ping(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	var n := N(300.0)
	var ring := osc("sine", F(A6, 300.0), D.aenv(1.0, 250.0, n))
	D.mix(o, D.delay(D.fit(ring, N(350.0)), 70.0, P([0.35, 0.25], v), 4000.0, 0.5), 0.0, -3.0)
	D.mix(o, osc("sine", F(P([E8, A7 * 2.0], v), 40.0), D.aenv(0.5, 35.0, N(40.0))), 0.0, -8.0)
	D.mix(o, D.sigil(A6, 15.0))
	return o


func _c_cast_rot(v: int) -> PackedFloat32Array:
	var o := out(230.0)
	var n := N(220.0)
	var fc := D.penv(1400.0, P([2400.0, 2000.0], v), 200.0, n)
	var wob := D.lfo(9.0, 2.0, "sine", n)
	for i in n:
		fc[i] *= pow(2.0, wob[i] / 12.0)
	var b := D.amp(D.svf_mod(D.noise(n, R(1), "brown"), "bp", fc, 6.0), D.aenv(4.0, 150.0, n))
	D.mix(o, D.crush(b, 6, P([6.0, 5.0], v), 0.5), 0.0, 2.0)
	D.mix(o, D.sigil(A6, 18.0))
	return o


func _c_cast_void(v: int) -> PackedFloat32Array:
	var o := out(300.0)
	D.mix(o, D.sigil(A6, 15.0, 0.5), 0.0, -6.0)
	var n := N(220.0)
	var sw := D.svf_mod(D.noise(n, R(1), "pink"), "bp", D.penv(3000.0, P([800.0, 1000.0], v), 250.0, n), 2.0)
	sw = D.add(sw, D.sat(D.sine(F(110.0, 220.0)), 3.0), -8.0)
	D.mix(o, D.reverse(D.amp(sw, D.aenv(1.0, 215.0, n))), 0.0, -2.0)
	D.mix(o, drop(180.0, 90.0, 40.0, 70.0, 5.0, 1000.0, 0.8, 0.5), 220.0)
	return o


func _c_cast_summon(v: int) -> PackedFloat32Array:
	var o := out(310.0)
	var n := N(180.0)
	D.mix(o, fmt(D.penv(A5, A6, 120.0, n), 2.0, 1.5, 0.3, 150.0, 2.0, 170.0), 0.0, -2.0)
	D.mix(o, md("glass", P([A7, E7 * 2.0], v), 120.0, 180.0, "mallet", 1, 4), 120.0, -4.0)
	D.mix(o, D.sigil(A6, 18.0))
	return o


func _c_trigger(v: int) -> PackedFloat32Array:
	var o := out(110.0)
	D.mix(o, sigils([A6, E7], 35.0, 18.0, P([0.9, 0.6], v)))
	D.mix(o, D.comb(D.fit(sigils([A6, E7], 35.0, 18.0, 0.5), N(90.0)), 1.13, P([0.5, 0.65], v), 1.0), 0.0, -6.0)
	return o


func _c_cast_delayed(_v: int) -> PackedFloat32Array:
	return D.fit(D.sigil(A6, 30.0, 0.7), N(40.0))


func _c_fizzle(v: int) -> PackedFloat32Array:
	var o := out(110.0)
	var s := D.stutter(D.fit(D.sigil(A6, 24.0), N(30.0)), 0.0, 8.0, 3)
	D.mix(o, D.crush(s, 6, 4.0, 1.0))
	D.mix(o, nzs(1, "white", 70.0, P([3000.0, 3600.0], v), 1000.0, 60.0, 3.0), 10.0, -3.0)
	return o


func _c_familiar_end(_v: int) -> PackedFloat32Array:
	var o := out(100.0)
	D.mix(o, drop(A5, A4, 40.0, 70.0, 1.5, 0.0, 0.0, 0.5))
	D.mix(o, md("glass", A6, 60.0, 90.0, "mallet", 1, 4), 0.0, -8.0)
	return o


func _c_duck_soak(v: int) -> PackedFloat32Array:
	var o := out(110.0)
	var n := N(100.0)
	var k := D.st(P([0.0, 2.0, -2.0], v))
	var f := D.penv_pts([[0.0, 900.0 * k], [35.0, 1300.0 * k], [90.0, 700.0 * k]], n)
	var s := D.saw(f)
	var fmnt := D.add(D.svf(s, "bp", 1200.0, 5.0), D.svf(s, "bp", 2600.0, 5.0), -2.0)
	D.mix(o, D.amp(fmnt, D.aenv(3.0, 95.0, n)))
	D.mix(o, click(0.4))
	return o


# ------------------------------------------------------------------ hits, crits, defences (§4.3)

func _c_hit(v: int) -> PackedFloat32Array:
	var o := out(65.0)
	var t := D.add(nz(1, "white", 3.0, "hp", 5000.0, 0.7071, 0.1), click(0.7))
	D.mix(o, D.svf(D.fit(t, N(10.0)), "bp", 4000.0, 2.0), 0.0, 2.0)
	# the stone's fundamental sits above R1 (the spec's 1.0-1.3 kHz would put it in the threat band)
	var b := md("stone", P([1500.0, 1650.0, 1800.0, 1950.0], v), 35.0, 60.0, S(["impulse", "noise", "mallet", "noise"], v), 2, 4)
	D.mix(o, D.sat(b, 2.0), 0.0, -1.0)
	return o


## crit: a sweetener layered on the element hit (DEV-A8). The brass bar's second mode (2425 Hz)
## leads, so the ring sits in R2 and outlasts every other combat cue's 2-4 kHz content.
func _c_crit(v: int) -> PackedFloat32Array:
	var o := out(400.0)
	D.mix(o, nz(1, "white", 3.0, "hp", 4000.0, 0.7071, 0.1), 0.0, -6.0)
	var gains: Array = [[0.22, 1.0, 0.3, 0.08], [0.18, 1.0, 0.22, 0.05], [0.26, 1.0, 0.42, 0.12]][v]
	var e := D.excitation(S(["mallet", "impulse", "noise"], v), N(380.0), R(2), 2.0, P([6000.0, 9000.0, 9000.0], v))
	var brass: Dictionary = D.MATERIALS["brass"]
	var ring := D.modal_bank(brass["ratios"], gains, A5, 0.75, e, 4)
	D.fade_in(ring, 0.0, 40.0)
	D.mix(o, ring)
	return o


func _c_hit_heavy(v: int) -> PackedFloat32Array:
	var o := out(95.0)
	var b := md("stone", P([300.0, 267.0, 337.0], v), 70.0, 90.0, "mallet", 1, 5)
	D.mix(o, weight(D.sat(b, 3.0), 180.0, 4.0, 0.6))
	D.mix(o, nz(2, "white", 4.0, "bp", 1500.0, 1.0, 0.1), 0.0, -3.0)
	return o


func _c_hit_fire(v: int) -> PackedFloat32Array:
	var o := out(125.0)
	D.mix(o, nz(1, "white", 5.0, "bp", 3000.0, 1.0, 0.1))
	D.mix(o, nzs(2, "pink", 110.0, P([1900.0, 2300.0, 1700.0, 2600.0], v), P([1300.0, 1450.0, 1300.0, 1600.0], v), 80.0, 1.2, 1.0), 0.0, 1.0)
	D.mix(o, D.grain(N(110.0), R(3), 40.0, 3.0, "noise", 3000.0, 5000.0), 0.0, -4.0)
	return o


func _c_hit_ice(v: int) -> PackedFloat32Array:
	var o := out(95.0)
	D.mix(o, md("glass", A7 * D.st(P([0.0, -1.0, 1.0, -2.0], v)), 50.0, 90.0, S(["impulse", "noise", "mallet", "impulse"], v), 1, 4))
	D.mix(o, nz(2, "white", 10.0, "hp", 7000.0, 0.7071, 0.1), 0.0, -6.0)
	D.mix(o, fmt(F(E8, 80.0), 1.41, 1.5, 0.0, 60.0, 1.0, 60.0), 0.0, -8.0)
	return o


func _c_hit_static(v: int) -> PackedFloat32Array:
	var o := out(85.0)
	D.mix(o, crk(1, 60.0, 2500.0, P([4000.0, 3200.0, 5000.0, 3600.0], v), 0.85), 0.0, 2.0)
	var n := N(40.0)
	D.mix(o, osc("saw", D.penv(5000.0, 2000.0, 30.0, n), D.aenv(0.5, 35.0, n)), 0.0, -8.0)
	return o


func _c_hit_arcane(v: int) -> PackedFloat32Array:
	var o := out(85.0)
	D.mix(o, click(0.6))
	D.mix(o, fmt(F(E7 * D.st(P([0.0, -1.0, 1.0], v)), 80.0), 3.5, 2.0, 0.0, 50.0, 0.5, 55.0))
	return o


func _c_hit_void(v: int) -> PackedFloat32Array:
	var o := out(110.0)
	D.mix(o, D.reverse(nz(1, "pink", 60.0, "bp", P([1500.0, 1800.0, 1300.0], v), 1.5, 1.0)))
	# the thump stays under R1 (it is chatter): 270 -> 135 Hz, lower in the other variants
	var k := D.st(P([0.0, -2.0, -1.0], v))
	D.mix(o, drop(270.0 * k, 135.0 * k, 30.0, 45.0, 4.0, 290.0, 0.0, 0.5), 58.0, -6.0)
	return o


func _c_hit_rot(v: int) -> PackedFloat32Array:
	var o := out(95.0)
	var b := nzs(1, "brown", 90.0, P([1550.0, 1700.0, 1650.0], v), P([2200.0, 2600.0, 1950.0], v), 60.0, 5.0, 1.0)
	D.mix(o, D.crush(b, 4, P([5.0, 4.0, 6.0], v), 0.6), 0.0, 3.0)
	return o


func _c_hit_armor(v: int) -> PackedFloat32Array:
	var o := out(185.0)
	D.mix(o, nz(1, "white", 3.0, "hp", 4000.0, 0.7071, 0.1), 0.0, -3.0)
	D.mix(o, md("plate", P([1480.0, 1397.0, 1568.0], v), 90.0, 180.0, S(["mallet", "impulse", "noise"], v), 2, 6))
	D.mix(o, osc("sine", F(261.63, 60.0), D.aenv(1.0, 40.0, N(60.0))), 0.0, -10.0)
	return o


func _c_hit_ward(v: int) -> PackedFloat32Array:
	var o := out(165.0)
	var b := fmt(F(C7 * D.st(P([0.0, 1.0, -1.0], v)), 160.0), 1.5, 1.0, 0.0, 140.0, 1.0, 110.0)
	D.mix(o, D.am(b, 20.0, 0.5))
	D.mix(o, nz(2, "white", 20.0, "hp", P([6000.0, 5000.0, 7000.0], v), 0.7071, 0.3), 0.0, -6.0)
	return o


func _c_hit_shield(v: int) -> PackedFloat32Array:
	var o := out(145.0)
	D.mix(o, nz(1, "pink", 40.0, "bp", P([1600.0, 1800.0, 1450.0], v), 4.0, 2.0), 0.0, 2.0)
	var n := N(90.0)
	var s := osc("sine", D.penv(1900.0, 1500.0, 60.0, n), D.aenv(1.0, 80.0, n))
	D.mix(o, D.comb(D.fit(s, N(140.0)), 2.27, 0.6, 0.6), 0.0, -3.0)
	return o


func _c_armor_break(v: int) -> PackedFloat32Array:
	var o := out(720.0)
	D.mix(o, nz(1, "white", 10.0, "hp", 3000.0, 0.7071, 0.1), 0.0, -3.0)
	D.mix(o, md("plate", P([740.0, 698.0], v), 400.0, 700.0, "noise", 2, 8), 0.0, -2.0)
	D.mix(o, drop(220.0, 110.0, 150.0, 300.0, 4.0, 1200.0, 0.9))
	D.mix(o, nz(3, "pink", 300.0, "lp", 2000.0, 0.7071, 2.0), 20.0, -8.0)
	D.mix(o, D.grain(N(300.0), R(4), 40.0, 25.0, "stone", 1600.0, 2600.0, thin(300.0)), 30.0, -6.0)
	return o


func _c_shield_break(v: int) -> PackedFloat32Array:
	var o := out(460.0)
	D.mix(o, nz(1, "white", 6.0, "hp", 3000.0, 0.7071, 0.1), 0.0, -3.0)
	var n := N(440.0)
	D.mix(o, fmt(D.penv(1600.0, P([400.0, 470.0], v), 300.0, n), 1.5, 3.0, 0.0, 350.0, 1.0, 430.0))
	D.mix(o, crk(2, 200.0, 1000.0, 3000.0), 10.0, -4.0)
	return o


func _c_locked(v: int) -> PackedFloat32Array:
	var o := out(115.0)
	var p := md("plate", P([300.0, 267.0], v), 60.0, 110.0, "mallet", 1, 6)
	D.mix(o, weight(D.svf(p, "lp", 1500.0, 0.7071), 180.0, 4.0, 0.5))
	var n := N(50.0)
	var lo := P([220.0, 196.0], v)
	var buzz := D.add(D.pulse(F(lo, 50.0), 0.25), D.pulse(F(lo * D.st(1.0), 50.0), 0.25))
	D.mix(o, D.amp(D.svf(buzz, "lp", 1200.0, 0.7071), D.aenv(2.0, 48.0, n)), 5.0, -8.0)
	return o


func _c_ward_break(v: int) -> PackedFloat32Array:
	var o := out(620.0)
	D.mix(o, D.grain(N(260.0), R(1), 100.0, 60.0, "glass", 2000.0, 6000.0, thin(260.0, 0.1)))
	var n := N(420.0)
	D.mix(o, fmt(D.penv(A7, A6, 200.0, n), 1.41, 1.6, 0.0, 250.0, 1.0, 400.0), 0.0, P([-4.0, -6.0], v))
	D.mix(o, nz(2, "white", 200.0, "hp", P([5000.0, 4200.0], v), 0.7071, 1.0), 0.0, -9.0)
	return o


# ------------------------------------------------------------------ kills and explosions (§4.4)

## The small kill: a transient, a saturated "pop" and the in-key glass "confirm" (walked by chain).
func _kill_core(v: int, pop_db := 0.0) -> PackedFloat32Array:
	var o := out(160.0)
	D.mix(o, nz(1, "white", 5.0, "bp", 3000.0, 1.0, 0.1), 0.0, -2.0)
	D.mix(o, drop(P([330.0, 350.0, 311.0], v), 220.0, P([60.0, 40.0, 90.0], v), 130.0, P([4.0, 6.0, 3.0], v), 900.0, 1.2, 0.5, -9.0, 45.0), 0.0, pop_db)
	D.mix(o, md("glass", A6, 90.0, 150.0, S(["impulse", "mallet", "noise"], v), 2, 4), 3.0, -3.0)
	return o


func _c_kill(v: int) -> PackedFloat32Array:
	return _kill_core(v)


func _c_kill_mid(v: int) -> PackedFloat32Array:
	var o := out(420.0)
	D.mix(o, nz(1, "white", 5.0, "bp", 3000.0, 1.0, 0.1), 0.0, -2.0)
	var b := drop(P([250.0, 262.0, 235.0], v), 110.0, 120.0, 220.0, 5.0, 0.0, 1.0, 0.5)
	b = D.add(b, nz(2, "pink", 150.0, "lp", P([1200.0, 1500.0, 950.0], v), 0.7071, 1.0), -6.0)
	D.mix(o, b)
	D.mix(o, md("glass", A6, 120.0, 250.0, S(["impulse", "mallet", "noise"], v), 3, 4), 3.0, -3.0)
	return D.room(o, "S", 0.12, 0.4)


func _c_kill_big(v: int) -> PackedFloat32Array:
	var o := out(1000.0)
	D.mix(o, nz(1, "white", 8.0, "hp", 3000.0, 0.7071, 0.1), 0.0, -2.0)
	var b := drop(200.0, 80.0, 250.0, 500.0, 6.0, 1500.0, 1.0)
	b = D.add(b, md("stone", P([420.0, 392.0], v), 200.0, 500.0, "noise", 2, 5), -4.0)
	D.mix(o, b)
	D.mix(o, md("brass", A5, 600.0, 700.0, "mallet", 3, 4), 5.0, -4.0)
	D.mix(o, md("brass", E6, 600.0, 650.0, "mallet", 4, 4), 95.0, -6.0)
	D.mix(o, nz(5, "pink", 400.0, "lp", 1500.0, 0.7071, 2.0), 10.0, -9.0)
	return D.room(o, "M", 0.18, 0.5)


func _c_kill_burn(v: int) -> PackedFloat32Array:
	var o := D.fit(_kill_core(v), N(300.0))
	D.mix(o, D.grain(N(250.0), R(6), 120.0, 3.0, "noise", 2500.0, 5000.0, thin(250.0, 0.2)), 20.0, -3.0)
	D.mix(o, D.whoosh(N(260.0), R(7), 2000.0, 4000.0, 250.0, 1.0, 0.4), 10.0, -8.0)
	return o


func _c_kill_shatter(v: int) -> PackedFloat32Array:
	var o := D.fit(_kill_core(v, -4.0), N(260.0))
	D.mix(o, D.grain(N(210.0), R(6), 90.0, 40.0, "glass", 3000.0, 8000.0, thin(210.0, 0.15)), 10.0, -2.0)
	return o


func _c_kill_spark(v: int) -> PackedFloat32Array:
	var o := D.fit(_kill_core(v), N(190.0))
	var cn := N(150.0)
	var c := D.amp(D.crackle(cn, R(6), 3000.0, 0.7, 5000.0, 1.0), D.env([[0.0, 0.0, 0.0], [1.0, 1.0, 0.0], [70.0, 0.7, 0.0], [150.0, 0.0, 2.0]], cn))
	D.mix(o, c, 5.0, -2.0)
	var n := N(50.0)
	D.mix(o, osc("saw", D.penv(5000.0, 1500.0, 40.0, n), D.aenv(0.5, 45.0, n)), 0.0, -10.0)
	return o


func _c_split(v: int) -> PackedFloat32Array:
	var o := out(160.0)
	D.mix(o, nzs(1, "brown", 150.0, 500.0, P([1200.0, 1000.0], v), 120.0, 4.0, 3.0), 0.0, 4.0)
	var n := N(110.0)
	D.mix(o, D.sat(osc("sine", D.penv(300.0, P([500.0, 440.0], v), 80.0, n), D.aenv(3.0, 100.0, n)), 3.0), 0.0, -4.0)
	return o


func _c_crash(v: int) -> PackedFloat32Array:
	var o := out(320.0)
	var burst := D.crush(nz(1, "pink", 120.0, "", 0.0, 0.7071, 0.5), 3, P([5.0, 4.0, 6.0], v), 1.0)
	D.mix(o, D.stutter(burst, 0.0, 20.0, 3))
	D.mix(o, drop(400.0, 150.0, 80.0, 200.0, 5.0, 1500.0, 0.8), 0.0, -2.0)
	D.mix(o, sigils([A6, 1244.51], 50.0, 20.0, 0.8), 150.0, -4.0)
	return o


func _c_boom(v: int) -> PackedFloat32Array:
	var o := out(560.0)
	D.mix(o, nz(1, "white", 6.0, "hp", 2500.0, 0.7071, 0.1), 0.0, -2.0)
	D.mix(o, drop(P([150.0, 165.0, 138.0], v), 60.0, 200.0, 420.0, 8.0, 1600.0, 1.4))
	var n := N(400.0)
	var p := D.svf_mod(D.noise(n, R(2), "pink"), "lp", D.penv(3000.0, 500.0, 300.0, n), 0.9)
	D.mix(o, D.amp(p, D.aenv(1.0, 380.0, n)), 0.0, P([-3.0, -1.0, -5.0], v))
	D.mix(o, D.grain(N(300.0), R(3), 30.0, 20.0, "stone", 700.0, 1800.0), 40.0, -8.0)
	return D.room(o, "S", 0.10, 0.4)


func _c_bigboom(_v: int) -> PackedFloat32Array:
	var o := out(2000.0)
	D.mix(o, nz(1, "white", 15.0, "hp", 2000.0, 0.7071, 0.2), 0.0, -2.0)
	D.mix(o, drop(110.0, 40.0, 600.0, 1100.0, 10.0, 1400.0, 1.6))
	D.mix(o, drop(98.0, 40.0, 600.0, 900.0, 10.0, 1400.0, 1.6), 180.0, -4.0)
	var n := N(1000.0)
	var b := D.svf_mod(D.noise(n, R(2), "brown"), "lp", D.penv(1200.0, 300.0, 900.0, n), 0.9)
	D.mix(o, D.amp(b, D.aenv(3.0, 980.0, n)), 0.0, -2.0)
	D.mix(o, weight(md("stone", 160.0, 500.0, 900.0, "noise", 3, 5), 180.0, 4.0, 1.0), 0.0, -4.0)
	return D.room(o, "M", 0.25, 0.5)


# ------------------------------------------------------------------ the player (§4.5)

## The hurt stab: a minor-2nd saw pair (lo, hi) falling 3 semitones, saturated, under a closing
## resonant low-pass: dissonant, mid-band, unmistakable.
func _stab(lo: float, hi: float, ms: float, lp_to: float, lp_ms: float) -> PackedFloat32Array:
	var n := N(ms)
	var bend := D.penv(1.0, D.st(-3.0), 150.0, n)
	var f1 := D.zeros(n)
	var f2 := D.zeros(n)
	for i in n:
		f1[i] = lo * bend[i]
		f2[i] = hi * bend[i]
	var s := D.sat(D.add(D.saw(f1), D.saw(f2, 0.37)), 5.0)
	s = D.svf_mod(s, "lp", D.penv(3000.0, lp_to, lp_ms, n), 3.0)
	return D.amp(s, D.env([[0.0, 0.0, 0.0], [1.0, 1.0, 0.0], [ms * 0.45, 0.8, 0.0], [ms, 0.0, 3.0]], n))


func _c_hurt(v: int) -> PackedFloat32Array:
	var o := out(290.0)
	D.mix(o, D.add(nz(1, "white", 8.0, "bp", 2500.0, 1.0, 0.1), click(0.5)), 0.0, -8.0)
	var pair: Array = [[311.13, 329.63], [293.66, 311.13], [329.63, 349.23]][v]
	D.mix(o, _stab(float(pair[0]), float(pair[1]), 270.0, 600.0, 180.0))
	D.mix(o, drop(150.0, 80.0, 120.0, 200.0, 4.0, 0.0, 0.6), 0.0, -8.0)
	return o


func _c_dash(v: int) -> PackedFloat32Array:
	var o := out(210.0)
	D.mix(o, D.whoosh(N(200.0), R(1), P([600.0, 700.0, 520.0], v), P([3500.0, 4200.0, 3000.0], v), 180.0, 2.0, 0.33, 1200.0))
	var n := N(120.0)
	D.mix(o, osc("sine", D.penv(330.0, 660.0, 100.0, n), D.aenv(5.0, 110.0, n)), 0.0, -14.0)
	return o


func _c_mana_empty(v: int) -> PackedFloat32Array:
	var o := out(150.0)
	var s := D.fit(D.sigil(A6, 30.0), N(15.0))
	D.fade_in(s, 0.0, 1.0)
	D.mix(o, s)
	D.mix(o, D.crush(nzs(1, "white", 120.0, 2000.0, P([800.0, 950.0], v), 80.0, 4.0, 1.0), 8, 4.0, 1.0), 10.0, -1.0)
	return o


func _c_low_hp(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	var beat := drop(P([110.0, 104.0], v), 70.0, 60.0, 150.0, 6.0, 700.0, 1.2, 2.0)
	D.mix(o, beat)
	D.mix(o, beat, 180.0, -4.0)
	return o


func _c_die(_v: int) -> PackedFloat32Array:
	var o := out(920.0)
	D.mix(o, D.add(nz(1, "white", 8.0, "bp", 2500.0, 1.0, 0.1), click(0.5)), 0.0, -6.0)
	D.mix(o, _stab(311.13, 329.63, 520.0, 300.0, 450.0))
	var run := sigils([A6, A5, A4, 220.0], 60.0, 40.0, 0.9)
	var bits := D.env([[0.0, 12.0, 0.0], [240.0, 4.0, 0.0]], run.size())
	D.mix(o, D.crush(run, 3, 12.0, 1.0, bits), 60.0, -2.0)
	D.mix(o, drop(150.0, 40.0, 600.0, 880.0, 6.0, 1200.0, 1.4), 0.0, -2.0)
	return o


func _c_graze(v: int) -> PackedFloat32Array:
	var o := out(95.0)
	D.mix(o, D.whoosh(N(80.0), R(1), 3000.0, P([6000.0, 7000.0], v), 70.0, 3.0))
	D.mix(o, D.sigil(A7, 10.0, 0.7), 20.0)
	return o


func _c_shield_soak(v: int) -> PackedFloat32Array:
	var o := out(230.0)
	D.mix(o, md("glass", E6, 150.0, 220.0, S(["mallet", "noise"], v), 1, 4))
	D.mix(o, fmt(F(E7, 150.0), 1.41, 1.0, 0.0, 120.0, 1.0, 140.0), 0.0, -4.0)
	D.mix(o, drop(200.0, 180.0, 40.0, 90.0, 3.0, 0.0, 0.5), 0.0, -10.0)
	return o


func _c_step_stone(v: int) -> PackedFloat32Array:
	var o := out(70.0)
	D.mix(o, md("stone", P([900.0, 820.0, 980.0, 860.0], v), 25.0, 60.0, S(["mallet", "noise", "impulse", "noise"], v), 1, 4))
	D.mix(o, nz(2, "white", 4.0, "bp", P([3000.0, 2500.0, 3500.0, 2800.0], v), 1.0, 0.2), 0.0, -4.0)
	return o


func _c_step_moss(v: int) -> PackedFloat32Array:
	var o := out(80.0)
	D.mix(o, nz(1, "pink", 30.0, "bp", P([1200.0, 1000.0, 1400.0, 1100.0], v), 1.5, 3.0))
	D.mix(o, D.grain(N(60.0), R(2), 150.0, 4.0, "noise", 2000.0, 4000.0), 5.0, -6.0)
	return o


func _c_step_metal(v: int) -> PackedFloat32Array:
	var o := out(75.0)
	D.mix(o, md("plate", P([1300.0, 1230.0, 1380.0, 1270.0], v), 40.0, 70.0, S(["mallet", "noise", "impulse", "mallet"], v), 1, 4))
	return o


# ------------------------------------------------------------------ enemies (§4.6)

func _c_eshot(v: int) -> PackedFloat32Array:
	var o := out(95.0)
	var n := N(90.0)
	var b := D.pulse(D.penv(P([1000.0, 1100.0, 1200.0], v), 550.0, 70.0, n), 0.3)
	D.mix(o, D.amp(D.svf(b, "lp", 1600.0, 1.5), D.aenv(1.0, 85.0, n)))
	D.mix(o, nz(1, "white", 5.0, "bp", 900.0, 1.5, 0.1), 0.0, -4.0)
	return o


func _c_eshot_ring(v: int) -> PackedFloat32Array:
	var o := out(225.0)
	D.mix(o, nz(1, "pink", 155.0, "bp", P([700.0, 620.0], v), 2.0, 5.0), 0.0, -3.0)
	var n := N(200.0)
	var t := osc("tri", D.penv(620.0, 470.0, 140.0, n), D.aenv(3.0, 190.0, n))
	D.mix(o, D.am(t, 30.0, 0.7))
	return o


func _c_eshot_laser(v: int) -> PackedFloat32Array:
	var o := out(145.0)
	var n := N(140.0)
	var s := D.add(D.saw(F(A5 * D.st(0.1), 140.0)), D.saw(F(A5 * D.st(-0.1), 140.0), 0.5))
	s = D.svf_mod(s, "bp", D.penv(P([1200.0, 1100.0], v), P([700.0, 620.0], v), 120.0, n), 6.0)
	D.mix(o, D.amp(s, D.aenv(1.0, 135.0, n)), 0.0, 3.0)
	D.mix(o, nz(1, "white", 5.0, "bp", 1500.0, 1.5, 0.1), 0.0, -3.0)
	return o


## The Threat Warble (§4.6): pulse voices rising exponentially f_lo -> f_hi over the 1.5 s master,
## band-passed on their own fundamental (Q q) so the energy stays in R1, a tremolo speeding up
## from trem_lo to trem_hi (depth 40%) phased to end on full level, an 18 dB exponential swell
## and a 1 ms hard stop at TELE_S. voices: [[frequency multiplier, cents], ...].
func _warble(f_lo: float, f_hi: float, voices: Array, trem_lo := 10.0, trem_hi := 22.0, q := 3.0) -> PackedFloat32Array:
	var n := N(TELE_S)
	var f := D.penv(f_lo, f_hi, TELE_S, n)
	var sum := D.zeros(n)
	var ph := 0.0
	for vc: Array in voices:
		var k := float(vc[0]) * pow(2.0, float(vc[1]) / 1200.0)
		var fv := D.zeros(n)
		for i in n:
			fv[i] = f[i] * k
		D.mix_at(sum, D.pulse(fv, 0.3, PackedFloat32Array(), ph), 0, 1.0 / voices.size())
		ph += 0.31
	sum = D.svf_mod(sum, "bp", f, q)
	sum = _tremolo(sum, D.penv(trem_lo, trem_hi, TELE_S, n), 0.4)
	sum = D.amp(sum, D.rise_db(18.0, TELE_S, n))
	D.fade_in(sum, 0.5, 1.0)
	return sum


## A tremolo whose rate follows the curve, phased so it ends at full gain (the release is loud).
func _tremolo(x: PackedFloat32Array, rate: PackedFloat32Array, depth: float) -> PackedFloat32Array:
	var cycles := 0.0
	for r in rate:
		cycles += r / D.sr
	var l := D.lfo_mod(rate, 1.0, "sine", 0.0, 0.75 - cycles)
	var y := D.zeros(x.size())
	for i in x.size():
		y[i] = x[i] * (1.0 - depth * (0.5 + 0.5 * l[i]))
	return y


## A master buffer: the 1.5 s warble plus room for the release after the stop.
func _tele_out() -> PackedFloat32Array:
	return out(TELE_S + 90.0)


func _c_tele(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	D.mix(o, _warble(220.0, A5, [[1.0, 12.0], [1.0, -12.0]]))
	D.mix(o, nz(1, "white", 4.0, "bp", 1000.0, 1.5, 0.1), TELE_S, -6.0)
	return o


func _c_tele_charge(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	var w := _warble(165.0, E5, [[1.0, 12.0], [1.0, -12.0]])
	# the stamp: an 8 Hz square AM over the last 0.3 s
	var from := N(TELE_S - 300.0)
	for i in range(from, w.size()):
		var ph := fmod(float(i - from) * 8.0 / D.sr, 1.0)
		w[i] *= 1.0 if ph < 0.55 else 0.45
	D.mix(o, w)
	D.mix(o, drop(200.0, 90.0, 40.0, 80.0, 4.0, 0.0, 0.8, 0.3), TELE_S, -4.0)
	return o


func _c_tele_slam(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	D.mix(o, _warble(220.0, A5, [[1.0, 12.0], [1.0, -12.0]]))
	# the falling partner: 440 -> 220 under the rising voice, the interval opening
	var n := N(TELE_S)
	var f := D.penv(A4, 220.0, TELE_S, n)
	var p := D.svf_mod(D.pulse(f, 0.3), "bp", f, 3.0)
	p = D.amp(p, D.rise_db(14.0, TELE_S, n))
	D.fade_in(p, 0.5, 1.0)
	D.mix(o, p, 0.0, -7.0)
	D.mix(o, md("stone", 240.0, 60.0, 80.0, "mallet", 1, 5), TELE_S, -4.0)
	return o


func _c_slam(v: int) -> PackedFloat32Array:
	var o := out(720.0)
	D.mix(o, nz(1, "white", 10.0, "bp", 1500.0, 1.0, 0.1), 0.0, -2.0)
	D.mix(o, drop(P([130.0, 123.0], v), 55.0, 300.0, 450.0, 8.0, 1400.0, 1.6))
	D.mix(o, weight(md("stone", 240.0, 250.0, 450.0, "noise", 2, 5), 180.0, 4.0, 0.8), 0.0, -3.0)
	D.mix(o, nz(3, "brown", 400.0, "lp", 900.0, 0.7071, 2.0), 10.0, -8.0)
	return D.room(o, "S", 0.12, 0.4)


func _c_fuse(_v: int) -> PackedFloat32Array:
	var o := out(45.0)
	var b := D.svf(D.fit(osc("pulse", F(A5, 5.0), D.aenv(0.3, 4.5, N(5.0)), 0.3), N(40.0)), "bp", A5, 8.0)
	D.mix(o, D.amp(b, D.aenv(0.1, 38.0, N(40.0))))
	D.mix(o, nz(1, "white", 3.0, "bp", 3000.0, 1.0, 0.1), 0.0, -10.0)
	return o


func _c_fuse_pop(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	D.mix(o, nz(1, "white", 5.0, "hp", 2000.0, 0.7071, 0.1), 0.0, -2.0)
	D.mix(o, drop(P([260.0, 245.0], v), 90.0, 150.0, 250.0, 6.0, 1500.0, 1.2))
	D.mix(o, nz(2, "pink", 200.0, "lp", 2500.0, 0.7071, 1.0), 0.0, -6.0)
	return D.crush(o, 3, 8.0, 0.4)


func _c_summon(v: int) -> PackedFloat32Array:
	var o := out(460.0)
	var k := D.ks(220.0, 0.4, 0.2, 0.2, N(450.0), R(1))
	k = D.varispeed(k, D.penv(1.0, D.st(2.0), 350.0, N(450.0)), N(440.0))
	D.fade_in(k, 0.0, 30.0)
	D.mix(o, weight(k, 250.0, 3.0, 0.5))
	D.mix(o, D.grain(N(250.0), R(2), 30.0, 8.0, "sine", 3000.0, 5000.0), P([80.0, 120.0], v), -4.0)
	return o


func _c_ward_up(v: int) -> PackedFloat32Array:
	var o := out(460.0)
	var n := N(260.0)
	D.mix(o, fmt(D.penv(1046.5, C7, 200.0, n), 1.41, 1.0, 0.4, 250.0, 20.0, 230.0), 0.0, -2.0)
	D.mix(o, md("glass", P([4186.0, 3951.0], v), 300.0, 250.0, "mallet", 1, 4), 200.0, -4.0)
	return o


func _c_charge(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	D.mix(o, nzs(1, "pink", 350.0, 500.0, P([1500.0, 1300.0], v), 250.0, 2.0, 30.0))
	var n := N(330.0)
	var s := D.sat(osc("saw", F(110.0, 330.0), D.aenv(20.0, 310.0, n)), 3.0)
	s = D.am(s, P([18.0, 15.0], v), 0.8, "square")
	D.mix(o, weight(D.svf(s, "lp", 900.0, 0.7071), 180.0, 4.0, 0.8), 0.0, -3.0)
	return o


func _c_bonk(v: int) -> PackedFloat32Array:
	var o := out(420.0)
	D.mix(o, nz(1, "white", 5.0, "bp", 2000.0, 1.0, 0.1), 0.0, -3.0)
	D.mix(o, md("wood", P([300.0, 283.0], v), 120.0, 250.0, "mallet", 2, 3))
	D.mix(o, drop(180.0, 120.0, 80.0, 150.0, 3.0, 0.0, 1.0), 0.0, -3.0)
	D.mix(o, sigils([E7, G7, A7, G7, A7], 30.0, 30.0, 0.3), 150.0, -12.0)
	D.mix(o, D.grain(N(180.0), R(3), 30.0, 60.0, "glass", 2600.0, 3600.0), 150.0, -12.0)
	return o


func _c_spawn(_v: int) -> PackedFloat32Array:
	var o := out(830.0)
	var n := N(800.0)
	var b := D.svf_mod(D.noise(n, R(1), "pink"), "bp", D.penv(400.0, 2500.0, 700.0, n), 5.0)
	var rise := D.env([[0.0, 0.05, 0.0], [700.0, 1.0, -3.0], [800.0, 0.0, 4.0]], n)
	D.mix(o, D.amp(b, rise), 0.0, 3.0)
	D.mix(o, D.amp(D.fm(D.penv(A4, A5, 700.0, n), 1.41, D.const_curve(1.0, n)), rise), 0.0, -8.0)
	D.mix(o, nz(2, "white", 4.0, "bp", 2000.0, 1.0, 0.1), 700.0, -4.0)
	return o


func _c_burn(v: int) -> PackedFloat32Array:
	return D.fit(crk(1, 45.0, P([700.0, 900.0, 800.0], v), P([3000.0, 2600.0, 3600.0], v), 0.85), N(60.0))


func _c_freeze(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	D.mix(o, md("glass", E7 * D.st(P([0.0, -1.0], v)), 250.0, 350.0, S(["mallet", "noise"], v), 1, 4))
	var n := N(220.0)
	var w := D.svf_mod(D.svf(D.noise(n, R(2), "white"), "hp", 5000.0, 0.7071), "lp", D.penv(8000.0, 4000.0, 200.0, n), 0.9)
	D.mix(o, D.amp(w, D.aenv(20.0, 190.0, n)), 0.0, -6.0)
	D.mix(o, fmt(F(E6, 250.0), 1.41, 1.0, 0.0, 200.0, 1.0, 240.0), 0.0, -8.0)
	return o


func _c_panic(_v: int) -> PackedFloat32Array:
	var o := out(610.0)
	var n := N(600.0)
	var f := D.zeros(n)
	for i in n:
		f[i] = E6 if fmod(float(i) * 8.0 / D.sr, 1.0) < 0.5 else 1244.51
	var s := D.svf(D.sat(D.pulse(f, 0.4), 2.0), "lp", 3000.0, 0.7071)
	D.mix(o, D.amp(s, D.env([[0.0, 0.0, 0.0], [5.0, 0.7, 0.0], [590.0, 1.0, 0.0], [600.0, 0.0, 0.0]], n)))
	return o


func _c_blink_charge(_v: int) -> PackedFloat32Array:
	var o := out(460.0)
	for i in 15:
		D.mix(o, D.sigil(A5 * pow(2.0, i / 14.0), 25.0, 0.4), 30.0 * i, -6.0 + 0.4 * i)
	return D.crush(o, 2, 6.0, 0.6)


func _c_blink_land(v: int) -> PackedFloat32Array:
	var o := out(190.0)
	var w := D.reverse(D.whoosh(N(120.0), R(1), 1000.0, P([5000.0, 4200.0], v), 120.0, 1.5, 0.3))
	D.mix(o, w, 0.0, -2.0)
	D.mix(o, D.crush(drop(600.0, 300.0, 30.0, 60.0, 3.0, 0.0, 0.0, 0.5), 3, 5.0, 0.6), 120.0)
	return o


func _c_thorns(v: int) -> PackedFloat32Array:
	var o := out(460.0)
	var r := R(1)
	var steps := [0, 3, 5, 7, 10, 12]
	for i in 6:
		var at := r.randf() * 380.0
		var f := 330.0 * D.st(float(steps[r.randi() % 6]) - 5.0 + 2.0 * v)
		var k := D.ks(f, 0.2, 0.5, 0.2, N(90.0), R(10 + i))
		D.fade_in(k, 0.0, 10.0)
		D.mix(o, k, at, -2.0)
	D.mix(o, D.grain(N(440.0), R(2), 60.0, 12.0, "noise", 2000.0, 4000.0), 0.0, -8.0)
	return o


func _c_thorns_spark(v: int) -> PackedFloat32Array:
	var o := out(460.0)
	var n := N(440.0)
	var c := D.amp(D.crackle(n, R(1), P([900.0, 1200.0], v), 0.85, P([3500.0, 4200.0], v), 1.0), D.env([[0.0, 0.0, 0.0], [20.0, 1.0, 0.0], [440.0, 0.0, 1.0]], n))
	D.mix(o, c, 0.0, 2.0)
	D.mix(o, D.sigil(A6, 20.0, 0.6), 0.0, -6.0)
	return o


## trail_loop: the Loop's burning chase trail, a seamless 2.0 s loop (every periodic part
## completes whole cycles; the noise crossfades over the seam).
func _c_trail_loop(_v: int) -> PackedFloat32Array:
	var L := N(2000.0)
	var xf := N(200.0)
	var tex := D.svf(D.noise(L + xf, R(1), "pink"), "bp", 1200.0, 1.5)
	D.mix_at(tex, D.grain(L + xf, R(2), 60.0, 4.0, "noise", 2000.0, 3500.0), 0, D.db2lin(-3.0))
	tex = D.loop_xfade(tex, L, xf)
	# the hum: 55 Hz, 110 whole cycles in 2 s; rendered twice so the phantom's filters settle
	var hum := D.sine(D.const_curve(55.0, 2 * L))
	hum = D.second_half(weight(D.sat(hum, 3.0), 180.0, 4.0, 1.5, -12.0))
	return D.add(tex, hum, -4.0)


func _c_box_fill(_v: int) -> PackedFloat32Array:
	var o := out(360.0)
	var n := N(300.0)
	var w := D.svf_mod(D.noise(n, R(1), "white"), "bp", D.penv(800.0, 4000.0, 250.0, n), 2.0)
	D.mix(o, D.crush(D.amp(w, D.aenv(10.0, 280.0, n)), 3, 6.0, 0.7), 0.0, -4.0)
	var ps: Array = []
	for i in 8:
		ps.append(A6 * pow(2.0, i / 7.0))
	D.mix(o, sigils(ps, 25.0, 20.0, 0.6), 0.0, -2.0)
	D.mix(o, drop(E5, 330.0, 30.0, 120.0, 4.0, 1200.0, 0.0), 210.0, -2.0)
	return o


func _c_trash(_v: int) -> PackedFloat32Array:
	var o := out(610.0)
	var n := N(600.0)
	var g := D.svf_mod(D.noise(n, R(1), "brown"), "bp", D.penv(300.0, 900.0, 600.0, n, "lin"), 2.0)
	g = D.am(g, 16.0, 0.8, "square")
	D.mix(o, D.amp(g, D.env([[0.0, 0.0, 0.0], [40.0, 1.0, 0.0], [520.0, 0.8, 0.0], [600.0, 0.0, 0.0]], n)), 0.0, 3.0)
	var r := R(2)
	for i in 4:
		D.mix(o, md("plate", 700.0 * D.st(r.randf_range(-2.0, 2.0)), 150.0, 150.0, "noise", 3 + i, 5), 60.0 + 130.0 * i + r.randf() * 50.0, -4.0)
	return D.crush(o, 2, 7.0, 0.4)


func _c_elite_arrive(_v: int) -> PackedFloat32Array:
	var o := out(520.0)
	for step in 2:
		var f := A4 if step == 0 else 622.25
		var ms := 380.0 - 120.0 * step
		var s := D.sat(D.add(D.saw(F(f, ms)), D.saw(F(f * 1.0114, ms), 0.4)), 3.0)
		s = D.svf(s, "lp", 2200.0, 1.0)
		D.mix(o, D.amp(s, D.aenv(4.0, ms - 10.0, N(ms))), 120.0 * step, -2.0)
	D.mix(o, md("brass", A5, 400.0, 500.0, "mallet", 1, 4), 0.0, -4.0)
	return o


func _c_hit_proxy(v: int) -> PackedFloat32Array:
	var o := out(155.0)
	D.mix(o, click(0.6))
	D.mix(o, md("plate", C7 * D.st(P([0.0, 1.0, -1.0], v)), 60.0, 100.0, "mallet", 1, 5))
	var n := N(150.0)
	D.mix(o, osc("sine", D.penv(E7, A6, 120.0, n), D.aenv(2.0, 140.0, n)), 0.0, -6.0)
	return o


func _c_thermal(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	var n := N(350.0)
	var s := D.svf_mod(D.svf(D.noise(n, R(1), "white"), "hp", 3000.0, 0.7071), "bp", D.penv(6000.0, 2000.0, 250.0, n), 1.5)
	D.mix(o, D.amp(s, D.aenv(5.0, 340.0, n)))
	D.mix(o, md("glass", A6, 120.0, 200.0, S(["impulse", "noise"], v), 2, 4), 0.0, -2.0)
	D.mix(o, drop(400.0, 200.0, 80.0, 200.0, 4.0, 0.0, 0.8), 0.0, -4.0)
	return o


# ------------------------------------------------------------------ bosses (§4.7)

func _c_tele_boss(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	D.mix(o, _warble(165.0, E5, [[1.0, 12.0], [1.0, -12.0], [0.5, 0.0]]))
	# the sub partner at half pitch, saturated with its phantom, well under the warble
	var n := N(TELE_S)
	var sub := D.sine(D.penv(82.5, 330.0, TELE_S, n))
	sub = weight(D.sat(D.amp(sub, D.rise_db(18.0, TELE_S, n)), 2.0), 180.0, 4.0, 0.5)
	D.fade_in(sub, 0.5, 1.0)
	D.mix(o, sub, 0.0, -14.0)
	D.mix(o, md("stone", 240.0, 80.0, 90.0, "mallet", 1, 5), TELE_S, -3.0)
	D.mix(o, nz(2, "white", 4.0, "bp", 1000.0, 1.5, 0.1), TELE_S, -6.0)
	return o


func _c_copy_cast(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	var n := N(TELE_S)
	# your own cast sigils looping, reversed, glitched and combed, rising to the stop
	var lp := D.zeros(n)
	var ps := [A6, C7, E7, A7]
	var i := 0
	var t := 0.0
	while t < TELE_S:
		D.mix(lp, D.sigil(float(ps[i % 4]), 30.0, 0.5), t)
		t += 55.0
		i += 1
	lp = D.reverse(lp)
	lp = D.crush(D.stutter(lp, 400.0, 30.0, 2), 6, 5.0, 0.8)
	lp = D.comb(D.fit(lp, n), 2.3, 0.7, 0.5)
	lp = D.amp(lp, D.rise_db(18.0, TELE_S, n))
	D.fade_in(lp, 0.5, 1.0)
	D.mix(o, lp, 0.0, -4.0)
	D.mix(o, _warble(220.0, A5, [[1.0, 12.0], [1.0, -12.0]]))
	D.mix(o, nz(1, "white", 4.0, "bp", 1000.0, 1.5, 0.1), TELE_S, -6.0)
	return o


## select_all: the Ctrl-A chime sits at 0.5 s (inside both wind-ups, 1.2 s and 1.02 s, which
## start the master at 0.3 s and 0.48 s), then the warble with marching-ant ticks for tremolo.
func _c_select_all(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	var n := N(TELE_S)
	D.mix(o, _warble(220.0, A5, [[1.0, 12.0], [1.0, -12.0]], 8.0, 24.0, 3.0))
	# the ticks: sigil pulses at 8 -> 24 Hz, rising with the swell
	var rate := D.penv(8.0, 24.0, TELE_S, n)
	var ph := 0.0
	var ticks := D.zeros(n)
	for s in n:
		ph += rate[s] / D.sr
		if ph >= 1.0:
			ph -= 1.0
			D.mix_at(ticks, D.sigil(A6, 8.0, 0.4), s, 1.0)
	D.mix(o, D.amp(ticks, D.rise_db(18.0, TELE_S, n)), 0.0, -8.0)
	D.mix(o, sigils([A6, C7, E7], 60.0, 40.0, 0.8), 500.0, -10.0)
	D.mix(o, nz(1, "white", 4.0, "bp", 1000.0, 1.5, 0.1), TELE_S, -6.0)
	return o


func _c_tele_collect(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	var n := N(TELE_S)
	var f := D.penv(200.0, 900.0, TELE_S, n)
	var suck := D.svf_mod(D.noise(n, R(1), "brown"), "bp", f, 3.0)
	suck = D.amp(suck, D.rise_db(18.0, TELE_S, n))
	D.fade_in(suck, 0.5, 1.0)
	D.mix(o, suck, 0.0, 2.0)
	D.mix(o, _warble(220.0, A5, [[1.0, 0.0]]), 0.0, -2.0)
	D.mix(o, drop(300.0, 120.0, 40.0, 70.0, 3.0, 0.0, 0.6, 0.3), TELE_S, -4.0)
	D.mix(o, click(0.6), TELE_S)
	return o


func _c_tele_lap(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	D.mix(o, _warble(220.0, A5, [[1.0, 12.0], [1.0, -12.0]]))
	var n := N(TELE_S)
	var rate := D.penv(4.0, 16.0, TELE_S, n)
	var ph := 0.0
	var lvl := D.rise_db(12.0, TELE_S, n)
	var clack := md("wood", 180.0, 80.0, 60.0, "mallet", 1, 3)
	for s in n:
		ph += rate[s] / D.sr
		if ph >= 1.0 and s < n - N(70.0):
			ph -= 1.0
			D.mix_at(o, clack, s, 0.25 * lvl[s])
	for k in 2:
		D.mix(o, md("wood", 180.0, 80.0, 90.0, "mallet", 2, 3), TELE_S + 60.0 * k - 60.0, -6.0)
	return o


func _c_tele_sweep(_v: int) -> PackedFloat32Array:
	var o := _tele_out()
	var n := N(TELE_S)
	var bend := D.penv(1.0, 2.0, TELE_S, n)
	var f1 := D.zeros(n)
	var f2 := D.zeros(n)
	for i in n:
		f1[i] = 110.0 * bend[i]
		f2[i] = 165.0 * bend[i]
	var hum := D.sat(D.add(D.saw(f1), D.saw(f2, 0.3)), 4.0)
	hum = D.svf(hum, "bp", 800.0, 2.0)
	hum = D.amp(hum, D.rise_db(18.0, TELE_S, n))
	D.fade_in(hum, 0.5, 1.0)
	D.mix(o, hum, 0.0, -2.0)
	D.mix(o, _warble(220.0, A5, [[1.0, 12.0], [1.0, -12.0]]), 0.0, -3.0)
	return o


func _c_ctrl_z(_v: int) -> PackedFloat32Array:
	var o := out(360.0)
	var n := N(320.0)
	var f := D.penv(2640.0, 330.0, 300.0, n)
	var s := D.svf_mod(D.saw(f), "bp", f, 5.0)
	D.mix(o, D.amp(s, D.env([[0.0, 0.0, 0.0], [10.0, 1.0, 0.0], [300.0, 0.7, 0.0], [320.0, 0.0, 0.0]], n)))
	D.mix(o, D.reverse(nz(1, "pink", 300.0, "bp", 1500.0, 1.0, 1.0)), 0.0, -8.0)
	D.mix(o, click(0.7), 320.0)
	return o


func _c_paste(_v: int) -> PackedFloat32Array:
	var o := out(310.0)
	var s := sigils([E7, A6], 60.0, 30.0, 0.9)
	D.mix(o, D.comb(D.fit(s, N(160.0)), 1.13, 0.6, 0.6))
	D.mix(o, D.grain(N(150.0), R(1), 60.0, 8.0, "sine", 3000.0, 5000.0), 140.0, -4.0)
	return o


func _c_chomp(v: int) -> PackedFloat32Array:
	var o := out(260.0)
	D.mix(o, nz(1, "white", 8.0, "bp", 2000.0, 1.0, 0.1), 0.0, -2.0)
	for k in 2:
		D.mix(o, weight(md("wood", P([180.0, 170.0], v), 80.0, 120.0, "mallet", 2 + k, 3), 250.0, 4.0, 1.0), 60.0 * k)
	D.mix(o, drop(200.0, 90.0, 100.0, 200.0, 5.0, 1200.0, 1.2), 0.0, -3.0)
	return o


## beam: the Deadlock beam, a seamless 1.0 s loop. The saws (110 and 165 Hz) and the 2 Hz sweep
## complete whole cycles in 44,100 samples; the render runs twice so every filter settles and
## the second pass is kept; the crackle crossfades over the seam.
func _c_beam(_v: int) -> PackedFloat32Array:
	var L := N(1000.0)
	var n := 2 * L
	var hum := D.sat(D.add(D.saw(D.const_curve(110.0, n)), D.saw(D.const_curve(165.0, n), 0.25)), 4.0)
	hum = weight(hum, 180.0, 4.0, 0.8)
	var sweep := D.lfo(2.0, 1.0, "sine", n)
	var fc := D.zeros(n)
	for i in n:
		fc[i] = 800.0 * pow(2.0, 0.6 * sweep[i])
	hum = D.second_half(D.svf_mod(hum, "bp", fc, 3.0))
	var xf := N(100.0)
	var c := D.loop_xfade(D.crackle(L + xf, R(1), 400.0, 0.82, 4000.0, 1.0), L, xf)
	D.mix_at(hum, c, 0, D.db2lin(-14.0) * 4.0)
	return hum


func _c_derail(_v: int) -> PackedFloat32Array:
	var o := out(1000.0)
	var n := N(600.0)
	var s := osc("saw", D.penv(A6, A4, 600.0, n), D.env([[0.0, 0.0, 0.0], [10.0, 1.0, 0.0], [560.0, 0.8, 0.0], [600.0, 0.0, 0.0]], n))
	D.mix(o, D.comb(D.fit(D.svf(s, "lp", 3000.0, 0.7071), N(640.0)), 2.2, 0.8, 0.6), 0.0, -3.0)
	D.mix(o, weight(md("plate", 300.0, 600.0, 580.0, "noise", 1, 8), 250.0, 4.0, 1.0), 400.0)
	D.mix(o, md("brass", A5, 600.0, 400.0, "mallet", 2, 4), 580.0, -4.0)
	D.mix(o, md("brass", E6, 600.0, 320.0, "mallet", 3, 4), 680.0, -5.0)
	return o


func _c_roar(_v: int) -> PackedFloat32Array:
	var o := out(1120.0)
	var n := N(1100.0)
	var s := D.add(D.add(D.saw(F(110.0, 1100.0)), D.saw(F(111.5, 1100.0), 0.4)), D.pulse(F(55.0, 1100.0), 0.3), -4.0)
	s = D.sat(s, 8.0)
	s = D.svf_mod(s, "lp", D.penv(2500.0, 700.0, 900.0, n), 3.0)
	s = D.add(D.add(s, D.svf(s, "bp", 700.0, 4.0), 2.0), D.svf(s, "bp", 1200.0, 4.0), 0.0)
	s = D.am(s, 25.0, 0.3)
	s = weight(s, 180.0, 4.0, 0.8)
	s = D.amp(s, D.env([[0.0, 0.0, 0.0], [60.0, 1.0, 0.0], [700.0, 0.8, 0.0], [1100.0, 0.0, 2.0]], n))
	D.mix(o, D.crush(s, 2, 6.0, 0.2))
	return o


func _c_phase(_v: int) -> PackedFloat32Array:
	var o := out(1800.0)
	D.mix(o, nz(1, "white", 10.0, "hp", 2000.0, 0.7071, 0.2), 600.0, -3.0)
	var sw := fmt(F(220.0, 600.0), 2.756, 4.0, 0.0, 600.0, 1.0, 590.0)
	D.mix(o, D.reverse(sw), 0.0, -2.0)
	D.mix(o, md("bell", 220.0, 1500.0, 1200.0, "mallet", 2, 8), 600.0)
	var sub := D.sat(osc("sine", F(55.0, 1200.0), D.aenv(5.0, 1190.0, N(1200.0))), 4.0)
	D.mix(o, weight(sub, 180.0, 4.0, 1.2), 600.0, -4.0)
	var bits := D.env([[0.0, 12.0, 0.0], [600.0, 12.0, 0.0], [1600.0, 4.0, 0.0]], o.size())
	return D.crush(o, 1, 12.0, 0.5, bits)


func _c_key_turn(_v: int) -> PackedFloat32Array:
	var o := out(310.0)
	for k in 2:
		D.mix(o, md("plate", A5, 200.0, 220.0, "mallet", 1 + k, 6), 70.0 * k, -2.0)
	D.mix(o, sigils([A6, E7], 50.0, 30.0, 0.8), 140.0)
	return o


func _c_weak_open(_v: int) -> PackedFloat32Array:
	var o := out(420.0)
	var g := [0.4, 1.0, 0.4, 0.1]
	D.mix(o, md("brass", A5, 700.0, 400.0, "mallet", 1, 4, g))
	D.mix(o, md("brass", E6, 700.0, 300.0, "mallet", 2, 4, g), 100.0, -2.0)
	D.mix(o, D.sigil(A7, 15.0, 0.6), 100.0, -8.0)
	return o


func _c_gulp(v: int) -> PackedFloat32Array:
	var o := out(310.0)
	D.mix(o, nzs(1, "brown", 280.0, 400.0, 200.0, 200.0, 4.0, 10.0), 0.0, 4.0)
	D.mix(o, drop(P([300.0, 283.0], v), 120.0, 150.0, 250.0, 4.0, 0.0, 1.0, 5.0))
	return D.crush(o, 5, 6.0, 0.5)


func _c_choked(_v: int) -> PackedFloat32Array:
	var o := out(620.0)
	for k in 2:
		D.mix(o, weight(nz(1 + k, "brown", 110.0, "bp", 600.0, 2.0, 5.0), 250.0, 4.0, 0.6), 140.0 * k, 4.0)
	var g := [0.4, 1.0, 0.4, 0.1]
	D.mix(o, md("brass", A5, 700.0, 330.0, "mallet", 3, 4, g), 290.0, -2.0)
	D.mix(o, md("brass", E6, 700.0, 230.0, "mallet", 4, 4, g), 390.0, -3.0)
	return o


func _c_segment_break(v: int) -> PackedFloat32Array:
	var o := out(360.0)
	D.mix(o, weight(md("plate", P([520.0, 490.0], v), 250.0, 340.0, "noise", 1, 8), 250.0, 4.0, 0.8))
	D.mix(o, crk(2, 150.0, 900.0, 3000.0), 0.0, -3.0)
	D.mix(o, D.crush(sigils([E7, C7, A6], 40.0, 30.0, 0.8), 3, 5.0, 0.8), 60.0, -4.0)
	return o


func _c_loop_jr(_v: int) -> PackedFloat32Array:
	var o := out(420.0)
	var n := N(400.0)
	var s := D.sat(D.add(D.saw(F(220.0, 400.0)), D.saw(F(223.0, 400.0), 0.4)), 6.0)
	s = D.svf_mod(s, "lp", D.penv(3500.0, 1000.0, 350.0, n), 3.0)
	s = D.add(s, D.svf(s, "bp", 1400.0, 4.0), 0.0)
	s = D.amp(D.am(s, 25.0, 0.3), D.env([[0.0, 0.0, 0.0], [25.0, 1.0, 0.0], [400.0, 0.0, 2.0]], n))
	D.mix(o, D.comb(s, 1.13, 0.5, 0.5))
	return o


func _c_back_on_track(_v: int) -> PackedFloat32Array:
	var o := out(620.0)
	var n := N(500.0)
	var s := osc("saw", D.penv(A4, A6, 500.0, n), D.env([[0.0, 0.0, 0.0], [20.0, 0.8, 0.0], [490.0, 1.0, 0.0], [500.0, 0.0, 0.0]], n))
	D.mix(o, D.comb(D.fit(D.svf(s, "lp", 3000.0, 0.7071), N(520.0)), 2.2, 0.75, 0.6), 0.0, -2.0)
	D.mix(o, weight(md("wood", 200.0, 90.0, 110.0, "mallet", 1, 3), 250.0, 4.0, 1.0), 500.0)
	return o


# ------------------------------------------------------------------ the world (§4.8)

func _c_crate(v: int) -> PackedFloat32Array:
	var o := out(260.0)
	D.mix(o, weight(md("wood", P([260.0, 245.0, 277.0], v), 90.0, 200.0, S(["mallet", "noise", "impulse"], v), 1, 3), 200.0, 4.0, 0.8))
	D.mix(o, nz(2, "white", 60.0, "bp", 1500.0, 1.0, 0.3), 0.0, -4.0)
	D.mix(o, D.grain(N(150.0), R(3), 30.0, 15.0, "wood", 900.0, 2400.0), 15.0, -6.0)
	return o


func _c_pod_pop(v: int) -> PackedFloat32Array:
	var o := out(310.0)
	D.mix(o, drop(600.0, 200.0, 40.0, 120.0, 3.0, 0.0, 0.8, 0.5))
	D.mix(o, nz(1, "pink", 150.0, "bp", P([1000.0, 1250.0], v), 2.0, 1.0), 0.0, -3.0)
	D.mix(o, D.grain(N(200.0), R(2), 50.0, 10.0, "noise", 1500.0, 3500.0), 20.0, -8.0)
	return o


func _c_bramble_burn(v: int) -> PackedFloat32Array:
	var o := out(610.0)
	D.mix(o, D.grain(N(500.0), R(1), 120.0, 3.0, "noise", 2500.0, 5000.0, thin(500.0, 0.3)))
	D.mix(o, nzs(2, "pink", 600.0, 1000.0, P([3000.0, 3600.0], v), 500.0, 1.0, 40.0), 0.0, -4.0)
	return o


func _c_crack_open(_v: int) -> PackedFloat32Array:
	var o := out(720.0)
	D.mix(o, weight(md("stone", 200.0, 300.0, 500.0, "noise", 1, 5), 250.0, 4.0, 1.2))
	D.mix(o, nz(2, "brown", 500.0, "lp", 1500.0, 0.7071, 5.0), 20.0, -4.0)
	D.mix(o, D.grain(N(500.0), R(3), 60.0, 20.0, "stone", 800.0, 2500.0), 20.0, -6.0)
	return o


func _c_secret(_v: int) -> PackedFloat32Array:
	var o := out(1000.0)
	var ps := [A6, E7, C7]
	for i in 3:
		D.mix(o, md("glass", float(ps[i]), 500.0, 700.0, "mallet", 1 + i, 4), 110.0 * i, -2.0)
	D.mix(o, D.grain(N(700.0), R(5), 25.0, 60.0, "glass", 5000.0, 8000.0, thin(700.0)), 200.0, -10.0)
	return o


func _c_pylon(_v: int) -> PackedFloat32Array:
	var o := out(1200.0)
	D.mix(o, md("bell", A4, 1200.0, 1150.0, "mallet", 1, 8))
	D.mix(o, fmt(F(A5, 600.0), 3.5, 2.0, 0.0, 300.0, 1.0, 590.0), 0.0, -6.0)
	return o


func _c_pit_fall(_v: int) -> PackedFloat32Array:
	var o := out(510.0)
	var n := N(500.0)
	D.mix(o, osc("sine", D.penv(E6, 330.0, 450.0, n), D.env([[0.0, 0.0, 0.0], [5.0, 1.0, 0.0], [500.0, 0.0, 1.0]], n)))
	D.mix(o, nz(1, "pink", 500.0, "lp", 1000.0, 0.7071, 20.0), 0.0, -8.0)
	return o


func _c_chest(_v: int) -> PackedFloat32Array:
	var o := out(720.0)
	var n := N(260.0)
	var k := D.ks(90.0, 0.3, 0.8, 0.1, n, R(1))
	k = D.varispeed(k, D.penv(1.0, D.st(1.0), 250.0, n), n)
	D.mix(o, weight(D.svf(k, "hp", 150.0, 0.7071), 180.0, 4.0, 1.0), 0.0, -3.0)
	D.mix(o, weight(md("wood", 180.0, 150.0, 250.0, "mallet", 2, 3), 250.0, 4.0, 1.2), 250.0)
	D.mix(o, D.grain(N(400.0), R(3), 30.0, 80.0, "glass", 3000.0, 6000.0, thin(400.0)), 280.0, -10.0)
	return o


func _c_forge(v: int) -> PackedFloat32Array:
	var o := out(920.0)
	D.mix(o, md("plate", P([620.0, 587.0], v), 600.0, 900.0, "mallet", 1, 8))
	D.mix(o, md("brass", 1240.0 * D.st(P([0.0, -1.0], v)), 600.0, 800.0, "mallet", 2, 4), 0.0, -4.0)
	D.mix(o, nz(3, "white", 10.0, "hp", 3000.0, 0.7071, 0.1), 0.0, -4.0)
	D.mix(o, nz(4, "white", 300.0, "hp", 4000.0, 0.7071, 60.0), 120.0, -14.0)
	return o


## altar: a reversed bell swell into the bell and its minor third; 1.2 s (the spec's 1.5 s is
## trimmed to the SFX length ceiling of §7.12).
func _c_altar(_v: int) -> PackedFloat32Array:
	var o := out(1200.0)
	D.mix(o, D.reverse(md("bell", 220.0, 800.0, 400.0, "mallet", 1, 8)), 0.0, -4.0)
	D.mix(o, md("bell", 220.0, 1000.0, 800.0, "mallet", 2, 8), 400.0)
	D.mix(o, md("bell", 261.63, 1000.0, 780.0, "mallet", 3, 8), 420.0, -6.0)
	var sub := D.sat(osc("sine", F(110.0, 780.0), D.aenv(5.0, 770.0, N(780.0))), 4.0)
	D.mix(o, weight(sub, 180.0, 4.0, 1.0), 400.0, -8.0)
	return o


func _c_door(_v: int) -> PackedFloat32Array:
	var o := out(720.0)
	var n := N(560.0)
	var b := D.svf_mod(D.noise(n, R(1), "brown"), "lp", D.penv(400.0, 1200.0, 500.0, n), 1.2)
	D.mix(o, weight(D.amp(b, D.env([[0.0, 0.0, 0.0], [60.0, 1.0, 0.0], [500.0, 0.8, 0.0], [560.0, 0.0, 0.0]], n)), 250.0, 4.0, 1.0), 0.0, 4.0)
	D.mix(o, D.grain(n, R(2), 60.0, 10.0, "stone", 700.0, 2000.0), 0.0, -6.0)
	D.mix(o, weight(md("stone", 120.0, 150.0, 160.0, "mallet", 3, 5), 250.0, 4.0, 1.5), 540.0)
	return o


func _c_door_shut(_v: int) -> PackedFloat32Array:
	var o := out(520.0)
	D.mix(o, weight(md("stone", 160.0, 200.0, 300.0, "noise", 1, 5), 250.0, 4.0, 1.5))
	D.mix(o, nz(2, "white", 8.0, "bp", 1500.0, 1.0, 0.1), 0.0, -4.0)
	D.mix(o, D.grain(N(300.0), R(3), 40.0, 30.0, "noise", 1200.0, 3000.0, thin(300.0)), 20.0, -8.0)
	return D.room(o, "S", 0.10, 0.4)


func _c_glitch_toll(_v: int) -> PackedFloat32Array:
	var o := out(820.0)
	var g := md("glass", A6, 400.0, 400.0, "mallet", 1, 4)
	D.mix(o, D.stutter(D.crush(g, 4, 5.0, 1.0), 40.0, 40.0, 3))
	D.mix(o, drop(110.0, 55.0, 300.0, 600.0, 6.0, 1200.0, 1.4), 0.0, -3.0)
	return o


# ------------------------------------------------------------------ rewards and progression (§4.9)

func _c_coin(v: int) -> PackedFloat32Array:
	var o := out(115.0)
	D.mix(o, md("glass", A7, 80.0, 110.0, S(["impulse", "mallet", "noise"], v), 1, 4))
	D.mix(o, D.sigil(E8, 8.0, P([0.6, 0.3, 0.9], v)), 0.0, -4.0)
	return o


func _c_heal(_v: int) -> PackedFloat32Array:
	var o := out(620.0)
	var ps := [A6, CS7, E7]
	for i in 3:
		D.mix(o, md("glass", float(ps[i]), 350.0, 500.0, "mallet", 1 + i, 4), 60.0 * i, -2.0)
	D.mix(o, osc("sine", F(A5, 460.0), D.aenv(50.0, 400.0, N(460.0))), 0.0, -10.0)
	return o


func _c_heal_small(v: int) -> PackedFloat32Array:
	var o := out(260.0)
	D.mix(o, md("glass", P([E7, CS7], v), 200.0, 250.0, "mallet", 1, 4))
	var n := N(240.0)
	D.mix(o, osc("sine", F(E6, 240.0), D.env([[0.0, 0.0, 0.0], [80.0, 1.0, -2.0], [240.0, 0.0, 2.0]], n)), 0.0, -8.0)
	return o


func _c_heart(_v: int) -> PackedFloat32Array:
	var o := out(820.0)
	var ps := [A6, CS7, E7]
	for i in 3:
		D.mix(o, md("glass", float(ps[i]), 350.0, 500.0, "mallet", 1 + i, 4), 60.0 * i, -3.0)
	D.mix(o, drop(A4 * 0.5, 247.0, 60.0, 150.0, 4.0, 900.0, 1.0, 2.0), 250.0, -2.0)
	D.mix(o, drop(247.0, 262.0, 60.0, 150.0, 4.0, 900.0, 1.0, 2.0), 420.0, -2.0)
	D.mix(o, md("brass", A5, 500.0, 500.0, "mallet", 5, 4), 300.0, -6.0)
	return o


func _c_relic_proc(v: int) -> PackedFloat32Array:
	var o := out(260.0)
	D.mix(o, md("glass", G7 * D.st(P([0.0, 2.0], v)), 150.0, 250.0, "mallet", 1, 4))
	D.mix(o, md("brass", G6, 200.0, 250.0, "mallet", 2, 4), 0.0, -6.0)
	return o


func _c_caught(_v: int) -> PackedFloat32Array:
	var o := out(1200.0)
	D.mix(o, md("brass", A5, 900.0, 1150.0, "impulse", 1, 4))
	var ps := [A6, CS7, E7]
	for i in 3:
		D.mix(o, md("glass", float(ps[i]), 400.0, 600.0, "mallet", 2 + i, 4), 90.0 + 90.0 * i, -4.0)
	D.mix(o, D.grain(N(800.0), R(6), 25.0, 60.0, "glass", 4000.0, 7000.0, thin(800.0)), 300.0, -10.0)
	return o


func _c_wand_recharge(_v: int) -> PackedFloat32Array:
	var o := out(95.0)
	D.mix(o, D.sigil(A5, 20.0, 0.6))
	for k in 3:
		D.mix(o, nz(1 + k, "white", 4.0, "bp", 3000.0, 2.0, 0.1), 15.0 + 25.0 * k, -4.0)
	return o


# ------------------------------------------------------------------ UI (§4.10)

## The taps: a sigil on a small wooden key. The key rings 45 ms (a 70 ms file) so a tap carries
## its UI level without leaning on the limiter.
func _c_ui(v: int) -> PackedFloat32Array:
	var o := out(75.0)
	D.mix(o, D.sigil(C7, 16.0, P([0.5, 0.35], v)))
	D.mix(o, md("wood", P([1400.0, 1480.0], v), 45.0, 70.0, S(["mallet", "noise"], v), 1, 3), 0.0, -1.0)
	return o


func _c_ui_back(v: int) -> PackedFloat32Array:
	var o := out(75.0)
	D.mix(o, D.sigil(G6, 16.0, P([0.5, 0.35], v)))
	D.mix(o, md("wood", P([1050.0, 1110.0], v), 45.0, 70.0, S(["mallet", "noise"], v), 1, 3), 0.0, -1.0)
	return o


func _c_ui_open(v: int) -> PackedFloat32Array:
	var o := out(145.0)
	D.mix(o, nzs(1, "pink", 130.0, 1500.0, P([4000.0, 4800.0], v), 90.0, 1.5, 15.0))
	D.mix(o, D.sigil(A6, 12.0, 0.6), 0.0, -3.0)
	return o


func _c_ui_close(v: int) -> PackedFloat32Array:
	var o := out(135.0)
	D.mix(o, nzs(1, "pink", 120.0, P([4000.0, 4800.0], v), 1500.0, 90.0, 1.5, 10.0))
	D.mix(o, D.sigil(E6, 12.0, 0.6), 60.0, -3.0)
	return o


func _c_ui_equip(v: int) -> PackedFloat32Array:
	var o := out(210.0)
	D.mix(o, nz(1, "white", 3.0, "hp", 4000.0, 0.7071, 0.1), 0.0, -4.0)
	D.mix(o, md("glass", E7, 90.0, 150.0, S(["mallet", "noise"], v), 2, 4))
	D.mix(o, md("brass", E6, 150.0, 200.0, "mallet", 3, 4), 0.0, P([-4.0, -7.0], v))
	return o


func _c_ui_drag(_v: int) -> PackedFloat32Array:
	var o := out(85.0)
	var n := N(80.0)
	D.mix(o, osc("sine", D.penv(A5, E6, 60.0, n), D.aenv(3.0, 75.0, n)))
	D.mix(o, nz(1, "white", 30.0, "bp", 3000.0, 1.0, 2.0), 0.0, -8.0)
	return o


func _c_ui_drop(v: int) -> PackedFloat32Array:
	var o := out(95.0)
	D.mix(o, md("wood", P([700.0, 740.0], v), 60.0, 90.0, S(["mallet", "impulse"], v), 1, 3))
	D.mix(o, D.sigil(E6, 10.0, 0.6), 0.0, -3.0)
	return o


func _c_swap(_v: int) -> PackedFloat32Array:
	var o := out(115.0)
	for k in 2:
		D.mix(o, nz(1 + k, "white", 20.0, "bp", 2500.0, 2.0, 3.0), 45.0 * k)
	D.mix(o, sigils([A6, D7], 45.0, 20.0, 0.7), 0.0, -3.0)
	return o


func _c_deny(_v: int) -> PackedFloat32Array:
	var o := out(165.0)
	for k in 2:
		var b := D.add(D.pulse(F(220.0, 60.0), 0.25), D.pulse(F(233.08, 60.0), 0.25, PackedFloat32Array(), 0.3))
		D.mix(o, D.amp(D.svf(b, "lp", 1200.0, 0.7071), D.aenv(3.0, 55.0, N(60.0))), 80.0 * k)
	return o


func _c_buy(_v: int) -> PackedFloat32Array:
	var o := out(300.0)
	D.mix(o, md("glass", D7, 120.0, 150.0, "mallet", 1, 4))
	D.mix(o, md("glass", A7, 150.0, 220.0, "mallet", 2, 4), 70.0)
	D.mix(o, md("brass", A6, 200.0, 220.0, "impulse", 3, 4), 70.0, -6.0)
	return o


func _c_pick(_v: int) -> PackedFloat32Array:
	var o := out(460.0)
	var ps := [587.33, A5, 698.46]
	for i in 3:
		D.mix(o, fmt(F(float(ps[i]), 340.0), 3.5, 2.2, 0.3, 200.0, 1.0, 330.0), 60.0 * i, -2.0)
	D.mix(o, D.sigil(A6, 12.0, 0.6), 0.0, -6.0)
	return o


func _c_levelup(_v: int) -> PackedFloat32Array:
	var o := out(1100.0)
	var ps := [A5, E6, CS6, D6, E6, GS6, A6]
	for i in ps.size():
		D.mix(o, fmt(F(float(ps[i]), 300.0), 3.5, 2.2, 0.3, 150.0, 1.0, 280.0), 45.0 * i, -3.0)
	D.mix(o, md("brass", A5, 800.0, 800.0, "mallet", 1, 4), 45.0 * 6)
	D.mix(o, D.grain(N(700.0), R(2), 25.0, 60.0, "glass", 4000.0, 7000.0, thin(700.0)), 300.0, -10.0)
	return o


func _c_ui_confirm(_v: int) -> PackedFloat32Array:
	var o := out(185.0)
	D.mix(o, D.sigil(A6, 16.0))
	D.mix(o, D.sigil(E7, 16.0), 0.0, -2.0)
	D.mix(o, md("glass", A7, 150.0, 180.0, "mallet", 1, 4), 0.0, -2.0)
	return o


## compile: the anvil, then the Incantation in D minor on brass bars (D A F G A ‖ C D) and a
## shimmer on the tag.
func _c_compile(_v: int) -> PackedFloat32Array:
	var o := out(1600.0)
	D.mix(o, md("plate", 620.0, 600.0, 700.0, "mallet", 1, 8), 0.0, -2.0)
	var ps := [587.33, A5, 698.46, 783.99, A5, 1046.5, 1174.66]
	for i in ps.size():
		var tag := i >= 5
		D.mix(o, md("brass", float(ps[i]), 500.0 if tag else 250.0, 700.0 if tag else 300.0, "mallet", 2 + i, 4), 120.0 + 40.0 * i + (80.0 if tag else 0.0), -3.0)
	D.mix(o, D.grain(N(800.0), R(12), 25.0, 60.0, "glass", 4000.0, 7000.0, thin(800.0)), 500.0, -10.0)
	return o


func _c_unlock(_v: int) -> PackedFloat32Array:
	var o := out(1200.0)
	var ps := [D6, A6, 1479.98]
	for i in 3:
		D.mix(o, md("glass", float(ps[i]), 500.0, 700.0, "mallet", 1 + i, 4), 100.0 * i, -2.0)
	D.mix(o, md("brass", 587.33, 800.0, 900.0, "mallet", 5, 4), 300.0, -5.0)
	return o


func _c_ui_pick(v: int) -> PackedFloat32Array:
	var o := out(65.0)
	D.mix(o, md("glass", C7 * D.st(P([0.0, 2.0], v)), 50.0, 60.0, "mallet", 1, 4))
	D.mix(o, D.sigil(A6, 8.0, 0.5), 0.0, -3.0)
	return o


func _c_tip(_v: int) -> PackedFloat32Array:
	var o := out(65.0)
	D.mix(o, nz(1, "pink", 25.0, "bp", 3000.0, 1.5, 2.0))
	D.mix(o, D.sigil(E7, 10.0, 0.4), 5.0, -6.0)
	return o


## The Duck's non-verbal babble: one squeaky syllable through two formants (§4.10).
func _syllable(f: float, ms: float, crushed: bool) -> PackedFloat32Array:
	var n := N(ms)
	var s := D.saw(D.penv(f * 1.08, f, 25.0, n))
	var fm_ := D.add(D.svf(s, "bp", 1200.0, 5.0), D.svf(s, "bp", 2600.0, 5.0), -3.0)
	fm_ = D.amp(fm_, D.env([[0.0, 0.0, 0.0], [4.0, 1.0, 0.0], [ms * 0.7, 0.7, 0.0], [ms, 0.0, 2.0]], n))
	return D.crush(fm_, 4, 4.0, 1.0) if crushed else fm_


func _c_duck_say(v: int) -> PackedFloat32Array:
	return D.fit(_syllable(700.0 * D.st(P([0.0, 2.0, -2.0], v)), P([70.0, 60.0, 85.0], v), false), N(95.0))


func _c_glitch_say(v: int) -> PackedFloat32Array:
	return D.fit(_syllable(700.0, P([70.0, 60.0, 85.0], v), true), N(95.0))


# ------------------------------------------------------------------ ambience spots (§4.11, 22.05 kHz)

func _c_amb_drip(v: int) -> PackedFloat32Array:
	var o := out(320.0)
	var d := md("glass", P([2000.0, 2300.0, 2600.0, 2900.0], v), 60.0, 100.0, "mallet", 1, 4)
	D.mix(o, d)
	D.mix(o, D.svf(d, "lp", 2500.0, 0.7071), 180.0, -9.0)
	return o


func _c_amb_creak(v: int) -> PackedFloat32Array:
	var n := N(700.0)
	var k := D.ks(P([70.0, 78.0], v), 0.5, 0.1, 0.3, n, R(1))
	k = D.varispeed(k, D.penv(1.0, D.st(P([1.0, -1.0], v)), 600.0, n), n)
	D.fade_in(k, 0.0, 60.0)
	return weight(D.svf(k, "hp", 120.0, 0.7071), 180.0, 4.0, 1.0)


func _c_amb_rustle(v: int) -> PackedFloat32Array:
	var n := N(620.0)
	var sh := D.env([[0.0, 0.2, 0.0], [200.0, 1.0, 0.0], [600.0, 0.0, 0.0]], n)
	return D.grain(n, R(1), P([90.0, 60.0, 120.0], v), 12.0, "noise", 2000.0, 4000.0, sh)


func _c_amb_glitch(v: int) -> PackedFloat32Array:
	var o := out(260.0)
	var r := R(1)
	for k in 3:
		var f := D.penv(r.randf_range(3000.0, 5000.0), r.randf_range(3000.0, 5000.0), 30.0, N(40.0))
		D.mix(o, fmt(f, 1.41, 2.0, 0.5, 30.0, 0.5, 35.0), 60.0 * k + 20.0 * v, -2.0)
	return D.crush(o, 3, 5.0, 0.8)


func _c_amb_steam(v: int) -> PackedFloat32Array:
	var n := N(1200.0)
	var s := D.svf_mod(D.svf(D.noise(n, R(1), "white"), "hp", 2000.0, 0.7071), "bp", D.penv(P([2500.0, 3000.0, 2200.0], v), P([5000.0, 4200.0, 6000.0], v), 900.0, n), 1.2)
	return D.amp(s, D.env([[0.0, 0.0, 0.0], [300.0, 1.0, -2.0], [900.0, 0.6, 0.0], [1200.0, 0.0, 1.0]], n))


func _c_amb_clank(v: int) -> PackedFloat32Array:
	var o := out(700.0)
	D.mix(o, md("plate", P([400.0, 550.0, 700.0], v), 300.0, 450.0, "mallet", 1, 8), 0.0, -6.0)
	return D.room(o, "M", 0.3, 0.5)


## The Page Archive: a page turning in the stacks (a rustle that swells, the sheet's soft flap).
func _c_amb_page(v: int) -> PackedFloat32Array:
	var o := out(720.0)
	var n := N(700.0)
	var sh := D.env([[0.0, 0.1, 0.0], [P([350.0, 250.0, 450.0], v), 1.0, 0.0], [600.0, 0.0, 0.0]], n)
	D.mix(o, D.grain(n, R(1), P([80.0, 110.0, 60.0], v), 10.0, "noise", 1800.0, 4500.0, sh))
	D.mix(o, nzs(2, "pink", 60.0, 2500.0, 800.0, 50.0, 1.0, 2.0), P([380.0, 280.0, 480.0], v), -6.0)
	return o


## The Page Archive: a mantel clock somewhere in the stacks, three beats of its escapement.
func _c_amb_tick(v: int) -> PackedFloat32Array:
	var o := out(900.0)
	for k in 3:
		var f := P([2400.0, 2100.0], v) * (1.0 if k % 2 == 0 else 0.75)
		D.mix(o, md("wood", f, 30.0, 80.0, "impulse", 1 + k, 3), 330.0 * k, -2.0 if k % 2 == 0 else -4.0)
		D.mix(o, md("brass", f * 1.5, 20.0, 60.0, "impulse", 4 + k, 3), 330.0 * k, -10.0)
	return D.room(o, "M", 0.25, 0.5)


## Ring Zero: the Glitch's nest far off, one slow throb with a glass shimmer riding it. A single
## swell, never a heartbeat's double beat, so it cannot be mistaken for the low-HP warning.
func _c_amb_nest(v: int) -> PackedFloat32Array:
	var o := out(950.0)
	var n := N(900.0)
	var e := D.env([[0.0, 0.0, 0.0], [250.0, 1.0, -2.0], [900.0, 0.0, 2.0]], n)
	var body := D.sat(osc("sine", D.penv(P([98.0, 92.5], v), P([82.0, 77.8], v), 900.0, n), e), 3.0)
	D.mix(o, weight(body, 180.0, 4.0, 1.0, -6.0))
	D.mix(o, D.amp(fmt(F(P([1975.5, 1864.7], v), 900.0), 1.41, 1.0, 0.2, 600.0, 200.0, 700.0), e), 0.0, -18.0)
	return D.room(o, "M", 0.3, 0.5)


## Ring Zero: a brass trace arcing over, a crackle and a zap down the circuit.
func _c_amb_spark(v: int) -> PackedFloat32Array:
	var o := out(400.0)
	D.mix(o, crk(1, P([120.0, 90.0, 160.0], v), 900.0, P([3500.0, 4200.0, 3000.0], v)))
	var n := N(150.0)
	D.mix(o, fmt(D.penv(P([4000.0, 3500.0, 4500.0], v), 900.0, 120.0, n), 2.756, 1.5, 0.2, 100.0, 0.5, 140.0), 20.0, -6.0)
	return D.room(o, "S", 0.2, 0.5)


# ------------------------------------------------------------------ World 3: the Kernel (0.20)

## Memory Leak drips a puddle: a drop's rising bubble blip, the plop into the puddle (a soft
## saturated body) and a crushed splash, because the leaked memory is data.
func _c_leak_drip(v: int) -> PackedFloat32Array:
	var o := out(300.0)
	var n := N(60.0)
	var f0 := P([700.0, 620.0, 800.0], v)
	D.mix(o, osc("sine", D.penv(f0, f0 * 2.3, 30.0, n), D.aenv(1.0, 55.0, n)), 0.0, -2.0)
	D.mix(o, drop(P([320.0, 290.0, 350.0], v), 150.0, 60.0, 180.0, 3.0, 1200.0, 1.0, 1.0), 40.0, -4.0)
	D.mix(o, D.crush(nz(1, "pink", 120.0, "bp", 1500.0, 1.5, 2.0), 4, 5.0, 1.0), 45.0, -10.0)
	return o


## Its puddles dry up (the leak is freed): a sizzle that rises and thins, a low sigh, then the
## freed memory chimes up the major arpeggio (A C# E A').
func _c_leak_dry(v: int) -> PackedFloat32Array:
	var o := out(900.0)
	var n := N(600.0)
	var sz := D.svf_mod(D.noise(n, R(1), "white"), "bp", D.penv(1500.0, P([6000.0, 5000.0], v), 550.0, n), 1.5)
	D.mix(o, D.amp(sz, D.env([[0.0, 0.0, 0.0], [40.0, 1.0, 0.0], [600.0, 0.0, 2.0]], n)), 0.0, -4.0)
	D.mix(o, drop(260.0, 140.0, 200.0, 300.0, 3.0, 900.0, 1.0, 5.0), 0.0, -6.0)
	var ps := [A6, CS7, E7, A7]
	for i in 4:
		D.mix(o, md("glass", float(ps[i]), 300.0, 400.0, "mallet", 2 + i, 4), 120.0 + 70.0 * i, -4.0 - i)
	return o


## Null Pointer aims: a thin pulse line drawn up through the threat band (440 -> 1100 Hz) with
## the threat warble's tremolo on it (14 -> 22 Hz), a sigil at the base and a click at the tip.
func _c_null_aim(_v: int) -> PackedFloat32Array:
	var o := out(420.0)
	var n := N(380.0)
	var f := D.penv(A4, 1100.0, 340.0, n)
	var p := D.svf_mod(D.pulse(f, 0.3), "bp", f, 3.0)
	p = D.am_mod(p, D.penv(14.0, 22.0, 380.0, n), 0.4)
	D.mix(o, D.amp(p, D.env([[0.0, 0.0, 0.0], [20.0, 0.6, 0.0], [340.0, 1.0, 0.0], [380.0, 0.0, 1.0]], n)))
	D.mix(o, D.sigil(A6, 14.0, 1.0), 0.0, -6.0)
	D.mix(o, D.sigil(E7, 14.0, 1.0), 330.0, -4.0)
	return o


## It blinks to the line's end (dereferenced): a crushed sigil run falling into a null, a
## reversed zip, a hard pop, and the small ring it snaps in (a pitched plate).
func _c_null_blink(v: int) -> PackedFloat32Array:
	var o := out(320.0)
	D.mix(o, D.crush(sigils([A7, E7, A6, E6], 12.0, 10.0, 0.9), 2, P([6.0, 5.0], v), 0.7), 0.0, -2.0)
	D.mix(o, D.reverse(D.whoosh(N(80.0), R(1), 1200.0, P([5000.0, 4000.0], v), 80.0, 1.5, 0.3)), 0.0, -6.0)
	D.mix(o, drop(P([520.0, 480.0], v), 200.0, 25.0, 70.0, 4.0, 0.0, 0.6, 0.3), 60.0, -2.0)
	D.mix(o, md("plate", P([1320.0, 1245.0], v), 160.0, 220.0, "impulse", 2, 6), 65.0, -8.0)
	return o


## Interrupt suspends one of your spells: a padlock's clunk (a small iron plate with weight,
## then the latch) and the interrupt's glitchy chirp, an FM chirp down, stuttered and crushed.
func _c_interrupt_lock(_v: int) -> PackedFloat32Array:
	var o := out(520.0)
	D.mix(o, weight(md("plate", 330.0, 120.0, 220.0, "mallet", 1, 6), 250.0, 4.0, 1.0))
	D.mix(o, drop(200.0, 110.0, 40.0, 110.0, 4.0, 1000.0, 1.0, 0.5), 0.0, -4.0)
	D.mix(o, nz(2, "white", 4.0, "bp", 3000.0, 2.0, 0.1), 70.0, -4.0)
	var ch := fmt(D.penv(E7, A6, 60.0, N(70.0)), 1.41, 2.0, 0.5, 50.0, 0.5, 65.0)
	D.mix(o, D.crush(D.stutter(ch, 0.0, 18.0, 3), 3, 5.0, 0.8), 130.0, -6.0)
	return o


## The spell comes back: the lock springs (two light plate clicks, the key turning back), then
## the slot's sigil climbs home (A6 E7 A7) with a glass ring.
func _c_interrupt_free(_v: int) -> PackedFloat32Array:
	var o := out(560.0)
	for k in 2:
		D.mix(o, md("plate", A5 * (1.0 + 0.12 * k), 150.0, 180.0, "mallet", 1 + k, 6), 50.0 * k, -4.0)
	D.mix(o, sigils([A6, E7, A7], 45.0, 22.0, 0.9), 110.0)
	D.mix(o, md("glass", A7, 250.0, 350.0, "mallet", 4, 4), 200.0, -6.0)
	return o


## Race Condition: the two threads cross and burst. Two saws race head-on (one climbing, one
## falling) into the same pitch, then collide: a crushed burst over a saturated low body.
func _c_race_cross(v: int) -> PackedFloat32Array:
	var o := out(720.0)
	var n := N(220.0)
	var mid := P([660.0, 620.0], v)
	var e := D.env([[0.0, 0.0, 0.0], [10.0, 0.5, 0.0], [210.0, 1.0, 0.0], [220.0, 0.0, 0.0]], n)
	var up := osc("saw", D.penv(mid * 0.5, mid, 200.0, n), e)
	var dn := osc("saw", D.penv(mid * 2.0, mid * D.st(0.3), 200.0, n), e)
	D.mix(o, D.svf(D.add(up, dn), "lp", 3000.0, 0.7071), 0.0, -8.0)
	D.mix(o, nz(1, "white", 6.0, "bp", 1500.0, 1.0, 0.1), 220.0, -2.0)
	D.mix(o, drop(P([180.0, 170.0], v), 60.0, 200.0, 400.0, 7.0, 1400.0, 1.4), 220.0)
	D.mix(o, D.crush(nz(2, "pink", 300.0, "lp", 3000.0, 0.7071, 1.0), 3, 6.0, 0.8), 220.0, -6.0)
	return D.room(o, "S", 0.10, 0.4)


## The fallen thread respawns (a warning): a fork, one pulse tone splitting in two (660 -> 440
## and 990 Hz) with the threat warble's tremolo, swelling to a restart stamp.
func _c_race_respawn(_v: int) -> PackedFloat32Array:
	var o := out(900.0)
	var n := N(700.0)
	var e := D.env([[0.0, 0.0, 0.0], [20.0, 0.5, 0.0], [680.0, 1.0, -2.0], [700.0, 0.0, 0.0]], n)
	for tgt: float in [440.0, 990.0]:
		var f := D.penv(660.0, tgt, 250.0, n)
		var p := D.svf_mod(D.pulse(f, 0.3), "bp", f, 3.0)
		D.mix(o, D.amp(D.am_mod(p, D.penv(14.0, 22.0, 700.0, n), 0.4), e), 0.0, -3.0)
	D.mix(o, D.reverse(D.whoosh(N(200.0), R(1), 800.0, 4000.0, 200.0, 1.2)), 0.0, -8.0)
	D.mix(o, md("stone", 240.0, 60.0, 90.0, "mallet", 2, 5), 700.0, -3.0)
	D.mix(o, sigils([A6, A6], 70.0, 20.0, 1.0), 700.0, -6.0)
	return o


## The Glitch's red "-" rows telegraph: a flat, buzzy minor second (pulses at 392 and 415 Hz,
## band-passed in the threat band) whose tremolo speeds up 10 -> 22 Hz as it swells, and a
## diff-line tick per row.
func _c_diff_warn(_v: int) -> PackedFloat32Array:
	var o := out(760.0)
	var n := N(700.0)
	var s := D.add(D.pulse(F(392.0, 700.0), 0.3), D.pulse(F(415.3, 700.0), 0.3, PackedFloat32Array(), 0.4))
	s = D.am_mod(D.svf(s, "bp", 600.0, 1.2), D.penv(10.0, 22.0, 700.0, n), 0.45)
	D.mix(o, D.amp(s, D.env([[0.0, 0.0, 0.0], [15.0, 0.25, 0.0], [690.0, 1.0, -2.0], [700.0, 0.0, 0.0]], n)))
	for k in 4:
		D.mix(o, D.sigil(E6, 12.0, 0.8), 120.0 * k, -8.0)
	return o


## The rows burn: a flash of fire (a band-pass roar opening), a crushed "delete" cut, a low
## saturated thud and the crackle of the lines charring.
func _c_diff_burn(v: int) -> PackedFloat32Array:
	var o := out(700.0)
	var n := N(450.0)
	var b := D.svf_mod(D.noise(n, R(1), "pink"), "bp", D.penv(700.0, P([2800.0, 2400.0], v), 200.0, n), 1.2)
	D.mix(o, D.amp(b, D.env([[0.0, 0.0, 0.0], [8.0, 1.0, 0.0], [250.0, 0.7, 0.0], [450.0, 0.0, 2.0]], n)), 0.0, 2.0)
	D.mix(o, D.crush(nz(2, "white", 40.0, "hp", 1500.0, 0.7071, 0.1), 2, 4.0, 1.0), 0.0, -8.0)
	D.mix(o, drop(P([150.0, 140.0], v), 70.0, 120.0, 300.0, 6.0, 1200.0, 1.2), 0.0, -6.0)
	D.mix(o, crk(3, 400.0, 250.0, 3000.0), 60.0, -4.0)
	return o


## A revert glyph appears: a brass bar swelling in backwards (the tape runs the wrong way),
## landing on the bar with its fifth in glass. An opening, so it rings in the brass band.
func _c_revert_spawn(_v: int) -> PackedFloat32Array:
	var o := out(1000.0)
	var g := [0.4, 1.0, 0.4, 0.1]
	D.mix(o, D.reverse(md("brass", A5, 500.0, 300.0, "mallet", 1, 4, g)), 0.0, -6.0)
	D.mix(o, md("brass", A5, 700.0, 600.0, "mallet", 2, 4, g), 300.0)
	D.mix(o, md("glass", E7, 400.0, 500.0, "mallet", 3, 4), 380.0, -4.0)
	D.mix(o, D.grain(N(400.0), R(4), 25.0, 50.0, "glass", 3000.0, 6000.0, thin(400.0)), 320.0, -12.0)
	return o


## You take a revert: a tape rewind (sigils and a bell played backwards and bent up an octave),
## the undo's whoosh, then the old code lands: a brass bar and its fifth over a warm thump.
func _c_revert_take(_v: int) -> PackedFloat32Array:
	var o := out(1300.0)
	var src := out(500.0)
	D.mix(src, sigils([A6, E7, C7, A6, E6, A5], 50.0, 30.0, 0.8))
	D.mix(src, md("bell", A5, 500.0, 480.0, "mallet", 1, 8), 0.0, -4.0)
	var n := N(450.0)
	D.mix(o, D.varispeed(D.reverse(src), D.penv(0.8, D.st(12.0), 450.0, n), n), 0.0, -2.0)
	D.mix(o, D.whoosh(N(500.0), R(2), 400.0, 5000.0, 480.0, 1.2, 0.85, 3000.0), 0.0, -4.0)
	var g := [0.4, 1.0, 0.4, 0.1]
	D.mix(o, md("brass", A5, 900.0, 800.0, "mallet", 3, 4, g), 470.0)
	D.mix(o, md("brass", E6, 900.0, 700.0, "mallet", 4, 4, g), 470.0, -4.0)
	D.mix(o, drop(220.0, 110.0, 80.0, 300.0, 4.0, 1000.0, 1.2, 1.0), 470.0, -2.0)
	return o


## The Glitch's stack unwinds: frames pop down the call stack (a falling run of sigils, each
## with its own digital ring), and old bosses echo back small: the Loop's growl, Deadlock's
## clanking lock, a falling weight; all through a receding echo that crushes as it goes.
func _c_glitch_unwind(_v: int) -> PackedFloat32Array:
	var o := out(1400.0)
	var ps := [A7, E7, C7, A6, E6, 1046.5, A5]
	for i in ps.size():
		var pop := D.fit(D.sigil(float(ps[i]), 20.0, 1.0), N(80.0))
		D.mix(o, D.comb(pop, 2000.0 / float(ps[i]), 0.6, 0.6), 90.0 * i, -1.0 - 0.3 * i)
	var n := N(350.0)
	var growl := D.sat(D.add(D.saw(F(220.0, 350.0)), D.saw(F(223.0, 350.0), 0.4)), 5.0)
	growl = D.amp(D.svf_mod(growl, "lp", D.penv(3000.0, 900.0, 300.0, n), 3.0), D.aenv(15.0, 330.0, n))
	D.mix(o, D.comb(growl, 1.13, 0.5, 0.5), 150.0, -8.0)
	for k in 2:
		D.mix(o, weight(md("plate", 330.0 * (1.0 + 0.06 * k), 200.0, 260.0, "mallet", 2 + k, 8), 250.0, 4.0, 1.0), 450.0 + 90.0 * k, -5.0)
	D.mix(o, drop(160.0, 55.0, 500.0, 700.0, 6.0, 1200.0, 1.4), 600.0, -4.0)
	var bits := D.env([[0.0, 12.0, 0.0], [700.0, 12.0, 0.0], [1400.0, 5.0, 0.0]], o.size())
	return D.crush(D.delay(o, 180.0, 0.35, 2500.0, 0.3), 1, 12.0, 0.5, bits)


## A caged resident is freed and compiles back in, row by row: twelve soft sigil rows drawing
## (climbing the A major pentatonic), then a warm boot chime: an A major bell chord over a
## brass bar and a low swell, with a breath of glass.
func _c_resident_free(_v: int) -> PackedFloat32Array:
	var o := out(1700.0)
	var ps := [A5, 987.77, CS6, E6, 1479.98, A6, 1975.53, CS7, E7, 2959.96, A7, A7]
	for i in ps.size():
		D.mix(o, D.sigil(float(ps[i]), 14.0, 0.5), 50.0 * i, -8.0 + 0.3 * i)
	var ch := [A5, CS6, E6, A6]
	for i in ch.size():
		D.mix(o, fmt(F(float(ch[i]), 900.0), 3.5, 2.0, 0.3, 250.0, 2.0, 880.0), 620.0 + 25.0 * i, -3.0)
	var g := [0.4, 1.0, 0.4, 0.1]
	D.mix(o, md("brass", A5, 900.0, 1000.0, "mallet", 1, 4, g), 620.0, -4.0)
	D.mix(o, osc("sine", F(A4, 900.0), D.env([[0.0, 0.0, 0.0], [200.0, 1.0, 0.0], [900.0, 0.0, 2.0]], N(900.0))), 600.0, -10.0)
	D.mix(o, D.grain(N(700.0), R(2), 25.0, 60.0, "glass", 4000.0, 7000.0, thin(700.0)), 700.0, -12.0)
	return o


## A Lost Page picked up: the paper lifts (a rustle swelling in, the flap of the sheet), then a
## soft chime, the motif's head (A E) in glass.
func _c_page_take(_v: int) -> PackedFloat32Array:
	var o := out(900.0)
	var n := N(260.0)
	var sh := D.env([[0.0, 0.1, 0.0], [180.0, 1.0, 0.0], [260.0, 0.0, 0.0]], n)
	D.mix(o, D.grain(n, R(1), 120.0, 8.0, "noise", 2000.0, 6000.0, sh), 0.0, 2.0)
	D.mix(o, nzs(2, "pink", 70.0, 3000.0, 900.0, 60.0, 1.2, 2.0), 230.0, -2.0)
	D.mix(o, md("glass", A6, 400.0, 550.0, "mallet", 3, 4), 280.0, -4.0)
	D.mix(o, md("glass", E7, 400.0, 500.0, "mallet", 4, 4), 360.0, -6.0)
	return o


## A wand skin applied: a brush of lacquer over the wand (a bright swipe with glints) and the
## gem set into it (a glass clink, then the octave).
func _c_skin_equip(v: int) -> PackedFloat32Array:
	var o := out(520.0)
	D.mix(o, D.whoosh(N(220.0), R(1), 2000.0, P([7000.0, 6000.0], v), 220.0, 1.5, 0.7), 0.0, -4.0)
	D.mix(o, D.grain(N(220.0), R(2), 60.0, 6.0, "glass", 4000.0, 8000.0, thin(220.0)), 20.0, -10.0)
	D.mix(o, md("glass", P([E7, D7], v), 200.0, 260.0, "mallet", 3, 4), 200.0, -2.0)
	D.mix(o, md("glass", A7, 250.0, 300.0, "mallet", 4, 4), 270.0, -4.0)
	return o


## Grep's search finds a hint: his lantern flares (a soft breathy swell), then two glass notes,
## the motif's head (A E), over the low knock of his pole.
func _c_hint(_v: int) -> PackedFloat32Array:
	var o := out(900.0)
	var n := N(300.0)
	D.mix(o, D.amp(D.svf(D.noise(n, R(1), "pink"), "bp", 1800.0, 1.0), D.env([[0.0, 0.0, 0.0], [220.0, 1.0, -2.0], [300.0, 0.0, 1.0]], n)), 0.0, -8.0)
	D.mix(o, md("glass", A6, 350.0, 500.0, "mallet", 2, 4), 250.0, -2.0)
	D.mix(o, md("glass", E7, 450.0, 600.0, "mallet", 3, 4), 350.0, -3.0)
	D.mix(o, weight(md("wood", 240.0, 80.0, 120.0, "mallet", 4, 3), 250.0, 4.0, 1.0), 250.0, -8.0)
	return o
