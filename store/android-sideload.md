# Installing the Android test build (sideload)

The APK is built on Linux by `tools/build_android.sh`. It writes `build/wandcraft-<version>-debug.apk`, which is not committed. It is a **debug build signed with a throwaway debug key**: fine for testing, never for the Play Store.

## On the phone (Android 7.0 or newer, 64-bit)
1. Copy the `.apk` to the phone (Drive, email to yourself, or USB).
2. Tap the file. Android asks to allow installs from that app (Files, Drive, Gmail…): allow it once.
3. Install, then open **Wandcraft**. It runs in landscape.
   - Android may show a "Play Protect" warning because the build is not from the store. Choose *Install anyway*.

With a cable and `adb` instead: `adb install -r build/wandcraft-0.3.0-debug.apk`.

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
