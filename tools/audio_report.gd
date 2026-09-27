extends SceneTree
## Sound v2 audit (research/sound-v2.md §7): measures every shipped effect (game/assets/audio/
## sfx_*.wav, read from the WAV source, not the QOA import) against the SFX lines of the DOG and
## prints one row per file, then a pass/fail line per criterion.
## Run: tools/godot.sh --headless --path game -s <abs path>/tools/audio_report.gd [-- --quiet]
##
## Measured per file:
##   M      maximum momentary loudness, LUFS-M (Loudness.momentary_max): the family level
##   TP     true peak, dBTP (Loudness.true_peak_db, 4x oversampled)
##   R1     energy share in 330-1200 Hz (the threat band)       (Loudness.band_share)
##   R2     energy share in 2.2-3.6 kHz (the crit's ring band)
##   ring   the longest run (ms) of 10 ms STFT frames (1024-point Hann) whose 2-4 kHz energy
##          stays within 30 dB of the file's loudest frame (the "rings in R2" test of DOG 5);
##          measured for the combat cues (casts, hits, crit, trigger)
##   phone  loudness lost through the phone model (4th-order high-pass at 300 Hz, low-pass at
##          12 kHz), LU (DOG 4)
##   dom    the octave band holding the most energy, from one FFT of the whole file (DOG 4: never
##          under 200 Hz or over 10 kHz)
## Variant sets are compared by octave-band shape and body pitch (DOG 9: >= 2 dB apart in some
## band, or >= 1 semitone apart in the strongest spectral peak); the loops
## by their seam (DOG 6).

const D := preload("lib_dsp.gd")
const G := preload("gen_audio.gd")
const DIR := "res://assets/audio/"
const OCT := [[25.0, 50.0], [50.0, 100.0], [100.0, 200.0], [200.0, 400.0], [400.0, 800.0], [800.0, 1600.0],
	[1600.0, 3200.0], [3200.0, 6400.0], [6400.0, 12800.0], [12800.0, 20000.0]]
## Chatter whose R1 share must stay <= 15% (DOG 5); cast_boom and cast_void are exempt by the spec,
## hit_heavy is exempt (§4.3: it co-fires with a hit, never alone).
const R1_EXEMPT := ["cast_boom", "cast_void", "hit_heavy"]

