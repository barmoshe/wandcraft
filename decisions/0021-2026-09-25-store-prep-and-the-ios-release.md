# 0021. Store prep and the iOS release path

- Date: 2026-09-25
- Status: Accepted
- Builds on ADR 0010 (M10-M11: store-ready at $0, then the betas) and ADR 0011 (design first).

## Context
With D6, D8 and D9 done, Bar asked to publish on iOS and chose to finish D9 first. He decided: free, no in-app purchases; an Individual Apple Developer account, which he buys; the bundle id `com.barbuilds.wandcraft`; a public site on a new Vercel project; `1barmoshe1@gmail.com` as the public contact.

## Decision
- **iPhone only** for the first release (`targeted_device_family=0`). iPads run it in iPhone mode; supporting iPad would add its own screenshots and review scrutiny for no new player.
- **The listing** is `store/app-store.md`, every App Store Connect field ready to paste, written to the copy rules (no em dashes, no counts that grow, no claims). Privacy: Data Not Collected. Age rating answers expect 9+.
- **Screenshots** at the 6.9-inch size (2868 x 1320) by `tools/store_shots.sh`, rendered at half size and doubled nearest-neighbour so the pixels stay whole.
- **Public pages** at https://wandcraft-plum.vercel.app (`tools/deploy_site.sh`): a landing page, the privacy policy and the support page. The plain `wandcraft.vercel.app` belongs to someone else; a custom domain can replace it later without touching the game.
- **The release script**, `tools/release_ios.sh`: `--check` builds unsigned (no account), `--archive` signs, `--upload` sends to App Store Connect through the Apple ID Bar signs in to Xcode. The Team ID lives in `~/.config/wandcraft/team_id` and goes into the preset only for the export. The agent never handles Bar's credentials, never accepts Apple's agreements, and uploads or submits only on Bar's word.
- **CI**: `.github/workflows/tests.yml` runs the unit tests on every push, on Linux with Godot 4.7.2. The first run passed (180/180; stress ratio 3.33 against the 5.2 guard).
- **The start pick** (Bar's report on the web build): a locked Codex start shows greyed with its price, the free one is preselected, and card stats fall back to a short form so they never overflow.

## Consequences
- What waits on Bar is listed in `store/ios-release.md`: about 11 GB of free disk for Xcode's iOS platform (the download failed at 5.9 GB free), the enrolment, the Xcode sign-in, the Team ID and the app record. After that the agent runs the check, the upload and TestFlight, and submits for review when Bar says go.
- Android's Play release still waits on Bar's Google account (ADR 0010); the APK builds on the Mac now.
