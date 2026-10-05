#!/usr/bin/env python3
"""Generates the logo images: the app icon and the launch-screen logo.

A yellow stopwatch with a gap in the dial (the "blind" part). Pure
standard library.

- AppIcon.png: 1024x1024 RGB on black, no alpha, as the App Store requires.
- LaunchLogo@2x/@3x.png: the same mark on a transparent background, shown
  at 200 pt on the launch screen. LogoMark.swift draws the identical shape
  so the animated splash continues seamlessly from it.

    python3 Tools/generate_icon.py
"""
import math
import struct
import zlib
from pathlib import Path

ASSETS = Path(__file__).resolve().parent.parent / "BlindTen" / "Resources" / "Assets.xcassets"

ICON_BACKGROUND = (10, 10, 12)
YELLOW = (255, 209, 0)

# Geometry in a 1024 x 1024 design space (keep in sync with LogoMark.swift).
CX, CY = 512, 560          # dial center
R_OUT, R_IN = 330, 262     # ring
GAP = (100, 150)           # gap in degrees, 0 = right, 90 = down
HAND_W = 34
HAND_TOP = CY - R_IN + 50  # 348
HUB_R = 46


def inside(x, y):
    dx, dy = x - CX, y - CY
    d = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dy, dx))
    if R_IN <= d <= R_OUT and not (GAP[0] <= angle <= GAP[1]):
        return True
    if abs(x - CX) <= 52 and CY - R_OUT - 92 <= y <= CY - R_OUT + 10:   # crown stem
        return True
    if abs(x - CX) <= 90 and CY - R_OUT - 130 <= y <= CY - R_OUT - 80:  # crown cap
        return True
    if abs(x - CX) <= HAND_W / 2 and HAND_TOP <= y <= CY:               # hand
        return True
    return d <= HUB_R                                                    # hub


def render(size, background, samples=2):
    """Returns PNG bytes. `background` None means transparent RGBA."""
    scale = 1024 / size
    step = 1 / samples
    rows = bytearray()
    for py in range(size):
        rows.append(0)
        for px in range(size):
            hits = sum(
                inside((px + (sx + 0.5) * step) * scale, (py + (sy + 0.5) * step) * scale)
                for sy in range(samples)
                for sx in range(samples)
            )
            a = hits / (samples * samples)
            if background is None:
                rows += bytes(YELLOW) + bytes([round(255 * a)])
            else:
                rows += bytes(round(background[i] * (1 - a) + YELLOW[i] * a) for i in range(3))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    color_type = 6 if background is None else 2
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    return png


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    print(f"Wrote {path.relative_to(ASSETS.parent.parent.parent)} ({len(data) // 1024} KB)")


if __name__ == "__main__":
    write(ASSETS / "AppIcon.appiconset" / "AppIcon.png", render(1024, ICON_BACKGROUND))
    write(ASSETS / "LaunchLogo.imageset" / "LaunchLogo@2x.png", render(400, None, samples=3))
    write(ASSETS / "LaunchLogo.imageset" / "LaunchLogo@3x.png", render(600, None, samples=3))
