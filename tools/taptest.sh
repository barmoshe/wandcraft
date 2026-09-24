#!/usr/bin/env bash
# Real-input menu test under Xvfb: taps menu buttons with touch events in a phone-sized
# window, plain and after a portrait-to-landscape rotation. Needs xvfb-run.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../game"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1
code=0
for mode in "" "--rotate"; do
  echo "== taptest ${mode:-landscape}"
  LOG="$(mktemp)"
  xvfb-run -a -s "-screen 0 2400x2400x24" \
    "$HERE/godot.sh" --path "$GAME" --resolution 2340x1080 --rendering-method mobile \
    res://tests/input/tap_test.tscn -- $mode 2>&1 | tee "$LOG" | grep -E "TAPTEST|  ok|  FAIL|window|SCRIPT ERROR|ERROR"
  grep -q "TAPTEST: PASS" "$LOG" || code=1
  grep -qE "SCRIPT ERROR|Parse Error" "$LOG" && code=1
  rm -f "$LOG"
done
exit $code
