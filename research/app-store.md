# App Store publishing research (2026-09-24)

Sources were checked in September 2026. Items marked *uncertain* need verifying closer to submission.

## Account and tooling
- **Apple Developer Program:** $99 a year.
  - **Individual:** your personal name is shown as the seller.
  - **Organization:** needs a legal entity and a D-U-N-S number.
  - Source: https://developer.apple.com/programs/enroll/
- **SDK floor:** since 2026-04-28, every upload must be built with **Xcode 26 or later and the iOS 26 SDK**. The deployment target can be lower. Source: https://developer.apple.com/news/upcoming-requirements/
- **Building without a Mac:** Codemagic, Bitrise or GitHub macOS runners, using fastlane and an App Store Connect API key. Xcode Cloud offers 25 free hours a month, but needs one-time setup on a Mac.
- **Testing:** use TestFlight on a real device, which is needed to check haptics, 120Hz and the Dynamic Island.

## Review guidelines and IP
- **Guideline text:**
  - **4.1(a)–(c):** no copycats, and no using another product's name, icon or brand.
  - **4.2:** apps must offer lasting entertainment value.
  - **4.3(b):** tightened on 2026-06-08. https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/
  - **5.2.1:** no third-party trademarks or copyrighted works, and no "copycat representations, names, or metadata".
  - Source: https://developer.apple.com/app-store/review/guidelines/
- **Magicraft's owners:** the game is by Wave Game, published by bilibili (Steam app 2103140), and reached version 1.0 on 2024-11-01.
- **Not protected:** mechanics and rules.
- **Protected:**
  - Text, art, audio and code.
  - "Look and feel": Tetris Holding v. Xio (2012), https://en.wikipedia.org/wiki/Tetris_Holding,_LLC_v._Xio_Interactive,_Inc.
  - Spry Fox v. 6waves (settled), https://en.wikipedia.org/wiki/Spry_Fox,_LLC_v._Lolapps,_Inc.
  - Names fall under trademark law and Apple's copycat rules.
  - *Uncertain:* whether copying a whole balance table is risky.

## Compliance checklist
- [ ] **Privacy:** privacy nutrition label ("Data Not Collected"), plus a `PrivacyInfo.xcprivacy` declaring the required-reason APIs the engine uses, such as UserDefaults and file timestamps.
- [ ] **No ATT:** we have no ads and no tracking, so the App Tracking Transparency prompt isn't needed.
- [ ] **Age rating:** answer the questionnaire for the new tiers (4+, 9+, 13+, 16+, 18+). Fantasy violence probably lands at 9+ (*check the answers*). https://developer.apple.com/news/?id=ks775ehf
- [ ] **EU:** declare our Digital Services Act trader status. Traders have their address, phone and email shown publicly.
- [ ] **Encryption:** set `ITSAppUsesNonExemptEncryption = NO`.
- [ ] **Screenshots:** a 6.9" iPhone set (1320×2868 or its landscape equivalent), and a 13" iPad set (2064×2752) if we support iPad.
- [ ] **Icon:** 1024×1024 with no transparency, plus an optional layered Liquid Glass icon made in Icon Composer (ships with Xcode 26).
- [ ] **Small Business Program:** enroll to pay 15% commission.

## iOS best practices for games
- [ ] **Game Center:** achievements, leaderboards and Challenges, which show up in the Apple Games app on iOS 26. https://developer.apple.com/games-app/
- [ ] **Info.plist keys:**
  - [ ] `GCSupportsControllerUserInteraction` and `GCSupportsGameMode` for controllers and Game Mode.
  - [ ] `CADisableMinimumFrameDurationOnPhone = YES` for 120Hz.
- [ ] **Screen layout:** keep the HUD and sticks inside the landscape safe area, clear of the Dynamic Island and home indicator. Add a haptics toggle.
- [ ] **Cloud saves (later):** NSUbiquitousKeyValueStore allows 1 MB total, which is enough for meta progress.
