# 0003. Free download with World 1, plus one non-consumable "Full Game" unlock

- Date: 2026-09-24
- Status: Accepted

## Context
Bar picked "Free + one unlock" on 2026-09-24. Comparable roguelites on iOS use several models:
- Premium price: Slay the Spire at $9.99, Dead Cells at about $8.99.
- Free with cosmetic IAP and ads: Soul Knight.
- Free with optional ads and DLC: Vampire Survivors.

A free-to-try demo followed by one unlock keeps compliance simple: no ads, no ATT, no consumables.

## Decision
- The download is free, and World 1 (the tutorial world plus its mini-boss and boss) is fully playable.
- One non-consumable in-app purchase, "Full Game", unlocks Worlds 2-5 and meta progression beyond World 1:
  - StoreKit 2 on iOS.
  - Play Billing on Android.
- A **Restore Purchases** button is always visible where the unlock is offered.
- No ads, no consumables, no loot boxes and no subscriptions.

## Consequences
- The privacy label is "Data Not Collected". Purchases are handled by the platforms.
- Bar needs to enroll in the App Store Small Business Program (15% commission) and complete the tax and banking forms. Google Play also takes 15% on the first $1M.
- The unlock price is still open (around $4.99 suggested). It can be tuned without a new build.
