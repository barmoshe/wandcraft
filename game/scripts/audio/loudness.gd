class_name Loudness
extends RefCounted
## D8: a loudness meter to ITU-R BS.1770-4 (design-plan §9 "Pipeline"), for mono buffers at
## any sample rate. K-weighting is the standard two-stage filter (a +4 dB high shelf near
## 1.7 kHz, then a 38 Hz high-pass), with coefficients derived for the buffer's rate the same
## way pyloudnorm derives them. Integrated loudness uses 400 ms blocks with 75% overlap, the
## -70 LUFS absolute gate and the -10 LU relative gate. A sound shorter than one block is
## measured as a single block, so short effects still get a number.
##
## Used by tools/gen_audio.gd to normalise every file, by tools/audio_norm.gd for the report,
## and by the tests to check the shipped files stay on target.


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