var fails := {}
var notes: Array[String] = []


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var quiet := "--quiet" in OS.get_cmdline_user_args()
	var dir := ProjectSettings.globalize_path(DIR)
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("sfx_") and f.ends_with(".wav"):
			files.append(f)
	files.sort()
	var ids: Array = G.CUES.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	var sets := {}          # id -> [octave profiles of its plain variants]
	var bytes := 0
	var secs := 0.0
	var seen := {}
	if not quiet:
		print("%-24s %4s %6s %7s %6s %5s %5s %5s %6s %5s %-10s %s" % ["file", "fam", "target", "M", "TP", "R1", "R2", "hurt", "ring", "phone", "dom", "ms"])
	for f: String in files:
		var stem := f.trim_prefix("sfx_").trim_suffix(".wav")
		var id := ""
		var suffix := ""
		for cand: String in ids:
			if stem == cand or stem.begins_with(cand + "_") and _is_suffix(stem.substr(cand.length() + 1)):
				id = cand
				suffix = stem.substr(cand.length() + 1) if stem != cand else ""
				break
		if id == "":
			_fail("coverage", "%s has no cue in gen_audio.gd" % f)
			continue
		seen[id] = true
		var row: Array = G.CUES[id]
		var fam := String(row[0])
		var flags := String(row[2])
		var target := float(row[3]) if float(row[3]) != 0.0 else float(G.FAMILY[fam])
		var w := AudioStreamWAV.load_from_file(dir.path_join(f))
		var x := Loudness.samples(w)
		var rate := w.mix_rate
		D.set_rate(rate)
		bytes += FileAccess.get_file_as_bytes(dir.path_join(f)).size()
		var ms := x.size() * 1000.0 / rate
		secs += ms / 1000.0
		var m := Loudness.momentary_max(x, rate)
		var tp := Loudness.true_peak_db(x, rate)
		var r1 := Loudness.band_share(x, rate, 330.0, 1200.0)
		var r2 := Loudness.band_share(x, rate, 2200.0, 3600.0)
		var hb := Loudness.band_share(x, rate, 250.0, 900.0)
		var combat := id == "hit" or id == "crit" or id == "trigger" or id.begins_with("hit_") or id.begins_with("cast_")
		var ring := _ring_ms(x, rate) if combat else 0.0
		var phone := Loudness.momentary_max(D.svf(D.svf2(x, "hp", 300.0), "lp", minf(12000.0, 0.45 * rate), 0.7071), rate) - m
		var prof := _octaves(x, rate)
		var dom := 0
		for b in prof.size():
			if prof[b] > prof[dom]:
				dom = b
		var dom_s := "%d-%d" % [int(OCT[dom][0]), int(OCT[dom][1])]
		if not quiet:
			print("%-24s %4s %6.1f %7.2f %6.2f %5.2f %5.2f %5.2f %6.0f %5.1f %-10s %4.0f" % [stem, fam, target, m, tp, r1, r2, hb, ring, phone, dom_s, ms])
		# DOG 1: family loudness
		var ok_l := absf(m - target) <= 1.0 or (tp >= -1.25 and m <= target and m >= target - 3.0)
		if not ok_l or m > target + 1.0:
			_fail("1 family loudness", "%s M %.2f target %.1f (TP %.2f)" % [stem, m, target, tp])
		# DOG 2: true peak
		if tp > -1.0:
			_fail("2 true peak", "%s TP %.2f" % [stem, tp])
		# DOG 4: phone translation and dominant band
		if fam in ["E", "A", "M"] and "loop" not in flags and phone < -3.0:
			_fail("4 phone loss (E/A/M)", "%s loses %.1f LU" % [stem, -phone])
		if OCT[dom][1] <= 200.0 or OCT[dom][0] >= 10000.0:
			_fail("4 dominant band", "%s dominant %s Hz" % [stem, dom_s])
		# DOG 5: slots
		if id.begins_with("tele") and r1 < 0.5:
			_fail("5 telegraph R1 >= 50%", "%s R1 %.2f" % [stem, r1])
		if id == "hurt" and hb < 0.5:
			_fail("5 hurt 250-900 >= 50%", "%s %.2f" % [stem, hb])
		var dense := (id == "hit" or id.begins_with("hit_") or id.begins_with("cast_")) and id not in R1_EXEMPT and suffix != "heavy"
		if dense and r1 > 0.15:
			_fail("5 chatter R1 <= 15%", "%s R1 %.2f" % [stem, r1])
		if id == "crit":
			if r2 < 0.45:
				_fail("5 crit R2 >= 45%", "%s R2 %.2f" % [stem, r2])
			if ring < 150.0:
				_fail("5 crit rings >= 150 ms", "%s ring %.0f ms" % [stem, ring])
		elif (id == "hit" or id.begins_with("hit_") or id.begins_with("cast_") or id == "trigger") and ring >= 150.0:
			_fail("5 only the crit rings in 2-4 kHz", "%s ring %.0f ms" % [stem, ring])
		# DOG 6: loops
		if "loop" in flags:
			# the seam step against the loop's own sample-to-sample steps: seamless when the step from
			# the last sample back to the first is no bigger than the loop's 99.9th-percentile step
			var s := D.seam(x)
			var steps := PackedFloat32Array()
			for k in range(1, x.size()):
				steps.append(absf(x[k] - x[k - 1]))
			steps.sort()
			var p999 := steps[int(steps.size() * 0.999)]
			var low := D.second_half(D.svf(D.twice(x), "lp", 500.0, 0.7071))
			var sl := D.seam(low)
			var lsteps := PackedFloat32Array()
			for k in range(1, low.size()):
				lsteps.append(absf(low[k] - low[k - 1]))
			lsteps.sort()
			var lp999 := lsteps[int(lsteps.size() * 0.999)]
			notes.append("loop %s: %d samples (%.3f s); seam step %.4f FS vs the loop's 99.9th-percentile step %.4f; under 500 Hz %.5f FS vs %.5f; RMS first/last 50 ms %.1f / %.1f dB; DC %.5f" % [stem, x.size(), ms / 1000.0, s["jump"], p999, sl["jump"], lp999, s["rms_first_db"], s["rms_last_db"], s["dc"]])
			if float(s["jump"]) > p999 or float(sl["jump"]) > lp999 or absf(float(s["rms_first_db"]) - float(s["rms_last_db"])) > 3.0 or absf(float(s["dc"])) > 0.002:
				_fail("6 loop seam", "%s" % stem)
		# DOG 12: lengths
		var cap := 2000.0 if fam == "M" else 1200.0
		if "tele" in flags or "loop" in flags:
			cap = 2100.0   # the 1.5 s telegraph masters and the 2 s trail loop are sized by design (§4.6)
		if ms > cap + 1.0:
			_fail("12 length", "%s %.0f ms" % [stem, ms])
		if suffix == "" or suffix.is_valid_int():
			if not sets.has(id):
				sets[id] = []
			(sets[id] as Array).append([prof, _peak_hz(x, rate)])
	# DOG 8 (effects half): every cue has its files
	for id: String in G.CUES:
		if not seen.has(id):
			_fail("8 coverage", "%s has no file" % id)
		elif (sets.get(id, []) as Array).size() != int(G.CUES[id][1]):
			_fail("8 coverage", "%s has %d variant files, expected %d" % [id, (sets.get(id, []) as Array).size(), int(G.CUES[id][1])])
	# DOG 9: variation
	var pairs := 0
	for id: String in sets:
		var ps: Array = sets[id]
		for i in ps.size():
			for j in range(i + 1, ps.size()):
				pairs += 1
				var best := 0.0
				var a: PackedFloat32Array = ps[i][0]
				var b: PackedFloat32Array = ps[j][0]
				for k in a.size():
					if maxf(a[k], b[k]) > -30.0:
						best = maxf(best, absf(a[k] - b[k]))
				var semis := absf(12.0 * log(float(ps[i][1]) / float(ps[j][1])) / log(2.0))
				if best < 2.0 and semis < 0.95:
					_fail("9 variation", "%s variants %d/%d differ by %.1f dB at most and %.2f semitones" % [id, i + 1, j + 1, best, semis])
	D.set_rate(44100)
	print("")
	for n_ in notes:
		print(n_)
	print("")
	print("SFX: %d cues, %d files, %.1f s of audio, %.2f MB WAV; %d variant pairs compared; report took %.1f s" % [G.CUES.size(), files.size(), secs, bytes / 1048576.0, pairs, (Time.get_ticks_msec() - t0) / 1000.0])
	for crit in ["1 family loudness", "2 true peak", "4 phone loss (E/A/M)", "4 dominant band", "5 telegraph R1 >= 50%", "5 hurt 250-900 >= 50%",
			"5 chatter R1 <= 15%", "5 crit R2 >= 45%", "5 crit rings >= 150 ms", "5 only the crit rings in 2-4 kHz", "6 loop seam", "8 coverage", "9 variation", "12 length"]:
		var list: Array = fails.get(crit, [])
		print("%-36s %s%s" % [crit, "PASS" if list.is_empty() else "FAIL (%d)" % list.size(), "" if list.is_empty() else ": " + "; ".join(list.slice(0, 12))])
	quit()


