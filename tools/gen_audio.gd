extends SceneTree
## Renders every sound effect to game/assets/audio/sfx_*.wav (the music is gen_music.gd).
## Run: tools/audio.sh   (godot --headless --path game -s <abs path to this file>)
##
## A small software synth: oscillators (square, saw, triangle, sine) with an exponential
## pitch slide and an exponential decay, filtered noise, a 2-operator FM bell, a reversed
## swell and a crackle. It began as a port of our own prototype synth (Wandcraft v5,
## 35-audio.js), so every sound is original. Deterministic: the same code writes the same bytes.
##
## D0 audio pass: 44.1 kHz, band-limited square and saw (PolyBLEP), bass and booms moved into
## what a phone speaker can play, a seamless 80 Hz high-pass on every file.
## D8 (design-plan §9): about 80 sounds, most built from a transient, a body and a tail; one
## timbre per element (fire: noise and saw; ice: a glassy tink; static: crackle; arcane: an FM
## bell; void: a reversed swell); telegraph cues that rise into their release; the sounds
## heard most get three variants (their own noise seed, pitch 1.0 / 1.04 / 0.96) that the game
## plays through an AudioStreamRandomizer; every file is normalised to a BS.1770 loudness
## target (Loudness.lufs) under a -1.5 dBFS peak ceiling.

const SR := 44100
## Integrated loudness per family (LUFS). The whole game sits around -18, UI well under it.
const TARGET_LUFS := {"sfx": -18.0, "ui": -24.0}
const PEAK := 0.84
const UI_SOUNDS := ["ui", "ui_back", "swap", "deny", "coin", "ui_open", "ui_close", "ui_equip", "ui_drag", "ui_drop", "buy"]
## Sounds rendered in three variants (sfx_x.wav, sfx_x_2.wav, sfx_x_3.wav).
const VARIANTS := ["hit", "crit", "kill", "kill_mid", "hurt", "eshot", "cast_spark", "cast_laser", "cast_fire", "cast_ice",
	"cast_static", "cast_arcane", "cast_boom", "hit_fire", "hit_ice", "hit_static", "hit_arcane", "hit_armor", "coin", "crate"]
const OUT := "res://assets/audio/"

var rng := RandomNumberGenerator.new()
var _pitch := 1.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var n := 0
	for name in SFX:
		var family := "ui" if name in UI_SOUNDS else "sfx"
		for v in (3 if name in VARIANTS else 1):
			# each sound and variant has its own noise seed, so adding a sound never changes
			# another one
			rng.seed = hash(name) + v * 7919
			_pitch = [1.0, 1.04, 0.96][v]
			_save(_render_sfx(SFX[name]), OUT + "sfx_%s%s.wav" % [name, "" if v == 0 else "_%d" % (v + 1)], family)
			n += 1
	print("gen_audio: wrote %d files to %s" % [n, OUT])
	quit()


# ------------------------------------------------------------------ primitives

## A decaying oscillator from t0 (seconds): 3 ms attack, then an exponential fall to -80 dB.
func tone(buf: PackedFloat32Array, t0: float, f: float, d: float, type: String, vol: float, slide := 0.0) -> void:
	f *= _pitch
	var n := int(d * SR)
	var start := int(t0 * SR)
	var ph := 0.0
	var f_end := maxf(20.0, f * slide) if slide > 0.0 else f
	for i in n:
		var k := float(i) / n
		var dph := f * pow(f_end / f, k) / SR
		ph += dph
		ph -= floorf(ph)
		var s: float
		match type:
			"square":
				s = (1.0 if ph < 0.5 else -1.0) + _blep(ph, dph) - _blep(fmod(ph + 0.5, 1.0), dph)
			"sawtooth":
				s = ph * 2.0 - 1.0 - _blep(ph, dph)
			"triangle":
				s = 1.0 - absf(ph * 4.0 - 2.0)
			_:
				s = sin(ph * TAU)
		var j := start + i
		if j >= buf.size():
			break
		buf[j] += s * minf(1.0, i / (0.003 * SR)) * pow(0.0001, k) * vol


