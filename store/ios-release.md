# Publishing on iOS: TestFlight, then the App Store

Decided on 2026-09-25: free, an Individual Apple Developer account, bundle id
`com.barbuilds.wandcraft`, iPhone only. The listing text is `store/app-store.md`; the pages it
links to are live at https://wandcraft-plum.vercel.app (`tools/deploy_site.sh`).

The agent never types Bar's Apple ID, password or payment details, never accepts Apple's
agreements, and never uploads or submits without Bar saying so in the chat.

## Bar, once

1. **Free disk space.** The Mac needs about 11 GB free for Xcode's iOS platform (it had
   5.9 GB free on 2026-09-25). Then the agent runs `xcodebuild -downloadPlatform iOS`.
2. **Enroll** at developer.apple.com/programs as an Individual ($99/yr). Apple usually
   confirms within 48 hours. Accept the agreements in App Store Connect when asked
   (Business > Agreements; the Free Apps agreement is enough for a free app).
3. **Sign in to Xcode** with that Apple ID: Xcode > Settings > Accounts > +.
4. **Team ID:** developer.apple.com > Account > Membership details, a 10-character code.
   Save it where the release script reads it (it is not secret, but it stays off git):
   ```bash
   mkdir -p ~/.config/wandcraft && echo YOURTEAMID > ~/.config/wandcraft/team_id
   ```
5. **Create the app record** in App Store Connect > My Apps > + > New App, with the values
   in `store/app-store.md` (name, bundle id, SKU). If "Wandcraft" is taken, use the fallback
   name listed there.

## The agent, then (each step after Bar says go)

1. `tools/release_ios.sh --check`: the unsigned build, to prove the project compiles.
2. `tools/release_ios.sh --upload`: a signed Release archive, uploaded to App Store Connect
   through Xcode's signed-in account. It appears in TestFlight after Apple processes it.
3. TestFlight: Bar adds himself (and friends) as testers and plays it on the iPhone.
4. The listing: fill `store/app-store.md` into App Store Connect, upload the screenshots in
   `store/screenshots/`, answer App Privacy ("Data Not Collected") and the age rating.
5. Submit for review once Bar has played the TestFlight build and says go.

## Every later version

`tools/bump_version.sh X.Y.Z` (it raises the build number), run the tests, then
`tools/release_ios.sh --upload`. App Store Connect refuses a build number it has seen.
