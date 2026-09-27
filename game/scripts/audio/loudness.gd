class_name Loudness
extends RefCounted
## D8: a loudness meter to ITU-R BS.1770-4 (design-plan §9 "Pipeline"), for mono buffers at
## any sample rate. K-weighting is the standard two-stage filter (a +4 dB high shelf near
## 1.7 kHz, then a 38 Hz high-pass), with coefficients derived for the buffer's rate the same
## way pyloudnorm derives them. Integrated loudness uses 400 ms blocks with 75% overlap, the
## -70 LUFS absolute gate and the -10 LU relative gate. A sound shorter than one block is
## measured as a single block, so short effects still get a number.
##
## Sound v2 adds momentary_max (LUFS-M, the level every effect family is set to), true_peak_db
## (4x oversampled) and band_share (the energy in a band), per research/sound-v2.md §3.12.
##
## Used by tools/gen_audio.gd and gen_music.gd to normalise every file, by tools/audio_report.gd
## for the DOG audit, and by the tests to check the shipped files stay on target.


## Integrated loudness in LUFS (-INF for silence).
static func lufs(buf: PackedFloat32Array, rate: int) -> float:
	var k := k_weighted(buf, rate)
	var block := int(0.4 * rate)
	var hop := block / 4
	var z: Array[float] = []
	if k.size() <= block:
		z.append(_mean_square(k, 0, k.size()))
	else:
		var start := 0
		while start + block <= k.size():
			z.append(_mean_square(k, start, block))
			start += hop
	# absolute gate
	var kept: Array[float] = []
	for v in z:
		if _l(v) > -70.0:
			kept.append(v)
	if kept.is_empty():
		return -INF
	# relative gate: 10 LU under the loudness of the blocks that passed the absolute gate
	var rel := _l(_avg(kept)) - 10.0
	var final: Array[float] = []
	for v in kept:
		if _l(v) > rel:
			final.append(v)
	return _l(_avg(final)) if not final.is_empty() else -INF


## Sample peak in dBFS.
static func peak_db(buf: PackedFloat32Array) -> float:
	var p := 0.0
	for v in buf:
		p = maxf(p, absf(v))
	return 20.0 * log(maxf(p, 1e-9)) / log(10.0)


## Sound v2 (research/sound-v2.md §3.12): the maximum momentary loudness (LUFS-M) of a buffer,
## the level every effect is normalised to. EBU R128 momentary: 400 ms K-weighted blocks, hop
## 100 ms; a buffer shorter than 400 ms is zero-padded to 400 ms. -INF for silence.
static func momentary_max(buf: PackedFloat32Array, rate: int) -> float:
	var block := int(0.4 * rate)
	var src := buf
	if buf.size() < block:
		src = buf.duplicate()
		src.resize(block)
	var k := k_weighted(src, rate)
	var hop := maxi(1, int(0.1 * rate))
	# running sums of squares, so each block costs O(1)
	var best := 0.0
	var s := 0.0
	for i in block:
		s += k[i] * k[i]
	best = s
	var start := 0
	while start + block + hop <= k.size():
		for i in range(start, start + hop):
			s -= k[i] * k[i]
		for i in range(start + block, start + block + hop):
			s += k[i] * k[i]
		start += hop
		best = maxf(best, s)
	if best <= 0.0:
		return -INF
	return _l(best / block)


## True peak in dBTP (sound v2 §3.12, BS.1770-4 Annex 2 style): 4x oversampling with a 48-tap
## windowed-sinc polyphase FIR (12 taps per phase), evaluated only in the 64-sample windows
## whose sample peak is within 6 dB of the file peak (the only places a true peak can win).
static func true_peak_db(buf: PackedFloat32Array, _rate := 0) -> float:
	var n := buf.size()
	var p := 0.0
	for v in buf:
		p = maxf(p, absf(v))
	if p <= 0.0:
		return -INF
	var taps := _tp_taps()
	var th := p * 0.5012   # -6 dB
	var best := p
	var w := 64
	var start := 0
	while start < n:
		var end := mini(n, start + w)
		var wp := 0.0
		for i in range(start, end):
			wp = maxf(wp, absf(buf[i]))
		if wp >= th:
			for i in range(start, end):
				for ph in range(1, 4):
					var acc := 0.0
					for m in 12:
						var j := i - 5 + m
						if j >= 0 and j < n:
							acc += buf[j] * taps[ph * 12 + m]
					best = maxf(best, absf(acc))
		start = end
	return 20.0 * log(best) / log(10.0)


static var _taps_cache := PackedFloat32Array()


