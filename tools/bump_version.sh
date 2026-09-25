#!/usr/bin/env bash
# Sets the game version everywhere it lives and bumps the store build number by one.
#   tools/bump_version.sh 0.11.0
# project.godot (config/version), the Android preset (version/name, version/code) and the
# iOS preset (application/short_version, application/version) stay in step.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
VER="${1:?usage: tools/bump_version.sh X.Y.Z}"
GAME="$HERE/../game"
CODE=$(( $(grep '^version/code=' "$GAME/export_presets.cfg" | cut -d= -f2) + 1 ))
sed_inplace "s/^config\/version=\".*\"/config\/version=\"$VER\"/" "$GAME/project.godot"
sed_inplace "s/^version\/name=\".*\"/version\/name=\"$VER\"/; s/^version\/code=.*/version\/code=$CODE/" "$GAME/export_presets.cfg"
sed_inplace "s/^application\/short_version=\".*\"/application\/short_version=\"$VER\"/; s/^application\/version=\".*\"/application\/version=\"$CODE\"/" "$GAME/export_presets.cfg"
echo "version $VER, build $CODE"
