#!/usr/bin/env bash
# The App Store build: export the Xcode project from Godot, then build, sign and (only when
# asked) upload it with xcodebuild. Runs on the Mac. Guide: store/ios-release.md.
#
#   tools/release_ios.sh --check      export and build UNSIGNED for a generic iPhone: proves the
#                                     project compiles, needs no Apple account (the default)
#   tools/release_ios.sh --archive    build a signed Release archive and export the .ipa into
#                                     build/ios/ (needs the Team ID and Xcode signed in)
#   tools/release_ios.sh --upload     the same, then upload it to App Store Connect (TestFlight)
#
# The Team ID comes from $WANDCRAFT_TEAM_ID or ~/.config/wandcraft/team_id (10 characters,
# from developer.apple.com > Membership). It is written into the iOS preset only for the
# export and the file is restored after, so it never reaches git. Signing and the upload use
# the Apple ID signed in to Xcode (Settings > Accounts); this script never asks for it and
# never sees a password.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/platform.sh"
GAME="$HERE/../game"
OUT="$HERE/../build/ios"
MODE="${1:---check}"

say() { echo "[release_ios] $*"; }
fail() { echo "[release_ios] $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "iOS builds need a Mac with Xcode."
xcodebuild -version >/dev/null 2>&1 || fail "Xcode not found (xcode-select -p)."
[ -f "$GODOT_TPL_ROOT/4.7.2.stable/ios.zip" ] || fail "Godot 4.7.2 iOS templates missing (see tools/build_web.sh for the download)."

TEAM="${WANDCRAFT_TEAM_ID:-}"
[ -z "$TEAM" ] && [ -f "$HOME/.config/wandcraft/team_id" ] && TEAM="$(tr -d '[:space:]' < "$HOME/.config/wandcraft/team_id")"
if [ "$MODE" != "--check" ]; then
  [[ "$TEAM" =~ ^[A-Z0-9]{10}$ ]] || fail "No Team ID. Put the 10-character Team ID from developer.apple.com > Membership in ~/.config/wandcraft/team_id (or \$WANDCRAFT_TEAM_ID)."
fi

VER="$(grep '^config/version=' "$GAME/project.godot" | cut -d'"' -f2)"
BUILD="$(grep '^application/version=' "$GAME/export_presets.cfg" | cut -d'"' -f2)"
say "Wandcraft $VER (build $BUILD), mode $MODE"
rm -rf "$OUT/project" "$OUT/Wandcraft.xcarchive" "$OUT/export"
mkdir -p "$OUT/project"

# the Team ID goes into the preset for this export only
PRESETS="$GAME/export_presets.cfg"
cp "$PRESETS" "$OUT/export_presets.backup"
trap 'cp "$OUT/export_presets.backup" "$PRESETS"' EXIT
sed_inplace "s/^application\/app_store_team_id=\".*\"/application\/app_store_team_id=\"${TEAM:-AAAAAAAAAA}\"/" "$PRESETS"

"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true
say "exporting the Xcode project"
"$HERE/godot.sh" --headless --path "$GAME" --export-release "iOS" "$OUT/project/Wandcraft.ipa" > "$OUT/export.log" 2>&1
PROJ="$(ls -d "$OUT"/project/*.xcodeproj 2>/dev/null | head -1)"
[ -n "$PROJ" ] || { tail -20 "$OUT/export.log"; fail "Godot did not write an Xcode project (build/ios/export.log)."; }
SCHEME="$(basename "$PROJ" .xcodeproj)"
say "project: $PROJ (scheme $SCHEME)"

case "$MODE" in
  --check)
    say "building unsigned for a generic iPhone (no account needed)"
    xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release -destination "generic/platform=iOS" \
      -derivedDataPath "$OUT/derived" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build > "$OUT/xcodebuild.log" 2>&1
    code=$?
    grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" "$OUT/xcodebuild.log" | tail -5
    [ $code -eq 0 ] || fail "the Xcode build failed (build/ios/xcodebuild.log)"
    APP="$(find "$OUT/derived" -name '*.app' -maxdepth 6 | head -1)"
    say "ok: $APP"
    /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleShortVersionString" -c "Print :CFBundleVersion" \
      -c "Print :UIDeviceFamily" -c "Print :ITSAppUsesNonExemptEncryption" "$APP/Info.plist" 2>/dev/null | sed 's/^/[release_ios]   /'
    ;;
  --archive|--upload)
    DEST="export"
    [ "$MODE" = "--upload" ] && DEST="upload"
    cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>$DEST</string>
	<key>teamID</key><string>$TEAM</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
    say "archiving (automatic signing with team $TEAM)"
    xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release -destination "generic/platform=iOS" \
      -archivePath "$OUT/Wandcraft.xcarchive" -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic \
      archive > "$OUT/archive.log" 2>&1 || { grep -E "error:" "$OUT/archive.log" | head; fail "archive failed (build/ios/archive.log)"; }
    say "exporting ($DEST)"
    xcodebuild -exportArchive -archivePath "$OUT/Wandcraft.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
      -exportPath "$OUT/export" -allowProvisioningUpdates > "$OUT/exportArchive.log" 2>&1 \
      || { grep -E "error:" "$OUT/exportArchive.log" | head; fail "export failed (build/ios/exportArchive.log)"; }
    if [ "$DEST" = "upload" ]; then
      say "uploaded build $BUILD to App Store Connect. It appears in TestFlight after Apple processes it (usually 10-30 minutes)."
    else
      say "ok: $(ls "$OUT"/export/*.ipa)"
    fi
    ;;
  *)
    fail "usage: tools/release_ios.sh [--check|--archive|--upload]"
    ;;
esac
