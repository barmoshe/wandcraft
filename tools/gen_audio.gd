extends SceneTree
## Renders every sound effect and music loop to game/assets/audio/*.wav.
## Run: tools/audio.sh   (godot --headless --path game -s <abs path to this file>)
##
## A small software synth: oscillators (square, saw, triangle, sine) with an exponential
## pitch slide and an exponential decay, and filtered noise. It is a port of our own
## prototype synth (Wandcraft v5, 35-audio.js), so every sound is original. Output is
## deterministic: the same code always writes the same bytes.

const SR := 22050
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rng.seed = 1337
	var n := 0
	for name in SFX:
		var buf := _render_sfx(SFX[name])
		_save(buf, OUT + "sfx_%s.wav" % name)
		n += 1
	for name in SONGS:
		_save(_render_song(SONGS[name]), OUT + "music_%s.wav" % name)
		n += 1
	print("gen_audio: wrote %d files to %s" % [n, OUT])
	quit()


# ------------------------------------------------------------------ primitives

## Adds a decaying oscillator into buf starting at t0 (seconds). When wrap is true the tail
## wraps around to the start (for seamless music loops).
func tone(buf: PackedFloat32Array, t0: float, f: float, d: float, type: String, vol: float, slide := 0.0, wrap := false) -> void:
	var n := int(d * SR)
	var start := int(t0 * SR)
	var ph := 0.0
	var f_end := maxf(20.0, f * slide) if slide > 0.0 else f
	var size := buf.size()
	for i in n:
		var k := float(i) / n
		var freq := f * pow(f_end / f, k)
		ph += freq / SR
		ph -= floorf(ph)
		var s: float
		match type:
			"square":
				s = 1.0 if ph < 0.5 else -1.0
			"sawtooth":
				s = ph * 2.0 - 1.0
			"triangle":
				s = 1.0 - absf(ph * 4.0 - 2.0)
			_:
				s = sin(ph * TAU)
		# 3 ms attack, then an exponential fall to -80 dB at the end
		var env := minf(1.0, i / (0.003 * SR)) * pow(0.0001, k)
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += s * env * vol


## Filtered noise burst: one-pole high-pass (hp Hz) or low-pass (lp Hz).
func noise(buf: PackedFloat32Array, t0: float, d: float, vol: float, hp := 800.0, lp := 0.0, wrap := false) -> void:
	var n := int(d * SR)
	var start := int(t0 * SR)
	var size := buf.size()
	var a_lp := 1.0 - exp(-TAU * lp / SR) if lp > 0.0 else 0.0
	var a_hp := exp(-TAU * hp / SR)
	var y := 0.0
	var prev_x := 0.0
	var prev_y := 0.0
	for i in n:
		var x := rng.randf() * 2.0 - 1.0
		if lp > 0.0:
			y += a_lp * (x - y)
		else:
			# high-pass: y[n] = a * (y[n-1] + x[n] - x[n-1])
			y = a_hp * (prev_y + x - prev_x)
			prev_x = x
			prev_y = y
		var k := float(i) / n
		var env := pow(0.0001, k)
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += y * env * vol


