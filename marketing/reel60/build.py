#!/usr/bin/env python3
"""Builds the 60 s reel from shots.json.

- "app" shots: Blind Ten screens re-drawn in the app's design and animated
  frame by frame (START, blind phase, reveals, Showdown, TV, DEAD ON).
- "ai" shots: your generated clips from clips/<ID>.mp4 (any size; cropped to
  9:16). Missing clips become placeholder cards, so the cut works as an
  animatic before any footage exists.
- Overlays: text in the app's type and colors, inside the safe zone.
- Sound: music.mp3 or music.wav next to this file if present, else the
  generated track from music.py, plus the app's own sound effects.

    python3 marketing/reel60/build.py
    -> marketing/video/reel-60s.mp4           (all AI clips present)
    -> marketing/video/reel-60s-animatic.mp4  (some still missing)

Needs playwright, ffmpeg and Chromium (set CHROMIUM=/path if needed).
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE.parent / "tools"))
import render  # noqa: E402  (shared CSS, colors and helpers)

from playwright.sync_api import sync_playwright  # noqa: E402

CONFIG = json.loads((HERE / "shots.json").read_text())
FPS, W, H = CONFIG["fps"], CONFIG["width"], CONFIG["height"]
BUILD = HERE / "build"
CLIPS = HERE / "clips"
SOUNDS = ROOT / "BlindTen" / "Resources" / "Sounds"
OUT = HERE.parent / "video"

ACCENT, SECONDARY = render.ACCENT, render.SECONDARY

ANIM_CSS = """
.layer { position:absolute; inset:0; display:flex; flex-direction:column; align-items:center;
         justify-content:center; text-align:center; }
.tap { position:absolute; width:170px; height:170px; border-radius:50%; border:10px solid #fff; opacity:0; }
"""

CONFETTI_JS = f"""
function mulberry32(a) {{ return function() {{ a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a);
  t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }}; }}
const rnd = mulberry32(10);
const colors = ["{ACCENT}", "{render.EARLY}", "{render.LATE}", "#ffffff", "#40F28C", "#FF73D9"];
const pieces = Array.from({{length: 180}}, (_, i) => ({{ x: rnd(), y: -0.15 + rnd() * 0.2,
  vx: (rnd() - 0.5) * 0.5, vy: -0.35 + rnd() * 0.5, spin: (rnd() - 0.5) * 18, flutter: 4 + rnd() * 8,
  w: 14 + rnd() * 10, h: 22 + rnd() * 14, c: colors[i % colors.length] }}));
function confetti(canvas, e) {{
  const ctx = canvas.getContext("2d"); ctx.clearRect(0, 0, canvas.width, canvas.height);
  if (e < 0) return;
  for (const p of pieces) {{
    const x = (p.x + p.vx * e) * canvas.width, y = (p.y + p.vy * e + 0.45 * e * e) * canvas.height;
    if (y > canvas.height + 30) continue;
    ctx.save(); ctx.translate(x, y); ctx.rotate(p.spin * e); ctx.scale(Math.cos(p.flutter * e), 1);
    ctx.fillStyle = p.c; ctx.fillRect(-p.w / 2, -p.h / 2, p.w, p.h); ctx.restore();
  }}
}}
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
function tap(el, x, y, t, at) {{
  const p = (t - at) / 0.4;
  if (p < 0 || p > 1) {{ el.style.opacity = 0; return; }}
  el.style.left = (x - 85) + "px"; el.style.top = (y - 85) + "px";
  el.style.opacity = 1 - p; el.style.transform = `scale(${{0.6 + p}})`;
}}
"""


def anim_page(body, script):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{render.BASE_CSS}
.frame {{ width:{W}px; height:{H}px; }} {ANIM_CSS}</style></head>
<body><div class="frame">{body}<div class="tap" id="tap"></div></div>
<script>{CONFETTI_JS}
const $ = id => document.getElementById(id);
{script}
render(0);</script></body></html>"""


