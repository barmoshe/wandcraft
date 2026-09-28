#!/usr/bin/env python3
"""Encodes the music masters to Ogg Vorbis, the files the game ships (ADR 0034).

Run by tools/audio.sh after tools/gen_music.gd:
    encode_music.py <masters dir> <game audio dir> <loops file>

- Reads every music_*.wav master (build/music_wav/, git-ignored) and the LOOP lines
  gen_music printed ("LOOP|<file>|loop_begin=<n>|loop_end=<n>").
- Writes game/assets/audio/<file>.ogg: frames [0, loop_end), so the guard sample the WAV
  loop needed is dropped. The engine loops an Ogg by decoding to its end and seeking to
  loop_offset, so the resampler sees continuous audio and needs no guard.
- Prints one "OGG|<file>|loop_offset=<seconds>|kbps=<n>|peak=<dBFS>" line per file.
  tools/audio.sh writes loop=true and that loop_offset into the .ogg.import files.
- Deletes a stale <file>.wav (and its .import) in the game audio dir: the WAV music does
  not ship any more.

Vorbis quality 4 (libsndfile's compression level 0.6, its default). Deterministic: the
libvorbis encoder is, and the Ogg stream serial number (random in libsndfile) is replaced
by a CRC of the file name, with every page checksum redone. Same masters, same bytes, on
the same libsndfile build (tools/requirements-audio.txt pins it).
"""
import io
import os
import re
import struct
import sys
import zlib

import numpy as np
import soundfile as sf

QUALITY = 0.4          # Vorbis quality 4 on libvorbis's -0.1..1.0 scale
BLOCK = 8192           # libsndfile's Vorbis writer crashes on very large single writes


def _crc_table():
    table = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else (r << 1)
        table.append(r & 0xFFFFFFFF)
    return table


_CRC = _crc_table()


def _ogg_crc(data):
    c = 0
    for b in data:
        c = ((c << 8) & 0xFFFFFFFF) ^ _CRC[((c >> 24) ^ b) & 0xFF]
    return c


def set_serial(data, serial):
    """Rewrites every Ogg page's stream serial number and redoes its checksum."""
    out = bytearray(data)
    p = 0
    while p < len(out):
        if out[p:p + 4] != b"OggS":
            raise ValueError("not an Ogg page at byte %d" % p)
        nseg = out[p + 26]
        end = p + 27 + nseg + sum(out[p + 27:p + 27 + nseg])
        struct.pack_into("<I", out, p + 14, serial)
        struct.pack_into("<I", out, p + 22, 0)
        struct.pack_into("<I", out, p + 22, _ogg_crc(out[p:end]))
        p = end
    return bytes(out)


def encode(x, rate):
    buf = io.BytesIO()
    channels = 1 if x.ndim == 1 else x.shape[1]
    with sf.SoundFile(buf, "w", samplerate=rate, channels=channels, format="OGG", subtype="VORBIS",
                      compression_level=1.0 - QUALITY) as f:
        for i in range(0, len(x), BLOCK):
            f.write(x[i:i + BLOCK])
    return buf.getvalue()


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    masters, out_dir, loops_file = sys.argv[1:]
    loops = {}
    with open(loops_file, encoding="utf-8") as f:
        for line in f:
            m = re.match(r"^LOOP\|([^|]+)\|loop_begin=(\d+)\|loop_end=(\d+)", line.strip())
            if m:
                loops[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    names = sorted(n[:-4] for n in os.listdir(masters) if n.startswith("music_") and n.endswith(".wav"))
    done = 0
    for name in names:
        if name not in loops:
            continue   # not rendered this run (ONLY=...): its .ogg stays as it is
        lb, le = loops[name]
        x, rate = sf.read(os.path.join(masters, name + ".wav"), dtype="int16")
        if len(x) != le + 1:
            sys.exit("%s: %d frames, expected loop_end + 1 guard = %d" % (name, len(x), le + 1))
        x = x[:le]
        data = set_serial(encode(x, rate), zlib.crc32(name.encode()))
        with open(os.path.join(out_dir, name + ".ogg"), "wb") as f:
            f.write(data)
        y, _ = sf.read(io.BytesIO(data), dtype="float32")
        if len(y) != le:
            sys.exit("%s: the Ogg decodes to %d frames, not %d" % (name, len(y), le))
        peak = 20.0 * np.log10(max(float(np.max(np.abs(y))), 1e-9))
        kbps = len(data) * 8.0 / (le / rate) / 1000.0
        # the engine seeks to int(loop_offset * rate): make sure that lands on loop_begin
        offset = "%.9g" % (lb / rate)
        if int(float(offset) * rate) != lb:
            offset = "%.12g" % ((lb + 0.25) / rate)
        print("OGG|%s|loop_offset=%s|kbps=%.0f|peak=%.2f" % (name, offset, kbps, peak))
        for stale in (name + ".wav", name + ".wav.import"):
            p = os.path.join(out_dir, stale)
            if os.path.exists(p):
                os.remove(p)
        done += 1
    print("encode_music: %d files" % done)


if __name__ == "__main__":
    main()
