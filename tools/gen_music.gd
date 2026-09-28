extends SceneTree
## Sound v2 (research/sound-v2.md §5): renders the stingers to game/assets/audio/ (sting_*.wav)
## and the music and ambience beds as WAV masters to build/music_wav/ (music_*.wav, outside git).
## tools/encode_music.py turns the masters into the Ogg Vorbis files the game ships
## (game/assets/audio/music_*.ogg, ADR 0034).
## Run: tools/audio.sh   (godot --headless --path game -s <abs path to this file>)
##
## Every note is generated here from the shared toolkit (tools/lib_dsp.gd, §3), so the music
## is original and deterministic (ADR 0019, ADR 0002): the same code writes the same bytes.
## The whole score is built on one leitmotif, "The Incantation" (§2.4): 1-5-b3-4-5 | b7-1'.
##
## Cues (§5.3-§5.10):
##   title    96 bpm  D minor     24 bars, one loop: the full motif on an FM bell over harp
##   shop     96 bpm  D dorian    16 bars, one loop: the motif on a music box, swung
##   cellar  120 bpm  A minor     base 32 bars, drums 8 (+ motor bass), lead 16
##   grove   120 bpm  C# phrygian the same stems, half-time, crushed; the corrupted motif
##   foundry 125 bpm  F minor     the same stems; the motif as an anvil ostinato
##   kernel  100 bpm  B minor     the same stems; the motif "paged" on a celesta over a clock
##   mini    128 bpm  E minor     loop = 2 intro bars + 16, p2 = 2 silent bars + 8
##   boss    150 bpm  C minor     loop = 4 intro bars + 32, p2 = 4 silent + 16, p3 = 4 silent + 8
##   stings  clear / reward (+ _grove, _foundry, _kernel), boss, boss_down, victory, defeat,
##           world (+ _kernel), glitch (the Glitch's entrance)
##   beds    amb_cellar, amb_grove, amb_foundry, amb_kernel, amb_ring: stereo 22.05 kHz, 20 s
##
## Rules this file keeps:
## - 32 kHz mono stems. Every tempo gives a whole-sample bar (7,680,000 / bpm) and a
##   whole-sample 16th, so every stem's loop is a whole number of bars and the layers stay
##   locked (the Foundry moved from 112 to 125 bpm for this).
## - Loops are rendered as loops: note tails wrap to the start, and everything with memory
##   (chorus, reverb, delay, filters) runs over the loop twice and keeps the second pass, so
##   its state is continuous across the seam (§3.10, §3.12).
## - A folded intro (boss, mini) is rendered from silence up to loop_begin, then the loop
##   follows; the last 20 ms of the intro ramp into the loop's first sample so the first
##   pass is click-free too.
## - The loop point. Godot 4.7.2 plays a forward loop as the samples (loop_begin, loop_end],
##   inclusive of the sample AT loop_end and never replaying the one at loop_begin (measured
##   with AudioStreamPlayback.mix_audio). So each loop master ends in one guard sample equal to
##   the sample at loop_begin and loop_end = frames - 1: the heard period is exactly
##   loop_end - loop_begin = whole bars. The shipped Ogg (ADR 0034) is frames [0, loop_end)
##   with loop_offset = loop_begin / rate (6.4 s for the boss, 3.75 s for the mini boss):
##   tools/encode_music.py drops the guard, and tools/audio.sh writes the loop into the import.
## - Each note is rendered once per cue and mixed in as a copy (the note cache, §3.12).
## - Loudness (§5.1): the full mix of a cue (all layers on) is -20 LUFS-I, the base alone
##   -24.5 (the mini boss -23.6, still inside the ±1 LU tolerance, because it has one layer to
##   add); each layer's gain is solved from the BS.1770 meter so the documented deltas hold.
##   Stingers -19 LUFS-I, beds -30. True peak (4x oversampled) at most -1 dBTP on every file
##   and on every cue's full mix.

const D := preload("lib_dsp.gd")

const SR := 32000
const AMB_SR := 22050
const OUT := "res://assets/audio/"
## The music and bed masters: WAV, outside the game (tools/encode_music.py ships them as Ogg).
var masters := ProjectSettings.globalize_path("res://").path_join("../build/music_wav/").simplify_path() + "/"
const MUSIC_LUFS := -20.0
const STING_LUFS := -19.0
const AMB_LUFS := -30.0
const BASE_LUFS := -24.5
## True-peak ceiling (dBTP), with margin for the 16-bit rounding and meter differences.
const TP_MAX := -1.2
## The pre-roll that makes a loop's effects continuous across its seam (_loopfx).
const PREROLL_MS := 4000.0
## Retired by the v2 spec (§5.2, §9): the boss intro is folded into music_boss_loop.
const RETIRED := ["music_boss_intro"]

## Scales, as semitones over the tonic.
const MINOR := [0, 2, 3, 5, 7, 8, 10]
const HARMONIC := [0, 2, 3, 5, 7, 8, 11]
## The Incantation (§2.4): scale degrees (0-based: 1 5 b3 4 5 b7 1') and rhythm in 16ths
## (four eighths and a half note, then two quarters).
const MOTIF := [0, 4, 2, 3, 4, 6, 7]
const MOTIF_RHYTHM := [[0, 2], [2, 2], [4, 2], [6, 2], [8, 8], [16, 4], [20, 4]]
## Instruments whose output is low-passed at or under 2.4 kHz: their notes are rendered at
## half the sample rate (16 kHz) and interpolated up, which halves the costliest renders.
const HALF_RATE := ["pad_warm", "pad_dark", "pad_tri", "choir_pad"]
## Drum pattern characters: accent, normal, open (hats), ghost.
const VEL := {"X": 0.0, "x": -4.0, "o": -4.0, "g": -10.0}

var _cue := ""
var _st := 4000
var _cache := {}
var _hum := RandomNumberGenerator.new()
var _tp_taps: Array = []
var _tp_l1 := 1.0
## The smallest sum of the two central taps (x[c], x[c+1]) over the phases: with the largest
## L1 it bounds every phase, |y| <= L1·M - core·(M - max(|x[c]|, |x[c+1]|)).
var _tp_core := 2.0
var _report: Array = []
var _loops: Array = []
var _lap_t := 0
var _rt := {}