# ------------------------------------------------------------- app scenes

def scene_start():
    body = f"""<div class="layer" style="padding-top:420px">
      <div class="secondary" style="font-size:52px;margin-bottom:20px">Mia</div>
      <div class="display mono" style="font-size:104px;margin-bottom:60px">Stop at 10.00</div>
      <div id="btn" class="pill" style="width:900px;height:640px;border-radius:84px;display:flex;align-items:center;
           justify-content:center;font-size:170px">START</div></div>
      <div class="layer" id="go" style="background:{ACCENT};opacity:0"></div>"""
    script = """function render(t) {
      $("btn").style.transform = t > 1.6 && t < 1.8 ? "scale(0.96)" : "scale(1)";
      tap($("tap"), 540, 1420, t, 1.6);
      $("go").style.opacity = t < 1.75 ? 0 : Math.max(0, 0.8 - (t - 1.75) / 0.3 * 0.8);
      document.querySelector(".layer").style.opacity = t < 1.75 ? 1 : 0;
    }"""
    return anim_page(body, script)


def scene_blind():
    body = """<div class="layer"><div style="font-size:46px;color:#5a5a5a">Tap anywhere to stop</div></div>"""
    script = "function render(t) { tap($('tap'), 640, 1150, t, 1.55); }"
    return anim_page(body, script)


def scene_reveal(name, final, verdict_html, roll, landed_effects=False, name_color=None):
    """The app's drumroll and landing. `roll` is the count-up time; a roll
    longer than the shot never lands (the drumroll shot)."""
    body = f"""<canvas id="confetti" width="{W}" height="{H}" style="position:absolute;inset:0"></canvas>
      <div class="layer">
        <div id="name" class="display" style="font-size:80px;color:{SECONDARY};margin-bottom:12px">{name}</div>
        <div id="number" class="display mono" style="font-size:250px">0.00 s</div>
        <div id="verdict" style="opacity:0">{verdict_html}</div>
      </div>
      <div class="layer" id="flash" style="background:#fff;opacity:0"></div>"""
    script = f"""const final = {final}, roll = {roll}, effects = {str(landed_effects).lower()};
    function render(t) {{
      const p = roll > 0 ? clamp(t / roll) : 1, eased = 1 - Math.pow(1 - p, 3);
      $("number").textContent = (final * eased).toFixed(2) + " s";
      const landed = roll <= 0 || t >= roll;
      const pop = landed ? clamp((t - Math.max(roll, 0)) / 0.25) : 0;
      $("verdict").style.opacity = pop; $("verdict").style.transform = `scale(${{0.6 + 0.4 * pop}})`;
      $("name").style.color = landed && effects ? "{name_color or ACCENT}" : "{SECONDARY}";
      $("flash").style.opacity = landed && effects ? Math.max(0, 0.85 - (t - Math.max(roll, 0)) * 1.7) : 0;
      confetti($("confetti"), landed && effects ? t - Math.max(roll, 0) : -1);
    }}"""
    return anim_page(body, script)


def verdict(tier, color, deviation, dev_color, extra=""):
    return (f'<div class="display mono" style="font-size:96px;margin-top:20px;color:{dev_color}">{deviation}</div>'
            f'<div class="display" style="font-size:150px;color:{color}">{tier}</div>{extra}')


