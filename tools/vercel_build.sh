#!/usr/bin/env bash
# Builds the web version on Vercel's own build machine, for a git deployment of this repo to
# the "wandcraft-test" project (https://wandcraft-test.vercel.app). Used when no machine with
# a `vercel login` is at hand (a cloud session): Vercel clones the pushed commit, runs this,
# and serves build/web. The deployment's settings: build command `bash tools/vercel_build.sh`,
# output directory `build/web`, no install step. The usual route is still build_web.sh plus
# deploy_web.sh from the Mac (store/web-test.md).
# It fetches Godot and the web export templates (web only are kept), then runs build_web.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
VER="4.7.2"
CACHE="${TMPDIR:-/tmp}/wandcraft-godot"
TPL_DIR="$GODOT_TPL_ROOT/${VER}.stable"
BIN="$CACHE/Godot_v${VER}-stable_linux.x86_64"
mkdir -p "$CACHE" "$TPL_DIR"

log() { echo "[vercel_build] $*"; }

# unzip_some <zip> <dest> <glob>...: python's zipfile if there is a python, else unzip
unzip_some() {
  local zip="$1" dest="$2"
  shift 2
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$zip" "$dest" "$@" <<'PY'
import fnmatch, sys, zipfile
zip_path, dest, pats = sys.argv[1], sys.argv[2], sys.argv[3:]
with zipfile.ZipFile(zip_path) as z:
    for n in z.namelist():
        if not pats or any(fnmatch.fnmatch(n, p) for p in pats):
            z.extract(n, dest)
PY
  else
    unzip -o -q "$zip" "$@" -d "$dest"
  fi
}

if [ ! -x "$BIN" ]; then
  log "downloading Godot ${VER}"
  curl -sSfL -o "$CACHE/godot.zip" "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_linux.x86_64.zip"
  unzip_some "$CACHE/godot.zip" "$CACHE"
  chmod +x "$BIN"
  rm -f "$CACHE/godot.zip"
fi
"$BIN" --version

if [ ! -f "$TPL_DIR/web_nothreads_release.zip" ]; then
  log "downloading the export templates (web only are kept)"
  curl -sSfL -o "$CACHE/templates.tpz" "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_export_templates.tpz"
  unzip_some "$CACHE/templates.tpz" "$CACHE/tpl" 'templates/web_*' 'templates/version.txt'
  cp "$CACHE"/tpl/templates/web_* "$CACHE"/tpl/templates/version.txt "$TPL_DIR/"
  rm -rf "$CACHE/templates.tpz" "$CACHE/tpl"
fi

# the title's build stamp: Vercel's commit (there is no .git in its checkout)
export WANDCRAFT_STAMP="${VERCEL_GIT_COMMIT_SHA:0:7}"
[ -n "$WANDCRAFT_STAMP" ] || WANDCRAFT_STAMP="vercel"
GODOT="$BIN" bash "$HERE/build_web.sh"
cp "$HERE/web/vercel.json" "$HERE/../build/web/" 2>/dev/null || true
log "done"
