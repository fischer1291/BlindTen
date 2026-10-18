#!/usr/bin/env python3
"""Renders the animated product page header: one round of Blind Ten as an
8-second loop.

START is tapped, the timer runs and vanishes, "Can you feel 10 seconds?"
fills the blind phase, then STOP lands on 10.02 s, DEAD ON, with a burst
of confetti, and START comes back for the next loop. One clear idea on a
dark stage, everything in the center that iPhone shows (see render.py),
no sound needed (videos play muted).

Specs (creative asset specifications): 21:9 at 3840 x 1646, 30 fps,
5 to 30 seconds, .mp4; it loops continuously. The 3:2 search results
version uses the same animation.

    python3 marketing/appstore-art/header_video.py

Needs ffmpeg. Set CHROMIUM=/path/to/chrome if Playwright has no browser
of its own.
"""
import base64
import os
import subprocess
from pathlib import Path

from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FONTS = ROOT / "marketing" / "tools" / "fonts"
OUT = ROOT / "AppStore" / "Artwork"

FPS = 30
SECONDS = 8

# name: (width, height)
SIZES = {
    "header-video-21x9-3840x1646": (3840, 1646),
    "search-video-3x2-1920x1280": (1920, 1280),
}


def data_uri(path, mime):
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def page(width, height):
    font = data_uri(FONTS / "nunito-latin-900-normal.woff2", "font/woff2")
    # Everything scales with the height (or the width, on the narrower
    # 3:2 canvas), so both sizes share one layout.
    u = min(height / 100, width / 183)
    return f"""<!doctype html><html><head><style>
@font-face {{ font-family: Nunito; font-weight: 900; src: url({font}); }}
* {{ margin: 0; box-sizing: border-box; }}
html, body {{ width: {width}px; height: {height}px; overflow: hidden; background: #0A0A0C; }}
body {{ font-family: Nunito; font-weight: 900; color: #fff; position: relative; }}
.c {{ position: absolute; left: 50%; top: 56%; transform: translate(-50%, -50%); text-align: center; white-space: nowrap; }}
#glow {{ position: absolute; left: 50%; top: 56%; width: {150 * u}px; height: {150 * u}px; margin: {-75 * u}px 0 0 {-75 * u}px;
  border-radius: 50%; background: radial-gradient(circle, rgba(255,209,0,0.34), rgba(255,209,0,0.08) 45%, transparent 70%); }}
#start {{ width: {70 * u}px; height: {36 * u}px; border-radius: {9 * u}px; background: #FFD100; color: #0A0A0C;
  font-size: {18 * u}px; line-height: {36 * u}px; letter-spacing: {-0.25 * u}px; }}
#ring {{ width: {20 * u}px; height: {20 * u}px; border-radius: 50%; border: {0.9 * u}px solid #fff; }}
#timer {{ font-size: {38 * u}px; font-variant-numeric: tabular-nums; letter-spacing: {-0.6 * u}px; }}
#phrase {{ font-size: {20 * u}px; line-height: 1.05; letter-spacing: {-0.25 * u}px; }}
#phrase em {{ font-style: normal; color: #FFD100; }}
#result {{ line-height: 1; }}
#time {{ font-size: {38 * u}px; letter-spacing: {-0.6 * u}px; }}
#dead {{ font-size: {16 * u}px; color: #FFD100; margin-top: {2 * u}px; letter-spacing: {-0.1 * u}px; }}
canvas {{ position: absolute; inset: 0; }}
</style></head><body>
<div id="glow"></div>
<canvas id="confetti" width="{width}" height="{height}"></canvas>
<div class="c" id="start">START</div>
<div class="c" id="ring"></div>
<div class="c" id="timer">0.00</div>
<div class="c" id="phrase">Can you feel<br><em>10 seconds?</em></div>
<div class="c" id="result"><div id="time">10.02 s</div><div id="dead">DEAD ON</div></div>
<script>
const U = {u}, W = {width}, H = {height}, LOOP = {SECONDS};
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const ramp = (t, a, b) => clamp((t - a) / (b - a));
const out = x => 1 - Math.pow(1 - x, 3);
const inOut = x => x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2;
// A spring that overshoots a little and settles.
const spring = x => x <= 0 ? 0 : x >= 1 ? 1 : 1 - Math.exp(-6 * x) * Math.cos(9 * x);
const set = (id, opacity, scale = 1, extra = '') => {{
  const el = document.getElementById(id);
  el.style.opacity = opacity;
  el.style.transform = `translate(-50%, -50%) scale(${{scale}})` + extra;
}};

// Confetti: a fixed, seeded burst from the center at the STOP moment.
let seed = 7;
const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const COLORS = ['#FFD100', '#FFFFFF', '#FF5454', '#54A6FF', '#40F28C', '#FF9E40'];
const pieces = Array.from({{length: 140}}, () => {{
  const angle = rand() * Math.PI * 2, speed = (40 + rand() * 70) * U;
  return {{ x0: Math.cos(angle) * 62 * U, y0: Math.sin(angle) * 30 * U, vx: Math.cos(angle) * speed * 1.6, vy: Math.sin(angle) * speed - 30 * U,
    w: (1.2 + rand() * 1.2) * U, h: (0.6 + rand() * 0.5) * U, spin: (rand() - 0.5) * 14,
    rot: rand() * 6.28, color: COLORS[Math.floor(rand() * COLORS.length)] }};
}});
const STOP = 5.25;

function frame(t) {{
  // Glow: breathes slowly (never a 1-second beat) and flares at STOP.
  const flare = Math.exp(-Math.pow((t - STOP - 0.15) / 0.35, 2));
  const glow = 0.75 + 0.12 * Math.sin(t / LOOP * Math.PI * 4) + 0.5 * flare;
  set('glow', clamp(glow), 1 + 0.25 * flare, '');
  document.getElementById('glow').style.transform = `scale(${{1 + 0.25 * flare}})`;

  // START: visible at the loop's start, pressed at 0.9 s, back at the end.
  const press = Math.exp(-Math.pow((t - 0.95) / 0.07, 2));
  const leave = out(ramp(t, 1.0, 1.25));
  const back = out(ramp(t, 7.45, 8.0));
  const startShown = t < 4 ? 1 - leave : back;
  const startScale = t < 4 ? (1 - 0.06 * press) * (1 - 0.15 * leave) : 0.85 + 0.15 * back;
  set('start', startShown, startScale);

  // A tap ring on START.
  const ring = tap => {{ const x = ramp(t, tap, tap + 0.55); return [x > 0 && x < 1 ? (1 - x) * 0.8 : 0, 0.6 + out(x) * 2.6]; }};
  const [r1, s1] = ring(0.92);
  set('ring', r1, s1);

  // The timer runs, then blurs away: the blind phase starts.
  const shown = ramp(t, 1.1, 1.3) * (1 - ramp(t, 1.95, 2.6));
  const blur = 4 * U * ramp(t, 1.95, 2.6);
  const timer = document.getElementById('timer');
  timer.textContent = Math.max(0, t - 1.1).toFixed(2);
  timer.style.filter = `blur(${{blur}}px)`;
  set('timer', shown, 1 + 0.08 * ramp(t, 1.95, 2.6));

  // The phrase holds the dark middle.
  const phrase = out(ramp(t, 2.6, 3.1)) * (1 - ramp(t, 4.75, 5.05));
  set('phrase', phrase, 0.96 + 0.04 * out(ramp(t, 2.6, 3.4)) + 0.02 * ramp(t, 3.4, 5.05));

  // STOP: 10.02 s springs in, DEAD ON follows.
  const res = (1 - ramp(t, 7.05, 7.45));
  set('result', t >= STOP ? res : 0, 0.6 + 0.4 * spring(ramp(t, STOP, STOP + 0.9)));
  const dead = document.getElementById('dead');
  const d = ramp(t, STOP + 0.25, STOP + 0.75);
  dead.style.opacity = out(d);
  dead.style.transform = `scale(${{0.7 + 0.3 * spring(d)}})`;

  // Confetti flies out and falls.
  const ctx = document.getElementById('confetti').getContext('2d');
  ctx.clearRect(0, 0, W, H);
  const age = t - STOP;
  if (age > 0 && age < 2.2) {{
    const fade = 1 - ramp(age, 1.4, 2.2);
    for (const p of pieces) {{
      const drag = (1 - Math.exp(-2.2 * age)) / 2.2;
      const x = W / 2 + p.x0 + p.vx * drag, y = H * 0.56 + p.y0 + p.vy * drag + 22 * U * age * age;
      ctx.save();
      ctx.globalAlpha = fade;
      ctx.translate(x, y);
      ctx.rotate(p.rot + p.spin * age);
      ctx.fillStyle = p.color;
      ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h);
      ctx.restore();
    }}
  }}
}}
frame(0);
</script>
</body></html>"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        for name, (width, height) in SIZES.items():
            out = OUT / f"{name}.mp4"
            tab = browser.new_page(viewport={"width": width, "height": height})
            tab.set_content(page(width, height))
            tab.evaluate("document.fonts.ready")
            # Silent stereo track: some App Store video slots expect audio.
            ffmpeg = subprocess.Popen([
                "ffmpeg", "-y", "-loglevel", "error",
                "-f", "image2pipe", "-framerate", str(FPS), "-c:v", "mjpeg", "-i", "-",
                "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
                "-map", "0:v", "-map", "1:a", "-shortest",
                "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p", "-crf", "14",
                "-preset", "slow", "-r", str(FPS),
                "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(out),
            ], stdin=subprocess.PIPE)
            for n in range(FPS * SECONDS):
                tab.evaluate(f"frame({n / FPS})")
                ffmpeg.stdin.write(tab.screenshot(type="jpeg", quality=95,
                                                  clip={"x": 0, "y": 0, "width": width, "height": height}))
            ffmpeg.stdin.close()
            if ffmpeg.wait() != 0:
                raise SystemExit(f"ffmpeg failed for {name}")
            print("Wrote", out.relative_to(ROOT))
            tab.close()
        browser.close()


if __name__ == "__main__":
    main()
