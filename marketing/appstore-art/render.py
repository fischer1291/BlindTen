#!/usr/bin/env python3
"""Renders the App Store product page header and search result artwork.

Follows Apple's asset best practices: one universal design for both
placements, a single clear idea with the focal point in the center (one
iPhone at the DEAD ON moment, in a yellow glow with confetti), a short
phrase that adds to the visual, no logo or app name (the App Store shows
those), and the bottom edge kept clear for the App Store's own overlay.

Formats per Apple's creative asset specifications: the 16:9 sizes must be
PNG, the others are JPEG; no alpha channel.

    python3 marketing/appstore-art/render.py

Set CHROMIUM=/path/to/chrome if Playwright has no browser of its own.
"""
import base64
import io
import math
import os
import random
from pathlib import Path

from PIL import Image, ImageCms
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
FONTS = ROOT / "marketing" / "tools" / "fonts"
SCREENSHOT = ROOT / "AppStore" / "Screenshots" / "iPhone-6.9" / "1-dead-on.jpg"
OUT = ROOT / "AppStore" / "Artwork"

# name: (width, height, format)
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()

SIZES = {
    "header-16x9-5244x2950": (5244, 2950, "png"),
    "header-21x9-3840x1646": (3840, 1646, "jpg"),
    "search-16x9-5244x2950": (5244, 2950, "png"),
    "search-3x2-3840x2560": (3840, 2560, "jpg"),
    "search-3x2-1920x1280": (1920, 1280, "jpg"),
}

ACCENT = "#FFD100"
CONFETTI = ["#FFD100", "#FFFFFF", "#FF5454", "#54A6FF", "#40F28C", "#FF9E40"]


def data_uri(path, mime):
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def confetti(cx, cy, inner, outer, count, seed, band):
    """A still burst around the phone, denser near it. It stays within
    `band` of the center line, so the phrase on both sides stays clean."""
    rng = random.Random(seed)
    pieces = []
    while len(pieces) < count:
        angle = rng.uniform(0, 2 * math.pi)
        distance = inner + (outer - inner) * rng.random() ** 1.6
        x, y = cx + math.cos(angle) * distance, cy + math.sin(angle) * distance * 0.8
        if abs(x - cx) > band:
            continue
        w, h = rng.uniform(0.5, 1.0) * inner * 0.05, rng.uniform(0.25, 0.45) * inner * 0.05
        rotation = rng.uniform(0, 360)
        color = rng.choice(CONFETTI)
        opacity = max(0.25, 1 - (distance - inner) / (outer - inner))
        pieces.append(f'<rect x="{x - w / 2:.1f}" y="{y - h / 2:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{h / 3:.1f}" '
                      f'fill="{color}" opacity="{opacity:.2f}" transform="rotate({rotation:.0f} {x:.1f} {y:.1f})"/>')
    return "".join(pieces)


def page(width, height):
    # The phone sets the scale: it fills most of the height, sitting a
    # little above center so the bottom stays clear for the App Store.
    phone_h = height * 0.78
    phone_w = phone_h * 1320 / 2868
    cx, cy = width / 2, height * 0.46
    side = (width - phone_w) / 2
    # The phrase, left and right of the phone, as large as fits.
    font = min(side * 0.82 / 6.4, height * 0.14)
    gap = phone_w * 0.18
    fonts = f"@font-face {{ font-family: Nunito; font-weight: 900; src: url({data_uri(FONTS / 'nunito-latin-900-normal.woff2', 'font/woff2')}); }}"
    svg = (
        f'<svg class="art" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
        + confetti(cx, cy, phone_h * 0.36, phone_h * 0.62, 70, seed=10, band=phone_w / 2 + gap * 0.55)
        + "</svg>"
    )
    return f"""<!doctype html><html><head><style>
{fonts}
* {{ margin: 0; box-sizing: border-box; }}
html, body {{ width: {width}px; height: {height}px; overflow: hidden; }}
body {{
  font-family: Nunito; font-weight: 900; position: relative;
  background:
    radial-gradient(circle {phone_h * 0.75:.0f}px at {cx:.0f}px {cy:.0f}px, rgba(255,209,0,0.30), rgba(255,209,0,0.06) 60%, transparent 100%),
    #0A0A0C;
}}
.art {{ position: absolute; inset: 0; }}
.phone {{
  position: absolute; left: {cx - phone_w / 2:.0f}px; top: {cy - phone_h / 2:.0f}px;
  width: {phone_w:.0f}px; height: {phone_h:.0f}px; border-radius: {phone_w * 0.16:.0f}px;
  padding: {phone_w * 0.022:.0f}px; background: #2A2A2E;
  box-shadow: 0 {phone_h * 0.03:.0f}px {phone_h * 0.08:.0f}px rgba(0,0,0,0.7), 0 0 0 {phone_w * 0.005:.0f}px #45454C;
  transform: rotate(-4deg);
}}
.phone img {{ width: 100%; height: 100%; display: block; border-radius: {phone_w * 0.14:.0f}px; }}
.phrase {{
  position: absolute; top: {cy:.0f}px; transform: translateY(-50%);
  font-size: {font:.0f}px; line-height: 1; letter-spacing: {-font * 0.02:.1f}px; white-space: nowrap;
}}
.left {{ right: {cx + phone_w / 2 + gap:.0f}px; color: #FFFFFF; text-align: right; }}
.right {{ left: {cx + phone_w / 2 + gap:.0f}px; color: {ACCENT}; }}
</style></head><body>
{svg}
<div class="phrase left">Can you feel</div>
<div class="phone"><img src="{data_uri(SCREENSHOT, 'image/jpeg')}"></div>
<div class="phrase right">10 seconds?</div>
</body></html>"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.jpg"):
        old.unlink()
    for old in OUT.glob("*.png"):
        old.unlink()
    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        for name, (width, height, kind) in SIZES.items():
            tab = browser.new_page(viewport={"width": width, "height": height})
            tab.set_content(page(width, height))
            tab.evaluate("document.fonts.ready")
            tab.wait_for_timeout(300)
            png = tab.screenshot(clip={"x": 0, "y": 0, "width": width, "height": height})
            image = Image.open(io.BytesIO(png)).convert("RGB")
            assert image.size == (width, height), image.size
            out = OUT / f"{name}.{kind}"
            # Tagged sRGB at 72 dpi, like a design tool's export: untagged
            # files can be rejected by App Store Connect's upload check.
            tags = {"icc_profile": SRGB, "dpi": (72, 72)}
            if kind == "png":
                image.save(out, optimize=True, **tags)
            else:
                image.save(out, quality=92, optimize=True, **tags)
            print("Wrote", out.relative_to(ROOT), image.size, image.mode)
            tab.close()
        browser.close()


if __name__ == "__main__":
    main()
