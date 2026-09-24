#!/usr/bin/env bash
# Renders screenshots of the game under Xvfb (Mesa lavapipe for Vulkan) into shots/.
# Usage: tools/shots.sh [name args...]   e.g. tools/shots.sh combat --demo --frames=240
# With no arguments it renders the standard review set.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../game"
OUT="$HERE/../shots"
mkdir -p "$OUT"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1

shot() {
  local name="$1"; shift
  local res="${RES:-1440x810}"
  xvfb-run -a -s "-screen 0 ${res}x24" \
    "$HERE/godot.sh" --path "$GAME" --resolution "$res" --rendering-method "${RENDERER:-mobile}" -- \
    --shot="$OUT/$name.png" "$@" > "$OUT/$name.log" 2>&1
  if [ -f "$OUT/$name.png" ]; then echo "shots/$name.png"; else echo "FAILED $name (see shots/$name.log)"; fi
}

if [ $# -gt 0 ]; then shot "$@"; exit; fi
shot start --frames=40
shot combat --demo --frames=420 --seed=3
shot combat-cross --demo --frames=360 --room=cross --seed=5
shot treasure --kind=treasure --frames=60
RES=2556x1179 shot iphone-touch --demo --frames=300 --touchdemo --room=pillars