func _is_suffix(s: String) -> bool:
	return s == "heavy" or s.is_valid_int()


func _fail(crit: String, what: String) -> void:
	if not fails.has(crit):
		fails[crit] = []
	(fails[crit] as Array).append(what)


## The octave-band profile: each band's energy in dB relative to the whole file, from one FFT.
func _octaves(x: PackedFloat32Array, rate: int) -> PackedFloat32Array:
	var n := 1
	while n < x.size() and n < 131072:
		n *= 2
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(n)
	im.resize(n)
	for i in mini(n, x.size()):
		re[i] = x[i]
	_fft(re, im)
	var e := PackedFloat64Array()
	e.resize(OCT.size())
	var total := 0.0
	for k in range(1, n / 2):
		var f := float(k) * rate / n
		var pw := re[k] * re[k] + im[k] * im[k]
		total += pw
		for b in OCT.size():
			if f >= float(OCT[b][0]) and f < float(OCT[b][1]):
				e[b] += pw
				break
	var p := PackedFloat32Array()
	for b in OCT.size():
		p.append(10.0 * log(maxf(1e-12, e[b] / maxf(total, 1e-20))) / log(10.0))
	return p


## The body pitch: the strongest spectral peak between 150 Hz and 8 kHz (one FFT of the file),
## refined by parabolic interpolation, in Hz.
func _peak_hz(x: PackedFloat32Array, rate: int) -> float:
	var n := 1
	while n < x.size() and n < 131072:
		n *= 2
	n = maxi(n, 8192)
	var re := PackedFloat64Array()
	var im := PackedFloat64Array()
	re.resize(n)
	im.resize(n)
	for i in mini(n, x.size()):
		re[i] = x[i] * (0.5 - 0.5 * cos(TAU * (i + 0.5) / x.size()))
	_fft(re, im)
	var lo := int(150.0 * n / rate)
	var hi := mini(n / 2 - 2, int(8000.0 * n / rate))
	var best := lo
	var mags := PackedFloat64Array()
	mags.resize(n / 2)
	for k in range(lo - 1, hi + 2):
		mags[k] = sqrt(re[k] * re[k] + im[k] * im[k])
	for k in range(lo, hi):
		if mags[k] > mags[best]:
			best = k
	var a := log(maxf(mags[best - 1], 1e-12))
	var b := log(maxf(mags[best], 1e-12))
	var c := log(maxf(mags[best + 1], 1e-12))
	var d := 0.5 * (a - c) / (a - 2.0 * b + c) if absf(a - 2.0 * b + c) > 1e-12 else 0.0
	return (best + d) * rate / n


