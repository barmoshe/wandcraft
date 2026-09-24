#!/usr/bin/env bash
# World 1 balance guardrail: the bot plays without god mode over several seeds and reports
# survival, HP lost and boss kill times (tests/bench/test_balance.gd). Slow (a few minutes),
# so it is not part of tools/test.sh. Record results in research/balance-w1.md.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/godot.sh" --headless --path "$HERE/../game" -s res://tests/run_tests.gd -- --dir=bench "$@" 2>&1 | grep -vE "^Godot|^$"