## Polyphase taps: phase ph (0..3) at fractional time ph/4, tap m on sample n - 5 + m; a
## Hann-windowed sinc of half-width 6 samples, each phase normalised to unity DC gain.
static func _tp_taps() -> PackedFloat32Array:
	if _taps_cache.size() == 48:
		return _taps_cache
	var t := PackedFloat32Array()
	t.resize(48)
	for ph in 4:
		var sum := 0.0
		for m in 12:
			var tau := ph / 4.0 + 5.0 - m
			var sinc := 1.0 if absf(tau) < 1e-9 else sin(PI * tau) / (PI * tau)
			var win := 0.5 + 0.5 * cos(PI * tau / 6.0) if absf(tau) < 6.0 else 0.0
			t[ph * 12 + m] = sinc * win
			sum += sinc * win
		for m in 12:
			t[ph * 12 + m] /= sum
	_taps_cache = t
	return t


## The share (0..1) of a buffer's energy between lo and hi Hz (sound v2 §3.12), FFT-free: the
## buffer through a 4th-order Butterworth high-pass at lo and low-pass at hi (two state-variable
## sections each, Q 0.541 and 1.307). lo <= 0 or hi >= rate/2 skip that side.
static func band_share(buf: PackedFloat32Array, rate: int, lo: float, hi: float) -> float:
	var total := 0.0
	for v in buf:
		total += v * v
	if total <= 0.0:
		return 0.0
	var y := buf
	if lo > 0.0:
		y = _svf(_svf(y, rate, lo, 0.5412, true), rate, lo, 1.3066, true)
	if hi < rate * 0.5:
		y = _svf(_svf(y, rate, hi, 0.5412, false), rate, hi, 1.3066, false)
	var e := 0.0
	for v in y:
		e += v * v
	return e / total


## One Simper TPT state-variable section: high-pass or low-pass at fc with Q.
static func _svf(x: PackedFloat32Array, rate: int, fc: float, q: float, high: bool) -> PackedFloat32Array:
	var g := tan(PI * minf(fc, 0.45 * rate) / rate)
	var k := 1.0 / q
	var a1 := 1.0 / (1.0 + g * (g + k))
	var a2 := g * a1
	var a3 := g * a2
	var ic1 := 0.0
	var ic2 := 0.0
	var y := PackedFloat32Array()
	y.resize(x.size())
	for i in x.size():
		var v0 := x[i]
		var v3 := v0 - ic2
		var v1 := a1 * ic1 + a2 * v3
		var v2 := ic2 + a2 * ic1 + a3 * v3
		ic1 = 2.0 * v1 - ic1
		ic2 = 2.0 * v2 - ic2
		y[i] = (v0 - k * v1 - v2) if high else v2
	return y


## The buffer through the K-weighting filter.
static func k_weighted(buf: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	var shelf := _shelf(rate)
	var hp := _highpass(rate)
	return _biquad(_biquad(buf, shelf), hp)


static func _l(ms: float) -> float:
	return -0.691 + 10.0 * log(maxf(ms, 1e-12)) / log(10.0)


static func _avg(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()


static func _mean_square(b: PackedFloat32Array, start: int, n: int) -> float:
	var s := 0.0
	for i in range(start, start + n):
		s += b[i] * b[i]
	return s / maxf(1.0, n)


## Stage 1: the head's high shelf. Returns [b0, b1, b2, a1, a2] normalised by a0.
static func _shelf(rate: int) -> Array[float]:
	var g := 4.0
	var q := 1.0 / sqrt(2.0)
	var fc := 1500.0
	var a := pow(10.0, g / 40.0)
	var w0 := TAU * fc / rate
	var alpha := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var sa := 2.0 * sqrt(a) * alpha
	var b0 := a * ((a + 1.0) + (a - 1.0) * cw + sa)
	var b1 := -2.0 * a * ((a - 1.0) + (a + 1.0) * cw)
	var b2 := a * ((a + 1.0) + (a - 1.0) * cw - sa)
	var a0 := (a + 1.0) - (a - 1.0) * cw + sa
	var a1 := 2.0 * ((a - 1.0) - (a + 1.0) * cw)
	var a2 := (a + 1.0) - (a - 1.0) * cw - sa
	return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]


## Stage 2: the RLB high-pass.
static func _highpass(rate: int) -> Array[float]:
	var q := 0.5
	var fc := 38.0
	var w0 := TAU * fc / rate
	var alpha := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var a0 := 1.0 + alpha
	return [(1.0 + cw) / 2.0 / a0, -(1.0 + cw) / a0, (1.0 + cw) / 2.0 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0]


static func _biquad(x: PackedFloat32Array, c: Array[float]) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var xi := x[i]
		var yi := c[0] * xi + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = xi
		y2 = y1
		y1 = yi
		y[i] = yi
	return y


## Decodes a 16-bit PCM AudioStreamWAV (mono, or the left channel of stereo) to floats. An
## imported stream is QOA-compressed: read the source with AudioStreamWAV.load_from_file.
static func samples(w: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var d := w.data
	var step := 4 if w.stereo else 2
	out.resize(d.size() / step)
	for i in out.size():
		out[i] = d.decode_s16(i * step) / 32768.0
	return out
