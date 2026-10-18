# App Store images

Generated from the real app by the **App Store Screenshots** workflow
(Actions tab, "Run workflow"). Rerun it after UI changes: it commits the
new set into this folder on the branch it ran on, so `git pull` brings
it to your computer.

All images are JPEG without an alpha channel: App Store Connect rejects
screenshots with transparency. The workflow checks size and alpha.

## How the set is made

1. The workflow captures the real app into `raw/<size>/<scene>.jpg`.
2. `marketing/appstore-art/screenshots.py` puts each capture into an
   iPhone frame under one short caption and writes the numbered upload
   images below. Change the order or captions in its `STORY` list and
   run it locally with `python3 marketing/appstore-art/screenshots.py`.

Following Apple's guidance, the set tells the game in order and leads with
the hook: the first three also appear in search results.

## iPhone-6.9 (1320 x 2868)

Upload in this order under the version's "iPhone 6.9" Display" screenshots.

1. `1-dead-on.jpg`: "Can you feel 10 seconds?" with the DEAD ON reveal
2. `2-start.jpg`: "Tap START. The timer vanishes."
3. `3-showdown.jpg`: "Showdown: head to head." with the split screen
4. `4-awards.jpg`: "Crown the inner clock." with results and awards
5. `5-home.jpg`: "Party, solo or online." with Home
6. `6-streak.jpg`: "Daily Challenge & streaks." with a new personal best
7. `7-seasons.jpg`: "A new season every week." with the weekly season
8. `8-modes.jpg`: "8 modes to master." with the mode cards

## iPhone-6.3 (1206 x 2622)

The same eight images, in the same order, for the "iPhone 6.3"" / "6.1""
slot. Upload this set or the 6.9" one; either is enough.

## InAppPurchase

- `review-screenshot.jpg`: "Review Information > Screenshot" of the Party Pack
- `party-pack-promo-1024.jpg`: optional "Promotional Image" (1024 x 1024, no transparency)

## archive-1.0-6.5-inch

The 1242 x 2688 screenshots uploaded for version 1.0, kept for reference.
They show the old Home screen; App Store Connect only needs the 6.9" set.
