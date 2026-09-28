#!/usr/bin/env python3
"""Renders Wandcraft's voice lines (research/voices-plan.md).

Every line comes from Story (tools/export_lines.gd dumps it to JSON). Each is spoken by
Kokoro-82M (Apache-2.0, run through kokoro-onnx on CPU), then baked through its speaker's
chain, then normalised to the dialogue loudness, and written as mono 24 kHz 16-bit WAV to
game/assets/voice/<file>.wav. Godot imports it QOA-compressed (tools/voices.sh).

  DUCK  a warm voice, sped up a little and pitched up (varispeed), band-limited to a small
        speaker, a honk at 1.4 kHz, a slight vibrato.
  LINT  a deeper, slower voice through a 16-band channel vocoder on a 110 Hz saw (the
        monotone), a 50 Hz ring modulator, a short metallic comb, a 12 kHz / 9-bit crush.

  GREP    an older British voice, a semitone lower (varispeed), a slow age tremor, warm
          low mids, the top rolled off like an old reviewer's desk radio, a dry small room.
  HOTFIX  a playful voice, two semitones up and quick, a 3.5 ms tin comb, a 120 Hz buzz and
          a 10-bit / 12 kHz crush mixed in (a patched golem, still intelligible).
  CACHE   a soft voice, a little air on top, and a library: a pre-delayed, dark, 1.4 s
          reverb from a seeded noise tail.

The chains are baked because Godot has no vocoder or ring modulator and the web build
plays in sample mode, where bus effects don't run.

assets_src/voice/manifest.json keeps a hash of (text, voice, speed, chain, strength) per
line, so only changed lines render again.

  gen_voices.py <lines.json>                   render every line that changed
  gen_voices.py <lines.json> --audition <dir> [WHO ...]   6 lines each, 2 voices x 2 strengths
"""
import hashlib
import json
import os
import sys

import numpy as np
import pyloudnorm
import soundfile as sf
from scipy import signal

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MODELS = os.path.join(HERE, ".voice-models")
OUT = os.path.join(ROOT, "game", "assets", "voice")
MANIFEST = os.path.join(ROOT, "assets_src", "voice", "manifest.json")
SR = 24000
CHAIN_VERSION = 1
TARGET_LUFS = -18.0   # dialogue sits above the music's -20 (agree with the sound session)
PEAK = 10 ** (-1.0 / 20)   # -1 dBFS

# The picks (Bar may change them after the audition in shots/voice-audition/).
# `lang` (default en-us) is the phonemiser's accent; `semis` is a varispeed shift in the chain,
# which render() pre-compensates so the line still lands at `speed`.
CAST = {
    "DUCK": {"voice": "af_heart", "speed": 1.1, "strength": "light"},
    "LINT": {"voice": "am_fenrir", "speed": 0.92, "strength": "medium"},
    # the residents (0.20, research/world3-0.20.md section 3)
    "GREP": {"voice": "bm_george", "speed": 0.9, "strength": "light", "lang": "en-gb", "semis": -1.0},
    "HOTFIX": {"voice": "am_puck", "speed": 1.05, "strength": "light", "semis": 2.0},
    "CACHE": {"voice": "bf_emma", "speed": 0.95, "strength": "light", "lang": "en-gb"},
}
AUDITION = {
    "DUCK": ["af_heart", "af_bella"],
    "LINT": ["am_michael", "am_fenrir"],
    "GREP": ["bm_george", "bm_lewis"],
    "HOTFIX": ["am_puck", "am_echo"],
    "CACHE": ["bf_emma", "af_nicole"],
}


# ------------------------------------------------------------------ filters

def _sos_band(lo, hi, order=2):
    return signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")


def _peaking(x, f0, gain_db, q=1.0):
    a = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / SR
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w0), 1 - alpha * a]
    den = [1 + alpha / a, -2 * np.cos(w0), 1 - alpha / a]
    return signal.lfilter(b, den, x)


def _trim(x, thresh=0.01, pad=0.04):
    idx = np.where(np.abs(x) > thresh * np.max(np.abs(x) + 1e-9))[0]
    if len(idx) == 0:
        return x
    p = int(pad * SR)
    return x[max(0, idx[0] - p): min(len(x), idx[-1] + p)]


# ------------------------------------------------------------------ the Duck

