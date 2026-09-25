extends SceneTree
## D8: renders the music (design-plan §9) to game/assets/audio/music_*.wav and sting_*.wav.
## Run: tools/audio.sh   (godot --headless --path game -s <abs path to this file>)
##
## Every note is generated here, so the music is original and costs nothing (Bar's call on
## 2026-09-25: generated in code, no downloaded packs). A small subtractive and FM synth:
## band-limited saw and square (PolyBLEP), triangle, sine and a 2-operator FM bell; unison
## detune, ADSR, delayed vibrato and a one-pole low-pass per note; synthesized drums tuned
## for phone speakers (the kick's weight sits at 150-200 Hz, not below 60).
##
## Cues (style: chip leads for "code", warm pads for "arcane", glitch percussion):
##   title   96 bpm  D minor   one 24-bar loop: pads, arp, bass, then an FM-bell melody
##   shop    96 bpm  D minor   the title's harmony and pads without its melody, softer
##   cellar  120 bpm A minor   World 1 rooms 1-4, three stems: base (32 bars), drums (4),
##                             lead (16). Drums join in combat, the lead in elite rooms.
##   grove   120 bpm C# minor  the Corrupted Grove (rooms 5-8): the same stems, detuned,
##                             bit-crushed, phrygian
##   boss    128 bpm E minor   an intro (4 bars) that hands over to a 32-bar loop, and a
##                             phase-2 lead layer (8 bars) that switches in on the bar
##   stings  room clear, reward, boss intro, victory, defeat
##
## The sample rate is 32 kHz mono (a phone speaker has nothing above 16 kHz to give), and the
## tempos are chosen so a bar is a whole number of samples: 96 bpm = 80000, 120 = 64000,
## 128 = 60000. That is what lets a 4-bar drum stem loop under a 32-bar base without drift.
## Loops wrap their tails to the start, so every seam is click-free. Deterministic.

const SR := 32000
const OUT := "res://assets/audio/"
## One gain per cue brings the whole mix (every layer on) to this loudness (BS.1770).
const MUSIC_LUFS := -20.0
const STING_LUFS := -19.0
const PEAK := 0.84   # about -1.5 dBFS: headroom for true peaks and the bus limiter

var rng := RandomNumberGenerator.new()

