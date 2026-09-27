extends RefCounted
## The shared synthesis toolkit of sound v2 (research/sound-v2.md §3), used by gen_audio.gd
## and gen_music.gd. Load it from a generator in tools/ with a relative preload (a -s script
## keeps its own absolute path, so the preload resolves next to it; there is no class_name,
## because tools/ is outside res:// and never enters the global class cache):
##
##     const D := preload("lib_dsp.gd")
##     D.set_rate(44100)
##     var r := D.rng_for("hit", 0, 1)
##     var body := D.amp(D.modal("stone", 1200.0, 0.035, D.n_of(60.0), "impulse", r), D.aenv(0.5, 60.0, D.n_of(60.0)))
##
## Conventions (binding for both generators):
## - Every signal is a mono PackedFloat32Array. Processors return a new array of the same
##   length (the input is never changed) unless the name ends in `_in`.
## - The sample rate is the static `sr` (set_rate): 44.1 kHz for effects, 32 kHz for music.
## - A "curve" is a per-sample PackedFloat32Array: a frequency in Hz, a level, an index. The
##   oscillators, filters and FM take curves, so every parameter can move. Filters recompute
##   their coefficients at control rate (every CTRL = 32 samples, §3.1).
## - Times are in milliseconds, frequencies in Hz, gains in dB unless a name says otherwise.
## - All randomness comes from a RandomNumberGenerator the caller passes in, seeded per
##   (cue, variant, layer) with rng_for(): adding or reordering a cue never changes another
##   cue's bytes. Nothing here reads a global random stream.
## - Deterministic: the same calls give the same bytes on the same machine.
##
## After the "v1 ready" marker below, existing signatures are frozen (other generators call
## them); new functions may be added. The music generator appends its own functions only in
## the section at the very end of this file headed "# ---- music additions".
##
## lib_dsp: v1 ready

## Control-rate block for moving filter coefficients (§3.1).
const CTRL := 32

## Modal material presets (§3.8): mode frequency ratios, relative gains, base T60 (seconds).
const MATERIALS := {
	"stone": {"ratios": [1.0, 1.52, 2.23, 3.17, 4.02], "gains": [1.0, 0.6, 0.45, 0.3, 0.2], "t60": 0.08},
	"wood": {"ratios": [1.0, 2.76, 5.40], "gains": [1.0, 0.35, 0.15], "t60": 0.12},
	"brass": {"ratios": [1.0, 2.756, 5.404, 8.933], "gains": [1.0, 0.5, 0.3, 0.15], "t60": 0.6},
	"glass": {"ratios": [1.0, 2.32, 4.25, 6.63], "gains": [1.0, 0.5, 0.35, 0.2], "t60": 0.4},
	"plate": {"ratios": [1.0, 1.594, 2.136, 2.296, 2.653, 2.918, 3.156, 3.5], "gains": [1.0, 0.8, 0.7, 0.6, 0.5, 0.4, 0.35, 0.3], "t60": 0.35},
	"bell": {"ratios": [0.5, 1.0, 1.183, 1.506, 2.0, 2.514, 2.662, 3.011], "gains": [0.6, 1.0, 0.5, 0.6, 0.7, 0.3, 0.25, 0.2], "t60": 1.5},
}

## FM ratio presets (§3.7): [ratio, index at the attack, index at the end].
const FM_PRESETS := {
	"bell": [3.5, 2.2, 0.3],
	"glass": [1.414, 1.6, 0.0],
	"metal": [2.756, 3.0, 0.5],
	"wood": [1.0, 0.8, 0.0],
	"growl": [0.5, 4.0, 1.0],
}

static var sr: int = 44100


# ================================================================== setup and units

## Sets the sample rate every function below uses.
static func set_rate(rate: int) -> void:
	sr = rate


## Milliseconds to samples.
static func n_of(ms: float) -> int:
	return int(roundf(ms * 0.001 * sr))


## Samples to milliseconds.
static func ms_of(n: int) -> float:
	return n * 1000.0 / sr