## The longest run of 10 ms STFT frames (1024-point Hann) whose 2-4 kHz energy stays above
## -30 dB relative to the loudest frame's full-band energy, in ms.
func _ring_ms(x: PackedFloat32Array, rate: int) -> float:
	var nf := 1024
	var hop := int(rate * 0.01)
	var k_lo := int(ceil(2000.0 * nf / rate))
	var k_hi := int(floor(4000.0 * nf / rate))
	var bands := PackedFloat64Array()
	var top := 0.0
	var start := -nf / 2
	while start < x.size():
		var re := PackedFloat64Array()
		var im := PackedFloat64Array()
		re.resize(nf)
		im.resize(nf)
		for i in nf:
			var j := start + i
			if j >= 0 and j < x.size():
				re[i] = x[j] * (0.5 - 0.5 * cos(TAU * (i + 0.5) / nf))
		_fft(re, im)
		var tot := 0.0
		var bd := 0.0
		for k in range(1, nf / 2):
			var pw := re[k] * re[k] + im[k] * im[k]
			tot += pw
			if k >= k_lo and k <= k_hi:
				bd += pw
		top = maxf(top, tot)
		bands.append(bd)
		start += hop
	var run := 0
	var best := 0
	for bd in bands:
		if bd > top * 0.001:
			run += 1
			best = maxi(best, run)
		else:
			run = 0
	return best * 10.0


## In-place iterative radix-2 FFT (the size is a power of two).
func _fft(re: PackedFloat64Array, im: PackedFloat64Array) -> void:
	var n := re.size()
	var j := 0
	for i in range(1, n):
		var bit := n >> 1
		while j & bit:
			j ^= bit
			bit >>= 1
		j |= bit
		if i < j:
			var tr := re[i]
			re[i] = re[j]
			re[j] = tr
			var ti := im[i]
			im[i] = im[j]
			im[j] = ti
	var size := 2
	while size <= n:
		var half := size / 2
		var ang := -TAU / size
		var wr := cos(ang)
		var wi := sin(ang)
		var s0 := 0
		while s0 < n:
			var cr := 1.0
			var ci := 0.0
			for k in half:
				var a := s0 + k
				var b := a + half
				var xr := re[b] * cr - im[b] * ci
				var xi := re[b] * ci + im[b] * cr
				re[b] = re[a] - xr
				im[b] = im[a] - xi
				re[a] += xr
				im[a] += xi
				var t := cr * wr - ci * wi
				ci = cr * wi + ci * wr
				cr = t
			s0 += size
		size *= 2
