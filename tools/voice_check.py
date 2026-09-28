#!/usr/bin/env python3
"""Intelligibility check for the baked voices: Whisper (tiny.en, faster-whisper) transcribes
each file and we score its word accuracy against the line's text. A stand-in for "Bar
understands 5 of 5 lines without reading" (research/voices-plan.md), not a replacement.

  voice_check.py <dir> <lines.json|audition>   prints per-file accuracy and the mean per group
"""
import glob
import json
import os
import re
import sys
from difflib import SequenceMatcher

from faster_whisper import WhisperModel

MODEL = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".voice-models", "whisper")


def words(s):
    return re.sub(r"[^a-z0-9' ]", " ", s.lower().replace("-", " ")).split()


def acc(ref, hyp):
    return SequenceMatcher(None, words(ref), words(hyp)).ratio()


def main():
    d = sys.argv[1]
    try:
        m = WhisperModel("tiny.en", device="cpu", compute_type="int8", download_root=MODEL)
    except Exception as e:   # the model comes from huggingface.co on first use
        sys.exit("voice_check: can't load Whisper tiny.en into %s (%s: %s).\n"
                 "  It downloads from huggingface.co once; run where that host is reachable." % (MODEL, type(e).__name__, e))
    texts = {}
    if sys.argv[2] == "audition":
        # the audition's index.html pairs each file with its text
        for name, text in re.findall(r"src='([^']+)'></audio></td><td>([^<]*)</td>", open(os.path.join(d, "index.html")).read()):
            texts[name] = text
    else:
        for r in json.load(open(sys.argv[2])):
            texts[r["file"] + ".wav"] = r["text"]
    groups = {}
    for name, text in sorted(texts.items()):
        p = os.path.join(d, name)
        if not os.path.exists(p):
            continue
        segs, _ = m.transcribe(p, beam_size=1, language="en")
        hyp = " ".join(s.text for s in segs)
        a = acc(text, hyp)
        g = "_".join(name.split("_")[:4]) if sys.argv[2] == "audition" else name.split(".")[0].split("_")[0]
        groups.setdefault(g, []).append(a)
        if a < 0.75:
            print("  low %.2f  %s\n        said: %s\n       heard: %s" % (a, name, text, hyp.strip()))
    for g, v in sorted(groups.items()):
        print("%-28s %.2f  (%d files, %d under 0.75)" % (g, sum(v) / len(v), len(v), sum(1 for x in v if x < 0.75)))


if __name__ == "__main__":
    main()