const INST := {
	"pad": {"wave": "saw", "uni": 2, "det": 0.007, "a": 0.4, "d": 0.4, "s": 0.8, "r": 0.6, "lp": 1300.0, "vol": 0.03},
	"pad_dark": {"wave": "saw", "uni": 3, "det": 0.014, "a": 0.6, "d": 0.4, "s": 0.8, "r": 0.8, "lp": 900.0, "vol": 0.026, "wow": 0.004},
	"warm": {"wave": "tri", "uni": 2, "det": 0.004, "a": 0.25, "d": 0.3, "s": 0.8, "r": 0.5, "lp": 2400.0, "vol": 0.045},
	"bass": {"wave": "square", "duty": 0.25, "uni": 1, "a": 0.004, "d": 0.18, "s": 0.55, "r": 0.05, "lp": 1100.0, "vol": 0.07},
	"sub": {"wave": "tri", "uni": 1, "a": 0.004, "d": 0.2, "s": 0.8, "r": 0.05, "vol": 0.09},
	"arp": {"wave": "square", "duty": 0.125, "uni": 1, "a": 0.002, "d": 0.11, "s": 0.0, "r": 0.02, "lp": 4200.0, "vol": 0.028},
	"lead": {"wave": "square", "duty": 0.5, "uni": 1, "a": 0.01, "d": 0.2, "s": 0.7, "r": 0.08, "lp": 3600.0, "vol": 0.04,
		"vib": 0.18, "vib_rate": 5.5, "vib_delay": 0.18},
	"lead_thin": {"wave": "square", "duty": 0.25, "uni": 1, "a": 0.008, "d": 0.2, "s": 0.6, "r": 0.06, "lp": 4000.0, "vol": 0.036,
		"vib": 0.12, "vib_rate": 6.0, "vib_delay": 0.15},
	"bell": {"wave": "fm", "ratio": 3.5, "index": 2.2, "uni": 1, "a": 0.003, "d": 1.1, "s": 0.0, "r": 0.4, "vol": 0.05},
	"stab": {"wave": "saw", "uni": 3, "det": 0.01, "a": 0.004, "d": 0.35, "s": 0.2, "r": 0.2, "lp": 2200.0, "vol": 0.035},
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rng.seed = 2609
	var t0 := Time.get_ticks_msec()
	_cue({"title": _title()})
	_cue({"shop": _shop()})
	_cue({"cellar_base": _cellar_base(), "cellar_drums": _cellar_drums(), "cellar_lead": _cellar_lead()}, "cellar_base")
	_cue({"grove_base": _grove_base(), "grove_drums": _grove_drums(), "grove_lead": _grove_lead()}, "grove_base")
	_cue({"boss_intro": _boss_intro()})
	_cue({"boss_loop": _boss_loop(), "boss_p2": _boss_p2()}, "boss_loop")
	for s in ["clear", "reward", "boss", "victory", "defeat"]:
		var b: PackedFloat32Array = call("_sting_" + s)
		_normalize_save({"sting_" + s: b}, "sting_" + s, STING_LUFS, false)
	print("gen_music: done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


# ------------------------------------------------------------------ mixing and files

## Saves a cue's layers with one shared gain, measured on the full mix (shorter layers are
## tiled under the longest, as the game plays them).
func _cue(layers: Dictionary, main := "") -> void:
	var names: Array = layers.keys()
	_normalize_save(layers, names[0] if main == "" else main, MUSIC_LUFS, true)


func _normalize_save(layers: Dictionary, main: String, target: float, loop: bool) -> void:
	var long: PackedFloat32Array = layers[main]
	var mix := long.duplicate()
	for k in layers:
		if k == main:
			continue
		var b: PackedFloat32Array = layers[k]
		for i in mix.size():
			mix[i] += b[i % b.size()]
	for k in layers:
		_highpass(layers[k], 70.0, loop)
	_highpass(mix, 70.0, loop)
	var gain := pow(10.0, (target - Loudness.lufs(mix, SR)) / 20.0)
	var peak := 0.0001
	for v in mix:
		peak = maxf(peak, absf(v))
	gain = minf(gain, PEAK / peak)
	for k in layers:
		_save(layers[k], OUT + "%s.wav" % ("music_" + k if not k.begins_with("sting_") else k), gain, loop)


func _save(buf: PackedFloat32Array, path: String, gain: float, loop: bool) -> void:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, clampi(int(round(buf[i] * gain * 32767.0)), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	w.save_to_wav(path)


func _highpass(buf: PackedFloat32Array, hz: float, loop: bool) -> void:
	var a := exp(-TAU * hz / SR)
	var px := buf[buf.size() - 1] if loop else 0.0
	var py := 0.0
	for pass_i in (2 if loop else 1):
		for i in buf.size():
			var x := buf[i]
			py = a * (py + x - px)
			px = x
			if pass_i == (1 if loop else 0):
				buf[i] = py


static func blank(bars: int, bpm: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(round(bars * 4 * 60.0 / bpm * SR)))
	return b


# ------------------------------------------------------------------ the synth

static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## One note: `inst` from INST, `vel` 0..1. Tails past the end wrap when `wrap` is set.
func note(buf: PackedFloat32Array, t0: float, dur: float, midi: float, inst: Dictionary, vel := 1.0, wrap := true) -> void:
	var a: float = inst.get("a", 0.01)
	var d: float = inst.get("d", 0.1)
	var s: float = inst.get("s", 0.7)
	var r: float = inst.get("r", 0.05)
	var n_on := int(dur * SR)
	var n := n_on + int(r * SR)
	var start := int(t0 * SR)
	var size := buf.size()
	var wave: String = inst.get("wave", "square")
	var duty: float = inst.get("duty", 0.5)
	var uni: int = inst.get("uni", 1)
	var det: float = inst.get("det", 0.0)
	var vol: float = float(inst.get("vol", 0.05)) * vel
	var lp: float = inst.get("lp", 0.0)
	var a_lp := 1.0 - exp(-TAU * lp / SR) if lp > 0.0 else 1.0
	var vib: float = inst.get("vib", 0.0)
	var vib_rate: float = inst.get("vib_rate", 5.0)
	var vib_delay: float = inst.get("vib_delay", 0.2)
	var wow: float = inst.get("wow", 0.0)
	var ratio: float = inst.get("ratio", 2.0)
	var index: float = inst.get("index", 1.0)
	var f0 := mtof(midi)
	var na := maxf(1.0, a * SR)
	var nd := maxf(1.0, d * SR)
	for u in uni:
		var spread := 0.0 if uni == 1 else (float(u) / (uni - 1) * 2.0 - 1.0)
		var f := f0 * (1.0 + det * spread)
		var ph := rng.randf()
		var mph := 0.0
		var y := 0.0
		var level := 0.0
		for i in n:
			# ADSR (the release falls from wherever the envelope was)
			if i < n_on:
				if i < na:
					level = i / na
				elif i < na + nd:
					level = 1.0 - (1.0 - s) * ((i - na) / nd)
				else:
					level = s
			else:
				level *= 1.0 - 1.0 / maxf(1.0, r * SR * 0.25)
			var t := float(i) / SR
			var ff := f
			if vib > 0.0 and t > vib_delay:
				ff *= pow(2.0, vib * sin(TAU * vib_rate * (t - vib_delay)) / 12.0)
			if wow > 0.0:
				ff *= 1.0 + wow * sin(TAU * 0.7 * (t0 + t))
			var dph := ff / SR
			ph += dph
			ph -= floorf(ph)
			var v: float
			match wave:
				"saw":
					v = ph * 2.0 - 1.0 - _blep(ph, dph)
				"square":
					v = (1.0 if ph < duty else -1.0) + _blep(ph, dph) - _blep(fmod(ph + 1.0 - duty, 1.0), dph)
				"tri":
					v = 1.0 - absf(ph * 4.0 - 2.0)
				"fm":
					mph += dph * ratio
					mph -= floorf(mph)
					v = sin(TAU * ph + index * (level + 0.2) * sin(TAU * mph))
				_:
					v = sin(TAU * ph)
			y += a_lp * (v - y)
			var j := start + i
			if j >= size:
				if not wrap:
					break
				j %= size
			buf[j] += y * level * vol / sqrt(uni)


func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


## Filtered noise with an exponential decay: high-pass `hp` and/or low-pass `lp` (Hz).
func noise(buf: PackedFloat32Array, t0: float, d: float, vol: float, hp := 0.0, lp := 0.0, wrap := true, crush := 0) -> void:
	var n := int(d * SR)
	var start := int(t0 * SR)
	var size := buf.size()
	var a_lp := 1.0 - exp(-TAU * lp / SR) if lp > 0.0 else 1.0
	var a_hp := exp(-TAU * hp / SR) if hp > 0.0 else 0.0
	var y := 0.0
	var px := 0.0
	var hy := 0.0
	var held := 0.0
	for i in n:
		var x := rng.randf() * 2.0 - 1.0
		if crush > 0:
			if i % crush == 0:
				held = x
			x = held
		y += a_lp * (x - y)
		var v := y
		if hp > 0.0:
			hy = a_hp * (hy + v - px)
			px = v
			v = hy
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += v * pow(0.001, float(i) / n) * vol


## A pitch-swept sine (kicks, toms, risers).
func sweep(buf: PackedFloat32Array, t0: float, d: float, f_from: float, f_to: float, vol: float, wrap := true) -> void:
	var n := int(d * SR)
	var start := int(t0 * SR)
	var size := buf.size()
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += f_from * pow(f_to / f_from, k) / SR
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += sin(TAU * ph) * pow(0.001, k) * vol


# drums, tuned for a phone speaker
func kick(b: PackedFloat32Array, t: float, v := 1.0) -> void:
	sweep(b, t, 0.16, 180.0, 55.0, 0.34 * v)
	sweep(b, t, 0.05, 420.0, 160.0, 0.12 * v)
	noise(b, t, 0.01, 0.12 * v, 2500.0)


func snare(b: PackedFloat32Array, t: float, v := 1.0) -> void:
	noise(b, t, 0.16, 0.2 * v, 900.0, 9000.0)
	sweep(b, t, 0.08, 240.0, 180.0, 0.12 * v)


func hat(b: PackedFloat32Array, t: float, v := 1.0, open := false) -> void:
	noise(b, t, 0.12 if open else 0.035, 0.07 * v, 7000.0)


## Glitch percussion: a bit-crushed burst whose "sample rate" steps with the seed.
func glitch(b: PackedFloat32Array, t: float, v := 1.0) -> void:
	noise(b, t, 0.05, 0.11 * v, 1200.0, 0.0, true, 4 + rng.randi() % 10)


func crash(b: PackedFloat32Array, t: float, v := 1.0) -> void:
	noise(b, t, 1.2, 0.11 * v, 4000.0)


## A bit-crush over a whole buffer (the Corrupted Grove): hold every `hold` samples and
## quantize to `bits`, mixed in at `wet`.
static func crush(buf: PackedFloat32Array, hold: int, bits: int, wet: float) -> void:
	var q := pow(2.0, bits - 1)
	var held := 0.0
	for i in buf.size():
		if i % hold == 0:
			held = roundf(buf[i] * q) / q
		buf[i] = lerpf(buf[i], held, wet)


# ------------------------------------------------------------------ writing parts

## A melody: [[step (16ths), midi, length in 16ths], ...] from bar `at_bar`.
func melody(buf: PackedFloat32Array, bpm: float, at_bar: int, notes: Array, inst: Dictionary, vel := 1.0) -> void:
	var st := 60.0 / bpm / 4.0
	for n in notes:
		note(buf, (at_bar * 16 + int(n[0])) * st, float(n[2]) * st * 0.92, float(n[1]), inst, vel)


## Held chords, one per bar: `prog` is [[midi, midi, midi], ...] cycled over `bars`.
func pads(buf: PackedFloat32Array, bpm: float, bars: int, prog: Array, inst: Dictionary, vel := 1.0) -> void:
	var bar := 4 * 60.0 / bpm
	for b in bars:
		for m in prog[b % prog.size()]:
			note(buf, b * bar, bar * 0.96, float(m), inst, vel)


## A bass line from chord roots: `pattern` is 16 steps of "x" (root), "o" (octave), "5"
## (fifth), "." (rest). The sub doubles the root an octave down, quietly.
func bassline(buf: PackedFloat32Array, bpm: float, bars: int, roots: Array, pattern: String, from_bar := 0, vel := 1.0) -> void:
	var st := 60.0 / bpm / 4.0
	for b in range(from_bar, from_bar + bars):
		var r: int = roots[b % roots.size()]
		for i in 16:
			var c := pattern[i]
			if c == ".":
				continue
			var m := r + (12 if c == "o" else (7 if c == "5" else 0))
			note(buf, (b * 16 + i) * st, st * 1.6, m, INST["bass"], vel)
			if c == "x":
				note(buf, (b * 16 + i) * st, st * 1.6, m - 12, INST["sub"], vel * 0.6)


## A 16th-note arpeggio over each bar's chord, `order` indexing its notes (+12 above).
func arpeggio(buf: PackedFloat32Array, bpm: float, bars: int, prog: Array, order: Array, from_bar := 0, vel := 1.0, every := 1) -> void:
	var st := 60.0 / bpm / 4.0
	for b in range(from_bar, from_bar + bars):
		var ch: Array = prog[b % prog.size()]
		for i in range(0, 16, every):
			var k: int = order[(i / every) % order.size()]
			var m: int = ch[k % ch.size()] + 12 * (k / ch.size())
			note(buf, (b * 16 + i) * st, st * 0.9, m, INST["arp"], vel * (1.0 if i % 4 == 0 else 0.75))


## A drum pattern per bar: each string is 16 steps; kick "x", snare "x", hat "x" closed,
## "o" open, glitch "x"; `v` scales everything.
func drums(buf: PackedFloat32Array, bpm: float, bars: int, k: String, s: String, h: String, g := "", from_bar := 0, v := 1.0) -> void:
	var st := 60.0 / bpm / 4.0
	for b in range(from_bar, from_bar + bars):
		for i in 16:
			var t := (b * 16 + i) * st
			if k[i] == "x":
				kick(buf, t, v)
			if s[i] == "x":
				snare(buf, t, v)
			if h[i] == "x":
				hat(buf, t, v * (1.0 if i % 4 == 0 else 0.7))
			elif h[i] == "o":
				hat(buf, t, v, true)
			if g != "" and g[i] == "x":
				glitch(buf, t, v)


# ------------------------------------------------------------------ title and shop (D minor, 96 bpm)

const T_BPM := 96.0
## Dm Bb F C | Dm Bb F A (the A turns back to Dm)
const T_PROG := [[62, 65, 69], [62, 65, 70], [60, 65, 69], [60, 64, 67], [62, 65, 69], [62, 65, 70], [60, 65, 69], [61, 64, 69]]
const T_ROOTS := [38, 34, 41, 36, 38, 34, 41, 33]
## The motif (8 bars), an FM bell.
const T_MELODY := [
	[0, 69, 4], [4, 74, 4], [8, 77, 6], [14, 76, 2],
	[16, 74, 4], [20, 72, 2], [22, 74, 2], [24, 70, 8],
	[32, 69, 4], [36, 72, 4], [40, 77, 4], [44, 81, 4],
	[48, 79, 6], [54, 77, 2], [56, 76, 4], [60, 72, 4],
	[64, 74, 8], [72, 69, 4], [76, 74, 4],
	[80, 77, 6], [86, 76, 2], [88, 74, 4], [92, 77, 4],
	[96, 81, 8], [104, 79, 4], [108, 77, 4],
	[112, 76, 6], [118, 74, 2], [120, 73, 8],
]


func _title() -> PackedFloat32Array:
	var b := blank(24, T_BPM)
	pads(b, T_BPM, 24, T_PROG, INST["pad"])
	bassline(b, T_BPM, 24, T_ROOTS, "x.......x...o...")
	arpeggio(b, T_BPM, 24, T_PROG, [0, 1, 2, 3, 2, 1], 0, 0.8, 2)
	# the motif enters at bar 8, then again an octave-doubled variation at bar 16
	melody(b, T_BPM, 8, T_MELODY, INST["bell"])
	melody(b, T_BPM, 16, T_MELODY, INST["bell"], 0.8)
	melody(b, T_BPM, 16, T_MELODY.map(func(n: Array) -> Array: return [n[0], n[1] - 12, n[2]]), INST["lead_thin"], 0.35)
	drums(b, T_BPM, 8, "x.......x.......", "................", "..x...x...x...x.", "", 16, 0.6)
	return b


func _shop() -> PackedFloat32Array:
	# the title's harmony and pads with a walking bass and a light shaker, no melody
	var b := blank(16, T_BPM)
	pads(b, T_BPM, 16, T_PROG, INST["warm"], 0.9)
	bassline(b, T_BPM, 16, T_ROOTS, "x...5...o...5...", 0, 0.8)
	arpeggio(b, T_BPM, 16, T_PROG, [2, 1, 0, 1], 0, 0.5, 4)
	drums(b, T_BPM, 16, "x.......x.......", "................", "x.x.x.x.x.x.x.x.", "", 0, 0.35)
	return b


# ------------------------------------------------------------------ World 1: the Cellar (A minor, 120 bpm)

const W_BPM := 120.0
## Am F C G | Am F Dm E
const C_PROG := [[69, 72, 76], [69, 72, 77], [67, 72, 76], [67, 71, 74], [69, 72, 76], [69, 72, 77], [69, 74, 77], [68, 71, 76]]
const C_ROOTS := [45, 41, 36, 43, 45, 41, 38, 40]
const C_LEAD := [
	[0, 69, 2], [2, 72, 2], [4, 76, 4], [8, 74, 2], [10, 72, 2], [12, 71, 2], [14, 72, 2],
	[16, 69, 6], [22, 72, 2], [24, 77, 4], [28, 76, 4],
	[32, 79, 4], [36, 76, 2], [38, 72, 2], [40, 76, 4], [44, 79, 4],
	[48, 74, 6], [54, 71, 2], [56, 74, 4], [60, 79, 4],
	[64, 81, 4], [68, 79, 2], [70, 76, 2], [72, 81, 4], [76, 84, 4],
	[80, 81, 6], [86, 79, 2], [88, 77, 4], [92, 81, 4],
	[96, 77, 4], [100, 76, 2], [102, 74, 2], [104, 77, 4], [108, 81, 4],
	[112, 80, 6], [118, 76, 2], [120, 71, 4], [124, 68, 4],
]


func _cellar_base() -> PackedFloat32Array:
	var b := blank(32, W_BPM)
	pads(b, W_BPM, 32, C_PROG, INST["pad"])
	bassline(b, W_BPM, 32, C_ROOTS, "x.x.o.x.x.x.o.5.")
	# the arp thins out in the second half of each 16 bars so the lead has room
	arpeggio(b, W_BPM, 8, C_PROG, [0, 1, 2, 3, 2, 1, 0, 2], 0, 0.9)
	arpeggio(b, W_BPM, 8, C_PROG, [0, 2, 1, 3], 8, 0.7, 2)
	arpeggio(b, W_BPM, 8, C_PROG, [0, 1, 2, 3, 2, 1, 0, 2], 16, 0.9)
	arpeggio(b, W_BPM, 8, C_PROG, [2, 1, 0, 1], 24, 0.7, 2)
	return b


func _cellar_drums() -> PackedFloat32Array:
	var b := blank(4, W_BPM)
	drums(b, W_BPM, 3, "x.....x.x.......", "....x.......x...", "x.x.x.x.x.x.x.x.", "...........x....")
	drums(b, W_BPM, 1, "x.....x.x.....x.", "....x.......x.xx", "x.x.x.x.x.x.x.o.", "...x.......x...x", 3)
	return b


func _cellar_lead() -> PackedFloat32Array:
	var b := blank(16, W_BPM)
	melody(b, W_BPM, 0, C_LEAD, INST["lead"])
	# the answer: the same phrase with the last bar turned home to A
	var answer: Array = C_LEAD.slice(0, C_LEAD.size() - 4) + [[112, 76, 4], [116, 72, 4], [120, 69, 8]]
	melody(b, W_BPM, 8, answer, INST["lead"])
	return b


# ------------------------------------------------------------------ the Corrupted Grove (C# minor, 120 bpm)

## C#m D C#m B | A D B C# (phrygian: the flat second, D, is the corruption)
const G_PROG := [[68, 73, 76], [69, 74, 78], [68, 73, 76], [66, 71, 75], [69, 73, 76], [69, 74, 78], [66, 71, 75], [68, 73, 77]]
const G_ROOTS := [37, 38, 37, 35, 45, 38, 35, 37]
const G_LEAD := [
	[0, 68, 4], [4, 73, 4], [8, 74, 2], [10, 73, 2], [12, 68, 4],
	[16, 69, 4], [20, 74, 4], [24, 78, 6], [30, 76, 2],
	[32, 76, 4], [36, 74, 2], [38, 73, 2], [40, 71, 4], [44, 73, 4],
	[48, 75, 6], [54, 78, 2], [56, 71, 8],
	[64, 73, 4], [68, 76, 4], [72, 81, 6], [78, 80, 2],
	[80, 78, 4], [84, 81, 2], [86, 78, 2], [88, 74, 8],
	[96, 75, 4], [100, 78, 4], [104, 83, 4], [108, 81, 4],
	[112, 80, 8], [120, 77, 4], [124, 73, 4],
]


func _grove_base() -> PackedFloat32Array:
	var b := blank(32, W_BPM)
	pads(b, W_BPM, 32, G_PROG, INST["pad_dark"])
	bassline(b, W_BPM, 32, G_ROOTS, "x..x..x.x..x.o..")
	arpeggio(b, W_BPM, 16, G_PROG, [0, 2, 1, 3, 1, 2], 0, 0.7, 2)
	arpeggio(b, W_BPM, 16, G_PROG, [0, 1, 2, 4, 2, 1, 0, 1], 16, 0.8)
	crush(b, 3, 7, 0.35)
	return b


func _grove_drums() -> PackedFloat32Array:
	var b := blank(4, W_BPM)
	drums(b, W_BPM, 3, "x.....x...x.....", "....x.......x...", "x.xxx.x.x.xxx.x.", "..x....x.x....x.")
	drums(b, W_BPM, 1, "x.....x...x...x.", "....x.......xxxx", "x.xxx.x.x.xxx.o.", "..x.x..x.x.xx..x", 3)
	crush(b, 4, 6, 0.5)
	return b


func _grove_lead() -> PackedFloat32Array:
	var b := blank(16, W_BPM)
	melody(b, W_BPM, 0, G_LEAD, INST["lead_thin"])
	# the second pass stutters: every long note breaks into 16ths, like a skipping record
	var stutter: Array = []
	for n in G_LEAD:
		if int(n[2]) >= 6:
			for k in 4:
				stutter.append([int(n[0]) + k, n[1], 1])
			stutter.append([int(n[0]) + 4, n[1], int(n[2]) - 4])
		else:
			stutter.append(n)
	melody(b, W_BPM, 8, stutter, INST["lead_thin"])
	crush(b, 3, 6, 0.4)
	return b


# ------------------------------------------------------------------ the boss (E minor, 128 bpm)

const B_BPM := 128.0
## Em C D B | Em C Am B
const B_PROG := [[64, 67, 71], [64, 67, 72], [66, 69, 74], [66, 71, 75], [64, 67, 71], [64, 67, 72], [64, 69, 72], [63, 66, 71]]
const B_ROOTS := [40, 36, 38, 35, 40, 36, 33, 35]
const B_LEAD := [
	[0, 76, 2], [2, 79, 2], [4, 83, 4], [8, 81, 2], [10, 79, 2], [12, 78, 2], [14, 79, 2],
	[16, 76, 4], [20, 72, 2], [22, 76, 2], [24, 79, 4], [28, 76, 4],
	[32, 78, 4], [36, 81, 4], [40, 86, 4], [44, 81, 4],
	[48, 87, 6], [54, 83, 2], [56, 78, 4], [60, 75, 4],
	[64, 88, 4], [68, 86, 2], [70, 83, 2], [72, 79, 4], [76, 83, 4],
	[80, 84, 6], [86, 83, 2], [88, 79, 4], [92, 76, 4],
	[96, 81, 4], [100, 84, 4], [104, 88, 4], [108, 84, 4],
	[112, 83, 8], [120, 87, 4], [124, 90, 4],
]


func _boss_intro() -> PackedFloat32Array:
	var b := blank(4, B_BPM)
	var st := 60.0 / B_BPM / 4.0
	# two bars of stabs on a B pedal under a riser, then a drum fill into the loop
	for i in range(0, 32, 4):
		note(b, i * st, st * 2.0, 47, INST["bass"], 1.0, false)
		note(b, i * st, st * 2.0, 35, INST["sub"], 0.6, false)
		if i % 8 == 0:
			for m in [59, 63, 66]:
				note(b, i * st, st * 3.0, m, INST["stab"], 0.8, false)
	sweep(b, 0.0, 32 * st, 200.0, 1200.0, 0.05, false)
	noise(b, 16 * st, 16 * st, 0.05, 1500.0, 0.0, false)
	for i in range(32, 64):
		if i < 48 and i % 2 == 1:
			continue
		snare(b, i * st, 0.4 + 0.6 * (i - 32) / 32.0)
	for i in range(32, 64, 4):
		kick(b, i * st)
	return b


func _boss_loop() -> PackedFloat32Array:
	var b := blank(32, B_BPM)
	pads(b, B_BPM, 32, B_PROG, INST["stab"], 0.7)
	bassline(b, B_BPM, 32, B_ROOTS, "xxoxxxoxxxoxxo5o")
	arpeggio(b, B_BPM, 8, B_PROG, [0, 1, 2, 3], 8, 0.8)
	arpeggio(b, B_BPM, 8, B_PROG, [0, 1, 2, 3, 4, 3, 2, 1], 16, 0.9)
	arpeggio(b, B_BPM, 8, B_PROG, [2, 1, 0, 1], 24, 0.7, 2)
	drums(b, B_BPM, 8, "x.......x.......", "....x.......x...", "x.x.x.x.x.x.x.x.", "", 0, 0.8)
	drums(b, B_BPM, 16, "x.x...x.x.x...x.", "....x.......x...", "xxxxxxxxxxxxxxxx", "..........x....x", 8)
	drums(b, B_BPM, 7, "x.......x.......", "....x.......x...", "x.x.x.x.x.x.x.x.", "", 24, 0.8)
	drums(b, B_BPM, 1, "x.x.x.x.x.x.x.x.", "....x...x.x.xxxx", "xxxxxxxxxxxxxxox", "", 31)
	for bar in [0, 8, 16, 24]:
		crash(b, bar * 16 * st_of(B_BPM))
	return b


func _boss_p2() -> PackedFloat32Array:
	var b := blank(8, B_BPM)
	melody(b, B_BPM, 0, B_LEAD, INST["lead"], 0.9)
	melody(b, B_BPM, 0, B_LEAD.map(func(n: Array) -> Array: return [n[0], n[1] - 12, n[2]]), INST["lead_thin"], 0.35)
	return b


static func st_of(bpm: float) -> float:
	return 60.0 / bpm / 4.0


# ------------------------------------------------------------------ stingers

func _sting_clear() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(1.8 * SR))
	var st := 0.07
	for k in 4:
		note(b, k * st, st * 1.5, [69, 73, 76, 81][k], INST["arp"], 1.2, false)
	for m in [69, 73, 76, 81]:
		note(b, 4 * st, 0.8, m, INST["bell"], 0.6, false)
	return b


func _sting_reward() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(2.4 * SR))
	var st := 0.055
	var run := [74, 76, 78, 81, 83, 86, 88, 90]
	for k in run.size():
		note(b, k * st, st * 2.0, run[k], INST["bell"], 0.7, false)
	for m in [74, 78, 81, 86]:
		note(b, run.size() * st, 1.3, m, INST["warm"], 0.8, false)
	return b


func _sting_boss() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(3.0 * SR))
	kick(b, 0.0, 1.4)
	crash(b, 0.0, 1.2)
	for m in [40, 52, 55, 59]:
		note(b, 0.0, 1.6, m, INST["stab"], 1.2, false)
	note(b, 0.0, 2.2, 65, INST["bell"], 0.6, false)   # the flat second, a warning
	note(b, 0.0, 2.2, 28 + 12, INST["sub"], 0.8, false)
	return b


