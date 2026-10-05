#!/usr/bin/env python3
"""Generates the placeholder app icon: a yellow stopwatch on black.

Pure standard library. 1024x1024 RGB without alpha, as the App Store
requires. Replace with a designed icon before launch.

    python3 Tools/generate_icon.py
"""
import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
SAMPLES = 2  # 2x2 supersampling for smooth edges
OUT = Path(__file__).resolve().parent.parent / "BlindTen" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

BACKGROUND = (10, 10, 12)
YELLOW = (255, 209, 0)

CX, CY = 512, 560          # dial center
R_OUT, R_IN = 330, 262     # ring
HAND_W = 34                # hand width


def inside(x, y):
    dx, dy = x - CX, y - CY
    d = math.hypot(dx, dy)
    # Ring with a gap at the bottom-left: the "blind" part of the dial.
    angle = math.degrees(math.atan2(dy, dx))  # 0 = right, 90 = down
    if R_IN <= d <= R_OUT and not (100 <= angle <= 150):
        return True
    # Crown button on top.
    if abs(x - CX) <= 52 and CY - R_OUT - 92 <= y <= CY - R_OUT + 10:
        return True
    if abs(x - CX) <= 90 and CY - R_OUT - 130 <= y <= CY - R_OUT - 80:
        return True
    # Hand pointing straight up, to the target.
    if abs(x - CX) <= HAND_W / 2 and CY - R_IN + 50 <= y <= CY:
        return True
    # Hub.
    if d <= 46:
        return True
    return False


def main():
    rows = bytearray()
    step = 1 / SAMPLES
    for py in range(SIZE):
        rows.append(0)  # PNG filter: none
        for px in range(SIZE):
            hits = 0
            for sy in range(SAMPLES):
                for sx in range(SAMPLES):
                    if inside(px + (sx + 0.5) * step, py + (sy + 0.5) * step):
                        hits += 1
            a = hits / (SAMPLES * SAMPLES)
            rows += bytes(round(BACKGROUND[i] * (1 - a) + YELLOW[i] * a) for i in range(3))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))  # 8-bit RGB
    png += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    png += chunk(b"IEND", b"")
    OUT.write_bytes(png)
    print(f"Wrote {OUT.name} ({len(png) // 1024} KB)")


if __name__ == "__main__":
    main()
