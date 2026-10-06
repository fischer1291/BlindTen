# 60-second reel

Fast-cut reel for Instagram and TikTok: how to play, friends in bars and on
the couch, the TV session, a DEAD ON climax, and a "Coming soon" end card.
English text overlays, license-free sound, 1080 × 1920, 30 fps.

`shots.json` is the source of truth (timing, overlays, prompts, sound
effects). `build.py` turns it into the video:

```
pip install playwright pillow
python3 marketing/reel60/build.py
```

- Without footage it writes `marketing/video/reel-60s-animatic.mp4`, with
  placeholder cards where the AI clips go, so the timing can be judged now.
- With every clip in `clips/` (named `S01.mp4`, `S02.mp4`, …) it writes the
  final `marketing/video/reel-60s.mp4`. Clips can be any size and length:
  they are cropped to 9:16 and trimmed to the shot.
- Sound: the generated track from `music.py` (120 BPM, our own, no license
  needed) plus the app's own drumroll, cymbal and trombone. To use another
  license-free track, put it next to this file as `music.mp3`.

## Shots

| Shot | Time | Source | Picture | Text overlay |
| --- | --- | --- | --- | --- |
| S01 | 0.0–2.0 s | AI clip | Extreme close-up of a thumb about to tap a phone screen in a dim, cozy… | Can you feel |
| S02 | 2.0–4.0 s | AI clip | Five friends on a living-room couch explode into cheers and laughter, … | 10 seconds? |
| S03 | 4.0–6.5 s | App: start | — | STEP 1 · Tap START |
| S04 | 6.5–8.5 s | AI clip | A young woman in a bar closes her eyes and concentrates hard while hol… | STEP 2 · The timer vanishes |
| S05 | 8.5–10.5 s | App: blind | — | STEP 3 · Stop at exactly 10.00 |
| S06 | 10.5–12.5 s | AI clip | Close-up of a guy in a hoodie secretly counting on his fingers under a… | No peeking. |
| S07 | 12.5–15.0 s | App: reveal-lost | — | — |
| S08 | 15.0–16.5 s | AI clip | A friend facepalms dramatically while everyone around a kitchen table … | — |
| S09 | 16.5–18.5 s | AI clip | Hands quickly passing a smartphone from person to person across a crow… | Pass the phone |
| S10 | 18.5–20.5 s | AI clip | A grandmother and her twenty-something granddaughter on a cozy couch h… | Anyone can play |
| S11 | 20.5–22.5 s | App: showdown | — | Showdown: 1 vs 1 |
| S12 | 22.5–24.5 s | AI clip | Two friends face to face over one phone lying flat on a table, each wi… | — |
| S13 | 24.5–26.5 s | AI clip | Friends at a rooftop party at golden hour scream with joy around a pho… | — |
| S14 | 26.5–28.5 s | App: reveal-sharp | — | — |
| S15 | 28.5–30.3 s | AI clip | A young man celebrates with both arms up at a house party in a kitchen… | — |
| S16 | 30.3–32.0 s | AI clip | A young woman laughs so hard she cries and falls back into the couch c… | — |
| S17 | 32.0–35.0 s | AI clip | Wide shot of a living room at night: six friends on a sofa, each holdi… | Play together on the TV |
| S18 | 35.0–38.0 s | App: tv | — | Everyone joins with their own iPhone |
| S19 | 38.0–41.0 s | AI clip | Over-the-shoulder shot of a young man staring at his phone in a dim li… | — |
| S20 | 41.0–44.0 s | AI clip | The whole group jumps up from the couch cheering, popcorn flying throu… | — |
| S21 | 44.0–46.0 s | App: drumroll | — | — |
| S22 | 46.0–49.0 s | App: dead-on | — | — |
| S23 | 49.0–52.0 s | AI clip | Slow motion: friends lift the winner onto their shoulders in a lively … | DEAD ON. |
| S24 | 52.0–60.0 s | End card | — | — |

The app screens are re-drawn from the app's design, so they always match the
real game and need no screen recording.

## Generating the AI clips

Any text-to-video tool works (for example Sora, Veo, Runway or Kling). For
each shot:

1. Paste the prompt below and choose **9:16 vertical**, 1080p if offered.
2. Generate at least the shot length (5 s clips are fine; the build trims).
3. Pick the take where faces and hands look natural, download it and save it
   as `marketing/reel60/clips/<shot>.mp4`.
4. Rerun `build.py`. Shots without a clip stay placeholders.

Tips:
- Keep the same style suffix on every prompt so the clips look like one shoot.
- If phones show garbled screens, regenerate or pick a take where the screen
  faces away; the real app screens come from the app shots.
- Instagram and TikTok ask you to label realistic AI-generated video: turn on
  the "AI-generated" label when posting.

**S01** (2 s, generate 5 s)
```
Extreme close-up of a thumb about to tap a phone screen in a dim, cozy bar at night; four friends lean in behind it, faces lit by warm bar lights and the phone's yellow glow, holding their breath. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S02** (2 s, generate 5 s)
```
Five friends on a living-room couch explode into cheers and laughter, arms in the air, one grabbing another's shoulder, handheld camera shaking with the energy. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S04** (2 s, generate 5 s)
```
A young woman in a bar closes her eyes and concentrates hard while holding a phone; her friends around the table silently watch her, biting their lips, trying not to laugh. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S06** (2 s, generate 5 s)
```
Close-up of a guy in a hoodie secretly counting on his fingers under a bar table; his friends catch him and point at him, laughing. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S08** (1.5 s, generate 5 s)
```
A friend facepalms dramatically while everyone around a kitchen table laughs hysterically, evening light, snacks on the table. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S09** (2 s, generate 5 s)
```
Hands quickly passing a smartphone from person to person across a crowded bar table with snacks and soft drinks, fast motion, shallow depth of field. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S10** (2 s, generate 5 s)
```
A grandmother and her twenty-something granddaughter on a cozy couch high-five and burst out laughing, a phone in the granddaughter's hand. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S12** (2 s, generate 5 s)
```
Two friends face to face over one phone lying flat on a table, each with a thumb ready on their half of the screen, intense rivalry, friends cheering behind them. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S13** (2 s, generate 5 s)
```
Friends at a rooftop party at golden hour scream with joy around a phone, string lights and a city skyline behind them. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S15** (1.8 s, generate 5 s)
```
A young man celebrates with both arms up at a house party in a kitchen, friends hugging him and laughing. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S16** (1.7 s, generate 5 s)
```
A young woman laughs so hard she cries and falls back into the couch cushions, friends laughing around her. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S17** (3 s, generate 5 s)
```
Wide shot of a living room at night: six friends on a sofa, each holding their own phone, a large TV on the wall glowing with bright yellow light, everyone leaning forward in suspense. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S19** (3 s, generate 5 s)
```
Over-the-shoulder shot of a young man staring at his phone in a dim living room while the whole room watches the glowing TV in suspense. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S20** (3 s, generate 5 s)
```
The whole group jumps up from the couch cheering, popcorn flying through the air, one friend pointing at the TV in disbelief, slow motion. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```

**S23** (3 s, generate 5 s)
```
Slow motion: friends lift the winner onto their shoulders in a lively bar, confetti in the air, everyone screaming with joy. Vertical 9:16 video, shot on a smartphone, handheld and candid, warm practical lighting, shallow depth of field, natural skin tones, friends in their twenties and thirties from diverse backgrounds, energetic and joyful party mood. Phone screens face away from the camera or show only a bright yellow glow. No readable text, no logos, no alcohol in focus.
```
