# App Store images

Generated from the real app by the **App Store Screenshots** workflow
(Actions tab, "Run workflow"). Rerun it after UI changes: it commits the
new set into this folder on the branch it ran on, so `git pull` brings
it to your computer.

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
6. `6-home.jpg`: Home sorted by how you play, with "Up next"
7. `7-streak.jpg`: a streak summary with a new personal best
8. `8-seasons.jpg`: streaks with personal bests and the weekly season
9. `9-modes.jpg`: setting up a game with the mode cards

## InAppPurchase

- `review-screenshot.jpg`: "Review Information > Screenshot" of the Party Pack
- `party-pack-promo-1024.jpg`: optional "Promotional Image" (1024 x 1024, no transparency)

## archive-1.0-6.5-inch

The 1242 x 2688 screenshots uploaded for version 1.0, kept for reference.
They show the old Home screen; App Store Connect only needs the 6.9" set.
