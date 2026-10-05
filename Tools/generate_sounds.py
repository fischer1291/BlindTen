#!/usr/bin/env python3
"""Generates the placeholder sound effects in BlindTen/Resources/Sounds.

Pure standard library, deterministic. Replace the output with produced
sounds before launch; keep the file names (drumroll, cymbal, trombone).

    python3 Tools/generate_sounds.py
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "BlindTen" / "Resources" / "Sounds"


def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.89 / peak
    fade = int(0.01 * RATE)
    data = bytearray()
    for i, s in enumerate(samples):
        gain = min(1.0, i / fade, (len(samples) - 1 - i) / fade)
        data += struct.pack("<h", int(max(-1.0, min(1.0, s * scale * gain)) * 32767))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(data))


def drumroll(rng, seconds=1.6):
    """Snare hits that speed up and get louder."""
    n = int(seconds * RATE)
    out = [0.0] * n
    t = 0.0
    while t < seconds:
        progress = t / seconds
        level = 0.35 + 0.65 * progress
        start = int(t * RATE)
        for i in range(int(0.06 * RATE)):
            if start + i >= n:
                break
            env = math.exp(-i / (0.012 * RATE))
            noise = rng.uniform(-1, 1)
            body = math.sin(2 * math.pi * 190 * i / RATE)
            out[start + i] += level * env * (0.8 * noise + 0.35 * body)
        t += 0.065 - 0.035 * progress + rng.uniform(-0.004, 0.004)
    return out


def cymbal(rng, seconds=1.8):
    """Bright crash: high-passed noise with a long decay."""
    n = int(seconds * RATE)
    out = []
    previous = 0.0
    for i in range(n):
        noise = rng.uniform(-1, 1)
        bright = noise - previous  # first difference = simple high-pass
        previous = noise
        env = math.exp(-i / (0.45 * RATE)) * (1.0 if i > 40 else i / 40)
        shimmer = 0.15 * math.sin(2 * math.pi * 5300 * i / RATE) * env
        out.append(0.7 * bright * env + shimmer)
    return out


def trombone(rng, seconds=2.6):
    """Sad 'wah wah wah waaah': four falling notes, vibrato on the last."""
    notes = [(233.08, 0.42), (220.0, 0.42), (207.65, 0.42), (196.0, 1.2)]
    out = []
    for index, (freq, length) in enumerate(notes):
        count = int(length * RATE)
        phase = 0.0
        last = index == len(notes) - 1
        for i in range(count):
            t = i / RATE
            f = freq * (1 + (0.015 * math.sin(2 * math.pi * 5.5 * t) if last else 0))
            if last:
                f *= 1 - 0.04 * (t / length)
            phase += 2 * math.pi * f / RATE
            tone = sum(math.sin(k * phase) / k ** 1.3 for k in range(1, 7))
            attack = min(1.0, t / 0.04)
            release = min(1.0, (length - t) / (0.25 if last else 0.06))
            wah = 0.55 + 0.45 * math.sin(math.pi * min(1.0, t / (length * 0.8)))
            out.append(tone * attack * release * wah)
        out.extend([0.0] * int(0.03 * RATE))
    total = int(seconds * RATE)
    return (out + [0.0] * total)[:total]


if __name__ == "__main__":
    write("drumroll", drumroll(random.Random(1)))
    write("cymbal", cymbal(random.Random(2)))
    write("trombone", trombone(random.Random(3)))
    print("Wrote", ", ".join(sorted(p.name for p in OUT.glob("*.wav"))))
