#!/usr/bin/env python3
"""Renders the App Store product page header and search result artwork.

Text on the left, three iPhones with the real App Store screenshots on the
right, in the app's look (yellow on black, Nunito, the stopwatch logo).
Key content stays inside the middle of the canvas, since the App Store
crops these images differently per device. Output: RGB JPEG, no alpha.

    python3 marketing/appstore-art/render.py

Set CHROMIUM=/path/to/chrome if Playwright has no browser of its own.
"""
import base64
import io
import os
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FONTS = ROOT / "marketing" / "tools" / "fonts"
SHOTS = ROOT / "AppStore" / "Screenshots" / "iPhone-6.9"
OUT = ROOT / "AppStore" / "Artwork"

SIZES = {
    "header-5244x2950": (5244, 2950),
    "header-3840x1646": (3840, 1646),
    "search-5244x2950": (5244, 2950),
    "search-3840x2560": (3840, 2560),
    "search-1920x1280": (1920, 1280),
}

# Left to right: back, front, back.
PHONES = ["6-home.jpg", "1-dead-on.jpg", "7-streak.jpg"]


def data_uri(path, mime):
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def page(width, height):
    # One unit scales everything so 16:9, 7:3 and 3:2 canvases all fit.
    u = min(width / 2.25, height) / 100
    fonts = "".join(
        f"@font-face {{ font-family: Nunito; font-weight: {w}; src: url({data_uri(FONTS / f'nunito-latin-{w}-normal.woff2', 'font/woff2')}); }}"
        for w in (800, 900)
    )
    phones = "".join(
        f'<div class="phone p{i}"><img src="{data_uri(SHOTS / name, "image/jpeg")}"></div>'
        for i, name in enumerate(PHONES)
    )
    logo = data_uri(ROOT / "marketing" / "tools" / "logo.png", "image/png")
    return f"""<!doctype html><html><head><style>
{fonts}
* {{ box-sizing: border-box; margin: 0; }}
html, body {{ width: {width}px; height: {height}px; background: #0A0A0C; overflow: hidden; }}
body {{
  font-family: Nunito; color: #fff; display: flex; align-items: center; justify-content: center;
  gap: {6 * u}px;
  background:
    radial-gradient(ellipse {70 * u}px {60 * u}px at 72% 55%, rgba(255,209,0,0.28), transparent 70%),
    radial-gradient(ellipse {60 * u}px {50 * u}px at 18% 30%, rgba(255,209,0,0.10), transparent 70%),
    #0A0A0C;
}}
.ring {{
  position: absolute; width: {130 * u}px; height: {130 * u}px; border-radius: 50%;
  border: {5 * u}px solid rgba(255,209,0,0.07); right: {-10 * u}px; top: 50%; transform: translateY(-50%);
}}
.text {{ width: {88 * u}px; position: relative; z-index: 2; }}
.brand {{ display: flex; align-items: center; gap: {2.4 * u}px; margin-bottom: {4 * u}px; }}
.brand img {{ width: {11 * u}px; height: {11 * u}px; }}
.brand span {{ font-weight: 900; font-size: {7.2 * u}px; letter-spacing: {0.1 * u}px; }}
h1 {{ font-weight: 900; font-size: {11.5 * u}px; line-height: 1.02; letter-spacing: {-0.2 * u}px; }}
h1 em {{ font-style: normal; color: #FFD100; }}
p {{ font-weight: 800; font-size: {4.3 * u}px; line-height: 1.3; color: #B8B8B8; margin-top: {3.4 * u}px; }}
.chips {{ display: flex; gap: {1.4 * u}px; margin-top: {4.4 * u}px; }}
.chip {{
  font-weight: 900; font-size: {3.1 * u}px; padding: {1.2 * u}px {2.4 * u}px; border-radius: {10 * u}px;
  white-space: nowrap;
  background: #1C1C1C; color: #fff;
}}
.chip.y {{ background: #FFD100; color: #000; }}
.phones {{ position: relative; width: {92 * u}px; height: {84 * u}px; z-index: 1; }}
.phone {{
  position: absolute; top: 50%; left: 50%; height: {74 * u}px; aspect-ratio: 1320 / 2868;
  border-radius: {7.6 * u}px; padding: {1.1 * u}px; background: #2A2A2E;
  box-shadow: 0 {3 * u}px {8 * u}px rgba(0,0,0,0.6), 0 0 0 {0.25 * u}px #3A3A40;
}}
.phone img {{ width: 100%; height: 100%; border-radius: {6.6 * u}px; display: block; }}
.p1 {{ transform: translate(-50%, -50%); z-index: 3; height: {80 * u}px; }}
.p0 {{ transform: translate(-112%, -47%) rotate(-8deg); z-index: 2; opacity: 0.95; }}
.p2 {{ transform: translate(12%, -47%) rotate(8deg); z-index: 2; opacity: 0.95; }}
</style></head><body>
<div class="ring"></div>
<div class="text">
  <div class="brand"><img src="{logo}"><span>Blind Ten</span></div>
  <h1>Can you feel<br><em>10 seconds?</em></h1>
  <p>Tap START, the timer vanishes. Stop at exactly 10.00. Closest wins.</p>
  <div class="chips"><span class="chip y">Party game</span><span class="chip">Daily Challenge</span><span class="chip">Online duels</span></div>
</div>
<div class="phones">{phones}</div>
</body></html>"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        for name, (width, height) in SIZES.items():
            page_ = browser.new_page(viewport={"width": width, "height": height})
            page_.set_content(page(width, height))
            page_.evaluate("document.fonts.ready")
            page_.wait_for_timeout(300)
            png = page_.screenshot(clip={"x": 0, "y": 0, "width": width, "height": height})
            image = Image.open(io.BytesIO(png)).convert("RGB")
            assert image.size == (width, height), image.size
            out = OUT / f"{name}.jpg"
            image.save(out, quality=92, optimize=True)
            print("Wrote", out.relative_to(ROOT), image.size)
            page_.close()
        browser.close()


if __name__ == "__main__":
    main()