def duck_chain(x, strength):
    full = strength == "full"
    semis = 4.0 if full else 3.0
    # varispeed: a little faster and higher, like a small throat (not a chipmunk)
    ratio = 2 ** (semis / 12)
    up, down = 100, int(round(100 * ratio))
    y = signal.resample_poly(x, up, down)
    # a small speaker: 250 Hz to 6 kHz, and the honk at 1.4 kHz
    y = signal.sosfilt(_sos_band(250, 6000), y)
    y = _peaking(y, 1400, 5.0 if full else 4.0, 1.2)
    # vibrato: a modulated delay, about a quarter of a semitone at 6 Hz
    n = np.arange(len(y))
    depth = (0.00045 if full else 0.0003) * SR
    d = depth * (1 + np.sin(2 * np.pi * 6.0 * n / SR))
    idx = np.clip(n - d, 0, len(y) - 1)
    y = np.interp(idx, n, y)
    return y


# ------------------------------------------------------------------ LINT

def lint_chain(x, strength):
    full = strength == "full"
    mid = strength == "medium"
    n = len(x)
    t = np.arange(n) / SR
    # the carrier: a band-limited 110 Hz saw (a monotone) plus a little noise for consonants
    f0 = 110.0
    carrier = np.zeros(n)
    for k in range(1, int((SR / 2) / f0)):
        carrier += np.sin(2 * np.pi * f0 * k * t) / k
    carrier = carrier / np.max(np.abs(carrier))
    carrier += 0.12 * np.random.default_rng(0).standard_normal(n)
    # a 16-band channel vocoder, 150 Hz to 7.5 kHz
    edges = np.geomspace(150, 7500, 17)
    env_lp = signal.butter(2, 45, btype="lowpass", fs=SR, output="sos")
    voc = np.zeros(n)
    for lo, hi in zip(edges[:-1], edges[1:]):
        sos = _sos_band(lo, hi)
        env = signal.sosfilt(env_lp, np.abs(signal.sosfilt(sos, x)))
        voc += signal.sosfilt(sos, carrier) * env
    voc *= np.sqrt(np.mean(x ** 2)) / (np.sqrt(np.mean(voc ** 2)) + 1e-9)
    wet = 0.7 if full else (0.55 if mid else 0.5)
    y = wet * voc + (1 - wet) * x
    # the ring modulator at 50 Hz (the classic robot)
    rm = 0.4 if full else (0.35 if mid else 0.25)
    y = y * (1 - rm) + y * np.sin(2 * np.pi * 50.0 * t) * rm
    # a 6 ms comb: metal
    dly = int(0.006 * SR)
    fb = 0.6 if full else (0.5 if mid else 0.4)
    a = np.zeros(dly + 1)
    a[0] = 1.0
    a[-1] = -fb
    y = signal.lfilter([1.0 - fb], a, y)
    # a 12 kHz sample-and-hold and 9 bits
    y = np.repeat(y[::2], 2)[:n]
    peak = np.max(np.abs(y)) + 1e-9
    y = np.round(y / peak * 255) / 255 * peak
    # lows off, then a gentle saturation as the compressor
    y = signal.sosfilt(signal.butter(2, 150, btype="highpass", fs=SR, output="sos"), y)
    y = np.tanh(1.5 * y / (np.max(np.abs(y)) + 1e-9)) / np.tanh(1.5)
    if mid:
        y = _peaking(y, 2800, 4.0, 0.9)   # presence: the consonants that tell "build" from "you'll"
    return y


# ------------------------------------------------------------------ the residents

def _varispeed(x, semis):
    if semis == 0:
        return x
    up = 100
    return signal.resample_poly(x, up, int(round(up * 2 ** (semis / 12))))


def _wobble(y, rate, depth_s):
    """A modulated delay: pitch vibrato of `depth_s` seconds at `rate` Hz."""
    n = np.arange(len(y))
    d = depth_s * SR * (1 + np.sin(2 * np.pi * rate * n / SR))
    return np.interp(np.clip(n - d, 0, len(y) - 1), n, y)


def _tail(y, sec):
    return np.concatenate([y, np.zeros(int(sec * SR))])


