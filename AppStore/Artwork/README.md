# App Store artwork

Rendered by `python3 marketing/appstore-art/render.py` from
`AppStore/Screenshots/raw/iPhone-6.9/dead-on.jpg`, following Apple's
[asset best practices](https://developer.apple.com/app-store/asset-best-practices/)
and [creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications):

- One universal design for the header and search results.
- A single idea with the focal point in the center: the DEAD ON moment.
- A short phrase that adds to the visual; no logo or app name (the App
  Store shows them), no prices, URLs or awards.
- The header keeps everything inside the center 1.45 x its height: on
  iPhone the product page crops its sides away.
- The bottom edge stays clear for the App Store's own overlay.
- No alpha channel; the 16:9 sizes are PNG as the specification requires.

## Product page header

- `header-21x9-3840x1646.jpg` (21:9)
- `header-16x9-5244x2950.png` (16:9)

## Search results

- `search-3x2-3840x2560.jpg` (3:2, maximum size)
- `search-3x2-1920x1280.jpg` (3:2, minimum size; upload one of the two)
- `search-16x9-5244x2950.png` (16:9)

## Header video

Rendered by `python3 marketing/appstore-art/header_video.py` (needs ffmpeg):
one round as an 8-second seamless loop at 30 fps. START is tapped, the
timer runs and blurs away, "Can you feel 10 seconds?" holds the blind
phase, then 10.02 s, DEAD ON and confetti, and START returns. Everything
stays in the header's visible center; it works muted.

- `header-video-21x9-3840x1646.mp4`: product page header (21:9)
- `search-video-3x2-1920x1280.mp4`: the same loop for search results (3:2)
