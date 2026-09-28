#!/usr/bin/env bash
# Renders screenshots of the game under Xvfb (Mesa lavapipe for Vulkan) into shots/.
# Usage: tools/shots.sh [name args...]   e.g. tools/shots.sh combat --demo --frames=240
# With no arguments it renders the standard review set.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
GAME="$HERE/../game"
OUT="$HERE/../shots"
mkdir -p "$OUT"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1

shot() {
  local name="$1"; shift
  local res="${RES:-1440x810}"
  with_display -s "-screen 0 ${res}x24" \
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
# 0.19: the Workshop and its stations (a player with a few runs behind them)
shot workshop --screen=hub --runs=3 --wins=1 --bits=140 --frames=150
shot workshop-shop --screen=hub --runs=3 --bits=140 --at=pkg --frames=90
shot merchant --screen=pkg --runs=3 --bits=140 --frames=60
shot bounties --screen=board --runs=3 --frames=60
shot compendium --screen=docs --runs=3 --frames=60
RES=2556x1179 shot iphone-workshop --screen=hub --runs=3 --frames=150