## Prints the time since the last lap (profiling; PROFILE=1).
func _lap(label: String) -> void:
	var now := Time.get_ticks_msec()
	if OS.get_environment("PROFILE") == "1":
		print("LAP|%s|%s|%d ms" % [_cue, label, now - _lap_t])
	_lap_t = Time.get_ticks_msec()


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(masters)
	_tp_init()
	_retire()
	# ONLY=cellar (a comma list) renders just those cues, for working on one
	var only := OS.get_environment("ONLY").split(",", false)
	D.set_rate(SR)
	for c in ["title", "shop", "cellar", "grove", "foundry", "kernel", "mini", "boss", "stingers"]:
		if only.is_empty() or c in only:
			_lap_t = Time.get_ticks_msec()
			call("_" + c)
	if only.is_empty() or "ambience" in only:
		D.set_rate(AMB_SR)
		_ambience()
	if OS.get_environment("PROFILE") == "1":
		for k in _rt:
			print("INST|%s|%d ms" % [k, int(_rt[k]) / 1000])
	for line in _report:
		print(line)
	for line in _loops:
		print(line)
	print("gen_music: done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


## Deletes the files the v2 spec retired (and their import sidecars).
func _retire() -> void:
	for name in RETIRED:
		for ext in [".wav", ".wav.import", ".ogg", ".ogg.import"]:
			var p := ProjectSettings.globalize_path(OUT + name + ext)
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
				print("gen_music: retired %s%s" % [name, ext])


# ================================================================== time, notes, parts

## Starts a cue: its tempo sets the 16th in samples; the note cache is per cue.
func _begin(cue: String, bpm: float) -> void:
	_cue = cue
	_st = int(roundf(60.0 / bpm / 4.0 * D.sr))
	assert(absf(_st * bpm * 4.0 / 60.0 - D.sr) < 0.01, "%s: a 16th must be whole samples" % cue)
	_cache.clear()


## A silent part of `bars` bars.
func _bars(bars: int) -> PackedFloat32Array:
	return D.zeros(bars * 16 * _st)


## Seeds the humaniser for one part of the cue (so a new part never shifts another's timing).
func _part(name: String) -> void:
	_hum = D.rng_for(_cue + "/" + name, 0, 0)


## The sample a 16th step falls on: swing delays the off-beat 16ths (grid 16) or eighths
## (grid 8); humanising moves non-downbeat 16ths by up to ±4 ms (§5.1).
func _time(step: int, opts: Dictionary) -> int:
	var t := step * _st
	var sw: float = opts.get("swing", 0.5)
	if sw > 0.5:
		if int(opts.get("grid", 16)) == 16:
			if posmod(step, 2) == 1:
				t += int(roundf((sw - 0.5) * 2.0 * _st))
		elif posmod(step, 4) == 2:
			t += int(roundf((sw - 0.5) * 4.0 * _st))
	if opts.get("human", false) and posmod(step, 4) != 0:
		t += int(roundf(_hum.randf_range(-4.0, 4.0) * D.sr / 1000.0))
	return t


## Adds src into a loop at sample `at`; whatever runs past the end wraps to the start.
func _mix_wrap(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, k: float) -> void:
	var n := dst.size()
	var a := posmod(at, n)
	var m := src.size()
	var i := 0
	while i < m:
		var c := mini(m - i, n - a)
		for j in c:
			dst[a + j] += src[i + j] * k
		i += c
		a = 0


## One note (or drum hit) into a part. opts: db, human, swing, grid, off (steps), tr
## (semitones), gate (fraction of the length the note is held), vars (drum variants), wrap.
func _play(buf: PackedFloat32Array, inst: String, step: int, midi: float, len16: float, opts := {}) -> void:
	var db: float = opts.get("db", 0.0)
	if opts.get("human", false):
		db += _hum.randf_range(-1.5, 1.5)
	var at := _time(step + int(opts.get("off", 0)), opts)
	var gate := maxi(1, int(roundf(len16 * _st * float(opts.get("gate", 0.92)))))
	var v := posmod(step, int(opts.get("vars", 1)))
	var src := _note(inst, midi + float(opts.get("tr", 0)), gate, v)
	if opts.get("wrap", true):
		_mix_wrap(buf, src, at, D.db2lin(db))
	else:
		D.mix_at(buf, src, at, D.db2lin(db))


## A melody or line: [[step, midi, length in 16ths, (dB)], ...].
func _seq(buf: PackedFloat32Array, inst: String, notes: Array, opts := {}) -> void:
	for n: Array in notes:
		var o := opts
		if n.size() > 3:
			o = opts.duplicate()
			o["db"] = float(opts.get("db", 0.0)) + float(n[3])
		_play(buf, inst, int(n[0]), float(n[1]), float(n[2]), o)


## One chord per bar, held.
func _pads(buf: PackedFloat32Array, inst: String, chords: Array, bars: Array, opts := {}) -> void:
	var o := opts.duplicate()
	o["gate"] = opts.get("gate", 0.98)
	for b: int in bars:
		for m: int in chords[b % chords.size()]:
			_play(buf, inst, b * 16, m, 16, o)


## An arpeggio over one bar: `pattern` indexes the chord's tones (past the top, an octave up),
## one note every `every` 16ths. Downbeats get the accent.
func _arp(buf: PackedFloat32Array, inst: String, tones: Array, bar: int, pattern: Array, every: int, opts := {}) -> void:
	var o := opts.duplicate()
	var base_db: float = opts.get("db", 0.0)
	for i in range(0, 16, every):
		var k: int = pattern[(i / every) % pattern.size()]
		var m: int = int(tones[k % tones.size()]) + 12 * (k / tones.size())
		o["db"] = base_db + (0.0 if i % 4 == 0 else -2.5)
		_play(buf, inst, bar * 16 + i, m, every, o)


## A drum pattern for one bar: 16 characters from VEL ("." is a rest). An "o" on a hat opens it.
func _drum(buf: PackedFloat32Array, inst: String, pat: String, bar: int, opts := {}, midi := 60.0) -> void:
	var o := opts.duplicate()
	o["vars"] = 3
	var base_db: float = opts.get("db", 0.0)
	for i in 16:
		var c := pat[i]
		if c == ".":
			continue
		o["db"] = base_db + float(VEL[c])
		var name := "hat_open" if inst == "hat" and c == "o" else inst
		_play(buf, name, bar * 16 + i, midi, 1, o)


## The chord's tones moved by semitones.
static func _up(tones: Array, semis: int) -> Array:
	var out: Array = []
	for m: int in tones:
		out.append(m + semis)
	return out


## A scale degree (0-based, may run past the octave) in a key.
static func _deg(tonic: int, scale: Array, degree: int) -> int:
	var o := floori(float(degree) / scale.size())
	return tonic + 12 * o + int(scale[posmod(degree, scale.size())])


## The motif in a key, from step `at`: [[step, midi, len], ...] (scale-degree mapped, so a
## major scale gives the major form).
static func _motif(tonic: int, scale: Array, at := 0) -> Array:
	var out: Array = []
	for i in MOTIF.size():
		var r: Array = MOTIF_RHYTHM[i]
		out.append([at + int(r[0]), _deg(tonic, scale, int(MOTIF[i])), int(r[1])])
	return out


## Every long note (>= 6 16ths) broken into four 16ths and the rest (a skipping record).
static func _stuttered(notes: Array) -> Array:
	var out: Array = []
	for n: Array in notes:
		if int(n[2]) >= 6:
			for k in 4:
				out.append([int(n[0]) + k, n[1], 1])
			out.append([int(n[0]) + 4, n[1], int(n[2]) - 4])
		else:
			out.append(n)
	return out


## Notes moved by `steps` 16ths and `semis` semitones.
static func _shift(notes: Array, steps: int, semis := 0) -> Array:
	var out: Array = []
	for n: Array in notes:
		var c := n.duplicate()
		c[0] = int(n[0]) + steps
		c[1] = int(n[1]) + semis
		out.append(c)
	return out


# ================================================================== the note cache and instruments

## A rendered note, from the cache when this (instrument, pitch, gate, variant) was heard
## before in this cue. Its random stream is seeded by the key alone, so it never depends on
## what was rendered earlier.
func _note(inst: String, midi: float, gate: int, v: int) -> PackedFloat32Array:
	var key := "%s|%.3f|%d|%d" % [inst, midi, gate, v]
	if not _cache.has(key):
		var t0 := Time.get_ticks_usec()
		var src: PackedFloat32Array
		if inst in HALF_RATE:
			# low-passed at or under 2.4 kHz: rendered at half the rate and interpolated up
			var rate := D.sr
			D.set_rate(rate / 2)
			src = _render(inst, D.hz(midi), gate / 2, D.rng_for(key, v, 0))
			D.set_rate(rate)
			src = _up2(src)
		else:
			src = _render(inst, D.hz(midi), gate, D.rng_for(key, v, 0))
		_rt[inst] = int(_rt.get(inst, 0)) + Time.get_ticks_usec() - t0
		D.declick_in(src)
		_cache[key] = src
	return _cache[key]


## The pads' supersaw (§3.4: five PolyBLEP saws over ±det cents, the centre at full level, the
## sides at 0.6, seeded start phases, scaled to about one saw's RMS) in one pass, with an
## optional wow (rate Hz, ±cents, updated every 32 samples). The same sound as D.supersaw,
## about twice as fast, which matters for notes a bar long.
static func _supersaw(f: float, n: int, r: RandomNumberGenerator, det: float, wow_hz := 0.0, wow_cents := 0.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var k := 1.0 / sqrt(1.0 + 0.36 * 4.0)
	var gs := 0.6 * k
	var base := f / D.sr
	var r0 := base * pow(2.0, -det / 1200.0)
	var r1 := base * pow(2.0, -0.5 * det / 1200.0)
	var r3 := base * pow(2.0, 0.5 * det / 1200.0)
	var r4 := base * pow(2.0, det / 1200.0)
	var p0 := r.randf()
	var p1 := r.randf()
	var p2 := r.randf()
	var p3 := r.randf()
	var p4 := r.randf()
	var m := 1.0
	var d0 := r0
	var d1 := r1
	var d2 := base
	var d3 := r3
	var d4 := r4
	for i in n:
		if wow_hz > 0.0 and i % 32 == 0:
			m = pow(2.0, wow_cents * sin(TAU * wow_hz * i / D.sr) / 1200.0)
			d0 = r0 * m
			d1 = r1 * m
			d2 = base * m
			d3 = r3 * m
			d4 = r4 * m
		var s0 := 2.0 * p0 - 1.0
		if p0 < d0:
			var t := p0 / d0
			s0 -= t + t - t * t - 1.0
		elif p0 > 1.0 - d0:
			var t := (p0 - 1.0) / d0
			s0 -= t * t + t + t + 1.0
		var s1 := 2.0 * p1 - 1.0
		if p1 < d1:
			var t := p1 / d1
			s1 -= t + t - t * t - 1.0
		elif p1 > 1.0 - d1:
			var t := (p1 - 1.0) / d1
			s1 -= t * t + t + t + 1.0
		var s2 := 2.0 * p2 - 1.0
		if p2 < d2:
			var t := p2 / d2
			s2 -= t + t - t * t - 1.0
		elif p2 > 1.0 - d2:
			var t := (p2 - 1.0) / d2
			s2 -= t * t + t + t + 1.0
		var s3 := 2.0 * p3 - 1.0
		if p3 < d3:
			var t := p3 / d3
			s3 -= t + t - t * t - 1.0
		elif p3 > 1.0 - d3:
			var t := (p3 - 1.0) / d3
			s3 -= t * t + t + t + 1.0
		var s4 := 2.0 * p4 - 1.0
		if p4 < d4:
			var t := p4 / d4
			s4 -= t + t - t * t - 1.0
		elif p4 > 1.0 - d4:
			var t := (p4 - 1.0) / d4
			s4 -= t * t + t + t + 1.0
		out[i] = s2 * k + (s0 + s1 + s3 + s4) * gs
		p0 += d0
		p1 += d1
		p2 += d2
		p3 += d3
		p4 += d4
		if p0 >= 1.0:
			p0 -= 1.0
		if p1 >= 1.0:
			p1 -= 1.0
		if p2 >= 1.0:
			p2 -= 1.0
		if p3 >= 1.0:
			p3 -= 1.0
		if p4 >= 1.0:
			p4 -= 1.0
	return out


## x at twice its rate (linear interpolation; x is band-limited far below the new Nyquist).
static func _up2(x: PackedFloat32Array) -> PackedFloat32Array:
	var n := x.size()
	var y := PackedFloat32Array()
	y.resize(2 * n)
	for i in n:
		var a := x[i]
		y[2 * i] = a
		y[2 * i + 1] = 0.5 * (a + (x[i + 1] if i + 1 < n else a))
	return y


static func _add_const(x: PackedFloat32Array, c: float) -> void:
	for i in x.size():
		x[i] += c


## One note of an instrument (§5.1), at unit level. f in Hz, gate in samples.
func _render(inst: String, f: float, gate: int, r: RandomNumberGenerator) -> PackedFloat32Array:
	var gms := D.ms_of(gate)
	match inst:
		"pad_warm":
			# supersaw 5 x ±10 ct -> 24 dB low-pass at 2.1 kHz ± 300 Hz (0.1 Hz), slow ADSR, and
			# the baked chorus (±6 ct, 12 ms, 25%: DEV-A3), which lives on the pad notes
			var n := gate + D.n_of(600.0)
			var x := _supersaw(f, n, r, 10.0)
			var cut := D.lfo(0.1, 300.0, "sine", n, 0.0, r.randf())
			_add_const(cut, 2100.0)
			x = D.svf_mod(D.svf_mod(x, "lp", cut, 0.5412), "lp", cut, 1.3066)
			return D.chorus(D.amp(x, D.adsr(400.0, 400.0, 0.8, 600.0, gms, n)), 12.0, 6.0, 0.4, 0.25)
		"pad_dark":
			# supersaw ±16 ct with a 0.7 Hz wow (±12 ct) -> 24 dB low-pass at 1.1 kHz, chorus
			var n := gate + D.n_of(800.0)
			var x := D.svf2(_supersaw(f, n, r, 16.0, 0.7, 12.0), "lp", 1100.0)
			return D.chorus(D.amp(x, D.adsr(600.0, 400.0, 0.8, 800.0, gms, n)), 12.0, 6.0, 0.4, 0.25)
		"pad_tri":
			# the shop's soft pad: three detuned triangles, darkened, chorus
			var n := gate + D.n_of(500.0)
			var x := D.zeros(n)
			for c in [-5.0, 0.0, 5.0]:
				D.mix_at(x, D.tri(D.const_curve(f * D.st(c / 100.0), n), r.randf()), 0, 0.5)
			x = D.lp1(x, 2400.0)
			return D.chorus(D.amp(x, D.adsr(250.0, 300.0, 0.8, 500.0, gms, n)), 12.0, 6.0, 0.4, 0.25)
		"choir_pad":
			# supersaw through two formant band-passes (700 / 1200 Hz): an "ah" without a voice
			var n := gate + D.n_of(700.0)
			var x := _supersaw(f, n, r, 12.0)
			var y := D.svf(x, "bp", 700.0, 4.0)
			D.mix_at(y, D.svf(x, "bp", 1200.0, 5.0), 0, 0.8)
			D.mix_at(y, D.svf(x, "lp", 500.0, 0.7), 0, 0.3)
			return D.amp(y, D.adsr(500.0, 300.0, 0.85, 700.0, gms, n))
		"harp":
			var n := D.n_of(900.0)
			var y := D.ks(f, 1.3, 0.6, 0.13, n, r)
			D.fade_in(y, 0.0, 150.0)
			return y
		"musicbox":
			var n := D.n_of(900.0)
			var y := D.ks(f, 0.9, 0.9, 0.1, n, r)
			D.mix_at(y, D.modal("glass", 2.0 * f, 0.08, n, "impulse", r, 4), 0, 0.35)
			D.fade_in(y, 0.0, 60.0)
			return y
		"pizz":
			var n := D.n_of(380.0)
			var y := D.ks(f, 0.25, 0.45, 0.2, n, r)
			y = D.phantom(y, 180.0, 4.0, 0.6)
			D.fade_in(y, 0.0, 40.0)
			return y
		"bass_sat":
			# pulse(.3) with its octave at .35 -> low-pass opening 400 -> 1.4k and settling at
			# 1k -> tanh(4) -> phantom, the fundamental shelved -4 dB under 120 Hz: at least 40%
			# of the energy sits above 200 Hz, so a phone hears the line (§5.1)
			var n := gate + D.n_of(60.0)
			var x := D.pulse(D.const_curve(f, n), 0.3, PackedFloat32Array(), r.randf())
			D.mix_at(x, D.pulse(D.const_curve(2.0 * f, n), 0.3, PackedFloat32Array(), r.randf()), 0, 0.35)
			var fc := D.env([[0.0, 400.0, 0.0], [25.0, 1400.0, -1.5], [25.0 + maxf(80.0, gms * 0.9), 1000.0, 3.0]], n)
			x = D.svf_mod(x, "lp", fc, 1.2)
			x = D.sat(D.amp(x, D.adsr(4.0, 150.0, 0.7, 60.0, gms, n)), 4.0)
			if f < 160.0:
				x = D.eq(D.phantom(x, 180.0, 5.0, 1.0), "lowshelf", 120.0, -4.0, 0.7)
			return x
		"fm_bass":
			# FM ratio 1, index 3.5 -> 1.8, with a pulse an octave up: a growl with its own
			# harmonics, saturated, phantom, the fundamental shelved (40% above 200 Hz)
			var n := gate + D.n_of(60.0)
			var x := D.fm(D.const_curve(f, n), 1.0, D.index_env(3.5, 1.8, 200.0, n))
			D.mix_at(x, D.pulse(D.const_curve(2.0 * f, n), 0.3, PackedFloat32Array(), r.randf()), 0, 0.3)
			x = D.sat(D.amp(x, D.adsr(4.0, 200.0, 0.7, 60.0, gms, n)), 4.0)
			return D.eq(D.phantom(x, 180.0, 5.0, 1.0), "lowshelf", 120.0, -4.0, 0.7)
		"wub":
			# the Grove's motor bass: a resonant low-pass closing on every eighth (4 Hz at 120)
			var n := gate + D.n_of(30.0)
			var x := D.saw(D.const_curve(f, n), r.randf())
			D.mix_at(x, D.pulse(D.const_curve(f * 2.0, n), 0.5), 0, 0.35)
			var fc := D.env([[0.0, 1500.0, 0.0], [maxf(gms, 20.0), 280.0, 2.5]], n)
			x = D.svf_mod(x, "lp", fc, 2.2)
			x = D.sat(D.amp(x, D.adsr(3.0, 60.0, 0.8, 30.0, gms, n)), 2.0)
			return D.phantom(x, 180.0, 4.0, 0.7)
		"lead_pwm":
			# pulse, duty .3 ± .1 at 0.3 Hz -> low-pass 900 -> 2.8k per note, vibrato after 180 ms
			var n := gate + D.n_of(90.0)
			var fcv := D.vibrato(D.const_curve(f, n), 5.5, 18.0, 180.0)
			var duty := D.lfo(0.3, 0.1, "sine", n, 0.0, r.randf())
			_add_const(duty, 0.3)
			var x := D.pulse(fcv, 0.3, duty, r.randf())
			var fc := D.env([[0.0, 900.0, 0.0], [40.0, 2800.0, -1.0], [340.0, 1700.0, 3.0]], n)
			x = D.svf_mod(x, "lp", fc, 1.5)
			return D.amp(x, D.adsr(8.0, 200.0, 0.75, 90.0, gms, n))
		"bell_fm":
			# ratio 3.5, index 2.2 -> 0.3: a bright strike with a pure tail
			var dec := clampf(gms * 2.5, 500.0, 1800.0)
			var n := D.n_of(dec + 20.0)
			var x := D.fm(D.const_curve(f, n), 3.5, D.index_env(2.2, 0.3, 300.0, n))
			return D.amp(x, D.aenv(3.0, dec, n))
		"glass", "glass_s", "glass_l":
			var t60: float = {"glass": 0.4, "glass_s": 0.15, "glass_l": 0.9}[inst]
			return D.modal("glass", f, t60, D.n_of(t60 * 1100.0), "mallet", r, 4)
		"glass_fm":
			# the Grove's crushed lead voice: FM on the glass ratio, a short bright strike
			var n := gate + D.n_of(250.0)
			var x := D.fm(D.const_curve(f, n), 1.414, D.index_env(1.6, 0.2, 220.0, n))
			return D.amp(x, D.adsr(3.0, 250.0, 0.5, 200.0, gms, n))
		"brass_bar":
			return D.modal("brass", f, 0.9, D.n_of(1100.0), "mallet", r, 4)
		"brass_saw":
			# two saws ±7 ct -> low-pass opening 600 -> 3k over the 30 ms attack -> tanh(1.5)
			var n := gate + D.n_of(150.0)
			var x := D.saw(D.const_curve(f * D.st(0.07), n), r.randf())
			D.mix_at(x, D.saw(D.const_curve(f / D.st(0.07), n), r.randf()), 0, 1.0)
			D.scale_in(x, 0.6)
			var fc := D.env([[0.0, 600.0, 0.0], [30.0, 3000.0, -1.0], [280.0, 1800.0, 3.0]], n)
			x = D.svf_mod(x, "lp", fc, 0.9)
			return D.sat(D.amp(x, D.adsr(30.0, 200.0, 0.8, 150.0, gms, n)), 1.5)
		"furnace_lead":
			# saw -> wavefolder -> low-pass (4 kHz for its octave-6 register): hot iron
			var n := gate + D.n_of(100.0)
			var x := D.saw(D.vibrato(D.const_curve(f, n), 5.0, 10.0, 200.0), r.randf())
			x = D.svf(D.sat(x, 1.5, "fold"), "lp", 4000.0, 0.9)
			return D.amp(x, D.adsr(5.0, 150.0, 0.7, 100.0, gms, n))
		"celesta":
			# the Kernel's music box: a steel bar over a wooden resonator. FM on the bar's bright
			# partial (ratio 4) whose index dies in 120 ms (the felt hammer), a pure octave above
			# at a whisper, a glass ping for the strike; the tail rings 0.7-1.6 s
			var dec := clampf(gms * 3.0, 700.0, 1600.0)
			var n := D.n_of(dec + 20.0)
			var x := D.fm(D.const_curve(f, n), 4.0, D.index_env(1.4, 0.05, 120.0, n))
			D.mix_at(x, D.sine(D.const_curve(2.0 * f, n), r.randf()), 0, 0.12)
			x = D.amp(x, D.aenv(2.0, dec, n))
			D.mix_at(x, D.modal("glass", 2.0 * f, 0.06, D.n_of(90.0), "impulse", r, 4), 0, 0.2)
			return x
		# ---- drums (f is ignored except by the tuned ones)
		"tick", "tock":
			# the Kernel's clock: a tiny wooden escapement (tick high, tock low) with a brass glint
			var n := D.n_of(80.0)
			var y := D.modal("wood", 2600.0 if inst == "tick" else 1900.0, 0.03, n, "impulse")
			D.mix_at(y, D.modal("brass", 3900.0 if inst == "tick" else 3300.0, 0.02, n, "impulse"), 0, 0.25)
			D.mix_at(y, D.amp(D.svf(D.noise(n, r), "hp", 5000.0, 0.7), D.aenv(0.1, 6.0, n)), 0, 0.4)
			return y
		"kick":
			# a sine drop 170 -> 55 Hz with a short tail, a 320 -> 190 Hz knock and a click,
			# driven hard (asym 5) and through the phantom, the sub shelved down 8 dB: the body
			# reads at 200-400 Hz on a phone, the earbuds still get the drop (§5.1, pillar 3)
			var n := D.n_of(300.0)
			var body := D.amp(D.sine(D.penv(170.0, 55.0, 70.0, n, "drop")), D.aenv(0.5, 120.0, n))
			D.mix_at(body, D.amp(D.sine(D.penv(320.0, 190.0, 40.0, n)), D.aenv(0.5, 55.0, n)), 0, 0.9)
			D.mix_at(body, D.amp(D.svf(D.noise(n, r), "bp", 3500.0, 0.8), D.aenv(0.0, 10.0, n)), 0, 1.0)
			var y := D.phantom(D.dc_block(D.sat(body, 5.0, "asym")), 180.0, 5.0, 1.0)
			return D.hp2(D.eq(y, "lowshelf", 110.0, -8.0, 0.7), 55.0)
		"snare":
			var n := D.n_of(220.0)
			var y := D.amp(D.svf(D.noise(n, r), "bp", 1800.0, 0.8), D.aenv(0.5, 170.0, n))
			D.mix_at(y, D.modal("wood", 240.0, 0.08, n, "impulse"), 0, 0.5)
			return D.sat(y, 1.5)
		"gsnare":
			# the Grove's long gated noise snare
			var n := D.n_of(260.0)
			var y := D.amp(D.svf(D.noise(n, r), "bp", 1500.0, 0.6), D.env([[0.0, 0.0, 0.0], [1.0, 1.0, 0.0], [170.0, 0.75, 1.0], [200.0, 0.0, 0.0]], n))
			D.mix_at(y, D.modal("wood", 200.0, 0.1, n, "impulse"), 0, 0.5)
			return D.sat(y, 1.5)
		"hat", "hat_open":
			var dec := 120.0 if inst == "hat_open" else 30.0
			var n := D.n_of(dec + 10.0)
			var x := D.crush(D.svf(D.noise(n, r), "hp", 6000.0, 0.7), 2, 8.0)
			return D.amp(x, D.aenv(0.3, dec, n))
		"hammer":
			# the Foundry's hat: a tiny iron plate and a crushed tick
			var n := D.n_of(90.0)
			var y := D.modal("plate", 3000.0, 0.05, n, "noise", r, 4, 0.8)
			D.mix_at(y, D.amp(D.crush(D.svf(D.noise(n, r), "hp", 5000.0, 0.7), 2, 8.0), D.aenv(0.2, 20.0, n)), 0, 0.5)
			return y
		"tom":
			var n := D.n_of(450.0)
			var m: Dictionary = D.MATERIALS["plate"]
			var y := D.modal_bank(m["ratios"], m["gains"], f, 0.2, D.excitation("mallet", n, r, 2.0, 900.0), 8)
			y = D.phantom(D.sat(y, 3.0), 180.0, 5.0, 1.0)
			return D.hp2(D.eq(y, "lowshelf", 110.0, -6.0, 0.7), 55.0)
		"anvil":
			return D.modal("plate", f, 0.25, D.n_of(400.0), "noise", r, 8, 1.5)
		"crash":
			var n := D.n_of(1400.0)
			var x := D.svf2(D.noise(n, r), "hp", 3500.0)
			D.scale_in(x, 0.8)
			D.mix_at(x, D.modal("plate", 3100.0, 0.8, n, "noise", r, 8, 3.0), 0, 0.25)
			return D.amp(D.svf(x, "lp", 9000.0, 0.7), D.aenv(1.0, 1300.0, n))
		"glitch":
			var n := D.n_of(50.0)
			var x := D.crush(D.svf(D.noise(n, r), "hp", 1200.0, 0.7), 4 + r.randi_range(0, 9), 4.0)
			return D.amp(x, D.aenv(0.5, 45.0, n))
		"rim":
			return D.modal("wood", 1200.0, 0.05, D.n_of(120.0), "impulse")
		"wood":
			return D.modal("wood", 880.0, 0.07, D.n_of(150.0), "mallet", r, 3)
		"shaker":
			var n := D.n_of(70.0)
			return D.amp(D.svf(D.noise(n, r), "bp", 6000.0, 1.5), D.aenv(4.0, 55.0, n))
		"steam":
			var n := D.n_of(1000.0)
			var x := D.svf(D.svf2(D.noise(n, r), "hp", 2000.0), "lp", 7000.0, 0.7)
			return D.amp(x, D.env([[0.0, 0.0, 0.0], [450.0, 1.0, -2.0], [1000.0, 0.0, 3.0]], n))
	push_error("gen_music: no instrument %s" % inst)
	return D.zeros(1)


# ================================================================== loop processing

## Runs fx over a loop so its state is continuous across the seam (§3.10, §3.12): the loop
## plays after its own last PREROLL_MS (the whole loop when it is shorter, which is the spec's
## 2x render) and the steady-state pass is kept. 4 s is past every memory in the chain (the
## room's tail is about 0.8 s to -60 dB, the paste delay's feedback .45 is -74 dB by then), so
## the state at the start equals the state at the end to below the 16-bit step.
func _loopfx(x: PackedFloat32Array, fx: Callable) -> PackedFloat32Array:
	var n := x.size()
	var w := mini(n, D.n_of(PREROLL_MS))
	var y := x.slice(n - w)
	y.append_array(x)
	return (fx.call(y) as PackedFloat32Array).slice(w)


## x repeated to n samples (native copies).
static func _tile(x: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	while y.size() < n:
		y.append_array(x)
	return y.slice(0, n)


## The baked space of every stem (§3.10, DEV-A3): room.M at 14% wet, damp 0.5, then the
## 45 Hz music high-pass and a 13 kHz ceiling (nothing load-bearing lives above 10 kHz, and
## the crushed hats' images near 16 kHz only make inter-sample peaks).
func _space(x: PackedFloat32Array) -> PackedFloat32Array:
	return _hp_lp(_room_half(x, 0.14))


## room.M run at half the sample rate (its tail is damped far below 8 kHz): decimate by
## averaging pairs, run the room, interpolate its wet part back up and add it at `wet`. Half
## the cost of the costliest loop in the generator. The damping is per sample, so at half
## the rate it is 0.25, which keeps the full-rate damp 0.5's corner (about 3.5 kHz).
func _room_half(x: PackedFloat32Array, wet: float) -> PackedFloat32Array:
	var n := x.size()
	var h := (n + 1) / 2
	var d := PackedFloat32Array()
	d.resize(h)
	for i in h:
		var a := x[2 * i]
		d[i] = 0.5 * (a + (x[2 * i + 1] if 2 * i + 1 < n else a))
	var rate := D.sr
	D.set_rate(rate / 2)
	var w := D.room(d, "M", 1.0, 0.25)
	D.set_rate(rate)
	for k in h:
		w[k] -= d[k]
	var y := x.duplicate()
	for i in n:
		var p := maxf(0.0, (i - 0.5) * 0.5)
		var j := int(p)
		var fr := p - j
		var a := w[j]
		var b := w[j + 1] if j + 1 < h else a
		y[i] += (a + (b - a) * fr) * wet
	return y


## The music output filter in one pass: a 2nd-order Butterworth high-pass at 45 Hz (§3.5)
## and a 2nd-order Butterworth low-pass at 13 kHz.
func _hp_lp(x: PackedFloat32Array) -> PackedFloat32Array:
	var c := D.rbj("hp", 45.0, 0.0, 0.7071)
	var e := D.rbj("lp", 13000.0, 0.0, 0.7071)
	var c0 := c[0]
	var c1 := c[1]
	var c2 := c[2]
	var c3 := c[3]
	var c4 := c[4]
	var e0 := e[0]
	var e1 := e[1]
	var e2 := e[2]
	var e3 := e[3]
	var e4 := e[4]
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var m1 := 0.0
	var m2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var xi := x[i]
		var m := c0 * xi + c1 * x1 + c2 * x2 - c3 * m1 - c4 * m2
		x2 = x1
		x1 = xi
		var yi := e0 * m + e1 * m1 + e2 * m2 - e3 * y1 - e4 * y2
		m2 = m1
		m1 = m
		y2 = y1
		y1 = yi
		y[i] = yi
	return y


## A soft ceiling for transients (memoryless, so loop-safe): each sample passes through a tanh
## knee `over_db` above the RMS of the stem's sounding part. It trims the crest factor of
## plucked and struck stems so the cue reaches its loudness under the true-peak ceiling.
func _glue(x: PackedFloat32Array, over_db: float) -> PackedFloat32Array:
	var s := 0.0
	var c := 0
	for v in x:
		if absf(v) > 1e-4:
			s += v * v
			c += 1
	var t := sqrt(s / maxf(1.0, c)) * D.db2lin(over_db)
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		y[i] = t * tanh(x[i] / t)
	return y


## Saves a part on its own for measurement when DIAG names a directory (normalised, 16-bit).
func _diag(name: String, x: PackedFloat32Array) -> void:
	var dir := OS.get_environment("DIAG")
	if dir != "":
		var p := D.peak(x)
		D.save_wav(x, dir.path_join(_cue + "_" + name + ".wav"), 0.9 / maxf(p, 1e-9), D.sr)


## The lead stems' dip (§5.1): -4 dB at 800 Hz, Q 1, so the telegraph band stays clear.
func _dip(x: PackedFloat32Array) -> PackedFloat32Array:
	return D.eq(x, "peak", 800.0, -4.0, 1.0)


## Wow (a warped record) on a loop: x through a 15 ms delay swinging ±cents of pitch, fully
## wet, at a rate near `rate_hz` with whole cycles per loop.
func _wow_loop(x: PackedFloat32Array, cents: float, rate_hz: float) -> PackedFloat32Array:
	var secs := float(x.size()) / D.sr
	var rate := maxf(1.0, roundf(rate_hz * secs)) / secs
	var fx := func(y: PackedFloat32Array) -> PackedFloat32Array:
		var out := D.zeros(y.size())
		var base := 0.015 * D.sr
		var amp_s := (pow(2.0, cents / 1200.0) - 1.0) / (TAU * rate) * D.sr
		for i in y.size():
			var p := i - (base + amp_s * sin(TAU * rate * i / D.sr))
			var j := int(floor(p))
			var fr := p - j
			var a := y[j] if j >= 0 else 0.0
			var b := y[j + 1] if j + 1 >= 0 and j + 1 < y.size() else 0.0
			out[i] = a + (b - a) * fr
		return out
	return _loopfx(x, fx)


## A stem: a loop's parts summed, then its space. Parts are [buffer, fx Callable or null].
func _stem(parts: Array) -> PackedFloat32Array:
	_lap("parts")
	var n: int = (parts[0][0] as PackedFloat32Array).size()
	var dry := D.zeros(n)
	for p: Array in parts:
		var b: PackedFloat32Array = p[0]
		if p.size() > 1 and p[1] is Callable:
			b = _loopfx(b, p[1])
		D.mix_at(dry, b, 0, 1.0)
	var out := _loopfx(dry, _space)
	_lap("stem fx")
	return out


## A file with a folded intro: the intro (rendered from silence into a buffer that runs on
## into the loop, so its tails and reverb are real) up to lb, then the processed loop. The
## last 20 ms of the intro take on the step between the intro's own continuation and the
## loop's first sample, so the first pass joins without a click.
func _fold(intro_dry: PackedFloat32Array, loop: PackedFloat32Array, lb: int) -> PackedFloat32Array:
	var tail := mini(loop.size(), D.n_of(PREROLL_MS))
	var xi_in := intro_dry.slice(0, mini(intro_dry.size(), lb + tail))
	xi_in.resize(lb + tail)
	var xi := _space(xi_in)
	var y := xi.slice(0, lb)
	var delta := loop[0] - xi[lb]
	var f := D.n_of(20.0)
	for k in range(1, f + 1):
		var w := 1.0 - float(k - 1) / f
		y[lb - k] += delta * w * w
	y.append_array(loop)
	return y


# ================================================================== loudness and true peak

## The 4x true-peak interpolator (BS.1770-4 Annex 2 style, a little longer): three fractional
## phases of a 64-tap Hann-windowed sinc, 16 taps each (the fourth phase is the sample itself).
func _tp_init() -> void:
	for p in [1, 2, 3]:
		var taps := PackedFloat32Array()
		for j in range(-7, 9):
			var u := float(p) / 4.0 - j
			var s := 1.0 if absf(u) < 1e-9 else sin(PI * u) / (PI * u)
			taps.append(s * (0.5 + 0.5 * cos(PI * u / 8.5)))
		_tp_taps.append(taps)
		var l1 := 0.0
		for t in taps:
			l1 += absf(t)
		_tp_l1 = maxf(_tp_l1, l1)
		_tp_core = minf(_tp_core, absf(taps[7]) + absf(taps[8]))


## True peak (linear), 4x oversampled. An interpolated point is at most L1 (the largest sum
## of |taps|) times the largest of its 16 neighbours, so only points next to a sample above
## peak / L1 can beat the sample peak: those are the only ones evaluated. With a gain k, a
## buffer whose bound (peak · L1 · k) already sits under the ceiling returns the bound: it
## cannot reach the ceiling, so the exact figure is left to the audit.
func _true_peak(x: PackedFloat32Array, k := 0.0) -> float:
	var n := x.size()
	var pk := 0.0
	for v in x:
		pk = maxf(pk, absf(v))
	if k > 0.0 and pk * _tp_l1 * k <= D.db2lin(TP_MAX):
		return pk * _tp_l1
	var thr := pk / _tp_l1
	var seen := PackedByteArray()
	seen.resize(n)
	var best := pk
	# the largest |sample| in each 16-sample block bounds a point's outer taps
	var bm := PackedFloat32Array()
	bm.resize(n / 16 + 1)
	for i in n:
		bm[i / 16] = maxf(bm[i / 16], absf(x[i]))
	var rest := _tp_l1 - _tp_core
	for i in n:
		if absf(x[i]) < thr:
			continue
		for c in range(maxi(7, i - 8), mini(n - 9, i + 7) + 1):
			if seen[c] == 1:
				continue
			seen[c] = 1
			var b := c / 16
			var m := maxf(bm[maxi(0, b - 1)], maxf(bm[b], bm[mini(bm.size() - 1, b + 1)]))
			if _tp_core * maxf(absf(x[c]), absf(x[c + 1])) + rest * m <= best:
				continue
			for taps: PackedFloat32Array in _tp_taps:
				var acc := 0.0
				for j in 16:
					acc += x[c - 7 + j] * taps[j]
				best = maxf(best, absf(acc))
	return best


## The K-weighting of Loudness (its two stages and coefficients) in one pass.
func _kw(x: PackedFloat32Array) -> PackedFloat32Array:
	var a: Array[float] = Loudness._shelf(D.sr)
	var b: Array[float] = Loudness._highpass(D.sr)
	var a0 := a[0]
	var a1 := a[1]
	var a2 := a[2]
	var a3 := a[3]
	var a4 := a[4]
	var b0 := b[0]
	var b1 := b[1]
	var b2 := b[2]
	var b3 := b[3]
	var b4 := b[4]
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var m1 := 0.0
	var m2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var xi := x[i]
		var m := a0 * xi + a1 * x1 + a2 * x2 - a3 * m1 - a4 * m2
		x2 = x1
		x1 = xi
		var yi := b0 * m + b1 * m1 + b2 * m2 - b3 * y1 - b4 * y2
		m2 = m1
		m1 = m
		y2 = y1
		y1 = yi
		y[i] = yi
	return y


## Per-hop K-weighted energies of the stems and, when `cross`, their cross terms: the
## loudness of any gain mix then comes out without re-filtering (K-weighting is linear).
func _hops(ks: Array, cross: bool) -> Dictionary:
	var hop := int(0.4 * D.sr) / 4
	var n: int = (ks[0] as PackedFloat32Array).size()
	var nh := n / hop
	var pairs: Array = []
	for i in ks.size():
		for j in range(i, ks.size()):
			if i != j and not cross:
				continue
			var a: PackedFloat32Array = ks[i]
			var b: PackedFloat32Array = ks[j]
			var e := PackedFloat64Array()
			e.resize(nh)
			for h in nh:
				var s := 0.0
				for t in range(h * hop, h * hop + hop):
					s += a[t] * b[t]
				e[h] = s
			pairs.append([i, j, e])
	return {"pairs": pairs, "nh": nh, "block": hop * 4}


## Integrated loudness (BS.1770-4, the same gates as Loudness.lufs) of Σ g_i · stem_i.
func _lufs_of(h: Dictionary, g: Array) -> float:
	var nh: int = h["nh"]
	var e := PackedFloat64Array()
	e.resize(nh)
	for p: Array in h["pairs"]:
		var w := float(g[p[0]]) * float(g[p[1]]) * (1.0 if p[0] == p[1] else 2.0)
		if w == 0.0:
			continue
		var arr: PackedFloat64Array = p[2]
		for k in nh:
			e[k] += w * arr[k]
	var z: Array[float] = []
	var block := float(h["block"])
	for b in range(0, nh - 3):
		z.append((e[b] + e[b + 1] + e[b + 2] + e[b + 3]) / block)
	var kept: Array[float] = []
	for v in z:
		if _l(v) > -70.0:
			kept.append(v)
	if kept.is_empty():
		return -INF
	var rel := _l(_avg(kept)) - 10.0
	var fin: Array[float] = []
	for v in kept:
		if _l(v) > rel:
			fin.append(v)
	return _l(_avg(fin))


static func _l(ms: float) -> float:
	return -0.691 + 10.0 * log(maxf(ms, 1e-12)) / log(10.0)


static func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


## The gain of layer k that makes it add `delta` LU over the layers below it.
func _solve_layer(h: Dictionary, g: Array, k: int, delta: float) -> float:
	var g0 := g.duplicate()
	g0[k] = 0.0
	var below := _lufs_of(h, g0)
	var lo := -4.0
	var hi := 2.0
	for it in 50:
		var mid := 0.5 * (lo + hi)
		g0[k] = pow(10.0, mid)
		if _lufs_of(h, g0) - below < delta:
			lo = mid
		else:
			hi = mid
	return pow(10.0, 0.5 * (lo + hi))


## Masters and saves a cue. layers: [{file, data (intro + loop, no guard), lb}], base first.
## The base alone sits at `base_lufs`; each further layer adds deltas[k - 1] LU; the full
## mix therefore lands on base_lufs + Σ deltas. Every file and the full mix stay under the
## true-peak ceiling (if the ceiling bites, the whole cue comes down together and says so).
func _master(layers: Array, base_lufs: float, deltas: Array) -> void:
	var loops: Array = []
	for l: Dictionary in layers:
		var d: PackedFloat32Array = l["data"]
		loops.append(d.slice(int(l["lb"])))
	var lb_len: int = (loops[0] as PackedFloat32Array).size()
	var ks: Array = []
	var tiled: Array = []
	for lp: PackedFloat32Array in loops:
		tiled.append(_tile(lp, lb_len))
		ks.append(_tile(_loopfx(lp, _kw), lb_len))
	_lap("master kweight")
	var h := _hops(ks, true)
	_lap("master hops")
	var g: Array = []
	for i in layers.size():
		g.append(1.0 if i == 0 else 0.0)
	for k in range(1, layers.size()):
		g[k] = _solve_layer(h, g, k, float(deltas[k - 1]))
	var target := base_lufs
	for dl: float in deltas:
		target += dl
	var full := _lufs_of(h, g)
	var gain := pow(10.0, (target - full) / 20.0)
	# the true-peak ceiling: each file and the full mix of the loop
	var mix := D.zeros(lb_len)
	for i in layers.size():
		D.mix_at(mix, tiled[i], 0, float(g[i]))
	var tp := _true_peak(mix, gain)
	var tps: Array = []
	for i in layers.size():
		tps.append(_true_peak(layers[i]["data"], gain * float(g[i])) * float(g[i]))
		tp = maxf(tp, float(tps[i]))
	_lap("master tp")
	var cap := D.db2lin(TP_MAX) / maxf(tp * gain, 1e-9)
	var capped := cap < 1.0
	if capped:
		gain *= cap
	var cum := g.duplicate()
	for i in cum.size():
		cum[i] = 0.0
	for i in layers.size():
		var l: Dictionary = layers[i]
		var d: PackedFloat32Array = l["data"]
		var lb: int = l["lb"]
		var k := gain * float(g[i])
		_save_loop(l["file"], d, lb, k)
		cum[i] = float(g[i])
		var alone := g.duplicate()
		for j in alone.size():
			alone[j] = float(g[j]) if j == i else 0.0
		var period := d.size() - lb
		_report.append("REPORT|%s|frames=%d|lb=%d|period=%d|alone=%.2f|cumulative=%.2f|tp=%.2f%s" % [
			l["file"], d.size() + 1, lb, period, _lufs_of(h, alone) + 20.0 * log(gain) / log(10.0),
			_lufs_of(h, cum) + 20.0 * log(gain) / log(10.0), D.lin2db(float(tps[i]) * gain), "|CAPPED" if capped else ""])
		_loops.append("LOOP|%s|loop_begin=%d|loop_end=%d" % [l["file"], lb, d.size()])
	_lap("master save")
	_report.append("REPORT|%s-mix|lufs=%.2f|tp=%.2f" % [_cue, _lufs_of(h, g) + 20.0 * log(gain) / log(10.0), D.lin2db(tp * gain)])


## Writes a loop master with its guard sample (the sample at loop_begin, played at loop_end).
func _save_loop(file: String, x: PackedFloat32Array, lb: int, k: float) -> void:
	var y := x.duplicate()
	y.append(x[lb])
	D.save_wav(y, masters + file + ".wav", k, D.sr)


## Masters and saves a one-shot (a stinger): integrated loudness on target under the ceiling.
func _master_one(file: String, x: PackedFloat32Array, target: float) -> void:
	var y := _space(x)
	D.fade_in(y, 0.0, 30.0)
	var k := pow(10.0, (target - Loudness.lufs(y, D.sr)) / 20.0)
	var tp := _true_peak(y) * k
	var capped := tp > D.db2lin(TP_MAX)
	if capped:
		k *= D.db2lin(TP_MAX) / tp
	D.save_wav(y, OUT + file + ".wav", k, D.sr)
	var yk := D.scale(y, k)
	_report.append("REPORT|%s|frames=%d|lufs=%.2f|tp=%.2f%s" % [file, y.size(), Loudness.lufs(yk, D.sr), D.lin2db(_true_peak(yk)), "|CAPPED" if capped else ""])


# ================================================================== title: "Incantation" (D minor, 96)

const T_DM9 := [53, 57, 62, 64]
const T_BBMAJ7 := [53, 58, 62, 69]
const T_A7 := [52, 55, 61, 64]
const T_DM := [50, 57, 62, 65]
const T_BB := [50, 53, 58, 62]
const T_F := [48, 53, 57, 60]
const T_C := [48, 52, 55, 60]
const T_GM := [50, 55, 58, 62]
const T_A := [49, 52, 57, 61]
const T_EB := [51, 55, 58, 63]
const T_CSUS2 := [48, 50, 55, 60]
## A (bars 5-12): the full motif on the bell, answered, then again with a higher tag.
const T_A_MEL := [
	[0, 74, 2], [2, 81, 2], [4, 77, 2], [6, 79, 2], [8, 81, 8],
	[16, 84, 4], [20, 86, 4], [24, 82, 2], [26, 81, 2], [28, 77, 4],
	[32, 81, 6], [38, 79, 2], [40, 77, 4], [44, 72, 4],
	[48, 76, 8], [56, 79, 4], [60, 76, 4],
	[64, 74, 2], [66, 81, 2], [68, 77, 2], [70, 79, 2], [72, 81, 8],
	[80, 84, 4], [84, 86, 4], [88, 89, 4], [92, 86, 4],
	[96, 82, 6], [102, 81, 2], [104, 79, 4], [108, 82, 4],
	[112, 81, 8], [120, 79, 2], [122, 76, 2], [124, 73, 4],
]
## B (bars 13-20): the same phrase sequenced up a fourth (G minor), turning home on A.
const T_B_MEL := [
	[0, 79, 2], [2, 86, 2], [4, 82, 2], [6, 84, 2], [8, 86, 8],
	[16, 89, 4], [20, 91, 4], [24, 87, 2], [26, 86, 2], [28, 82, 4],
	[32, 86, 6], [38, 84, 2], [40, 82, 4], [44, 77, 4],
	[48, 81, 8], [56, 84, 4], [60, 81, 4],
	[64, 79, 2], [66, 86, 2], [68, 82, 2], [70, 84, 2], [72, 86, 8],
	[80, 89, 4], [84, 91, 4], [88, 87, 4], [92, 86, 4],
	[96, 86, 6], [102, 84, 2], [104, 82, 4], [108, 77, 4],
	[112, 81, 4], [116, 79, 2], [118, 77, 2], [120, 76, 4], [124, 73, 4],
]
## Tag (bars 21-24): the motif augmented (eighths become half notes), ending on the tag C-D.
const T_TAG := [[0, 74, 8], [8, 81, 8], [16, 77, 8], [24, 79, 8], [32, 81, 16], [48, 84, 8], [56, 86, 8]]


func _title() -> void:
	_begin("title", 96.0)
	var bars := 24
	var ch := [T_DM9, T_DM9, T_BBMAJ7, T_A7, T_DM, T_BB, T_F, T_C, T_DM, T_BB, T_GM, T_A,
		T_GM, T_EB, T_BB, T_F, T_GM, T_EB, T_BB, T_A, T_DM, T_BBMAJ7, T_F, T_CSUS2]
	var roots := [38, 38, 46, 45, 38, 46, 41, 36, 38, 46, 43, 45, 43, 39, 46, 41, 43, 39, 46, 45, 38, 46, 41, 36]
	var pads := _bars(bars)
	_part("pads")
	_pads(pads, "pad_warm", ch, range(bars), {"db": -15.0})
	var harp := _bars(bars)
	_part("harp")
	for b in bars:
		var tones := _up(ch[b], 12)
		if b >= 12 and b < 20:
			_arp(harp, "harp", tones, b, [0, 1, 2, 3, 4, 3, 2, 1], 1, {"db": -15.0, "human": true})
		else:
			_arp(harp, "harp", tones, b, [0, 1, 2, 3, 4, 3, 2, 1], 2, {"db": -12.0, "human": true})
	# the intro's glass: the head (D A F) in bar 2, the rise to the tag in bar 4
	var glass := _bars(bars)
	_seq(glass, "glass_l", [[16, 86, 2], [18, 93, 2], [20, 89, 8], [48, 91, 2], [50, 93, 6], [56, 96, 4], [60, 98, 4]], {"db": -11.0})
	var bell := _bars(bars)
	_part("bell")
	_seq(bell, "bell_fm", _shift(T_A_MEL, 64), {"db": -6.0, "human": true})
	_seq(bell, "bell_fm", _shift(T_B_MEL, 192), {"db": -6.0, "human": true})
	_seq(bell, "bell_fm", _shift(T_TAG, 320), {"db": -7.0})
	var brass := _bars(bars)
	_seq(brass, "brass_saw", _shift(T_B_MEL, 192, -12), {"db": -16.0})
	var bass := _bars(bars)
	for b in bars:
		var r: int = roots[b]
		if b < 4 or b >= 20:
			_play(bass, "bass_sat", b * 16, r, 15, {"db": -10.0})
		else:
			_seq(bass, "bass_sat", [[b * 16, r, 7], [b * 16 + 8, r, 5], [b * 16 + 14, r + 7, 2]], {"db": -9.0})
	var drums := _bars(bars)
	_part("drums")
	for b in range(12, 20):
		_drum(drums, "kick", "X.......x.......", b, {"db": -10.0})
		_drum(drums, "glitch", "..x...x...x...x.", b, {"db": -20.0, "human": true})
		_drum(drums, "hat", "....g.......g..g", b, {"db": -18.0, "human": true})
	_diag("bass", bass)
	var stem := _stem([[pads], [harp], [glass], [bell], [brass], [bass], [drums]])
	_master([{"file": "music_title", "data": stem, "lb": 0}], MUSIC_LUFS, [])


# ================================================================== shop: "Merchant's Ledger" (D dorian, 96)

const S_CH := [[53, 57, 60, 62], [50, 55, 59, 62], [53, 57, 60, 62], [50, 55, 59, 62],
	[53, 57, 60, 64], [52, 55, 60, 64], [50, 55, 59, 64], [50, 52, 57, 62]]
## The motif on the music box (D dorian: the raised sixth, B, is the warmth), 8 bars.
const S_MEL := [
	[0, 74, 2], [2, 81, 2], [4, 77, 2], [6, 79, 2], [8, 81, 8],
	[16, 84, 4], [20, 86, 4], [24, 83, 2], [26, 81, 2], [28, 79, 4],
	[32, 81, 6], [38, 79, 2], [40, 77, 4], [44, 74, 4],
	[48, 76, 2], [50, 77, 2], [52, 79, 4], [56, 83, 8],
	[64, 81, 2], [66, 84, 2], [68, 81, 2], [70, 79, 2], [72, 77, 8],
	[80, 76, 4], [84, 79, 4], [88, 84, 8],
	[96, 83, 4], [100, 81, 4], [104, 79, 2], [106, 77, 2], [108, 76, 4],
	[112, 74, 2], [114, 76, 2], [116, 81, 12],
]
## The counter-line of the second pass: guide tones in long notes.
const S_COUNTER := [[0, 72, 8], [8, 77, 8], [16, 71, 16], [32, 72, 8], [40, 69, 8], [48, 71, 8], [56, 74, 8],
	[64, 76, 16], [80, 76, 8], [88, 79, 8], [96, 74, 16], [112, 74, 8], [120, 76, 8]]
## The pizzicato walking bass, four quarters a bar.
const S_WALK := [[50, 53, 48, 44], [43, 47, 50, 49], [50, 48, 45, 44], [43, 47, 45, 42],
	[41, 45, 43, 47], [48, 45, 43, 41], [40, 43, 47, 46], [45, 50, 52, 49]]


func _shop() -> void:
	_begin("shop", 96.0)
	var bars := 16
	var swing := {"swing": 0.58, "grid": 8}
	var mb := _bars(bars)
	_part("musicbox")
	var o := swing.duplicate()
	o.merge({"db": -5.0, "human": true})
	_seq(mb, "musicbox", S_MEL, o)
	_seq(mb, "musicbox", _shift(S_MEL, 128, 12), o)
	var o2 := o.duplicate()
	o2["db"] = -12.0
	_seq(mb, "musicbox", _shift(S_COUNTER, 128), o2)
	var pads := _bars(bars)
	_pads(pads, "pad_tri", S_CH, range(bars), {"db": -19.0})
	var bass := _bars(bars)
	_part("pizz")
	for b in bars:
		var w: Array = S_WALK[b % 8]
		for q in 4:
			_play(bass, "pizz", b * 16 + q * 4, w[q], 3, {"db": -6.0, "human": true})
	var shaker := _bars(bars)
	_part("shaker")
	for b in bars:
		_drum(shaker, "shaker", "XgxgXgxgXgxgXgxg", b, {"db": -17.0, "swing": 0.58, "grid": 16, "human": true})
	_diag("bass", bass)
	var stem := _glue(_stem([[mb], [pads], [bass], [shaker]]), 11.0)
	_master([{"file": "music_shop", "data": stem, "lb": 0}], MUSIC_LUFS, [])


# ================================================================== the Cellar (A minor, 120)

const C_CH := [[57, 60, 64, 69], [57, 60, 65, 69], [55, 60, 64, 67], [55, 59, 62, 67],
	[57, 60, 64, 69], [57, 60, 65, 69], [57, 62, 65, 69], [56, 59, 64, 68]]
## The breakdown keeps the roots and changes the voicings (Am9, Fmaj7, Cadd9, G6...).
const C_CH_B := [[57, 60, 64, 71], [53, 57, 60, 64], [55, 60, 62, 64], [55, 59, 62, 64],
	[55, 60, 64, 69], [53, 57, 60, 64], [57, 60, 64, 65], [56, 59, 62, 64]]
const C_ROOTS := [45, 41, 48, 43, 45, 41, 50, 40]
## The motif on the harp, the base's statement at the head of A and A''.
const C_HARP_MOTIF := [[0, 69, 2], [2, 76, 2], [4, 72, 2], [6, 74, 2], [8, 76, 8], [16, 79, 4], [20, 81, 4]]
## The lead (16 bars): the motif in bars 1-2, developed, and an answer that turns home to A.
const C_LEAD := [
	[0, 81, 2], [2, 88, 2], [4, 84, 2], [6, 86, 2], [8, 88, 8],
	[16, 91, 4], [20, 93, 4], [24, 89, 2], [26, 88, 2], [28, 84, 4],
	[32, 88, 6], [38, 86, 2], [40, 84, 4], [44, 79, 4],
	[48, 83, 8], [56, 86, 4], [60, 83, 4],
	[64, 81, 2], [66, 88, 2], [68, 84, 2], [70, 86, 2], [72, 88, 8],
	[80, 91, 4], [84, 93, 4], [88, 89, 4], [92, 88, 4],
	[96, 89, 6], [102, 88, 2], [104, 86, 4], [108, 81, 4],
	[112, 80, 8], [120, 83, 4], [124, 88, 4],
	[128, 81, 2], [130, 88, 2], [132, 84, 2], [134, 86, 2], [136, 88, 8],
	[144, 91, 4], [148, 93, 4], [152, 89, 2], [154, 88, 2], [156, 84, 4],
	[160, 88, 6], [166, 86, 2], [168, 84, 4], [172, 79, 4],
	[176, 83, 8], [184, 86, 4], [188, 83, 4],
	[192, 84, 4], [196, 88, 4], [200, 93, 8],
	[208, 93, 6], [214, 91, 2], [216, 89, 4], [220, 84, 4],
	[224, 86, 8], [232, 89, 4], [236, 88, 2], [238, 86, 2],
	[240, 83, 4], [244, 80, 4], [248, 81, 8],
]


func _cellar() -> void:
	_begin("cellar", 120.0)
	var human := {"human": true, "swing": 0.54, "grid": 16}
	# base: A (8), A' (8, the arp inverted), B breakdown (8), A'' (8)
	var pads := _bars(32)
	for b in 32:
		_pads(pads, "pad_warm", C_CH_B if b >= 16 and b < 24 else C_CH, [b], {"db": -16.0})
	var harp := _bars(32)
	_part("harp")
	var o := human.duplicate()
	o["db"] = -12.0
	for b in 32:
		if b >= 16 and b < 24 or b in [0, 1, 24, 25]:
			continue
		var tones := _up(C_CH[b % 8], 12)
		_arp(harp, "harp", tones, b, [0, 1, 2, 3, 4, 3, 2, 1] if b < 8 or b >= 24 else [4, 3, 2, 1, 0, 1, 2, 3], 1, o)
	var om := o.duplicate()
	om["db"] = -7.0
	_seq(harp, "harp", C_HARP_MOTIF, om)
	_seq(harp, "harp", _shift(C_HARP_MOTIF, 384), om)
	var wood := _bars(32)
	_part("wood")
	for b in 32:
		if b >= 16 and b < 24:
			_drum(wood, "wood", "x...g...x...g...", b, {"db": -14.0, "human": true})
		else:
			_drum(wood, "wood", "..g...g...g...g.", b, {"db": -16.0, "swing": 0.54, "human": true})
	# the breakdown's drips: the motif head (A E C) in glass, then seeded drops on the pentatonic
	var drips := _bars(32)
	var dr := D.rng_for("cellar/drips", 0, 0)
	_seq(drips, "glass_s", [[256, 93, 2], [259, 100, 2], [262, 96, 4]], {"db": -13.0})
	for k in 10:
		var step := 256 + 8 + dr.randi_range(0, 118)
		var m: int = [93, 96, 98, 100, 103][dr.randi_range(0, 4)]
		var db := dr.randf_range(-20.0, -14.0)
		_play(drips, "glass_s", step, m, 1, {"db": db})
		_play(drips, "glass_s", step, m, 1, {"db": db - 9.0, "off": 3})
	var bass := _bars(32)
	_part("bass")
	for b in 32:
		var r: int = C_ROOTS[b % 8]
		if b >= 16 and b < 24:
			_seq(bass, "bass_sat", [[b * 16, r, 7], [b * 16 + 8, r, 7]], {"db": -10.0})
		else:
			for q in 4:
				_play(bass, "bass_sat", b * 16 + q * 4, r, 3, {"db": -10.0, "human": true})
	_diag("bass", bass)
	var base := _stem([[pads], [harp], [wood], [drips], [bass]])
	# drums (8 bars): kick 1 and the "and" of 2, snare 2 and 4, swung hats, a fill, a motor bass
	var dr_buf := _bars(8)
	_part("drums")
	var dh := human.duplicate()
	for b in 8:
		var fill := b == 7
		_drum(dr_buf, "kick", "X.....x.X......." if b % 2 == 1 else "X.....x.........", b, dh)
		_drum(dr_buf, "snare", "....X...g.x.xxXX" if fill else "....X.......X...", b, dh)
		_drum(dr_buf, "hat", "xgxgxgxgxgxgxgog" if b == 3 else ("xgxgxgxg........" if fill else "xgxgxgxgxgxgxgxg"), b, _with(dh, "db", -7.0))
	var motor := _bars(8)
	for b in 8:
		var r: int = C_ROOTS[b]
		for e in 8:
			_play(motor, "bass_sat", b * 16 + e * 2, r + (24 if e == 2 or e == 6 else 12), 2, {"db": -13.0 if e % 2 == 1 else -11.0})
	_diag("motor", motor)
	_diag("kit", dr_buf)
	var drums := _glue(_stem([[dr_buf], [motor]]), 12.0)
	# lead (16 bars) with glass an octave up at -12 dB
	var lead := _bars(16)
	_part("lead")
	_seq(lead, "lead_pwm", C_LEAD, {"db": -6.0, "human": true})
	_seq(lead, "glass_s", _shift(C_LEAD, 0, 12), {"db": -18.0})
	var lead_s := _stem([[lead, _dip]])
	_master([{"file": "music_cellar_base", "data": base, "lb": 0}, {"file": "music_cellar_drums", "data": drums, "lb": 0},
		{"file": "music_cellar_lead", "data": lead_s, "lb": 0}], BASE_LUFS, [3.0, 1.5])


static func _with(o: Dictionary, k: String, v: Variant) -> Dictionary:
	var c := o.duplicate()
	c[k] = v
	return c


# ================================================================== the Corrupted Grove (C# phrygian, 120 half-time)

const G_CH := [[56, 61, 64, 68], [57, 62, 66, 69], [56, 61, 64, 68], [54, 59, 63, 66],
	[57, 61, 64, 69], [57, 62, 66, 69], [54, 59, 63, 66], [56, 61, 65, 68]]
const G_ROOTS := [37, 38, 37, 35, 45, 38, 35, 37]
## The corrupted motif (1-5-b3-b2-1): the fourth has fallen to the flat second.
const G_HARP_MOTIF := [[0, 73, 2], [2, 80, 2], [4, 76, 2], [6, 74, 2], [8, 73, 8]]
const G_LEAD := [
	[0, 85, 2], [2, 92, 2], [4, 88, 2], [6, 86, 2], [8, 85, 8],
	[16, 86, 4], [20, 90, 4], [24, 93, 6], [30, 90, 2],
	[32, 88, 4], [36, 86, 2], [38, 85, 2], [40, 80, 8],
	[48, 83, 6], [54, 87, 2], [56, 90, 8],
	[64, 85, 2], [66, 92, 2], [68, 88, 2], [70, 86, 2], [72, 85, 8],
	[80, 86, 6], [86, 88, 2], [88, 90, 4], [92, 93, 4],
	[96, 95, 6], [102, 93, 2], [104, 90, 4], [108, 87, 4],
	[112, 89, 8], [120, 85, 8],
]


func _grove() -> void:
	_begin("grove", 120.0)
	var pads := _bars(32)
	_pads(pads, "pad_dark", G_CH, range(32), {"db": -15.0})
	# a reversed pad swell into every 4th bar
	var swell := _bars(32)
	for b in range(3, 32, 4):
		var nxt: Array = G_CH[(b + 1) % 8]
		for m: int in nxt:
			var src := D.reverse(_note("pad_dark", m, 16 * _st, 0))
			_mix_wrap(swell, src, (b + 1) * 16 * _st - src.size(), D.db2lin(-19.0))
	var harp := _bars(32)
	_part("harp")
	for b in 32:
		if b in [0, 16]:
			continue
		var tones := _up(G_CH[b % 8], 12)
		var pat := [0, 2, 1, 3, 1, 2, 0, 3]
		for e in 8:
			if e == 3 or e == 7:
				continue
			var k: int = pat[e]
			_play(harp, "harp", b * 16 + e * 2, int(tones[k]), 2, {"db": -12.0 if e % 2 == 0 else -14.5, "human": true})
	_seq(harp, "harp", G_HARP_MOTIF, {"db": -7.0})
	_seq(harp, "harp", _shift(G_HARP_MOTIF, 256), {"db": -7.0})
	var bass := _bars(32)
	for b in 32:
		var r: int = G_ROOTS[b % 8]
		_seq(bass, "fm_bass", [[b * 16, r, 5], [b * 16 + 6, r, 2], [b * 16 + 8, r + 12, 3], [b * 16 + 11, r, 3]], {"db": -11.0})
	var crushed := func(x: PackedFloat32Array) -> PackedFloat32Array: return D.crush(x, 3, 7.0, 0.3)
	var base := _stem([[pads, crushed], [swell], [_wow_loop(harp, 15.0, 0.7)], [bass]])
	# drums (8): half-time kick and gated snare, rims, a glitch stutter every 2nd bar, the wub
	var dr := _bars(8)
	_part("drums")
	for b in 8:
		_drum(dr, "kick", "X.........g....." if b % 2 == 1 else "X...............", b)
		_drum(dr, "gsnare", "........X.......", b)
		_drum(dr, "rim", "...x..x....x..g.", b, {"db": -6.0, "human": true})
		_drum(dr, "hat", "....g.......g...", b, {"db": -12.0})
		if b % 2 == 1:
			for k in 3:
				D.mix_at(dr, _note("glitch", 60.0, 1, k), b * 16 * _st + 15 * _st + k * (_st / 3), D.db2lin(-4.0 - 2.0 * k))
	var wub := _bars(8)
	for b in 8:
		for e in 8:
			_play(wub, "wub", b * 16 + e * 2, int(G_ROOTS[b]) + 12, 2, {"db": -12.0, "gate": 0.95})
	var dcr := func(x: PackedFloat32Array) -> PackedFloat32Array: return D.crush(x, 4, 6.0, 0.35)
	_diag("wub", wub)
	_diag("kit", dr)
	_diag("bass", bass)
	var drums := _glue(_stem([[dr, dcr], [wub]]), 12.0)
	# lead: the corrupted motif on crushed glass-FM; the second 8 bars stutter every long note
	var lead := _bars(16)
	_seq(lead, "glass_fm", G_LEAD, {"db": -6.0})
	_seq(lead, "glass_fm", _shift(_stuttered(G_LEAD), 128), {"db": -6.0})
	var lcr := func(x: PackedFloat32Array) -> PackedFloat32Array: return _dip(D.crush(x, 3, 6.0, 0.4))
	var lead_s := _stem([[lead, lcr]])
	_master([{"file": "music_grove_base", "data": base, "lb": 0}, {"file": "music_grove_drums", "data": drums, "lb": 0},
		{"file": "music_grove_lead", "data": lead_s, "lb": 0}], BASE_LUFS, [3.0, 1.5])


# ================================================================== the Overheated Foundry (F minor, 125)

const F_CH := [[53, 56, 60, 65], [53, 56, 60, 65], [53, 56, 61, 65], [51, 55, 58, 63],
	[53, 56, 60, 65], [53, 56, 60, 65], [53, 58, 61, 65], [52, 55, 60, 64]]
const F_ROOTS := [41, 41, 37, 39, 41, 41, 46, 48]
## The anvil ostinato: the motif as a one-bar machine riff in eighths, on F, on E-flat
## (mixolydian) and on C (the dominant, with the E natural).
const F_RIFF_F := [65, 72, 68, 70, 72, 75, 77, 72]
const F_RIFF_EB := [63, 70, 67, 68, 70, 73, 75, 70]
const F_RIFF_C := [60, 67, 64, 65, 67, 70, 72, 67]
const F_LEAD := [
	[0, 77, 2], [2, 84, 2], [4, 80, 2], [6, 82, 2], [8, 84, 8],
	[16, 87, 4], [20, 89, 4], [24, 87, 2], [26, 84, 2], [28, 80, 4],
	[32, 80, 6], [38, 82, 2], [40, 84, 4], [44, 85, 4],
	[48, 87, 8], [56, 82, 4], [60, 79, 4],
	[64, 77, 2], [66, 84, 2], [68, 80, 2], [70, 82, 2], [72, 84, 8],
	[80, 87, 4], [84, 89, 4], [88, 87, 4], [92, 84, 4],
	[96, 89, 6], [102, 87, 2], [104, 85, 4], [108, 82, 4],
	[112, 84, 8], [120, 79, 4], [124, 76, 4],
]
## The bell's answer in the second pass, an octave up, in the lead's long notes.
const F_ANSWER := [[136, 89, 2], [138, 96, 2], [140, 92, 4], [168, 92, 2], [170, 94, 2], [172, 96, 4],
	[184, 99, 4], [188, 94, 4], [200, 96, 8], [232, 94, 4], [236, 92, 4], [252, 100, 4]]


func _foundry() -> void:
	_begin("foundry", 125.0)
	var anvil := _bars(32)
	_part("anvil")
	for b in 32:
		var riff: Array = F_RIFF_EB if b % 8 == 3 else (F_RIFF_C if b % 8 == 7 else F_RIFF_F)
		for e in 8:
			_play(anvil, "anvil", b * 16 + e * 2, int(riff[e]), 2, {"db": -8.0 if e % 2 == 0 else -10.5, "human": true})
	var steam := _bars(32)
	for b in range(1, 32, 2):
		_play(steam, "steam", b * 16 + 2, 60.0, 1, {"db": -16.0})
	var pads := _bars(32)
	_pads(pads, "pad_dark", _up_all(F_CH, -12), range(32), {"db": -17.0})
	var bass := _bars(32)
	for b in 32:
		var r: int = F_ROOTS[b % 8]
		for e in 8:
			_play(bass, "bass_sat", b * 16 + e * 2, r + (12 if e == 3 or e == 7 else 0), 2, {"db": -10.0 if e % 2 == 0 else -12.0})
	_diag("bass", bass)
	var base := _stem([[anvil], [steam], [pads], [bass]])
	# drums (8): four on the floor, anvil + noise snare on 2 and 4, straight hammer 16ths, a tom fill
	var dr := _bars(8)
	for b in 8:
		var fill := b == 7
		_drum(dr, "kick", "X...X...X...X...", b, {"db": -6.0})
		_drum(dr, "snare", "....X......." + ("...." if fill else "X..."), b)
		_drum(dr, "anvil", "....x.......x...", b, {"db": -4.0}, 72.0)
		_drum(dr, "hammer", "XgxgXgxg........" if fill else "XgxgXgxgXgxgXgxg", b, {"db": -1.0})
	for k in 6:
		_play(dr, "tom", 7 * 16 + [8, 10, 12, 13, 14, 15][k], D_TOM[k], 1, {"db": -2.0 + k * 0.5})
	var drums := _glue(_stem([[dr]]), 12.0)
	# the lead sits in octave 6 (1.3-2.8 kHz), above the telegraph band (R1, §4.1)
	var lead := _bars(16)
	_seq(lead, "furnace_lead", F_LEAD, {"db": -6.0, "tr": 12})
	_seq(lead, "furnace_lead", _shift(F_LEAD.slice(0, F_LEAD.size() - 3), 128) + [[240, 84, 4], [244, 79, 4], [248, 88, 8]], {"db": -6.0, "tr": 12})
	_seq(lead, "bell_fm", F_ANSWER, {"db": -14.0})
	var lead_s := _stem([[lead, _dip]])
	_master([{"file": "music_foundry_base", "data": base, "lb": 0}, {"file": "music_foundry_drums", "data": drums, "lb": 0},
		{"file": "music_foundry_lead", "data": lead_s, "lb": 0}], BASE_LUFS, [3.0, 1.5])


## Tom pitches (MIDI) for a descending fill: about 140, 125, 110, 100, 90, 80 Hz.
const D_TOM := [49.0, 47.0, 45.0, 43.5, 41.5, 39.5]


static func _up_all(chords: Array, semis: int) -> Array:
	var out: Array = []
	for c: Array in chords:
		out.append(_up(c, semis))
	return out


# ================================================================== the Kernel (B minor, 100)

## World 3 (research/world3-0.20.md §3): the Page Archive and Ring Zero share one track. The
## Archive's mood is the base: sparse clockwork, a celesta over a low pulse and a tick-tock
## clock in straight eighths. The drums and the lead make it drive in a fight. The motif's
## Kernel form is "paged": the motif with every second note flipped an octave down, as memory
## pages swap in and out (B F# D E F# | A B, then B f# D e F# | a B).
## 100 bpm: bar 76,800, 16th 4,800 samples (whole, §5.1).
const K_CH := [[54, 59, 62, 66], [54, 59, 62, 66], [52, 55, 59, 62], [54, 58, 61, 64],
	[55, 59, 62, 66], [55, 59, 62, 66], [52, 57, 61, 64], [54, 58, 61, 64]]
## Bm Bm Em7 F#7 | Gmaj7 Gmaj7 A F#7 (the F# major's A# is the harmonic minor's pull home).
const K_ROOTS := [47, 47, 40, 42, 43, 43, 45, 42]
## The melody (8 bars): the motif, its answer, the paged motif, its answer, home to F#.
const K_MEL := [
	[0, 83, 2], [2, 90, 2], [4, 86, 2], [6, 88, 2], [8, 90, 8],
	[16, 93, 4], [20, 95, 4], [24, 93, 2], [26, 91, 2], [28, 90, 4],
	[32, 88, 6], [38, 86, 2], [40, 85, 4], [44, 86, 4],
	[48, 90, 8], [56, 85, 4], [60, 82, 4],
	[64, 83, 2], [66, 78, 2], [68, 86, 2], [70, 76, 2], [72, 90, 8],
	[80, 81, 4], [84, 95, 4], [88, 98, 4], [92, 95, 4],
	[96, 93, 6], [102, 91, 2], [104, 90, 4], [108, 88, 4],
	[112, 85, 8], [120, 82, 4], [124, 78, 4],
]
## The paged motif alone (the head of A'').
const K_PAGED := [[0, 83, 2], [2, 78, 2], [4, 86, 2], [6, 76, 2], [8, 90, 8], [16, 81, 4], [20, 95, 4]]


func _kernel() -> void:
	_begin("kernel", 100.0)
	# base: A (8, the melody), A' (8, the music box winds: an arpeggio), B breakdown (8: the
	# clock, the pulse and glass pings of the head), A'' (8, the arpeggio turned, the paged head)
	var pads := _bars(32)
	_part("pads")
	for b in 32:
		var brk := b >= 16 and b < 24
		_pads(pads, "pad_dark" if brk else "pad_warm", K_CH, [b], {"db": -16.0 if brk else -18.0})
	var cel := _bars(32)
	_part("celesta")
	_seq(cel, "celesta", K_MEL, {"db": -8.0})
	for b in range(8, 32):
		if b >= 16 and b < 24:
			continue
		var tones := _up(K_CH[b % 8], 24)
		_arp(cel, "celesta", tones, b, [0, 2, 1, 3, 4, 3, 2, 1] if b < 16 else [4, 3, 2, 1, 0, 1, 2, 3], 2, {"db": -15.0 if b < 16 else -17.0})
	_seq(cel, "celesta", _shift(K_PAGED, 384), {"db": -9.0})
	# the breakdown: the head (B F# D) in glass, high, then an octave down
	_seq(cel, "glass_l", [[256, 95, 4], [260, 102, 4], [264, 98, 8], [320, 83, 4], [324, 90, 4], [328, 86, 8]], {"db": -12.0})
	var clock := _bars(32)
	_part("clock")
	for b in 32:
		if b >= 16 and b < 24:
			_drum(clock, "tick", "x.......x.......", b, {"db": -14.0})
			_drum(clock, "tock", "....g.......g...", b, {"db": -14.0})
		else:
			_drum(clock, "tick", "x...x...x...x...", b, {"db": -15.0})
			_drum(clock, "tock", "..g...g...g...g.", b, {"db": -15.0})
	# the low pulse: the root on the beat, a pendulum (a half note in the breakdown)
	var pulse := _bars(32)
	_part("pulse")
	for b in 32:
		var r: int = K_ROOTS[b % 8]
		if b >= 16 and b < 24:
			_seq(pulse, "bass_sat", [[b * 16, r, 3], [b * 16 + 8, r, 3]], {"db": -11.0})
		else:
			for q in 4:
				_play(pulse, "bass_sat", b * 16 + q * 4, r, 2, {"db": -10.0 if q == 0 else -13.0})
	_diag("pulse", pulse)
	var base := _stem([[pads], [cel], [clock], [pulse]])
	# drums (8): kick 1, the "and" of 2 and 3, snare 2 and 4, the clock as 16th hats, a
	# ratchet bass in 16ths, the bug's glitch closing bars 4 and 8, a tom fill
	var dr := _bars(8)
	_part("drums")
	for b in 8:
		var fill := b == 7
		_drum(dr, "kick", "X.....x.X.....x." if not fill else "X.....x.X.......", b, {"db": -5.0})
		_drum(dr, "snare", "....X......." + ("...." if fill else "X..."), b)
		_drum(dr, "tick", "XgxgXgxg........" if fill else "XgxgXgxgXgxgXgxg", b, {"db": -2.0})
		if b == 3 or b == 7:
			_drum(dr, "glitch", "...............x", b, {"db": -3.0})
	for k in 6:
		_play(dr, "tom", 7 * 16 + [8, 10, 12, 13, 14, 15][k], D_TOM[k], 1, {"db": -2.0 + k * 0.5})
	var motor := _bars(8)
	for b in 8:
		var r: int = K_ROOTS[b]
		for s in 16:
			if s % 2 == 0:
				_play(motor, "bass_sat", b * 16 + s, r + (24 if s == 4 or s == 12 else 12), 2, {"db": -11.0 if s % 4 == 0 else -13.0})
			else:
				_play(motor, "bass_sat", b * 16 + s, r + 12, 1, {"db": -19.0})
	_diag("motor", motor)
	var drums := _glue(_stem([[dr], [motor]]), 12.0)
	# lead (16): the melody on the pulse lead with the celesta an octave up; the second pass
	# races itself, a second thread 3/16 behind on the celesta, and turns home on F#
	var lead := _bars(16)
	_part("lead")
	var pass2: Array = _shift(K_MEL.slice(0, K_MEL.size() - 3), 128) + [[240, 85, 4], [244, 88, 4], [248, 90, 8]]
	_seq(lead, "lead_pwm", K_MEL + pass2, {"db": -7.0, "human": true})
	_seq(lead, "celesta", K_MEL + pass2, {"db": -10.0, "tr": 12})
	_seq(lead, "celesta", _shift(pass2, 3), {"db": -14.0, "tr": 12})
	var lead_s := _stem([[lead, _dip]])
	_master([{"file": "music_kernel_base", "data": base, "lb": 0}, {"file": "music_kernel_drums", "data": drums, "lb": 0},
		{"file": "music_kernel_lead", "data": lead_s, "lb": 0}], BASE_LUFS, [3.0, 1.5])


# ================================================================== mini-bosses: Copy-Paste, the Garbage Collector (E minor, 128)

const M_CH := [[52, 55, 59, 64], [52, 55, 60, 64], [52, 57, 60, 64], [51, 54, 59, 63],
	[52, 55, 59, 64], [52, 55, 60, 64], [50, 54, 57, 62], [51, 54, 59, 63]]
const M_ROOTS := [40, 36, 45, 35, 40, 36, 38, 35]
## The whole motif backwards (1'-b7-5 | 4-b3-5-1), the rhythm reversed too.
const M_RETRO := [[0, 88, 4], [4, 86, 4], [8, 83, 8], [16, 81, 2], [18, 79, 2], [20, 83, 2], [22, 76, 2]]
const M_COPY := [
	[32, 84, 4], [36, 83, 4], [40, 81, 8], [48, 78, 2], [50, 75, 2], [52, 78, 2], [54, 71, 2],
	[96, 86, 4], [100, 84, 4], [104, 81, 8], [112, 87, 2], [114, 83, 2], [116, 87, 2], [118, 78, 2],
]
## p2: the retrograde cell in eighths on brass (E, or B over the dominant), with a fifth above.
const M_CELL_E := [76, 74, 71, 69, 67, 71, 76]
const M_CELL_B := [71, 69, 66, 64, 63, 66, 71]
const M_GATE := "x.xx.x.xx.xxx.x."


func _mini() -> void:
	_begin("mini", 128.0)
	var lb := 2 * 16 * _st
	# intro (2 bars): the retrograde head on glitched glass, pasted; a crash; a reversed swell
	var intro := _bars(4)
	var ig := _bars(4)
	_seq(ig, "glass", [[0, 83, 8], [8, 81, 2], [10, 79, 2], [12, 83, 2], [14, 76, 2]], {"db": -4.0, "wrap": false})
	ig = D.delay(D.crush(ig, 3, 6.0, 0.5), 3.0 * _st * 1000.0 / D.sr, 0.45, 3500.0, 0.7)
	D.mix_at(intro, ig, 0, 1.0)
	_play(intro, "crash", 16, 60.0, 1, {"db": -8.0, "wrap": false})
	for s in [24, 28, 30]:
		_play(intro, "tom", s, 45.0, 1, {"db": -8.0 + (s - 24) * 0.8, "wrap": false})
	var rev := D.reverse(_note("crash", 60.0, 1, 1))
	rev = D.slice(rev, rev.size() - D.n_of(600.0), D.n_of(600.0))
	D.fade_in(rev, 5.0, 8.0)
	D.mix_at(intro, rev, lb - rev.size(), D.db2lin(-10.0))
	# loop (16 bars): chopped dark pads, FM bass, glitch drums, the copy lead
	var pads := _bars(16)
	_pads(pads, "pad_dark", M_CH, range(16), {"db": -13.0})
	var gate := D.zeros(pads.size())
	var ramp := D.n_of(3.0)
	for i in gate.size():
		var s := (i / _st) % 16
		var ph := i % _st
		if M_GATE[s] == "x":
			gate[i] = minf(1.0, minf(float(ph) / ramp, float(_st - ph) / ramp))
	pads = D.amp(pads, gate)
	var bass := _bars(16)
	for b in 16:
		var r: int = M_ROOTS[b % 8]
		_seq(bass, "fm_bass", [[b * 16, r, 2], [b * 16 + 3, r, 2], [b * 16 + 6, r, 2], [b * 16 + 8, r, 1],
			[b * 16 + 10, r + 12, 2], [b * 16 + 12, r, 1], [b * 16 + 14, r, 2]], {"db": -11.0})
	var dr := _bars(16)
	_part("drums")
	for b in 16:
		_drum(dr, "kick", "X......X..X.....", b)
		_drum(dr, "snare", "....X.......X..." if b % 4 != 3 else "....X.......XgXX", b)
		_drum(dr, "glitch", ["..g.....g..g..gg", ".g....g...g.g...", "..g..g.....g.g.g", "g.....g.g.....gg"][b % 4], b, {"db": -5.0})
		_drum(dr, "hat", "x.x.x.x.x.x.x.x.", b, {"db": -9.0, "human": true})
	var drc := func(x: PackedFloat32Array) -> PackedFloat32Array: return D.crush(x, 3, 7.0, 0.35)
	var lead := _bars(16)
	for rep in [0, 64, 128, 192]:
		_seq(lead, "lead_pwm", _shift(M_RETRO, rep), {"db": -8.0})
	_seq(lead, "lead_pwm", M_COPY, {"db": -8.0})
	_seq(lead, "lead_pwm", _shift(M_COPY, 128), {"db": -8.0})
	var paste := func(x: PackedFloat32Array) -> PackedFloat32Array: return _dip(D.delay(x, 3.0 * _st * 1000.0 / D.sr, 0.45, 3500.0, 0.7))
	var loop := _stem([[pads], [bass], [dr, drc], [lead, paste]])
	var base := _fold(intro, loop, lb)
	# p2 (8 bars after 2 silent): brass retrograde cell in eighths, doubled a fifth up
	var p2 := _bars(8)
	for b in 8:
		var cell: Array = M_CELL_B if b % 4 == 3 else M_CELL_E
		for e in 7:
			_play(p2, "brass_saw", b * 16 + e * 2, int(cell[e]), 2, {"db": -8.0})
			_play(p2, "brass_saw", b * 16 + e * 2, int(cell[e]) + 7, 2, {"db": -12.0})
	var p2_s := _fold(D.zeros(lb), _stem([[p2, _dip]]), lb)
	_master([{"file": "music_mini_loop", "data": base, "lb": lb}, {"file": "music_mini_p2", "data": p2_s, "lb": lb}], BASE_LUFS + 0.9, [3.6])


# ================================================================== final bosses: the Infinite Loop, Deadlock (C minor, 150)

const B_CH := [[55, 60, 63, 67], [56, 60, 63, 68], [55, 58, 63, 67], [53, 58, 62, 65],
	[55, 60, 63, 67], [56, 60, 63, 68], [53, 56, 60, 65], [55, 59, 62, 67]]
## The chord's degree in C minor (0 = C) for the ostinato's diatonic transposition.
const B_DEG := [0, 5, 2, 6, 0, 5, 3, 4]
## The 12-step harp counter-cell (3 against 4): C G Eb C G Bb G Eb in 16ths and rests.
const B_HARP := [[0, 84], [2, 91], [3, 87], [5, 84], [6, 91], [8, 94], [9, 91], [11, 87]]
## p2: the brass lead in diminution (16ths, quarter, eighths), 16 bars.
const B_P2 := [
	[0, 72, 1], [1, 79, 1], [2, 75, 1], [3, 77, 1], [4, 79, 4], [8, 82, 2], [10, 84, 6],
	[16, 84, 4], [20, 82, 2], [22, 80, 2], [24, 79, 4], [28, 75, 4],
	[32, 75, 1], [33, 82, 1], [34, 79, 1], [35, 80, 1], [36, 82, 4], [40, 86, 2], [42, 87, 6],
	[48, 86, 4], [52, 84, 2], [54, 82, 2], [56, 79, 4], [60, 77, 4],
	[64, 72, 1], [65, 79, 1], [66, 75, 1], [67, 77, 1], [68, 79, 4], [72, 82, 2], [74, 84, 6],
	[80, 84, 4], [84, 87, 4], [88, 84, 2], [90, 82, 2], [92, 80, 4],
	[96, 77, 1], [97, 84, 1], [98, 80, 1], [99, 82, 1], [100, 84, 4], [104, 87, 2], [106, 89, 6],
	[112, 86, 4], [116, 83, 4], [120, 79, 4], [124, 74, 4],
]
const B_CHOIR := [[60, 63, 67], [60, 63, 68], [58, 63, 67], [58, 62, 65], [60, 63, 67], [60, 63, 68], [60, 65, 68], [59, 62, 67]]
## p3: the motif augmented (eighths become half notes) in brass, the finale.
const B_P3 := [[0, 72, 8], [8, 79, 8], [16, 75, 8], [24, 77, 8], [32, 79, 32], [64, 82, 16], [80, 84, 32], [112, 83, 8], [120, 86, 8]]


## The ostinato cell for one bar: the motif in 16ths, twice, diatonically on the chord's
## degree (harmonic minor over G, so the leading tone is B natural).
func _boss_cell(deg: int) -> Array:
	var scale := HARMONIC if deg == 4 else MINOR
	var down := 12 if deg >= 3 else 0
	var out: Array = []
	for half in 2:
		for i in 8:
			var d: int = MOTIF[i] if i < 7 else 4
			if half == 1 and i == 7:
				d = 6
			out.append([half * 8 + i, _deg(48 - down, scale, d + deg), 1])
	return out


func _boss() -> void:
	_begin("boss", 150.0)
	var lb := 4 * 16 * _st
	# intro (4 bars): a riser, a tom crescendo, and the tritone brass (C then F#), into bar 5
	var intro := _bars(6)
	var r := D.rng_for("boss/intro", 0, 0)
	var n := lb
	var fc := D.penv(400.0, 4000.0, D.ms_of(n), n)
	var riser := D.amp(D.svf_mod(D.noise(n, r, "pink"), "bp", fc, 2.0), D.rise_db(24.0, D.ms_of(n), n))
	D.fade_in(riser, 0.0, 15.0)
	D.mix_at(intro, riser, 0, D.db2lin(-12.0))
	for nt: Array in [[0, 48, 15], [16, 54, 15], [32, 48, 15], [48, 54, 8], [56, 55, 6]]:
		_play(intro, "brass_saw", nt[0], nt[1], nt[2], {"db": -7.0, "wrap": false})
		_play(intro, "brass_saw", nt[0], int(nt[1]) + 12, nt[2], {"db": -11.0, "wrap": false})
	for s in range(32, 60, 2):
		_play(intro, "tom", s, 45.0 if s % 4 == 0 else 48.0, 1, {"db": -20.0 + (s - 32) * 0.6, "wrap": false})
	for s in range(60, 64):
		_play(intro, "snare", s, 60.0, 1, {"db": -6.0 + (s - 60), "wrap": false, "vars": 3})
	# the loop (32 bars): the "infinite loop" ostinato, the 3:4 harp, big drums, dark pads
	var cell := _bars(32)
	_part("cell")
	for b in 32:
		_seq(cell, "bass_sat", _shift(_boss_cell(B_DEG[b % 8]), b * 16), {"db": -9.0, "gate": 0.85})
	var harp := _bars(32)
	for block in 4:
		var s := 0
		while s < 128:
			for nt: Array in B_HARP:
				if s + int(nt[0]) < 128:
					_play(harp, "harp", block * 128 + s + int(nt[0]), nt[1], 1, {"db": -14.0})
			s += 12
	var pads := _bars(32)
	_pads(pads, "pad_dark", B_CH, range(32), {"db": -18.0})
	var dr := _bars(32)
	_part("drums")
	for b in 32:
		var fill := b % 8 == 7
		_drum(dr, "kick", "X.....x.X.......", b)
		_drum(dr, "snare", "....X...xgxgXxXX" if fill else "....X.......X...", b)
		_drum(dr, "hat", "XgxgXgxgXgxgXgxg", b, {"db": -8.0, "human": true})
		if b % 8 == 0:
			_play(dr, "crash", b * 16, 60.0, 1, {"db": -6.0})
	_diag("cell", cell)
	var loop := _stem([[cell], [harp], [pads], [dr]])
	var base := _fold(intro, loop, lb)
	# p2 (16 bars): brass lead in diminution + the choir
	var p2 := _bars(16)
	_seq(p2, "brass_saw", B_P2, {"db": -6.0})
	_seq(p2, "brass_saw", _shift(B_P2.slice(0, B_P2.size() - 4), 128) + [[240, 86, 2], [242, 83, 2], [244, 79, 2], [246, 83, 2], [248, 86, 4], [252, 83, 4]], {"db": -6.0})
	var choir := _bars(16)
	_pads(choir, "choir_pad", B_CHOIR, range(16), {"db": -13.0})
	var p2_s := _fold(D.zeros(lb), _stem([[p2, _dip], [choir]]), lb)
	# p3 (8 bars): the augmented motif on brass and bells, half-time big toms
	var p3 := _bars(8)
	_seq(p3, "brass_saw", B_P3, {"db": -4.0, "gate": 0.97})
	_seq(p3, "brass_saw", _shift(B_P3, 0, -12), {"db": -10.0, "gate": 0.97})
	for nt: Array in B_P3:
		var s := int(nt[0])
		while s < int(nt[0]) + int(nt[2]):
			_play(p3, "bell_fm", s, int(nt[1]) + 12, 8, {"db": -12.0 if s == int(nt[0]) else -17.0})
			s += 8
	for b in 8:
		_drum(p3, "tom", "X.......x......." if b != 7 else "X.......x.x.x.xx", b, {"db": -3.0}, 43.0)
	var p3_s := _fold(D.zeros(lb), _stem([[p3, _dip]]), lb)
	_master([{"file": "music_boss_loop", "data": base, "lb": lb}, {"file": "music_boss_p2", "data": p2_s, "lb": lb},
		{"file": "music_boss_p3", "data": p3_s, "lb": lb}], BASE_LUFS, [2.5, 2.0])


# ================================================================== stingers (§5.10)

## A one-shot buffer of `secs` seconds.
func _shot(secs: float) -> PackedFloat32Array:
	return D.zeros(int(roundf(secs * D.sr)))


## A note in a one-shot at t seconds, held `dur` seconds.
func _at(buf: PackedFloat32Array, inst: String, t: float, midi: float, dur: float, db := 0.0) -> void:
	var src := _note(inst, midi, maxi(1, int(roundf(dur * D.sr))), 0)
	D.mix_at(buf, src, int(roundf(t * D.sr)), D.db2lin(db))


## A shimmer: glass pings rising and trembling on the chord's tones, from t for `secs`.
func _shimmer(buf: PackedFloat32Array, tones: Array, t: float, secs: float, db: float) -> void:
	var k := 0
	var s := t
	while s < t + secs:
		_at(buf, "glass_s", s, int(tones[k % tones.size()]) + 12 * (k / tones.size() % 2), 0.1, db - 1.5 * (s - t))
		k += 1
		s += 0.07


func _stingers() -> void:
	_begin("sting", 120.0)
	# room clear: the head resolved (1-5 -> 1'), glass and a brass bar, in the area key
	for key: Array in [["sting_clear", 0], ["sting_clear_grove", 4], ["sting_clear_foundry", -4], ["sting_clear_kernel", 2]]:
		var b := _shot(1.4)
		var tr: int = key[1]
		_at(b, "glass_l", 0.0, 81 + tr, 0.2, -3.0)
		_at(b, "glass_l", 0.11, 88 + tr, 0.2, -4.0)
		_at(b, "glass_l", 0.26, 93 + tr, 0.4, -2.0)
		_at(b, "brass_bar", 0.26, 81 + tr, 0.6, -5.0)
		_at(b, "brass_bar", 0.26, 69 + tr, 0.6, -9.0)
		_master_one(key[0], b, STING_LUFS)
	# reward: the motif in major, fast, ascending, on bells with a shimmer, in the area key
	for key: Array in [["sting_reward", 0], ["sting_reward_grove", 4], ["sting_reward_foundry", -4], ["sting_reward_kernel", 2]]:
		var b := _shot(2.0)
		var tr: int = key[1]
		var mel := [81, 88, 85, 86, 88, 92, 93]
		for i in mel.size():
			_at(b, "bell_fm", i * 0.055, int(mel[i]) + tr, 0.12 if i < 6 else 0.5, -4.0)
		for m in [69, 73, 76]:
			_at(b, "pad_warm", 0.33, m + tr, 1.0, -14.0)
		_shimmer(b, [93 + tr, 97 + tr, 100 + tr], 0.4, 1.2, -12.0)
		_master_one(key[0], b, STING_LUFS)
	# boss: the tritone head (C -> F#) on low brass, a tom, a reversed cymbal lead-in
	var bs := _shot(2.5)
	var rev := D.reverse(_note("crash", 60.0, 1, 2))
	rev = D.slice(rev, rev.size() - D.n_of(500.0), D.n_of(500.0))
	D.fade_in(rev, 5.0, 6.0)
	D.mix_at(bs, rev, 0, D.db2lin(-6.0))
	_at(bs, "tom", 0.5, 42.0, 0.1, 0.0)
	_at(bs, "brass_saw", 0.5, 60, 0.3, -3.0)
	_at(bs, "brass_saw", 0.5, 48, 0.3, -5.0)
	_at(bs, "brass_saw", 0.82, 66, 1.45, -3.0)
	_at(bs, "brass_saw", 0.82, 54, 1.45, -5.0)
	_at(bs, "tom", 0.82, 39.0, 0.1, -3.0)
	_master_one("sting_boss", bs, STING_LUFS)
	# boss down: the head in major on brass over a held tonic, with shimmer (C major)
	var bd := _shot(3.0)
	for m in [48, 55, 60, 64]:
		_at(bd, "pad_warm", 0.0, m, 2.0, -12.0)
	_at(bd, "brass_saw", 0.0, 72, 0.16, -4.0)
	_at(bd, "brass_saw", 0.18, 79, 0.16, -4.0)
	_at(bd, "brass_saw", 0.36, 76, 0.2, -4.0)
	_at(bd, "brass_saw", 0.6, 84, 1.9, -4.0)
	_at(bd, "brass_bar", 0.6, 72, 0.5, -6.0)
	_at(bd, "tom", 0.6, 43.0, 0.1, -4.0)
	_shimmer(bd, [96, 100, 103], 0.7, 1.6, -12.0)
	_master_one("sting_boss_down", bd, STING_LUFS)
	# victory: the full motif in D major on brass and bells over the warm pad; the 1 held
	var v := _shot(5.0)
	var vm := [[0.0, 62, 0.23], [0.25, 69, 0.23], [0.5, 66, 0.23], [0.75, 67, 0.23], [1.0, 69, 0.95], [2.0, 73, 0.45], [2.5, 74, 2.1]]
	for nt: Array in vm:
		_at(v, "brass_saw", nt[0], nt[1], nt[2], -5.0)
		_at(v, "bell_fm", nt[0], int(nt[1]) + 12, nt[2], -8.0)
	for c: Array in [[0.0, [50, 57, 62, 66], 0.95], [1.0, [50, 55, 59, 62], 0.95], [2.0, [49, 52, 57, 61], 0.45], [2.5, [50, 57, 62, 66, 69], 2.0]]:
		for m: int in c[1]:
			_at(v, "pad_warm", c[0], m, c[2], -14.0)
	for t in [0.0, 1.0, 2.0, 2.5]:
		_at(v, "tom", t, 38.0, 0.1, -6.0)
	_shimmer(v, [86, 90, 93], 2.6, 2.0, -11.0)
	_master_one("sting_victory", v, STING_LUFS)
	# defeat: the motif inverted and falling in D minor, slowing, ending b6 -> 5 unresolved
	var df := _shot(4.0)
	for nt: Array in [[0.0, 74], [0.4, 67], [0.85, 70], [1.35, 69], [1.95, 67], [2.6, 58], [3.3, 57]]:
		_at(df, "harp", nt[0], nt[1], 0.3, -3.0)
	for m in [55, 58, 62]:
		_at(df, "pad_dark", 0.0, m, 2.4, -12.0)
	for m in [46, 55, 58]:
		_at(df, "pad_dark", 2.6, m, 0.6, -12.0)
	for m in [45, 52, 57]:
		_at(df, "pad_dark", 3.3, m, 0.2, -12.0)
	_master_one("sting_defeat", df, STING_LUFS)
	# world: entering World 2, the motif in F minor on anvil and brass
	var w := _shot(3.0)
	for nt: Array in [[0.0, 65, 0.22], [0.24, 72, 0.22], [0.48, 68, 0.22], [0.72, 70, 0.22], [0.96, 72, 0.45], [1.44, 75, 0.45], [1.92, 77, 1.0]]:
		_at(w, "anvil", nt[0], nt[1], 0.1, -2.0)
		_at(w, "brass_saw", nt[0], int(nt[1]) - 12, nt[2], -7.0)
	_at(w, "steam", 1.9, 60.0, 0.1, -10.0)
	_master_one("sting_world", w, STING_LUFS)
	# world, into the Kernel (sting_world_kernel): a clock winds, then the paged motif in B minor
	# on the celesta over low brass, the pulse on the tonic under the tag
	var wk := _shot(3.3)
	for k in 4:
		_at(wk, "tick" if k % 2 == 0 else "tock", 0.12 * k, 60.0, 0.05, -6.0 + 1.5 * k)
	for nt: Array in [[0.48, 83, 0.2], [0.7, 78, 0.2], [0.92, 86, 0.2], [1.14, 76, 0.2], [1.36, 90, 0.45], [1.84, 81, 0.4], [2.28, 95, 0.9]]:
		_at(wk, "celesta", nt[0], int(nt[1]) + 12, nt[2], -3.0)
		_at(wk, "brass_saw", nt[0], int(nt[1]) - 24, nt[2], -9.0)
	for t in [1.36, 2.28]:
		_at(wk, "bass_sat", t, 47.0, 0.3, -8.0)
	for m in [59, 62, 66]:
		_at(wk, "pad_dark", 2.28, m, 0.9, -13.0)
	_master_one("sting_world_kernel", wk, STING_LUFS)
	# glitch: the Glitch's entrance (Audio.sting("glitch")). The boss sting's tritone head, in B
	# (B -> F), whose held note is your own bug: it stutters, crushes and chirps
	var gs := _shot(2.6)
	var grev := D.reverse(_note("crash", 60.0, 1, 2))
	grev = D.slice(grev, grev.size() - D.n_of(500.0), D.n_of(500.0))
	D.fade_in(grev, 5.0, 6.0)
	D.mix_at(gs, grev, 0, D.db2lin(-6.0))
	_at(gs, "tom", 0.5, 41.0, 0.1, 0.0)
	_at(gs, "brass_saw", 0.5, 59, 0.3, -3.0)
	_at(gs, "brass_saw", 0.5, 47, 0.3, -5.0)
	var held := _shot(1.6)
	_at(held, "brass_saw", 0.0, 65, 1.45, -3.0)
	_at(held, "brass_saw", 0.0, 53, 1.45, -5.0)
	held = D.crush(D.stutter(held, 0.0, 70.0, 3), 3, 6.0, 0.45)
	D.mix_at(gs, held, int(roundf(0.82 * D.sr)), 1.0)
	_at(gs, "tom", 0.82, 38.0, 0.1, -3.0)
	for k in 4:
		_at(gs, "glitch", [0.82, 0.89, 0.96, 1.9][k], 60.0 + k, 0.05, -5.0)
	_at(gs, "glass_fm", 2.0, 95, 0.12, -10.0)
	_at(gs, "glass_fm", 2.1, 89, 0.3, -12.0)
	_master_one("sting_glitch", gs, STING_LUFS)
	_lap("stingers")


# ================================================================== ambience beds (stereo, 22.05 kHz, 20 s)

## A frequency whose cycles fit a 20 s loop exactly (a multiple of 0.05 Hz).
static func _snap(hz_: float) -> float:
	return roundf(hz_ * 20.0) / 20.0


## A periodic sum of sines (loop-exact frequencies).
func _tones(n: int, parts: Array) -> PackedFloat32Array:
	var y := D.zeros(n)
	for p: Array in parts:
		D.mix_at(y, D.sine(D.const_curve(_snap(p[0]), n), float(p[2]) if p.size() > 2 else 0.0), 0, D.db2lin(p[1]))
	return y


## A slow swell curve: 1 - depth·(0.5 + 0.5·sin), `cycles` whole cycles per loop.
func _breath(n: int, cycles: int, depth: float, phase: float) -> PackedFloat32Array:
	var y := D.zeros(n)
	for i in n:
		y[i] = 1.0 - depth * (0.5 + 0.5 * sin(TAU * (cycles * float(i) / n + phase)))
	return y


## A heartbeat swell: `cycles` whole beats per loop, each a 60 ms rise to full and a decay
## back to 1 - depth (continuous across the seam: the beat starts where the last one settled).
func _throb(n: int, cycles: int, depth: float) -> PackedFloat32Array:
	var y := D.zeros(n)
	var period := float(n) / cycles / D.sr
	for i in n:
		var t := fmod(float(cycles) * i / n, 1.0) * period
		var a := minf(1.0, t / 0.06)
		y[i] = 1.0 - depth + depth * a * a * (3.0 - 2.0 * a) * exp(-maxf(0.0, t - 0.06) / 0.3)
	return y


## Point events placed in both channels (panned) and wrapped into the loop.
func _events(l: PackedFloat32Array, r: PackedFloat32Array, src: PackedFloat32Array, at: int, pan: float, db: float) -> void:
	var g := D.pan_gains(pan)
	var k := D.db2lin(db)
	_mix_wrap(l, src, at, g.x * k)
	_mix_wrap(r, src, at, g.y * k)


func _ambience() -> void:
	var n := 20 * AMB_SR
	for area in ["cellar", "grove", "foundry", "kernel", "ring"]:
		_cue = "amb_" + area
		var ch: Array = []
		for c in 2:
			var r := D.rng_for(_cue, c, 0)
			var y := D.zeros(n)
			match area:
				"cellar":
					# a low draught that breathes, and a thin cold air above it
					var dr := _loopfx(D.noise(n, r, "brown"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "lp", 380.0, 0.7))
					D.mix_at(y, D.amp(dr, _breath(n, 2, 0.6, 0.37 * c)), 0, 1.0)
					var air := _loopfx(D.noise(n, r, "pink"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "bp", 900.0, 0.7))
					D.mix_at(y, D.amp(air, _breath(n, 1, 0.7, 0.5 + 0.2 * c)), 0, 0.12)
				"grove":
					# a hollow drone that breathes (C#, G#, C#), beating differently in each ear
					var sgn := -1.0 if c == 0 else 1.0
					var drone := _tones(n, [[69.30, -6.0], [69.30 + 0.1 * sgn, -8.0, 0.3], [103.85, -9.0], [138.60, -12.0], [138.60 + 0.15 * sgn, -14.0, 0.6], [277.20, -20.0]])
					drone = D.sat(drone, 1.5)
					D.mix_at(y, D.amp(drone, _breath(n, 3, 0.5, 0.25 * c)), 0, 0.5)
					var wind := _loopfx(D.noise(n, r, "pink"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "lp", 600.0, 0.7))
					D.mix_at(y, D.amp(wind, _breath(n, 1, 0.8, 0.6 * c)), 0, 0.25)
					var rustle := D.loop_wrap(D.grain(n + D.n_of(800.0), r, 5.0, 300.0, "noise", 2000.0, 4000.0), n)
					D.mix_at(y, rustle, 0, 0.08)
				"foundry":
					# the machine hum that never stops (F), the furnace's roar
					var sgn := -1.0 if c == 0 else 1.0
					var hum := _tones(n, [[43.65, -4.0], [87.30, -6.0, 0.2], [87.30 + 0.05 * sgn, -9.0], [130.95, -12.0], [174.60, -12.0, 0.5], [261.90, -18.0], [349.20, -20.0]])
					D.mix_at(y, D.sat(hum, 2.0), 0, 0.35)
					var roar := _loopfx(D.noise(n, r, "brown"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "bp", 350.0, 0.6))
					D.mix_at(y, D.amp(roar, _breath(n, 2, 0.5, 0.3 * c)), 0, 0.5)
				"kernel":
					# the Page Archive's hush: a low room tone that breathes, a dry paper air above
					# it, and the amber lamps' warm filament hum on B (beating apart in each ear)
					var sgn := -1.0 if c == 0 else 1.0
					var tone := _loopfx(D.noise(n, r, "brown"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "lp", 300.0, 0.7))
					D.mix_at(y, D.amp(tone, _breath(n, 1, 0.4, 0.3 * c)), 0, 0.8)
					var air := _loopfx(D.noise(n, r, "pink"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "bp", 2400.0, 0.5))
					D.mix_at(y, D.amp(air, _breath(n, 2, 0.6, 0.45 + 0.2 * c)), 0, 0.06)
					var lamp := _tones(n, [[123.45, -10.0], [246.9 + 0.1 * sgn, -14.0, 0.4], [370.35, -20.0], [493.8, -24.0, 0.2]])
					D.mix_at(y, D.amp(D.sat(lamp, 1.5), _breath(n, 4, 0.3, 0.1 * c)), 0, 0.12)
				"ring":
					# Ring Zero: the void's drone on B (B1 F#2 B2), beating apart in each ear, swelling
					# 16 times a loop (48 bpm) like the nest's heart; a brass circuit's hiss and
					# sparse crackle above it
					var sgn := -1.0 if c == 0 else 1.0
					var drone := _tones(n, [[61.75, -4.0], [61.75 + 0.1 * sgn, -7.0, 0.3], [92.5, -9.0], [123.5, -10.0],
						[123.5 + 0.15 * sgn, -13.0, 0.5], [185.0, -16.0], [247.0, -20.0]])
					D.mix_at(y, D.amp(D.sat(drone, 2.0), _throb(n, 16, 0.55)), 0, 0.4)
					var hiss := _loopfx(D.noise(n, r, "white"), func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf(x, "bp", 4200.0, 1.2))
					D.mix_at(y, D.amp(hiss, _breath(n, 3, 0.7, 0.2 + 0.3 * c)), 0, 0.025)
					var crackle := D.loop_wrap(D.grain(n + D.n_of(300.0), r, 2.0, 25.0, "noise", 3000.0, 6000.0), n)
					D.mix_at(y, crackle, 0, 0.05)
			ch.append(y)
		var l: PackedFloat32Array = ch[0]
		var rr: PackedFloat32Array = ch[1]
		# point sources, the same event in both ears at its own pan
		var er := D.rng_for(_cue, 9, 0)
		match area:
			"cellar":
				for k in 3:
					var st := D.modal("stone", er.randf_range(130.0, 210.0), 0.3, D.n_of(900.0), "mallet", er, 5)
					D.mix_at(st, D.amp(D.svf(D.noise(D.n_of(500.0), er, "brown"), "lp", 300.0, 0.7), D.aenv(5.0, 450.0, D.n_of(500.0))), 0, 0.6)
					_events(l, rr, st, int((0.12 + k * 0.33 + er.randf() * 0.1) * n), er.randf_range(-0.7, 0.7), -14.0)
			"foundry":
				for k in 3:
					var sm := _render("steam", 0.0, 1, er)
					var long := D.fit(sm, D.n_of(1200.0))
					_events(l, rr, long, int((0.2 + k * 0.3 + er.randf() * 0.08) * n), er.randf_range(-0.8, 0.8), -12.0)
			"kernel":
				# a far clock (tick, tock, once a second: 20 a loop, so the loop is exact) and
				# three pages settling somewhere in the stacks
				var far := er.randf_range(0.4, 0.6)
				for k in 20:
					var tk := D.svf(_render("tick" if k % 2 == 0 else "tock", 0.0, 1, er), "lp", 3000.0, 0.7)
					_events(l, rr, tk, k * AMB_SR, far, -22.0)
				for k in 3:
					var pg := D.grain(D.n_of(700.0), er, 70.0, 10.0, "noise", 1800.0, 4500.0, D.env([[0.0, 0.1, 0.0], [250.0, 1.0, 0.0], [700.0, 0.0, 0.0]], D.n_of(700.0)))
					_events(l, rr, pg, int((0.1 + k * 0.31 + er.randf() * 0.1) * n), er.randf_range(-0.8, 0.8), -16.0)
			"ring":
				# brass relays clicking over in the circuitry
				for k in 3:
					var rl := D.modal("brass", er.randf_range(1800.0, 2600.0), 0.25, D.n_of(600.0), "mallet", er, 4)
					_events(l, rr, rl, int((0.15 + k * 0.3 + er.randf() * 0.1) * n), er.randf_range(-0.8, 0.8), -20.0)
		var fx := func(x: PackedFloat32Array) -> PackedFloat32Array: return D.svf2(D.hp2(_room_half(x, 0.2), 40.0), "lp", 8000.0)
		l = _loopfx(l, fx)
		rr = _loopfx(rr, fx)
		_lap("render")
		_master_stereo("music_amb_" + area, l, rr, AMB_LUFS)
		_lap("master")


## Masters and saves a stereo loop (the beds): BS.1770 sums the channels' energy.
func _master_stereo(file: String, l: PackedFloat32Array, r: PackedFloat32Array, target: float) -> void:
	var h := _hops([_loopfx(l, _kw), _loopfx(r, _kw)], false)
	var lufs := _lufs_of(h, [1.0, 1.0])
	var k := pow(10.0, (target - lufs) / 20.0)
	var tp := maxf(_true_peak(l), _true_peak(r)) * k
	if tp > D.db2lin(TP_MAX):
		k *= D.db2lin(TP_MAX) / tp
	# mono check: the energy of L+R against the channels' summed energy (§3.11)
	var e_sum := 0.0
	var e_ch := 0.0
	for i in l.size():
		e_sum += (l[i] + r[i]) * (l[i] + r[i])
		e_ch += l[i] * l[i] + r[i] * r[i]
	var ll := l.duplicate()
	ll.append(l[0])
	var rg := r.duplicate()
	rg.append(r[0])
	D.save_wav_stereo(ll, rg, masters + file + ".wav", k, D.sr)
	_report.append("REPORT|%s|frames=%d|lufs=%.2f|tp=%.2f|mono_sum_db=%.2f" % [file, ll.size(), _lufs_of(h, [k, k]), D.lin2db(tp), 10.0 * log(e_sum / e_ch) / log(10.0)])
	_loops.append("LOOP|%s|loop_begin=0|loop_end=%d" % [file, l.size()])