def _room(y, rt60, wet, predelay=0.0, dark=4000.0, seed=1):
    """A seeded noise-tail reverb: `rt60` seconds, low-passed at `dark` Hz."""
    n = int(rt60 * SR)
    t = np.arange(n) / SR
    ir = np.random.default_rng(seed).standard_normal(n) * np.exp(-6.9 * t / rt60)
    ir = signal.sosfilt(signal.butter(2, dark, btype="lowpass", fs=SR, output="sos"), ir)
    ir = np.concatenate([np.zeros(int(predelay * SR)), ir])
    x = _tail(y, rt60 + predelay)
    rev = signal.fftconvolve(x, ir)[: len(x)]
    rev *= np.sqrt(np.mean(y ** 2)) / (np.sqrt(np.mean(rev ** 2)) + 1e-9)
    return (1 - wet) * x + wet * rev


def grep_chain(x, strength):
    full = strength == "full"
    y = _varispeed(x, CAST["GREP"].get("semis", -1.0))
    # an old voice: a slow, small pitch tremor and a little amplitude waver
    y = _wobble(y, 4.5, 0.0005 if full else 0.00035)
    n = np.arange(len(y))
    y = y * (1 - (0.08 if full else 0.05) * (1 + np.sin(2 * np.pi * 5.2 * n / SR)) / 2)
    # warm and a bit dusty: lows under 90 Hz off, low mids up, the top rolled off at 6.5 kHz
    y = signal.sosfilt(signal.butter(2, [90, 6500 if full else 7500], btype="bandpass", fs=SR, output="sos"), y)
    y = _peaking(y, 260, 2.5, 0.8)
    y = _peaking(y, 2500, 2.0, 1.0)   # keep the consonants
    # a dry little room (his chair in the Workshop)
    y = _room(y, 0.35, 0.12 if full else 0.08, 0.008, 3000, seed=11)
    return np.tanh(1.2 * y / (np.max(np.abs(y)) + 1e-9)) / np.tanh(1.2)


def hotfix_chain(x, strength):
    full = strength == "full"
    y = _varispeed(x, CAST["HOTFIX"].get("semis", 2.0))
    n = len(y)
    t = np.arange(n) / SR
    # tin: a 3.5 ms comb, mixed in
    dly = int(0.0035 * SR)
    fb = 0.45 if full else 0.35
    a = np.zeros(dly + 1)
    a[0] = 1.0
    a[-1] = -fb
    comb = signal.lfilter([1.0 - fb], a, y)
    y = 0.6 * y + 0.4 * comb
    # a patched circuit: a light 120 Hz buzz
    rm = 0.18 if full else 0.12
    y = y * (1 - rm) + y * np.sin(2 * np.pi * 120.0 * t) * rm
    # a 12 kHz / 10-bit crush, blended so the words stay clear
    peak = np.max(np.abs(y)) + 1e-9
    crush = np.repeat(y[::2], 2)[:n]
    crush = np.round(crush / peak * 511) / 511 * peak
    mix = 0.5 if full else 0.35
    y = (1 - mix) * y + mix * crush
    y = signal.sosfilt(signal.butter(2, [160, 7500], btype="bandpass", fs=SR, output="sos"), y)
    y = _peaking(y, 2200, 3.0, 1.0)
    return np.tanh(1.6 * y / (np.max(np.abs(y)) + 1e-9)) / np.tanh(1.6)


def cache_chain(x, strength):
    full = strength == "full"
    y = signal.sosfilt(signal.butter(2, 110, btype="highpass", fs=SR, output="sos"), x)
    y = _peaking(y, 9000, 3.0, 0.7)   # air
    y = _peaking(y, 3000, 1.5, 1.0)
    # the library: tall shelves, a soft dark tail
    y = _room(y, 1.4, 0.32 if full else 0.24, 0.022, 3500, seed=7)
    # the tail fades out instead of stopping
    f = int(0.25 * SR)
    y[-f:] *= np.linspace(1, 0, f)
    return y


CHAINS = {"DUCK": duck_chain, "LINT": lint_chain, "GREP": grep_chain, "HOTFIX": hotfix_chain, "CACHE": cache_chain}


# ------------------------------------------------------------------ rendering

_kokoro = None


def kokoro():
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro
        _kokoro = Kokoro(os.path.join(MODELS, "kokoro-v1.0.onnx"), os.path.join(MODELS, "voices-v1.0.bin"))
    return _kokoro


def speak(text, voice, speed, lang="en-us"):
    audio, sr = kokoro().create(text, voice=voice, speed=speed, lang=lang)
    assert sr == SR, sr
    return np.asarray(audio, dtype=np.float64)