## The random stream of one (cue, variant, layer): seed = hash("cue/variant/layer") (§3).
static func rng_for(cue: String, variant: int, layer: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s/%d/%d" % [cue, variant, layer])
	return r


## MIDI note to Hz (A4 = 69 = 440 Hz).
static func hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## A frequency ratio of `semis` semitones.
static func st(semis: float) -> float:
	return pow(2.0, semis / 12.0)


static func db2lin(db: float) -> float:
	return pow(10.0, db / 20.0)


static func lin2db(v: float) -> float:
	return 20.0 * log(maxf(absf(v), 1e-12)) / log(10.0)


# ================================================================== buffers

## A silent buffer of n samples.
static func zeros(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(maxi(0, n))
	b.fill(0.0)
	return b


## A silent buffer of `ms` milliseconds.
static func buf_ms(ms: float) -> PackedFloat32Array:
	return zeros(n_of(ms))


## A constant curve (a fixed frequency or level) of n samples.
static func const_curve(v: float, n: int) -> PackedFloat32Array:
	var b := zeros(n)
	b.fill(v)
	return b


## Adds `src` into `dst` starting at `at_ms`, scaled by `db`. Whatever falls past dst's end is
## dropped (size the destination for the longest layer).
static func mix(dst: PackedFloat32Array, src: PackedFloat32Array, at_ms := 0.0, db := 0.0) -> void:
	mix_at(dst, src, n_of(at_ms), db2lin(db))


## Adds `src` into `dst` at sample `at`, times the linear gain k.
static func mix_at(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, k := 1.0) -> void:
	var end := mini(src.size(), dst.size() - at)
	for i in range(maxi(0, -at), end):
		dst[at + i] += src[i] * k


## Element-wise product (a signal times an envelope). The result has the signal's length; past
## the envelope's end the last envelope value holds.
static func amp(x: PackedFloat32Array, e: PackedFloat32Array) -> PackedFloat32Array:
	var y := zeros(x.size())
	var ne := e.size()
	if ne == 0:
		return y
	var last := e[ne - 1]
	for i in x.size():
		y[i] = x[i] * (e[i] if i < ne else last)
	return y


## The sum of two buffers (the longer one's length).
static func add(a: PackedFloat32Array, b: PackedFloat32Array, b_db := 0.0) -> PackedFloat32Array:
	var y := zeros(maxi(a.size(), b.size()))
	mix_at(y, a, 0, 1.0)
	mix_at(y, b, 0, db2lin(b_db))
	return y


## x times a gain in dB.
static func gain(x: PackedFloat32Array, db: float) -> PackedFloat32Array:
	return scale(x, db2lin(db))


## x times a linear factor.
static func scale(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := zeros(x.size())
	for i in x.size():
		y[i] = x[i] * k
	return y


## In place: x times a linear factor.
static func scale_in(x: PackedFloat32Array, k: float) -> void:
	for i in x.size():
		x[i] *= k


## The buffer backwards (§3.9 rev: void, pre-swells, "rewind").
static func reverse(x: PackedFloat32Array) -> PackedFloat32Array:
	var n := x.size()
	var y := zeros(n)
	for i in n:
		y[i] = x[n - 1 - i]
	return y


## A copy padded with silence (or cut) to n samples.
static func fit(x: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var y := zeros(n)
	for i in mini(n, x.size()):
		y[i] = x[i]
	return y


## Samples [from, from + n) as a new buffer (silence past the end).
static func slice(x: PackedFloat32Array, from: int, n: int) -> PackedFloat32Array:
	var y := zeros(n)
	for i in n:
		var j := from + i
		if j >= 0 and j < x.size():
			y[i] = x[j]
	return y


## `a` then `b`.
static func concat(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var y := a.duplicate()
	y.append_array(b)
	return y


## `src` repeated to n samples (tiling a rendered bar or note).
static func tile(src: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var y := zeros(n)
	var m := src.size()
	if m == 0:
		return y
	for i in n:
		y[i] = src[i % m]
	return y


## Sample peak (linear).
static func peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p


## RMS (linear) of samples [from, from + n); the whole buffer when n < 0.
static func rms(x: PackedFloat32Array, from := 0, n := -1) -> float:
	var end := x.size() if n < 0 else mini(x.size(), from + n)
	var s := 0.0
	var c := 0
	for i in range(maxi(0, from), end):
		s += x[i] * x[i]
		c += 1
	return sqrt(s / maxf(1.0, c))


## In place: scales x so its sample peak is `level` (linear). Silence stays silent.
static func normalize_in(x: PackedFloat32Array, level := 1.0) -> void:
	var p := peak(x)
	if p > 1e-9:
		scale_in(x, level / p)


## A single impulse of height `a` at sample `at` in a buffer of n samples (a click).
static func impulse(n: int, at := 0, a := 1.0) -> PackedFloat32Array:
	var y := zeros(n)
	if at >= 0 and at < n:
		y[at] = a
	return y


# ================================================================== envelopes (§3.2)

## A multi-segment breakpoint envelope of n samples. points = [[t_ms, level, curve], ...] in
## time order; the curve of a point shapes the segment that ENDS at it: level = a + (b - a)·s(k)
## with s(k) = (1 - e^(-c·k)) / (1 - e^(-c)). c > 0 is fast-then-slow (a natural decay), c < 0
## slow-then-fast (a swell), c = 0 linear. Before the first point the first level holds, after
## the last point the last level holds.
static func env(points: Array, n: int) -> PackedFloat32Array:
	var out := zeros(n)
	if points.is_empty() or n == 0:
		return out
	var p0: Array = points[0]
	var n0 := mini(n, maxi(0, n_of(float(p0[0]))))
	for j in n0:
		out[j] = float(p0[1])
	for s in range(1, points.size()):
		var a: Array = points[s - 1]
		var b: Array = points[s]
		var na := n_of(float(a[0]))
		var nb := n_of(float(b[0]))
		var la := float(a[1])
		var lb := float(b[1])
		var c := float(b[2]) if b.size() > 2 else 0.0
		var seg := nb - na
		if seg <= 0:
			continue
		var lin := absf(c) < 1e-4
		var denom := 1.0 if lin else 1.0 - exp(-c)
		for j in range(maxi(na, 0), mini(nb, n)):
			var k := float(j - na) / seg
			var sk := k if lin else (1.0 - exp(-c * k)) / denom
			out[j] = la + (lb - la) * sk
	var pl: Array = points[points.size() - 1]
	for j in range(maxi(0, n_of(float(pl[0]))), n):
		out[j] = float(pl[1])
	return out


## A two-segment percussive envelope: a linear attack to 1 in a_ms, then an exponential decay
## that reaches -60 dB (zero) d_ms later (c = 6.9).
static func aenv(a_ms: float, d_ms: float, n: int) -> PackedFloat32Array:
	return env([[0.0, 0.0, 0.0], [a_ms, 1.0, 0.0], [a_ms + d_ms, 0.0, 6.9]], n)


## ADSR held for gate_ms, then released over r_ms from wherever it was (no click).
static func adsr(a_ms: float, d_ms: float, s: float, r_ms: float, gate_ms: float, n: int) -> PackedFloat32Array:
	var pts: Array = [[0.0, 0.0, 0.0]]
	var at_gate := s
	if gate_ms <= a_ms:
		at_gate = gate_ms / maxf(a_ms, 1e-3)
		pts.append([gate_ms, at_gate, 0.0])
	else:
		pts.append([a_ms, 1.0, 0.0])
		if gate_ms <= a_ms + d_ms:
			var k := (gate_ms - a_ms) / maxf(d_ms, 1e-3)
			at_gate = 1.0 + (s - 1.0) * (1.0 - exp(-4.0 * k)) / (1.0 - exp(-4.0))
			pts.append([gate_ms, at_gate, 4.0])
		else:
			pts.append([a_ms + d_ms, s, 4.0])
			pts.append([gate_ms, s, 0.0])
	pts.append([gate_ms + r_ms, 0.0, 5.0])
	return env(pts, n)


## An exponential rise of `db` decibels over ms, from 1/10^(db/20) up to 1 (a telegraph swell).
static func rise_db(db: float, ms: float, n: int) -> PackedFloat32Array:
	var out := zeros(n)
	var m := maxi(1, n_of(ms))
	var lo := db2lin(-db)
	for i in n:
		var k := minf(1.0, float(i) / m)
		out[i] = lo * pow(1.0 / lo, k)
	return out


# ================================================================== pitch envelopes (§3.3)

## A frequency curve from f1 to f2 over ms (then f2 holds). shape "exp" (default): f1·(f2/f1)^k;
## "drop": f2 + (f1 - f2)·e^(-t/τ), τ = ms/5 (kicks, impacts; keeps settling); "lin": linear.
static func penv(f1: float, f2: float, ms: float, n: int, shape := "exp") -> PackedFloat32Array:
	var out := zeros(n)
	var m := maxi(1, n_of(ms))
	if shape == "drop":
		var tau := maxf(1.0, m / 5.0)
		for i in n:
			out[i] = f2 + (f1 - f2) * exp(-i / tau)
	elif shape == "lin":
		for i in n:
			out[i] = f1 + (f2 - f1) * minf(1.0, float(i) / m)
	else:
		var r := f2 / f1
		for i in n:
			out[i] = f1 * pow(r, minf(1.0, float(i) / m))
	return out


## A frequency curve through several points [[t_ms, hz], ...], exponential between them.
static func penv_pts(points: Array, n: int) -> PackedFloat32Array:
	var semis: Array = []
	var f0 := float((points[0] as Array)[1])
	for p: Array in points:
		semis.append([float(p[0]), 12.0 * log(float(p[1]) / f0) / log(2.0), 0.0])
	return penv_semis(f0, semis, n)


## f0 moved by a breakpoint envelope in semitones: f = f0·2^(s(t)/12) (wobble, rewind).
static func penv_semis(f0: float, points: Array, n: int) -> PackedFloat32Array:
	var s := env(points, n)
	for i in n:
		s[i] = f0 * pow(2.0, s[i] / 12.0)
	return s


## A low-frequency oscillator curve in [-depth, depth]. shape: "sine" | "tri" | "square" |
## "sh" (sample-and-hold: a new seeded random value every cycle; pass rng). A delay holds it at
## zero for delay_ms, then it fades in over 100 ms. `phase` is in cycles.
static func lfo(rate_hz: float, depth: float, shape: String, n: int, delay_ms := 0.0, phase := 0.0, rng: RandomNumberGenerator = null) -> PackedFloat32Array:
	return lfo_mod(const_curve(rate_hz, n), depth, shape, delay_ms, phase, rng)


## lfo() with a moving rate (a tremolo that speeds up).
static func lfo_mod(rate: PackedFloat32Array, depth: float, shape: String, delay_ms := 0.0, phase := 0.0, rng: RandomNumberGenerator = null) -> PackedFloat32Array:
	var n := rate.size()
	var out := zeros(n)
	var ph := phase - floorf(phase)
	var nd := n_of(delay_ms)
	var nf := n_of(100.0) if delay_ms > 0.0 else 0
	var held := rng.randf() * 2.0 - 1.0 if rng else 1.0
	for i in n:
		var v: float
		if shape == "tri":
			v = 1.0 - 4.0 * absf(ph - 0.5)
		elif shape == "square":
			v = 1.0 if ph < 0.5 else -1.0
		elif shape == "sh":
			v = held
		else:
			v = sin(TAU * ph)
		var g := 1.0
		if i < nd:
			g = 0.0
		elif nf > 0 and i < nd + nf:
			g = float(i - nd) / nf
		out[i] = v * depth * g
		ph += rate[i] / sr
		if ph >= 1.0:
			ph -= floorf(ph)
			if shape == "sh" and rng:
				held = rng.randf() * 2.0 - 1.0
	return out


## A frequency curve with vibrato: rate Hz, ±cents, starting after delay_ms.
static func vibrato(f: PackedFloat32Array, rate_hz: float, cents: float, delay_ms := 0.0) -> PackedFloat32Array:
	var l := lfo(rate_hz, cents, "sine", f.size(), delay_ms)
	var y := zeros(f.size())
	for i in f.size():
		y[i] = f[i] * pow(2.0, l[i] / 1200.0)
	return y


# ================================================================== oscillators (§3.4)

## PolyBLEP correction: smooths a waveform's jump over one sample so high notes do not alias.
static func _blep(t: float, dt: float) -> float:
	if t < dt:
		var x := t / dt
		return x + x - x * x - 1.0
	if t > 1.0 - dt:
		var x := (t - 1.0) / dt
		return x * x + x + x + 1.0
	return 0.0


## Band-limited saw following the frequency curve f. `phase` is the start phase in cycles.
static func saw(f: PackedFloat32Array, phase := 0.0) -> PackedFloat32Array:
	var n := f.size()
	var out := zeros(n)
	var ph := phase - floorf(phase)
	for i in n:
		var dt := f[i] / sr
		out[i] = 2.0 * ph - 1.0 - _blep(ph, dt)
		ph += dt
		ph -= floorf(ph)
	return out


## Band-limited pulse with duty cycle `duty`, or a moving duty curve (PWM) when given. The DC
## of an asymmetric pulse is removed.
static func pulse(f: PackedFloat32Array, duty := 0.5, duty_curve := PackedFloat32Array(), phase := 0.0) -> PackedFloat32Array:
	var n := f.size()
	var out := zeros(n)
	var ph := phase - floorf(phase)
	var pwm := duty_curve.size() > 0
	for i in n:
		var dt := f[i] / sr
		var d := clampf(duty_curve[i] if pwm and i < duty_curve.size() else duty, 0.02, 0.98)
		var s := (1.0 if ph < d else -1.0) + _blep(ph, dt)
		var t2 := ph - d
		if t2 < 0.0:
			t2 += 1.0
		s -= _blep(t2, dt)
		out[i] = s - (2.0 * d - 1.0)
		ph += dt
		ph -= floorf(ph)
	return out


## Triangle (naive; fine up to about 3 kHz).
static func tri(f: PackedFloat32Array, phase := 0.0) -> PackedFloat32Array:
	var n := f.size()
	var out := zeros(n)
	var ph := phase - floorf(phase)
	for i in n:
		out[i] = 4.0 * absf(ph - 0.5) - 1.0
		ph += f[i] / sr
		ph -= floorf(ph)
	return out


## Sine following the frequency curve f.
static func sine(f: PackedFloat32Array, phase := 0.0) -> PackedFloat32Array:
	var n := f.size()
	var out := zeros(n)
	var ph := phase - floorf(phase)
	for i in n:
		out[i] = sin(TAU * ph)
		ph += f[i] / sr
		ph -= floorf(ph)
	return out


## One oscillator by name: "saw" | "pulse" (duty) | "square" | "tri" | "sine".
static func osc(kind: String, f: PackedFloat32Array, duty := 0.5, phase := 0.0) -> PackedFloat32Array:
	match kind:
		"saw":
			return saw(f, phase)
		"pulse":
			return pulse(f, duty, PackedFloat32Array(), phase)
		"square":
			return pulse(f, 0.5, PackedFloat32Array(), phase)
		"tri":
			return tri(f, phase)
	return sine(f, phase)


## Supersaw: `voices` saws spread over ±detune_cents; the centre voice at full level, the others
## at `side`, with seeded random start phases. Scaled to about the RMS of one saw.
static func supersaw(f: PackedFloat32Array, rng: RandomNumberGenerator, voices := 5, detune_cents := 12.0, side := 0.6) -> PackedFloat32Array:
	var n := f.size()
	var out := zeros(n)
	var norm := 1.0 / sqrt(1.0 + side * side * (voices - 1))
	for v in voices:
		var pos := 0.0 if voices == 1 else -1.0 + 2.0 * v / (voices - 1)
		var ratio := pow(2.0, pos * detune_cents / 1200.0)
		var g := 1.0 if absf(pos) < 1e-6 else side
		var fv := zeros(n)
		for i in n:
			fv[i] = f[i] * ratio
		mix_at(out, saw(fv, rng.randf()), 0, g * norm)
	return out


## Noise of n samples: "white" (the seeded RNG), "pink" (Paul Kellet's 3-pole approximation),
## "brown" (a leaky integrator y = 0.98y + 0.02x, rescaled). All roughly ±1.
static func noise(n: int, rng: RandomNumberGenerator, kind := "white") -> PackedFloat32Array:
	var out := zeros(n)
	if kind == "pink":
		var b0 := 0.0
		var b1 := 0.0
		var b2 := 0.0
		for i in n:
			var w := rng.randf() * 2.0 - 1.0
			b0 = 0.99765 * b0 + w * 0.0990460
			b1 = 0.96300 * b1 + w * 0.2965164
			b2 = 0.57000 * b2 + w * 1.0526913
			out[i] = (b0 + b1 + b2 + w * 0.1848) * 0.25
	elif kind == "brown":
		var y := 0.0
		for i in n:
			y = 0.98 * y + 0.02 * (rng.randf() * 2.0 - 1.0)
			out[i] = y * 6.0
	else:
		for i in n:
			out[i] = rng.randf() * 2.0 - 1.0
	return out


## The sigil (§3.4, the signature "code" tick): a 25% pulse at f through a band-pass at 2f
## (Q 6), under aenv(0.3, ms), plus a one-sample click at the onset scaled by `bright`.
static func sigil(f: float, ms: float, bright := 1.0) -> PackedFloat32Array:
	var n := n_of(ms)
	var y := amp(svf(pulse(const_curve(f, n), 0.25), "bp", 2.0 * f, 6.0), aenv(0.3, ms, n))
	if n > 0:
		y[0] += 0.6 * bright
	return y


# ================================================================== filters (§3.5)

## Simper TPT state-variable filter with fixed coefficients. mode: "lp" | "bp" | "hp" |
## "notch" | "peak" | "ap". The band-pass is normalised to 0 dB at the centre (k·v1).
static func svf(x: PackedFloat32Array, mode: String, fc: float, q: float) -> PackedFloat32Array:
	return svf_mod(x, mode, PackedFloat32Array(), q, PackedFloat32Array(), fc)


## The SVF with a moving cutoff curve (and optionally a moving Q curve), recomputed every CTRL
## samples. fc is clamped to [20, 0.45·sr]. When fc_curve is empty, `fc_const` is used.
static func svf_mod(x: PackedFloat32Array, mode: String, fc_curve: PackedFloat32Array, q: float, q_curve := PackedFloat32Array(), fc_const := 1000.0) -> PackedFloat32Array:
	var n := x.size()
	var y := zeros(n)
	var ic1 := 0.0
	var ic2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var a3 := 0.0
	var m0 := 0.0
	var m1 := 0.0
	var m2 := 0.0
	var has_f := fc_curve.size() > 0
	var has_q := q_curve.size() > 0
	var fmax := 0.45 * sr
	for i in n:
		if i % CTRL == 0:
			var fc := fc_curve[mini(i, fc_curve.size() - 1)] if has_f else fc_const
			var qq := q_curve[mini(i, q_curve.size() - 1)] if has_q else q
			var g := tan(PI * clampf(fc, 20.0, fmax) / sr)
			var k := 1.0 / maxf(qq, 0.05)
			a1 = 1.0 / (1.0 + g * (g + k))
			a2 = g * a1
			a3 = g * a2
			match mode:
				"lp":
					m0 = 0.0; m1 = 0.0; m2 = 1.0
				"bp":
					m0 = 0.0; m1 = k; m2 = 0.0
				"hp":
					m0 = 1.0; m1 = -k; m2 = -1.0
				"notch":
					m0 = 1.0; m1 = -k; m2 = 0.0
				"peak":
					m0 = -1.0; m1 = k; m2 = 2.0
				_:
					m0 = 1.0; m1 = -2.0 * k; m2 = 0.0
		var v0 := x[i]
		var v3 := v0 - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		y[i] = m0 * v0 + m1 * v1 + m2 * v2
	return y


## Two SVF stages in series: 24 dB/oct for lp and hp (Butterworth Q pair 0.541 / 1.307 when
## q is 0.707), a steeper band for bp.
static func svf2(x: PackedFloat32Array, mode: String, fc: float, q := 0.7071) -> PackedFloat32Array:
	if absf(q - 0.7071) < 1e-3 and (mode == "lp" or mode == "hp"):
		return svf(svf(x, mode, fc, 0.5412), mode, fc, 1.3066)
	return svf(svf(x, mode, fc, q), mode, fc, q)


## A band-pass between lo and hi Hz built from 24 dB/oct high- and low-passes (flat inside).
static func band(x: PackedFloat32Array, lo: float, hi: float) -> PackedFloat32Array:
	return svf2(svf2(x, "hp", lo), "lp", hi)


## One-pole low-pass (6 dB/oct; cheap tone shaping).
static func lp1(x: PackedFloat32Array, hz_: float) -> PackedFloat32Array:
	var y := zeros(x.size())
	var a := 1.0 - exp(-TAU * hz_ / sr)
	var s := 0.0
	for i in x.size():
		s += a * (x[i] - s)
		y[i] = s
	return y


## One-pole high-pass (6 dB/oct).
static func hp1(x: PackedFloat32Array, hz_: float) -> PackedFloat32Array:
	var y := zeros(x.size())
	var a := exp(-TAU * hz_ / sr)
	var px := 0.0
	var py := 0.0
	for i in x.size():
		py = a * (py + x[i] - px)
		px = x[i]
		y[i] = py
	return y


## DC blocker y = x - x1 + 0.995·y1 (every output passes through it).
static func dc_block(x: PackedFloat32Array) -> PackedFloat32Array:
	var y := zeros(x.size())
	var x1 := 0.0
	var y1 := 0.0
	for i in x.size():
		y1 = x[i] - x1 + 0.995 * y1
		x1 = x[i]
		y[i] = y1
	return y


## RBJ cookbook biquad coefficients [b0, b1, b2, a1, a2] (normalised by a0). kind: "peak" |
## "lowshelf" | "highshelf" | "lp" | "hp" | "bp".
static func rbj(kind: String, f: float, gain_db: float, q: float) -> PackedFloat32Array:
	var a := pow(10.0, gain_db / 40.0)
	var w0 := TAU * clampf(f, 10.0, 0.49 * sr) / sr
	var cw := cos(w0)
	var alpha := sin(w0) / (2.0 * q)
	var b0: float
	var b1: float
	var b2: float
	var a0: float
	var a1: float
	var a2: float
	match kind:
		"lowshelf":
			var sa := 2.0 * sqrt(a) * alpha
			b0 = a * ((a + 1.0) - (a - 1.0) * cw + sa)
			b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cw)
			b2 = a * ((a + 1.0) - (a - 1.0) * cw - sa)
			a0 = (a + 1.0) + (a - 1.0) * cw + sa
			a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cw)
			a2 = (a + 1.0) + (a - 1.0) * cw - sa
		"highshelf":
			var sa := 2.0 * sqrt(a) * alpha
			b0 = a * ((a + 1.0) + (a - 1.0) * cw + sa)
			b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cw)
			b2 = a * ((a + 1.0) + (a - 1.0) * cw - sa)
			a0 = (a + 1.0) - (a - 1.0) * cw + sa
			a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cw)
			a2 = (a + 1.0) - (a - 1.0) * cw - sa
		"lp":
			b0 = (1.0 - cw) / 2.0; b1 = 1.0 - cw; b2 = b0
			a0 = 1.0 + alpha; a1 = -2.0 * cw; a2 = 1.0 - alpha
		"hp":
			b0 = (1.0 + cw) / 2.0; b1 = -(1.0 + cw); b2 = b0
			a0 = 1.0 + alpha; a1 = -2.0 * cw; a2 = 1.0 - alpha
		"bp":
			b0 = alpha; b1 = 0.0; b2 = -alpha
			a0 = 1.0 + alpha; a1 = -2.0 * cw; a2 = 1.0 - alpha
		_:   # peak
			b0 = 1.0 + alpha * a; b1 = -2.0 * cw; b2 = 1.0 - alpha * a
			a0 = 1.0 + alpha / a; a1 = -2.0 * cw; a2 = 1.0 - alpha / a
	return PackedFloat32Array([b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0])


## Runs a biquad (coefficients from rbj()).
static func biquad(x: PackedFloat32Array, c: PackedFloat32Array) -> PackedFloat32Array:
	var y := zeros(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	for i in x.size():
		var xi := x[i]
		var yi := b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = yi
		y[i] = yi
	return y


## Static EQ (§3.5): "peak" | "lowshelf" | "highshelf" at f with gain_db and q.
static func eq(x: PackedFloat32Array, kind: String, f: float, gain_db: float, q := 0.7071) -> PackedFloat32Array:
	return biquad(x, rbj(kind, f, gain_db, q))


## The mandatory output filter (§3.5): a 2nd-order Butterworth high-pass (70 Hz for effects,
## 45 Hz for music).
static func hp2(x: PackedFloat32Array, hz_: float) -> PackedFloat32Array:
	return biquad(x, rbj("hp", hz_, 0.0, 0.7071))


## hp2 for a loop: the filter runs over the loop twice and the second pass is kept, so its state
## is continuous across the seam (the two-pass wrap trick).
static func hp2_loop(x: PackedFloat32Array, hz_: float) -> PackedFloat32Array:
	return second_half(hp2(twice(x), hz_))


# ================================================================== nonlinearity (§3.6)

## Saturation. kind: "tanh" tanh(d·x)/tanh(d) (odd harmonics); "asym" tanh(d·(x + 0.2x²))/tanh(d)
## (adds even harmonics: a warmer thump; leaves DC, so dc_block after); "fold" sin(d·x·π/2)
## (wavefolder, Foundry metal); "hard" clamp(d·x).
static func sat(x: PackedFloat32Array, drive: float, kind := "tanh") -> PackedFloat32Array:
	var y := zeros(x.size())
	var norm := 1.0 / tanh(maxf(drive, 1e-3))
	match kind:
		"asym":
			for i in x.size():
				var v := x[i]
				y[i] = tanh(drive * (v + 0.2 * v * v)) * norm
		"fold":
			for i in x.size():
				y[i] = sin(drive * x[i] * PI * 0.5)
		"hard":
			for i in x.size():
				y[i] = clampf(drive * x[i], -1.0, 1.0)
		_:
			for i in x.size():
				y[i] = tanh(drive * x[i]) * norm
	return y


## The phantom fundamental (§3.6): the part of x below `split` Hz is isolated, saturated
## (asymmetric, level-independent), band-passed to 200-700 Hz and added back at `mixv`, so
## the 2nd and 3rd harmonics of a low body make a phone speaker imply its fundamental.
static func phantom(x: PackedFloat32Array, split := 180.0, drive := 4.0, mixv := 0.5) -> PackedFloat32Array:
	var low := svf2(x, "lp", split)
	var p := peak(low)
	if p < 1e-9:
		return x.duplicate()
	var h := sat(scale(low, 1.0 / p), drive, "asym")
	h = band(h, 200.0, 700.0)
	var y := x.duplicate()
	mix_at(y, h, 0, mixv * p)
	return y


## Bit-crush (§3.6): sample-and-hold every `hold` samples, quantise to `bits`, blend `wet`. A
## bits_curve (per sample) overrides `bits` (a crush that deepens: 12 → 4).
static func crush(x: PackedFloat32Array, hold: int, bits: float, wet := 1.0, bits_curve := PackedFloat32Array()) -> PackedFloat32Array:
	var y := zeros(x.size())
	var held := 0.0
	var hb := maxi(1, hold)
	var has_c := bits_curve.size() > 0
	for i in x.size():
		if i % hb == 0:
			held = x[i]
		var b := bits_curve[mini(i, bits_curve.size() - 1)] if has_c else bits
		var levels := pow(2.0, maxf(1.0, b) - 1.0)
		var q := roundf(held * levels) / levels
		y[i] = x[i] + (q - x[i]) * wet
	return y


## Stutter (§3.6): the slice [at_ms, at_ms + slice_ms) plays `repeats` times, then the rest
## follows. The result is longer by slice·(repeats - 1). Slice edges get 0.5 ms fades.
static func stutter(x: PackedFloat32Array, at_ms: float, slice_ms: float, repeats: int) -> PackedFloat32Array:
	var a := n_of(at_ms)
	var s := maxi(1, n_of(slice_ms))
	var piece := slice(x, a, s)
	fade_in(piece, 0.5, 0.5)
	var y := slice(x, 0, a)
	for r in repeats:
		y.append_array(piece)
	y.append_array(slice(x, a + s, maxi(0, x.size() - a - s)))
	return y


## Amplitude modulation (tremolo): gain swings between 1 and 1 - depth at rate Hz.
static func am(x: PackedFloat32Array, rate_hz: float, depth: float, shape := "sine") -> PackedFloat32Array:
	return am_mod(x, const_curve(rate_hz, x.size()), depth, shape)


## am() with a moving rate curve (a warble that speeds up), optionally a moving depth curve.
static func am_mod(x: PackedFloat32Array, rate: PackedFloat32Array, depth: float, shape := "sine", depth_curve := PackedFloat32Array()) -> PackedFloat32Array:
	var l := lfo_mod(rate, 1.0, shape, 0.0, 0.25)
	var y := zeros(x.size())
	var has_d := depth_curve.size() > 0
	for i in x.size():
		var d := depth_curve[mini(i, depth_curve.size() - 1)] if has_d else depth
		y[i] = x[i] * (1.0 - d * (0.5 + 0.5 * l[i]))
	return y


# ================================================================== FM (§3.7)

## 2-operator FM (modulator → carrier) on the frequency curve f with a per-sample index curve.
## ops = 3 stacks a second modulator (ratio2, index2) on the first, for richer metal. The
## result is unenveloped; multiply it by an amplitude envelope.
static func fm(f: PackedFloat32Array, ratio: float, index: PackedFloat32Array, ops := 2, ratio2 := 1.0, index2 := 0.0) -> PackedFloat32Array:
	var n := f.size()
	var out := zeros(n)
	var pc := 0.0
	var pm := 0.0
	var pm2 := 0.0
	var ni := index.size()
	for i in n:
		var ix := index[mini(i, ni - 1)] if ni > 0 else 0.0
		var mod := sin(TAU * pm + (index2 * sin(TAU * pm2) if ops >= 3 else 0.0))
		out[i] = sin(TAU * pc + ix * mod)
		var fi := f[i] / sr
		pc += fi
		pm += fi * ratio
		pm2 += fi * ratio * ratio2
		pc -= floorf(pc)
		pm -= floorf(pm)
		pm2 -= floorf(pm2)
	return out


## FM with a material preset from FM_PRESETS (the index falls from its attack value to its end
## value over index_ms, exponentially), unenveloped.
static func fm_preset(preset: String, f: PackedFloat32Array, index_ms: float) -> PackedFloat32Array:
	var p: Array = FM_PRESETS[preset]
	var n := f.size()
	var ix := env([[0.0, float(p[1]), 0.0], [index_ms, float(p[2]), 4.0]], n)
	return fm(f, float(p[0]), ix)


## A curve falling from i1 to i2 over ms (an FM index envelope), exponential-ish.
static func index_env(i1: float, i2: float, ms: float, n: int) -> PackedFloat32Array:
	return env([[0.0, i1, 0.0], [ms, i2, 4.0]], n)


# ================================================================== physical models (§3.8)

## Extended Karplus-Strong (Jaffe & Smith): a pluck at f Hz whose loop decays to -60 dB in t60
## seconds. bright 0..1 (the loop filter: 1 = no damping of highs, 0 = the classic average),
## pick_pos 0..1 (a comb on the excitation). Tuned with a first-order allpass for the
## fractional delay. n samples out.
static func ks(f: float, t60: float, bright: float, pick_pos: float, n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := zeros(n)
	var s := 0.5 * (1.0 - clampf(bright, 0.0, 1.0))
	var total := float(sr) / f - s
	var ni := int(floor(total))
	var frac := total - ni
	if frac < 0.1 and ni > 2:
		ni -= 1
		frac += 1.0
	var c := (1.0 - frac) / (1.0 + frac)
	var rho := pow(0.001, 1.0 / maxf(1e-3, f * t60))
	# excitation: a noise burst one period long, low-passed by brightness, combed by pick position
	var burst := noise(ni, rng)
	burst = lp1(burst, clampf(bright * 8000.0, 400.0, 0.45 * sr))
	var pd := int(roundf(pick_pos * ni))
	var exc := burst.duplicate()
	if pd > 0:
		for i in range(pd, ni):
			exc[i] -= burst[i - pd]
	var line := zeros(ni)
	var idx := 0
	var ap_x1 := 0.0
	var ap_y1 := 0.0
	var lp_x1 := 0.0
	var ne := exc.size()
	for i in n:
		var dl := line[idx]
		var ap := c * dl + ap_x1 - c * ap_y1
		ap_x1 = dl
		ap_y1 = ap
		var fb := rho * ((1.0 - s) * ap + s * lp_x1)
		lp_x1 = ap
		var y := fb + (exc[i] if i < ne else 0.0)
		line[idx] = y
		idx += 1
		if idx >= ni:
			idx = 0
		out[i] = y
	return out


## An excitation buffer for modal(): "impulse" (one sample), "noise" (a white burst of
## excite_ms with a fast decay), "mallet" (a click through an SVF low-pass at mallet_hz: soft).
static func excitation(kind: String, n: int, rng: RandomNumberGenerator, excite_ms := 2.0, mallet_hz := 2000.0) -> PackedFloat32Array:
	if kind == "noise" and rng:
		var m := mini(n, maxi(1, n_of(excite_ms)))
		var b := amp(noise(m, rng), aenv(0.0, excite_ms, m))
		return fit(b, n)
	if kind == "mallet":
		var e := impulse(n, 0, 1.0)
		e[mini(1, n - 1)] = 0.6
		return svf2(e, "lp", mallet_hz)
	return impulse(n, 0, 1.0)


## A modal resonator bank (§3.8): the material's modes at f0 × ratio, each a 2-pole resonator
## with t60_mode = t60 · ratio^-0.7 (higher modes die faster). t60 <= 0 uses the material's own.
## At most `max_modes` modes (4 for chatter cues); modes above 0.45·sr are skipped. `gains`
## overrides the preset's gains. The result is normalised so the first 20 ms peak at 1.
static func modal(material: String, f0: float, t60: float, n: int, excite := "impulse", rng: RandomNumberGenerator = null, max_modes := 8, excite_ms := 2.0, gains := [], mallet_hz := 0.0) -> PackedFloat32Array:
	var m: Dictionary = MATERIALS[material]
	var g: Array = gains if not gains.is_empty() else m["gains"]
	var t := t60 if t60 > 0.0 else float(m["t60"])
	var e := excitation(excite, n, rng, excite_ms, mallet_hz if mallet_hz > 0.0 else clampf(f0 * 2.5, 400.0, 9000.0))
	return modal_bank(m["ratios"], g, f0, t, e, max_modes)


## The resonator bank itself for custom ratios and gains, driven by excitation e.
static func modal_bank(ratios: Array, gains: Array, f0: float, t60: float, e: PackedFloat32Array, max_modes := 8) -> PackedFloat32Array:
	var n := e.size()
	var out := zeros(n)
	for mi in mini(mini(ratios.size(), gains.size()), max_modes):
		var fm_ := f0 * float(ratios[mi])
		if fm_ >= 0.45 * sr or fm_ <= 10.0:
			continue
		var w := TAU * fm_ / sr
		var tm := t60 * pow(float(ratios[mi]), -0.7)
		var r := exp(-6.91 / (maxf(tm, 1e-3) * sr))
		var b1 := 2.0 * r * cos(w)
		var b2 := -r * r
		var gg := float(gains[mi]) * sin(w)
		var y1 := 0.0
		var y2 := 0.0
		for i in n:
			var y := b1 * y1 + b2 * y2 + gg * e[i]
			y2 = y1
			y1 = y
			out[i] += y
	var p := 0.0
	for i in mini(n, n_of(20.0)):
		p = maxf(p, absf(out[i]))
	if p > 1e-9:
		scale_in(out, 1.0 / p)
	return out


# ================================================================== textures (§3.9)

## Sparse grains over n samples: `density_hz` grains a second (a seeded Poisson process), each
## `len_ms` long (±40%), at a random log-uniform frequency in [lo, hi]. source: "noise" (a
## band-passed Hann burst), "sine" (a Hann blip), or a modal material name (a short ping with 3
## modes). An optional `shape` curve thins the density over time (grain kept with probability
## shape[t]) and scales each grain.
static func grain(n: int, rng: RandomNumberGenerator, density_hz: float, len_ms: float, source: String, lo: float, hi: float, shape := PackedFloat32Array()) -> PackedFloat32Array:
	var out := zeros(n)
	var t := 0.0
	var has_s := shape.size() > 0
	while true:
		t += -log(maxf(1e-6, rng.randf())) / maxf(density_hz, 1e-3) * sr
		var at := int(t)
		if at >= n:
			break
		var f := exp(lerpf(log(lo), log(hi), rng.randf()))
		var gl := maxi(8, n_of(len_ms * (0.6 + 0.8 * rng.randf())))
		var a := 0.5 + 0.5 * rng.randf()
		var keep := 1.0
		if has_s:
			keep = shape[mini(at, shape.size() - 1)]
			if rng.randf() > keep:
				continue
		var g: PackedFloat32Array
		if source == "noise":
			g = svf(noise(gl, rng), "bp", f, 2.0)
			_hann_in(g)
		elif source == "sine":
			g = sine(const_curve(f, gl), rng.randf())
			_hann_in(g)
		else:
			g = modal(source, f, len_ms * 0.001, gl, "impulse", null, 3)
			fade_in(g, 0.0, 1.0)
		mix_at(out, g, at, a * (keep if has_s else 1.0))
	return out


static func _hann_in(g: PackedFloat32Array) -> void:
	var m := g.size()
	for i in m:
		g[i] *= 0.5 - 0.5 * cos(TAU * (i + 0.5) / m)


## Crackle (§3.9): sparse seeded impulses (`rate` a second) each ringing down by `ring` per
## sample, band-passed through the SVF (fc, Q 1 by default) so it is not a full-band click.
static func crackle(n: int, rng: RandomNumberGenerator, rate: float, ring := 0.82, fc := 4000.0, q := 1.0) -> PackedFloat32Array:
	var raw := zeros(n)
	var r := 0.0
	var p := rate / sr
	for i in n:
		if rng.randf() < p:
			r = rng.randf() * 2.0 - 1.0
		r *= ring
		raw[i] = r
	return svf(raw, "bp", fc, q)


## A whoosh (§3.9): pink noise through a band-pass whose centre rises f_lo → f_hi over the first
## `split` of ms, then falls to f_end (default f_lo); the amplitude follows the centre's log
## position. n samples (the whoosh itself lasts ms).
static func whoosh(n: int, rng: RandomNumberGenerator, f_lo: float, f_hi: float, ms: float, q := 1.0, split := 0.6, f_end := -1.0) -> PackedFloat32Array:
	var fe := f_lo if f_end <= 0.0 else f_end
	var up := ms * split
	var pts: Array = [[0.0, f_lo, 0.0], [up, f_hi, 0.0]]
	if split < 0.999:
		pts.append([ms, fe, 0.0])
	var fc := penv_pts(pts, n)
	var y := svf_mod(noise(n, rng, "pink"), "bp", fc, q)
	var lo := log(minf(f_lo, fe))
	var span := maxf(1e-3, log(f_hi) - lo)
	var nm := n_of(ms)
	for i in n:
		var a := clampf((log(fc[i]) - lo) / span, 0.0, 1.0)
		a = 0.25 + 0.75 * a
		if i >= nm:
			a *= maxf(0.0, 1.0 - float(i - nm) / maxf(1.0, n_of(20.0)))
		y[i] *= a
	fade_in(y, 1.0, 0.0)
	return y


# ================================================================== delay, comb, space (§3.10)

## A feedback delay (§3.10): echoes every ms, each fb quieter and darker (a one-pole LP at lp_hz
## in the loop), added to the dry signal at `wet`. The output keeps x's length (pad x first).
static func delay(x: PackedFloat32Array, ms: float, fb: float, lp_hz: float, wet: float) -> PackedFloat32Array:
	var n := x.size()
	var d := maxi(1, n_of(ms))
	var line := zeros(d)
	var y := x.duplicate()
	var a := 1.0 - exp(-TAU * lp_hz / sr)
	var s := 0.0
	var idx := 0
	for i in n:
		var out := line[idx]
		s += a * (out - s)
		line[idx] = x[i] + s * fb
		idx += 1
		if idx >= d:
			idx = 0
		y[i] += out * wet
	return y


## A short feedback comb (§3.10): y[n] = x[n] + fb·y[n - D], D = ms (fractional, linearly
## interpolated); 0.5-3 ms is a pitched "digital ring". `wet` blends it with the dry signal.
static func comb(x: PackedFloat32Array, ms: float, fb: float, wet := 1.0) -> PackedFloat32Array:
	var n := x.size()
	var d := maxf(1.0, ms * 0.001 * sr)
	var di := int(floor(d))
	var fr := d - di
	var y := zeros(n)
	for i in n:
		var a := y[i - di] if i - di >= 0 else 0.0
		var b := y[i - di - 1] if i - di - 1 >= 0 else 0.0
		y[i] = x[i] + fb * (a + (b - a) * fr)
	var out := zeros(n)
	for i in n:
		out[i] = x[i] + (y[i] - x[i]) * wet
	return out


## Freeverb-lite (§3.10): 4 damped feedback combs + 2 allpasses. size "S" (0.55, fb 0.70) or
## "M" (0.85, fb 0.80); damp 0..1 darkens the tail; `wet` is the reverb's level against the dry
## signal. The output keeps x's length (pad x for the tail, then fade it).
static func room(x: PackedFloat32Array, size := "S", wet := 0.12, damp := 0.3) -> PackedFloat32Array:
	var n := x.size()
	var sf := 0.85 if size == "M" else 0.55
	var fb := 0.80 if size == "M" else 0.70
	var k := float(sr) / 44100.0
	var lens := [1116, 1188, 1277, 1356]
	var acc := zeros(n)
	for L in lens:
		var d := maxi(1, int(roundf(float(L) * sf * k)))
		var line := zeros(d)
		var idx := 0
		var filt := 0.0
		for i in n:
			var o := line[idx]
			filt = o * (1.0 - damp) + filt * damp
			line[idx] = x[i] * 0.25 + filt * fb
			idx += 1
			if idx >= d:
				idx = 0
			acc[i] += o
	for L in [556, 441]:
		var d := maxi(1, int(roundf(float(L) * k)))
		var line := zeros(d)
		var idx := 0
		for i in n:
			var bo := line[idx]
			var v := acc[i]
			line[idx] = v + bo * 0.5
			acc[i] = bo - v
			idx += 1
			if idx >= d:
				idx = 0
	var y := x.duplicate()
	mix_at(y, acc, 0, wet)
	return y


## A baked chorus (§3.10, music pads): one voice through a delay of delay_ms modulated at rate
## Hz by ±depth_cents of pitch, blended at `wet`.
static func chorus(x: PackedFloat32Array, delay_ms := 12.0, depth_cents := 6.0, rate := 0.4, wet := 0.25) -> PackedFloat32Array:
	var n := x.size()
	var base := delay_ms * 0.001 * sr
	var amp_s := (pow(2.0, depth_cents / 1200.0) - 1.0) / (TAU * rate) * sr
	var y := x.duplicate()
	for i in n:
		var d := base + amp_s * sin(TAU * rate * i / sr)
		var p := i - d
		var j := int(floor(p))
		var fr := p - j
		var a := x[j] if j >= 0 and j < n else 0.0
		var b := x[j + 1] if j + 1 >= 0 and j + 1 < n else 0.0
		y[i] += (a + (b - a) * fr) * wet
	return y


# ================================================================== stereo (§3.11)

## Equal-power pan gains for p in [-1, 1]: Vector2(left, right).
static func pan_gains(p: float) -> Vector2:
	var a := (clampf(p, -1.0, 1.0) + 1.0) * PI / 4.0
	return Vector2(cos(a), sin(a))


## Adds a mono source into a stereo pair at at_ms, panned p, scaled db.
static func pan_mix(l: PackedFloat32Array, r: PackedFloat32Array, src: PackedFloat32Array, at_ms: float, p: float, db := 0.0) -> void:
	var g := pan_gains(p)
	var k := db2lin(db)
	var at := n_of(at_ms)
	mix_at(l, src, at, g.x * k)
	mix_at(r, src, at, g.y * k)


# ================================================================== pipeline utilities (§3.12)

## In place: a fade-in of in_ms and a fade-out of out_ms (raised-cosine). 0 skips a side.
static func fade_in(x: PackedFloat32Array, in_ms: float, out_ms: float) -> void:
	var n := x.size()
	var a := mini(n, n_of(in_ms))
	for i in a:
		x[i] *= 0.5 - 0.5 * cos(PI * (i + 0.5) / a)
	var b := mini(n, n_of(out_ms))
	for i in b:
		x[n - 1 - i] *= 0.5 - 0.5 * cos(PI * (i + 0.5) / b)


## The anti-click rule (§3.2), in place: 0.5 ms fade-in (skipped for a hard onset) and 2 ms
## fade-out.
static func declick_in(x: PackedFloat32Array, hard_onset := false) -> void:
	fade_in(x, 0.0 if hard_onset else 0.5, 2.0)


## A tail cut (QOA, §1.2): drops everything after the last sample louder than floor_db under the
## peak, then fades the last fade_ms to zero. Returns the shorter buffer (never under min_ms).
static func trim_tail(x: PackedFloat32Array, floor_db := -60.0, fade_ms := 8.0, min_ms := 0.0) -> PackedFloat32Array:
	var th := peak(x) * db2lin(floor_db)
	var last := 0
	for i in range(x.size() - 1, -1, -1):
		if absf(x[i]) > th:
			last = i
			break
	var n := maxi(mini(x.size(), last + n_of(fade_ms)), mini(x.size(), n_of(min_ms)))
	var y := slice(x, 0, n)
	fade_in(y, 0.0, fade_ms)
	return y


## x followed by itself (for a filter that must be continuous across a loop seam).
static func twice(x: PackedFloat32Array) -> PackedFloat32Array:
	return concat(x, x)


## The second half of y (after twice() and a filter: the steady-state loop).
static func second_half(y: PackedFloat32Array) -> PackedFloat32Array:
	var h := y.size() / 2
	return slice(y, h, y.size() - h)


## A loop of L samples from a longer render whose tail rings past L: the tail wraps to the start
## and is added there (the loop plays after itself, so notes ringing over the seam continue).
static func loop_wrap(a: PackedFloat32Array, L: int) -> PackedFloat32Array:
	var y := slice(a, 0, L)
	var i := L
	while i < a.size():
		y[(i - L) % L] += a[i]
		i += 1
	return y


## A loop of L samples from a render of L + F samples of a non-periodic texture (noise,
## crackle): the first F samples crossfade (equal power) with the F samples after L, so the
## seam from L-1 back to 0 is continuous.
static func loop_xfade(a: PackedFloat32Array, L: int, F: int) -> PackedFloat32Array:
	var y := slice(a, 0, L)
	var f := mini(F, a.size() - L)
	for j in f:
		var k := (j + 0.5) / f
		y[j] = a[j] * sin(k * PI * 0.5) + a[L + j] * cos(k * PI * 0.5)
	return y


## Seam figures for a loop (§7 DOG 6): the first-to-last sample jump, the RMS in dB of the first
## and last 50 ms, and the mean (DC).
static func seam(x: PackedFloat32Array) -> Dictionary:
	var n := x.size()
	var w := n_of(50.0)
	var s := 0.0
	for v in x:
		s += v
	return {"jump": absf(x[n - 1] - x[0]) if n > 0 else 0.0,
		"rms_first_db": lin2db(rms(x, 0, w)), "rms_last_db": lin2db(rms(x, n - w, w)), "dc": s / maxf(1.0, n)}


## 16-bit PCM bytes of a float buffer times a linear gain (round-to-nearest, clamped).
static func pcm16(x: PackedFloat32Array, k := 1.0) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(x.size() * 2)
	for i in x.size():
		bytes.encode_s16(i * 2, clampi(int(roundf(x[i] * k * 32767.0)), -32768, 32767))
	return bytes


## Varispeed: x read at a moving playback rate (1 = as is, st(2) = two semitones up), with
## linear interpolation. Bends a rendered pluck or creak; the result is n samples long.
static func varispeed(x: PackedFloat32Array, rate: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var y := zeros(n)
	var p := 0.0
	var m := x.size()
	var nr := rate.size()
	for i in n:
		var j := int(p)
		if j + 1 >= m:
			break
		var fr := p - j
		y[i] = x[j] + (x[j + 1] - x[j]) * fr
		p += rate[mini(i, nr - 1)] if nr > 0 else 1.0
	return y


## A look-ahead peak limiter: no sample of the result exceeds `ceiling` (linear). The gain
## reaches its floor exactly at each peak along a smooth look_ms ramp (a running minimum over
## the look-ahead, then a box average of the same length), and recovers over release_ms. Used
## to lower a short cue's crest factor so it can reach its family loudness under the
## true-peak cap. O(n): the running minimum uses a monotonic queue.
static func limit(x: PackedFloat32Array, ceiling: float, look_ms := 1.5, release_ms := 40.0) -> PackedFloat32Array:
	var n := x.size()
	var la := maxi(1, n_of(look_ms))
	var req := zeros(n)
	for i in n:
		req[i] = minf(1.0, ceiling / maxf(absf(x[i]), 1e-9))
	# gmin[i] = min(req[i .. i + la]) with a monotonic deque of indices
	var gmin := zeros(n)
	var q := PackedInt32Array()
	q.resize(n + la + 2)
	var head := 0
	var tail := 0
	var next := 0
	for i in n:
		while next < n and next <= i + la:
			while tail > head and req[q[tail - 1]] >= req[next]:
				tail -= 1
			q[tail] = next
			tail += 1
			next += 1
		while q[head] < i:
			head += 1
		gmin[i] = req[q[head]]
	# release: follow drops at once, recover exponentially (never above gmin)
	var rel := exp(-1.0 / maxf(1.0, n_of(release_ms)))
	var r := 1.0
	for i in n:
		var t := gmin[i]
		r = t if t < r else t + (r - t) * rel
		gmin[i] = r
	# a box average over la samples ramps the gain down ahead of the peak
	# (gmin[j] <= req[p] for every j in [p - la, p], so the average at a peak p never exceeds it)
	var y := zeros(n)
	var acc := 0.0
	for i in n:
		acc += gmin[i]
		if i >= la:
			acc -= gmin[i - la]
		y[i] = x[i] * acc / mini(i + 1, la)
	return y


## Writes a mono 16-bit WAV (times a linear gain) at `rate` (the current sr when 0).
static func save_wav(x: PackedFloat32Array, path: String, k := 1.0, rate := 0) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate if rate > 0 else sr
	w.stereo = false
	w.data = pcm16(x, k)
	w.save_to_wav(path)


## Writes a stereo 16-bit WAV (interleaved L/R, times a linear gain).
static func save_wav_stereo(l: PackedFloat32Array, r: PackedFloat32Array, path: String, k := 1.0, rate := 0) -> void:
	var n := mini(l.size(), r.size())
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in n:
		bytes.encode_s16(i * 4, clampi(int(roundf(l[i] * k * 32767.0)), -32768, 32767))
		bytes.encode_s16(i * 4 + 2, clampi(int(roundf(r[i] * k * 32767.0)), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate if rate > 0 else sr
	w.stereo = true
	w.data = bytes
	w.save_to_wav(path)


# ---- music additions
# (gen_music.gd's own functions go below this line; the effects generator does not edit them.)
