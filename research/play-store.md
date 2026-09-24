# Google Play publishing notes (2026-09-24)

The notes below come from working knowledge and still need checking in Play Console before submission. Checked items are verified against the build.

## Account
- [ ] **Console fee:** a Google Play Console developer account costs $25 once, and requires identity verification.
- [ ] **Closed test first:** new *personal* accounts must run a closed test before production access. It has been reported as at least 12 opted-in testers for 14 consecutive days (it was 20 testers before December 2024). **Verify the current number, and start the test as early as possible.**
- [ ] **Organization accounts** need a D-U-N-S number but skip the closed-test requirement.

## Technical
- [ ] **Package format:** upload an Android App Bundle (AAB) signed with an upload key, and let Play App Signing manage the app signing key. Keep the keystore outside git.
- [ ] **Target API:** new apps and updates must target a recent level. It was API 35 (Android 15) from 2025-08-31, and API 36 is expected in 2026. **Verify before the first upload.**
- [ ] **Godot export:** Godot 4.7 exports AABs from Linux. It needs the Android SDK, a JDK and export templates.
- [ ] **Billing:** use the Play Billing Library through Godot's Google Play Billing plugin. Our "Full Game" unlock is a non-consumable, one-time product.
- [ ] **Play Games Services v2:** achievements and leaderboards (optional, recommended).

## Store listing
- [ ] **Data safety form:** "No data collected".
- [ ] **Content rating:** answer the IARC questionnaire (fantasy violence).
- [ ] **Graphics:** a 512×512 icon, a 1024×500 feature graphic, and 2 to 8 phone screenshots. 7" and 10" tablet sets are optional.
- [ ] **Service fee:** 15% on the first $1M a year.
