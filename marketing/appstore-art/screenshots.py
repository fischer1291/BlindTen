#!/usr/bin/env python3
"""Turns the raw simulator captures into App Store screenshots.

Each screenshot shows the real app in an iPhone frame under one short
phrase, in the app's look (Apple's guidance: lead with the best moments,
tell a story in order, let short text add to the real interface). The
first three also appear in search results, so they carry the hook.

Reads   AppStore/Screenshots/raw/<size>/<scene>.jpg   (from the workflow)
Writes  AppStore/Screenshots/<size>/<n>-<scene>.jpg   (upload these)

    python3 marketing/appstore-art/screenshots.py

Set CHROMIUM=/path/to/chrome if Playwright has no browser of its own.
"""
import base64
import io
import os
from pathlib import Path

from PIL import Image
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent.parent
FONTS = ROOT / "marketing" / "tools" / "fonts"
SCREENSHOTS = ROOT / "AppStore" / "Screenshots"

# Display size folder: canvas App Store Connect expects.
SIZES = {
    "iPhone-6.9": (1320, 2868),
    "iPhone-6.3": (1206, 2622),
}

# In order: (raw capture, phrase). "|" breaks the line; [brackets] are yellow.
STORY = [
    ("dead-on", "Can you feel|[10 seconds?]"),
    ("start", "Tap START.|[The timer vanishes.]"),
    ("showdown", "Showdown:|[head to head.]"),
    ("awards", "Crown the|[inner clock.]"),
    ("home", "Party, solo|[or online.]"),
    ("streak", "Daily Challenge|[& streaks.]"),
    ("seasons", "A new season|[every week.]"),
    ("modes", "[8 modes]|to master."),
]


def data_uri(path, mime):
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def phrase_html(text):
    return text.replace("[", "<em>").replace("]", "</em>").replace("|", "<br>")


def page(width, height, shot, phrase):
    u = width / 100
    font = data_uri(FONTS / "nunito-latin-900-normal.woff2", "font/woff2")
    # The phone keeps the capture's own aspect ratio.
    phone_w = width * 0.80
    raw = Image.open(shot)
    phone_h = phone_w * raw.height / raw.width
    return f"""<!doctype html><html><head><style>
@font-face {{ font-family: Nunito; font-weight: 900; src: url({font}); }}
* {{ margin: 0; box-sizing: border-box; }}
html, body {{ width: {width}px; height: {height}px; overflow: hidden; }}
body {{
  font-family: Nunito; font-weight: 900; color: #fff; position: relative;
  background:
    radial-gradient(ellipse {70 * u}px {55 * u}px at 50% 66%, rgba(255,209,0,0.26), transparent 70%),
    #0A0A0C;
}}
h1 {{
  position: absolute; left: {7 * u}px; right: {7 * u}px; top: {11 * u}px;
  font-size: {9.6 * u}px; line-height: 1.08; white-space: nowrap; letter-spacing: {-0.15 * u}px; text-align: center;
}}
h1 em {{ font-style: normal; color: #FFD100; }}
.phone {{
  position: absolute; left: {(width - phone_w) / 2:.0f}px; top: {height * 0.22:.0f}px;
  width: {phone_w:.0f}px; height: {phone_h:.0f}px; border-radius: {phone_w * 0.14:.0f}px;
  padding: {phone_w * 0.022:.0f}px; background: #2A2A2E;
  box-shadow: 0 {2 * u}px {7 * u}px rgba(0,0,0,0.65), 0 0 0 {0.3 * u}px #45454C;
}}
.phone img {{ width: 100%; height: 100%; display: block; border-radius: {phone_w * 0.12:.0f}px; }}
</style></head><body>
<h1>{phrase_html(phrase)}</h1>
<div class="phone"><img src="{data_uri(shot, 'image/jpeg')}"></div>
</body></html>"""


def main():
    with sync_playwright() as p:
        launch = {"executable_path": os.environ["CHROMIUM"]} if os.environ.get("CHROMIUM") else {}
        browser = p.chromium.launch(**launch)
        for folder, (width, height) in SIZES.items():
            raw_dir = SCREENSHOTS / "raw" / folder
            if not raw_dir.is_dir():
                print("Skipping", folder, "(no raw captures)")
                continue
            out_dir = SCREENSHOTS / folder
            out_dir.mkdir(parents=True, exist_ok=True)
            for old in out_dir.glob("*.jpg"):
                old.unlink()
            for number, (scene, phrase) in enumerate(STORY, start=1):
                shot = raw_dir / f"{scene}.jpg"
                tab = browser.new_page(viewport={"width": width, "height": height})
                tab.set_content(page(width, height, shot, phrase))
                tab.evaluate("document.fonts.ready")
                tab.wait_for_timeout(200)
                png = tab.screenshot(clip={"x": 0, "y": 0, "width": width, "height": height})
                image = Image.open(io.BytesIO(png)).convert("RGB")
                assert image.size == (width, height), image.size
                out = out_dir / f"{number}-{scene}.jpg"
                image.save(out, quality=92, optimize=True)
                print("Wrote", out.relative_to(ROOT), image.size)
                tab.close()
        browser.close()


if __name__ == "__main__":
    main()