func _sting_victory() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(5.0 * SR))
	var st := 60.0 / 120.0 / 4.0
	var fan := [[0, 74, 2], [2, 78, 2], [4, 81, 4], [8, 79, 2], [10, 81, 2], [12, 83, 4], [16, 86, 12]]
	for n in fan:
		note(b, int(n[0]) * st, int(n[2]) * st * 0.95, n[1], INST["lead"], 1.0, false)
	for c in [[0, [62, 66, 69]], [8, [67, 71, 74]], [16, [62, 66, 69, 74]]]:
		for m in c[1]:
			note(b, int(c[0]) * st, 8 * st if int(c[0]) < 16 else 2.2, m, INST["pad"], 1.2, false)
	for i in [0, 4, 8, 12, 16]:
		kick(b, i * st)
	snare(b, 12 * st)
	crash(b, 16 * st)
	return b


func _sting_defeat() -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(4.0 * SR))
	var line := [[0.0, 69], [0.45, 67], [0.95, 65], [1.55, 64], [2.25, 62]]
	for n in line:
		note(b, n[0], 0.6 if n[1] != 62 else 1.4, n[1], INST["warm"], 1.0, false)
	for m in [50, 53, 57]:
		note(b, 2.25, 1.5, m, INST["pad_dark"], 1.2, false)
	return b
