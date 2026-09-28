#!/usr/bin/env bash
# The voices (research/voices-plan.md): exports every line from Story, renders the ones that
# changed with Kokoro-82M plus each speaker's baked chain (tools/gen_voices.py), imports them
# QOA-compressed, and writes the licence rows (assets_src/voice/LICENSES.csv).
# One-time setup: a venv in tools/.venv-voice and the model in tools/.voice-models (both
# git-ignored, about 380 MB). Runs on CPU; a full render takes about 2 minutes.
#   tools/voices.sh              render what changed
#   tools/voices.sh --audition [WHO ...]   6 lines each in 2 voices x 2 strengths, into
#                                shots/voice-audition (every speaker, or only the tags named)
#   tools/voices.sh --check      Whisper transcribes every line (tools/voice_check.py)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
ROOT="$HERE/.."
GAME="$ROOT/game"
VENV="$HERE/.venv-voice"
MODELS="$HERE/.voice-models"
REL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1"

if [ ! -x "$VENV/bin/python" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q --upgrade pip
  "$VENV/bin/pip" install -q kokoro-onnx soundfile numpy scipy pyloudnorm faster-whisper
fi
mkdir -p "$MODELS"
[ -f "$MODELS/kokoro-v1.0.onnx" ] || curl -sSL -o "$MODELS/kokoro-v1.0.onnx" "$REL/kokoro-v1.0.onnx"
[ -f "$MODELS/voices-v1.0.bin" ] || curl -sSL -o "$MODELS/voices-v1.0.bin" "$REL/voices-v1.0.bin"

mkdir -p "$ROOT/build"
LINES="$ROOT/build/voice_lines.json"
"$HERE/godot.sh" --headless --path "$GAME" -s "$HERE/export_lines.gd" -- "$LINES" | grep -v "^Godot\|^$"

case "${1:-}" in
  --audition) exec "$VENV/bin/python" "$HERE/gen_voices.py" "$LINES" --audition "$ROOT/shots/voice-audition" "${@:2}" ;;
  --check) exec "$VENV/bin/python" "$HERE/voice_check.py" "$GAME/assets/voice" "$LINES" ;;
esac

"$VENV/bin/python" "$HERE/gen_voices.py" "$LINES"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true
# speech ships mono at 22.05 kHz (0.22 speed-and-size: the renders are 24 kHz; the top
# 11-12 kHz carries nothing a phone speaker plays), QOA-compressed, never looped
for f in "$GAME"/assets/voice/*.wav.import; do
  sed_inplace -e "s/^edit\/loop_mode=.*/edit\/loop_mode=1/" -e "s/^compress\/mode=.*/compress\/mode=2/" \
    -e "s/^force\/mono=.*/force\/mono=true/" -e "s/^force\/max_rate=.*/force\/max_rate=true/" \
    -e "s/^force\/max_rate_hz=.*/force\/max_rate_hz=22050/" "$f"
done
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true

# the licence rows: every voice file is Kokoro output (Apache-2.0 model and voices)
LIC="$ROOT/assets_src/voice/LICENSES.csv"
{
  echo "file,title,source,license,author,credit_required"
  for w in "$GAME"/assets/voice/*.wav; do
    b="$(basename "$w")"
    echo "$b,voice ${b%.wav},tools/gen_voices.py (Kokoro-82M via kokoro-onnx),Apache-2.0 model; output original,Bar Moshe (generated with Kokoro-82M),yes"
  done
} > "$LIC"
echo "voices: $(ls "$GAME"/assets/voice/*.wav | wc -l | tr -d ' ') files, $(du -sh "$GAME/assets/voice" | cut -f1) of WAV"