## PolyBLEP: smooths the jump of a square or saw wave over one sample, so high notes do
## not alias into harsh inharmonic whistles.
func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


## Filtered noise burst: one-pole low-pass (lp Hz) if given, otherwise high-pass (hp Hz).
func noise(buf: PackedFloat32Array, t0: float, d: float, vol: float, hp := 800.0, lp := 0.0) -> void:
	var n := int(d * SR)
	var start := int(t0 * SR)
	var a_lp := 1.0 - exp(-TAU * lp / SR) if lp > 0.0 else 0.0
	var a_hp := exp(-TAU * hp / SR)
	var y := 0.0
	var px := 0.0
	var py := 0.0
	for i in n:
		var x := rng.randf() * 2.0 - 1.0
		if lp > 0.0:
			y += a_lp * (x - y)
		else:
			y = a_hp * (py + x - px)
			px = x
			py = y
		var j := start + i
		if j >= buf.size():
			break
		buf[j] += y * pow(0.0001, float(i) / n) * vol


## 2-operator FM bell (arcane, ice, glass): the modulation index falls with the envelope, so
## the attack is bright and the tail pure.
func fm(buf: PackedFloat32Array, t0: float, f: float, d: float, ratio: float, index: float, vol: float) -> void:
	f *= _pitch
	var n := int(d * SR)
	var start := int(t0 * SR)
	var ph := 0.0
	var mph := 0.0
	for i in n:
		var env := minf(1.0, i / (0.002 * SR)) * pow(0.0005, float(i) / n)
		ph += f / SR
		mph += f * ratio / SR
		var j := start + i
		if j >= buf.size():
			break
		buf[j] += sin(TAU * ph + index * env * sin(TAU * mph)) * env * vol


## A reversed swell (void, telegraphs): a decaying tone and a breath of noise rendered
## backwards, so it rises into its end. A falling `slide` becomes a rising pitch.
func swell(buf: PackedFloat32Array, t0: float, f: float, d: float, type: String, vol: float, slide := 0.0) -> void:
	var tmp := PackedFloat32Array()
	tmp.resize(int(d * SR))
	tone(tmp, 0.0, f / _pitch, d, type, vol, slide)
	noise(tmp, 0.0, d, vol * 0.4, 2000.0, 0.0)
	var start := int(t0 * SR)
	for i in tmp.size():
		var j := start + i
		if j >= buf.size():
			break
		buf[j] += tmp[tmp.size() - 1 - i]


## Crackle (static): sparse impulses with a short ring, `rate` per second, fading out.
func crackle(buf: PackedFloat32Array, t0: float, d: float, vol: float, rate: float) -> void:
	var n := int(d * SR)
	var start := int(t0 * SR)
	var ring := 0.0
	var p := rate / SR
	for i in n:
		if rng.randf() < p:
			ring = rng.randf() * 2.0 - 1.0
		ring *= 0.82
		var j := start + i
		if j >= buf.size():
			break
		buf[j] += ring * vol * pow(0.01, float(i) / n)


## One-pole high-pass in place.
func _highpass(buf: PackedFloat32Array, hz: float) -> void:
	var a := exp(-TAU * hz / SR)
	var px := 0.0
	var py := 0.0
	for i in buf.size():
		var x := buf[i]
		py = a * (py + x - px)
		px = x
		buf[i] = py


