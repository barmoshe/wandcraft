#!/usr/bin/env bash
# Builds the web version (single-threaded, runs in iPhone Safari) into build/web/.
#   tools/build_web.sh           export build/web/index.html (+ .wasm, .pck, PWA files)
# The Godot web export templates are fetched on first use into the local template folder
# (outside the repo). Hosting: see store/web-test.md (Vercel, static, no build step).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../game"
OUT="$HERE/../build/web"
VER="4.7.2"
TPL_DIR="$HOME/.local/share/godot/export_templates/${VER}.stable"
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
STAMP="$(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo dev)"
git -C "$HERE" diff --quiet HEAD -- "$GAME" 2>/dev/null || STAMP="$STAMP+"
sed -i "s|__WANDCRAFT_BUILD__|$STAMP|" "$OUT/index.html"
grep -q "wandcraftBuild = '$STAMP'" "$OUT/index.html" || { log "build stamp missing from index.html"; exit 1; }
log "build stamp: $STAMP"
log "done:"
ls -la "$OUT" | awk 'NR>1 {printf "  %10s  %s\n", $5, $9}'