def scene_showdown():
    half = lambda name, rot: f"""<div style="flex:1;width:100%;display:flex;align-items:center;justify-content:center;
        transform:rotate({rot}deg)"><div class="hl" style="width:100%;height:100%;background:{ACCENT};color:#000;
        display:flex;flex-direction:column;align-items:center;justify-content:center;border-radius:48px">
        <div class="display" style="font-size:70px">{name}</div>
        <div style="font-size:52px;font-weight:800;margin:10px 0 18px">Stop at 10.00</div>
        <div class="display" style="font-size:130px">START</div></div></div>"""
    body = f"""<div class="layer" style="padding:24px;gap:16px;justify-content:stretch">
      {half("Jay", 180)}{half("Mia", 0)}</div><div class="tap" id="tap2"></div>"""
    script = """function render(t) {
      const halves = document.querySelectorAll(".hl");
      halves[0].style.background = t > 1.55 ? "#000" : "#FFD100";
      halves[1].style.background = t > 1.35 ? "#000" : "#FFD100";
      tap($("tap"), 540, 1500, t, 1.3); tap($("tap2"), 540, 760, t, 1.5);
    }"""
    return anim_page(body, script)


def scene_tv():
    phones = "".join(
        f"""<div style="width:190px;height:380px;border:12px solid #fff;border-radius:44px;display:flex;flex-direction:column;
            align-items:center;justify-content:center;gap:10px;background:#000">
            <div style="font-size:64px">{emoji}</div><div class="display" style="font-size:30px">{name}</div></div>"""
        for emoji, name in (("🦊", "Mia"), ("🐸", "Jay"), ("🐙", "Zoe"))
    )
    body = f"""<div class="layer" style="padding-top:330px;background:radial-gradient(circle at 50% 45%, #2a2410 0%, #000 65%)">
      <div style="width:980px;height:551px;border:18px solid #222;border-radius:28px;background:#000;position:relative;
                  overflow:hidden;box-shadow:0 0 120px rgba(255,209,0,0.25)">
        <canvas id="confetti" width="944" height="515" style="position:absolute;inset:0"></canvas>
        <div id="lobby" class="layer">
          <div class="display" style="font-size:54px">Join on your iPhone</div>
          <div style="font-size:84px;margin:18px 0">🦊🐙🐳</div>
          <div class="secondary" style="font-size:34px">3 players</div></div>
        <div id="board" class="layer" style="opacity:0">
          <div class="display accent" style="font-size:44px">Jay</div>
          <div class="display mono" style="font-size:150px">10.00 s</div>
          <div class="display accent" style="font-size:90px">DEAD ON</div></div>
      </div>
      <div style="width:90px;height:20px;background:#222;margin-top:0"></div>
      <div style="display:flex;gap:60px;margin-top:90px">{phones}</div></div>"""
    script = """function render(t) {
      const show = clamp((t - 1.3) / 0.25);
      $("lobby").style.opacity = 1 - show; $("board").style.opacity = show;
      $("board").style.transform = `scale(${0.7 + 0.3 * show})`;
      confetti($("confetti"), t > 1.3 ? t - 1.3 : -1);
    }"""
    return anim_page(body, script)


def scene_end():
    body = f"""<div class="layer">
      <img id="logo" src="logo.png" style="width:300px;height:300px">
      <div id="title" class="display" style="font-size:150px;letter-spacing:0.06em;margin-top:40px">BLIND TEN</div>
      <div id="tag" class="display" style="font-size:72px;margin-top:40px;padding:0 80px">Who's got the best<br><span class="accent">inner clock</span>?</div>
      <div id="soon" class="pill" style="font-size:58px;padding:24px 56px;margin-top:80px">Coming soon on iPhone</div>
      <div id="url" class="secondary" style="font-size:46px;margin-top:40px">blindten.com</div></div>"""
    script = """function render(t) {
      const a = id => clamp((t - id) / 0.35);
      $("logo").style.opacity = a(0); $("logo").style.transform = `scale(${0.6 + 0.4 * a(0)}) rotate(${(1 - a(0)) * -90}deg)`;
      $("title").style.opacity = a(0.4); $("tag").style.opacity = a(1.1);
      $("soon").style.opacity = a(2.0); $("soon").style.transform = `scale(${0.8 + 0.2 * a(2.0)})`;
      $("url").style.opacity = a(2.6);
    }"""
    return anim_page(body, script)


