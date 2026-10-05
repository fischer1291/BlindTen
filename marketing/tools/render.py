#!/usr/bin/env python3
"""Renders the Instagram and TikTok kit in the app's look.

Everything is drawn from HTML templates with the app's colors, the logo and
Nunito (a free rounded font close to SF Rounded), then captured with
Chromium (Playwright). The reel is rendered frame by frame from a scripted
timeline and encoded with ffmpeg, so every run gives the same result.

    pip install playwright pillow
    python3 marketing/tools/render.py            # everything
    python3 marketing/tools/render.py --no-video # stills only

Set CHROMIUM=/path/to/chrome if Playwright has no browser of its own.
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

TOOLS = Path(__file__).resolve().parent
OUT = TOOLS.parent
BUILD = TOOLS / "build"

# Theme.swift
ACCENT = "#FFD100"
SURFACE = "#1C1C1C"
SECONDARY = "#B8B8B8"
EARLY = "#54A6FF"
LATE = "#FF5454"
TIERS = [
    ("DEAD ON", "within 0.05 s", ACCENT, 10),
    ("Sharp", "within 0.25 s", "#40F28C", 7),
    ("Close", "within 0.50 s", "#B3ED59", 5),
    ("Meh", "within 1 s", "#FFFFFF", 3),
    ("Off", "within 2 s", "#FF9E40", 1),
    ("Lost in time", "more than 2 s off", LATE, 0),
]
MODES = [
    ("Classic", "Stop at exactly 10 seconds."),
    ("Random Target", "A new target every turn."),
    ("Showdown", "Two players, one split screen."),
    ("Distraction", "Random beeps try to throw you off."),
    ("Liar's Clock", "A countdown that lies."),
    ("Heartbeat", "A pulse at the wrong tempo."),
    ("Elimination", "Worst player each round is out."),
    ("Teams", "Lowest combined deviation wins."),
]

BASE_CSS = f"""
@font-face {{ font-family: Nunito; font-weight: 700; src: url(fonts/nunito-latin-700-normal.woff2); }}
@font-face {{ font-family: Nunito; font-weight: 800; src: url(fonts/nunito-latin-800-normal.woff2); }}
@font-face {{ font-family: Nunito; font-weight: 900; src: url(fonts/nunito-latin-900-normal.woff2); }}
* {{ box-sizing: border-box; margin: 0; padding: 0; }}
html, body {{ background: #000; color: #fff; font-family: Nunito, sans-serif; font-weight: 800; }}
.frame {{ position: relative; overflow: hidden; background: #000; display: flex; flex-direction: column;
          align-items: center; justify-content: center; text-align: center; }}
.accent {{ color: {ACCENT}; }}
.secondary {{ color: {SECONDARY}; }}
.display {{ font-weight: 900; line-height: 1.02; letter-spacing: -0.01em; }}
.mono {{ font-variant-numeric: tabular-nums; }}
.footer {{ position: absolute; bottom: 64px; left: 0; right: 0; display: flex; justify-content: center;
           align-items: center; gap: 18px; font-size: 34px; color: {SECONDARY}; font-weight: 800; }}
.footer img {{ width: 52px; height: 52px; }}
.card {{ background: {SURFACE}; border-radius: 40px; }}
.pill {{ background: {ACCENT}; color: #000; border-radius: 999px; font-weight: 900; }}
"""

FOOTER = '<div class="footer"><img src="logo.png">BLIND TEN · blindten.com</div>'


def page(width, height, body, extra_css=""):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.frame {{ width: {width}px; height: {height}px; }} {extra_css}</style></head>
<body><div class="frame">{body}</div></body></html>"""


def confetti_svg(width, height, count=140, seed=7, band=0.45):
    """Static confetti like the app's DEAD ON burst."""
    import random

    rng = random.Random(seed)
    colors = [ACCENT, EARLY, LATE, "#FFFFFF", "#40F28C", "#FF73D9"]
    pieces = []
    for i in range(count):
        x = rng.uniform(0, width)
        y = rng.uniform(0, height * band)
        w, h = rng.uniform(10, 18), rng.uniform(16, 28)
        angle = rng.uniform(0, 180)
        pieces.append(
            f'<rect x="{x - w / 2:.1f}" y="{y - h / 2:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'fill="{colors[i % len(colors)]}" transform="rotate({angle:.0f} {x:.1f} {y:.1f})"/>'
        )
    return (f'<svg width="{width}" height="{height}" style="position:absolute;inset:0" '
            f'xmlns="http://www.w3.org/2000/svg">{"".join(pieces)}</svg>')


# ---------------------------------------------------------------- profile

def profile_picture():
    # Instagram and TikTok crop to a circle: keep the mark inside it.
    return page(1080, 1080, '<img src="logo.png" style="width:640px;height:640px">')


# ------------------------------------------------------------- highlights

HIGHLIGHT_ICONS = {
    "how-to-play": '<polygon points="380,300 380,780 760,540" fill="none" stroke="{c}" stroke-width="56" stroke-linejoin="round"/>',
    "dead-on": '<circle cx="540" cy="540" r="250" fill="none" stroke="{c}" stroke-width="52"/>'
               '<circle cx="540" cy="540" r="110" fill="none" stroke="{c}" stroke-width="52"/>'
               '<circle cx="540" cy="540" r="30" fill="{c}"/>',
    "modes": "".join(
        f'<rect x="{x}" y="{y}" width="200" height="200" rx="44" fill="none" stroke="{{c}}" stroke-width="48"/>'
        for x in (300, 580) for y in (300, 580)
    ),
    "tv": '<rect x="260" y="330" width="560" height="360" rx="48" fill="none" stroke="{c}" stroke-width="52"/>'
          '<line x1="420" y1="800" x2="660" y2="800" stroke="{c}" stroke-width="52" stroke-linecap="round"/>',
    "support": '<path d="M430 420 a110 110 0 1 1 160 98 c-36 20 -50 44 -50 82 v24" fill="none" stroke="{c}" '
               'stroke-width="56" stroke-linecap="round"/><circle cx="540" cy="760" r="34" fill="{c}"/>',
}


def highlight(name):
    icon = HIGHLIGHT_ICONS[name].format(c=ACCENT)
    svg = f'<svg width="1080" height="1080" viewBox="0 0 1080 1080">{icon}</svg>'
    return page(1080, 1920, svg)


# ------------------------------------------------------------------ posts

def post_hero(w, h):
    return page(w, h, f"""
      <img src="logo.png" style="width:220px;height:220px;margin-bottom:56px">
      <div class="display" style="font-size:112px;padding:0 70px">Can you stop at exactly <span class="accent">10.00</span> seconds?</div>
      <div class="secondary" style="font-size:44px;margin-top:44px">No timer. No clock. Just your gut.</div>
      {FOOTER}""")


def post_dead_on(w, h):
    return page(w, h, f"""
      {confetti_svg(w, h, count=110, band=0.22 if h < 1500 else 0.28)}
      <div class="display accent" style="font-size:120px;margin-bottom:12px;margin-top:{"120px" if h < 1500 else "0"}">Mia</div>
      <div class="display mono" style="font-size:250px">10.02 s</div>
      <div class="display mono accent" style="font-size:96px;margin-top:10px">+0.02</div>
      <div class="display accent" style="font-size:150px;margin-top:6px">DEAD ON</div>
      <div style="font-size:46px;margin-top:40px">Mic drop. Phone stays.</div>
      {FOOTER}""")


def post_tiers(w, h):
    rows = "".join(
        f'<div class="card" style="display:flex;align-items:center;justify-content:space-between;'
        f'padding:28px 44px;margin:12px 0">'
        f'<span class="display" style="font-size:60px;color:{color}">{name}</span>'
        f'<span class="secondary" style="font-size:36px">{rule} · {pts} pts</span></div>'
        for name, rule, color, pts in TIERS
    )
    return page(w, h, f"""
      <div class="display" style="font-size:92px;margin-bottom:40px">How close is close?</div>
      <div style="width:{w - 140}px;text-align:left">{rows}</div>
      {FOOTER}""")


def post_modes(w, h):
    cells = "".join(
        f'<div class="card" style="padding:30px 32px;text-align:left">'
        f'<div class="display" style="font-size:50px;color:{ACCENT if i < 3 else "#fff"}">{name}</div>'
        f'<div class="secondary" style="font-size:30px;margin-top:8px">{line}</div></div>'
        for i, (name, line) in enumerate(MODES)
    )
    return page(w, h, f"""
      <div class="display" style="font-size:96px;margin-bottom:12px">8 ways to lose</div>
      <div class="secondary" style="font-size:40px;margin-bottom:40px">your sense of time</div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:22px;width:{w - 140}px">{cells}</div>
      {FOOTER}""")


def post_tv(w, h):
    phone = ('<div style="width:130px;height:250px;border:10px solid #fff;border-radius:30px;display:flex;'
             'align-items:center;justify-content:center;padding:12px">'
             '<div class="pill" style="width:100%;height:100px;border-radius:20px;display:flex;align-items:center;'
             'justify-content:center;font-size:26px">START</div></div>')
    return page(w, h, f"""
      <div class="display" style="font-size:96px;margin-bottom:44px;margin-top:-60px">Play together<br>on the <span class="accent">TV</span></div>
      <div style="width:720px;height:400px;border:14px solid #fff;border-radius:40px;display:flex;flex-direction:column;
                  align-items:center;justify-content:center;position:relative;overflow:hidden">
        {confetti_svg(720, 400, count=40, seed=3, band=0.2)}
        <div class="display mono" style="font-size:140px">10.02 s</div>
        <div class="display accent" style="font-size:84px">DEAD ON</div>
      </div>
      <div style="display:flex;gap:56px;margin-top:44px">{phone}{phone}{phone}</div>
      <div class="secondary" style="font-size:38px;margin-top:32px">Everyone plays on their own iPhone.</div>
      {FOOTER}""")


def post_challenge(w, h):
    return page(w, h, f"""
      <div class="pill" style="font-size:44px;padding:16px 40px;margin-bottom:56px">CHALLENGE</div>
      <div class="display" style="font-size:118px;padding:0 60px">Stop at <span class="accent">10.00</span>.<br>No peeking.</div>
      <div class="secondary" style="font-size:46px;margin-top:48px;padding:0 90px">Comment your best time.<br>Closest to ten gets bragging rights.</div>
      {FOOTER}""")


POSTS = {
    "01-hero": post_hero,
    "02-dead-on": post_dead_on,
    "03-how-close": post_tiers,
    "04-modes": post_modes,
    "05-tv": post_tv,
    "06-challenge": post_challenge,
}


# ------------------------------------------------------------------- reel

REEL = f"""<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}
.frame {{ width:1080px; height:1920px; }}
.scene {{ position:absolute; inset:0; display:flex; flex-direction:column; align-items:center;
          justify-content:center; text-align:center; opacity:0; }}
#confetti {{ position:absolute; inset:0; }}
</style></head><body><div class="frame">
  <div class="scene" id="intro">
    <img src="logo.png" style="width:260px;height:260px;margin-bottom:60px">
    <div class="display" style="font-size:120px;padding:0 70px">Can you feel<br><span class="accent">10 seconds</span>?</div>
  </div>
  <div class="scene" id="start">
    <div class="secondary" style="font-size:52px;margin-bottom:24px">Mia</div>
    <div class="display mono" style="font-size:110px;margin-bottom:70px">Stop at 10.00</div>
    <div id="startButton" class="pill" style="width:860px;height:640px;border-radius:80px;display:flex;
         align-items:center;justify-content:center;font-size:160px">START</div>
  </div>
  <div class="scene" id="blind" style="background:#000">
    <div id="blindText" style="font-size:44px;color:#5a5a5a">Tap anywhere to stop</div>
    <div id="gut" class="display" style="font-size:84px;margin-top:60px;opacity:0">No timer.<br>No clock.<br>Just your gut.</div>
  </div>
  <div class="scene" id="reveal">
    <canvas id="confetti" width="1080" height="1920"></canvas>
    <div id="name" class="display" style="font-size:72px;color:{SECONDARY};margin-bottom:10px">Mia</div>
    <div id="number" class="display mono" style="font-size:240px">0.00 s</div>
    <div id="verdict" style="opacity:0">
      <div class="display mono accent" style="font-size:96px;margin-top:20px">+0.02</div>
      <div class="display accent" style="font-size:170px">DEAD ON</div>
    </div>
  </div>
  <div id="tap" style="position:absolute;width:160px;height:160px;border-radius:50%;border:10px solid #fff;opacity:0"></div>
  <div class="footer" id="footer" style="opacity:0"><img src="logo.png">BLIND TEN · on the App Store</div>
</div>
<script>
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const fade = (t, start, end) => clamp((t - start) / (end - start));
function mulberry32(a) {{ return function() {{ a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a);
  t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }}; }}
const rnd = mulberry32(10);
const colors = ["{ACCENT}", "{EARLY}", "{LATE}", "#ffffff", "#40F28C", "#FF73D9"];
const pieces = Array.from({{length: 180}}, (_, i) => ({{
  x: rnd(), y: -0.15 + rnd() * 0.2, vx: (rnd() - 0.5) * 0.5, vy: -0.35 + rnd() * 0.5,
  spin: (rnd() - 0.5) * 18, flutter: 4 + rnd() * 8, w: 14 + rnd() * 10, h: 22 + rnd() * 14, c: colors[i % colors.length] }}));
const $ = id => document.getElementById(id);
function show(id, o) {{ $(id).style.opacity = o; }}
function render(t) {{
  // 0.0–1.6 intro, 1.6–3.0 START, 3.0–6.0 blind, 6.0–7.3 drumroll, 7.3– landed
  show("intro", fade(t, 0, 0.3) * (1 - fade(t, 1.4, 1.6)));
  show("start", fade(t, 1.6, 1.8) * (t < 2.9 ? 1 : 0));
  const pressed = t > 2.7 && t < 2.9;
  $("startButton").style.transform = pressed ? "scale(0.96)" : "scale(1)";
  show("blind", t >= 2.9 && t < 6.0 ? 1 : 0);
  $("gut").style.opacity = fade(t, 3.6, 4.0) * (1 - fade(t, 5.4, 5.7));
  show("reveal", t >= 6.0 ? 1 : 0);
  const roll = clamp((t - 6.0) / 1.3);
  const eased = 1 - Math.pow(1 - roll, 3);
  $("number").textContent = (10.02 * eased).toFixed(2) + " s";
  const landed = t >= 7.3;
  $("name").style.color = landed ? "{ACCENT}" : "{SECONDARY}";
  const pop = fade(t, 7.3, 7.55);
  $("verdict").style.opacity = pop;
  $("verdict").style.transform = `scale(${{0.6 + 0.4 * pop}})`;
  show("footer", fade(t, 8.2, 8.6));
  // taps: START at 2.7 s, STOP at 5.9 s
  const tapAt = t >= 2.7 && t < 3.1 ? [540, 1360, t - 2.7] : t >= 5.9 && t < 6.3 ? [620, 1100, t - 5.9] : null;
  if (tapAt) {{
    const p = tapAt[2] / 0.4;
    $("tap").style.left = (tapAt[0] - 80) + "px"; $("tap").style.top = (tapAt[1] - 80) + "px";
    $("tap").style.opacity = 1 - p; $("tap").style.transform = `scale(${{0.6 + p}})`;
  }} else {{ $("tap").style.opacity = 0; }}
  // white flash and confetti on DEAD ON
  const ctx = $("confetti").getContext("2d");
  ctx.clearRect(0, 0, 1080, 1920);
  const flash = landed ? Math.max(0, 0.8 - (t - 7.3) * 1.6) : 0;
  if (landed) {{
    const e = t - 7.3;
    for (const p of pieces) {{
      const x = (p.x + p.vx * e) * 1080, y = (p.y + p.vy * e + 0.45 * e * e) * 1920;
      if (y > 1950) continue;
      ctx.save(); ctx.translate(x, y); ctx.rotate(p.spin * e); ctx.scale(Math.cos(p.flutter * e), 1);
      ctx.fillStyle = p.c; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); ctx.restore();
    }}
  }}
  document.querySelector(".frame").style.boxShadow = flash ? `inset 0 0 0 2000px rgba(255,255,255,${{flash}})` : "none";
}}
render(0);
</script></body></html>"""


# ----------------------------------------------------------------- output

def write(name, html):
    BUILD.mkdir(exist_ok=True)
    path = TOOLS / f"_{name}.html"  # next to fonts/ and logo.png so relative URLs work
    path.write_text(html)
    return path


def shoot(pg, html_path, out, width, height, jpeg=False):
    out.parent.mkdir(parents=True, exist_ok=True)
    pg.set_viewport_size({"width": width, "height": height})
    pg.goto(html_path.as_uri())
    pg.evaluate("document.fonts.ready")
    pg.wait_for_timeout(150)
    if jpeg:
        pg.screenshot(path=str(out), type="jpeg", quality=92)
    else:
        pg.screenshot(path=str(out))
    print("wrote", out.relative_to(OUT.parent))


def render_reel(pg, out, seconds=10.0, fps=30):
    frames = BUILD / "reel"
    shutil.rmtree(frames, ignore_errors=True)
    frames.mkdir(parents=True)
    path = write("reel", REEL)
    pg.set_viewport_size({"width": 1080, "height": 1920})
    pg.goto(path.as_uri())
    pg.evaluate("document.fonts.ready")
    for i in range(int(seconds * fps)):
        pg.evaluate(f"render({i / fps})")
        pg.screenshot(path=str(frames / f"{i:04d}.png"))
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps), "-i", str(frames / "%04d.png"),
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-movflags", "+faststart", str(out)],
        check=True,
    )
    path.unlink()
    print("wrote", out.relative_to(OUT.parent))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-video", action="store_true")
    args = parser.parse_args()

    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        pg = browser.new_page()
        temp = []

        path = write("profile", profile_picture()); temp.append(path)
        shoot(pg, path, OUT / "profile" / "profile-picture-1080.png", 1080, 1080)

        for name in HIGHLIGHT_ICONS:
            path = write(f"hl-{name}", highlight(name)); temp.append(path)
            shoot(pg, path, OUT / "instagram" / "highlights" / f"{name}.png", 1080, 1920)

        for name, make in POSTS.items():
            path = write(f"post-{name}", make(1080, 1350)); temp.append(path)
            shoot(pg, path, OUT / "instagram" / "posts" / f"{name}.jpg", 1080, 1350, jpeg=True)
            path = write(f"tall-{name}", make(1080, 1920)); temp.append(path)
            shoot(pg, path, OUT / "tiktok" / "covers" / f"{name}.jpg", 1080, 1920, jpeg=True)

        if not args.no_video:
            if not shutil.which("ffmpeg"):
                sys.exit("ffmpeg is needed for the reel (or pass --no-video)")
            render_reel(pg, OUT / "video" / "dead-on-reel.mp4")

        for path in temp:
            path.unlink()
        browser.close()


if __name__ == "__main__":
    main()
