# Blind Ten on Instagram and TikTok

Everything here is generated from the app's design by `tools/render.py`
(colors, logo, a rounded font close to SF Rounded). Rerun it after changing a
template:

```
pip install playwright pillow
python3 marketing/tools/render.py            # add --no-video for stills only
```

| Folder | What | Size |
| --- | --- | --- |
| `profile/profile-picture-1080.png` | Profile picture for both platforms | 1080 × 1080 |
| `instagram/highlights/` | Story highlight covers (How to play, DEAD ON, Modes, TV, Support) | 1080 × 1920 |
| `instagram/posts/` | Six feed posts | 1080 × 1350 (4:5) |
| `tiktok/covers/` | The same six as full-screen covers or stories | 1080 × 1920 (9:16) |
| `video/dead-on-reel.mp4` | 10 s reel: START, blind phase, drumroll, DEAD ON | 1080 × 1920, 30 fps |

The reel has no sound on purpose: add a trending sound in Instagram or TikTok
itself, where the music is licensed for the platform.

## Accounts

Use the same handle everywhere, ideally **@blindten**, and hello@blindten.com.
Switch Instagram to a **Creator** or **Business** account (Settings → Account
type) to get statistics and, later, posting through the Meta API.

**Name:** Blind Ten – the 10-second game

**Instagram bio (150 max)**
```
Tap START. The timer vanishes. Stop at exactly 10.00 s.
Closest wins. 🎯
Party game for iPhone 👇
```

**TikTok bio (80 max)**
```
Can you feel 10 seconds? ⏱ Party game for iPhone
```

**Link:** https://www.blindten.com (switch to the App Store link once the app is live)

## First posts

Post the hero first, then one piece every one or two days. Reels and TikToks
reach new people; feed posts and stories convince visitors of the profile.

| # | File | Caption |
| --- | --- | --- |
| 1 | `posts/01-hero.jpg` | Can you stop at exactly 10.00 seconds? No timer, no clock, just your gut. Blind Ten is the party game that proves who really has a perfect inner clock. Coming to iPhone. |
| 2 | `video/dead-on-reel.mp4` | 10.02 seconds. DEAD ON. 🎯 Your turn. |
| 3 | `posts/03-how-close.jpg` | How close is close? Six tiers from DEAD ON (within 0.05 s) to Lost in time. Where do you land? |
| 4 | `posts/06-challenge.jpg` | Challenge: stop at 10.00 without looking. Comment your best time, closest to ten gets bragging rights. |
| 5 | `posts/04-modes.jpg` | 8 ways to lose your sense of time: Classic, Random Target, Showdown, Distraction, Liar's Clock, Heartbeat, Elimination, Teams. Which one breaks you? |
| 6 | `posts/05-tv.jpg` | Game night upgrade: host on your phone, put it on the TV, everyone plays on their own iPhone. The reveal lands on the big screen. |
| 7 | `posts/02-dead-on.jpg` | Mic drop. Phone stays. 🎤 |

**Hashtags** (3–5 per post works best; mix one broad, a few niche):
`#partygame #gamenight #iphonegames #challenge #10secondchallenge #friendsgame #reactiongame`

## Three-week plan

| Week | Mon | Wed | Fri | Sun |
| --- | --- | --- | --- | --- |
| 1 | Hero post | DEAD ON reel | How close is close | Challenge |
| 2 | Real group clip (film friends playing) | Modes | Showdown duel clip | Story poll: "Could you hit 10.00?" |
| 3 | TV post | DEAD ON post | Behind the scenes: the app being built | Launch countdown in stories |

**What works best on TikTok:** real reactions. Film a group playing on the
phone (vertical, faces and the screen in shot), cut to the reveal, put the
time as on-screen text. Keep it under 15 seconds. The rendered reel is a good
opener and a template for the look.

## Highlights

Upload each cover as a story, add it to a highlight with the same name, then
pick the story as cover: How to play, DEAD ON, Modes, TV, Support.