func _save(buf: PackedFloat32Array, path: String) -> void:
	# normalise gently (never boost quiet sounds by more than 2x), then 16-bit PCM
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := minf(2.0, 0.9 / peak)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		var s := clampi(int(round(buf[i] * gain * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	w.save_to_wav(path)


# ------------------------------------------------------------------ sound effects
# Each entry: [length s, [[kind, t0, args...], ...]]
#   ["t", t0, freq, dur, type, vol, slide]    ["n", t0, dur, vol, hp, lp]

const SFX := {
	# casts
	"cast_spark": [0.08, [["t", 0, 1150, 0.06, "square", 0.016, 0.45]]],
	"cast_laser": [0.1, [["t", 0, 1800, 0.07, "sawtooth", 0.02, 0.4]]],
	"cast_fan": [0.2, [["t", 0, 700, 0.08, "triangle", 0.02, 1.2], ["t", 0.03, 900, 0.08, "triangle", 0.02, 1.2], ["t", 0.06, 1100, 0.08, "triangle", 0.02, 1.2]]],
	"cast_missile": [0.14, [["t", 0, 500, 0.12, "sawtooth", 0.02, 1.8]]],
	"cast_fire": [0.2, [["n", 0, 0.14, 0.04, 500, 0], ["t", 0, 220, 0.18, "sawtooth", 0.03, 0.6]]],
	"cast_ice": [0.1, [["t", 0, 1600, 0.08, "triangle", 0.03, 0.6]]],
	"cast_chain": [0.1, [["t", 0, 1500, 0.07, "square", 0.025, 0.3], ["n", 0, 0.05, 0.02, 4000, 0]]],
	"cast_orbit": [0.22, [["t", 0, 660, 0.2, "triangle", 0.04, 1.5]]],
	"cast_boom": [0.3, [["n", 0, 0.25, 0.07, 0, 1200], ["t", 0, 120, 0.25, "sine", 0.09, 0.4]]],
	"trigger": [0.1, [["t", 0, 990, 0.05, "square", 0.02, 1.5], ["t", 0.04, 1480, 0.05, "square", 0.015, 1.2]]],
	# combat
	"hit": [0.06, [["n", 0, 0.05, 0.035, 1800, 0]]],
	"crit": [0.1, [["n", 0, 0.08, 0.06, 1200, 0], ["t", 0, 1800, 0.08, "square", 0.03, 0.5]]],
	"kill": [0.14, [["t", 0, 340, 0.12, "square", 0.03, 0.4], ["n", 0, 0.08, 0.03, 1500, 0]]],
	"boom": [0.4, [["n", 0, 0.35, 0.09, 0, 900], ["t", 0, 90, 0.3, "sine", 0.12, 0.4]]],
	"bigboom": [0.9, [["n", 0, 0.8, 0.14, 0, 600], ["t", 0, 60, 0.8, "sine", 0.18, 0.3]]],
	"hurt": [0.32, [["t", 0, 160, 0.3, "sawtooth", 0.07, 0.4], ["n", 0, 0.2, 0.07, 400, 0]]],
	"eshot": [0.08, [["t", 0, 280, 0.07, "sawtooth", 0.02, 0.6]]],
	"tele": [0.5, [["t", 0, 420, 0.5, "triangle", 0.05, 1.9]]],
	"phase": [1.0, [["n", 0, 0.8, 0.1, 200, 0], ["t", 0, 80, 1.0, "sawtooth", 0.1, 2.5]]],
	"spawn": [0.25, [["t", 0, 300, 0.22, "triangle", 0.03, 2.2]]],
	"burn": [0.12, [["n", 0, 0.1, 0.03, 0, 1500]]],
	"freeze": [0.2, [["t", 0, 2000, 0.2, "triangle", 0.04, 0.5]]],
	"crate": [0.15, [["n", 0, 0.12, 0.05, 0, 2500], ["t", 0, 180, 0.08, "square", 0.03, 0.6]]],
	# rewards and world
	"coin": [0.07, [["t", 0, 1320, 0.06, "square", 0.025, 1.4]]],
	"pick": [0.32, [["t", 0, 660, 0.1, "square", 0.03, 0], ["t", 0.08, 880, 0.1, "square", 0.03, 0], ["t", 0.16, 1175, 0.14, "square", 0.03, 0]]],
	"door": [0.6, [["t", 0, 200, 0.6, "triangle", 0.06, 2.0]]],
	"heal": [0.4, [["t", 0, 523, 0.14, "triangle", 0.04, 0], ["t", 0.1, 659, 0.14, "triangle", 0.04, 0], ["t", 0.2, 784, 0.18, "triangle", 0.04, 0]]],
	"levelup": [0.6, [["t", 0, 440, 0.18, "square", 0.04, 0], ["t", 0.08, 554, 0.18, "square", 0.04, 0], ["t", 0.16, 659, 0.18, "square", 0.04, 0], ["t", 0.24, 880, 0.3, "square", 0.04, 0]]],
	"win": [1.2, [["t", 0, 523.25, 0.35, "triangle", 0.07, 0], ["t", 0.14, 659.25, 0.35, "triangle", 0.07, 0], ["t", 0.28, 783.99, 0.35, "triangle", 0.07, 0], ["t", 0.42, 1046.5, 0.7, "triangle", 0.07, 0]]],
	"lose": [1.2, [["t", 0, 392, 0.4, "triangle", 0.07, 0.9], ["t", 0.3, 330, 0.4, "triangle", 0.07, 0.9], ["t", 0.6, 262, 0.6, "triangle", 0.07, 0.8]]],
	# ui
	"ui": [0.05, [["t", 0, 900, 0.04, "square", 0.02, 0]]],
	"ui_back": [0.06, [["t", 0, 600, 0.05, "square", 0.02, 0.7]]],
	"swap": [0.06, [["t", 0, 500, 0.05, "square", 0.03, 1.5]]],
	"deny": [0.08, [["t", 0, 180, 0.06, "square", 0.03, 0]]],
}


func _render_sfx(def: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int((float(def[0]) + 0.02) * SR))
	for p in def[1]:
		if p[0] == "t":
			tone(buf, p[1], p[2], p[3], p[4], p[5], p[6])
		else:
			noise(buf, p[1], p[2], p[3], p[4], p[5])
	return buf


# ------------------------------------------------------------------ music
# Chiptune loops: a 4-chord progression, 16 steps per bar, 16 bars (the lead pattern
# changes every 4 bars so the loop is not obviously short). Tails wrap, so it loops clean.

const SONGS := {
	"title": {"bpm": 92, "lead": "sine", "boss": false,
		"prog": [[123.47, [493.88, 587.33, 739.99]], [98.0, [392.0, 493.88, 587.33]], [110.0, [440.0, 554.37, 659.25]], [92.5, [369.99, 440.0, 554.37]]]},
	"grove": {"bpm": 112, "lead": "triangle", "boss": false,
		"prog": [[110.0, [440.0, 523.25, 659.25]], [87.31, [349.23, 440.0, 523.25]], [98.0, [392.0, 493.88, 587.33]], [82.41, [329.63, 392.0, 493.88]]]},
	"boss": {"bpm": 132, "lead": "square", "boss": true,
		"prog": [[110.0, [440.0, 523.25, 622.25]], [116.54, [466.16, 587.33, 698.46]], [103.83, [415.3, 523.25, 622.25]], [82.41, [415.3, 493.88, 659.25]]]},
}

const PATTERNS := [[0, 1, 2, 1, 2, 1], [0, 2, 1, 2, 0, 2], [2, 1, 0, 1, 2, 0], [0, 1, 2, 2, 1, 0]]


func _render_song(s: Dictionary) -> PackedFloat32Array:
	var step := 60.0 / float(s["bpm"]) / 4.0
	var bars := 16
	var total := bars * 16
	var buf := PackedFloat32Array()
	buf.resize(int(total * step * SR))
	var boss: bool = s["boss"]
	for st in total:
		var t := st * step
		var bar := (st / 16) % 4
		var round_i := st / 64
		var i := st % 16
		var chord: Array = s["prog"][bar]
		var root: float = chord[0]
		var notes: Array = chord[1]
		# bass
		if i % 4 == 0 or (boss and i % 2 == 0):
			tone(buf, t, root, step * 3.0, "triangle", 0.13, 0.0, true)
		# arpeggio lead, the pattern changes each pass
		var pat: Array = PATTERNS[round_i % PATTERNS.size()]
		var f: float = notes[pat[i % 6]] * (2.0 if i >= 8 and round_i % 2 == 1 else 1.0)
		if not (round_i == 0 and i % 2 == 1 and not boss):
			tone(buf, t, f, step * 1.5, String(s["lead"]), 0.018 if boss else 0.03, 0.0, true)
		# hat and kick
		if i % 8 == 4:
			noise(buf, t, 0.08, 0.04, 3000.0, 0.0, true)
		if boss and i % 4 == 0:
			tone(buf, t, 140.0, 0.1, "sine", 0.12, 0.3, true)
		if not boss and i % 8 == 0:
			tone(buf, t, root / 2.0, 0.12, "sine", 0.08, 0.5, true)
	return buf
