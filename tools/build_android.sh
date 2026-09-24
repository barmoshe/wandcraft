#!/usr/bin/env bash
# Builds an installable Android APK from the Godot project.
#
#   tools/build_android.sh            set up (first run only) and export build/wandcraft-<ver>.apk
#   tools/build_android.sh --debug    export the debug-template build instead (bigger, slower, has logs)
#   tools/build_android.sh --setup    only download and set up the toolchain
#
# The default build uses Godot's RELEASE template (about half the size and faster on the phone)
# but is still signed with the throwaway sideload key, so it is for testing only, never the store.
#
# Everything heavy lives OUTSIDE the repo in ~/.cache/wandcraft-build (Godot export templates,
# Android SDK command-line tools, build-tools, a debug keystore). Nothing here is committed.
# The debug keystore is a throwaway for sideloading; the Play Store release key is Bar's and
# never touches this repo (CLAUDE.md: secrets stay off git).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME="$HERE/../game"
OUT="$HERE/../build"
CACHE="${WANDCRAFT_BUILD_CACHE:-$HOME/.cache/wandcraft-build}"
GODOT_VER="4.7.2"
TPL_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VER}.stable"
SDK="$CACHE/android-sdk"
CMDLINE_ZIP="commandlinetools-linux-11076708_latest.zip"
BUILD_TOOLS="35.0.0"
KEYSTORE="$CACHE/debug.keystore"
mkdir -p "$CACHE" "$OUT"

log() { echo "[build_android] $*"; }

setup_templates() {
  if [ -f "$TPL_DIR/android_debug.apk" ]; then return; fi
  log "downloading Godot ${GODOT_VER} export templates (about 1 GB)"
  local tpz="$CACHE/templates.tpz"
  [ -f "$tpz" ] || curl -sSfL -o "$tpz" "https://github.com/godotengine/godot/releases/download/${GODOT_VER}-stable/Godot_v${GODOT_VER}-stable_export_templates.tpz"
  mkdir -p "$TPL_DIR" "$CACHE/tpl"
  # only the Android templates are needed here (iOS exports happen on the Mac)
  unzip -o -q "$tpz" 'templates/android_*' 'templates/version.txt' -d "$CACHE/tpl"
  cp "$CACHE"/tpl/templates/* "$TPL_DIR/"
  rm -f "$tpz"
}

setup_sdk() {
  if [ -x "$SDK/build-tools/$BUILD_TOOLS/apksigner" ]; then return; fi
  log "downloading Android command-line tools"
  mkdir -p "$SDK/cmdline-tools"
  curl -sSfL -o "$CACHE/$CMDLINE_ZIP" "https://dl.google.com/android/repository/$CMDLINE_ZIP"
  unzip -o -q "$CACHE/$CMDLINE_ZIP" -d "$SDK/cmdline-tools"
  rm -rf "$SDK/cmdline-tools/latest"
  mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm -f "$CACHE/$CMDLINE_ZIP"
  log "installing platform-tools, build-tools $BUILD_TOOLS, platform 35"
  # `yes` dies of SIGPIPE when sdkmanager stops reading; that is expected, not a failure
  (yes || true) | "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --licenses >/dev/null || true
  "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" "platform-tools" "build-tools;$BUILD_TOOLS" "platforms;android-35" >/dev/null
}

setup_keystore() {
  if [ -f "$KEYSTORE" ]; then return; fi
  log "creating a debug keystore (sideload only)"
  keytool -genkeypair -v -keystore "$KEYSTORE" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
}

## Points the Godot editor settings at the SDK and JDK (the headless export reads them).
setup_editor_settings() {
  local jdk; jdk="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
  local dir="$HOME/.config/godot"
  local f="$dir/editor_settings-4.7.tres"
  mkdir -p "$dir"
  if [ ! -f "$f" ]; then
    printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$f"
  fi
  grep -v '^export/android/android_sdk_path\|^export/android/java_sdk_path\|^export/android/debug_keystore' "$f" > "$f.tmp"
  {
    cat "$f.tmp"
    echo "export/android/android_sdk_path = \"$SDK\""
    echo "export/android/java_sdk_path = \"$jdk\""
    echo "export/android/debug_keystore = \"$KEYSTORE\""
    echo "export/android/debug_keystore_user = \"androiddebugkey\""
    echo "export/android/debug_keystore_pass = \"android\""
  } > "$f"
  rm -f "$f.tmp"
}

setup_templates
setup_sdk
setup_keystore
setup_editor_settings
[ "${1:-}" = "--setup" ] && { log "toolchain ready in $CACHE"; exit 0; }

MODE="release"; [ "${1:-}" = "--debug" ] && MODE="debug"
VER="$(grep '^config/version=' "$GAME/project.godot" | cut -d'"' -f2)"
if [ "$MODE" = "debug" ]; then APK="$OUT/wandcraft-${VER:-dev}-debug.apk"; else APK="$OUT/wandcraft-${VER:-dev}.apk"; fi
rm -f "$APK" "$APK.idsig"
"$HERE/godot.sh" --headless --path "$GAME" --import >/dev/null 2>&1 || true
log "exporting $APK ($MODE template)"
GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$KEYSTORE" GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey \
GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android \
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE" GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android \
  "$HERE/godot.sh" --headless --path "$GAME" "--export-$MODE" "Android" "$APK" 2>&1 | tee "$OUT/export.log" | grep -E "ERROR|error|Export" || true
if [ -f "$APK" ]; then
  "$SDK/build-tools/$BUILD_TOOLS/apksigner" verify "$APK" 2>/dev/null || { log "signature check FAILED"; exit 1; }
  log "done: $APK ($(stat -c %s "$APK") bytes)"
  log "sha256: $(sha256sum "$APK" | cut -d' ' -f1)"
  "$SDK/build-tools/$BUILD_TOOLS/aapt" dump badging "$APK" 2>/dev/null | grep -E "^package|sdkVersion|targetSdk|launchable" || true
else
  log "export failed, see $OUT/export.log"
  exit 1
fi
