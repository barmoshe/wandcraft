# Installing the Android test build (sideload)

The APK is built on Linux by `tools/build_android.sh`. It writes `build/wandcraft-<version>.apk`, which is not committed. It uses Godot's release template (smaller and faster than debug) but is **signed with a throwaway sideload key**: fine for testing, never for the Play Store. `--debug` builds the debug-template variant instead.

## On the phone (Android 7.0 or newer, 64-bit)
1. Copy the `.apk` to the phone (Drive, email to yourself, or USB).
2. Tap the file. Android asks to allow installs from that app (Files, Drive, Gmail…): allow it once.
3. Install, then open **Wandcraft**. It runs in landscape.
   - Android may show a "Play Protect" warning because the build is not from the store. Choose *Install anyway*.

### "There's a problem with the app file"
The copy on the phone is incomplete: the download or transfer was cut short.
- Compare sizes. The build script prints the exact byte count and SHA-256, and the phone's file manager must show the same size (Samsung *My Files* shows decimal MB, so 27,668,409 bytes appears as 27.67 MB).
- Download the file again, directly on the phone, and wait until it finishes before tapping it. Don't forward a half-downloaded copy.
- If you send it through WhatsApp, attach it as a **Document** and wait for the upload to finish.

If the full-size file still fails, the phone may be running 32-bit Android (some older budget models). The build is 64-bit only (arm64), so tell us the phone model.

With a cable and `adb` instead: `adb install -r build/wandcraft-0.3.0.apk`.

## Rebuilding
```bash
cd projects/wandcraft
tools/build_android.sh
```
The first run downloads the Godot export templates and the Android SDK (about 2 GB, cached in `~/.cache/wandcraft-build`).

## Before the Play Store (not yet)
- **Release key:** a release keystore created and kept only by Bar (never in git), then Play App Signing in the Play Console.
- **Bundle format:** an AAB instead of an APK. That means the Gradle build, with `gradle_build/use_gradle_build=true`.
- **Package name:** the final package name (the same id as iOS). `com.barbuilds.wandcraft` is a placeholder.
