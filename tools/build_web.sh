#!/usr/bin/env bash
# Builds the web version (single-threaded, runs in iPhone Safari) into build/web/.
#   tools/build_web.sh           export build/web/index.html (+ .wasm, .pck, PWA files)
# The wasm, pck and engine scripts get content-hashed names (index-<hash>.*), so they can be
# cached for good; index.html points at them and is revalidated on every launch.
# The Godot web export templates are fetched on first use into the local template folder
# (outside the repo). Hosting: see store/web-test.md (Vercel, static, no build step).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
GAME="$HERE/../game"
OUT="$HERE/../build/web"
VER="4.7.2"
TPL_DIR="$GODOT_TPL_ROOT/${VER}.stable"
CACHE="${WANDCRAFT_BUILD_CACHE:-$HOME/.cache/wandcraft-build}"

log() { echo "[build_web] $*"; }

if [ ! -f "$TPL_DIR/web_nothreads_release.zip" ]; then
  log "downloading the Godot ${VER} export templates (web only are kept)"
  mkdir -p "$CACHE/tpl" "$TPL_DIR"
  curl -sSfL -o "$CACHE/templates.tpz" "https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_export_templates.tpz"
  unzip -o -q "$CACHE/templates.tpz" 'templates/web_*' 'templates/version.txt' -d "$CACHE/tpl"
  cp "$CACHE"/tpl/templates/web_* "$CACHE"/tpl/templates/version.txt "$TPL_DIR/"
  rm -f "$CACHE/templates.tpz"
fi

rm -rf "$OUT"
mkdir -p "$OUT"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true
log "exporting to $OUT"
"$HERE/godot.sh" --headless --path "$GAME" --export-release "Web" "$OUT/index.html" 2>&1 | tee "$OUT/../web-export.log" | grep -E "ERROR|error" || true
[ -f "$OUT/index.html" ] && [ -f "$OUT/index.wasm" ] || { log "export failed, see build/web-export.log"; exit 1; }

# Home Screen app files (the engine's PWA export is off: no service worker, decisions/0008),
# the kill switch for the old worker, and the build stamp the title shows.
cp "$HERE/web/index.manifest.json" "$HERE/web/index.service.worker.js" "$OUT/"
for n in 144 180 512; do cp "$GAME/assets/icon/pwa_$n.png" "$OUT/index.${n}x${n}.png"; done
# WANDCRAFT_STAMP: a stamp from outside (tools/vercel_build.sh, whose checkout has no .git)
if [ -n "${WANDCRAFT_STAMP:-}" ]; then
  STAMP="$WANDCRAFT_STAMP"
else
  STAMP="$(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo dev)"
  git -C "$HERE" diff --quiet HEAD -- "$GAME" 2>/dev/null || STAMP="$STAMP+"
fi
sed_inplace "s|__WANDCRAFT_BUILD__|$STAMP|" "$OUT/index.html"
grep -q "wandcraftBuild = '$STAMP'" "$OUT/index.html" || { log "build stamp missing from index.html"; exit 1; }
log "build stamp: $STAMP"

# Content-hashed names, so phones can cache the big files for a year (tools/web/vercel.json):
#   index-<engine>.wasm/.js/.audio*.worklet.js   hash of the engine files (changes with Godot)
#   index-<pack>.pck                              hash of the pck (changes with the game)
# The loader derives the wasm and worklet names from GODOT_CONFIG.executable, and the pck
# from GODOT_CONFIG.mainPack. index.html keeps its name and is never cached (no-cache).
ENGINE_FILES=(index.wasm index.js index.audio.worklet.js index.audio.position.worklet.js)
for f in "${ENGINE_FILES[@]}" index.pck; do [ -f "$OUT/$f" ] || { log "missing $f after export"; exit 1; }; done
EH="$(cd "$OUT" && sha256 <(cat "${ENGINE_FILES[@]}") | cut -c1-8)"
PH="$(sha256 "$OUT/index.pck" | cut -c1-8)"
for f in "${ENGINE_FILES[@]}"; do mv "$OUT/$f" "$OUT/index-$EH${f#index}"; done
mv "$OUT/index.pck" "$OUT/index-$PH.pck"
sed_inplace -e "s|\"executable\":\"index\"|\"executable\":\"index-$EH\",\"mainPack\":\"index-$PH.pck\"|" \
  -e "s|\"index\\.wasm\":|\"index-$EH.wasm\":|" -e "s|\"index\\.pck\":|\"index-$PH.pck\":|" \
  -e "s|<script src=\"index\\.js\">|<script src=\"index-$EH.js\">|" "$OUT/index.html"
for want in "\"executable\":\"index-$EH\"" "\"mainPack\":\"index-$PH.pck\"" "\"index-$EH.wasm\":" \
            "\"index-$PH.pck\":" "<script src=\"index-$EH.js\">"; do
  grep -qF "$want" "$OUT/index.html" || { log "index.html lacks $want (did the shell or Godot change?)"; exit 1; }
done
log "hashed names: engine index-$EH, pack index-$PH.pck"
log "done:"
ls -la "$OUT" | awk 'NR>1 {printf "  %10s  %s\n", $5, $9}'
