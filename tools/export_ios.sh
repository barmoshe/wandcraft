#!/usr/bin/env bash
# Exports the iOS Xcode project for a TEST build on your own iPhone (no App Store).
# Runs on the Mac. Guide: store/ios-test.md or store/ios-first-build.md.
#
#   tools/export_ios.sh            export to ~/wandcraft-ios and open it in Xcode
#   OUT=/some/dir tools/export_ios.sh
#
# Godot only generates the Xcode project (preset: export_project_only). Signing happens in
# Xcode with "Automatically manage signing" and your Personal Team (a free Apple ID works;
# the app then runs for 7 days, re-Run from Xcode to refresh). Nothing here is committed:
# the Team ID lives in your local Godot settings and the export goes outside the repo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../game"
OUT="${OUT:-$HOME/wandcraft-ios}"
VER="4.7.2"

say() { echo "[export_ios] $*"; }
fail() { echo "[export_ios] $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "This runs on a Mac (iOS apps are built with Xcode). On Linux use tools/build_android.sh."

# Xcode
if ! xcodebuild -version >/dev/null 2>&1; then
  fail "Xcode not found. Install Xcode from the App Store, open it once, then run: sudo xcode-select -s /Applications/Xcode.app"
fi
say "$(xcodebuild -version | head -1)"

# Godot and its iOS export template
"$HERE/godot.sh" --version >/dev/null 2>&1 || fail "Godot $VER not found. Put Godot.app in /Applications, or set GODOT=/path/to/Godot."
TPL="$HOME/Library/Application Support/Godot/export_templates/${VER}.stable/ios.zip"
[ -f "$TPL" ] || fail "Godot export templates missing. Open Godot > Editor > Manage Export Templates > Download and Install."

# Team ID: set once in Godot (Project > Export > iOS > App Store Team ID). It is stored in
# the preset or in game/.godot/export_credentials.cfg; either way it stays on this Mac.
team="$(grep -h 'app_store_team_id=' "$GAME/export_presets.cfg" "$GAME/.godot/export_credentials.cfg" 2>/dev/null | grep -v '=""' | head -1)"
if [ -z "$team" ]; then
  fail "No Team ID yet. In Xcode: Settings > Accounts > add your Apple ID (a free one is fine) and note the Personal Team ID (10 characters). Then in Godot: Project > Export > iOS > App Store Team ID. Do not commit it."
fi

mkdir -p "$OUT"
say "importing the project"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true
say "exporting the Xcode project to $OUT"
"$HERE/godot.sh" --headless --path "$GAME" --export-debug "iOS" "$OUT/Wandcraft.ipa" 2>&1 | tee "$OUT/export.log" | grep -E "ERROR|error:" || true
PROJ="$(ls -d "$OUT"/*.xcodeproj 2>/dev/null | head -1)"
[ -n "$PROJ" ] || fail "Export failed, see $OUT/export.log"
say "done: $PROJ"
say "In Xcode: target Wandcraft > Signing & Capabilities > Automatically manage signing > your Personal Team. Plug in the iPhone, pick it, press Run."
open "$PROJ"
