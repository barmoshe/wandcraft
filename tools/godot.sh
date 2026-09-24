#!/usr/bin/env bash
# Resolves the Godot binary: $GODOT, then `godot` on PATH, then the dev-container download.
set -euo pipefail
if [[ -n "${GODOT:-}" ]]; then exec "$GODOT" "$@"; fi
if command -v godot >/dev/null 2>&1; then exec godot "$@"; fi
for c in /tmp/claude-0/*/*/scratchpad/godot/Godot_v4.7.2-stable_linux.x86_64 "$HOME/.local/bin/godot" \
         /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$c" ]]; then exec "$c" "$@"; fi
done
echo "Godot 4.7.2 not found. Set GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64" >&2
exit 127
