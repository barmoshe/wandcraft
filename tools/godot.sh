#!/usr/bin/env bash
# Resolves the Godot binary: $GODOT, then the first 4.7 found among `godot` on PATH, the
# Mac app bundles and the dev-container download. Another version on PATH (a Mac with an
# older Godot.app) is skipped, because the export templates and project are 4.7.2.
set -euo pipefail
if [[ -n "${GODOT:-}" ]]; then exec "$GODOT" "$@"; fi
for c in "$HOME/Applications/Godot_v4.7.2.app/Contents/MacOS/Godot" /Applications/Godot_v4.7.2.app/Contents/MacOS/Godot \
         "$(command -v godot || true)" /tmp/claude-0/*/*/scratchpad/godot/Godot_v4.7.2-stable_linux.x86_64 \
         "$HOME/.local/bin/godot" /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -n "$c" && -x "$c" ]] && "$c" --version 2>/dev/null | grep -q '^4\.7'; then exec "$c" "$@"; fi
done
echo "Godot 4.7.x not found. Set GODOT=/path/to/the Godot 4.7.2 binary" >&2
exit 127
