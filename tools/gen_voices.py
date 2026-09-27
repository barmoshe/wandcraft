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

The chains are baked because Godot has no vocoder or ring modulator and the web build
plays in sample mode, where bus effects don't run.

assets_src/voice/manifest.json keeps a hash of (text, voice, speed, chain, strength) per
line, so only changed lines render again.

  gen_voices.py <lines.json>                   render every line that changed
  gen_voices.py <lines.json> --audition <dir>  6 lines each, 2 voices x 2 strengths
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
CAST = {
    "DUCK": {"voice": "af_heart", "speed": 1.1, "strength": "light"},
    "LINT": {"voice": "am_fenrir", "speed": 0.92, "strength": "medium"},
}
AUDITION = {
    "DUCK": ["af_heart", "af_bella"],
    "LINT": ["am_michael", "am_fenrir"],
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


CHAINS = {"DUCK": duck_chain, "LINT": lint_chain}


# ------------------------------------------------------------------ rendering

_kokoro = None


def kokoro():
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro
        _kokoro = Kokoro(os.path.join(MODELS, "kokoro-v1.0.onnx"), os.path.join(MODELS, "voices-v1.0.bin"))
    return _kokoro


def speak(text, voice, speed):
    audio, sr = kokoro().create(text, voice=voice, speed=speed, lang="en-us")
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
    # the Duck's varispeed speeds it up, so it is spoken slower to land at `speed`
    s = speed / (2 ** ((4.0 if strength == "full" else 3.0) / 12)) if who == "DUCK" else speed
    x = _trim(speak(text, voice, s))
    y = _trim(CHAINS[who](x, strength), 0.004)
    return loud(y)


def line_hash(row, cast):
    key = json.dumps([row["text"], cast["voice"], cast["speed"], cast["strength"], row["who"], CHAIN_VERSION])
    return hashlib.sha1(key.encode()).hexdigest()[:16]


def main():
    lines = json.load(open(sys.argv[1]))
    if "--audition" in sys.argv:
        return audition(lines, sys.argv[sys.argv.index("--audition") + 1])
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


def audition(lines, out):
    os.makedirs(out, exist_ok=True)
    rows = []
    for who in ("DUCK", "LINT"):
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
            "<h1>Wandcraft voice audition</h1><p>Picks now: DUCK %s (%s), LINT %s (%s).</p><table>" % (
                CAST["DUCK"]["voice"], CAST["DUCK"]["strength"], CAST["LINT"]["voice"], CAST["LINT"]["strength"])]
    for who, voice, strength, name, text in rows:
        html.append("<tr><td>%s</td><td>%s</td><td>%s</td><td><audio controls src='%s'></audio></td><td>%s</td></tr>" % (
            who, voice, strength, name, text))
    html.append("</table>")
    open(os.path.join(out, "index.html"), "w").write("\n".join(html))
    print("audition: %d files in %s" % (len(rows), out))


if __name__ == "__main__":
    main()