SCENES = {
    "start": scene_start,
    "blind": scene_blind,
    "reveal-lost": lambda: scene_reveal("Ben", 12.88, verdict("Lost in time", render.LATE, "+2.88", render.LATE), 1.25),
    "reveal-sharp": lambda: scene_reveal("Zoe", 9.94, verdict("Sharp", "#40F28C", "−0.06", render.EARLY), 1.0),
    "showdown": scene_showdown,
    "tv": scene_tv,
    "drumroll": lambda: scene_reveal("Jay", 10.00, "", 2.3),
    "dead-on": lambda: scene_reveal("Jay", 10.00, verdict("DEAD ON", ACCENT, "+0.00", ACCENT), 0, landed_effects=True),
    "end": scene_end,
}


# ---------------------------------------------------------- stills / overlay

def rich(text):
    """[word] in brackets is drawn in the accent color."""
    return text.replace("[", f'<span style="color:{ACCENT}">').replace("]", "</span>")


def overlay_page(overlay):
    step = overlay.get("step")
    pill = (f'<div class="pill" style="font-size:44px;padding:10px 30px;margin-bottom:18px">STEP {step}</div>'
            if step else "")
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{render.BASE_CSS}
html, body, .frame {{ background: transparent !important; }}
.frame {{ width:{W}px; height:{H}px; justify-content:flex-start; padding-top:230px; }}
.t {{ font-size:92px; font-weight:900; line-height:1.05; margin:0 80px; padding:22px 40px 28px;
      background: rgba(0,0,0,0.72); border-radius:40px; }}
</style></head><body><div class="frame">{pill}<div class="t">{rich(overlay["text"])}</div></div></body></html>"""


def placeholder_page(shot):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{render.BASE_CSS}
.frame {{ width:{W}px; height:{H}px; background: linear-gradient(160deg, #26231a, #000 70%); }}
</style></head><body><div class="frame">
  <div class="pill" style="font-size:40px;padding:10px 28px;margin-top:500px">AI SHOT {shot["id"]}</div>
  <div class="secondary" style="font-size:42px;line-height:1.35;padding:40px 110px 0">{shot["prompt"]}</div>
</div></body></html>"""


# ------------------------------------------------------------------ build

def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *args], check=True)


ENCODE = ["-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-r", str(FPS)]


def render_anim(pg, html, seconds, out):
    frames = BUILD / "frames"
    shutil.rmtree(frames, ignore_errors=True)
    frames.mkdir(parents=True)
    path = render.write("reel60", html)
    pg.set_viewport_size({"width": W, "height": H})
    pg.goto(path.as_uri())
    pg.evaluate("document.fonts.ready")
    for i in range(round(seconds * FPS)):
        pg.evaluate(f"render({i / FPS})")
        pg.screenshot(path=str(frames / f"{i:04d}.png"))
    path.unlink()
    ffmpeg("-framerate", str(FPS), "-i", str(frames / "%04d.png"), *ENCODE, str(out))


def render_still(pg, html, out, transparent=False):
    path = render.write("reel60", html)
    pg.set_viewport_size({"width": W, "height": H})
    pg.goto(path.as_uri())
    pg.evaluate("document.fonts.ready")
    pg.wait_for_timeout(100)
    pg.screenshot(path=str(out), omit_background=transparent)
    path.unlink()


def find_clip(shot_id):
    for ext in (".mp4", ".mov", ".m4v", ".webm"):
        path = CLIPS / f"{shot_id}{ext}"
        if path.exists():
            return path
    return None


