#!/usr/bin/env bash
# App Store screenshots for the 6.9-inch iPhone (2868 x 1320 landscape) into store/screenshots/.
# Each scene renders at exactly half that size and is doubled with nearest-neighbour, so the
# pixel art stays crisp (the same whole pixels a phone shows, only bigger).
#   tools/store_shots.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
OUT="$HERE/../store/screenshots"
mkdir -p "$OUT"
export RES=1434x660
scene() {
  local name="$1"; shift
  "$HERE/shots.sh" "store_$name" "$@" >/dev/null
  cp "$HERE/../shots/store_$name.png" "$OUT/$name-half.png" 2>/dev/null || echo "FAILED $name"
}
scene 1-combat --showcase --wand=2 --frames=240 --seed=4
scene 2-boss --demo --kind=boss --step=8 --loadout=strong --frames=900 --seed=4
scene 3-editor --screen=editor --loadout=strong --frames=30
scene 4-copy-paste --demo --kind=mini --step=4 --loadout=strong --frames=330 --seed=6
scene 5-reward --screen=reward --offer=spell --frames=30 --seed=3
scene 6-map --screen=map --frames=30 --seed=3
"$HERE/godot.sh" --headless --path "$HERE/../game" -s "$HERE/lib/upscale.gd" -- "$OUT" 2 >/dev/null 2>&1
rm -f "$OUT"/*-half.png
ls -la "$OUT"
