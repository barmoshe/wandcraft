#!/usr/bin/env bash
# Regenerates the app icon set and splash from the game's pixel art (see gen_icon.gd).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
"$HERE/godot.sh" --headless --path "$HERE/../game" -s "$HERE/gen_icon.gd"
"$HERE/godot.sh" --headless --path "$HERE/../game" --import >/dev/null 2>&1 || true