def build_segment(pg, shot):
    seg = BUILD / f"{shot['id']}.mp4"
    base = BUILD / f"{shot['id']}-base.mp4"
    dur = shot["duration"]
    frames = ["-frames:v", str(round(dur * FPS))]
    missing = False
    if shot["type"] in ("app", "card"):
        render_anim(pg, SCENES[shot["scene"]](), dur, base)
    else:
        clip = find_clip(shot["id"])
        if clip:
            # "offset" skips the calm start of a generated clip; "zoom" crops
            # into the middle, e.g. to hide UI the model drew at the edges.
            offset, zoom = shot.get("offset", 1.0), shot.get("zoom", 1.0)
            zw, zh = round(W * zoom / 2) * 2, round(H * zoom / 2) * 2
            ffmpeg("-ss", f"{offset}", "-i", str(clip), "-t", f"{dur}", "-an", "-vf",
                   f"scale={zw}:{zh}:force_original_aspect_ratio=increase,crop={W}:{H},setsar=1,fps={FPS}",
                   *ENCODE, *frames, str(base))
        else:
            missing = True
            still = BUILD / f"{shot['id']}-placeholder.png"
            render_still(pg, placeholder_page(shot), still)
            ffmpeg("-loop", "1", "-framerate", str(FPS), "-i", str(still), *ENCODE, *frames, str(base))
    if "overlay" in shot:
        png = BUILD / f"{shot['id']}-overlay.png"
        render_still(pg, overlay_page(shot["overlay"]), png, transparent=True)
        ffmpeg("-i", str(base), "-loop", "1", "-framerate", str(FPS), "-i", str(png), "-filter_complex",
               "[1:v]format=rgba,fade=in:st=0:d=0.15:alpha=1[o];[0:v][o]overlay=0:0:eof_action=repeat",
               *ENCODE, *frames, str(seg))
    else:
        base.rename(seg)
    return seg, missing


def build_audio(out):
    music = next((HERE / name for name in ("music.mp3", "music.wav") if (HERE / name).exists()), None)
    if music is None:
        music = BUILD / "music.wav"
        subprocess.run([sys.executable, str(HERE / "music.py"), str(music)], check=True)
    inputs, filters, labels = ["-i", str(music)], ["[0:a]volume=0.9[m]"], ["[m]"]
    for i, fx in enumerate(CONFIG["sfx"], start=1):
        inputs += ["-i", str(SOUNDS / fx["file"])]
        delay = int(fx["at"] * 1000)
        filters.append(f"[{i}:a]adelay={delay}|{delay},volume=1.1[s{i}]")
        labels.append(f"[s{i}]")
    filters.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0,atrim=0:60,"
                   "loudnorm=I=-14:TP=-1.5:LRA=11[a]")
    ffmpeg(*inputs, "-filter_complex", ";".join(filters), "-map", "[a]", "-ar", "44100", "-ac", "2", str(out))


def main():
    shutil.rmtree(BUILD, ignore_errors=True)
    BUILD.mkdir(parents=True)
    CLIPS.mkdir(exist_ok=True)
    segments, missing = [], []
    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        pg = browser.new_page()
        for shot in CONFIG["shots"]:
            seg, is_missing = build_segment(pg, shot)
            segments.append(seg)
            if is_missing:
                missing.append(shot["id"])
            print("built", shot["id"], "(placeholder)" if is_missing else "")
        browser.close()

    listing = BUILD / "segments.txt"
    listing.write_text("".join(f"file '{s}'\n" for s in segments))
    video = BUILD / "video.mp4"
    ffmpeg("-f", "concat", "-safe", "0", "-i", str(listing), "-c", "copy", str(video))
    audio = BUILD / "audio.m4a"
    build_audio(audio)

    OUT.mkdir(exist_ok=True)
    name = "reel-60s-animatic.mp4" if missing else "reel-60s.mp4"
    final = OUT / name
    ffmpeg("-i", str(video), "-i", str(audio), "-map", "0:v", "-map", "1:a", "-c:v", "copy",
           "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", str(final))
    print("wrote", final.relative_to(ROOT))
    if missing:
        print("missing AI clips:", ", ".join(missing), "-> put them in", CLIPS.relative_to(ROOT))


if __name__ == "__main__":
    main()
