#!/usr/bin/env python3
"""Renders the Game Center achievement images (1024x1024, RGB, no alpha).

Game Center shows them in a circle, so each badge is centred and keeps its
content inside the circle. Same look as the app: yellow on black, Nunito,
and the stopwatch ring with the gap from the logo.

    python3 marketing/achievements/render.py

Set CHROMIUM=/path/to/chrome if Playwright has no browser of its own.
"""
import base64
import io
import os
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

HERE = Path(__file__).resolve().parent
FONTS = HERE.parent / "tools" / "fonts"
ACCENT = "#FFD100"
BG = "#0A0A0C"

# Ring with the logo's gap (100°–150°, 0° = right, clockwise).
def ring(r, width, color, gap=(100, 150), cx=512, cy=512):
    import math
    a0, a1 = math.radians(gap[1]), math.radians(gap[0] + 360)
    x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
    x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
    return (f'<path d="M {x0:.1f} {y0:.1f} A {r} {r} 0 1 1 {x1:.1f} {y1:.1f}" '
            f'fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>')


def dots(count, filled, y, spacing=56, r=17):
    start = 512 - spacing * (count - 1) / 2
    return "".join(
        f'<circle cx="{start + i * spacing:.1f}" cy="{y}" r="{r}" fill="{ACCENT}" opacity="{1 if i < filled else 0.25}"/>'
        for i in range(count)
    )


def text(value, y, size, color=ACCENT, weight=900, spacing=0):
    return (f'<text x="512" y="{y}" text-anchor="middle" font-family="Nunito" font-weight="{weight}" '
            f'font-size="{size}" letter-spacing="{spacing}" fill="{color}">{value}</text>')


BADGES = {
    # DEAD ON: a bullseye inside the ring, the hit dead centre.
    "deadon": ring(400, 44, ACCENT)
        + f'<circle cx="512" cy="470" r="200" fill="none" stroke="{ACCENT}" stroke-width="22" opacity="0.35"/>'
        + f'<circle cx="512" cy="470" r="120" fill="none" stroke="{ACCENT}" stroke-width="22" opacity="0.65"/>'
        + f'<circle cx="512" cy="470" r="46" fill="{ACCENT}"/>'
        + text("DEAD ON", 770, 104, spacing=4),
    # Streaks: the number, and the ring grows bolder with the level.
    "streak5": ring(400, 30, ACCENT)
        + text("5", 600, 400)
        + text("IN A ROW", 720, 64, color="#FFFFFF", weight=800, spacing=6),
    "streak10": ring(400, 52, ACCENT)
        + ring(330, 14, ACCENT, gap=(100, 150))
        + text("10", 590, 360)
        + text("IN A ROW", 710, 64, color="#FFFFFF", weight=800, spacing=6),
    "streak25": f'<circle cx="512" cy="512" r="430" fill="{ACCENT}"/>'
        + ring(360, 30, BG)
        + text("25", 590, 360, color=BG)
        + text("IN A ROW", 710, 64, color=BG, weight=900, spacing=6),
    # Daily: a calendar page with a stopwatch hand.
    "daily": ring(400, 30, ACCENT)
        + f'<rect x="292" y="290" width="440" height="400" rx="56" fill="none" stroke="{ACCENT}" stroke-width="30"/>'
        + f'<rect x="292" y="290" width="440" height="110" rx="56" fill="{ACCENT}"/>'
        + f'<rect x="292" y="350" width="440" height="50" fill="{ACCENT}"/>'
        + f'<rect x="372" y="240" width="34" height="100" rx="17" fill="{ACCENT}"/>'
        + f'<rect x="618" y="240" width="34" height="100" rx="17" fill="{ACCENT}"/>'
        + text("10.00", 592, 128, weight=900)
        + dots(3, 3, 650, spacing=60, r=16)
        + text("DAILY", 800, 80, color="#FFFFFF", weight=800, spacing=8),
}

PAGE = """<!doctype html><html><head><style>
@font-face {{ font-family: Nunito; font-weight: 800; src: url(data:font/woff2;base64,{f800}); }}
@font-face {{ font-family: Nunito; font-weight: 900; src: url(data:font/woff2;base64,{f900}); }}
html, body {{ margin: 0; background: {bg}; }}
</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<rect width="1024" height="1024" fill="{bg}"/>{content}</svg></body></html>"""


def font(weight):
    # Embedded, since a page without an origin may not load file:// fonts.
    return base64.b64encode((FONTS / f"nunito-latin-{weight}-normal.woff2").read_bytes()).decode()


def main():
    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        page = browser.new_page(viewport={"width": 1024, "height": 1024})
        for name, content in BADGES.items():
            page.set_content(PAGE.format(f800=font(800), f900=font(900), bg=BG, content=content))
            page.evaluate("document.fonts.ready")
            page.wait_for_timeout(200)
            png = page.screenshot(clip={"x": 0, "y": 0, "width": 1024, "height": 1024})
            out = HERE / f"achievement-{name}.png"
            Image.open(io.BytesIO(png)).convert("RGB").save(out, optimize=True)
            print("Wrote", out.relative_to(HERE.parent.parent))
        browser.close()


if __name__ == "__main__":
    main()
