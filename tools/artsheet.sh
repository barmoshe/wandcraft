#!/usr/bin/env bash
# Renders art contact sheets (every sprite, frame, icon and tile at 4x) to shots/.
# Usage: tools/artsheet.sh [chars|icons|tiles|fx|ui|all] [-- --only=label --scale=8]
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
GAME="$HERE/../game"
OUT="$(cd "$HERE/.." && pwd)/shots"
mkdir -p "$OUT"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1
EXTRA=()
SHEETS=()
seen_dd=0
for a in "$@"; do
  if [ "$a" = "--" ]; then seen_dd=1; continue; fi
  if [ $seen_dd = 1 ]; then EXTRA+=("$a"); else SHEETS+=("$a"); fi
done
[ ${#SHEETS[@]} -eq 0 ] && SHEETS=(all)
for s in "${SHEETS[@]}"; do
  with_display -s "-screen 0 1920x2400x24" \
    "$HERE/godot.sh" --path "$GAME" --resolution 1800x2300 --rendering-method mobile \
    res://tests/art/artsheet.tscn -- --sheet="$s" --out="$OUT" ${EXTRA[@]+"${EXTRA[@]}"} 2>&1 | grep -E "artsheet:|SCRIPT ERROR|Parse Error" || true
done
