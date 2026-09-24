#!/usr/bin/env bash
# Regenerates every sound effect and music loop into game/assets/audio/ (see gen_audio.gd),
# then re-imports the project so Godot picks them up. Deterministic: run it twice, same bytes.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../game"
"$HERE/godot.sh" --headless --path "$GAME" -s "$HERE/gen_audio.gd"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true
ls "$GAME/assets/audio/"*.wav | wc -l | xargs echo "audio files:"