func _save(buf: PackedFloat32Array, path: String, family := "sfx") -> void:
	_highpass(buf, 80.0)
	# normalise to the family's loudness (BS.1770), peaks under PEAK: a sharp transient reaches
	# the peak ceiling first and ends as loud as it can be without clipping
	var gain := clampf(pow(10.0, (float(TARGET_LUFS[family]) - Loudness.lufs(buf, SR)) / 20.0), 0.1, 256.0)
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	gain = minf(gain, PEAK / peak)
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, clampi(int(round(buf[i] * gain * 32767.0)), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	w.save_to_wav(path)


# ------------------------------------------------------------------ sound effects
# Each entry: [length s, [[kind, t0, args...], ...]]
#   ["t", t0, freq, dur, type, vol, slide]       a tone
#   ["n", t0, dur, vol, hp, lp]                  noise
#   ["f", t0, freq, dur, ratio, index, vol]      an FM bell
#   ["r", t0, freq, dur, type, vol, slide]       a reversed swell
#   ["c", t0, dur, vol, rate]                    crackle

const SFX := {
	# casts, one timbre per element
	"cast_spark": [0.08, [["t", 0, 1150, 0.06, "square", 0.016, 0.45], ["n", 0, 0.01, 0.02, 4000, 0]]],
	"cast_laser": [0.1, [["t", 0, 1800, 0.07, "sawtooth", 0.02, 0.4]]],
	"cast_fan": [0.2, [["t", 0, 700, 0.08, "triangle", 0.02, 1.2], ["t", 0.03, 900, 0.08, "triangle", 0.02, 1.2], ["t", 0.06, 1100, 0.08, "triangle", 0.02, 1.2]]],
	"cast_missile": [0.14, [["t", 0, 500, 0.12, "sawtooth", 0.02, 1.8]]],
	"cast_fire": [0.2, [["n", 0, 0.14, 0.04, 500, 0], ["t", 0, 220, 0.18, "sawtooth", 0.03, 0.6]]],
	"cast_ice": [0.14, [["f", 0, 1600, 0.12, 1.41, 1.6, 0.04], ["t", 0, 3200, 0.03, "triangle", 0.015, 0.8]]],
	"cast_chain": [0.1, [["t", 0, 1500, 0.07, "square", 0.025, 0.3], ["n", 0, 0.05, 0.02, 4000, 0]]],
	"cast_static": [0.12, [["c", 0, 0.1, 0.5, 3000], ["t", 0, 1400, 0.06, "square", 0.02, 0.5]]],
	"cast_arcane": [0.35, [["f", 0, 880, 0.3, 3.5, 2.5, 0.05], ["t", 0, 1760, 0.04, "sine", 0.02, 0]]],
	"cast_void": [0.3, [["r", 0, 180, 0.25, "sawtooth", 0.05, 0.5], ["t", 0.24, 90, 0.06, "triangle", 0.06, 0.5]]],
	"cast_orbit": [0.22, [["t", 0, 660, 0.2, "triangle", 0.04, 1.5]]],
	"cast_boom": [0.3, [["n", 0, 0.25, 0.07, 0, 1600], ["t", 0, 240, 0.25, "triangle", 0.09, 0.45], ["t", 0, 120, 0.12, "square", 0.02, 0.5]]],
	"trigger": [0.1, [["t", 0, 990, 0.05, "square", 0.02, 1.5], ["t", 0.04, 1480, 0.05, "square", 0.015, 1.2]]],
	# hits: a transient, then the element's body
	"hit": [0.06, [["n", 0, 0.05, 0.035, 1800, 0]]],
	"crit": [0.14, [["n", 0, 0.08, 0.06, 1200, 0], ["t", 0, 1800, 0.08, "square", 0.03, 0.5], ["f", 0.02, 2400, 0.1, 2.0, 1.0, 0.02]]],
	"hit_fire": [0.14, [["n", 0, 0.03, 0.05, 1500, 0], ["n", 0, 0.12, 0.05, 0, 2500], ["t", 0, 300, 0.1, "sawtooth", 0.02, 0.6]]],
	"hit_ice": [0.12, [["f", 0, 2400, 0.1, 1.41, 1.5, 0.04], ["n", 0, 0.02, 0.03, 5000, 0]]],
	"hit_static": [0.1, [["c", 0, 0.08, 0.6, 5000], ["n", 0, 0.02, 0.03, 3000, 0]]],
	"hit_arcane": [0.18, [["f", 0, 1320, 0.16, 2.0, 1.8, 0.04], ["n", 0, 0.02, 0.02, 3000, 0]]],
	"hit_void": [0.16, [["r", 0, 400, 0.12, "sine", 0.05, 2.0], ["n", 0.1, 0.04, 0.03, 1000, 0]]],
	# defences
	"hit_armor": [0.16, [["t", 0, 1900, 0.12, "square", 0.02, 0.98], ["t", 0, 2870, 0.1, "square", 0.015, 0.99], ["n", 0, 0.03, 0.06, 3000, 0]]],
	"hit_ward": [0.14, [["f", 0, 3100, 0.12, 1.5, 1.2, 0.04]]],
	"hit_shield": [0.12, [["t", 0, 220, 0.08, "triangle", 0.08, 0.6], ["n", 0, 0.04, 0.05, 0, 1200]]],
	"armor_break": [0.5, [["n", 0, 0.4, 0.1, 800, 0], ["t", 0, 1200, 0.3, "square", 0.03, 0.5], ["t", 0, 180, 0.25, "triangle", 0.1, 0.4]]],
	"ward_break": [0.5, [["f", 0, 2600, 0.35, 1.5, 2.0, 0.04], ["f", 0.05, 3500, 0.3, 1.5, 2.0, 0.03], ["n", 0, 0.3, 0.05, 5000, 0]]],
	# kills by size
	"kill": [0.14, [["t", 0, 340, 0.12, "square", 0.03, 0.4], ["n", 0, 0.08, 0.03, 1500, 0]]],
	"kill_mid": [0.3, [["t", 0, 280, 0.25, "square", 0.04, 0.35], ["n", 0, 0.18, 0.05, 1000, 0]]],
	"kill_big": [0.6, [["n", 0, 0.5, 0.12, 0, 1500], ["t", 0, 200, 0.45, "square", 0.05, 0.3], ["f", 0.05, 660, 0.4, 3.0, 2.0, 0.03]]],
	"boom": [0.4, [["n", 0, 0.35, 0.09, 0, 1400], ["t", 0, 220, 0.3, "triangle", 0.12, 0.35], ["t", 0, 110, 0.18, "square", 0.025, 0.5]]],
	"bigboom": [0.9, [["n", 0, 0.8, 0.14, 0, 1100], ["t", 0, 170, 0.8, "triangle", 0.16, 0.3], ["t", 0, 85, 0.4, "square", 0.03, 0.5], ["n", 0, 0.05, 0.06, 2500, 0]]],
	# the player
	"hurt": [0.32, [["t", 0, 160, 0.3, "sawtooth", 0.07, 0.4], ["n", 0, 0.2, 0.07, 400, 0]]],
	"dash": [0.2, [["n", 0, 0.18, 0.08, 0, 5000], ["t", 0, 400, 0.15, "sine", 0.02, 1.6]]],
	"mana_empty": [0.15, [["t", 0, 300, 0.12, "square", 0.03, 0.7], ["n", 0, 0.08, 0.02, 3000, 0]]],
	"low_hp": [0.4, [["t", 0, 180, 0.1, "triangle", 0.1, 0.8], ["t", 0.18, 180, 0.1, "triangle", 0.08, 0.8]]],
	# enemies: shots, and telegraph cues that rise into the moment of release
	"eshot": [0.08, [["t", 0, 280, 0.07, "sawtooth", 0.02, 0.6]]],
	"eshot_ring": [0.2, [["t", 0, 420, 0.15, "triangle", 0.05, 0.5], ["n", 0, 0.06, 0.03, 2000, 0]]],
	"eshot_laser": [0.12, [["t", 0, 900, 0.1, "sawtooth", 0.025, 0.5]]],
	"tele": [0.5, [["t", 0, 420, 0.5, "triangle", 0.05, 1.9]]],
	"tele_short": [0.3, [["r", 0, 900, 0.3, "triangle", 0.06, 0.4]]],
	"tele_mid": [0.5, [["r", 0, 800, 0.5, "triangle", 0.06, 0.4], ["r", 0, 1600, 0.5, "square", 0.008, 0.4]]],
	"tele_long": [1.0, [["r", 0, 700, 1.0, "triangle", 0.06, 0.35], ["r", 0, 1400, 1.0, "square", 0.01, 0.35]]],
	"slam": [0.5, [["n", 0, 0.4, 0.12, 0, 900], ["t", 0, 160, 0.35, "triangle", 0.14, 0.45], ["n", 0, 0.03, 0.06, 2500, 0]]],
	"fuse": [0.06, [["t", 0, 1800, 0.04, "square", 0.02, 1.0]]],
	"fuse_pop": [0.35, [["n", 0, 0.3, 0.1, 0, 1800], ["t", 0, 260, 0.2, "square", 0.05, 0.3]]],
	"summon": [0.4, [["t", 0, 200, 0.35, "sawtooth", 0.04, 2.0], ["c", 0.1, 0.25, 0.3, 800]]],
	"ward_up": [0.35, [["f", 0, 1200, 0.3, 2.0, 1.0, 0.04], ["t", 0.05, 1800, 0.2, "sine", 0.02, 1.2]]],
	"charge": [0.3, [["n", 0, 0.28, 0.06, 0, 4000], ["t", 0, 220, 0.25, "sawtooth", 0.03, 1.8]]],
	"bonk": [0.2, [["t", 0, 300, 0.15, "square", 0.05, 0.5], ["n", 0, 0.03, 0.05, 0, 1500]]],
	"phase": [1.0, [["n", 0, 0.8, 0.1, 300, 0], ["t", 0, 110, 1.0, "sawtooth", 0.1, 2.5]]],
	"spawn": [0.25, [["t", 0, 300, 0.22, "triangle", 0.03, 2.2]]],
	"burn": [0.12, [["n", 0, 0.1, 0.03, 0, 1500]]],
	"freeze": [0.2, [["f", 0, 2000, 0.2, 1.41, 1.2, 0.04]]],
	# bosses
	"copy_cast": [0.5, [["t", 0, 1200, 0.4, "square", 0.03, 0.25], ["c", 0, 0.4, 0.4, 2000], ["r", 0, 600, 0.2, "sawtooth", 0.03, 2.0]]],
	"ctrl_z": [0.4, [["r", 0, 1600, 0.35, "square", 0.03, 3.0]]],
	"select_all": [0.3, [["t", 0, 1000, 0.06, "square", 0.03, 0], ["t", 0.08, 1000, 0.06, "square", 0.03, 0], ["t", 0.16, 1500, 0.12, "square", 0.03, 0]]],
	"chomp": [0.25, [["n", 0, 0.1, 0.08, 0, 1500], ["t", 0, 140, 0.15, "square", 0.05, 0.6]]],
	"derail": [0.8, [["t", 0, 900, 0.7, "sawtooth", 0.04, 0.2], ["n", 0, 0.6, 0.08, 0, 2000]]],
	"roar": [1.0, [["t", 0, 120, 0.9, "sawtooth", 0.1, 0.6], ["t", 0, 181, 0.9, "square", 0.03, 0.6], ["n", 0, 0.8, 0.08, 0, 800]]],
	# the world
	"crate": [0.15, [["n", 0, 0.12, 0.05, 0, 2500], ["t", 0, 180, 0.08, "square", 0.03, 0.6]]],
	"pod_pop": [0.3, [["n", 0, 0.25, 0.1, 0, 2200], ["t", 0, 340, 0.15, "triangle", 0.06, 0.5], ["t", 0, 700, 0.05, "sine", 0.03, 1.5]]],
	"bramble_burn": [0.5, [["n", 0, 0.45, 0.06, 0, 3000], ["c", 0, 0.45, 0.3, 400]]],
	"crack_open": [0.6, [["n", 0, 0.5, 0.1, 0, 1200], ["t", 0, 140, 0.4, "triangle", 0.1, 0.5]]],
	"pylon": [0.6, [["f", 0, 440, 0.5, 2.0, 3.0, 0.05], ["t", 0, 880, 0.4, "sine", 0.03, 1.0]]],
	"pit_fall": [0.5, [["t", 0, 700, 0.45, "triangle", 0.05, 0.25]]],
	"chest": [0.6, [["n", 0, 0.08, 0.06, 0, 1500], ["t", 0.1, 784, 0.1, "square", 0.03, 0], ["t", 0.18, 988, 0.1, "square", 0.03, 0], ["t", 0.26, 1319, 0.3, "square", 0.03, 0]]],
	"secret": [0.9, [["f", 0, 1047, 0.6, 2.0, 1.5, 0.04], ["f", 0.12, 1319, 0.6, 2.0, 1.5, 0.04], ["f", 0.24, 1568, 0.6, 2.0, 1.5, 0.04]]],
	"forge": [0.6, [["t", 0, 1500, 0.4, "square", 0.02, 0.99], ["t", 0, 2200, 0.35, "square", 0.015, 0.99], ["n", 0, 0.05, 0.08, 2000, 0]]],
	"altar": [1.0, [["r", 0, 523, 0.5, "sine", 0.05, 1.4], ["f", 0.5, 523, 0.5, 2.0, 1.5, 0.05]]],
	# rewards
	"coin": [0.07, [["t", 0, 1320, 0.06, "square", 0.025, 1.4]]],
	"buy": [0.3, [["t", 0, 1320, 0.06, "square", 0.025, 1.2], ["t", 0.07, 1760, 0.12, "square", 0.025, 1.0]]],
	"pick": [0.32, [["t", 0, 660, 0.1, "square", 0.03, 0], ["t", 0.08, 880, 0.1, "square", 0.03, 0], ["t", 0.16, 1175, 0.14, "square", 0.03, 0]]],
	"door": [0.6, [["t", 0, 200, 0.6, "triangle", 0.06, 2.0]]],
	"heal": [0.4, [["t", 0, 523, 0.14, "triangle", 0.04, 0], ["t", 0.1, 659, 0.14, "triangle", 0.04, 0], ["t", 0.2, 784, 0.18, "triangle", 0.04, 0]]],
	"levelup": [0.6, [["t", 0, 440, 0.18, "square", 0.04, 0], ["t", 0.08, 554, 0.18, "square", 0.04, 0], ["t", 0.16, 659, 0.18, "square", 0.04, 0], ["t", 0.24, 880, 0.3, "square", 0.04, 0]]],
	"win": [1.2, [["t", 0, 523.25, 0.35, "triangle", 0.07, 0], ["t", 0.14, 659.25, 0.35, "triangle", 0.07, 0], ["t", 0.28, 783.99, 0.35, "triangle", 0.07, 0], ["t", 0.42, 1046.5, 0.7, "triangle", 0.07, 0]]],
	"lose": [1.2, [["t", 0, 392, 0.4, "triangle", 0.07, 0.9], ["t", 0.3, 330, 0.4, "triangle", 0.07, 0.9], ["t", 0.6, 262, 0.6, "triangle", 0.07, 0.8]]],
	# ui
	"ui": [0.05, [["t", 0, 900, 0.04, "square", 0.02, 0]]],
	"ui_back": [0.06, [["t", 0, 600, 0.05, "square", 0.02, 0.7]]],
	"ui_open": [0.12, [["t", 0, 700, 0.05, "square", 0.02, 1.3], ["t", 0.05, 1050, 0.06, "square", 0.02, 1.0]]],
	"ui_close": [0.12, [["t", 0, 1050, 0.05, "square", 0.02, 0.8], ["t", 0.05, 700, 0.06, "square", 0.02, 0.9]]],
	"ui_equip": [0.2, [["t", 0, 880, 0.06, "square", 0.025, 0], ["t", 0.06, 1320, 0.12, "triangle", 0.03, 0]]],
	"ui_drag": [0.05, [["t", 0, 600, 0.04, "triangle", 0.02, 1.2]]],
	"ui_drop": [0.08, [["t", 0, 500, 0.06, "square", 0.025, 0.7], ["n", 0, 0.02, 0.02, 3000, 0]]],
	"swap": [0.06, [["t", 0, 500, 0.05, "square", 0.03, 1.5]]],
	"deny": [0.08, [["t", 0, 180, 0.06, "square", 0.03, 0]]],
}


func _render_sfx(def: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int((float(def[0]) + 0.02) * SR))
	for p in def[1]:
		match p[0]:
			"t":
				tone(buf, p[1], p[2], p[3], p[4], p[5], p[6])
			"n":
				noise(buf, p[1], p[2], p[3], p[4], p[5])
			"f":
				fm(buf, p[1], p[2], p[3], p[4], p[5], p[6])
			"r":
				swell(buf, p[1], p[2], p[3], p[4], p[5], p[6])
			"c":
				crackle(buf, p[1], p[2], p[3], p[4])
	return buf
