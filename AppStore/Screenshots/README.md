# App Store images

Generated from the real app by the **App Store Screenshots** workflow
(Actions tab, "Run workflow"). Rerun it after UI changes; the newest set
is also pushed to the `app-store-assets` branch.

All images are JPEG without an alpha channel: App Store Connect rejects
screenshots with transparency. The workflow checks size and alpha, and
saves each file under the name below.

## iPhone-6.9 (1320 x 2868)

Upload in this order under the version's "iPhone 6.9" Display" screenshots.
App Store Connect scales them down for smaller iPhones.

1. `1-dead-on.jpg`: the DEAD ON reveal with confetti
2. `2-showdown.jpg`: Showdown split screen
3. `3-awards.jpg`: final results with awards
4. `4-pass-the-phone.jpg`: handoff
5. `5-start.jpg`: the START button
6. `6-modes.jpg`: Home with the modes

## InAppPurchase

- `review-screenshot.jpg`: "Review Information > Screenshot" of the Party Pack
- `party-pack-promo-1024.jpg`: optional "Promotional Image" (1024 x 1024, no transparency)