def loud(y):
    meter = pyloudnorm.Meter(SR, block_size=0.2)
    y = pyloudnorm.normalize.loudness(y, meter.integrated_loudness(y), TARGET_LUFS)
    p = np.max(np.abs(y))
    if p > PEAK:
        y = y * PEAK / p
    return y


def render(who, text, voice, speed, strength):
    # a varispeed chain changes the pace, so the line is spoken at a pace that lands at `speed`
    semis = (4.0 if strength == "full" else 3.0) if who == "DUCK" else CAST[who].get("semis", 0.0)
    s = speed / (2 ** (semis / 12))
    x = _trim(speak(text, voice, s, CAST[who].get("lang", "en-us")))
    y = _trim(CHAINS[who](x, strength), 0.004)
    return loud(y)


def line_hash(row, cast):
    parts = [row["text"], cast["voice"], cast["speed"], cast["strength"], row["who"], CHAIN_VERSION]
    # the newer knobs join the key only when set, so the Duck's and LINT's files keep their hashes
    parts += [[k, cast[k]] for k in ("lang", "semis") if k in cast]
    key = json.dumps(parts)
    return hashlib.sha1(key.encode()).hexdigest()[:16]


def main():
    lines = json.load(open(sys.argv[1]))
    if "--audition" in sys.argv:
        i = sys.argv.index("--audition")
        return audition(lines, sys.argv[i + 1], sys.argv[i + 2:] or list(CAST))
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(MANIFEST), exist_ok=True)
    man = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    keep = set()
    done = 0
    for row in lines:
        cast = CAST[row["who"]]
        h = line_hash(row, cast)
        path = os.path.join(OUT, row["file"] + ".wav")
        keep.add(row["file"])
        if man.get(row["file"], {}).get("hash") == h and os.path.exists(path):
            continue
        y = render(row["who"], row["text"], cast["voice"], cast["speed"], cast["strength"])
        sf.write(path, y.astype(np.float32), SR, subtype="PCM_16")
        man[row["file"]] = {"id": row["id"], "who": row["who"], "hash": h, "seconds": round(len(y) / SR, 2),
                            "voice": cast["voice"], "text": row["text"]}
        done += 1
        print("  %-34s %4.1f s  %s" % (row["file"], len(y) / SR, row["text"][:60]))
    # lines cut from Story lose their files
    for f in list(man):
        if f not in keep:
            p = os.path.join(OUT, f + ".wav")
            if os.path.exists(p):
                os.remove(p)
            man.pop(f)
    json.dump(dict(sorted(man.items())), open(MANIFEST, "w"), indent=1)
    total = sum(v["seconds"] for v in man.values())
    print("gen_voices: %d rendered, %d lines, %.0f s of speech" % (done, len(man), total))


def audition(lines, out, whos):
    os.makedirs(out, exist_ok=True)
    rows = []
    for who in whos:
        picks = [r for r in lines if r["who"] == who][:6]
        for voice in AUDITION[who]:
            for strength in ("light", "full"):
                for i, r in enumerate(picks):
                    y = render(who, r["text"], voice, CAST[who]["speed"], strength)
                    name = "%s_%s_%s_%d.wav" % (who.lower(), voice, strength, i)
                    sf.write(os.path.join(out, name), y.astype(np.float32), SR, subtype="PCM_16")
                    rows.append((who, voice, strength, name, r["text"]))
    html = ["<!doctype html><meta charset=utf-8><title>Voice audition</title>",
            "<style>body{font:14px system-ui;margin:24px;background:#141020;color:#eee}td{padding:4px 8px}</style>",
            "<h1>Wandcraft voice audition</h1><p>Picks now: %s.</p><table>" % ", ".join(
                "%s %s (%s)" % (w, CAST[w]["voice"], CAST[w]["strength"]) for w in whos)]
    for who, voice, strength, name, text in rows:
        html.append("<tr><td>%s</td><td>%s</td><td>%s</td><td><audio controls src='%s'></audio></td><td>%s</td></tr>" % (
            who, voice, strength, name, text))
    html.append("</table>")
    open(os.path.join(out, "index.html"), "w").write("\n".join(html))
    print("audition: %d files in %s" % (len(rows), out))


if __name__ == "__main__":
    main()
