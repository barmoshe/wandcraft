#!/usr/bin/env bash
# The web download, measured: index.wasm and index.pck as shipped and compressed (gzip -9,
# and brotli when a `brotli` CLI or python module is at hand), then the pck's contents by
# folder, read from the pck's own directory (Godot 4.7 pack format v4) and mapped back to
# the source folders through the .import files.
#   tools/size_report.sh            report build/web (builds it first if it is missing)
#   tools/size_report.sh --build    rebuild build/web (tools/build_web.sh), then report
#   tools/size_report.sh --no-build report only; fails if there is no build/web
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
GAME="$ROOT/game"
WEB="$ROOT/build/web"

mode="${1:-}"
case "$mode" in
  --build) bash "$HERE/build_web.sh" >/dev/null ;;
  --no-build) [ -f "$WEB/index.pck" ] || { echo "no build/web/index.pck (run tools/build_web.sh)" >&2; exit 1; } ;;
  "") [ -f "$WEB/index.pck" ] || bash "$HERE/build_web.sh" >/dev/null ;;
  *) sed -n '2,8p' "$0"; exit 2 ;;
esac

python3 - "$WEB" "$GAME" <<'PY'
import collections, glob, gzip, os, re, shutil, struct, subprocess, sys

web, game = sys.argv[1], sys.argv[2]
MB = 1e6

def gz(path):
    with open(path, "rb") as f:
        return len(gzip.compress(f.read(), 9))

def br(path):
    if shutil.which("brotli"):
        out = subprocess.run(["brotli", "-c", "-q", "11", path], capture_output=True, check=True)
        return len(out.stdout)
    try:
        import brotli
    except ImportError:
        return None
    with open(path, "rb") as f:
        return len(brotli.compress(f.read(), quality=11))

def fmt(n):
    return "     n/a" if n is None else "%8.2f" % (n / MB)

# the shipped files
print("web build: %s" % web)
print("%-12s %8s %8s %8s" % ("file", "MB", "gzip-9", "brotli"))
tot = [0, 0, 0]
for name in ("index.wasm", "index.pck"):
    p = os.path.join(web, name)
    raw, g, b = os.path.getsize(p), gz(p), br(p)
    tot = [tot[0] + raw, tot[1] + g, None if (b is None or tot[2] is None) else tot[2] + b]
    print("%-12s %s %s %s" % (name, fmt(raw), fmt(g), fmt(b)))
print("%-12s %s %s %s" % ("total", fmt(tot[0]), fmt(tot[1]), fmt(tot[2])))
if tot[2] is None:
    print("(brotli: no `brotli` CLI or python module here)")

# the pck's directory (format v4: header, then the directory at dir_offset)
data = open(os.path.join(web, "index.pck"), "rb").read()
magic, fmt_ver = data[:4], struct.unpack_from("<I", data, 4)[0]
if magic != b"GDPC" or fmt_ver < 3:
    sys.exit("unexpected pck header %r v%d" % (magic, fmt_ver))
dir_ofs = struct.unpack_from("<Q", data, 32)[0]
count = struct.unpack_from("<I", data, dir_ofs)[0]
p = dir_ofs + 4
entries = []
for _ in range(count):
    n = struct.unpack_from("<I", data, p)[0]; p += 4
    path = data[p:p + n].rstrip(b"\0").decode(); p += n
    _ofs, size = struct.unpack_from("<QQ", data, p); p += 16 + 16 + 4   # offset, size, md5, flags
    entries.append((path.removeprefix("res://"), size))

# imported file -> its source, from every .import file
src_of = {}
for imp in glob.glob(os.path.join(game, "**", "*.import"), recursive=True):
    if "/.godot/" in imp:
        continue
    text = open(imp, encoding="utf-8").read()
    m = re.search(r'^source_file="res://(.*)"', text, re.M)
    if not m:
        continue
    for dest in re.findall(r'"res://(\.godot/imported/[^"]+)"', text):
        src_of[dest] = m.group(1)

def folder(path):
    src = src_of.get(path, path)
    base = os.path.basename(src)
    if src.startswith("assets/voice/"):
        return "voice"
    if src.startswith("assets/audio/"):
        if base.startswith("music_"):
            return "audio/music"
        if base.startswith("sting_"):
            return "audio/sting"
        return "audio/sfx"
    if src.startswith(("assets/icon/", "assets/fonts/")):
        return "art (icons, fonts)"
    if src.endswith((".gd", ".gdc")) or src.startswith("scripts/"):
        return "scripts"
    return "other"

by = collections.defaultdict(lambda: [0, 0])
for path, size in entries:
    k = folder(path)
    by[k][0] += size
    by[k][1] += 1
header = len(data) - sum(s for _, s in entries)
order = ["voice", "audio/music", "audio/sting", "audio/sfx", "art (icons, fonts)", "scripts", "other"]
print("\nindex.pck by folder (%d files)" % count)
print("%-20s %8s %6s %6s" % ("folder", "MB", "files", "%"))
for k in order:
    if k in by:
        print("%-20s %8.2f %6d %5.1f%%" % (k, by[k][0] / MB, by[k][1], 100.0 * by[k][0] / len(data)))
print("%-20s %8.2f %6s %5.1f%%" % ("pck header+dir", header / MB, "", 100.0 * header / len(data)))
print("%-20s %8.2f %6d" % ("total", len(data) / MB, count))
print("\nlargest files:")
for path, size in sorted(entries, key=lambda e: -e[1])[:5]:
    print("  %6.2f MB  %s" % (size / MB, src_of.get(path, path)))
PY
